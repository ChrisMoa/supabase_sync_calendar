import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:supabase_sync_calendar/core/models/calendar_model.dart';
import 'package:supabase_sync_calendar/features/calendar/domain/blocs/calendar_management_bloc/calendar_management_bloc.dart';
import 'package:supabase_sync_calendar/features/calendar/domain/blocs/calendar_management_bloc/calendar_management_event.dart';

class ICSImportDialog extends StatefulWidget {
  final List<CalendarModel> calendars;
  final CalendarModel? defaultCalendar;
  final File? preselectedFile; // Add this parameter

  const ICSImportDialog({
    super.key,
    required this.calendars,
    this.defaultCalendar,
    this.preselectedFile, // Add this parameter
  });

  @override
  State<ICSImportDialog> createState() => _ICSImportDialogState();
}

class _ICSImportDialogState extends State<ICSImportDialog> {
  String? _selectedCalendarId;
  File? _selectedFile;
  File? _directFile; // Add this field for direct file handling
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize with default calendar
    _selectedCalendarId = widget.defaultCalendar?.id ??
        (widget.calendars.isNotEmpty ? widget.calendars.first.id : null);

    // Set preselected file if provided
    if (widget.preselectedFile != null) {
      _directFile = widget.preselectedFile;
    }
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
                    ? 'Selected: ${_selectedFile!.path}'
                    : 'No file selected'),
              ),
              ElevatedButton.icon(
                onPressed: _selectFile,
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

  Future<void> _selectFile() async {
    final file = (await FlutterFileDialog.pickFile());
    if (file != null) {
      setState(() {
        _selectedFile = File(file);
      });
    }
  }

  Future<void> _importFile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get the file
      File file;
      if (_directFile != null) {
        file = _directFile!;
      } else {
        file = File(_selectedFile!.path);
      }

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
