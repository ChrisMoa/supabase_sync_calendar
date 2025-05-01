import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_sync_calendar/features/calendar/domain/blocs/calendar_management_bloc/calendar_management_bloc.dart';
import 'package:supabase_sync_calendar/features/calendar/domain/blocs/calendar_management_bloc/calendar_management_event.dart';
import 'package:supabase_sync_calendar/features/calendar/domain/blocs/calendar_management_bloc/calendar_management_state.dart';
import 'package:supabase_sync_calendar/features/calendar/domain/blocs/calendar_bloc/calendar_bloc.dart';
import 'package:supabase_sync_calendar/features/calendar/domain/blocs/calendar_bloc/calendar_event.dart';
import 'package:supabase_sync_calendar/features/calendar/domain/blocs/calendar_bloc/calendar_state.dart';
import 'package:supabase_sync_calendar/core/models/calendar_model.dart';

class CalendarSelector extends StatelessWidget {
  const CalendarSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CalendarManagementBloc, CalendarManagementState>(
      builder: (context, state) {
        if (state is CalendarManagementLoading) {
          return const SizedBox(
            width: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (state is CalendarManagementLoaded) {
          final calendars = state.calendars;
          debugPrint('📋 CALENDAR SELECTOR: Available calendars:');
          for (final calendar in calendars) {
            debugPrint('📋 CALENDAR: ID=${calendar.id}, Name=${calendar.name}, Default=${calendar.isDefault}');
          }

          return BlocBuilder<CalendarBloc, CalendarState>(
            builder: (context, calendarState) {
              final activeCalendarId = calendarState is CalendarLoaded ? calendarState.activeCalendarFilter : null;
              debugPrint('📋 CALENDAR SELECTOR: Active calendar ID: $activeCalendarId');

              // Find the active calendar name
              String activeCalendarName = 'All Calendars';
              if (activeCalendarId != null) {
                final activeCalendar = calendars.firstWhere(
                  (cal) => cal.id == activeCalendarId,
                  orElse: () => CalendarModel(
                    id: '',
                    name: 'Unknown Calendar',
                    colorValue: 0xFF000000,
                    isDefault: false,
                    userId: '',
                    type: CalendarType.local,
                  ),
                );
                activeCalendarName = activeCalendar.name;
              }

              return Container(
                width: 200,
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: DropdownButton<String>(
                  value: activeCalendarId,
                  isExpanded: true,
                  hint: const Text('Select Calendar'),
                  underline: Container(
                    height: 2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  items: [
                    // All Calendars option
                    DropdownMenuItem<String>(
                      value: null,
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          const Text('All Calendars'),
                        ],
                      ),
                    ),
                    // Calendar list
                    ...calendars.map((calendar) {
                      return DropdownMenuItem<String>(
                        value: calendar.id,
                        child: Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: Color(calendar.colorValue),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                calendar.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                  onChanged: (String? newValue) {
                    debugPrint('📋 CALENDAR SELECTOR: Selected calendar ID: $newValue');
                    context.read<CalendarBloc>().add(CalendarFilterByCalendar(newValue));
                  },
                ),
              );
            },
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}
