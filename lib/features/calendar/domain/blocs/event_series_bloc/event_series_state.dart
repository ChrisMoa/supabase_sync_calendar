import 'package:equatable/equatable.dart';
import 'package:supabase_sync_calendar/core/models/calendar_event_model.dart';
import 'package:supabase_sync_calendar/core/models/calendar_event_series_model.dart';

abstract class EventSeriesState extends Equatable {
  const EventSeriesState();

  @override
  List<Object?> get props => [];
}

class EventSeriesInitial extends EventSeriesState {
  const EventSeriesInitial();
}

class EventSeriesLoading extends EventSeriesState {
  const EventSeriesLoading();
}

class EventSeriesLoaded extends EventSeriesState {
  final CalendarEventSeriesModel series;
  final List<CalendarEventModel> events;

  const EventSeriesLoaded({
    required this.series,
    required this.events,
  });

  @override
  List<Object?> get props => [series, events];
}

class EventSeriesCreated extends EventSeriesState {
  final CalendarEventSeriesModel series;
  final List<CalendarEventModel> events;

  const EventSeriesCreated({
    required this.series,
    required this.events,
  });

  @override
  List<Object?> get props => [series, events];
}

class EventSeriesUpdated extends EventSeriesState {
  final CalendarEventSeriesModel series;
  final List<CalendarEventModel> events;

  const EventSeriesUpdated({
    required this.series,
    required this.events,
  });

  @override
  List<Object?> get props => [series, events];
}

class EventSeriesDeleted extends EventSeriesState {
  final String seriesId;

  const EventSeriesDeleted({
    required this.seriesId,
  });

  @override
  List<Object?> get props => [seriesId];
}

class EventSeriesError extends EventSeriesState {
  final String message;

  const EventSeriesError(this.message);

  @override
  List<Object?> get props => [message];
}
