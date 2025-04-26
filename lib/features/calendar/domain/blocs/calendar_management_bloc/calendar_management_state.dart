import 'package:equatable/equatable.dart';
import 'package:supabase_sync_calendar/core/models/calendar_model.dart';

abstract class CalendarManagementState extends Equatable {
  const CalendarManagementState();

  @override
  List<Object> get props => [];
}

class CalendarManagementInitial extends CalendarManagementState {
  const CalendarManagementInitial();
}

class CalendarManagementLoading extends CalendarManagementState {
  const CalendarManagementLoading();
}

class CalendarManagementLoaded extends CalendarManagementState {
  final List<CalendarModel> calendars;
  final CalendarModel? defaultCalendar;

  const CalendarManagementLoaded({
    required this.calendars,
    this.defaultCalendar,
  });

  @override
  List<Object> get props =>
      [calendars, if (defaultCalendar != null) defaultCalendar!];
}

class CalendarManagementError extends CalendarManagementState {
  final String message;

  const CalendarManagementError(this.message);

  @override
  List<Object> get props => [message];
}

class CalendarSyncing extends CalendarManagementState {
  final String calendarId;

  const CalendarSyncing(this.calendarId);

  @override
  List<Object> get props => [calendarId];
}

class CalendarSyncComplete extends CalendarManagementState {
  final String calendarId;
  final int eventCount;

  const CalendarSyncComplete(this.calendarId, this.eventCount);

  @override
  List<Object> get props => [calendarId, eventCount];
}

class CalendarSyncError extends CalendarManagementState {
  final String calendarId;
  final String message;

  const CalendarSyncError(this.calendarId, this.message);

  @override
  List<Object> get props => [calendarId, message];
}

class DeviceCalendarsAvailable extends CalendarManagementState {
  final List<dynamic> deviceCalendars;

  const DeviceCalendarsAvailable(this.deviceCalendars);

  @override
  List<Object> get props => [deviceCalendars];
}
