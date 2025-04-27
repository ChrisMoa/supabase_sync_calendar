// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_sync_calendar/core/models/calendar_event_model.dart';
import 'package:supabase_sync_calendar/core/models/calendar_model.dart';
import 'package:supabase_sync_calendar/core/utils/time_utils.dart';
import 'package:supabase_sync_calendar/features/calendar/domain/blocs/calendar_management_bloc/calendar_management_bloc.dart';
import 'package:supabase_sync_calendar/features/calendar/domain/blocs/calendar_management_bloc/calendar_management_state.dart';
import 'package:supabase_sync_calendar/features/calendar/presentation/widgets/event_edit_dialog.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:uuid/uuid.dart';

import '../widgets/event_brief_info.dart';

class SfCalendarWidget extends StatefulWidget {
  /// The type of calendar view to display
  final CalendarView calendarView;

  /// List of events to display on the calendar
  final List<CalendarEventModel> events;

  /// Time interval for snapping events in minutes
  final int timeSnapInterval;

  /// Callback when an event is added
  final Function(CalendarEventModel)? onEventAdd;

  /// Callback when an event is updated
  final Function(CalendarEventModel)? onEventUpdate;

  /// Callback when an event is deleted
  final Function(String)? onEventDelete;

  /// Callback when the calendar view changes
  final Function(CalendarView)? onViewChanged;

  /// Callback when creating a series from an event
  final Function(CalendarEventModel)? onMakeSeries;

  /// Start hour of the day view (default: 7)
  final double startHour;

  /// End hour of the day view (default: 20)
  final double endHour;

  /// Height of each time slot in the day view
  final double timeIntervalHeight;

  const SfCalendarWidget({
    super.key,
    required this.calendarView,
    required this.events,
    this.timeSnapInterval = 15,
    this.onEventAdd,
    this.onEventUpdate,
    this.onEventDelete,
    this.onViewChanged,
    this.onMakeSeries,
    this.startHour = 7,
    this.endHour = 20,
    this.timeIntervalHeight = 50,
  });

  @override
  State<SfCalendarWidget> createState() => _SfCalendarWidgetState();
}

class _SfCalendarWidgetState extends State<SfCalendarWidget> {
  late CalendarController _calendarController;
  final _uuid = const Uuid();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _calendarController = CalendarController();
    _calendarController.view = widget.calendarView;
  }

  @override
  void dispose() {
    _removeOverlay();
    _calendarController.dispose();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _removeOverlay,
      child: SfCalendar(
        controller: _calendarController,
        view: widget.calendarView,
        dataSource: _getCalendarDataSource(),
        allowDragAndDrop: true,
        allowAppointmentResize: true,
        showNavigationArrow: true,
        timeSlotViewSettings: TimeSlotViewSettings(
          timeInterval: Duration(minutes: widget.timeSnapInterval),
          timeIntervalHeight: widget.timeIntervalHeight,
          timeFormat: 'HH:mm',
          startHour: widget.startHour,
          endHour: widget.endHour,
        ),
        monthViewSettings: const MonthViewSettings(
          appointmentDisplayMode: MonthAppointmentDisplayMode.appointment,
          showAgenda: true,
        ),
        onTap: _handleCalendarTap,
        onLongPress: _handleCalendarLongPress,
        onViewChanged: (details) {
          if (widget.onViewChanged != null) {
            widget.onViewChanged!(_calendarController.view!);
          }
        },
        appointmentBuilder: (context, details) {
          final Appointment appointment = details.appointments.first;
          return Container(
            decoration: BoxDecoration(
              color: appointment.color,
              borderRadius: BorderRadius.circular(4),
            ),
            padding: const EdgeInsets.all(2),
            child: Text(
              appointment.subject,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          );
        },
        dragAndDropSettings: const DragAndDropSettings(
          allowNavigation: true,
          allowScroll: true,
          autoNavigateDelay: Duration(seconds: 1),
          indicatorTimeFormat: 'HH:mm',
          showTimeIndicator: true,
        ),
        onDragStart: _handleDragStart,
        onDragUpdate: _handleDragUpdate,
        onDragEnd: _handleDragEnd,
        onAppointmentResizeStart: _handleResizeStart,
        onAppointmentResizeUpdate: _handleResizeUpdate,
        onAppointmentResizeEnd: _handleResizeEnd,
      ),
    );
  }

  _AppointmentDataSource _getCalendarDataSource() {
    print(
        'SfCalendarWidget: Converting ${widget.events.length} events to appointments');

    List<Appointment> appointments = widget.events.map((event) {
      print(
          'Processing event: ${event.id}, ${event.title}, ${event.start}-${event.end}');
      return Appointment(
        id: event.id,
        subject: event.title,
        notes: event.description,
        startTime: event.start,
        endTime: event.end,
        color: event.color,
        isAllDay: event.wholeDay,
        resourceIds: [event.calendarId],
      );
    }).toList();

    print('Created ${appointments.length} appointments for calendar');
    return _AppointmentDataSource(appointments);
  }

  DateTime _snapTimeToInterval(DateTime time) {
    return TimeUtils.snapToInterval(time, widget.timeSnapInterval);
  }

  void _handleCalendarTap(CalendarTapDetails details) {
    // Remove any existing overlay first
    _removeOverlay();

    if (details.targetElement == CalendarElement.appointment &&
        details.appointments != null &&
        details.appointments!.isNotEmpty) {
      final appointment = details.appointments!.first as Appointment;
      final String eventId =
          appointment.id.toString(); // Fix: Use toString() to safely get ID

      // Find the event
      final event = widget.events.firstWhere(
        (e) => e.id == eventId,
        orElse: () => throw Exception('Event not found'),
      );

      // Show custom event info popup
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showEventInfo(event, details);
      });
    } else if (details.targetElement == CalendarElement.calendarCell &&
        details.date != null) {
      // Create new event when clicking on empty cell
      final snappedTime = _snapTimeToInterval(details.date!);
      final endTime =
          snappedTime.add(Duration(minutes: widget.timeSnapInterval));

      _showAddEventDialog(snappedTime, endTime);
    }
  }

  void _showEventInfo(CalendarEventModel event, CalendarTapDetails details) {
    // Get the calendar widget's position and size
    final RenderBox calendarRenderBox = context.findRenderObject() as RenderBox;
    final calendarPosition = calendarRenderBox.localToGlobal(Offset.zero);
    final calendarSize = calendarRenderBox.size;

    // Calculate the position based on tap location
    // Since bounds isn't available, use the tap position directly if available
    Offset position;

    if (details.targetElement == CalendarElement.appointment) {
      // For appointments, use either details.position or a reasonable default
      if (details.date != null) {
        // Try to calculate position based on the date/time
        final timeAxisHeight =
            calendarSize.height / (widget.endHour - widget.startHour);
        final hourOffset = details.date!.hour -
            widget.startHour.toInt() +
            (details.date!.minute / 60.0);

        position = Offset(
          calendarPosition.dx + 20,
          calendarPosition.dy + (hourOffset * timeAxisHeight),
        );
      } else {
        // Fallback position if date isn't available
        position = Offset(
          calendarPosition.dx + 20,
          calendarPosition.dy + 100,
        );
      }
    } else {
      // Default position for other elements
      position = Offset(
        calendarPosition.dx + calendarSize.width * 0.25,
        calendarPosition.dy + calendarSize.height * 0.3,
      );
    }

    // Ensure the popup won't go off-screen
    final screenSize = MediaQuery.of(context).size;
    const popupWidth = 300.0;
    const popupHeight = 200.0;

    if (position.dx + popupWidth > screenSize.width) {
      position = Offset(screenSize.width - popupWidth - 20, position.dy);
    }

    if (position.dx < 10) {
      position = Offset(10, position.dy);
    }

    if (position.dy < 10) {
      position = Offset(position.dx, 10);
    }

    if (position.dy > screenSize.height - popupHeight) {
      position = Offset(position.dx, screenSize.height - popupHeight - 20);
    }

    // Create and show the overlay
    _overlayEntry = OverlayEntry(
      builder: (context) => EventBriefInfo(
        event: event,
        position: position,
        onClose: _removeOverlay,
        onEdit: _showEditEventDialog,
        onDuplicate: _handleEventDuplicate,
        onDelete: _handleEventDelete,
        onDurationChange: widget.onEventUpdate,
        onMakeSeries: widget.onMakeSeries, // Pass the callback from widget
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _handleEventDuplicate(CalendarEventModel event) {
    final duplicatedEvent = event.copyWith(
      id: _uuid.v4(),
    );

    if (widget.onEventAdd != null) {
      widget.onEventAdd!(duplicatedEvent);
    }
  }

  void _showAddEventDialog(DateTime startTime, DateTime endTime) {
    // Get available calendars from CalendarManagementBloc
    final calendarManagementBloc =
        BlocProvider.of<CalendarManagementBloc>(context, listen: false);
    final calendarManagementState = calendarManagementBloc.state;
    List<CalendarModel> availableCalendars = [];
    CalendarModel? defaultCalendar;

    if (calendarManagementState is CalendarManagementLoaded) {
      // Filter out invalid calendars to avoid any issues
      availableCalendars = calendarManagementState.calendars
          .where((cal) => cal.id.isNotEmpty)
          .toList();
      defaultCalendar = calendarManagementState.defaultCalendar;

      // Debug output
      print('Found ${availableCalendars.length} calendars for dropdown');
      for (var cal in availableCalendars) {
        print('Calendar: ${cal.id}, ${cal.name}, ${cal.color}');
      }
    } else {
      print(
          'CalendarManagementState is not loaded: ${calendarManagementState.runtimeType}');
    }

    // Fallback if no calendars available
    if (availableCalendars.isEmpty) {
      // Create a default calendar for display purposes
      availableCalendars = [
        CalendarModel(
          id: 'default',
          name: 'Default Calendar',
          color: Colors.blue,
          userId: '',
          type: CalendarType.local,
          isDefault: true,
        )
      ];
      defaultCalendar = availableCalendars.first;
      print('Using fallback default calendar');
    }

    showDialog(
      context: context,
      builder: (context) => EventEditDialog(
        startTime: startTime,
        endTime: endTime,
        calendarId: defaultCalendar?.id ?? availableCalendars.first.id,
        color: defaultCalendar?.color ?? availableCalendars.first.color,
        onSave: (title, description, start, end, color, wholeDay, calendarId,
            reminder) {
          final newEvent = CalendarEventModel(
            id: _uuid.v4(),
            title: title,
            description: description,
            start: start,
            end: end,
            color: color,
            userId: '', // This will be set in the bloc
            wholeDay: wholeDay,
            calendarId: calendarId,
            reminder: reminder,
            appendixes: const [],
          );

          if (widget.onEventAdd != null) {
            widget.onEventAdd!(newEvent);
          }
        },
        calendars: availableCalendars,
      ),
    );
  }

  void _showEditEventDialog(CalendarEventModel event) {
    // Get available calendars from CalendarManagementBloc
    final calendarManagementBloc =
        BlocProvider.of<CalendarManagementBloc>(context, listen: false);
    final calendarManagementState = calendarManagementBloc.state;
    List<CalendarModel> availableCalendars = [];

    if (calendarManagementState is CalendarManagementLoaded) {
      // Filter out invalid calendars
      availableCalendars = calendarManagementState.calendars
          .where((cal) => cal.id.isNotEmpty)
          .toList();

      // Debug output
      print('Edit dialog: Found ${availableCalendars.length} calendars');
      for (var cal in availableCalendars) {
        print('Calendar: ${cal.id}, ${cal.name}, ${cal.color}');
      }
    } else {
      print(
          'Edit dialog: CalendarManagementState is not loaded: ${calendarManagementState.runtimeType}');
    }

    // Ensure the event's calendar is in the list, or add it if missing
    bool eventCalendarExists =
        availableCalendars.any((cal) => cal.id == event.calendarId);

    if (!eventCalendarExists && event.calendarId.isNotEmpty) {
      // Add the event's calendar as a temporary item to avoid dropdown errors
      availableCalendars.add(
        CalendarModel(
          id: event.calendarId,
          name: 'Calendar',
          color: event.color,
          userId: '',
          type: CalendarType.local,
          isDefault: false,
        ),
      );
    }

    // Fallback if no calendars available
    if (availableCalendars.isEmpty) {
      availableCalendars = [
        CalendarModel(
          id: 'default',
          name: 'Default Calendar',
          color: Colors.blue,
          userId: '',
          type: CalendarType.local,
          isDefault: true,
        )
      ];
    }

    showDialog(
      context: context,
      builder: (context) => EventEditDialog(
        title: event.title,
        description: event.description,
        startTime: event.start,
        endTime: event.end,
        color: event.color,
        wholeDay: event.wholeDay,
        calendarId: event.calendarId,
        reminder: event.reminder,
        onSave: (title, description, start, end, color, wholeDay, calendarId,
            reminder) {
          final updatedEvent = event.copyWith(
            title: title,
            description: description,
            start: start,
            end: end,
            color: color,
            wholeDay: wholeDay,
            calendarId: calendarId,
            reminder: reminder,
          );

          if (widget.onEventUpdate != null) {
            widget.onEventUpdate!(updatedEvent);
          }
        },
        calendars: availableCalendars,
      ),
    );
  }

  void _handleCalendarLongPress(CalendarLongPressDetails details) {
    _removeOverlay();

    if (details.targetElement == CalendarElement.calendarCell &&
        details.date != null) {
      final DateTime date = details.date!;

      // Snap the time to the nearest interval
      final DateTime snappedTime = _snapTimeToInterval(date);
      final DateTime endTime =
          snappedTime.add(Duration(minutes: widget.timeSnapInterval));

      _showAddEventDialog(snappedTime, endTime);
    }
  }

  // Drag handlers with proper database syncing
  void _handleDragStart(AppointmentDragStartDetails details) {
    _removeOverlay();
  }

  void _handleDragUpdate(AppointmentDragUpdateDetails details) {
    // Optional visual feedback
  }

  void _handleDragEnd(AppointmentDragEndDetails details) {
    if (details.appointment != null && details.droppingTime != null) {
      // First get the appointment and cast it correctly
      final appointment = details.appointment as Appointment;
      // Now access the id safely
      final String eventId = appointment.id.toString();

      try {
        final event = widget.events.firstWhere((e) => e.id == eventId);

        // Calculate the duration to preserve it
        final Duration duration = event.end.difference(event.start);

        // Create new start and end times based on the drop position
        final DateTime newStart = _snapTimeToInterval(details.droppingTime!);
        final DateTime newEnd = newStart.add(duration);

        // Create updated event
        final updatedEvent = event.copyWith(
          start: newStart,
          end: newEnd,
        );

        // Update the event through callback
        if (widget.onEventUpdate != null) {
          widget.onEventUpdate!(updatedEvent);
        }
      } catch (e) {
        print('Error updating event: $e');
      }
    }
  }

  // Resize handlers with proper database syncing
  void _handleResizeStart(AppointmentResizeStartDetails details) {
    _removeOverlay();
  }

  void _handleResizeUpdate(AppointmentResizeUpdateDetails details) {
    // Optional visual feedback
  }

  void _handleResizeEnd(AppointmentResizeEndDetails details) {
    if (details.appointment != null) {
      final String eventId = details.appointment!.id.toString();
      final event = widget.events.firstWhere((e) => e.id == eventId);

      // Get the new start and end times from the resize operation
      final DateTime newStart = details.startTime ?? event.start;
      final DateTime newEnd = details.endTime ?? event.end;

      // Snap times to interval
      final DateTime snappedStart = _snapTimeToInterval(newStart);
      final DateTime snappedEnd = _snapTimeToInterval(newEnd);

      // Create updated event
      final updatedEvent = event.copyWith(
        start: snappedStart,
        end: snappedEnd,
      );

      // Update the event through callback
      if (widget.onEventUpdate != null) {
        widget.onEventUpdate!(updatedEvent);
      }
    }
  }

  @override
  void didUpdateWidget(SfCalendarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update the calendar view if it changed
    if (oldWidget.calendarView != widget.calendarView) {
      _calendarController.view = widget.calendarView;
    }
  }

  void _handleEventDelete(CalendarEventModel event) {
    // Special handling for series events
    if (event.seriesId != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Event'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Delete "${event.title}"?'),
              const SizedBox(height: 16),
              const Text('This event is part of a series. Do you want to:'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (widget.onEventDelete != null) {
                  widget.onEventDelete!(event.id);
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
              child: const Text('Delete This Event Only'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Special handling to delete all events in series
                _handleDeleteSeriesEvents(event);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete Entire Series'),
            ),
          ],
        ),
      );
    } else {
      // Regular event deletion
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Event'),
          content: Text('Are you sure you want to delete "${event.title}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (widget.onEventDelete != null) {
                  widget.onEventDelete!(event.id);
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
    }
  }

  void _handleDeleteSeriesEvents(CalendarEventModel event) {
    // This would be handled by your series management bloc
    // For now, we'll use a simple approach of finding and deleting all events with the same seriesId

    if (event.seriesId != null &&
        widget.events.isNotEmpty &&
        widget.onEventDelete != null) {
      // Get all events in the same series
      final seriesEvents =
          widget.events.where((e) => e.seriesId == event.seriesId).toList();

      // Delete each event in the series
      for (final seriesEvent in seriesEvents) {
        widget.onEventDelete!(seriesEvent.id);
      }
    }
  }
}

class _AppointmentDataSource extends CalendarDataSource {
  _AppointmentDataSource(List<Appointment> source) {
    appointments = source;
  }
}
