import 'package:equatable/equatable.dart';
import 'package:supabase_sync_calendar/core/models/calendar_event_model.dart';

abstract class CalendarState extends Equatable {
  final CalendarViewType calendarViewType;

  const CalendarState({
    this.calendarViewType = CalendarViewType.week,
  });

  @override
  List<Object> get props => [calendarViewType];
}

// Enum for calendar view types (needs to be accessible from multiple places)
enum CalendarViewType { day, week, month, schedule }

class CalendarInitial extends CalendarState {
  const CalendarInitial() : super();
}

class CalendarLoading extends CalendarState {
  const CalendarLoading() : super();
}

class CalendarLoaded extends CalendarState {
  final List<CalendarEventModel> events;

  const CalendarLoaded({
    required this.events,
    required super.calendarViewType,
  });

  @override
  List<Object> get props => [events, calendarViewType];
}

class CalendarError extends CalendarState {
  final String message;

  const CalendarError(this.message) : super();

  @override
  List<Object> get props => [message, calendarViewType];
}
