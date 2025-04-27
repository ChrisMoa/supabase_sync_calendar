import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_sync_calendar/core/models/calendar_event_model.dart';
import 'package:supabase_sync_calendar/core/models/calendar_event_series_model.dart';

class EventSeriesDialog extends StatefulWidget {
  final CalendarEventModel templateEvent;
  final CalendarEventSeriesModel? existingSeries;
  final Function(CalendarEventSeriesModel) onSave;

  const EventSeriesDialog({
    super.key,
    required this.templateEvent,
    this.existingSeries,
    required this.onSave,
  });

  @override
  State<EventSeriesDialog> createState() => _EventSeriesDialogState();
}

class _EventSeriesDialogState extends State<EventSeriesDialog> {
  late SeriesRepeatType _repeatType;
  late int _repeatInterval;
  late List<int> _selectedDaysOfWeek;
  late SeriesEndType _endType;
  late int _occurrences;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    // Initialize with existing series values or defaults
    if (widget.existingSeries != null) {
      _repeatType = widget.existingSeries!.repeatType;
      _repeatInterval = widget.existingSeries!.repeatInterval;
      _selectedDaysOfWeek = List.from(widget.existingSeries!.repeatDaysOfWeek);
      _endType = widget.existingSeries!.endType;
      _occurrences = widget.existingSeries!.occurrences ?? 10;
      _endDate = widget.existingSeries!.endDate ??
          DateTime.now().add(const Duration(days: 90));
    } else {
      // Default values for new series
      _repeatType = SeriesRepeatType.weekly;
      _repeatInterval = 1;
      _selectedDaysOfWeek = [
        widget.templateEvent.start.weekday
      ]; // Default to event's day of week
      _endType = SeriesEndType.afterOccurrences;
      _occurrences = 10; // Default to 10 occurrences
      _endDate =
          DateTime.now().add(const Duration(days: 90)); // Default to 90 days
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existingSeries != null
          ? 'Edit Event Series'
          : 'Create Event Series'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRepeatTypeSection(),
            const SizedBox(height: 16),
            if (_repeatType == SeriesRepeatType.weekly)
              _buildDaysOfWeekSelector(),
            const SizedBox(height: 16),
            _buildEndTypeSection(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveSeries,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildRepeatTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Repeat',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<SeriesRepeatType>(
                value: _repeatType,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: [
                  DropdownMenuItem(
                    value: SeriesRepeatType.none,
                    child: Text('None (Remove series)'),
                  ),
                  DropdownMenuItem(
                    value: SeriesRepeatType.daily,
                    child: Text('Daily'),
                  ),
                  DropdownMenuItem(
                    value: SeriesRepeatType.weekly,
                    child: Text('Weekly'),
                  ),
                  DropdownMenuItem(
                    value: SeriesRepeatType.monthly,
                    child: Text('Monthly'),
                  ),
                  DropdownMenuItem(
                    value: SeriesRepeatType.yearly,
                    child: Text('Yearly'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _repeatType = value;
                      // Reset days of week if switching from weekly
                      if (value != SeriesRepeatType.weekly) {
                        _selectedDaysOfWeek = [];
                      } else if (_selectedDaysOfWeek.isEmpty) {
                        _selectedDaysOfWeek = [
                          widget.templateEvent.start.weekday
                        ];
                      }
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 70,
              child: TextFormField(
                initialValue: _repeatInterval.toString(),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final interval = int.tryParse(value);
                  if (interval != null && interval > 0) {
                    setState(() {
                      _repeatInterval = interval;
                    });
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDaysOfWeekSelector() {
    const List<String> dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Repeat on',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(7, (index) {
            final dayNumber = index + 1; // 1-7, Monday-Sunday
            final isSelected = _selectedDaysOfWeek.contains(dayNumber);

            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    if (_selectedDaysOfWeek.length > 1) {
                      _selectedDaysOfWeek.remove(dayNumber);
                    }
                  } else {
                    _selectedDaysOfWeek.add(dayNumber);
                    _selectedDaysOfWeek.sort();
                  }
                });
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.grey,
                  ),
                ),
                child: Center(
                  child: Text(
                    dayLabels[index],
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildEndTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ends',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        RadioListTile<SeriesEndType>(
          title: const Text('Never'),
          value: SeriesEndType.never,
          groupValue: _endType,
          contentPadding: EdgeInsets.zero,
          onChanged: (value) {
            setState(() {
              _endType = value!;
            });
          },
        ),
        RadioListTile<SeriesEndType>(
          title: Row(
            children: [
              const Text('After'),
              const SizedBox(width: 8),
              SizedBox(
                width: 60,
                child: TextFormField(
                  initialValue: _occurrences.toString(),
                  enabled: _endType == SeriesEndType.afterOccurrences,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final occurrences = int.tryParse(value);
                    if (occurrences != null && occurrences > 0) {
                      setState(() {
                        _occurrences = occurrences;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              const Text('occurrences'),
            ],
          ),
          value: SeriesEndType.afterOccurrences,
          groupValue: _endType,
          contentPadding: EdgeInsets.zero,
          onChanged: (value) {
            setState(() {
              _endType = value!;
            });
          },
        ),
        RadioListTile<SeriesEndType>(
          title: Row(
            children: [
              const Text('On'),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap:
                      _endType == SeriesEndType.onDate ? _selectEndDate : null,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: _endType == SeriesEndType.onDate
                              ? Colors.blue
                              : Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      DateFormat('MMM d, yyyy').format(_endDate),
                      style: TextStyle(
                        color: _endType == SeriesEndType.onDate
                            ? Colors.black
                            : Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          value: SeriesEndType.onDate,
          groupValue: _endType,
          contentPadding: EdgeInsets.zero,
          onChanged: (value) {
            setState(() {
              _endType = value!;
            });
          },
        ),
      ],
    );
  }

  Future<void> _selectEndDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      setState(() {
        _endDate = pickedDate;
      });
    }
  }

  void _saveSeries() {
    // Create the series model
    final series = CalendarEventSeriesModel(
      id: widget.existingSeries?.id ?? '',
      userId: widget.templateEvent.userId,
      repeatType: _repeatType,
      repeatInterval: _repeatInterval,
      repeatDaysOfWeek:
          _repeatType == SeriesRepeatType.weekly ? _selectedDaysOfWeek : [],
      endType: _endType,
      occurrences:
          _endType == SeriesEndType.afterOccurrences ? _occurrences : null,
      endDate: _endType == SeriesEndType.onDate ? _endDate : null,
      templateEventId: widget.templateEvent.id,
    );

    widget.onSave(series);
    Navigator.of(context).pop();
  }
}
