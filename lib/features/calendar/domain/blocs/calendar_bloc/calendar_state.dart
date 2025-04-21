import 'package:draggable_calendar/draggable_calendar.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/models/calendar_event_model.dart';

abstract class CalendarState extends Equatable {
  final CalendarViewType calendarViewType;

  const CalendarState({
    this.calendarViewType = CalendarViewType.week,
  });

  @override
  List<Object> get props => [calendarViewType];
}

class CalendarInitial extends CalendarState {
  const CalendarInitial() : super();
}

class CalendarLoading extends CalendarState {
  const CalendarLoading() : super();
}

class CalendarLoaded extends CalendarState {
  final List<CalendarEventModel> events;
  final List<EventModel> draggableEvents;

  const CalendarLoaded({
    required this.events,
    required this.draggableEvents,
    required super.calendarViewType,
  });

  @override
  List<Object> get props => [events, draggableEvents, calendarViewType];
}

class CalendarError extends CalendarState {
  final String message;

  const CalendarError(this.message) : super();

  @override
  List<Object> get props => [message, calendarViewType];
}
