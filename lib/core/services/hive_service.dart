import 'dart:convert';
import 'package:hive_flutter/adapters.dart';
import 'package:supabase_sync_calendar/core/models/calendar_event_model.dart';
import 'package:supabase_sync_calendar/core/models/calendar_event_series_model.dart';
import 'package:supabase_sync_calendar/core/models/calendar_model.dart';
import 'package:crypto/crypto.dart';
import 'package:convert/convert.dart';
import 'package:flutter/foundation.dart';

// The generated files are included via 'part' directives in their respective models,
// so direct imports here are not needed and cause errors.
// import 'package:supabase_sync_calendar/core/models/calendar_event_model.g.dart';
// import 'package:supabase_sync_calendar/core/models/calendar_event_series_model.g.dart';
// import 'package:supabase_sync_calendar/core/models/calendar_model.g.dart';

// Adapter for CalendarType enum
class CalendarTypeAdapter extends TypeAdapter<CalendarType> {
  @override
  final int typeId = 10; // Must match the typeId used in CalendarModel

  @override
  CalendarType read(BinaryReader reader) {
    return CalendarType.values[reader.readByte()];
  }

  @override
  void write(BinaryWriter writer, CalendarType obj) {
    writer.writeByte(obj.index);
  }
}

// Adapter for SeriesRepeatType enum
class SeriesRepeatTypeAdapter extends TypeAdapter<SeriesRepeatType> {
  @override
  final int typeId = 11; // Must match the typeId used in the enum definition

  @override
  SeriesRepeatType read(BinaryReader reader) {
    return SeriesRepeatType.values[reader.readByte()];
  }

  @override
  void write(BinaryWriter writer, SeriesRepeatType obj) {
    writer.writeByte(obj.index);
  }
}

// Adapter for SeriesEndType enum
class SeriesEndTypeAdapter extends TypeAdapter<SeriesEndType> {
  @override
  final int typeId = 12; // Must match the typeId used in the enum definition

  @override
  SeriesEndType read(BinaryReader reader) {
    return SeriesEndType.values[reader.readByte()];
  }

  @override
  void write(BinaryWriter writer, SeriesEndType obj) {
    writer.writeByte(obj.index);
  }
}

class HiveService {
  static const String _userBox = 'user_box';
  static const String _calendarBox = 'calendar_box';
  static const String _eventBox = 'event_box';
  static const String _seriesBox = 'series_box';
  static const String _syncBox = 'sync_box'; // For tracking sync status

  // Initialize Hive with encryption key (derived from user password)
  static Future<void> init(String encryptionKey) async {
    // Initialize Hive with a specific path for this app
    await Hive.initFlutter('supabase_sync_calendar');

    // Register adapters
    // The adapter classes (e.g., CalendarModelAdapter) are defined in the .g.dart files,
    // which are included via 'part' in the model files.
    Hive.registerAdapter(CalendarModelAdapter());
    Hive.registerAdapter(CalendarEventModelAdapter()); // Assuming these are generated
    Hive.registerAdapter(CalendarEventSeriesModelAdapter()); // Assuming these are generated
    Hive.registerAdapter(CalendarTypeAdapter());
    Hive.registerAdapter(SeriesRepeatTypeAdapter()); // Register new enum adapter
    Hive.registerAdapter(SeriesEndTypeAdapter()); // Register new enum adapter

    // Create a 32-byte key from the password using SHA-256
    final keyBytes = sha256.convert(utf8.encode(encryptionKey)).bytes;

    // Open encrypted boxes
    await Hive.openBox(_userBox, encryptionCipher: HiveAesCipher(keyBytes));
    await Hive.openBox(_calendarBox, encryptionCipher: HiveAesCipher(keyBytes));
    await Hive.openBox(_eventBox, encryptionCipher: HiveAesCipher(keyBytes));
    await Hive.openBox(_seriesBox, encryptionCipher: HiveAesCipher(keyBytes));
    await Hive.openBox(_syncBox, encryptionCipher: HiveAesCipher(keyBytes));
  }

  // User data methods
  static Future<void> saveUserData(String userId, Map<String, dynamic> userData) async {
    final box = Hive.box(_userBox);
    // Convert all maps to Maps with String keys to ensure consistent retrieval
    final Map<String, dynamic> processedData = {};

    userData.forEach((key, value) {
      if (value is Map) {
        // Convert nested maps to ensure string keys
        final Map<String, dynamic> stringMap = {};
        (value as Map).forEach((k, v) {
          stringMap[k.toString()] = v;
        });
        processedData[key] = stringMap;
      } else {
        processedData[key] = value;
      }
    });

    await box.put(userId, processedData);
  }

  static dynamic getUserData(String userId) {
    final box = Hive.box(_userBox);
    return box.get(userId);
  }

  // Helper methods to get boxes
  static Box getCalendarBox() {
    return Hive.box(_calendarBox);
  }

  static Box getEventBox() {
    return Hive.box(_eventBox);
  }

  static Box getSeriesBox() {
    return Hive.box(_seriesBox);
  }

  static Box getSyncBox() {
    return Hive.box(_syncBox);
  }

  // Calendar methods
  static Future<void> saveCalendar(CalendarModel calendar) async {
    final box = getCalendarBox();
    await box.put(calendar.id, calendar);
    // Mark for sync
    await markForSync('calendar', calendar.id);
  }

  static List<CalendarModel> getAllCalendars() {
    final box = getCalendarBox();
    final allCalendars = box.values.cast<CalendarModel>().toList();
    debugPrint('📋 HIVE: getAllCalendars() - Found ${allCalendars.length} calendars in box');
    return allCalendars;
  }

  static CalendarModel? getCalendar(String calendarId) {
    final box = getCalendarBox();
    final calendar = box.get(calendarId);
    debugPrint('📋 HIVE: getCalendar($calendarId) - ${calendar != null ? 'Found' : 'Not found'}');
    return calendar;
  }

  static Future<void> deleteCalendar(String calendarId) async {
    final box = getCalendarBox();
    await box.delete(calendarId);
    // Mark for sync (deletion)
    await markForSync('calendar_delete', calendarId);
  }

  // Event methods
  static Future<void> saveEvent(CalendarEventModel event) async {
    final box = getEventBox();
    await box.put(event.id, event);
    // Mark for sync
    await markForSync('event', event.id);
  }

  static List<CalendarEventModel> getAllEvents() {
    final box = getEventBox();
    final allEvents = box.values.cast<CalendarEventModel>().toList();
    debugPrint('📋 HIVE: getAllEvents() - Found ${allEvents.length} events in box');
    return allEvents;
  }

  static List<CalendarEventModel> getEventsByCalendar(String calendarId) {
    final box = getEventBox();
    final allEvents = box.values.cast<CalendarEventModel>().toList();
    final filteredEvents = allEvents.where((event) => event.calendarId == calendarId).toList();
    debugPrint('📋 HIVE: getEventsByCalendar($calendarId) - Found ${filteredEvents.length} events for this calendar (of ${allEvents.length} total)');
    return filteredEvents;
  }

  static CalendarEventModel? getEvent(String eventId) {
    final box = getEventBox();
    final event = box.get(eventId);
    debugPrint('📋 HIVE: getEvent($eventId) - ${event != null ? 'Found' : 'Not found'}');
    return event;
  }

  static Future<void> deleteEvent(String eventId) async {
    final box = getEventBox();
    await box.delete(eventId);
    // Mark for sync (deletion)
    await markForSync('event_delete', eventId);
  }

  // Series methods
  static Future<void> saveSeries(CalendarEventSeriesModel series) async {
    final box = getSeriesBox();
    await box.put(series.id, series);
    // Mark for sync
    await markForSync('series', series.id);
  }

  // Alias for saveSeries to match the method names expected in other files
  static Future<void> saveEventSeries(CalendarEventSeriesModel series) async {
    await saveSeries(series);
  }

  static List<CalendarEventSeriesModel> getAllSeries() {
    final box = getSeriesBox();
    final allSeries = box.values.cast<CalendarEventSeriesModel>().toList();
    debugPrint('📋 HIVE: getAllSeries() - Found ${allSeries.length} series in box');
    return allSeries;
  }

  static CalendarEventSeriesModel? getSeries(String seriesId) {
    final box = getSeriesBox();
    final series = box.get(seriesId);
    debugPrint('📋 HIVE: getSeries($seriesId) - ${series != null ? 'Found' : 'Not found'}');
    return series;
  }

  // Alias for getSeries to match the method names expected in other files
  static CalendarEventSeriesModel? getEventSeries(String seriesId) {
    return getSeries(seriesId);
  }

  static Future<void> deleteSeries(String seriesId) async {
    final box = getSeriesBox();
    await box.delete(seriesId);
    // Mark for sync (deletion)
    await markForSync('series_delete', seriesId);
  }

  // Alias for deleteSeries to match the method names expected in other files
  static Future<void> deleteEventSeries(String seriesId) async {
    await deleteSeries(seriesId);
  }

  // Delete all events belonging to a series
  static Future<void> deleteSeriesEvents(String seriesId) async {
    final box = getEventBox();
    final allEvents = box.values.cast<CalendarEventModel>().toList();

    // Find all events with this series ID
    final seriesEvents = allEvents.where((event) => event.seriesId == seriesId).toList();

    // Delete each event
    for (final event in seriesEvents) {
      await box.delete(event.id);
      // Mark for sync (deletion)
      await markForSync('event_delete', event.id);
    }

    debugPrint('📋 HIVE: deleteSeriesEvents($seriesId) - Deleted ${seriesEvents.length} events');
  }

  // Sync tracking methods
  static Future<void> markForSync(String type, String id) async {
    final box = getSyncBox();
    final syncList = box.get(type, defaultValue: <String>[]);
    if (!syncList.contains(id)) {
      syncList.add(id);
      await box.put(type, syncList);
    }
  }

  static List<String> getItemsToSync(String type) {
    final box = getSyncBox();
    return (box.get(type, defaultValue: <String>[]) as List).cast<String>();
  }

  static Future<void> markAsSynced(String type, String id) async {
    final box = getSyncBox();
    final syncList = box.get(type, defaultValue: <String>[]);
    syncList.remove(id);
    await box.put(type, syncList);
  }

  // Clear all data (for logout)
  static Future<void> clearAllData() async {
    await Hive.box(_userBox).clear();
    await Hive.box(_calendarBox).clear();
    await Hive.box(_eventBox).clear();
    await Hive.box(_seriesBox).clear();
    await Hive.box(_syncBox).clear();
  }
}
