import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/models/calendar_model.dart';
import '../../../../core/services/hive_service.dart';
import '../../../../core/utils/supabase_utils.dart';

class CalendarManagementRepository {
  final SupabaseClient supabaseClient;
  final String userId;
  final Uuid _uuid = const Uuid();

  CalendarManagementRepository({
    required this.supabaseClient,
    required this.userId,
  });

  // Get all calendars for the current user
  Future<List<CalendarModel>> getCalendars() async {
    try {
      // First try to get calendars from local Hive storage
      List<CalendarModel> calendars = HiveService.getAllCalendars();

      // Filter for this user's calendars
      calendars = calendars.where((c) => c.userId == userId).toList();

      // If no calendars in Hive, try to fetch from Supabase
      if (calendars.isEmpty) {
        debugPrint('No calendars found in local storage. Trying to fetch from Supabase...');
        try {
          final response = await supabaseClient.from(SupabaseUtils.calendarsTable).select().eq(SupabaseUtils.colUserId, userId);

          calendars = (response as List).map((json) => CalendarModel.fromJson(json)).toList();

          // Store calendars in Hive for offline access
          for (final calendar in calendars) {
            await HiveService.saveCalendar(calendar);
          }

          debugPrint('Fetched ${calendars.length} calendars from Supabase');
        } catch (e) {
          debugPrint('Failed to fetch calendars from Supabase: $e');
          if (e.toString().contains('does not exist')) {
            // Table doesn't exist yet, return empty list
            return [];
          }
          // For other errors, rethrow to be handled by caller
          rethrow;
        }
      }

      return calendars;
    } catch (e) {
      debugPrint('Failed to load calendars: $e');
      throw Exception('Failed to load calendars: $e');
    }
  }

  // Create a new calendar
  Future<CalendarModel> createCalendar(CalendarModel calendar) async {
    try {
      final calendarId = calendar.id.isEmpty ? _uuid.v4() : calendar.id;
      final newCalendar = calendar.copyWith(id: calendarId, userId: userId);

      // Save to Hive for local storage
      await HiveService.saveCalendar(newCalendar);

      try {
        // Try to save to Supabase if online
        await supabaseClient.from(SupabaseUtils.calendarsTable).insert(newCalendar.toJson());
        debugPrint('Calendar saved to Supabase');
      } catch (e) {
        // If saving to Supabase fails, the calendar is still in Hive
        // and will be synced later by the SyncService
        debugPrint('Calendar saved locally but not to Supabase: $e');
      }

      return newCalendar;
    } catch (e) {
      debugPrint('Failed to create calendar: $e');
      throw Exception('Failed to create calendar: $e');
    }
  }

  // Update an existing calendar
  Future<CalendarModel> updateCalendar(CalendarModel calendar) async {
    try {
      // First update in Hive
      await HiveService.saveCalendar(calendar);

      try {
        // Then try to update in Supabase
        await supabaseClient.from(SupabaseUtils.calendarsTable).update(calendar.toJson()).eq(SupabaseUtils.colId, calendar.id).eq(SupabaseUtils.colUserId, userId);
        debugPrint('Calendar updated in Supabase');
      } catch (e) {
        // If updating in Supabase fails, it's still updated in Hive
        // and will be synced later by the SyncService
        debugPrint('Calendar updated locally but not in Supabase: $e');
      }

      return calendar;
    } catch (e) {
      debugPrint('Failed to update calendar: $e');
      throw Exception('Failed to update calendar: $e');
    }
  }

  // Delete a calendar
  Future<void> deleteCalendar(String calendarId) async {
    try {
      // First delete from Hive
      await HiveService.deleteCalendar(calendarId);

      try {
        // Then try to delete from Supabase
        await supabaseClient.from(SupabaseUtils.calendarsTable).delete().eq(SupabaseUtils.colId, calendarId).eq(SupabaseUtils.colUserId, userId);
        debugPrint('Calendar deleted from Supabase');
      } catch (e) {
        // If deleting from Supabase fails, it's still marked for deletion in Hive
        // and will be synced later by the SyncService
        debugPrint('Calendar deleted locally but not from Supabase: $e');
      }
    } catch (e) {
      debugPrint('Failed to delete calendar: $e');
      throw Exception('Failed to delete calendar: $e');
    }
  }

  // Create default calendar if none exists
  Future<CalendarModel> ensureDefaultCalendar() async {
    try {
      final calendars = await getCalendars();

      // If there are no calendars, create a default one
      if (calendars.isEmpty) {
        final defaultCalendar = CalendarModel(
          id: _uuid.v4(),
          name: 'Default Calendar',
          colorValue: const Color(0xFF3F51B5).value,
          userId: userId,
          type: CalendarType.local,
          isDefault: true,
        );

        return await createCalendar(defaultCalendar);
      }

      // If there's no default calendar, set the first one as default
      final defaultCalendars = calendars.where((c) => c.isDefault).toList();
      if (defaultCalendars.isEmpty && calendars.isNotEmpty) {
        final firstCalendar = calendars.first.copyWith(isDefault: true);
        return await updateCalendar(firstCalendar);
      }

      // Return the existing default calendar
      return defaultCalendars.first;
    } catch (e) {
      debugPrint('Failed to ensure default calendar: $e');
      throw Exception('Failed to ensure default calendar: $e');
    }
  }
}
