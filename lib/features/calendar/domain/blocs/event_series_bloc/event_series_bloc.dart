import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_sync_calendar/core/models/calendar_event_model.dart';
import 'package:uuid/uuid.dart';

import '../../../data/repositories/calendar_repository.dart';
import '../../../data/repositories/event_series_repository.dart';
import 'event_series_event.dart';
import 'event_series_state.dart';

class EventSeriesBloc extends Bloc<EventSeriesEvent, EventSeriesState> {
  final EventSeriesRepository _seriesRepository;
  final CalendarRepository _eventRepository;
  final Uuid _uuid = const Uuid();

  EventSeriesBloc({
    required SupabaseClient supabaseClient,
    required String userId,
  })  : _seriesRepository = EventSeriesRepository(
          supabaseClient: supabaseClient,
          userId: userId,
        ),
        _eventRepository = CalendarRepository(
          supabaseClient: supabaseClient,
          userId: userId,
        ),
        super(const EventSeriesInitial()) {
    on<LoadEventSeries>(_onLoadEventSeries);
    on<CreateEventSeries>(_onCreateEventSeries);
    on<UpdateEventSeries>(_onUpdateEventSeries);
    on<DeleteEventSeries>(_onDeleteEventSeries);
    on<UpdateSeriesEvent>(_onUpdateSeriesEvent);
    on<DeleteSeriesEvent>(_onDeleteSeriesEvent);
  }

  Future<void> _onLoadEventSeries(
    LoadEventSeries event,
    Emitter<EventSeriesState> emit,
  ) async {
    emit(const EventSeriesLoading());

    try {
      // Load the series
      final series = await _seriesRepository.getSeriesById(event.seriesId);

      // Load events in the series
      final List<CalendarEventModel> events =
          await _eventRepository.getEvents();
      final seriesEvents =
          events.where((e) => e.seriesId == event.seriesId).toList();

      emit(EventSeriesLoaded(series: series, events: seriesEvents));
    } catch (e) {
      emit(EventSeriesError('Failed to load event series: $e'));
    }
  }

  Future<void> _onCreateEventSeries(
    CreateEventSeries event,
    Emitter<EventSeriesState> emit,
  ) async {
    emit(const EventSeriesLoading());

    try {
      // Create a new series ID
      final String seriesId = _uuid.v4();
      final newSeries = event.series.copyWith(id: seriesId);

      // Save the series to the database
      final savedSeries = await _seriesRepository.createSeries(newSeries);

      // Generate events for the series
      final List<CalendarEventModel> generatedEvents =
          await _seriesRepository.generateSeriesEvents(
        savedSeries,
        event.templateEvent,
      );

      // Save the generated events (first event is already updated template)
      final List<CalendarEventModel> savedEvents = [];

      // The first event is the template - update it
      final templateEvent = generatedEvents.first;
      await _eventRepository.updateEvent(templateEvent);
      savedEvents.add(templateEvent);

      // Create all the other events
      for (int i = 1; i < generatedEvents.length; i++) {
        final generatedEvent = generatedEvents[i];
        final savedEvent = await _eventRepository.createEvent(generatedEvent);
        savedEvents.add(savedEvent);
      }

      emit(EventSeriesCreated(series: savedSeries, events: savedEvents));
    } catch (e) {
      emit(EventSeriesError('Failed to create event series: $e'));
    }
  }

  Future<void> _onUpdateEventSeries(
    UpdateEventSeries event,
    Emitter<EventSeriesState> emit,
  ) async {
    emit(const EventSeriesLoading());

    try {
      // Update the series
      final updatedSeries = await _seriesRepository.updateSeries(event.series);

      if (event.regenerateEvents) {
        // Get the template event
        final List<CalendarEventModel> events =
            await _eventRepository.getEvents();
        final templateEvent = events.firstWhere(
          (e) => e.id == updatedSeries.templateEventId,
          orElse: () => throw Exception('Template event not found'),
        );

        // Delete existing events except the template
        await _deleteSeriesEvents(updatedSeries.id, keepTemplate: true);

        // Generate new events
        final List<CalendarEventModel> generatedEvents =
            await _seriesRepository.generateSeriesEvents(
          updatedSeries,
          templateEvent,
        );

        // Save the generated events
        final List<CalendarEventModel> savedEvents = [];
        for (final generatedEvent in generatedEvents) {
          if (generatedEvent.id != templateEvent.id) {
            final savedEvent =
                await _eventRepository.createEvent(generatedEvent);
            savedEvents.add(savedEvent);
          } else {
            savedEvents.add(generatedEvent);
          }
        }

        emit(EventSeriesUpdated(series: updatedSeries, events: savedEvents));
      } else {
        // Just return the updated series with the current events
        final List<CalendarEventModel> events =
            await _eventRepository.getEvents();
        final seriesEvents =
            events.where((e) => e.seriesId == updatedSeries.id).toList();

        emit(EventSeriesUpdated(series: updatedSeries, events: seriesEvents));
      }
    } catch (e) {
      emit(EventSeriesError('Failed to update event series: $e'));
    }
  }

  Future<void> _onDeleteEventSeries(
    DeleteEventSeries event,
    Emitter<EventSeriesState> emit,
  ) async {
    emit(const EventSeriesLoading());

    try {
      // Delete the series and optionally its events
      await _seriesRepository.deleteSeries(
        event.seriesId,
        deleteEvents: event.deleteEvents,
      );

      emit(EventSeriesDeleted(seriesId: event.seriesId));
    } catch (e) {
      emit(EventSeriesError('Failed to delete event series: $e'));
    }
  }

  Future<void> _onUpdateSeriesEvent(
    UpdateSeriesEvent event,
    Emitter<EventSeriesState> emit,
  ) async {
    emit(const EventSeriesLoading());

    try {
      if (event.updateAllEvents) {
        // Get the series information
        final String? seriesId = event.event.seriesId;
        if (seriesId == null) {
          throw Exception('Event is not part of a series');
        }

        final series = await _seriesRepository.getSeriesById(seriesId);

        // Get all events in the series
        final List<CalendarEventModel> allEvents =
            await _eventRepository.getEvents();
        final seriesEvents =
            allEvents.where((e) => e.seriesId == seriesId).toList();

        // Update all events with changes from the updated event
        final List<CalendarEventModel> updatedEvents = [];

        for (final seriesEvent in seriesEvents) {
          // Calculate time differences to keep relative timing
          final Duration startDiff =
              event.event.start.difference(seriesEvent.start);
          final Duration endDiff = event.event.end.difference(seriesEvent.end);

          // Update each event while preserving date and time
          final updatedEvent = seriesEvent.copyWith(
            title: event.event.title,
            description: event.event.description,
            color: event.event.color,
            wholeDay: event.event.wholeDay,
            reminder: event.event.reminder != null
                ? seriesEvent.start.add(
                    event.event.start.difference(event.event.reminder!),
                  )
                : null,
          );

          final savedEvent = await _eventRepository.updateEvent(updatedEvent);
          updatedEvents.add(savedEvent);
        }

        emit(EventSeriesUpdated(series: series, events: updatedEvents));
      } else {
        // Just update the single event
        final updatedEvent = await _eventRepository.updateEvent(event.event);

        // If this is the template event, we might need to update the series
        if (event.event.seriesId != null) {
          final series =
              await _seriesRepository.getSeriesById(event.event.seriesId!);

          // Check if this is the template event
          if (series.templateEventId == event.event.id) {
            // Just get events without regenerating
            add(UpdateEventSeries(series: series, regenerateEvents: false));
          } else {
            // Just return the updated event
            final List<CalendarEventModel> events =
                await _eventRepository.getEvents();
            final seriesEvents = events
                .where((e) => e.seriesId == event.event.seriesId)
                .toList();

            emit(EventSeriesUpdated(series: series, events: seriesEvents));
          }
        }
      }
    } catch (e) {
      emit(EventSeriesError('Failed to update series event: $e'));
    }
  }

  Future<void> _onDeleteSeriesEvent(
    DeleteSeriesEvent event,
    Emitter<EventSeriesState> emit,
  ) async {
    emit(const EventSeriesLoading());

    try {
      // Get the event
      final List<CalendarEventModel> allEvents =
          await _eventRepository.getEvents();
      final eventToDelete = allEvents.firstWhere(
        (e) => e.id == event.eventId,
        orElse: () => throw Exception('Event not found'),
      );

      final seriesId = eventToDelete.seriesId;
      if (seriesId == null) {
        throw Exception('Event is not part of a series');
      }

      // Get the series
      final series = await _seriesRepository.getSeriesById(seriesId);

      if (event.deleteAllFollowing) {
        // Delete this event and all future events
        final seriesEvents =
            allEvents.where((e) => e.seriesId == seriesId).toList();

        // Sort events by start date
        seriesEvents.sort((a, b) => a.start.compareTo(b.start));

        // Find index of the event to delete
        final int eventIndex =
            seriesEvents.indexWhere((e) => e.id == event.eventId);

        if (eventIndex >= 0) {
          // Delete this event and all following events
          for (int i = eventIndex; i < seriesEvents.length; i++) {
            await _eventRepository.deleteEvent(seriesEvents[i].id);
          }

          // If we deleted the template event, update the series
          if (series.templateEventId == event.eventId && eventIndex > 0) {
            // Make the previous event the new template
            final newTemplate = seriesEvents[eventIndex - 1];
            final updatedSeries =
                series.copyWith(templateEventId: newTemplate.id);
            await _seriesRepository.updateSeries(updatedSeries);

            // Get the remaining events
            final remainingEvents = seriesEvents.sublist(0, eventIndex);

            emit(EventSeriesUpdated(
                series: updatedSeries, events: remainingEvents));
          } else if (eventIndex == 0) {
            // We deleted the first event, delete the whole series
            await _seriesRepository.deleteSeries(seriesId, deleteEvents: true);
            emit(EventSeriesDeleted(seriesId: seriesId));
          } else {
            // Get the remaining events
            final remainingEvents = seriesEvents.sublist(0, eventIndex);

            emit(EventSeriesUpdated(series: series, events: remainingEvents));
          }
        }
      } else {
        // Just delete this single event
        await _eventRepository.deleteEvent(event.eventId);

        // If we deleted the template event, update the series
        if (series.templateEventId == event.eventId) {
          // Get remaining events
          final remainingEvents = allEvents
              .where((e) => e.seriesId == seriesId && e.id != event.eventId)
              .toList();

          if (remainingEvents.isNotEmpty) {
            // Make the first remaining event the new template
            remainingEvents.sort((a, b) => a.start.compareTo(b.start));
            final newTemplate = remainingEvents.first;

            final updatedSeries =
                series.copyWith(templateEventId: newTemplate.id);
            await _seriesRepository.updateSeries(updatedSeries);

            emit(EventSeriesUpdated(
                series: updatedSeries, events: remainingEvents));
          } else {
            // No events left, delete the series
            await _seriesRepository.deleteSeries(seriesId);
            emit(EventSeriesDeleted(seriesId: seriesId));
          }
        } else {
          // Get the remaining events
          final remainingEvents = allEvents
              .where((e) => e.seriesId == seriesId && e.id != event.eventId)
              .toList();

          emit(EventSeriesUpdated(series: series, events: remainingEvents));
        }
      }
    } catch (e) {
      emit(EventSeriesError('Failed to delete series event: $e'));
    }
  }

  // Helper method to delete all events in a series, optionally keeping the template
  Future<void> _deleteSeriesEvents(String seriesId,
      {bool keepTemplate = false}) async {
    try {
      // Get all events in the series
      final List<CalendarEventModel> allEvents =
          await _eventRepository.getEvents();
      final seriesEvents =
          allEvents.where((e) => e.seriesId == seriesId).toList();

      // Get the template ID if needed
      String? templateId;
      if (keepTemplate) {
        final series = await _seriesRepository.getSeriesById(seriesId);
        templateId = series.templateEventId;
      }

      // Delete each event except the template if specified
      for (final event in seriesEvents) {
        if (!keepTemplate || event.id != templateId) {
          await _eventRepository.deleteEvent(event.id);
        }
      }
    } catch (e) {
      throw Exception('Failed to delete series events: $e');
    }
  }
}
