import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_sync_calendar/core/models/calendar_event_model.dart';
import 'package:supabase_sync_calendar/core/models/calendar_model.dart';
import 'package:supabase_sync_calendar/core/models/calendar_event_series_model.dart';
import 'package:supabase_sync_calendar/core/services/hive_service.dart';
import 'package:supabase_sync_calendar/core/services/network_service.dart';
import 'package:supabase_sync_calendar/core/utils/supabase_utils.dart';

class SyncService {
  final SupabaseClient supabaseClient;
  final String userId;
  final NetworkService _networkService = NetworkService();
  Timer? _syncTimer;
  bool _isSyncing = false;

  SyncService({
    required this.supabaseClient,
    required this.userId,
  });

  void startAutoSync({Duration syncInterval = const Duration(minutes: 5)}) {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(syncInterval, (_) => syncAll());

    // Also sync when connectivity changes to online
    _networkService.connectivityStream.listen((result) {
      if (_networkService.isConnected) {
        syncAll();
      }
    });
  }

  Future<void> syncAll() async {
    if (_isSyncing || !await _networkService.isOnline) return;

    try {
      _isSyncing = true;
      debugPrint('SyncService: Starting sync...');

      // First pull changes from the server
      await _pullChanges();

      // Then push local changes to the server
      await _pushChanges();

      _isSyncing = false;
      debugPrint('SyncService: Sync completed successfully');
    } catch (e) {
      _isSyncing = false;
      debugPrint('Error during sync: $e');
    }
  }

  // Pull changes from Supabase and store in Hive
  Future<void> _pullChanges() async {
    debugPrint('SyncService: Pulling changes from Supabase');

    try {
      // 1. Sync calendars
      final calendarResponse = await supabaseClient.from(SupabaseUtils.calendarsTable).select().eq(SupabaseUtils.colUserId, userId);

      final supabaseCalendars = (calendarResponse as List).map((json) => CalendarModel.fromJson(json)).toList();

      // Store calendars in Hive (without marking for sync)
      for (final calendar in supabaseCalendars) {
        final box = HiveService.getCalendarBox();
        await box.put(calendar.id, calendar);
      }
      debugPrint('SyncService: Pulled ${supabaseCalendars.length} calendars');

      // 2. Sync event series
      final seriesResponse = await supabaseClient.from(SupabaseUtils.seriesTable).select().eq(SupabaseUtils.colUserId, userId);

      final supabaSeries = (seriesResponse as List).map((json) => CalendarEventSeriesModel.fromJson(json)).toList();

      // Store series in Hive
      for (final series in supabaSeries) {
        final box = HiveService.getSeriesBox();
        await box.put(series.id, series);
      }
      debugPrint('SyncService: Pulled ${supabaSeries.length} event series');

      // 3. Sync events
      final eventResponse = await supabaseClient.from(SupabaseUtils.eventsTable).select().eq(SupabaseUtils.colUserId, userId);

      final supabaseEvents = (eventResponse as List).map((json) => CalendarEventModel.fromJson(json)).toList();

      // Store events in Hive
      for (final event in supabaseEvents) {
        final box = HiveService.getEventBox();
        await box.put(event.id, event);
      }
      debugPrint('SyncService: Pulled ${supabaseEvents.length} events');
    } catch (e) {
      debugPrint('Error pulling changes from Supabase: $e');
      throw Exception('Failed to pull changes: $e');
    }
  }

  // Push local changes to Supabase
  Future<void> _pushChanges() async {
    debugPrint('SyncService: Pushing local changes to Supabase');

    try {
      // 1. Push calendar changes
      final calendarIds = HiveService.getItemsToSync('calendar');
      for (final id in calendarIds) {
        final calendar = HiveService.getCalendar(id);
        if (calendar != null) {
          await supabaseClient.from(SupabaseUtils.calendarsTable).upsert(calendar.toJson());
          await HiveService.markAsSynced('calendar', id);
        }
      }
      debugPrint('SyncService: Pushed ${calendarIds.length} calendars');

      // 2. Push calendar deletions
      final calendarDeletionIds = HiveService.getItemsToSync('calendar_delete');
      for (final id in calendarDeletionIds) {
        await supabaseClient.from(SupabaseUtils.calendarsTable).delete().eq(SupabaseUtils.colId, id).eq(SupabaseUtils.colUserId, userId);
        await HiveService.markAsSynced('calendar_delete', id);
      }

      // 3. Push series changes
      final seriesIds = HiveService.getItemsToSync('series');
      for (final id in seriesIds) {
        final series = HiveService.getSeries(id);
        if (series != null) {
          await supabaseClient.from(SupabaseUtils.seriesTable).upsert(series.toJson());
          await HiveService.markAsSynced('series', id);
        }
      }
      debugPrint('SyncService: Pushed ${seriesIds.length} event series');

      // 4. Push series deletions
      final seriesDeletionIds = HiveService.getItemsToSync('series_delete');
      for (final id in seriesDeletionIds) {
        await supabaseClient.from(SupabaseUtils.seriesTable).delete().eq(SupabaseUtils.colId, id).eq(SupabaseUtils.colUserId, userId);
        await HiveService.markAsSynced('series_delete', id);
      }

      // 5. Push event changes
      final eventIds = HiveService.getItemsToSync('event');
      for (final id in eventIds) {
        final event = HiveService.getEvent(id);
        if (event != null) {
          await supabaseClient.from(SupabaseUtils.eventsTable).upsert(event.toJson());
          await HiveService.markAsSynced('event', id);
        }
      }
      debugPrint('SyncService: Pushed ${eventIds.length} events');

      // 6. Push event deletions
      final eventDeletionIds = HiveService.getItemsToSync('event_delete');
      for (final id in eventDeletionIds) {
        await supabaseClient.from(SupabaseUtils.eventsTable).delete().eq(SupabaseUtils.colId, id).eq(SupabaseUtils.colUserId, userId);
        await HiveService.markAsSynced('event_delete', id);
      }
    } catch (e) {
      debugPrint('Error pushing changes to Supabase: $e');
      throw Exception('Failed to push changes: $e');
    }
  }
}
