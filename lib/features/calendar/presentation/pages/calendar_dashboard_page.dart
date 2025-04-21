import 'package:draggable_calendar/draggable_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_sync_calendar/features/auth/presentation/pages/login_page.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/models/calendar_event_model.dart';
import '../../../../core/utils/error_utils.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../auth/domain/blocs/custom_auth_bloc/custom_auth_bloc.dart';
import '../../../auth/domain/blocs/custom_auth_bloc/custom_auth_event.dart';
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
    return Scaffold(
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
            print(
                'Building calendar with ${state.draggableEvents.length} events');
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
            return const LoadingIndicator(message: 'Initializing calendar...');
          }
        },
      ),
    );
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
          ],
        );
      },
    );
  }

  Widget _buildCalendar(CalendarLoaded state) {
    return DraggableCalendar(
      calendarViewType: state.calendarViewType,
      events: state.draggableEvents,
      onEventAdd: _handleEventAdd,
      onEventUpdate: _handleEventUpdate,
      onEventDelete: _handleEventDelete,
      onViewChanged: (viewType) {
        context.read<CalendarBloc>().add(CalendarChangeView(viewType));
      },
      timeSnapInterval: 15,
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

  void _handleEventAdd(EventModel eventModel) {
    // Convert from draggable calendar EventModel to our CalendarEventModel
    final newEvent = CalendarEventModel(
      id: eventModel.id.isEmpty ? _uuid.v4() : eventModel.id,
      title: eventModel.title,
      description: eventModel.description,
      start: eventModel.start,
      end: eventModel.end,
      color: eventModel.color,
      userId: widget.user.id,
    );

    context.read<CalendarBloc>().add(CalendarAddEvent(newEvent));

    // Show success message using post-frame callback
    SchedulerBinding.instance.addPostFrameCallback((_) {
      ErrorUtils.showSuccessSnackBar(
          context, 'Event "${newEvent.title}" added successfully');
    });
  }

  void _handleEventUpdate(EventModel eventModel) {
    // Find the original event in our state
    final calendarBloc = context.read<CalendarBloc>();
    final state = calendarBloc.state;

    if (state is CalendarLoaded) {
      final originalEvent = state.events.firstWhere(
        (event) => event.id == eventModel.id,
        orElse: () => CalendarEventModel(
          id: eventModel.id,
          title: eventModel.title,
          description: eventModel.description,
          start: eventModel.start,
          end: eventModel.end,
          color: eventModel.color,
          userId: widget.user.id,
        ),
      );

      // Update the event with new values
      final updatedEvent = originalEvent.copyWith(
        title: eventModel.title,
        description: eventModel.description,
        start: eventModel.start,
        end: eventModel.end,
        color: eventModel.color,
      );

      calendarBloc.add(CalendarUpdateEvent(updatedEvent));

      // Show success message using post-frame callback
      SchedulerBinding.instance.addPostFrameCallback((_) {
        ErrorUtils.showSuccessSnackBar(
            context, 'Event "${updatedEvent.title}" updated');
      });
    }
  }

  void _handleEventDelete(String eventId) {
    // Get the event title before deleting
    final calendarBloc = context.read<CalendarBloc>();
    final state = calendarBloc.state;
    String eventTitle = '';

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
        ),
      );
      eventTitle = event.title;
    }

    // Delete the event
    context.read<CalendarBloc>().add(CalendarDeleteEvent(eventId));

    // Show success message using post-frame callback
    SchedulerBinding.instance.addPostFrameCallback((_) {
      ErrorUtils.showSuccessSnackBar(context,
          'Event${eventTitle.isNotEmpty ? ' "$eventTitle"' : ''} deleted');
    });
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
                '4. Copy and paste the SQL script from "supabase_setup_script.sql"\n'
                '5. Run the script\n'
                '6. Return to the app and try again',
              ),
              const SizedBox(height: 16),
              const Text(
                'Note: You can find the SQL script in the project files or in '
                'the app documentation.',
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
}
