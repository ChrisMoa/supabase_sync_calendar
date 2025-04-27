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
        print('No calendar permissions, requesting...');
        permissionsGranted = await _deviceCalendarPlugin.requestPermissions();

        if (permissionsGranted.data == null ||
            permissionsGranted.data == false) {
          print('Calendar permissions denied by user');
          throw Exception(
              'Calendar access denied. Please enable calendar permissions in your device settings.');
        }
      }

      // Retrieve calendars
      final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();

      if (calendarsResult.isSuccess && calendarsResult.data != null) {
        final calendars = calendarsResult.data!;
        // Debug each calendar for troubleshooting
        for (int i = 0; i < calendars.length; i++) {
          final calendar = calendars[i];
          print(
              "Device calendar $i: id=${calendar.id}, name=${calendar.name}, color=${calendar.color}");
        }
        return calendars;
      } else {
        print('Failed to get calendars: ${calendarsResult.errors.toString()}');
        throw Exception(
            'Failed to retrieve device calendars: ${calendarsResult.errors.toString()}');
      }
    } catch (e) {
      print('Error getting device calendars: $e');
      throw Exception('Failed to access device calendars: $e');
    }
  }

  // Convert device calendars to CalendarModel
  List<CalendarModel> convertToCalendarModels(
      List<Calendar> deviceCalendars, String userId) {
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
      final Color color = deviceCalendar.color != null
          ? Color(deviceCalendar.color!)
          : defaultColors[i % defaultColors.length];

      calendars.add(CalendarModel(
        id: _uuid.v4(),
        name: deviceCalendar.name ?? 'Unknown Calendar',
        color: color,
        userId: userId,
        type: CalendarType.device,
        deviceCalendarId: deviceCalendar.id,
      ));
    }

    return calendars;
  }

  // Sync events from a device calendar
  Future<List<CalendarEventModel>> syncDeviceCalendar(CalendarModel calendar,
      {DateTime? startDate, DateTime? endDate}) async {
    if (calendar.type != CalendarType.device ||
        calendar.deviceCalendarId == null) {
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
  List<CalendarEventModel> _convertDeviceEvents(
      List<Event> deviceEvents, CalendarModel calendar) {
    final events = <CalendarEventModel>[];

    for (final deviceEvent in deviceEvents) {
      // Skip events with missing required data
      if (deviceEvent.start == null || deviceEvent.end == null) continue;

      events.add(CalendarEventModel(
        id: deviceEvent.eventId ?? _uuid.v4(),
        title: deviceEvent.title ?? 'Untitled Event',
        description: deviceEvent.description ?? '',
        start: deviceEvent.start!,
        end: deviceEvent.end!,
        color: calendar.color,
        userId: calendar.userId,
        calendarId: calendar.id,
        wholeDay: deviceEvent.allDay ?? false,
        isExternalReadOnly: true, // Mark as read-only since it's from device
      ));
    }

    return events;
  }
}
