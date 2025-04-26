import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_sync_calendar/core/models/calendar_model.dart';
import 'package:supabase_sync_calendar/core/utils/error_utils.dart';
import 'package:supabase_sync_calendar/core/widgets/loading_indicator.dart';
import 'package:supabase_sync_calendar/features/calendar/domain/blocs/calendar_management_bloc/calendar_management_bloc.dart';
import 'package:supabase_sync_calendar/features/calendar/domain/blocs/calendar_management_bloc/calendar_management_event.dart';
import 'package:supabase_sync_calendar/features/calendar/domain/blocs/calendar_management_bloc/calendar_management_state.dart';
import 'package:supabase_sync_calendar/features/calendar/presentation/widgets/calendar_edit_dialog.dart';
import 'package:supabase_sync_calendar/features/calendar/presentation/widgets/calendar_list_item.dart';
import 'package:uuid/uuid.dart';

class CalendarManagementPage extends StatefulWidget {
  final SupabaseClient supabaseClient;
  final User user;

  const CalendarManagementPage({
    super.key,
    required this.supabaseClient,
    required this.user,
  });

  @override
  State<CalendarManagementPage> createState() => _CalendarManagementPageState();
}

class _CalendarManagementPageState extends State<CalendarManagementPage> {
  final _uuid = Uuid();

  @override
  void initState() {
    super.initState();
    // Load calendars when page initializes
    context.read<CalendarManagementBloc>().add(const LoadCalendars());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Calendars'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: BlocConsumer<CalendarManagementBloc, CalendarManagementState>(
        listener: (context, state) {
          if (state is CalendarManagementError) {
            ErrorUtils.showErrorSnackBar(context, state.message);
          } else if (state is CalendarSyncComplete) {
            ErrorUtils.showSuccessSnackBar(
              context,
              'Successfully synced ${state.eventCount} events',
            );
          } else if (state is CalendarSyncError) {
            ErrorUtils.showErrorSnackBar(context, state.message);
          } else if (state is DeviceCalendarsAvailable) {
            _showDeviceCalendarSelection(context, state.deviceCalendars);
          }
        },
        builder: (context, state) {
          if (state is CalendarManagementLoading) {
            return const LoadingIndicator(message: 'Loading calendars...');
          } else if (state is CalendarManagementLoaded) {
            return _buildCalendarList(context, state);
          } else if (state is CalendarSyncing) {
            return const LoadingIndicator(message: 'Syncing calendar...');
          } else {
            return const Center(child: Text('Loading...'));
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCalendarOptions,
        tooltip: 'Add Calendar',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCalendarList(
      BuildContext context, CalendarManagementLoaded state) {
    if (state.calendars.isEmpty) {
      return const Center(
        child: Text('No calendars found. Add a calendar to get started.'),
      );
    }

    return ListView.builder(
      itemCount: state.calendars.length,
      itemBuilder: (context, index) {
        final calendar = state.calendars[index];
        return CalendarListItem(
          calendar: calendar,
          isSelected: state.defaultCalendar?.id == calendar.id,
          onTap: () {
            if (!calendar.isDefault) {
              _confirmSetDefaultCalendar(calendar);
            }
          },
          onSync: () {
            _syncCalendar(calendar);
          },
          onEdit: () {
            _showEditCalendarDialog(calendar);
          },
          onDelete: () {
            _confirmDeleteCalendar(calendar);
          },
        );
      },
    );
  }

  void _showAddCalendarOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add Calendar',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('New Local Calendar'),
                onTap: () {
                  Navigator.pop(context);
                  _showAddCalendarDialog(CalendarType.local);
                },
              ),
              ListTile(
                leading: const Icon(Icons.cloud),
                title: const Text('WebDAV Calendar'),
                onTap: () {
                  Navigator.pop(context);
                  _showAddCalendarDialog(CalendarType.webdav);
                },
              ),
              ListTile(
                leading: const Icon(Icons.phone_android),
                title: const Text('Import Device Calendars'),
                onTap: () {
                  Navigator.pop(context);
                  context.read<CalendarManagementBloc>().add(
                        const ImportDeviceCalendars(),
                      );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddCalendarDialog(CalendarType type) {
    showDialog(
      context: context,
      builder: (context) => CalendarEditDialog(
        calendar: CalendarModel(
          id: _uuid.v4(),
          name: '',
          color: Colors.blue,
          userId: widget.user.id,
          type: type,
        ),
        onSave: (calendar) {
          context.read<CalendarManagementBloc>().add(AddCalendar(calendar));
        },
      ),
    );
  }

  void _showEditCalendarDialog(CalendarModel calendar) {
    showDialog(
      context: context,
      builder: (context) => CalendarEditDialog(
        calendar: calendar,
        onSave: (updatedCalendar) {
          context.read<CalendarManagementBloc>().add(
                UpdateCalendar(updatedCalendar),
              );
        },
      ),
    );
  }

  void _confirmDeleteCalendar(CalendarModel calendar) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Calendar'),
        content: Text(
          'Are you sure you want to delete the calendar "${calendar.name}"? '
          'All events in this calendar will also be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<CalendarManagementBloc>().add(
                    DeleteCalendar(calendar.id),
                  );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmSetDefaultCalendar(CalendarModel calendar) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set as Default'),
        content: Text(
          'Do you want to make "${calendar.name}" your default calendar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<CalendarManagementBloc>().add(
                    SetDefaultCalendar(calendar.id),
                  );
            },
            child: const Text('Set as Default'),
          ),
        ],
      ),
    );
  }

  void _syncCalendar(CalendarModel calendar) {
    switch (calendar.type) {
      case CalendarType.webdav:
        context
            .read<CalendarManagementBloc>()
            .add(SyncWebDAVCalendar(calendar));
        break;
      case CalendarType.device:
        context
            .read<CalendarManagementBloc>()
            .add(SyncDeviceCalendar(calendar));
        break;
      default:
        ErrorUtils.showErrorSnackBar(
            context, 'This calendar type cannot be synced');
    }
  }

  void _showDeviceCalendarSelection(
      BuildContext context, List<dynamic> deviceCalendars) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Device Calendars'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: deviceCalendars.length,
            itemBuilder: (context, index) {
              final deviceCalendar = deviceCalendars[index];
              return ListTile(
                title: Text(deviceCalendar.name ?? 'Unnamed Calendar'),
                leading: Icon(
                  Icons.calendar_today,
                  color: deviceCalendar.color != null
                      ? Color(deviceCalendar.color)
                      : Colors.blue,
                ),
                onTap: () {
                  Navigator.pop(context);

                  // Create a new calendar from the device calendar
                  final newCalendar = CalendarModel(
                    id: _uuid.v4(),
                    name: deviceCalendar.name ?? 'Device Calendar',
                    color: deviceCalendar.color != null
                        ? Color(deviceCalendar.color)
                        : Colors.blue,
                    userId: widget.user.id,
                    type: CalendarType.device,
                    deviceCalendarId: deviceCalendar.id,
                  );

                  // Add the calendar
                  context
                      .read<CalendarManagementBloc>()
                      .add(AddCalendar(newCalendar));

                  // Immediately sync it
                  context
                      .read<CalendarManagementBloc>()
                      .add(SyncDeviceCalendar(newCalendar));
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
