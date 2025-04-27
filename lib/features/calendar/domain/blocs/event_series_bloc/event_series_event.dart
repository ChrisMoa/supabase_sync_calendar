import 'package:equatable/equatable.dart';
import 'package:supabase_sync_calendar/core/models/calendar_event_model.dart';
import 'package:supabase_sync_calendar/core/models/calendar_event_series_model.dart';

abstract class EventSeriesEvent extends Equatable {
  const EventSeriesEvent();

  @override
  List<Object?> get props => [];
}

class LoadEventSeries extends EventSeriesEvent {
  final String seriesId;

  const LoadEventSeries(this.seriesId);

  @override
  List<Object?> get props => [seriesId];
}

class CreateEventSeries extends EventSeriesEvent {
  final CalendarEventModel templateEvent;
  final CalendarEventSeriesModel series;

  const CreateEventSeries({
    required this.templateEvent,
    required this.series,
  });

  @override
  List<Object?> get props => [templateEvent, series];
}

class UpdateEventSeries extends EventSeriesEvent {
  final CalendarEventSeriesModel series;
  final bool regenerateEvents;

  const UpdateEventSeries({
    required this.series,
    this.regenerateEvents = true,
  });

  @override
  List<Object?> get props => [series, regenerateEvents];
}

class DeleteEventSeries extends EventSeriesEvent {
  final String seriesId;
  final bool deleteEvents;

  const DeleteEventSeries({
    required this.seriesId,
    this.deleteEvents = false,
  });

  @override
  List<Object?> get props => [seriesId, deleteEvents];
}

class UpdateSeriesEvent extends EventSeriesEvent {
  final CalendarEventModel event;
  final bool updateAllEvents;

  const UpdateSeriesEvent({
    required this.event,
    this.updateAllEvents = false,
  });

  @override
  List<Object?> get props => [event, updateAllEvents];
}

class DeleteSeriesEvent extends EventSeriesEvent {
  final String eventId;
  final bool deleteAllFollowing;

  const DeleteSeriesEvent({
    required this.eventId,
    this.deleteAllFollowing = false,
  });

  @override
  List<Object?> get props => [eventId, deleteAllFollowing];
}
