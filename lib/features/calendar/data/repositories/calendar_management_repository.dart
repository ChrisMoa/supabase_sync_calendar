import 'dart:ui';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/models/calendar_model.dart';
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
      final response = await supabaseClient
          .from(SupabaseUtils.calendarsTable)
          .select()
          .eq(SupabaseUtils.colUserId, userId);

      return (response as List)
          .map((calendarJson) => CalendarModel.fromJson(calendarJson))
          .toList();
    } catch (e) {
      if (e.toString().contains('does not exist')) {
        return [];
      }
      throw Exception('Failed to load calendars: $e');
    }
  }

  // Create a new calendar
  Future<CalendarModel> createCalendar(CalendarModel calendar) async {
    try {
      final calendarId = calendar.id.isEmpty ? _uuid.v4() : calendar.id;
      final newCalendar = calendar.copyWith(id: calendarId, userId: userId);

      await supabaseClient
          .from(SupabaseUtils.calendarsTable)
          .insert(newCalendar.toJson());

      return newCalendar;
    } catch (e) {
      throw Exception('Failed to create calendar: $e');
    }
  }

  // Update an existing calendar
  Future<CalendarModel> updateCalendar(CalendarModel calendar) async {
    try {
      await supabaseClient
          .from(SupabaseUtils.calendarsTable)
          .update(calendar.toJson())
          .eq(SupabaseUtils.colId, calendar.id)
          .eq(SupabaseUtils.colUserId, userId);

      return calendar;
    } catch (e) {
      throw Exception('Failed to update calendar: $e');
    }
  }

  // Delete a calendar
  Future<void> deleteCalendar(String calendarId) async {
    try {
      await supabaseClient
          .from(SupabaseUtils.calendarsTable)
          .delete()
          .eq(SupabaseUtils.colId, calendarId)
          .eq(SupabaseUtils.colUserId, userId);
    } catch (e) {
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
          color: const Color(0xFF3F51B5), // Fix this line - add const
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
      throw Exception('Failed to ensure default calendar: $e');
    }
  }
}
