import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:icalendar_parser/icalendar_parser.dart';
import 'package:supabase_sync_calendar/core/models/calendar_event_model.dart';
import 'package:supabase_sync_calendar/core/models/calendar_model.dart';
import 'package:supabase_sync_calendar/core/utils/event_checker.dart';
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
      // Read file content1
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
        } else if (event['dtstart'] is IcsDateTime) {
          final ev = event['dtstart'] as IcsDateTime;
          start = DateTime.tryParse(ev.dt);
        }
      }

      if (event['dtend'] != null) {
        if (event['dtend'] is DateTime) {
          end = event['dtend'] as DateTime;
        } else if (event['dtend'] is IcsDateTime) {
          final ev = event['dtend'] as IcsDateTime;
          end = DateTime.tryParse(ev.dt);
        }
      }

      // Skip events with missing required data
      if (start == null || end == null) continue;
      isAllDay = EventChecker.isCompleteDay(start, end);

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
