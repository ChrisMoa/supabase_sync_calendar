import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_sync_calendar/core/models/calendar_event_model.dart';
import 'package:supabase_sync_calendar/core/models/calendar_model.dart';
import 'package:supabase_sync_calendar/core/utils/error_utils.dart';
import 'package:supabase_sync_calendar/core/widgets/loading_indicator.dart';
import 'package:supabase_sync_calendar/features/calendar/domain/blocs/calendar_management_bloc/calendar_management_bloc.dart';
import 'package:supabase_sync_calendar/features/calendar/domain/blocs/calendar_management_bloc/calendar_management_event.dart';
import 'package:supabase_sync_calendar/features/calendar/domain/blocs/calendar_management_bloc/calendar_management_state.dart';
import 'package:supabase_sync_calendar/features/calendar/domain/blocs/event_series_bloc/event_series_bloc.dart';
import 'package:supabase_sync_calendar/features/calendar/domain/blocs/event_series_bloc/event_series_event.dart';
import 'package:supabase_sync_calendar/features/calendar/domain/blocs/event_series_bloc/event_series_state.dart';
import 'package:supabase_sync_calendar/features/calendar/presentation/pages/calendar_management_page.dart';
import 'package:supabase_sync_calendar/features/calendar/presentation/widgets/calendar_selector.dart';
import 'package:supabase_sync_calendar/features/calendar/presentation/widgets/event_edit_dialog.dart';
import 'package:supabase_sync_calendar/features/calendar/presentation/widgets/event_series_dialog.dart';
import 'package:supabase_sync_calendar/features/calendar/presentation/widgets/sf_calendar_widget.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:uuid/uuid.dart';

import '../../../auth/domain/blocs/custom_auth_bloc/custom_auth_bloc.dart';
import '../../../auth/domain/blocs/custom_auth_bloc/custom_auth_event.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../domain/blocs/calendar_bloc/calendar_bloc.dart';
import '../../domain/blocs/calendar_bloc/calendar_event.dart';
import '../../domain/blocs/calendar_bloc/calendar_state.dart';

class CalendarDashboardPage extends StatefulWidget {
  final SupabaseClient supabaseClient;
  final User user;

  const CalendarDashboardPage({
    super.key,
    required this.supabaseClient,
    required this.user,
  });

  @override
  State<CalendarDashboardPage> createState() => _CalendarDashboardPageState();
}

class _CalendarDashboardPageState extends State<CalendarDashboardPage> {
  final Uuid _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    print('CalendarDashboardPage initState');
    // Use a post-frame callback to initialize after first render
    SchedulerBinding.instance.addPostFrameCallback((_) {
      print('Initializing calendar bloc from initState');
      // Initialize the calendar with the Supabase client and user
      context.read<CalendarBloc>().add(CalendarInitialize(
            supabaseClient: widget.supabaseClient,
            userId: widget.user.id,
          ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // Add EventSeriesBloc
        BlocProvider<EventSeriesBloc>(
          create: (context) => EventSeriesBloc(
            supabaseClient: widget.supabaseClient,
            userId: widget.user.id,
          ),
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Calendar Dashboard'),
              Text(
                'User: ${widget.user.email}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          actions: [
            // Add calendar selector
            const CalendarSelector(),
            // Add calendar management button
            IconButton(
              onPressed: _navigateToCalendarManagement,
              icon: const Icon(Icons.calendar_view_day),
              tooltip: 'Manage Calendars',
            ),
            _buildViewSelector(),
            IconButton(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
            ),
          ],
        ),
        body: BlocConsumer<CalendarBloc, CalendarState>(
          listener: (context, state) {
            print('Calendar state changed: ${state.runtimeType}');

            if (state is CalendarError) {
              SchedulerBinding.instance.addPostFrameCallback((_) {
                ErrorUtils.showErrorSnackBar(context, state.message);

                // Show setup instructions if it's a table not existing error
                if (state.message.contains('table does not exist')) {
                  _showTableSetupInstructions(context);
                }
              });
            }
          },
          builder: (context, state) {
            print('Building UI for calendar state: ${state.runtimeType}');
            if (state is CalendarLoading) {
              return const LoadingIndicator(
                  message: 'Loading your calendar events...');
            } else if (state is CalendarLoaded) {
              print('Building calendar with ${state.events.length} events');
              if (state.events.isEmpty) {
                print('WARNING: No events to display in calendar');
              } else {
                // Debug the first few events
                final count = state.events.length > 3 ? 3 : state.events.length;
                for (int i = 0; i < count; i++) {
                  final e = state.events[i];
                  print(
                      'Event $i: ${e.title}, ${e.start}-${e.end}, color: ${e.color}');
                }
              }
              return _buildCalendar(state);
            } else {
              print('Initializing calendar...');
              // Instead of showing loading, initialize the bloc
              if (state is CalendarInitial) {
                print(
                    'Initializing calendar bloc with user ID: ${widget.user.id}');
                context.read<CalendarBloc>().add(CalendarInitialize(
                      supabaseClient: widget.supabaseClient,
                      userId: widget.user.id,
                    ));
              }
              return const LoadingIndicator(
                  message: 'Initializing calendar...');
            }
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _addNewEvent,
          tooltip: 'Add Event',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildCalendar(CalendarLoaded state) {
    print(
        'Building SfCalendarWidget with ${state.events.length} events and viewType: ${state.calendarViewType}');

    // Ensure CalendarManagementBloc is available to SfCalendarWidget
    return BlocProvider<CalendarManagementBloc>(
      create: (context) => CalendarManagementBloc(
        supabaseClient: widget.supabaseClient,
        userId: widget.user.id,
      )..add(const LoadCalendars()), // Immediately load calendars
      child: SfCalendarWidget(
        calendarView: _getCalendarView(state.calendarViewType),
        events: state.events,
        onEventAdd: _handleEventAdd,
        onEventUpdate: _handleEventUpdate,
        onEventDelete: _handleEventDelete,
        onViewChanged: (view) {
          context.read<CalendarBloc>().add(CalendarChangeView(
                _convertToCalendarViewType(view),
              ));
        },
        timeSnapInterval: 15,
        onMakeSeries: _handleMakeSeries, // Add this line to pass the handler
      ),
    );
  }

  void _showTableSetupInstructions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Database Setup Required'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The calendar_events table does not exist in your Supabase project. '
                'You need to run the SQL setup script to create the necessary database structure.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              const Text(
                'Steps to set up:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '1. Log in to your Supabase dashboard\n'
                '2. Navigate to the SQL Editor\n'
                '3. Create a new query\n'
                '4. Copy and paste the SQL script from "lib/core/sql/supabase_setup_script.sql"\n'
                '5. Run the script\n'
                '6. Return to the app and try again',
              ),
              const SizedBox(height: 16),
              const Text(
                'Note: The setup script includes the calendar_events, calendars, and event_series tables.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  CalendarView _getCalendarView(CalendarViewType viewType) {
    switch (viewType) {
      case CalendarViewType.day:
        return CalendarView.day;
      case CalendarViewType.week:
        return CalendarView.week;
      case CalendarViewType.month:
        return CalendarView.month;
      case CalendarViewType.schedule:
        return CalendarView.schedule;
    }
  }

  CalendarViewType _convertToCalendarViewType(CalendarView view) {
    switch (view) {
      case CalendarView.day:
        return CalendarViewType.day;
      case CalendarView.week:
        return CalendarViewType.week;
      case CalendarView.month:
        return CalendarViewType.month;
      case CalendarView.schedule:
        return CalendarViewType.schedule;
      default:
        return CalendarViewType.week;
    }
  }

  void _navigateToCalendarManagement() {
    // Create a standalone bloc outside of the BlocProvider
    final calendarManagementBloc = CalendarManagementBloc(
      supabaseClient: widget.supabaseClient,
      userId: widget.user.id,
    );

    // Add special listener for device calendars directly to the bloc
    calendarManagementBloc.stream.listen((state) {
      print("State observed outside build context: ${state.runtimeType}");

      if (state is DeviceCalendarsAvailable &&
          state.deviceCalendars.isNotEmpty) {
        print("DeviceCalendarsAvailable detected outside widget");

        // Show dialog outside of build context
        showDialog(
          context: context,
          builder: (dialogContext) => _buildDeviceCalendarSelectionDialog(
              dialogContext, state.deviceCalendars, calendarManagementBloc),
        );
      }
    });

    // Load calendars immediately
    calendarManagementBloc.add(const LoadCalendars());

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BlocProvider.value(
          value: calendarManagementBloc, // Use the same bloc instance
          child: CalendarManagementPage(
            supabaseClient: widget.supabaseClient,
            user: widget.user,
            // Pass a callback to trigger device calendar import
            onImportDeviceCalendars: () {
              calendarManagementBloc.add(const ImportDeviceCalendars());
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceCalendarSelectionDialog(BuildContext dialogContext,
      List<dynamic> deviceCalendars, CalendarManagementBloc bloc) {
    // Create a mutable list to maintain selected state
    List<bool> selectedStates = List.filled(deviceCalendars.length, false);

    return StatefulBuilder(builder: (context, setState) {
      return AlertDialog(
        title: const Text('Select Device Calendars'),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: 300,
          child: Column(
            children: [
              Text('Found ${deviceCalendars.length} device calendars'),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: deviceCalendars.length,
                  itemBuilder: (context, index) {
                    final deviceCalendar = deviceCalendars[index];
                    // Print calendar details for debugging
                    print(
                        "Calendar $index: name=${deviceCalendar.name}, id=${deviceCalendar.id}");

                    return CheckboxListTile(
                      title: Text(deviceCalendar.name ?? 'Unnamed Calendar'),
                      subtitle: Text(deviceCalendar.id ?? ''),
                      value: selectedStates[index],
                      onChanged: (bool? value) {
                        print(
                            "Selection changed for calendar ${deviceCalendar.name}: $value");
                        setState(() {
                          selectedStates[index] = value ?? false;
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);

              // Get selected calendars
              List<dynamic> selectedCalendars = [];
              for (int i = 0; i < deviceCalendars.length; i++) {
                if (selectedStates[i]) {
                  selectedCalendars.add(deviceCalendars[i]);
                }
              }

              print("Selected ${selectedCalendars.length} calendars");

              // Process each selected calendar
              _processSelectedCalendars(selectedCalendars, bloc);
            },
            child: const Text('Import Selected'),
          ),
        ],
      );
    });
  }

  // Process the selected device calendars
  void _processSelectedCalendars(
      List<dynamic> selectedCalendars, CalendarManagementBloc bloc) {
    final uuid = Uuid();

    if (selectedCalendars.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No calendars selected')));
      return;
    }

    // Show progress indicator
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Importing ${selectedCalendars.length} calendars...')));

    // Process each calendar
    for (int i = 0; i < selectedCalendars.length; i++) {
      final deviceCalendar = selectedCalendars[i];
      print(
          "Processing device calendar: name=${deviceCalendar.name}, id=${deviceCalendar.id}");

      // Create a new calendar model
      final newCalendar = CalendarModel(
        id: uuid.v4(),
        name: deviceCalendar.name ?? 'Device Calendar',
        color: deviceCalendar.color != null
            ? Color(deviceCalendar.color)
            : Colors.primaries[i % Colors.primaries.length],
        userId: widget.user.id,
        type: CalendarType.device,
        deviceCalendarId: deviceCalendar.id,
      );

      // Add the calendar
      print("Adding calendar: ${newCalendar.name} with ID ${newCalendar.id}");
      bloc.add(AddCalendar(newCalendar));

      // Sync the calendar
      print("Syncing calendar: ${newCalendar.name}");
      bloc.add(SyncDeviceCalendar(newCalendar));
    }
  }

  Widget _buildViewSelector() {
    return BlocBuilder<CalendarBloc, CalendarState>(
      builder: (context, state) {
        return PopupMenuButton<CalendarViewType>(
          icon: const Icon(Icons.calendar_view_month),
          tooltip: 'Change calendar view',
          onSelected: (viewType) {
            context.read<CalendarBloc>().add(CalendarChangeView(viewType));
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: CalendarViewType.day,
              child: Text('Day View'),
            ),
            const PopupMenuItem(
              value: CalendarViewType.week,
              child: Text('Week View'),
            ),
            const PopupMenuItem(
              value: CalendarViewType.month,
              child: Text('Month View'),
            ),
            const PopupMenuItem(
              value: CalendarViewType.schedule,
              child: Text('Schedule View'),
            ),
          ],
        );
      },
    );
  }

  void _logout() {
    context.read<CustomAuthBloc>().add(const LogoutRequested());

    // Use direct navigation instead of named routes
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const LoginPage(),
      ),
    );
  }

  void _addNewEvent() {
    // Get current date/time
    final now = DateTime.now();
    // Round to nearest half hour
    final startTime = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      (now.minute ~/ 30) * 30,
    );
    final endTime = startTime.add(const Duration(hours: 1));

    // Get available calendars from CalendarManagementBloc
    final calendarManagementState =
        context.read<CalendarManagementBloc>().state;
    List<CalendarModel> availableCalendars = [];
    CalendarModel? defaultCalendar;

    if (calendarManagementState is CalendarManagementLoaded) {
      availableCalendars = calendarManagementState.calendars
          .where((cal) =>
              cal.type ==
              CalendarType.local) // Only local calendars for new events
          .toList();
      defaultCalendar = calendarManagementState.defaultCalendar;
    }

    // If no calendars available, create a default one
    if (availableCalendars.isEmpty) {
      availableCalendars = [
        CalendarModel(
          id: 'default',
          name: 'Default Calendar',
          color: Colors.blue,
          userId: widget.user.id,
          type: CalendarType.local,
          isDefault: true,
        )
      ];
      defaultCalendar = availableCalendars.first;
    }

    // Show event creation dialog
    showDialog(
      context: context,
      builder: (context) => EventEditDialog(
        startTime: startTime,
        endTime: endTime,
        calendarId: defaultCalendar?.id ?? availableCalendars.first.id,
        color: defaultCalendar?.color ?? Colors.blue,
        calendars: availableCalendars,
        onSave: (title, description, start, end, color, wholeDay, calendarId,
            reminder) {
          final newEvent = CalendarEventModel(
            id: _uuid.v4(),
            title: title,
            description: description,
            start: start,
            end: end,
            color: color,
            userId: widget.user.id,
            calendarId: calendarId,
            wholeDay: wholeDay,
            reminder: reminder,
            appendixes: const [],
            seriesId: null, // Initially not part of a series
          );

          _handleEventAdd(newEvent);
        },
      ),
    );
  }

  void _handleEventAdd(CalendarEventModel newEvent) {
    // Set the userId if not already set
    final eventWithUserId = newEvent.copyWith(userId: widget.user.id);
    context.read<CalendarBloc>().add(CalendarAddEvent(eventWithUserId));

    // Show success message
    SchedulerBinding.instance.addPostFrameCallback((_) {
      ErrorUtils.showSuccessSnackBar(
          context, 'Event "${eventWithUserId.title}" added successfully');
    });
  }

  void _handleEventUpdate(CalendarEventModel updatedEvent) {
    // Check if event is part of a series
    if (updatedEvent.seriesId != null) {
      // Ask if user wants to update just this event or all events in series
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Update Series Event'),
          content: const Text(
              'Do you want to update just this event or all events in the series?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Update just this event
                final eventWithUserId =
                    updatedEvent.copyWith(userId: widget.user.id);
                context
                    .read<CalendarBloc>()
                    .add(CalendarUpdateEvent(eventWithUserId));

                SchedulerBinding.instance.addPostFrameCallback((_) {
                  ErrorUtils.showSuccessSnackBar(
                      context, 'Event "${updatedEvent.title}" updated');
                });
              },
              child: const Text('This Event Only'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Update all events in the series
                final eventSeriesBloc = context.read<EventSeriesBloc>();
                eventSeriesBloc.add(UpdateSeriesEvent(
                  event: updatedEvent,
                  updateAllEvents: true,
                ));

                // Listen for the result
                eventSeriesBloc.stream.listen((state) {
                  if (state is EventSeriesUpdated) {
                    // Reload all events
                    context
                        .read<CalendarBloc>()
                        .add(const CalendarLoadEvents());

                    SchedulerBinding.instance.addPostFrameCallback((_) {
                      ErrorUtils.showSuccessSnackBar(
                          context, 'All events in series updated');
                    });
                  } else if (state is EventSeriesError) {
                    SchedulerBinding.instance.addPostFrameCallback((_) {
                      ErrorUtils.showErrorSnackBar(context, state.message);
                    });
                  }
                });
              },
              child: const Text('All Events in Series'),
            ),
          ],
        ),
      );
    } else {
      // Regular single event update
      // Ensure userId is preserved
      final eventWithUserId = updatedEvent.copyWith(userId: widget.user.id);
      context.read<CalendarBloc>().add(CalendarUpdateEvent(eventWithUserId));

      // Show success message
      SchedulerBinding.instance.addPostFrameCallback((_) {
        ErrorUtils.showSuccessSnackBar(
            context, 'Event "${updatedEvent.title}" updated');
      });
    }
  }

  void _handleEventDelete(String eventId) {
    // Get the event before deleting
    final calendarBloc = context.read<CalendarBloc>();
    final state = calendarBloc.state;

    if (state is CalendarLoaded) {
      final event = state.events.firstWhere(
        (event) => event.id == eventId,
        orElse: () => CalendarEventModel(
          id: eventId,
          title: 'Event',
          description: '',
          start: DateTime.now(),
          end: DateTime.now().add(const Duration(hours: 1)),
          color: Colors.blue,
          userId: widget.user.id,
          calendarId: 'default',
          appendixes: const [],
        ),
      );

      String eventTitle = event.title;

      // Check if event is part of a series
      if (event.seriesId != null) {
        // Ask if user wants to delete just this event or all events in the series
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Series Event'),
            content: Text(
                'Do you want to delete just "$eventTitle" or all events in the series?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Delete just this event
                  final eventSeriesBloc = context.read<EventSeriesBloc>();
                  eventSeriesBloc.add(DeleteSeriesEvent(
                    eventId: eventId,
                    deleteAllFollowing: false,
                  ));

                  // Listen for result
                  eventSeriesBloc.stream.listen((state) {
                    if (state is EventSeriesUpdated ||
                        state is EventSeriesDeleted) {
                      // Reload all events
                      calendarBloc.add(const CalendarLoadEvents());

                      SchedulerBinding.instance.addPostFrameCallback((_) {
                        ErrorUtils.showSuccessSnackBar(
                            context, 'Event "$eventTitle" deleted');
                      });
                    }
                  });
                },
                style: TextButton.styleFrom(foregroundColor: Colors.orange),
                child: const Text('Just This Event'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Delete entire series
                  _handleDeleteSeries(event.seriesId!);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Entire Series'),
              ),
            ],
          ),
        );
      } else {
        // Regular event deletion
        calendarBloc.add(CalendarDeleteEvent(eventId));

        // Show success message
        SchedulerBinding.instance.addPostFrameCallback((_) {
          ErrorUtils.showSuccessSnackBar(
              context, 'Event "$eventTitle" deleted');
        });
      }
    } else {
      // If we can't find the event, just try to delete it
      calendarBloc.add(CalendarDeleteEvent(eventId));
    }
  }

  void _handleDeleteSeries(String seriesId) {
    // Delete the series through EventSeriesBloc
    context.read<EventSeriesBloc>().add(DeleteEventSeries(
          seriesId: seriesId,
          deleteEvents: true,
        ));

    // Reload events after deletion
    context.read<CalendarBloc>().add(const CalendarLoadEvents());

    SchedulerBinding.instance.addPostFrameCallback((_) {
      ErrorUtils.showSuccessSnackBar(context, 'Event series deleted');
    });
  }

  void _handleMakeSeries(CalendarEventModel event) {
    showDialog(
      context: context,
      builder: (context) => EventSeriesDialog(
        templateEvent: event,
        onSave: (series) {
          // Create the series
          context.read<EventSeriesBloc>().add(
                CreateEventSeries(
                  templateEvent: event,
                  series: series,
                ),
              );

          // Listen for completion and update calendar
          context.read<EventSeriesBloc>().stream.listen((state) {
            if (state is EventSeriesCreated) {
              // Reload all events
              context.read<CalendarBloc>().add(const CalendarLoadEvents());

              SchedulerBinding.instance.addPostFrameCallback((_) {
                ErrorUtils.showSuccessSnackBar(
                    context, 'Event series created successfully');
              });
            } else if (state is EventSeriesError) {
              SchedulerBinding.instance.addPostFrameCallback((_) {
                ErrorUtils.showErrorSnackBar(context, state.message);
              });
            }
          });
        },
      ),
    );
  }
}
