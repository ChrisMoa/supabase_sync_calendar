import 'package:dio/dio.dart';
import 'package:icalendar_parser/icalendar_parser.dart';
import 'package:supabase_sync_calendar/core/models/calendar_event_model.dart';
import 'package:supabase_sync_calendar/core/models/calendar_model.dart';
import 'package:uuid/uuid.dart';

class WebDAVCalendarService {
  final Dio _dio = Dio();
  final Uuid _uuid = const Uuid();

  // Synchronize events from a WebDAV calendar
  Future<List<CalendarEventModel>> syncCalendar(CalendarModel calendar) async {
    if (calendar.type != CalendarType.webdav || calendar.syncUrl == null) {
      throw Exception('Not a WebDAV calendar or missing sync URL');
    }

    try {
      // Fetch iCalendar data from WebDAV server
      final response = await _dio.get(calendar.syncUrl!);
      final icsData = response.data as String;

      // Parse iCalendar data
      final iCalendar = ICalendar.fromString(icsData);

      // Convert events
      return _convertICalendarEvents(iCalendar, calendar);
    } catch (e) {
      throw Exception('Failed to sync WebDAV calendar: $e');
    }
  }

  // Convert iCalendar events to CalendarEventModel
  List<CalendarEventModel> _convertICalendarEvents(
      ICalendar iCalendar, CalendarModel calendar) {
    final events = <CalendarEventModel>[];

    for (final event in iCalendar.data) {
      // Skip non-VEVENT entries
      if (event['type'] != 'VEVENT') continue;

      // Parse required fields
      final uid = event['uid'] ?? _uuid.v4();
      final summary = event['summary'] ?? 'Untitled Event';
      final description = event['description'] ?? '';

      // Parse start and end times
      DateTime? start;
      DateTime? end;
      bool isAllDay = false;

      if (event['dtstart'] != null) {
        if (event['dtstart'] is DateTime) {
          start = event['dtstart'] as DateTime;
        } else if (event['dtstart'] is Map &&
            event['dtstart']['value'] is DateTime) {
          start = event['dtstart']['value'] as DateTime;
          // Check if it's a date-only value (all-day event)
          isAllDay = event['dtstart']['params']?['value'] == 'DATE';
        }
      }

      if (event['dtend'] != null) {
        if (event['dtend'] is DateTime) {
          end = event['dtend'] as DateTime;
        } else if (event['dtend'] is Map &&
            event['dtend']['value'] is DateTime) {
          end = event['dtend']['value'] as DateTime;
        }
      }

      // Skip events with missing required data
      if (start == null || end == null) continue;

      events.add(CalendarEventModel(
        id: uid,
        title: summary,
        description: description,
        start: start,
        end: end,
        color: calendar.color,
        userId: calendar.userId,
        calendarId: calendar.id,
        wholeDay: isAllDay,
        isExternalReadOnly:
            true, // Mark as read-only since it's from external source
      ));
    }

    return events;
  }
}
