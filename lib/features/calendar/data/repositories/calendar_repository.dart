import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_sync_calendar/core/services/hive_service.dart';
import 'package:supabase_sync_calendar/core/services/sync_service.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/models/calendar_event_model.dart';
import '../../../../core/utils/supabase_utils.dart';

class CalendarRepository {
  final SupabaseClient supabaseClient;
  final String userId;
  final Uuid _uuid = const Uuid();
  late final SyncService _syncService;

  CalendarRepository({
    required this.supabaseClient,
    required this.userId,
  }) {
    _syncService = SyncService(
      supabaseClient: supabaseClient,
      userId: userId,
    );

    // Start auto-sync
    _syncService.startAutoSync();
  }

  Future<List<CalendarEventModel>> getEvents({String? calendarId}) async {
    try {
      // Get events from local database first
      List<CalendarEventModel> events;
      if (calendarId != null) {
        events = HiveService.getEventsByCalendar(calendarId);
      } else {
        events = HiveService.getAllEvents();
      }

      // Filter for this user's events
      events = events.where((e) => e.userId == userId).toList();

      // If no events found locally and we have an internet connection, try fetching from Supabase
      if (events.isEmpty) {
        debugPrint('No events found in local storage. Trying to fetch from Supabase...');
        try {
          final response = await supabaseClient.from(SupabaseUtils.eventsTable).select().eq(SupabaseUtils.colUserId, userId);

          if (calendarId != null) {
            response.where((item) => item[SupabaseUtils.colCalendarId] == calendarId);
          }

          final supabaseEvents = (response as List).map((json) => CalendarEventModel.fromJson(json)).toList();

          // Store events in Hive for offline access
          for (final event in supabaseEvents) {
            await HiveService.saveEvent(event);
          }

          debugPrint('Fetched ${supabaseEvents.length} events from Supabase');
          return supabaseEvents;
        } catch (e) {
          debugPrint('Error fetching events from Supabase: $e');
          // If there's an error fetching from Supabase, return the empty local list
        }
      }

      return events;
    } catch (e) {
      debugPrint('Error fetching events: $e');
      throw Exception('Failed to load events: $e');
    }
  }

  // Create a new event
  Future<CalendarEventModel> createEvent(CalendarEventModel event) async {
    try {
      debugPrint('Creating new event with title: ${event.title}');
      final eventId = _uuid.v4();
      final newEvent = event.copyWith(id: eventId, userId: userId);

      // First, check if the table exists
      try {
        // Attempt to create the table if it doesn't exist
        debugPrint('Checking/creating calendar_events table');
        await supabaseClient.rpc('ensure_calendar_events_table').catchError((e) {
          debugPrint('Could not create table via RPC: $e');
          // This is expected if the RPC doesn't exist, just continue
        });

        // Insert the event data
        debugPrint('Inserting event with ID: ${newEvent.id}');
        final result = await supabaseClient.from(SupabaseUtils.eventsTable).insert(newEvent.toJson()).select();

        debugPrint('Event created successfully');

        // If we get here, the operation succeeded
        return newEvent;
      } catch (e) {
        // If we get a specific error about table not existing
        if (e.toString().contains('does not exist')) {
          debugPrint('Table does not exist - need to create it first');
          throw Exception('Table does not exist. Please set up the calendar_events table in Supabase first.');
        }
        rethrow;
      }
    } catch (e) {
      debugPrint('Error creating event: $e');
      throw Exception('Failed to create event: $e');
    }
  }

  // Update an existing event
  Future<CalendarEventModel> updateEvent(CalendarEventModel event) async {
    try {
      await supabaseClient.from(SupabaseUtils.eventsTable).update(event.toJson()).eq(SupabaseUtils.colId, event.id).eq(SupabaseUtils.colUserId, userId);

      return event;
    } catch (e) {
      throw Exception('Failed to update event: $e');
    }
  }

  // Delete an event
  Future<void> deleteEvent(String eventId) async {
    try {
      await supabaseClient.from(SupabaseUtils.eventsTable).delete().eq(SupabaseUtils.colId, eventId).eq(SupabaseUtils.colUserId, userId);
    } catch (e) {
      throw Exception('Failed to delete event: $e');
    }
  }
}
