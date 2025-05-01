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
  SyncService? _syncService;
  final bool isOfflineMode;

  CalendarRepository({
    required this.supabaseClient,
    required this.userId,
    this.isOfflineMode = false,
  }) {
    // Only initialize sync service if not in offline mode
    if (!isOfflineMode) {
      debugPrint('🌐 SUPABASE: Created CalendarRepository with client');
      _syncService = SyncService(
        supabaseClient: supabaseClient,
        userId: userId,
      );

      // Start auto-sync only in online mode
      debugPrint('🌐 SUPABASE: Starting auto-sync service');
      _syncService!.startAutoSync();
    } else {
      debugPrint('🔌 OFFLINE: Created CalendarRepository in offline mode - no sync service');
    }
  }

  Future<List<CalendarEventModel>> getEvents({String? calendarId, bool fetchFromSupabaseIfEmpty = false}) async {
    try {
      // Get events from local database first
      debugPrint('📋 LOCAL DB: Attempting to load events from Hive local storage');
      List<CalendarEventModel> events;

      // First get all events to check calendar IDs
      List<CalendarEventModel> allEvents = HiveService.getAllEvents();
      debugPrint('📋 HIVE: getAllEvents() - Found ${allEvents.length} events in box');

      // Print unique calendar IDs for debugging
      _printUniqueCalendarIds(allEvents);

      // Check if there are any events with the requested calendar ID
      bool hasEventsWithRequestedCalendar = false;
      if (calendarId != null) {
        hasEventsWithRequestedCalendar = allEvents.any((e) => e.calendarId == calendarId);
        debugPrint('📋 CALENDAR CHECK: Has events with requested calendarId=$calendarId: $hasEventsWithRequestedCalendar');
      }

      if (calendarId != null && hasEventsWithRequestedCalendar) {
        // If there are events with this calendar ID, filter for them
        debugPrint('📋 LOCAL DB: Getting events for specific calendar: $calendarId');
        events = HiveService.getEventsByCalendar(calendarId);
      } else if (calendarId != null && !hasEventsWithRequestedCalendar && !fetchFromSupabaseIfEmpty) {
        // In offline mode, if the selected calendar has no events, try to be smart and return events from the most common calendar
        debugPrint('📋 LOCAL DB: No events found for calendar $calendarId, using all events instead');

        // Count events by calendar
        Map<String, int> calendarCounts = {};
        for (final event in allEvents) {
          calendarCounts[event.calendarId] = (calendarCounts[event.calendarId] ?? 0) + 1;
        }

        // Find most common calendar ID
        String? mostCommonCalendarId;
        int maxCount = 0;
        calendarCounts.forEach((calId, count) {
          if (count > maxCount) {
            maxCount = count;
            mostCommonCalendarId = calId;
          }
        });

        if (mostCommonCalendarId != null) {
          debugPrint('📋 SMART FALLBACK: Using most common calendar ID: $mostCommonCalendarId with $maxCount events');
          events = HiveService.getEventsByCalendar(mostCommonCalendarId!);
        } else {
          // Fallback to all events
          debugPrint('📋 LOCAL DB: Getting all events from all calendars');
          events = allEvents;
        }
      } else {
        // Get all events
        debugPrint('📋 LOCAL DB: Getting all events from all calendars');
        events = allEvents;
      }

      debugPrint('📋 LOCAL DB: Found ${events.length} events in local storage (before user filtering)');

      // Filter for this user's events
      events = events.where((e) => e.userId == userId).toList();
      debugPrint('📋 LOCAL DB: Found ${events.length} events for user $userId in local storage');

      // More detailed debug of the events after filtering
      if (events.isNotEmpty) {
        debugPrint('📋 SAMPLE EVENT DATA: First event calendarId: ${events[0].calendarId}');
      }

      if (calendarId != null) {
        debugPrint('📋 CALENDAR FILTER CHECK: Looking for events with calendarId=$calendarId');
        final matchingEvents = events.where((e) => e.calendarId == calendarId).toList();
        debugPrint('📋 CALENDAR FILTER CHECK: Found ${matchingEvents.length} events matching the calendarId filter');
      }

      // If no events found locally and fetchFromSupabaseIfEmpty is true and NOT in offline mode, try fetching from Supabase
      if (events.isEmpty && fetchFromSupabaseIfEmpty && !isOfflineMode) {
        debugPrint('🌐 SUPABASE: No events found in local storage. Trying to fetch from Supabase...');
        try {
          debugPrint('🌐 SUPABASE: Querying ${SupabaseUtils.eventsTable} table for user $userId');
          final response = await supabaseClient.from(SupabaseUtils.eventsTable).select().eq(SupabaseUtils.colUserId, userId);
          debugPrint('🌐 SUPABASE: Query completed, processing response');

          if (calendarId != null) {
            response.where((item) => item[SupabaseUtils.colCalendarId] == calendarId);
          }

          final supabaseEvents = (response as List).map((json) => CalendarEventModel.fromJson(json)).toList();
          debugPrint('🌐 SUPABASE: Converted ${supabaseEvents.length} events from JSON');

          // Store events in Hive for offline access
          debugPrint('📋 LOCAL DB: Saving ${supabaseEvents.length} events to local storage');
          for (final event in supabaseEvents) {
            await HiveService.saveEvent(event);
          }

          debugPrint('🌐 SUPABASE: Fetched ${supabaseEvents.length} events from Supabase');
          return supabaseEvents;
        } catch (e) {
          debugPrint('❌ ERROR: Error fetching events from Supabase: $e');
          // If there's an error fetching from Supabase, return the empty local list
        }
      } else if (events.isEmpty && isOfflineMode) {
        debugPrint('🔌 OFFLINE: No events found in local storage, and in offline mode so can\'t fetch from Supabase');
      } else if (events.isEmpty) {
        debugPrint('ℹ️ INFO: No events found in local storage for user $userId. Skipping Supabase fetch as per configuration.');
      } else {
        debugPrint('✅ SUCCESS: Using ${events.length} events from local storage');
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

      // Always save to Hive storage for offline access
      await HiveService.saveEvent(newEvent);

      // Only save to Supabase if not in offline mode
      if (!isOfflineMode) {
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
          debugPrint('Event created successfully in Supabase');
        } catch (e) {
          // If we get a specific error about table not existing
          if (e.toString().contains('does not exist')) {
            debugPrint('Table does not exist - need to create it first');
            throw Exception('Table does not exist. Please set up the calendar_events table in Supabase first.');
          }
          debugPrint('Error saving to Supabase (will continue with local save): $e');
        }
      } else {
        debugPrint('🔌 OFFLINE: Event created in local storage only');
      }

      return newEvent;
    } catch (e) {
      debugPrint('Error creating event: $e');
      throw Exception('Failed to create event: $e');
    }
  }

  // Update an existing event
  Future<CalendarEventModel> updateEvent(CalendarEventModel event) async {
    try {
      // Always update in Hive storage
      await HiveService.saveEvent(event);

      // Only update in Supabase if not in offline mode
      if (!isOfflineMode) {
        await supabaseClient.from(SupabaseUtils.eventsTable).update(event.toJson()).eq(SupabaseUtils.colId, event.id).eq(SupabaseUtils.colUserId, userId);
        debugPrint('Event updated successfully in Supabase');
      } else {
        debugPrint('🔌 OFFLINE: Event updated in local storage only');
      }

      return event;
    } catch (e) {
      throw Exception('Failed to update event: $e');
    }
  }

  // Delete an event
  Future<void> deleteEvent(String eventId) async {
    try {
      // Always delete from Hive storage
      await HiveService.deleteEvent(eventId);

      // Only delete from Supabase if not in offline mode
      if (!isOfflineMode) {
        await supabaseClient.from(SupabaseUtils.eventsTable).delete().eq(SupabaseUtils.colId, eventId).eq(SupabaseUtils.colUserId, userId);
        debugPrint('Event deleted successfully from Supabase');
      } else {
        debugPrint('🔌 OFFLINE: Event deleted from local storage only');
      }
    } catch (e) {
      throw Exception('Failed to delete event: $e');
    }
  }

  // Helper method to print unique calendar IDs for debugging
  void _printUniqueCalendarIds(List<CalendarEventModel> events) {
    final Set<String> uniqueCalendarIds = events.map((e) => e.calendarId).toSet();
    final calendarIdsList = uniqueCalendarIds.toList()..sort();
    debugPrint('📋 DIAGNOSTIC: Found ${uniqueCalendarIds.length} unique calendar IDs in events: ${calendarIdsList.join(', ')}');
  }
}
