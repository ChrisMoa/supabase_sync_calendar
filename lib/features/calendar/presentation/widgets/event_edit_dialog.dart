import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_sync_calendar/core/utils/time_utils.dart';

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
  final int _timeSnapInterval = 15; // Default to 15 minutes

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
  ]; // Placeholder for future implementation

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

            // Whole Day Checkbox
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
                const Text('All Day Event'),
              ],
            ),

            // Calendar Dropdown
            DropdownButtonFormField<String>(
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
            const SizedBox(height: 16),

            // Date/Time pickers
            if (!_wholeDay) ...[
              _buildDateTimePickers(
                label: 'Start',
                dateTime: _startTime,
                onChanged: (dateTime) {
                  setState(() {
                    _startTime = dateTime;
                    // Ensure end time is after start time
                    if (_endTime.isBefore(_startTime)) {
                      // Keep the duration the same
                      Duration duration =
                          widget.endTime.difference(widget.startTime);
                      _endTime = _startTime.add(duration);
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
              _buildDateTimePickers(
                label: 'End',
                dateTime: _endTime,
                onChanged: (dateTime) {
                  setState(() {
                    _endTime = dateTime;
                    // Ensure start time is before end time
                    if (_startTime.isAfter(_endTime)) {
                      // Keep the duration the same
                      Duration duration =
                          widget.endTime.difference(widget.startTime);
                      _startTime = _endTime.subtract(duration);
                    }
                  });
                },
              ),
            ] else ...[
              // Only date pickers for whole day events
              _buildDatePicker(
                label: 'Start Date',
                dateTime: _startTime,
                onChanged: (dateTime) {
                  setState(() {
                    _startTime = DateTime(
                      dateTime.year,
                      dateTime.month,
                      dateTime.day,
                    );

                    // Ensure end date is not before start date
                    if (_endTime.isBefore(_startTime)) {
                      _endTime = _startTime;
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
              _buildDatePicker(
                label: 'End Date',
                dateTime: _endTime,
                onChanged: (dateTime) {
                  setState(() {
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
                      _startTime = _endTime;
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
                                DateFormat('MMM d, h:mm a').format(_reminder!)),
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
            _buildColorPicker(),
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

  Widget _buildDatePicker({
    required String label,
    required DateTime dateTime,
    required Function(DateTime) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                Text(
                  DateFormat('EEE, MMM d, yyyy').format(dateTime),
                ),
                const Spacer(),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),
      ],
    );
  }

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

  Widget _buildDateTimePickers({
    required String label,
    required DateTime dateTime,
    required Function(DateTime) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label Time:',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        // Date picker
        InkWell(
          onTap: () async {
            final pickedDate = await showDatePicker(
              context: context,
              initialDate: dateTime,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );

            if (pickedDate != null) {
              final newDateTime = DateTime(
                pickedDate.year,
                pickedDate.month,
                pickedDate.day,
                dateTime.hour,
                dateTime.minute,
              );
              onChanged(newDateTime);
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
                Text(
                  DateFormat('EEE, MMM d, yyyy').format(dateTime),
                ),
                const Spacer(),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Time picker
        InkWell(
          onTap: () async {
            final pickedTime = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(dateTime),
              builder: (BuildContext context, Widget? child) {
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    alwaysUse24HourFormat: false,
                  ),
                  child: child!,
                );
              },
            );

            if (pickedTime != null) {
              DateTime newDateTime = DateTime(
                dateTime.year,
                dateTime.month,
                dateTime.day,
                pickedTime.hour,
                pickedTime.minute,
              );

              // Snap the time to the nearest interval (15 minutes)
              newDateTime =
                  TimeUtils.snapToInterval(newDateTime, _timeSnapInterval);
              onChanged(newDateTime);
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
                const Icon(Icons.access_time, size: 18),
                const SizedBox(width: 8),
                Text(
                  DateFormat('h:mm a').format(dateTime),
                ),
                const Spacer(),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColorPicker() {
    return Column(
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
                    color: _color == color ? Colors.black : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
