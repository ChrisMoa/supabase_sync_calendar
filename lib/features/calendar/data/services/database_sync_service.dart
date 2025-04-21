import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/models/calendar_event_model.dart';
import '../../../../core/utils/supabase_utils.dart';

class DatabaseSyncService {
  final SupabaseClient supabaseClient;
  final String userId;
  StreamSubscription? _eventsSubscription;
  RealtimeChannel? _eventsChannel;

  // Callbacks for handling real-time events
  final Function(CalendarEventModel)? onEventAdded;
  final Function(CalendarEventModel)? onEventUpdated;
  final Function(String)? onEventDeleted;

  DatabaseSyncService({
    required this.supabaseClient,
    required this.userId,
    this.onEventAdded,
    this.onEventUpdated,
    this.onEventDeleted,
  });

  void startSync() {
    // Create a single channel for all event types
    _eventsChannel = supabaseClient
        .channel('public:calendar_events')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: SupabaseUtils.eventsTable,
          callback: (payload) {
            _handleInsertEvent(payload);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: SupabaseUtils.eventsTable,
          callback: (payload) {
            _handleUpdateEvent(payload);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: SupabaseUtils.eventsTable,
          callback: (payload) {
            _handleDeleteEvent(payload);
          },
        )
        .subscribe();
  }

  void _handleInsertEvent(PostgresChangePayload payload) {
    try {
      final record = payload.newRecord;
      if (record[SupabaseUtils.colUserId] == userId) {
        final newEvent = CalendarEventModel.fromJson(record);
        if (onEventAdded != null) {
          onEventAdded!(newEvent);
        }
      }
    } catch (e) {
      debugPrint('Error handling insert event: $e');
    }
  }

  void _handleUpdateEvent(PostgresChangePayload payload) {
    try {
      final record = payload.newRecord;
      if (record[SupabaseUtils.colUserId] == userId) {
        final updatedEvent = CalendarEventModel.fromJson(record);
        if (onEventUpdated != null) {
          onEventUpdated!(updatedEvent);
        }
      }
    } catch (e) {
      debugPrint('Error handling update event: $e');
    }
  }

  void _handleDeleteEvent(PostgresChangePayload payload) {
    try {
      final record = payload.oldRecord;
      final deletedId = record[SupabaseUtils.colId] as String;
      final deletedUserId = record[SupabaseUtils.colUserId] as String;

      if (deletedUserId == userId && onEventDeleted != null) {
        onEventDeleted!(deletedId);
      }
    } catch (e) {
      debugPrint('Error handling delete event: $e');
    }
  }

  void dispose() {
    _eventsSubscription?.cancel();
    supabaseClient.removeChannel(_eventsChannel!);
  }
}
