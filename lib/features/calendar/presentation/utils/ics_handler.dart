import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_sync_calendar/features/calendar/domain/blocs/calendar_management_bloc/calendar_management_bloc.dart';
import 'package:supabase_sync_calendar/features/calendar/domain/blocs/calendar_management_bloc/calendar_management_event.dart';
import 'package:supabase_sync_calendar/features/calendar/domain/blocs/calendar_management_bloc/calendar_management_state.dart';
import 'package:supabase_sync_calendar/features/calendar/presentation/widgets/ics_import_dialog.dart';

class ICSHandler {
  // Pick and import an ICS file
  static Future<void> pickAndImportICS(BuildContext context) async {
    try {
      // Pick file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['ics'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.first.path!);
        importICSFile(context, file);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
    }
  }

  // Import an ICS file
  static Future<void> importICSFile(BuildContext context, File file) async {
    // Get calendar state
    final calendarManagementState =
        context.read<CalendarManagementBloc>().state;

    if (calendarManagementState is CalendarManagementLoaded) {
      final calendars = calendarManagementState.calendars;
      final defaultCalendar = calendarManagementState.defaultCalendar;

      if (calendars.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No calendars available to import events')),
        );
        return;
      }

      // Show import dialog
      showDialog(
        context: context,
        builder: (context) => ICSImportDialog(
          calendars: calendars,
          defaultCalendar: defaultCalendar,
          preselectedFile: file,
        ),
      );
    } else {
      // Ask user to wait for calendars to load
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait for calendars to load')),
      );

      // Trigger loading calendars
      context.read<CalendarManagementBloc>().add(const LoadCalendars());
    }
  }
}
