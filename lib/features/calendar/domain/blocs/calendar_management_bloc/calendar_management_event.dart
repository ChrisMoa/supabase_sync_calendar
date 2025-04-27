import 'package:equatable/equatable.dart';
import 'package:supabase_sync_calendar/core/models/calendar_model.dart';

abstract class CalendarManagementEvent extends Equatable {
  const CalendarManagementEvent();

  @override
  List<Object> get props => [];
}

class LoadCalendars extends CalendarManagementEvent {
  const LoadCalendars();
}

class AddCalendar extends CalendarManagementEvent {
  final CalendarModel calendar;

  const AddCalendar(this.calendar);

  @override
  List<Object> get props => [calendar];
}

class UpdateCalendar extends CalendarManagementEvent {
  final CalendarModel calendar;

  const UpdateCalendar(this.calendar);

  @override
  List<Object> get props => [calendar];
}

class DeleteCalendar extends CalendarManagementEvent {
  final String calendarId;

  const DeleteCalendar(this.calendarId);

  @override
  List<Object> get props => [calendarId];
}

class SetDefaultCalendar extends CalendarManagementEvent {
  final String calendarId;

  const SetDefaultCalendar(this.calendarId);

  @override
  List<Object> get props => [calendarId];
}

class SyncWebDAVCalendar extends CalendarManagementEvent {
  final CalendarModel calendar;

  const SyncWebDAVCalendar(this.calendar);

  @override
  List<Object> get props => [calendar];
}

class SyncDeviceCalendar extends CalendarManagementEvent {
  final CalendarModel calendar;

  const SyncDeviceCalendar(this.calendar);

  @override
  List<Object> get props => [calendar];
}

class ImportDeviceCalendars extends CalendarManagementEvent {
  const ImportDeviceCalendars();
}
