import 'package:bloc/bloc.dart';
import 'package:draggable_calendar/draggable_calendar.dart';

import '../../../../../core/models/calendar_event_model.dart';
import '../../../data/repositories/calendar_repository.dart';
import '../../../data/services/database_sync_service.dart';
import 'calendar_event.dart';
import 'calendar_state.dart';

class CalendarBloc extends Bloc<CalendarEvent, CalendarState> {
  CalendarRepository? _repository;
  DatabaseSyncService? _syncService;

  CalendarBloc() : super(const CalendarInitial()) {
    on<CalendarInitialize>(_onInitialize);
    on<CalendarLoadEvents>(_onLoadEvents);
    on<CalendarAddEvent>(_onAddEvent);
    on<CalendarUpdateEvent>(_onUpdateEvent);
    on<CalendarDeleteEvent>(_onDeleteEvent);
    on<CalendarChangeView>(_onChangeView);
    on<CalendarSyncEvent>(_onSyncEvent);
  }

  void _onInitialize(
    CalendarInitialize event,
    Emitter<CalendarState> emit,
  ) {
    print('Initializing calendar with user ID: ${event.userId}');

    _repository = CalendarRepository(
      supabaseClient: event.supabaseClient,
      userId: event.userId,
    );

    // Set up real-time sync
    _syncService = DatabaseSyncService(
      supabaseClient: event.supabaseClient,
      userId: event.userId,
      onEventAdded: (event) => add(CalendarSyncEvent.added(event)),
      onEventUpdated: (event) => add(CalendarSyncEvent.updated(event)),
      onEventDeleted: (id) => add(CalendarSyncEvent.deleted(id)),
    );

    _syncService?.startSync();

    emit(const CalendarLoading());
    add(const CalendarLoadEvents());
  }

  Future<void> _onLoadEvents(
    CalendarLoadEvents event,
    Emitter<CalendarState> emit,
  ) async {
    emit(const CalendarLoading());

    try {
      print('Loading calendar events...');
      if (_repository == null) {
        print('Calendar repository is null');
        emit(const CalendarError('Calendar not initialized'));
        return;
      }

      final events = await _repository!.getEvents().catchError((e) {
        print('Error loading events: $e');
        // If there's an error (like table doesn't exist), return empty list
        return <CalendarEventModel>[];
      });

      print('Loaded ${events.length} events');

      // Convert from CalendarEventModel to EventModel for draggable calendar
      final draggableEvents = events
          .map((event) => EventModel(
                id: event.id,
                title: event.title,
                description: event.description,
                start: event.start,
                end: event.end,
                color: event.color,
              ))
          .toList();

      print(
          'Emitting CalendarLoaded state with ${draggableEvents.length} events');
      emit(CalendarLoaded(
        events: events,
        draggableEvents: draggableEvents,
        calendarViewType: state.calendarViewType,
      ));
      print('CalendarLoaded state emitted successfully');
    } catch (e) {
      print('Failed to load events: $e');
      // Even if loading fails, emit a loaded state with empty lists
      // This prevents the UI from getting stuck in loading state
      emit(CalendarLoaded(
        events: [],
        draggableEvents: [],
        calendarViewType: state.calendarViewType,
      ));
    }
  }

  Future<void> _onAddEvent(
    CalendarAddEvent event,
    Emitter<CalendarState> emit,
  ) async {
    try {
      if (_repository == null) {
        emit(const CalendarError('Calendar not initialized'));
        return;
      }

      if (state is! CalendarLoaded) {
        emit(const CalendarError('Calendar not loaded'));
        return;
      }

      final currentState = state as CalendarLoaded;

      try {
        // Create the new event in Supabase
        final newEvent = await _repository!.createEvent(event.event);

        // Convert to draggable event
        final newDraggableEvent = EventModel(
          id: newEvent.id,
          title: newEvent.title,
          description: newEvent.description,
          start: newEvent.start,
          end: newEvent.end,
          color: newEvent.color,
        );

        // Update the state with the new event
        emit(CalendarLoaded(
          events: [...currentState.events, newEvent],
          draggableEvents: [...currentState.draggableEvents, newDraggableEvent],
          calendarViewType: currentState.calendarViewType,
        ));
      } catch (e) {
        print('Failed to add event: $e');
        if (e.toString().contains('Table does not exist')) {
          emit(CalendarError(
              'The calendar_events table does not exist in Supabase. Please run the setup script.'));
        } else {
          emit(CalendarError('Failed to add event: $e'));
        }

        // Even after error, revert to loaded state after a delay
        Future.delayed(const Duration(seconds: 3), () {
          if (state is CalendarError) {
            emit(CalendarLoaded(
              events: currentState.events,
              draggableEvents: currentState.draggableEvents,
              calendarViewType: currentState.calendarViewType,
            ));
          }
        });
      }
    } catch (e) {
      print('Failed to add event: $e');
      emit(CalendarError('Failed to add event: $e'));
    }
  }

  Future<void> _onUpdateEvent(
    CalendarUpdateEvent event,
    Emitter<CalendarState> emit,
  ) async {
    try {
      if (_repository == null) {
        emit(const CalendarError('Calendar not initialized'));
        return;
      }

      if (state is! CalendarLoaded) {
        emit(const CalendarError('Calendar not loaded'));
        return;
      }

      final currentState = state as CalendarLoaded;

      // Update the event in Supabase
      final updatedEvent = await _repository!.updateEvent(event.event);

      // Convert to draggable event
      final updatedDraggableEvent = EventModel(
        id: updatedEvent.id,
        title: updatedEvent.title,
        description: updatedEvent.description,
        start: updatedEvent.start,
        end: updatedEvent.end,
        color: updatedEvent.color,
      );

      // Update the events list
      final updatedEvents = currentState.events.map((e) {
        return e.id == updatedEvent.id ? updatedEvent : e;
      }).toList();

      // Update the draggable events list
      final updatedDraggableEvents = currentState.draggableEvents.map((e) {
        return e.id == updatedDraggableEvent.id ? updatedDraggableEvent : e;
      }).toList();

      emit(CalendarLoaded(
        events: updatedEvents,
        draggableEvents: updatedDraggableEvents,
        calendarViewType: currentState.calendarViewType,
      ));
    } catch (e) {
      print('Failed to update event: $e');
      emit(CalendarError('Failed to update event: $e'));
    }
  }

  Future<void> _onDeleteEvent(
    CalendarDeleteEvent event,
    Emitter<CalendarState> emit,
  ) async {
    try {
      if (_repository == null) {
        emit(const CalendarError('Calendar not initialized'));
        return;
      }

      if (state is! CalendarLoaded) {
        emit(const CalendarError('Calendar not loaded'));
        return;
      }

      final currentState = state as CalendarLoaded;

      // Delete the event from Supabase
      await _repository!.deleteEvent(event.eventId);

      // Filter out the deleted event from the lists
      final filteredEvents =
          currentState.events.where((e) => e.id != event.eventId).toList();

      final filteredDraggableEvents = currentState.draggableEvents
          .where((e) => e.id != event.eventId)
          .toList();

      emit(CalendarLoaded(
        events: filteredEvents,
        draggableEvents: filteredDraggableEvents,
        calendarViewType: currentState.calendarViewType,
      ));
    } catch (e) {
      print('Failed to delete event: $e');
      emit(CalendarError('Failed to delete event: $e'));
    }
  }

  void _onChangeView(
    CalendarChangeView event,
    Emitter<CalendarState> emit,
  ) {
    if (state is CalendarLoaded) {
      final currentState = state as CalendarLoaded;
      emit(CalendarLoaded(
        events: currentState.events,
        draggableEvents: currentState.draggableEvents,
        calendarViewType: event.viewType,
      ));
    }
  }

  Future<void> _onSyncEvent(
    CalendarSyncEvent event,
    Emitter<CalendarState> emit,
  ) async {
    if (state is! CalendarLoaded) return;

    final currentState = state as CalendarLoaded;

    // Handle different sync events
    switch (event.syncType) {
      case SyncType.added:
        if (event.event == null) return;

        // Convert to draggable event
        final newDraggableEvent = EventModel(
          id: event.event!.id,
          title: event.event!.title,
          description: event.event!.description,
          start: event.event!.start,
          end: event.event!.end,
          color: event.event!.color,
        );

        // Update the state with the new event
        emit(CalendarLoaded(
          events: [...currentState.events, event.event!],
          draggableEvents: [...currentState.draggableEvents, newDraggableEvent],
          calendarViewType: currentState.calendarViewType,
        ));
        break;

      case SyncType.updated:
        if (event.event == null) return;

        // Convert to draggable event
        final updatedDraggableEvent = EventModel(
          id: event.event!.id,
          title: event.event!.title,
          description: event.event!.description,
          start: event.event!.start,
          end: event.event!.end,
          color: event.event!.color,
        );

        // Update the events list
        final updatedEvents = currentState.events.map((e) {
          return e.id == event.event!.id ? event.event! : e;
        }).toList();

        // Update the draggable events list
        final updatedDraggableEvents = currentState.draggableEvents.map((e) {
          return e.id == updatedDraggableEvent.id ? updatedDraggableEvent : e;
        }).toList();

        emit(CalendarLoaded(
          events: updatedEvents,
          draggableEvents: updatedDraggableEvents,
          calendarViewType: currentState.calendarViewType,
        ));
        break;

      case SyncType.deleted:
        if (event.eventId == null) return;

        // Filter out the deleted event from the lists
        final filteredEvents =
            currentState.events.where((e) => e.id != event.eventId).toList();

        final filteredDraggableEvents = currentState.draggableEvents
            .where((e) => e.id != event.eventId)
            .toList();

        emit(CalendarLoaded(
          events: filteredEvents,
          draggableEvents: filteredDraggableEvents,
          calendarViewType: currentState.calendarViewType,
        ));
        break;
    }
  }

  // Clean up when the bloc is closed
  @override
  Future<void> close() {
    _syncService?.dispose();
    return super.close();
  }
}
