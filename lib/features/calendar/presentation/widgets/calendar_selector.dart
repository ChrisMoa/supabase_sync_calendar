import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_sync_calendar/core/models/calendar_model.dart';
import 'package:supabase_sync_calendar/features/calendar/domain/blocs/calendar_bloc/calendar_bloc.dart';
import 'package:supabase_sync_calendar/features/calendar/domain/blocs/calendar_bloc/calendar_event.dart';
import 'package:supabase_sync_calendar/features/calendar/domain/blocs/calendar_bloc/calendar_state.dart';
import 'package:supabase_sync_calendar/features/calendar/domain/blocs/calendar_management_bloc/calendar_management_bloc.dart';
import 'package:supabase_sync_calendar/features/calendar/domain/blocs/calendar_management_bloc/calendar_management_state.dart';

class CalendarSelector extends StatelessWidget {
  const CalendarSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CalendarManagementBloc, CalendarManagementState>(
      builder: (context, state) {
        if (state is! CalendarManagementLoaded) {
          return const SizedBox(); // Nothing to show yet
        }

        final calendars = state.calendars;
        if (calendars.isEmpty) {
          return const SizedBox(); // No calendars to show
        }

        return BlocBuilder<CalendarBloc, CalendarState>(
          builder: (context, calendarState) {
            final activeCalendarId = calendarState.activeCalendarFilter;

            return PopupMenuButton<String?>(
              icon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.filter_list,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _getCalendarFilterLabel(activeCalendarId, calendars),
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              onSelected: (calendarId) {
                context.read<CalendarBloc>().add(
                      CalendarFilterByCalendar(calendarId),
                    );
              },
              itemBuilder: (context) => [
                // Option to show all calendars
                const PopupMenuItem(
                  value: null,
                  child: Text('All Calendars'),
                ),
                // Divider
                const PopupMenuItem(
                  enabled: false,
                  height: 1,
                  padding: EdgeInsets.zero,
                  child: Divider(),
                ),
                // Individual calendars
                ...calendars.map((calendar) => PopupMenuItem(
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
                    )),
              ],
            );
          },
        );
      },
    );
  }

  String _getCalendarFilterLabel(
      String? activeCalendarId, List<CalendarModel> calendars) {
    if (activeCalendarId == null) {
      return 'All Calendars';
    }

    final calendar = calendars.firstWhere(
      (cal) => cal.id == activeCalendarId,
      orElse: () => CalendarModel(
        id: '',
        name: 'Unknown',
        color: Colors.grey,
        userId: '',
        type: CalendarType.local,
      ),
    );

    return calendar.name;
  }
}
