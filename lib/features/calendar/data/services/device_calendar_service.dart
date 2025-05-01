import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/models/calendar_event_model.dart';
import '../../../../core/models/calendar_model.dart';

class DeviceCalendarService {
  final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();
  final Uuid _uuid = const Uuid();

  Future<List<Calendar>> getDeviceCalendars() async {
    try {
      // Check permissions
      var permissionsGranted = await _deviceCalendarPlugin.hasPermissions();
      if (permissionsGranted.data == null || permissionsGranted.data == false) {
        debugPrint('No calendar permissions, requesting...');
        permissionsGranted = await _deviceCalendarPlugin.requestPermissions();

        if (permissionsGranted.data == null || permissionsGranted.data == false) {
          debugPrint('Calendar permissions denied by user');
          throw Exception('Calendar access denied. Please enable calendar permissions in your device settings.');
        }
      }

      // Retrieve calendars
      final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();

      if (calendarsResult.isSuccess && calendarsResult.data != null) {
        final calendars = calendarsResult.data!;
        // Debug each calendar for troubleshooting
        for (int i = 0; i < calendars.length; i++) {
          final calendar = calendars[i];
          debugPrint("Device calendar $i: id=${calendar.id}, name=${calendar.name}, color=${calendar.color}");
        }
        return calendars;
      } else {
        debugPrint('Failed to get calendars: ${calendarsResult.errors.toString()}');
        throw Exception('Failed to retrieve device calendars: ${calendarsResult.errors.toString()}');
      }
    } catch (e) {
      debugPrint('Error getting device calendars: $e');
      throw Exception('Failed to access device calendars: $e');
    }
  }

  // Convert device calendars to CalendarModel
  List<CalendarModel> convertToCalendarModels(List<Calendar> deviceCalendars, String userId) {
    final List<CalendarModel> calendars = [];
    final List<Color> defaultColors = [
      Colors.blue,
      Colors.green,
      Colors.red,
      Colors.orange,
      Colors.purple,
      Colors.teal,
    ];

    for (int i = 0; i < deviceCalendars.length; i++) {
      final deviceCalendar = deviceCalendars[i];
      final Color color = deviceCalendar.color != null ? Color(deviceCalendar.color!) : defaultColors[i % defaultColors.length];

      calendars.add(CalendarModel(
        id: _uuid.v4(),
        name: deviceCalendar.name ?? 'Unknown Calendar',
        colorValue: deviceCalendar.color != null ? color.value : defaultColors[i % defaultColors.length].value,
        userId: userId,
        type: CalendarType.device,
        deviceCalendarId: deviceCalendar.id,
        isDefault: deviceCalendar.isDefault ?? false,
      ));
    }

    return calendars;
  }

  // Sync events from a device calendar
  Future<List<CalendarEventModel>> syncDeviceCalendar(CalendarModel calendar, {DateTime? startDate, DateTime? endDate}) async {
    if (calendar.type != CalendarType.device || calendar.deviceCalendarId == null) {
      throw Exception('Not a device calendar or missing device calendar ID');
    }

    // Default to current year if no dates provided
    startDate ??= DateTime(DateTime.now().year, 1, 1);
    endDate ??= DateTime(DateTime.now().year, 12, 31);

    try {
      // Retrieve events
      final eventsResult = await _deviceCalendarPlugin.retrieveEvents(
        calendar.deviceCalendarId!,
        RetrieveEventsParams(
          startDate: startDate,
          endDate: endDate,
        ),
      );

      if (eventsResult.data == null) {
        return [];
      }

      // Convert events
      return _convertDeviceEvents(eventsResult.data!, calendar);
    } catch (e) {
      throw Exception('Failed to sync device calendar: $e');
    }
  }

  // Convert device events to CalendarEventModel
  List<CalendarEventModel> _convertDeviceEvents(List<Event> deviceEvents, CalendarModel calendar) {
    final events = <CalendarEventModel>[];

    for (final deviceEvent in deviceEvents) {
      // Skip events with missing required data
      if (deviceEvent.start == null || deviceEvent.end == null) continue;

      // Extract reminder time if available
      DateTime? reminderTime;
      if (deviceEvent.reminders?.isNotEmpty ?? false) {
        // Assuming we take the first reminder in minutes
        final minutes = deviceEvent.reminders!.first.minutes;
        if (minutes != null) {
          reminderTime = deviceEvent.start?.subtract(Duration(minutes: minutes));
        }
      }

      events.add(
        CalendarEventModel(
          id: deviceEvent.eventId ?? const Uuid().v4(), // Use device ID or generate
          title: deviceEvent.title ?? 'Untitled Event',
          description: deviceEvent.description ?? '',
          start: deviceEvent.start ?? DateTime.now(), // Provide default
          end: deviceEvent.end ?? (deviceEvent.start ?? DateTime.now()).add(const Duration(hours: 1)), // Provide default
          calendarId: calendar.id, // Link to our internal calendar ID
          wholeDay: deviceEvent.allDay ?? false,
          reminder: reminderTime, // Use extracted reminder time
          // Use colorValue from parent CalendarModel
          colorValue: calendar.colorValue,
          // Assume events from device calendar are not read-only by default in our app
          // unless the source calendar itself was marked read-only (which we don't store directly)
          isExternalReadOnly: false,
          userId: calendar.userId,
        ),
      );
    }

    return events;
  }
}
