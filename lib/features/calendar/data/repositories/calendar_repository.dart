import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/models/calendar_event_model.dart';
import '../../../../core/utils/supabase_utils.dart';

class CalendarRepository {
  final SupabaseClient supabaseClient;
  final String userId;
  final Uuid _uuid = const Uuid();

  CalendarRepository({
    required this.supabaseClient,
    required this.userId,
  });

  Future<List<CalendarEventModel>> getEvents({String? calendarId}) async {
    try {
      print(
          'Fetching events for user: $userId, calendarId filter: ${calendarId ?? "none"}');

      // First check if the table exists
      try {
        var query = supabaseClient
            .from(SupabaseUtils.eventsTable)
            .select()
            .eq(SupabaseUtils.colUserId, userId);

        // Apply calendar filter if provided
        if (calendarId != null) {
          query = query.eq(SupabaseUtils.colCalendarId, calendarId);
        }

        final response = await query;

        print('Successfully fetched ${response.length} events from database');
        // Print sample event data for debugging
        if (response.isNotEmpty) {
          print('Sample event: ${response[0]}');
        } else {
          print('No events found in database');
        }

        return (response as List)
            .map((eventJson) => CalendarEventModel.fromJson(eventJson))
            .toList();
      } catch (e) {
        // Check if the error is about the table not existing
        if (e.toString().contains('does not exist')) {
          print('Events table does not exist, returning empty list');
          return [];
        } else {
          print('Database error: $e');
          rethrow;
        }
      }
    } catch (e) {
      print('Error fetching events: $e');
      throw Exception('Failed to load events: $e');
    }
  }

  // Create a new event
  Future<CalendarEventModel> createEvent(CalendarEventModel event) async {
    try {
      print('Creating new event with title: ${event.title}');
      final eventId = _uuid.v4();
      final newEvent = event.copyWith(id: eventId, userId: userId);

      // First, check if the table exists
      try {
        // Attempt to create the table if it doesn't exist
        print('Checking/creating calendar_events table');
        await supabaseClient
            .rpc('ensure_calendar_events_table')
            .catchError((e) {
          print('Could not create table via RPC: $e');
          // This is expected if the RPC doesn't exist, just continue
        });

        // Insert the event data
        print('Inserting event with ID: ${newEvent.id}');
        final result = await supabaseClient
            .from(SupabaseUtils.eventsTable)
            .insert(newEvent.toJson())
            .select();

        print('Event created successfully');

        // If we get here, the operation succeeded
        return newEvent;
      } catch (e) {
        // If we get a specific error about table not existing
        if (e.toString().contains('does not exist')) {
          print('Table does not exist - need to create it first');
          throw Exception(
              'Table does not exist. Please set up the calendar_events table in Supabase first.');
        }
        rethrow;
      }
    } catch (e) {
      print('Error creating event: $e');
      throw Exception('Failed to create event: $e');
    }
  }

  // Update an existing event
  Future<CalendarEventModel> updateEvent(CalendarEventModel event) async {
    try {
      await supabaseClient
          .from(SupabaseUtils.eventsTable)
          .update(event.toJson())
          .eq(SupabaseUtils.colId, event.id)
          .eq(SupabaseUtils.colUserId, userId);

      return event;
    } catch (e) {
      throw Exception('Failed to update event: $e');
    }
  }

  // Delete an event
  Future<void> deleteEvent(String eventId) async {
    try {
      await supabaseClient
          .from(SupabaseUtils.eventsTable)
          .delete()
          .eq(SupabaseUtils.colId, eventId)
          .eq(SupabaseUtils.colUserId, userId);
    } catch (e) {
      throw Exception('Failed to delete event: $e');
    }
  }
}
