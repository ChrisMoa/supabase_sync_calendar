import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_sync_calendar/features/calendar/domain/blocs/calendar_bloc/calendar_state.dart';

import '../../../../../core/models/calendar_event_model.dart';

abstract class CalendarEvent extends Equatable {
  const CalendarEvent();

  @override
  List<Object> get props => [];
}

class CalendarInitialize extends CalendarEvent {
  final SupabaseClient supabaseClient;
  final String userId;

  const CalendarInitialize({
    required this.supabaseClient,
    required this.userId,
  });

  @override
  List<Object> get props => [supabaseClient, userId];
}

class CalendarLoadEvents extends CalendarEvent {
  const CalendarLoadEvents();
}

class CalendarAddEvent extends CalendarEvent {
  final CalendarEventModel event;

  const CalendarAddEvent(this.event);

  @override
  List<Object> get props => [event];
}

class CalendarUpdateEvent extends CalendarEvent {
  final CalendarEventModel event;

  const CalendarUpdateEvent(this.event);

  @override
  List<Object> get props => [event];
}

class CalendarDeleteEvent extends CalendarEvent {
  final String eventId;

  const CalendarDeleteEvent(this.eventId);

  @override
  List<Object> get props => [eventId];
}

class CalendarChangeView extends CalendarEvent {
  final CalendarViewType viewType;

  const CalendarChangeView(this.viewType);

  @override
  List<Object> get props => [viewType];
}

enum SyncType { added, updated, deleted }

class CalendarSyncEvent extends CalendarEvent {
  final SyncType syncType;
  final CalendarEventModel? event;
  final String? eventId;

  const CalendarSyncEvent._({
    required this.syncType,
    this.event,
    this.eventId,
  });

  factory CalendarSyncEvent.added(CalendarEventModel event) {
    return CalendarSyncEvent._(
      syncType: SyncType.added,
      event: event,
    );
  }

  factory CalendarSyncEvent.updated(CalendarEventModel event) {
    return CalendarSyncEvent._(
      syncType: SyncType.updated,
      event: event,
    );
  }

  factory CalendarSyncEvent.deleted(String eventId) {
    return CalendarSyncEvent._(
      syncType: SyncType.deleted,
      eventId: eventId,
    );
  }

  @override
  List<Object> get props => [
        syncType,
        if (event != null) event!,
        if (eventId != null) eventId!,
      ];
}

class CalendarFilterByCalendar extends CalendarEvent {
  final String? calendarId; // Null means show all calendars

  const CalendarFilterByCalendar(this.calendarId);

  @override
  List<Object> get props => calendarId != null ? [calendarId!] : [];
}
