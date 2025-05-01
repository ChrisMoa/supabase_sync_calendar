import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_sync_calendar/core/models/calendar_model.dart';
import 'package:supabase_sync_calendar/features/calendar/domain/blocs/calendar_management_bloc/calendar_management_bloc.dart';
import 'package:supabase_sync_calendar/features/calendar/domain/blocs/calendar_management_bloc/calendar_management_event.dart';
import 'package:supabase_sync_calendar/features/calendar/domain/blocs/calendar_management_bloc/calendar_management_state.dart';

class ICSFilePicker {
  // Pick an ICS file and import it
  static Future<void> pickAndImportICS(BuildContext context) async {
    try {
      // Pick file using file_picker package
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['ics'],
        allowMultiple: false,
      );

      if (result == null ||
          result.files.isEmpty ||
          result.files.first.path == null) {
        return;
      }

      final file = File(result.files.first.path!);
      final fileName = file.path.split('/').last;

      // Get calendar state
      final calendarManagementState =
          context.read<CalendarManagementBloc>().state;

      if (calendarManagementState is! CalendarManagementLoaded) {
        // Show loading message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Loading calendars...')),
        );

        // Trigger loading calendars
        context.read<CalendarManagementBloc>().add(const LoadCalendars());
        return;
      }

      final calendars = calendarManagementState.calendars;
      final defaultCalendar = calendarManagementState.defaultCalendar;

      if (calendars.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No calendars available to import events')),
        );
        return;
      }

      // Show calendar selection dialog
      final selectedCalendar = await _showCalendarSelectionDialog(
        context,
        calendars,
        defaultCalendar,
        fileName,
      );

      if (selectedCalendar != null) {
        // Import the file
        context.read<CalendarManagementBloc>().add(
              ImportICSFile(
                calendarId: selectedCalendar.id,
                icsFile: file,
              ),
            );

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Importing events from ICS file...')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
    }
  }

  // Show dialog to select which calendar to import to
  static Future<CalendarModel?> _showCalendarSelectionDialog(
    BuildContext context,
    List<CalendarModel> calendars,
    CalendarModel? defaultCalendar,
    String fileName,
  ) async {
    CalendarModel? selectedCalendar = defaultCalendar ?? calendars.first;

    return await showDialog<CalendarModel?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Import ICS File'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('File: $fileName'),
              const SizedBox(height: 16),
              const Text('Select calendar to import to:'),
              const SizedBox(height: 8),
              DropdownButtonFormField<CalendarModel>(
                value: selectedCalendar,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                items: calendars.map((calendar) {
                  return DropdownMenuItem<CalendarModel>(
                    value: calendar,
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
                              color: Theme.of(context)
                                  .primaryColor
                                  .withOpacity(0.2),
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
                  if (value != null) {
                    setState(() {
                      selectedCalendar = value;
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(selectedCalendar),
              child: const Text('Import'),
            ),
          ],
        ),
      ),
    );
  }
}
