import 'package:flutter/material.dart';
import 'package:supabase_sync_calendar/core/models/calendar_model.dart';

class CalendarEditDialog extends StatefulWidget {
  final CalendarModel? calendar; // Null for new calendar
  final Function(CalendarModel) onSave;

  const CalendarEditDialog({
    super.key,
    this.calendar,
    required this.onSave,
  });

  @override
  State<CalendarEditDialog> createState() => _CalendarEditDialogState();
}

class _CalendarEditDialogState extends State<CalendarEditDialog> {
  late TextEditingController _nameController;
  late TextEditingController _syncUrlController;
  late Color _selectedColor;
  late CalendarType _selectedType;
  late bool _isDefault;

  final List<Color> _availableColors = [
    Colors.blue,
    Colors.green,
    Colors.red,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
    Colors.amber,
    Colors.cyan,
  ];

  @override
  void initState() {
    super.initState();
    // Initialize with provided calendar or defaults
    _nameController = TextEditingController(text: widget.calendar?.name ?? '');
    _syncUrlController =
        TextEditingController(text: widget.calendar?.syncUrl ?? '');
    _selectedColor = widget.calendar?.color ?? _availableColors.first;
    _selectedType = widget.calendar?.type ?? CalendarType.local;
    _isDefault = widget.calendar?.isDefault ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _syncUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.calendar != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Calendar' : 'New Calendar'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Calendar Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Calendar type selector
            DropdownButtonFormField<CalendarType>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Calendar Type',
                border: OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: CalendarType.local,
                  child: Text('Local Calendar'),
                ),
                DropdownMenuItem(
                  value: CalendarType.webdav,
                  child: Text('WebDAV Calendar'),
                ),
              ],
              onChanged: (type) {
                if (type != null) {
                  setState(() {
                    _selectedType = type;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // WebDAV URL field (only for WebDAV calendars)
            if (_selectedType == CalendarType.webdav)
              TextField(
                controller: _syncUrlController,
                decoration: const InputDecoration(
                  labelText: 'WebDAV Calendar URL',
                  border: OutlineInputBorder(),
                  hintText: 'https://example.com/calendar.ics',
                ),
              ),

            const SizedBox(height: 16),

            // Color picker
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Calendar Color',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableColors.map((color) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedColor = color;
                        });
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _selectedColor == color
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

            const SizedBox(height: 16),

            // Default calendar checkbox
            CheckboxListTile(
              title: const Text('Make Default Calendar'),
              value: _isDefault,
              onChanged: (value) {
                setState(() {
                  _isDefault = value ?? false;
                });
              },
              contentPadding: EdgeInsets.zero,
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
          onPressed: _saveCalendar,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _saveCalendar() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a calendar name'),
        ),
      );
      return;
    }

    if (_selectedType == CalendarType.webdav &&
        _syncUrlController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a WebDAV URL'),
        ),
      );
      return;
    }

    final calendar = (widget.calendar ??
            CalendarModel(
              id: '',
              name: '',
              color: Colors.blue,
              userId: '',
              type: CalendarType.local,
            ))
        .copyWith(
      name: _nameController.text.trim(),
      color: _selectedColor,
      type: _selectedType,
      isDefault: _isDefault,
      syncUrl: _selectedType == CalendarType.webdav
          ? _syncUrlController.text.trim()
          : null,
    );

    widget.onSave(calendar);
    Navigator.of(context).pop();
  }
}
