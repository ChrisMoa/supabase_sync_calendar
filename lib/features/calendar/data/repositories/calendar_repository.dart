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
      // First try to get events from local Hive storage
      debugPrint('📋 LOCAL DB: Attempting to load events from Hive local storage');
      List<CalendarEventModel> allEvents = HiveService.getAllEvents();
      debugPrint('📋 LOCAL DB: Found ${allEvents.length} events in local storage (before user filtering)');

      // Filter for this user's events
      allEvents = allEvents.where((e) => e.userId == userId).toList();
      debugPrint('📋 LOCAL DB: Found ${allEvents.length} events for user $userId in local storage');

      List<CalendarEventModel> events;

      if (calendarId == null) {
        // If no calendar ID is provided, return all events
        debugPrint('📋 LOCAL DB: Getting all events from all calendars');
        events = allEvents;
      } else {
        // If a calendar ID is provided, filter for that calendar
        debugPrint('📋 LOCAL DB: Getting events for specific calendar: $calendarId');
        events = allEvents.where((e) => e.calendarId == calendarId).toList();
        debugPrint('📋 LOCAL DB: Found ${events.length} events for calendar $calendarId');
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

          events = (response as List).map((json) => CalendarEventModel.fromJson(json)).toList();
          debugPrint('🌐 SUPABASE: Converted ${events.length} events from JSON');

          // Store events in Hive for offline access
          debugPrint('📋 LOCAL DB: Saving ${events.length} events to local storage');
          for (final event in events) {
            await HiveService.saveEvent(event);
          }

          debugPrint('🌐 SUPABASE: Fetched ${events.length} events from Supabase');
        } catch (e) {
          debugPrint('❌ ERROR: Failed to fetch events from Supabase: $e');
          if (e.toString().contains('does not exist')) {
            // Table doesn't exist yet, return empty list
            return [];
          }
          // For other errors, rethrow to be handled by caller
          rethrow;
        }
      } else if (events.isEmpty && isOfflineMode) {
        debugPrint('🔌 OFFLINE: No events found in local storage. Cannot fetch from Supabase in offline mode.');
      } else if (events.isEmpty) {
        debugPrint('ℹ️ INFO: No events found in local storage for user $userId. Skipping Supabase fetch as per configuration.');
      } else {
        debugPrint('✅ SUCCESS: Using ${events.length} events from local storage');
      }

      return events;
    } catch (e) {
      debugPrint('Failed to load events: $e');
      throw Exception('Failed to load events: $e');
    }
  }

  // Create a new event
  Future<CalendarEventModel> createEvent(CalendarEventModel event) async {
    try {
      final eventId = event.id.isEmpty ? _uuid.v4() : event.id;
      final newEvent = event.copyWith(id: eventId, userId: userId);

      // Save to Hive for local storage
      await HiveService.saveEvent(newEvent);

      // Only try to save to Supabase if not in offline mode
      if (!isOfflineMode) {
        try {
          // Try to save to Supabase if online
          await supabaseClient.from(SupabaseUtils.eventsTable).insert(newEvent.toJson());
          debugPrint('🌐 SUPABASE: Event saved to Supabase');
        } catch (e) {
          // If saving to Supabase fails, the event is still in Hive
          // and will be synced later by the SyncService
          debugPrint('⚠️ WARNING: Event saved locally but not to Supabase: $e');
        }
      } else {
        debugPrint('🔌 OFFLINE: Event saved to local storage only');
      }

      return newEvent;
    } catch (e) {
      debugPrint('Failed to create event: $e');
      throw Exception('Failed to create event: $e');
    }
  }

  // Update an existing event
  Future<CalendarEventModel> updateEvent(CalendarEventModel event) async {
    try {
      // Update in Hive for local storage
      await HiveService.saveEvent(event);

      // Only try to update in Supabase if not in offline mode
      if (!isOfflineMode) {
        try {
          // Try to update in Supabase if online
          await supabaseClient.from(SupabaseUtils.eventsTable).update(event.toJson()).eq(SupabaseUtils.colId, event.id);
          debugPrint('🌐 SUPABASE: Event updated in Supabase');
        } catch (e) {
          // If updating in Supabase fails, the event is still updated in Hive
          // and will be synced later by the SyncService
          debugPrint('⚠️ WARNING: Event updated locally but not in Supabase: $e');
        }
      } else {
        debugPrint('🔌 OFFLINE: Event updated in local storage only');
      }

      return event;
    } catch (e) {
      debugPrint('Failed to update event: $e');
      throw Exception('Failed to update event: $e');
    }
  }

  // Delete an event
  Future<void> deleteEvent(String eventId) async {
    try {
      // Delete from Hive for local storage
      await HiveService.deleteEvent(eventId);

      // Only try to delete from Supabase if not in offline mode
      if (!isOfflineMode) {
        try {
          // Try to delete from Supabase if online
          await supabaseClient.from(SupabaseUtils.eventsTable).delete().eq(SupabaseUtils.colId, eventId);
          debugPrint('🌐 SUPABASE: Event deleted from Supabase');
        } catch (e) {
          // If deleting from Supabase fails, it's still deleted from Hive
          // and will be synced later by the SyncService
          debugPrint('⚠️ WARNING: Event deleted locally but not from Supabase: $e');
        }
      } else {
        debugPrint('🔌 OFFLINE: Event deleted from local storage only');
      }
    } catch (e) {
      debugPrint('Failed to delete event: $e');
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
