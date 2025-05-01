import 'dart:convert';
import 'package:hive_flutter/adapters.dart';
import 'package:supabase_sync_calendar/core/models/calendar_event_model.dart';
import 'package:supabase_sync_calendar/core/models/calendar_event_series_model.dart';
import 'package:supabase_sync_calendar/core/models/calendar_model.dart';
import 'package:crypto/crypto.dart';
import 'package:convert/convert.dart';

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
    await Hive.initFlutter();

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
    await box.put(userId, userData);
  }

  static Map<String, dynamic>? getUserData(String userId) {
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
    return box.values.cast<CalendarModel>().toList();
  }

  static CalendarModel? getCalendar(String calendarId) {
    final box = getCalendarBox();
    return box.get(calendarId);
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
    return box.values.cast<CalendarEventModel>().toList();
  }

  static List<CalendarEventModel> getEventsByCalendar(String calendarId) {
    final box = getEventBox();
    return box.values.cast<CalendarEventModel>().where((event) => event.calendarId == calendarId).toList();
  }

  static CalendarEventModel? getEvent(String eventId) {
    final box = getEventBox();
    return box.get(eventId);
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

  static List<CalendarEventSeriesModel> getAllSeries() {
    final box = getSeriesBox();
    return box.values.cast<CalendarEventSeriesModel>().toList();
  }

  static CalendarEventSeriesModel? getSeries(String seriesId) {
    final box = getSeriesBox();
    return box.get(seriesId);
  }

  static Future<void> deleteSeries(String seriesId) async {
    final box = getSeriesBox();
    await box.delete(seriesId);
    // Mark for sync (deletion)
    await markForSync('series_delete', seriesId);
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
