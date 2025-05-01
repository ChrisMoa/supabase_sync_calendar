import 'package:supabase_sync_calendar/core/extensions/datetime_extensions.dart';

class EventChecker {
  static bool isCompleteDay(DateTime timeStart, DateTime timeStop) {
    // Check if start is exactly at the beginning of a day
    if (!timeStart.isStartOfDay()) {
      return false;
    }

    // Check if stop is exactly at the end of a day
    if (!timeStop.isEndOfDay()) {
      return false;
    }

    // Check if the dates are different (spanning full days)
    return timeStart.day != timeStop.day ||
        timeStart.month != timeStop.month ||
        timeStart.year != timeStop.year;
  }
}
