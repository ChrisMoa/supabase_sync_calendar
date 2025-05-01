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

  Future<List<CalendarEventModel>> processOpenedFiles(List<SharedFile> sharedFiles, CalendarModel defaultCalendar) async {
    try {
      final List<CalendarEventModel> events = [];

      for (var sharedFile in sharedFiles) {
        final String? fileValue = sharedFile.value;
        if (fileValue == null) {
          print('Warning: File value is null, skipping...');
          continue;
        }

        print('Processing file: $fileValue with type: ${sharedFile.type}');

        try {
          String content;
          if (fileValue.startsWith('content://')) {
            print('Reading content URI: $fileValue');
            try {
              content = await _methodChannel.invokeMethod('readContentUri', {'uri': fileValue});
              print('Successfully read content from URI');
            } catch (e) {
              print('Error reading content URI: $e');
              rethrow;
            }
          } else {
            print('Reading file path: $fileValue');
            content = await File(fileValue).readAsString();
          }

          print('Parsing ICS content...');
          final ICalendar calendar = ICalendar.fromString(content);
          print('Successfully parsed ICS content');

          print('Converting events...');
          for (var event in calendar.data) {
            final type = event['type'] as String?;
            print('Processing component of type: $type');

            if (type == 'VEVENT') {
              final summary = event['summary'] as String?;
              print('Processing event: $summary');

              // Parse dates with fallback to current time
              DateTime start;
              DateTime end;
              try {
                final startIcs = event['dtstart'] as IcsDateTime?;
                final endIcs = event['dtend'] as IcsDateTime?;

                start = startIcs?.toDateTime() ?? DateTime.now();
                end = endIcs?.toDateTime() ?? start.add(const Duration(hours: 1));

                print('Parsed dates - Start: $start, End: $end');
              } catch (e) {
                print('Error parsing dates: $e');
                start = DateTime.now();
                end = start.add(const Duration(hours: 1));
              }

              events.add(CalendarEventModel(
                id: _uuid.v4(),
                title: summary ?? 'Untitled Event',
                description: event['description'] as String? ?? '',
                color: defaultCalendar.color.withAlpha(255),
                userId: defaultCalendar.userId,
                calendarId: defaultCalendar.id,
                start: start,
                end: end,
              ));
            }
          }
          print('Successfully processed ${events.length} events from file');
        } catch (e, stackTrace) {
          print('Error parsing ICS file: $e');
          print('Stack trace: $stackTrace');
          // Continue with other files if one fails
          continue;
        }
      }

      if (events.isEmpty && sharedFiles.isNotEmpty) {
        throw Exception("No valid calendar events could be extracted from the shared files.");
      }

      return events;
    } catch (e, stackTrace) {
      print('Error processing shared files: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }
}
