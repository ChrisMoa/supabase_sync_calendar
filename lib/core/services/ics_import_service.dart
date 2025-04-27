import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:icalendar_parser/icalendar_parser.dart';
import 'package:supabase_sync_calendar/core/models/calendar_event_model.dart';
import 'package:supabase_sync_calendar/core/models/calendar_model.dart';
import 'package:uuid/uuid.dart';

class ICSImportService {
  final Uuid _uuid = const Uuid();

  // Import events from an ICS file string content
  Future<List<CalendarEventModel>> importFromString(
    String icsContent,
    CalendarModel calendar,
  ) async {
    try {
      // Parse the ICS data
      final iCalendar = ICalendar.fromString(icsContent);

      // Convert events
      return _convertICalendarEvents(iCalendar, calendar);
    } catch (e) {
      debugPrint('Failed to import ICS file: $e');
      throw Exception('Failed to import ICS file: $e');
    }
  }

  // Import events from an ICS file
  Future<List<CalendarEventModel>> importFromFile(
    File icsFile,
    CalendarModel calendar,
  ) async {
    try {
      // Read file content
      final icsContent = await icsFile.readAsString();
      return importFromString(icsContent, calendar);
    } catch (e) {
      debugPrint('Failed to import ICS file: $e');
      throw Exception('Failed to import ICS file: $e');
    }
  }

  // Convert iCalendar events to CalendarEventModel
  List<CalendarEventModel> _convertICalendarEvents(
    ICalendar iCalendar,
    CalendarModel calendar,
  ) {
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
        isExternalReadOnly: false, // We can edit imported events
        appendixes: const [],
      ));
    }

    return events;
  }
}
