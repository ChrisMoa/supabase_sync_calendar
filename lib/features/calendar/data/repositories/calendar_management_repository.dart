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
  final bool isOfflineMode;

  CalendarManagementRepository({
    required this.supabaseClient,
    required this.userId,
    this.isOfflineMode = false,
  }) {
    debugPrint(isOfflineMode ? '🔌 OFFLINE: Created CalendarManagementRepository in offline mode' : '🌐 SUPABASE: Created CalendarManagementRepository with client');
  }

  // Get all calendars for the current user
  Future<List<CalendarModel>> getCalendars({bool fetchFromSupabaseIfEmpty = false}) async {
    try {
      // First try to get calendars from local Hive storage
      debugPrint('📋 LOCAL DB: Attempting to load calendars from Hive local storage');
      List<CalendarModel> calendars = HiveService.getAllCalendars();
      debugPrint('📋 LOCAL DB: Found ${calendars.length} calendars in local storage (before user filtering)');

      // Filter for this user's calendars
      calendars = calendars.where((c) => c.userId == userId).toList();
      debugPrint('📋 LOCAL DB: Found ${calendars.length} calendars for user $userId in local storage');

      // If no calendars for this user in Hive and fetchFromSupabaseIfEmpty is true, and NOT in offline mode, try to fetch from Supabase
      if (calendars.isEmpty && fetchFromSupabaseIfEmpty && !isOfflineMode) {
        debugPrint('🌐 SUPABASE: No calendars found in local storage. Trying to fetch from Supabase...');
        try {
          debugPrint('🌐 SUPABASE: Querying ${SupabaseUtils.calendarsTable} table for user $userId');
          final response = await supabaseClient.from(SupabaseUtils.calendarsTable).select().eq(SupabaseUtils.colUserId, userId);
          debugPrint('🌐 SUPABASE: Query completed, processing response');

          calendars = (response as List).map((json) => CalendarModel.fromJson(json)).toList();
          debugPrint('🌐 SUPABASE: Converted ${calendars.length} calendars from JSON');

          // Store calendars in Hive for offline access
          debugPrint('📋 LOCAL DB: Saving ${calendars.length} calendars to local storage');
          for (final calendar in calendars) {
            await HiveService.saveCalendar(calendar);
          }

          debugPrint('🌐 SUPABASE: Fetched ${calendars.length} calendars from Supabase');
        } catch (e) {
          debugPrint('❌ ERROR: Failed to fetch calendars from Supabase: $e');
          if (e.toString().contains('does not exist')) {
            // Table doesn't exist yet, return empty list
            return [];
          }
          // For other errors, rethrow to be handled by caller
          rethrow;
        }
      } else if (calendars.isEmpty && isOfflineMode) {
        debugPrint('🔌 OFFLINE: No calendars found in local storage. Cannot fetch from Supabase in offline mode.');
      } else if (calendars.isEmpty) {
        debugPrint('ℹ️ INFO: No calendars found in local storage for user $userId. Skipping Supabase fetch as per configuration.');
      } else {
        debugPrint('✅ SUCCESS: Using ${calendars.length} calendars from local storage');
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

      // Only try to save to Supabase if not in offline mode
      if (!isOfflineMode) {
        try {
          // Try to save to Supabase if online
          await supabaseClient.from(SupabaseUtils.calendarsTable).insert(newCalendar.toJson());
          debugPrint('🌐 SUPABASE: Calendar saved to Supabase');
        } catch (e) {
          // If saving to Supabase fails, the calendar is still in Hive
          // and will be synced later by the SyncService
          debugPrint('⚠️ WARNING: Calendar saved locally but not to Supabase: $e');
        }
      } else {
        debugPrint('🔌 OFFLINE: Calendar saved to local storage only');
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

      // Only try to update in Supabase if not in offline mode
      if (!isOfflineMode) {
        try {
          // Then try to update in Supabase
          await supabaseClient.from(SupabaseUtils.calendarsTable).update(calendar.toJson()).eq(SupabaseUtils.colId, calendar.id).eq(SupabaseUtils.colUserId, userId);
          debugPrint('🌐 SUPABASE: Calendar updated in Supabase');
        } catch (e) {
          // If updating in Supabase fails, it's still updated in Hive
          // and will be synced later by the SyncService
          debugPrint('⚠️ WARNING: Calendar updated locally but not in Supabase: $e');
        }
      } else {
        debugPrint('🔌 OFFLINE: Calendar updated in local storage only');
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

      // Only try to delete from Supabase if not in offline mode
      if (!isOfflineMode) {
        try {
          // Then try to delete from Supabase
          await supabaseClient.from(SupabaseUtils.calendarsTable).delete().eq(SupabaseUtils.colId, calendarId).eq(SupabaseUtils.colUserId, userId);
          debugPrint('🌐 SUPABASE: Calendar deleted from Supabase');
        } catch (e) {
          // If deleting from Supabase fails, it's still marked for deletion in Hive
          // and will be synced later by the SyncService
          debugPrint('⚠️ WARNING: Calendar deleted locally but not from Supabase: $e');
        }
      } else {
        debugPrint('🔌 OFFLINE: Calendar deleted from local storage only');
      }
    } catch (e) {
      debugPrint('Failed to delete calendar: $e');
      throw Exception('Failed to delete calendar: $e');
    }
  }

  // Create default calendar if none exists
  Future<CalendarModel> ensureDefaultCalendar({bool fetchFromSupabaseIfEmpty = false}) async {
    try {
      final calendars = await getCalendars(fetchFromSupabaseIfEmpty: fetchFromSupabaseIfEmpty);

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
