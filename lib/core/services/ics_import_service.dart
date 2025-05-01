import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sharing_intent/model/sharing_file.dart';
import 'package:icalendar_parser/icalendar_parser.dart';
import 'package:supabase_sync_calendar/core/models/calendar_event_model.dart';
import 'package:supabase_sync_calendar/core/models/calendar_model.dart';
import 'package:supabase_sync_calendar/core/utils/event_checker.dart';
import 'package:uuid/uuid.dart';

class ICSImportService {
  final Uuid _uuid = const Uuid();
  static const _methodChannel = MethodChannel('com.example.supabase_sync_calendar/file_handler');

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

      final startIcs = event['dtstart'] as IcsDateTime?;
      final endIcs = event['dtend'] as IcsDateTime?;
      start = startIcs?.toDateTime() ?? DateTime.now();
      end = endIcs?.toDateTime() ?? start.add(const Duration(hours: 1));
      isAllDay = EventChecker.isCompleteDay(start, end);

      events.add(CalendarEventModel(
        id: uid,
        title: summary,
        description: description,
        start: start,
        end: end,
        colorValue: calendar.colorValue,
        userId: calendar.userId,
        calendarId: calendar.id,
        wholeDay: isAllDay,
        isExternalReadOnly: false, // We can edit imported events
        appendixes: const [],
      ));
    }

    return events;
  }

  Future<List<CalendarEventModel>> processOpenedFiles(List<SharedFile> sharedFiles, CalendarModel defaultCalendar) async {
    try {
      final List<CalendarEventModel> events = [];

      for (var sharedFile in sharedFiles) {
        final String? fileValue = sharedFile.value;
        if (fileValue == null) {
          debugPrint('Warning: File value is null, skipping...');
          continue;
        }

        debugPrint('Processing file: $fileValue with type: ${sharedFile.type}');

        try {
          String content;
          if (fileValue.startsWith('content://')) {
            debugPrint('Reading content URI: $fileValue');
            try {
              content = await _methodChannel.invokeMethod('readContentUri', {'uri': fileValue});
              debugPrint('Successfully read content from URI');
            } catch (e) {
              debugPrint('Error reading content URI: $e');
              rethrow;
            }
          } else {
            debugPrint('Reading file path: $fileValue');
            content = await File(fileValue).readAsString();
          }

          debugPrint('Parsing ICS content...');
          final ICalendar calendar = ICalendar.fromString(content);
          debugPrint('Successfully parsed ICS content');

          debugPrint('Converting events...');
          for (var event in calendar.data) {
            final type = event['type'] as String?;
            debugPrint('Processing component of type: $type');

            if (type == 'VEVENT') {
              final summary = event['summary'] as String?;
              debugPrint('Processing event: $summary');

              // Parse dates with fallback to current time
              DateTime start;
              DateTime end;
              try {
                final startIcs = event['dtstart'] as IcsDateTime?;
                final endIcs = event['dtend'] as IcsDateTime?;

                start = startIcs?.toDateTime() ?? DateTime.now();
                end = endIcs?.toDateTime() ?? start.add(const Duration(hours: 1));

                debugPrint('Parsed dates - Start: $start, End: $end');
              } catch (e) {
                debugPrint('Error parsing dates: $e');
                start = DateTime.now();
                end = start.add(const Duration(hours: 1));
              }

              events.add(CalendarEventModel(
                id: _uuid.v4(),
                title: summary ?? 'Untitled Event',
                description: event['description'] as String? ?? '',
                colorValue: defaultCalendar.colorValue,
                userId: defaultCalendar.userId,
                calendarId: defaultCalendar.id,
                start: start,
                end: end,
              ));
            }
          }
          debugPrint('Successfully processed ${events.length} events from file');
        } catch (e, stackTrace) {
          debugPrint('Error parsing ICS file: $e');
          debugPrint('Stack trace: $stackTrace');
          // Continue with other files if one fails
          continue;
        }
      }

      if (events.isEmpty && sharedFiles.isNotEmpty) {
        throw Exception("No valid calendar events could be extracted from the shared files.");
      }

      return events;
    } catch (e, stackTrace) {
      debugPrint('Error processing shared files: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }
}
