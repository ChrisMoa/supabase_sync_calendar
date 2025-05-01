import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_sync_calendar/core/models/calendar_model.dart';
import 'package:supabase_sync_calendar/core/services/ics_import_service.dart';
import 'package:supabase_sync_calendar/features/calendar/domain/blocs/calendar_bloc/calendar_bloc.dart';
import 'package:supabase_sync_calendar/features/calendar/domain/blocs/calendar_bloc/calendar_event.dart';

import '../../../data/repositories/calendar_management_repository.dart';
import '../../../data/repositories/calendar_repository.dart';
import '../../../data/services/device_calendar_service.dart';
import '../../../data/services/webdav_calendar_service.dart';
import 'calendar_management_event.dart';
import 'calendar_management_state.dart';

class CalendarManagementBloc extends Bloc<CalendarManagementEvent, CalendarManagementState> {
  final CalendarManagementRepository _calendarRepo;
  final CalendarRepository _eventRepo;
  final WebDAVCalendarService _webdavService = WebDAVCalendarService();
  final DeviceCalendarService _deviceService = DeviceCalendarService();
  final ICSImportService _icsImportService = ICSImportService();
  final CalendarBloc? calendarBloc;

  CalendarManagementBloc({
    required SupabaseClient supabaseClient,
    required String userId,
    this.calendarBloc,
  })  : _calendarRepo = CalendarManagementRepository(
          supabaseClient: supabaseClient,
          userId: userId,
        ),
        _eventRepo = CalendarRepository(
          supabaseClient: supabaseClient,
          userId: userId,
        ),
        super(const CalendarManagementInitial()) {
    print('CalendarManagementBloc initialized');

    on<LoadCalendars>((event, emit) {
      print('LoadCalendars event handler called');
      return _onLoadCalendars(event, emit);
    });

    on<AddCalendar>((event, emit) {
      print('AddCalendar event handler called');
      return _onAddCalendar(event, emit);
    });

    on<SyncDeviceCalendar>((event, emit) {
      print('SyncDeviceCalendar event handler called for ${event.calendar.name}');
      return _onSyncDeviceCalendar(event, emit);
    });

    // Register other event handlers...
    on<UpdateCalendar>(_onUpdateCalendar);
    on<DeleteCalendar>(_onDeleteCalendar);
    on<SetDefaultCalendar>(_onSetDefaultCalendar);
    on<SyncWebDAVCalendar>(_onSyncWebDAVCalendar);
    on<ImportDeviceCalendars>(_onImportDeviceCalendars);
    on<ImportICSFile>(_onImportICSFile);
    on<ImportICSContent>(_onImportICSContent);
  }

  // Override add method to trace events
  @override
  void add(CalendarManagementEvent event) {
    print('Adding event to CalendarManagementBloc: ${event.runtimeType}');
    super.add(event);
  }

  Future<void> _onLoadCalendars(
    LoadCalendars event,
    Emitter<CalendarManagementState> emit,
  ) async {
    emit(const CalendarManagementLoading());

    try {
      // Ensure there's a default calendar
      final defaultCalendar = await _calendarRepo.ensureDefaultCalendar();

      // Load all calendars
      final calendars = await _calendarRepo.getCalendars();

      emit(CalendarManagementLoaded(
        calendars: calendars,
        defaultCalendar: defaultCalendar,
      ));
    } catch (e) {
      emit(CalendarManagementError('Failed to load calendars: $e'));
    }
  }

  Future<void> _onAddCalendar(
    AddCalendar event,
    Emitter<CalendarManagementState> emit,
  ) async {
    try {
      final newCalendar = await _calendarRepo.createCalendar(event.calendar);

      final currentState = state;
      if (currentState is CalendarManagementLoaded) {
        emit(CalendarManagementLoaded(
          calendars: [...currentState.calendars, newCalendar],
          defaultCalendar: newCalendar.isDefault ? newCalendar : currentState.defaultCalendar,
        ));
      }
    } catch (e) {
      emit(CalendarManagementError('Failed to add calendar: $e'));
    }
  }

  Future<void> _onUpdateCalendar(
    UpdateCalendar event,
    Emitter<CalendarManagementState> emit,
  ) async {
    try {
      final previousCalendarState = state;
      CalendarModel? previousCalendar;

      // Find the previous state of the calendar
      if (previousCalendarState is CalendarManagementLoaded) {
        previousCalendar = previousCalendarState.calendars.firstWhere(
          (cal) => cal.id == event.calendar.id,
          orElse: () => event.calendar,
        );
      }

      // Update the calendar
      final updatedCalendar = await _calendarRepo.updateCalendar(event.calendar);

      // Check if the color has changed
      if (previousCalendar != null && previousCalendar.color != updatedCalendar.color) {
        // Update all events' colors associated with this calendar
        await _updateEventsColorForCalendar(updatedCalendar);
      }

      final currentState = state;
      if (currentState is CalendarManagementLoaded) {
        final updatedCalendars = currentState.calendars.map((calendar) {
          return calendar.id == updatedCalendar.id ? updatedCalendar : calendar;
        }).toList();

        emit(CalendarManagementLoaded(
          calendars: updatedCalendars,
          defaultCalendar: updatedCalendar.isDefault ? updatedCalendar : currentState.defaultCalendar,
        ));
      }
    } catch (e) {
      emit(CalendarManagementError('Failed to update calendar: $e'));
    }
  }

  // Helper method to update the color of all events associated with a calendar
  Future<void> _updateEventsColorForCalendar(CalendarModel calendar) async {
    try {
      // Get all events for this calendar
      final events = await _eventRepo.getEvents(calendarId: calendar.id);

      // Update each event with the new calendar color
      for (final event in events) {
        final updatedEvent = event.copyWith(colorValue: calendar.colorValue);
        if (calendarBloc != null) {
          calendarBloc!.add(CalendarUpdateEvent(updatedEvent));
        }
      }

      print('Updated colors for ${events.length} events in calendar ${calendar.name}');
    } catch (e) {
      print('Error updating event colors: $e');
      // Don't throw here, just log the error to not interrupt the calendar update
    }
  }

  Future<void> _onDeleteCalendar(
    DeleteCalendar event,
    Emitter<CalendarManagementState> emit,
  ) async {
    try {
      await _calendarRepo.deleteCalendar(event.calendarId);

      final currentState = state;
      if (currentState is CalendarManagementLoaded) {
        final updatedCalendars = currentState.calendars.where((calendar) => calendar.id != event.calendarId).toList();

        // Check if we deleted the default calendar
        final isDefaultDeleted = currentState.defaultCalendar?.id == event.calendarId;
        CalendarModel? newDefault;

        if (isDefaultDeleted && updatedCalendars.isNotEmpty) {
          // Make the first calendar the default
          newDefault = updatedCalendars.first.copyWith(isDefault: true);
          await _calendarRepo.updateCalendar(newDefault);

          // Update the list with the new default
          final finalCalendars = updatedCalendars.map((calendar) {
            return calendar.id == newDefault!.id ? newDefault : calendar;
          }).toList();

          emit(CalendarManagementLoaded(
            calendars: finalCalendars,
            defaultCalendar: newDefault,
          ));
        } else {
          emit(CalendarManagementLoaded(
            calendars: updatedCalendars,
            defaultCalendar: isDefaultDeleted ? null : currentState.defaultCalendar,
          ));
        }
      }
    } catch (e) {
      emit(CalendarManagementError('Failed to delete calendar: $e'));
    }
  }

  Future<void> _onSetDefaultCalendar(
    SetDefaultCalendar event,
    Emitter<CalendarManagementState> emit,
  ) async {
    final currentState = state;
    if (currentState is CalendarManagementLoaded) {
      try {
        // Find the new default calendar
        final newDefault = currentState.calendars.firstWhere(
          (calendar) => calendar.id == event.calendarId,
        );

        // Update it to be the default
        final updatedDefault = newDefault.copyWith(isDefault: true);
        await _calendarRepo.updateCalendar(updatedDefault);

        // Update any previous default calendar to not be default
        for (final calendar in currentState.calendars) {
          if (calendar.id != event.calendarId && calendar.isDefault) {
            final updated = calendar.copyWith(isDefault: false);
            await _calendarRepo.updateCalendar(updated);
          }
        }

        // Reload calendars to get the updated list
        add(const LoadCalendars());
      } catch (e) {
        emit(CalendarManagementError('Failed to set default calendar: $e'));
      }
    }
  }

  Future<void> _onSyncWebDAVCalendar(
    SyncWebDAVCalendar event,
    Emitter<CalendarManagementState> emit,
  ) async {
    emit(CalendarSyncing(event.calendar.id));

    try {
      // Fetch events from WebDAV
      final events = await _webdavService.syncCalendar(event.calendar);

      // Delete existing events for this calendar
      await _deleteExistingCalendarEvents(event.calendar.id);

      // Save the new events
      for (final event in events) {
        await _eventRepo.createEvent(event);
      }

      emit(CalendarSyncComplete(event.calendar.id, events.length));

      // Reload the full state
      add(const LoadCalendars());
    } catch (e) {
      emit(CalendarSyncError(event.calendar.id, 'Failed to sync WebDAV calendar: $e'));
    }
  }

  Future<void> _onSyncDeviceCalendar(
    SyncDeviceCalendar event,
    Emitter<CalendarManagementState> emit,
  ) async {
    emit(CalendarSyncing(event.calendar.id));

    try {
      if (event.calendar.deviceCalendarId == null) {
        throw Exception('Missing device calendar ID');
      }

      print('Starting sync for device calendar: ${event.calendar.name} (${event.calendar.deviceCalendarId})');

      // Fetch events from device calendar
      final events = await _deviceService.syncDeviceCalendar(event.calendar);
      print('Retrieved ${events.length} events from device calendar');

      // Delete existing events for this calendar
      await _deleteExistingCalendarEvents(event.calendar.id);
      print('Deleted existing events for calendar');

      // Save the new events in batches to avoid memory issues
      const batchSize = 50;
      for (var i = 0; i < events.length; i += batchSize) {
        final end = (i + batchSize < events.length) ? i + batchSize : events.length;
        final batch = events.sublist(i, end);

        for (final event in batch) {
          await _eventRepo.createEvent(event);
        }
        print('Imported events ${i + 1} to $end of ${events.length}');
      }

      emit(CalendarSyncComplete(event.calendar.id, events.length));
      print('Sync completed for calendar ${event.calendar.name}');

      // Reload the full state
      add(const LoadCalendars());
    } catch (e) {
      print('Error syncing device calendar: $e');
      emit(CalendarSyncError(event.calendar.id, 'Failed to sync device calendar: $e'));
    }
  }

  Future<void> _onImportDeviceCalendars(
    ImportDeviceCalendars event,
    Emitter<CalendarManagementState> emit,
  ) async {
    print("_onImportDeviceCalendars called");
    emit(const CalendarManagementLoading());

    try {
      // Get device calendars
      print("Requesting device calendars...");
      final deviceCalendars = await _deviceService.getDeviceCalendars();
      print("Retrieved ${deviceCalendars.length} device calendars in bloc");

      // IMPORTANT: Use await here to ensure the state is emitted
      // before any other operations proceed
      emit(DeviceCalendarsAvailable(deviceCalendars));
      print("DeviceCalendarsAvailable state emitted");
    } catch (e) {
      print("Error importing device calendars: $e");
      emit(CalendarManagementError('Failed to import device calendars: $e'));
    }
  }

  // Helper method to delete existing events for a calendar
  Future<void> _deleteExistingCalendarEvents(String calendarId) async {
    // Get all events for this calendar
    final events = await _eventRepo.getEvents();
    final calendarEvents = events.where((e) => e.calendarId == calendarId).toList();

    // Delete each event
    for (final event in calendarEvents) {
      await _eventRepo.deleteEvent(event.id);
    }
  }

  Future<void> _onImportICSFile(
    ImportICSFile event,
    Emitter<CalendarManagementState> emit,
  ) async {
    emit(CalendarSyncing(event.calendarId));

    try {
      // Find the calendar by ID
      final calendars = await _calendarRepo.getCalendars();
      final calendar = calendars.firstWhere(
        (cal) => cal.id == event.calendarId,
        orElse: () => throw Exception('Calendar not found'),
      );

      // Import events from the ICS file
      final importedEvents = await _icsImportService.importFromFile(
        event.icsFile,
        calendar,
      );

      // Save events to the repository
      for (final event in importedEvents) {
        await _eventRepo.createEvent(event);
      }

      emit(CalendarSyncComplete(event.calendarId, importedEvents.length));

      // Reload calendars
      add(const LoadCalendars());
    } catch (e) {
      emit(CalendarSyncError(event.calendarId, 'Failed to import ICS file: $e'));
    }
  }

  Future<void> _onImportICSContent(
    ImportICSContent event,
    Emitter<CalendarManagementState> emit,
  ) async {
    emit(CalendarSyncing(event.calendarId));

    try {
      // Find the calendar by ID
      final calendars = await _calendarRepo.getCalendars();
      final calendar = calendars.firstWhere(
        (cal) => cal.id == event.calendarId,
        orElse: () => throw Exception('Calendar not found'),
      );

      // Import events from the ICS content
      final importedEvents = await _icsImportService.importFromString(
        event.icsContent,
        calendar,
      );

      // Save events to the repository
      for (final event in importedEvents) {
        await _eventRepo.createEvent(event);
      }

      emit(CalendarSyncComplete(event.calendarId, importedEvents.length));

      // Reload calendars
      add(const LoadCalendars());
    } catch (e) {
      emit(CalendarSyncError(event.calendarId, 'Failed to import ICS content: $e'));
    }
  }
}
