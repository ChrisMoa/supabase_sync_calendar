// ignore_for_file: avoid_print

import 'dart:math';

// ignore: depend_on_referenced_packages
import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

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
    on<CalendarFilterByCalendar>(_onFilterByCalendar);
    on<CalendarRefresh>(_onRefresh);
  }

  void _onInitialize(
    CalendarInitialize event,
    Emitter<CalendarState> emit,
  ) {
    debugPrint('Initializing calendar with user ID: ${event.userId}' + (event.isOfflineMode ? ' in OFFLINE mode' : ''));

    _repository = CalendarRepository(
      supabaseClient: event.supabaseClient,
      userId: event.userId,
      isOfflineMode: event.isOfflineMode,
    );

    // Set up real-time sync only if not in offline mode
    if (!event.isOfflineMode) {
      _syncService = DatabaseSyncService(
        supabaseClient: event.supabaseClient,
        userId: event.userId,
        onEventAdded: (event) => add(CalendarSyncEvent.added(event)),
        onEventUpdated: (event) => add(CalendarSyncEvent.updated(event)),
        onEventDeleted: (id) => add(CalendarSyncEvent.deleted(id)),
      );

      _syncService?.startSync();
    } else {
      debugPrint('🔌 OFFLINE: Skipping real-time sync service initialization');
    }

    emit(const CalendarLoading());
    add(const CalendarLoadEvents());
  }

  Future<void> _onLoadEvents(
    CalendarLoadEvents event,
    Emitter<CalendarState> emit,
  ) async {
    debugPrint('CalendarBloc: Loading events...');
    emit(const CalendarLoading());

    try {
      if (_repository == null) {
        debugPrint('Calendar repository is null');
        emit(const CalendarError('Calendar not initialized'));
        return;
      }

      final events = await _repository!
          .getEvents(
        fetchFromSupabaseIfEmpty: event.fetchFromSupabaseIfEmpty,
      )
          .catchError((e) {
        debugPrint('Error loading events: $e');
        // If there's an error (like table doesn't exist), return empty list
        return <CalendarEventModel>[];
      });

      debugPrint('CalendarBloc: Loaded ${events.length} events');

      // Debug event data
      if (events.isNotEmpty) {
        final sampleEvent = events.first;
        debugPrint('Sample event: title=${sampleEvent.title}, start=${sampleEvent.start}, end=${sampleEvent.end}, calendarId=${sampleEvent.calendarId}');
      } else {
        debugPrint('No events found');
      }

      emit(CalendarLoaded(
        events: events,
        calendarViewType: state.calendarViewType,
      ));

      debugPrint('CalendarLoaded state emitted successfully');
    } catch (e) {
      debugPrint('Failed to load events: $e');
      // Even if loading fails, emit a loaded state with empty lists
      // This prevents the UI from getting stuck in loading state
      emit(CalendarLoaded(
        events: [],
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

        // Update the state with the new event
        emit(CalendarLoaded(
          events: [...currentState.events, newEvent],
          calendarViewType: currentState.calendarViewType,
        ));
      } catch (e) {
        debugPrint('Failed to add event: $e');
        if (e.toString().contains('Table does not exist')) {
          emit(CalendarError('The calendar_events table does not exist in Supabase. Please run the setup script.'));
        } else {
          emit(CalendarError('Failed to add event: $e'));
        }

        // Even after error, revert to loaded state after a delay
        Future.delayed(const Duration(seconds: 3), () {
          if (state is CalendarError) {
            emit(CalendarLoaded(
              events: currentState.events,
              calendarViewType: currentState.calendarViewType,
            ));
          }
        });
      }
    } catch (e) {
      debugPrint('Failed to add event: $e');
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

      // Update the events list
      final updatedEvents = currentState.events.map((e) {
        return e.id == updatedEvent.id ? updatedEvent : e;
      }).toList();

      emit(CalendarLoaded(
        events: updatedEvents,
        calendarViewType: currentState.calendarViewType,
      ));
    } catch (e) {
      debugPrint('Failed to update event: $e');
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
      final filteredEvents = currentState.events.where((e) => e.id != event.eventId).toList();

      emit(CalendarLoaded(
        events: filteredEvents,
        calendarViewType: currentState.calendarViewType,
      ));
    } catch (e) {
      debugPrint('Failed to delete event: $e');
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

        // Update the state with the new event
        emit(CalendarLoaded(
          events: [...currentState.events, event.event!],
          calendarViewType: currentState.calendarViewType,
        ));
        break;

      case SyncType.updated:
        if (event.event == null) return;

        // Update the events list
        final updatedEvents = currentState.events.map((e) {
          return e.id == event.event!.id ? event.event! : e;
        }).toList();

        emit(CalendarLoaded(
          events: updatedEvents,
          calendarViewType: currentState.calendarViewType,
        ));
        break;

      case SyncType.deleted:
        if (event.eventId == null) return;

        // Filter out the deleted event from the lists
        final filteredEvents = currentState.events.where((e) => e.id != event.eventId).toList();

        emit(CalendarLoaded(
          events: filteredEvents,
          calendarViewType: currentState.calendarViewType,
        ));
        break;
    }
  }

  Future<void> _onFilterByCalendar(
    CalendarFilterByCalendar event,
    Emitter<CalendarState> emit,
  ) async {
    if (_repository == null) {
      emit(const CalendarError('Calendar not initialized'));
      return;
    }

    if (state is! CalendarLoaded) {
      emit(const CalendarError('Calendar not loaded'));
      return;
    }

    final currentState = state as CalendarLoaded;
    emit(const CalendarLoading());

    try {
      // If calendarId is null, show all events
      final events = event.calendarId == null
          ? await _repository!.getEvents(fetchFromSupabaseIfEmpty: event.fetchFromSupabaseIfEmpty)
          : await _repository!.getEvents(calendarId: event.calendarId, fetchFromSupabaseIfEmpty: event.fetchFromSupabaseIfEmpty);

      emit(CalendarLoaded(
        events: events,
        calendarViewType: currentState.calendarViewType,
        activeCalendarFilter: event.calendarId,
      ));
    } catch (e) {
      debugPrint('Error filtering events: $e');
      emit(CalendarError('Failed to filter events: $e'));

      // Revert to previous state after delay
      Future.delayed(const Duration(seconds: 3), () {
        emit(currentState);
      });
    }
  }

  void _onRefresh(
    CalendarRefresh event,
    Emitter<CalendarState> emit,
  ) {
    debugPrint('Manual refresh triggered');
    add(const CalendarLoadEvents(fetchFromSupabaseIfEmpty: true));
  }

  // Generate sample events for testing
  static List<CalendarEventModel> generateSampleEvents([int samples = 5]) {
    final List<CalendarEventModel> events = [];
    final now = DateTime.now();
    final uuid = Uuid();
    final random = Random();

    // Sample event templates
    final eventTemplates = [
      {
        'title': 'Morning Meeting',
        'description': 'Daily team standup',
        'colorValue': Colors.blue.value,
        'calendarId': 'work',
      },
      {
        'title': 'Lunch with Client',
        'description': 'Discuss new project requirements',
        'colorValue': Colors.green.value,
        'calendarId': 'work',
      },
      {
        'title': 'Project Review',
        'description': 'End of sprint review',
        'colorValue': Colors.orange.value,
        'calendarId': 'work',
      },
      {
        'title': 'Family Dinner',
        'description': 'At home',
        'colorValue': Colors.purple.value,
        'calendarId': 'family',
      },
      {
        'title': 'Gym Session',
        'description': 'Cardio and weights',
        'colorValue': Colors.red.value,
        'calendarId': 'personal',
      },
    ];

    // Generate random events
    for (int i = 0; i < samples; i++) {
      // Pick a random template
      final templateIndex = random.nextInt(eventTemplates.length);
      final template = eventTemplates[templateIndex];

      // Generate random date (-7 to +14 days from now)
      final daysOffset = random.nextInt(21) - 7;
      final eventDate = now.add(Duration(days: daysOffset));

      // Determine if it's a whole day event (20% chance)
      final isWholeDay = random.nextInt(5) == 0;

      DateTime startTime;
      DateTime endTime;

      if (isWholeDay) {
        // Whole day event
        startTime = DateTime(eventDate.year, eventDate.month, eventDate.day, 0, 0);
        endTime = DateTime(eventDate.year, eventDate.month, eventDate.day, 23, 59, 59);
      } else {
        // Regular event
        final startHour = 7 + random.nextInt(11);
        final startMinute = [0, 15, 30, 45][random.nextInt(4)]; // Quarter-hour intervals
        final durationMinutes = 30 + random.nextInt(5) * 30; // 30min increments

        startTime = DateTime(eventDate.year, eventDate.month, eventDate.day, startHour, startMinute);

        endTime = startTime.add(Duration(minutes: durationMinutes));
      }

      // 30% chance of having a reminder
      DateTime? reminder = random.nextInt(10) < 3 ? startTime.subtract(Duration(minutes: 15 * (1 + random.nextInt(8)))) : null;

      // For sample events, let's not use series functionality
      final String? seriesId = null;

      events.add(
        CalendarEventModel(
          id: uuid.v4(),
          title: template['title'] as String,
          description: template['description'] as String? ?? '',
          start: startTime,
          end: endTime,
          wholeDay: isWholeDay,
          reminder: reminder,
          appendixes: const [], // Assuming appendixes start empty for generated events
          seriesId: seriesId,
          colorValue: template['colorValue'] as int,
          userId: 'sample',
          calendarId: template['calendarId'] as String,
          isExternalReadOnly: false,
        ),
      );
    }

    return events;
  }

  // Clean up when the bloc is closed
  @override
  Future<void> close() {
    _syncService?.dispose();
    return super.close();
  }
}
