import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_sync_calendar/core/models/calendar_model.dart';
import 'package:supabase_sync_calendar/features/calendar/domain/blocs/calendar_management_bloc/calendar_management_bloc.dart';
import 'package:supabase_sync_calendar/features/calendar/domain/blocs/calendar_management_bloc/calendar_management_event.dart';

class ICSImportDialog extends StatefulWidget {
  final List<CalendarModel> calendars;
  final CalendarModel? defaultCalendar;

  const ICSImportDialog({
    super.key,
    required this.calendars,
    this.defaultCalendar,
  });

  @override
  State<ICSImportDialog> createState() => _ICSImportDialogState();
}

class _ICSImportDialogState extends State<ICSImportDialog> {
  String? _selectedCalendarId;
  PlatformFile? _selectedFile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize with default calendar
    _selectedCalendarId = widget.defaultCalendar?.id ??
        (widget.calendars.isNotEmpty ? widget.calendars.first.id : null);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import ICS File'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Calendar selection
          DropdownButtonFormField<String>(
            value: _selectedCalendarId,
            decoration: const InputDecoration(
              labelText: 'Import to Calendar',
              border: OutlineInputBorder(),
            ),
            items: widget.calendars.map((calendar) {
              return DropdownMenuItem<String>(
                value: calendar.id,
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: calendar.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(calendar.name),
                    if (calendar.isDefault)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).primaryColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Default',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedCalendarId = value;
              });
            },
          ),
          const SizedBox(height: 16),

          // File selection
          Row(
            children: [
              Expanded(
                child: Text(_selectedFile != null
                    ? 'Selected: ${_selectedFile!.name}'
                    : 'No file selected'),
              ),
              ElevatedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.file_upload),
                label: const Text('Select ICS File'),
              ),
            ],
          ),

          if (_isLoading) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: (_selectedFile != null &&
                  _selectedCalendarId != null &&
                  !_isLoading)
              ? _importFile
              : null,
          child: const Text('Import Events'),
        ),
      ],
    );
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['ics'],
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = result.files.first;
        });
      }
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting file: $e')),
      );
    }
  }

  Future<void> _importFile() async {
    if (_selectedFile == null || _selectedCalendarId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Get the file
      final file = File(_selectedFile!.path!);

      // Import the file
      context.read<CalendarManagementBloc>().add(
            ImportICSFile(
              calendarId: _selectedCalendarId!,
              icsFile: file,
            ),
          );

      // Close the dialog
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error importing file: $e')),
      );
    }
  }
}
