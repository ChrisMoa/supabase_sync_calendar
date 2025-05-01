import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/models/calendar_event_model.dart';
import '../../../../core/models/calendar_event_series_model.dart';
import '../../../../core/utils/supabase_utils.dart';
import '../../../../core/services/hive_service.dart';

class EventSeriesRepository {
  final SupabaseClient supabaseClient;
  final String userId;
  final Uuid _uuid = const Uuid();
  final bool isOfflineMode;

  EventSeriesRepository({
    required this.supabaseClient,
    required this.userId,
    this.isOfflineMode = false,
  });

  // Create a new event series
  Future<CalendarEventSeriesModel> createSeries(CalendarEventSeriesModel series) async {
    try {
      final String seriesId = series.id.isEmpty ? _uuid.v4() : series.id;
      final newSeries = series.copyWith(id: seriesId, userId: userId);

      if (!isOfflineMode) {
        await supabaseClient.from(SupabaseUtils.seriesTable).insert(newSeries.toJson());
      }

      // Always save to local storage
      await HiveService.saveEventSeries(newSeries);

      return newSeries;
    } catch (e) {
      throw Exception('Failed to create event series: $e');
    }
  }

  // Get an event series by ID
  Future<CalendarEventSeriesModel> getSeriesById(String seriesId) async {
    try {
      if (isOfflineMode) {
        final seriesData = HiveService.getEventSeries(seriesId);
        if (seriesData != null) {
          return seriesData;
        }
        throw Exception('Event series not found in local storage');
      }

      final response = await supabaseClient.from(SupabaseUtils.seriesTable).select().eq(SupabaseUtils.colId, seriesId).eq(SupabaseUtils.colUserId, userId).single();

      final series = CalendarEventSeriesModel.fromJson(response);

      // Save to local storage for offline access
      await HiveService.saveEventSeries(series);

      return series;
    } catch (e) {
      throw Exception('Failed to get event series: $e');
    }
  }

  // Update an event series
  Future<CalendarEventSeriesModel> updateSeries(CalendarEventSeriesModel series) async {
    try {
      if (!isOfflineMode) {
        await supabaseClient.from(SupabaseUtils.seriesTable).update(series.toJson()).eq(SupabaseUtils.colId, series.id).eq(SupabaseUtils.colUserId, userId);
      }

      // Always update in local storage
      await HiveService.saveEventSeries(series);

      return series;
    } catch (e) {
      throw Exception('Failed to update event series: $e');
    }
  }

  // Delete an event series
  Future<void> deleteSeries(String seriesId, {bool deleteEvents = true}) async {
    try {
      if (!isOfflineMode) {
        // Start a transaction
        if (deleteEvents) {
          // Delete all events in the series
          await supabaseClient.from(SupabaseUtils.eventsTable).delete().eq(SupabaseUtils.colSeriesId, seriesId).eq(SupabaseUtils.colUserId, userId);
        } else {
          // Just remove the series_id from events (keep events)
          await supabaseClient.from(SupabaseUtils.eventsTable).update({SupabaseUtils.colSeriesId: null}).eq(SupabaseUtils.colSeriesId, seriesId).eq(SupabaseUtils.colUserId, userId);
        }

        // Delete the series itself
        await supabaseClient.from(SupabaseUtils.seriesTable).delete().eq(SupabaseUtils.colId, seriesId).eq(SupabaseUtils.colUserId, userId);
      }

      // Delete from local storage too
      if (deleteEvents) {
        await HiveService.deleteSeriesEvents(seriesId);
      }
      await HiveService.deleteEventSeries(seriesId);
    } catch (e) {
      throw Exception('Failed to delete event series: $e');
    }
  }

  // Generate recurring events based on series
  Future<List<CalendarEventModel>> generateSeriesEvents(
    CalendarEventSeriesModel series,
    CalendarEventModel templateEvent, {
    DateTime? rangeStart,
    DateTime? rangeEnd,
  }) async {
    try {
      final List<CalendarEventModel> events = [];

      // Skip if series type is none
      if (series.repeatType == SeriesRepeatType.none) {
        // Just update the template event with the series ID
        final updatedTemplate = templateEvent.copyWith(seriesId: series.id);
        events.add(updatedTemplate);
        return events;
      }

      // Update template event with series ID and add it to events
      final updatedTemplate = templateEvent.copyWith(seriesId: series.id);
      events.add(updatedTemplate);

      // Calculate event duration to maintain it for all occurrences
      final Duration eventDuration = templateEvent.end.difference(templateEvent.start);

      // Set up range constraints
      final DateTime actualRangeStart = rangeStart ?? templateEvent.start;
      final DateTime actualRangeEnd = rangeEnd ?? (series.endType == SeriesEndType.onDate ? series.endDate! : actualRangeStart.add(const Duration(days: 365))); // Default to 1 year

      final int templateHour = templateEvent.start.hour;
      final int templateMinute = templateEvent.start.minute;
      final int templateSecond = templateEvent.start.second;
      // Now handle the recurring weeks based on interval
      // Start from the week after the template's week
      DateTime nextWeekStart = _getStartOfWeek(templateEvent.start).add(Duration(days: 7 * series.repeatInterval));

      // For weekly recurrences with specific days
      if (series.repeatType == SeriesRepeatType.weekly && series.repeatDaysOfWeek.isNotEmpty) {
        // Sort days to ensure correct order
        final sortedDays = List<int>.from(series.repeatDaysOfWeek)..sort();

        // Filter out the template's weekday if it's in the list, to avoid duplication
        final templateWeekday = templateEvent.start.weekday;
        final daysToGenerate = sortedDays.where((day) => day != templateWeekday).toList();

        // Generate the initial set of events for the first week
        // (for the selected days other than the template day)
        for (final weekday in daysToGenerate) {
          // Calculate days to add to reach this weekday from the template date
          int daysToAdd = weekday - templateEvent.start.weekday;
          if (daysToAdd <= 0) {
            daysToAdd += 7; // Move to next week if day already passed
          }

          final DateTime eventDate = DateTime(
            nextWeekStart.year,
            nextWeekStart.month,
            nextWeekStart.day + daysToAdd,
            templateHour,
            templateMinute,
            templateSecond,
          );
          final DateTime eventEnd = eventDate.add(eventDuration);

          // Only add if in range
          if (!eventDate.isAfter(actualRangeEnd)) {
            final String eventId = _uuid.v4();
            final CalendarEventModel event = templateEvent.copyWith(
              id: eventId,
              start: eventDate,
              end: eventEnd,
              seriesId: series.id,
            );

            events.add(event);
          }
        }

        int occurrenceCount = 1 + daysToGenerate.length; // Count template + first week events
        final int maxOccurrences = series.endType == SeriesEndType.afterOccurrences ? series.occurrences! : 1000; // Reasonable limit for infinite series

        // Loop through weeks based on the interval
        while (nextWeekStart.isBefore(actualRangeEnd) && occurrenceCount < maxOccurrences && !(series.endType == SeriesEndType.onDate && nextWeekStart.isAfter(series.endDate!))) {
          // For each week, add events for all specified days
          for (final weekday in sortedDays) {
            // Calculate the date for this weekday in this week
            final int daysToAdd = weekday - 1; // 1=Monday, so offset by 1
            final DateTime eventDate = DateTime(
              nextWeekStart.year,
              nextWeekStart.month,
              nextWeekStart.day + daysToAdd,
              templateHour,
              templateMinute,
              templateSecond,
            );

            // Skip if before range start or after range end
            if (eventDate.isBefore(actualRangeStart) || eventDate.isAfter(actualRangeEnd)) {
              continue;
            }

            // Skip if we've reached the end date
            if (series.endType == SeriesEndType.onDate && eventDate.isAfter(series.endDate!)) {
              continue;
            }

            // Create the event
            final DateTime eventEnd = eventDate.add(eventDuration);
            final String eventId = _uuid.v4();
            final CalendarEventModel event = templateEvent.copyWith(
              id: eventId,
              start: eventDate,
              end: eventEnd,
              seriesId: series.id,
            );

            events.add(event);
            occurrenceCount++;

            // Check if we've reached the max occurrences
            if (series.endType == SeriesEndType.afterOccurrences && occurrenceCount >= series.occurrences!) {
              break;
            }
          }

          // Move to the next week based on interval
          nextWeekStart = nextWeekStart.add(Duration(days: 7 * series.repeatInterval));
        }
      } else {
        // Handle other recurrence types (daily, monthly, yearly)
        // We'll start from the next occurrence after the template
        DateTime nextStart = _getNextOccurrenceStart(
          templateEvent.start,
          series.repeatType,
          series.repeatInterval,
          series.repeatDaysOfWeek,
        );

        int occurrenceCount = 1; // Count the template event as first occurrence
        final int maxOccurrences = series.endType == SeriesEndType.afterOccurrences ? series.occurrences! : 1000; // Reasonable limit for infinite series

        // Generate occurrences
        while (nextStart.isBefore(actualRangeEnd) && occurrenceCount < maxOccurrences && !(series.endType == SeriesEndType.onDate && nextStart.isAfter(series.endDate!))) {
          // Create the event with updated dates
          final DateTime nextEnd = nextStart.add(eventDuration);

          final String eventId = _uuid.v4();
          final CalendarEventModel event = templateEvent.copyWith(
            id: eventId,
            start: nextStart,
            end: nextEnd,
            seriesId: series.id,
          );

          events.add(event);
          occurrenceCount++;

          // Calculate next occurrence
          nextStart = _getNextOccurrenceStart(
            nextStart,
            series.repeatType,
            series.repeatInterval,
            series.repeatDaysOfWeek,
          );
        }
      }

      return events;
    } catch (e) {
      throw Exception('Failed to generate series events: $e');
    }
  }

  // Helper method to get the start of the week (Monday) for a given date
  DateTime _getStartOfWeek(DateTime date) {
    // Calculate days to subtract to get to Monday (weekday 1)
    int daysToSubtract = date.weekday - 1;
    return DateTime(date.year, date.month, date.day - daysToSubtract);
  }

  // Helper method to calculate next occurrence based on repeat rules
  DateTime _getNextOccurrenceStart(
    DateTime currentStart,
    SeriesRepeatType repeatType,
    int repeatInterval,
    List<int> repeatDaysOfWeek,
  ) {
    switch (repeatType) {
      case SeriesRepeatType.none:
        return currentStart; // Should not happen

      case SeriesRepeatType.daily:
        // For daily, simply add the interval in days
        return currentStart.add(Duration(days: repeatInterval));

      case SeriesRepeatType.weekly:
        if (repeatDaysOfWeek.isEmpty) {
          // Simple case: just add weeks based on interval
          return currentStart.add(Duration(days: 7 * repeatInterval));
        } else {
          // This case is now handled separately in generateSeriesEvents
          // for better control over weekly recurrence with multiple days
          return currentStart.add(Duration(days: 7 * repeatInterval));
        }

      case SeriesRepeatType.monthly:
        // Add months, keeping the same day of month when possible
        int year = currentStart.year;
        int month = currentStart.month + repeatInterval;
        int day = currentStart.day;

        // Adjust year if month overflows
        while (month > 12) {
          month -= 12;
          year++;
        }

        // Adjust day for month length
        int maxDays = DateTime(year, month + 1, 0).day; // Last day of the month
        if (day > maxDays) {
          day = maxDays;
        }

        return DateTime(
          year,
          month,
          day,
          currentStart.hour,
          currentStart.minute,
          currentStart.second,
        );

      case SeriesRepeatType.yearly:
        // Simply add years
        return DateTime(
          currentStart.year + repeatInterval,
          currentStart.month,
          currentStart.day,
          currentStart.hour,
          currentStart.minute,
          currentStart.second,
        );
    }
  }
}
