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
import 'package:supabase_sync_calendar/features/calendar/presentation/widgets/ics_import_dialog.dart';
import 'package:uuid/uuid.dart';

class CalendarManagementPage extends StatefulWidget {
  final SupabaseClient supabaseClient;
  final User user;
  final VoidCallback onImportDeviceCalendars;

  const CalendarManagementPage({
    super.key,
    required this.supabaseClient,
    required this.user,
    required this.onImportDeviceCalendars,
  });

  @override
  State<CalendarManagementPage> createState() => _CalendarManagementPageState();
}

class _CalendarManagementPageState extends State<CalendarManagementPage> {
  final _uuid = Uuid();

  @override
  void initState() {
    super.initState();
    print("CalendarManagementPage initialized");
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
      body: MultiBlocListener(
        listeners: [
          // Primary listener for state changes
          BlocListener<CalendarManagementBloc, CalendarManagementState>(
            listener: (context, state) {
              print("State listener received: ${state.runtimeType}");

              if (state is DeviceCalendarsAvailable) {
                print(
                    "HANDLING DeviceCalendarsAvailable in listener with ${state.deviceCalendars.length} calendars");
                // Use a post-frame callback to avoid build phase issues
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _showDeviceCalendarSelectionDialog(state.deviceCalendars);
                });
              }
            },
            listenWhen: (previous, current) =>
                current is DeviceCalendarsAvailable,
          ),

          // Listener for errors and notifications
          BlocListener<CalendarManagementBloc, CalendarManagementState>(
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
              }
            },
            listenWhen: (previous, current) =>
                current is CalendarManagementError ||
                current is CalendarSyncComplete ||
                current is CalendarSyncError,
          ),
        ],
        child: BlocBuilder<CalendarManagementBloc, CalendarManagementState>(
          buildWhen: (previous, current) {
            // Only rebuild for these specific states
            return current is CalendarManagementLoading ||
                current is CalendarManagementLoaded ||
                current is CalendarSyncing;
          },
          builder: (context, state) {
            if (state is CalendarManagementLoading) {
              return const LoadingIndicator(message: 'Loading calendars...');
            } else if (state is CalendarManagementLoaded) {
              return _buildCalendarList(state);
            } else if (state is CalendarSyncing) {
              return const LoadingIndicator(message: 'Syncing calendar...');
            } else {
              return const Center(child: Text('Loading...'));
            }
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCalendarOptions,
        tooltip: 'Add Calendar',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCalendarList(CalendarManagementLoaded state) {
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
                  widget.onImportDeviceCalendars(); // Use the callback instead
                },
              ),
              // Add this new option
              ListTile(
                leading: const Icon(Icons.file_upload),
                title: const Text('Import ICS File'),
                onTap: () {
                  Navigator.pop(context);
                  _showImportICSDialog();
                  // ICSFilePicker.pickAndImportICS(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeviceCalendarSelectionDialog(List<dynamic> deviceCalendars) {
    print("SHOWING DIALOG for ${deviceCalendars.length} device calendars");

    // Track selected calendars
    Set<dynamic> selectedCalendars = {};

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (dialogContext) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Select Device Calendars'),
            content: SizedBox(
              width: double.maxFinite,
              height: 300, // Fixed height for the list
              child: Column(
                children: [
                  Text('Found ${deviceCalendars.length} device calendars'),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: deviceCalendars.length,
                      itemBuilder: (context, index) {
                        final deviceCalendar = deviceCalendars[index];
                        final bool isSelected =
                            selectedCalendars.contains(deviceCalendar);

                        return CheckboxListTile(
                          title:
                              Text(deviceCalendar.name ?? 'Unnamed Calendar'),
                          value: isSelected,
                          onChanged: (bool? value) {
                            print(
                                "Calendar selection changed: ${deviceCalendar.name} - $value");
                            setDialogState(() {
                              if (value == true) {
                                selectedCalendars.add(deviceCalendar);
                              } else {
                                selectedCalendars.remove(deviceCalendar);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  print(
                      "Import button pressed for ${selectedCalendars.length} calendars");
                  Navigator.pop(dialogContext);
                  _importSelectedDeviceCalendars(selectedCalendars.toList());
                },
                child: const Text('Import Selected'),
              ),
            ],
          );
        });
      },
    );
  }

  void _importSelectedDeviceCalendars(List<dynamic> selectedCalendars) {
    if (selectedCalendars.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No calendars selected')));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Importing ${selectedCalendars.length} calendars...')));

    // Get a reference to the bloc
    final bloc = BlocProvider.of<CalendarManagementBloc>(context);

    // Process each selected calendar
    for (final deviceCalendar in selectedCalendars) {
      print("Processing calendar: ${deviceCalendar.name}");

      // Create a calendar model for the device calendar
      final newCalendar = CalendarModel(
        id: _uuid.v4(),
        name: deviceCalendar.name ?? 'Device Calendar',
        color: deviceCalendar.color != null
            ? Color(deviceCalendar.color!)
            : Colors.blue,
        userId: widget.user.id,
        type: CalendarType.device,
        deviceCalendarId: deviceCalendar.id,
      );

      // Add the calendar
      print("Adding calendar to bloc: ${newCalendar.name}");
      bloc.add(AddCalendar(newCalendar));

      // Sync the calendar
      print("Syncing calendar: ${newCalendar.name}");
      bloc.add(SyncDeviceCalendar(newCalendar));
    }
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

  void _showImportICSDialog() {
    final state = context.read<CalendarManagementBloc>().state;

    if (state is CalendarManagementLoaded) {
      showDialog(
        context: context,
        builder: (context) => ICSImportDialog(
          calendars: state.calendars,
          defaultCalendar: state.defaultCalendar,
        ),
      );
    } else {
      // Show error if calendars not loaded
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait for calendars to load')),
      );
    }
  }
}
