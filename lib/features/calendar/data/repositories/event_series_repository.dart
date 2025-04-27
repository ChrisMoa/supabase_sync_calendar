import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/models/calendar_event_model.dart';
import '../../../../core/models/calendar_event_series_model.dart';
import '../../../../core/utils/supabase_utils.dart';

class EventSeriesRepository {
  final SupabaseClient supabaseClient;
  final String userId;
  final Uuid _uuid = const Uuid();

  EventSeriesRepository({
    required this.supabaseClient,
    required this.userId,
  });

  // Create a new event series
  Future<CalendarEventSeriesModel> createSeries(
      CalendarEventSeriesModel series) async {
    try {
      final String seriesId = series.id.isEmpty ? _uuid.v4() : series.id;
      final newSeries = series.copyWith(id: seriesId, userId: userId);

      await supabaseClient
          .from(SupabaseUtils.seriesTable)
          .insert(newSeries.toJson());

      return newSeries;
    } catch (e) {
      throw Exception('Failed to create event series: $e');
    }
  }

  // Get an event series by ID
  Future<CalendarEventSeriesModel> getSeriesById(String seriesId) async {
    try {
      final response = await supabaseClient
          .from(SupabaseUtils.seriesTable)
          .select()
          .eq(SupabaseUtils.colId, seriesId)
          .eq(SupabaseUtils.colUserId, userId)
          .single();

      return CalendarEventSeriesModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to get event series: $e');
    }
  }

  // Update an event series
  Future<CalendarEventSeriesModel> updateSeries(
      CalendarEventSeriesModel series) async {
    try {
      await supabaseClient
          .from(SupabaseUtils.seriesTable)
          .update(series.toJson())
          .eq(SupabaseUtils.colId, series.id)
          .eq(SupabaseUtils.colUserId, userId);

      return series;
    } catch (e) {
      throw Exception('Failed to update event series: $e');
    }
  }

  // Delete an event series
  Future<void> deleteSeries(String seriesId, {bool deleteEvents = true}) async {
    try {
      // Start a transaction
      if (deleteEvents) {
        // Delete all events in the series
        await supabaseClient
            .from(SupabaseUtils.eventsTable)
            .delete()
            .eq(SupabaseUtils.colSeriesId, seriesId)
            .eq(SupabaseUtils.colUserId, userId);
      } else {
        // Just remove the series_id from events (keep events)
        await supabaseClient
            .from(SupabaseUtils.eventsTable)
            .update({SupabaseUtils.colSeriesId: null})
            .eq(SupabaseUtils.colSeriesId, seriesId)
            .eq(SupabaseUtils.colUserId, userId);
      }

      // Delete the series itself
      await supabaseClient
          .from(SupabaseUtils.seriesTable)
          .delete()
          .eq(SupabaseUtils.colId, seriesId)
          .eq(SupabaseUtils.colUserId, userId);
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
        return [templateEvent.copyWith(seriesId: series.id)];
      }

      // Use template event as the first occurrence
      events.add(templateEvent.copyWith(seriesId: series.id));

      // Calculate event duration to maintain it for all occurrences
      final Duration eventDuration =
          templateEvent.end.difference(templateEvent.start);

      // Set up range constraints
      final DateTime actualRangeStart = rangeStart ?? templateEvent.start;
      final DateTime actualRangeEnd = rangeEnd ??
          (series.endType == SeriesEndType.onDate
              ? series.endDate!
              : actualRangeStart
                  .add(const Duration(days: 365))); // Default to 1 year

      DateTime nextStart = _getNextOccurrenceStart(
        templateEvent.start,
        series.repeatType,
        series.repeatInterval,
        series.repeatDaysOfWeek,
      );

      int occurrenceCount = 1; // Count the template event as first occurrence
      final int maxOccurrences =
          series.endType == SeriesEndType.afterOccurrences
              ? series.occurrences!
              : 1000; // Reasonable limit for infinite series

      // Generate occurrences
      while (nextStart.isBefore(actualRangeEnd) &&
          occurrenceCount < maxOccurrences &&
          !(series.endType == SeriesEndType.onDate &&
              nextStart.isAfter(series.endDate!))) {
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

        // Calculate next occurrence
        nextStart = _getNextOccurrenceStart(
          nextStart,
          series.repeatType,
          series.repeatInterval,
          series.repeatDaysOfWeek,
        );

        occurrenceCount++;
      }

      return events;
    } catch (e) {
      throw Exception('Failed to generate series events: $e');
    }
  }

  // Helper method to calculate next occurrence based on repeat rules
  DateTime _getNextOccurrenceStart(
    DateTime currentStart,
    SeriesRepeatType repeatType,
    int repeatInterval,
    List<int> repeatDaysOfWeek,
  ) {
    DateTime nextDate;

    switch (repeatType) {
      case SeriesRepeatType.none:
        return currentStart; // Should not happen

      case SeriesRepeatType.daily:
        nextDate = currentStart.add(Duration(days: repeatInterval));
        break;

      case SeriesRepeatType.weekly:
        if (repeatDaysOfWeek.isEmpty) {
          // Simple case: just add weeks
          nextDate = currentStart.add(Duration(days: 7 * repeatInterval));
        } else {
          // Complex case: find next day of week in the list
          // 1-7 where 1 is Monday (ISO week format)
          int currentDayOfWeek = currentStart.weekday;
          int nextDayIndex = -1;

          // Find the next day of week in the list
          for (int i = 0; i < repeatDaysOfWeek.length; i++) {
            if (repeatDaysOfWeek[i] > currentDayOfWeek) {
              nextDayIndex = i;
              break;
            }
          }

          if (nextDayIndex >= 0) {
            // Found a day of week later in the current week
            int daysToAdd = repeatDaysOfWeek[nextDayIndex] - currentDayOfWeek;
            nextDate = currentStart.add(Duration(days: daysToAdd));
          } else {
            // No days later in this week, move to first day in next week
            int daysToNextWeek = 8 - currentDayOfWeek + repeatDaysOfWeek[0];
            nextDate = currentStart
                .add(Duration(days: daysToNextWeek + (repeatInterval - 1) * 7));
          }
        }
        break;

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

        nextDate = DateTime(
          year,
          month,
          day,
          currentStart.hour,
          currentStart.minute,
          currentStart.second,
        );
        break;

      case SeriesRepeatType.yearly:
        // Simply add years
        nextDate = DateTime(
          currentStart.year + repeatInterval,
          currentStart.month,
          currentStart.day,
          currentStart.hour,
          currentStart.minute,
          currentStart.second,
        );
        break;
    }

    return nextDate;
  }
}
