import 'package:flutter/material.dart';
import 'package:supabase_sync_calendar/core/models/calendar_event_model.dart';
import 'package:supabase_sync_calendar/core/utils/time_utils.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:uuid/uuid.dart';

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

  @override
  void initState() {
    super.initState();
    _calendarController = CalendarController();
    _calendarController.view = widget.calendarView;
  }

  @override
  void dispose() {
    _calendarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SfCalendar(
      controller: _calendarController,
      view: widget.calendarView,
      dataSource: _getCalendarDataSource(),
      allowDragAndDrop: true,
      allowAppointmentResize: true,
      timeSlotViewSettings: TimeSlotViewSettings(
        timeInterval: Duration(minutes: widget.timeSnapInterval),
        timeIntervalHeight: widget.timeIntervalHeight,
        timeFormat: 'HH:mm',
        startHour: widget.startHour,
        endHour: widget.endHour,
      ),
      monthViewSettings: const MonthViewSettings(
        appointmentDisplayMode: MonthAppointmentDisplayMode.appointment,
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
    );
  }

  _AppointmentDataSource _getCalendarDataSource() {
    List<Appointment> appointments = widget.events.map((event) {
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

    return _AppointmentDataSource(appointments);
  }

  DateTime _snapTimeToInterval(DateTime time) {
    return TimeUtils.snapToInterval(time, widget.timeSnapInterval);
  }

  void _handleCalendarTap(CalendarTapDetails details) {
    if (details.targetElement == CalendarElement.appointment &&
        details.appointments != null &&
        details.appointments!.isNotEmpty) {
      final appointment = details.appointments!.first;
      final String eventId = appointment.id as String;

      // Find the event
      final event = widget.events.firstWhere(
        (e) => e.id == eventId,
        orElse: () => throw Exception('Event not found'),
      );

      // Show event details dialog
      _showEventDetailsDialog(event);
    } else if (details.targetElement == CalendarElement.calendarCell &&
        details.date != null) {
      // Create new event when clicking on empty cell
      final snappedTime = _snapTimeToInterval(details.date!);
      final endTime =
          snappedTime.add(Duration(minutes: widget.timeSnapInterval));

      _showAddEventDialog(snappedTime, endTime);
    }
  }

  void _showEventDetailsDialog(CalendarEventModel event) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: event.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    event.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _formatDateRange(event.start, event.end, event.wholeDay),
              style: TextStyle(color: Colors.grey[700]),
            ),
            if (event.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(event.description),
            ],
            if (event.reminder != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.notifications, size: 16),
                  const SizedBox(width: 4),
                  Text('Reminder: ${_formatDateTime(event.reminder!)}'),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showEditEventDialog(event);
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showDeleteConfirmation(event);
                  },
                  icon: const Icon(Icons.delete),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}, ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateRange(DateTime start, DateTime end, bool wholeDay) {
    if (wholeDay) {
      if (start.year == end.year &&
          start.month == end.month &&
          start.day == end.day) {
        return 'All day, ${start.day}/${start.month}/${start.year}';
      } else {
        return 'All day, ${start.day}/${start.month}/${start.year} - ${end.day}/${end.month}/${end.year}';
      }
    } else {
      if (start.year == end.year &&
          start.month == end.month &&
          start.day == end.day) {
        return '${start.day}/${start.month}/${start.year}, ${start.hour}:${start.minute.toString().padLeft(2, '0')} - ${end.hour}:${end.minute.toString().padLeft(2, '0')}';
      } else {
        return '${start.day}/${start.month}/${start.year}, ${start.hour}:${start.minute.toString().padLeft(2, '0')} - ${end.day}/${end.month}/${end.year}, ${end.hour}:${end.minute.toString().padLeft(2, '0')}';
      }
    }
  }

  void _showAddEventDialog(DateTime startTime, DateTime endTime) {
    showDialog(
      context: context,
      builder: (context) => EventEditDialog(
        startTime: startTime,
        endTime: endTime,
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
      ),
    );
  }

  void _showEditEventDialog(CalendarEventModel event) {
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
      ),
    );
  }

  void _showDeleteConfirmation(CalendarEventModel event) {
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

  void _handleCalendarLongPress(CalendarLongPressDetails details) {
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

  @override
  void didUpdateWidget(SfCalendarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update the calendar view if it changed
    if (oldWidget.calendarView != widget.calendarView) {
      _calendarController.view = widget.calendarView;
    }
  }
}

class _AppointmentDataSource extends CalendarDataSource {
  _AppointmentDataSource(List<Appointment> source) {
    appointments = source;
  }
}

// This is a placeholder for the EventEditDialog class
// You should define this in another file or replace this with your existing implementation
class EventEditDialog extends StatefulWidget {
  final String? title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final Color? color;
  final bool? wholeDay;
  final String? calendarId;
  final DateTime? reminder;
  final Function(String title, String description, DateTime start, DateTime end,
      Color color, bool wholeDay, String calendarId, DateTime? reminder) onSave;

  const EventEditDialog({
    super.key,
    this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    this.color,
    this.wholeDay,
    this.calendarId,
    this.reminder,
    required this.onSave,
  });

  @override
  State<EventEditDialog> createState() => _EventEditDialogState();
}

class _EventEditDialogState extends State<EventEditDialog> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late DateTime _startTime;
  late DateTime _endTime;
  late Color _color;
  late bool _wholeDay;
  late String _calendarId;
  DateTime? _reminder;

  final List<Color> _availableColors = [
    Colors.blue,
    Colors.green,
    Colors.red,
    Colors.orange,
    Colors.purple,
    Colors.teal,
  ];

  final List<String> _availableCalendars = [
    'default',
    'work',
    'personal',
    'family'
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.title ?? '');
    _descriptionController =
        TextEditingController(text: widget.description ?? '');
    _startTime = widget.startTime;
    _endTime = widget.endTime;
    _color = widget.color ?? Colors.blue;
    _wholeDay = widget.wholeDay ?? false;
    _calendarId = widget.calendarId ?? 'default';
    _reminder = widget.reminder;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title != null && widget.title != ''
          ? 'Edit Event'
          : 'New Event'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Calendar and Whole Day options
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _calendarId,
                    decoration: const InputDecoration(
                      labelText: 'Calendar',
                    ),
                    items: _availableCalendars
                        .map((cal) => DropdownMenuItem<String>(
                              value: cal,
                              child: Text(cal),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _calendarId = value ?? 'default';
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Row(
                  children: [
                    Checkbox(
                      value: _wholeDay,
                      onChanged: (value) {
                        setState(() {
                          _wholeDay = value ?? false;
                        });
                      },
                    ),
                    const Text('All Day'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Date/Time selection based on whole day status
            if (_wholeDay) ...[
              // Date pickers for whole day events
              _buildDatePicker(
                label: 'Start',
                dateTime: _startTime,
                onChanged: (dateTime) {
                  setState(() {
                    // For whole day, set to start of day
                    _startTime = DateTime(
                      dateTime.year,
                      dateTime.month,
                      dateTime.day,
                    );

                    // Ensure end date is not before start date
                    if (_endTime.isBefore(_startTime)) {
                      _endTime = _startTime
                          .add(const Duration(days: 1))
                          .subtract(const Duration(seconds: 1));
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
              _buildDatePicker(
                label: 'End',
                dateTime: _endTime,
                onChanged: (dateTime) {
                  setState(() {
                    // For whole day, set to end of day
                    _endTime = DateTime(
                      dateTime.year,
                      dateTime.month,
                      dateTime.day,
                      23,
                      59,
                      59,
                    );

                    // Ensure start date is not after end date
                    if (_startTime.isAfter(_endTime)) {
                      _startTime = DateTime(
                        _endTime.year,
                        _endTime.month,
                        _endTime.day,
                      );
                    }
                  });
                },
              ),
            ] else ...[
              // Date/time pickers for regular events
              _buildDateTimePicker(
                label: 'Start',
                dateTime: _startTime,
                onChanged: (dateTime) {
                  setState(() {
                    _startTime = dateTime;
                    // Adjust end time if needed
                    if (_endTime.isBefore(_startTime)) {
                      _endTime = _startTime.add(const Duration(hours: 1));
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
              _buildDateTimePicker(
                label: 'End',
                dateTime: _endTime,
                onChanged: (dateTime) {
                  setState(() {
                    _endTime = dateTime;
                    // Adjust start time if needed
                    if (_startTime.isAfter(_endTime)) {
                      _startTime = _endTime.subtract(const Duration(hours: 1));
                    }
                  });
                },
              ),
            ],

            const SizedBox(height: 16),

            // Reminder
            Row(
              children: [
                const Text('Reminder:'),
                const SizedBox(width: 8),
                Expanded(
                  child: _reminder == null
                      ? OutlinedButton(
                          onPressed: _pickReminderDateTime,
                          child: const Text('Set Reminder'),
                        )
                      : Row(
                          children: [
                            Text(
                                '${_reminder!.day}/${_reminder!.month} at ${_reminder!.hour}:${_reminder!.minute.toString().padLeft(2, '0')}'),
                            IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _reminder = null;
                                });
                              },
                            ),
                          ],
                        ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Color picker
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Event Color',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableColors.map((color) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _color = color;
                        });
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _color == color
                                ? Colors.black
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_titleController.text.trim().isNotEmpty) {
              widget.onSave(
                _titleController.text,
                _descriptionController.text,
                _startTime,
                _endTime,
                _color,
                _wholeDay,
                _calendarId,
                _reminder,
              );
              Navigator.of(context).pop();
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  // Date picker for whole day events
  Widget _buildDatePicker({
    required String label,
    required DateTime dateTime,
    required Function(DateTime) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label Date:',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final pickedDate = await showDatePicker(
              context: context,
              initialDate: dateTime,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );

            if (pickedDate != null) {
              onChanged(pickedDate);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 18),
                const SizedBox(width: 8),
                Text('${dateTime.day}/${dateTime.month}/${dateTime.year}'),
                const Spacer(),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Combined date and time picker for regular events
  Widget _buildDateTimePicker({
    required String label,
    required DateTime dateTime,
    required Function(DateTime) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            // Date part
            Expanded(
              child: InkWell(
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: dateTime,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );

                  if (pickedDate != null) {
                    onChanged(DateTime(
                      pickedDate.year,
                      pickedDate.month,
                      pickedDate.day,
                      dateTime.hour,
                      dateTime.minute,
                    ));
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 18),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${dateTime.day}/${dateTime.month}/${dateTime.year}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 16),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Time part
            Expanded(
              child: InkWell(
                onTap: () async {
                  final pickedTime = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(dateTime),
                  );

                  if (pickedTime != null) {
                    onChanged(DateTime(
                      dateTime.year,
                      dateTime.month,
                      dateTime.day,
                      pickedTime.hour,
                      pickedTime.minute,
                    ));
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, size: 18),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Reminder date/time picker
  Future<void> _pickReminderDateTime() async {
    final now = DateTime.now();
    final initialDate = _reminder ?? now;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
      );

      if (pickedTime != null) {
        setState(() {
          _reminder = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }
}
