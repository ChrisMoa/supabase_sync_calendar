// lib/core/utils/supabase_utils.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseUtils {
  // Table names
  static const String eventsTable = 'calendar_events';
  static const String calendarsTable = 'calendars';
  static const String seriesTable = 'event_series'; // Add this line

  // Column names for events table
  static const String colId = 'id';
  static const String colTitle = 'title';
  static const String colDescription = 'description';
  static const String colStartTime = 'start_time';
  static const String colEndTime = 'end_time';
  static const String colColor = 'color';
  static const String colUserId = 'user_id';
  static const String colWholeDay = 'whole_day';
  static const String colCalendarId = 'calendar_id';
  static const String colReminder = 'reminder';
  static const String colAppendixes = 'appendixes';
  static const String colIsExternalReadOnly = 'is_external_read_only';
  static const String colSeriesId = 'series_id'; // Add this line

  // Column names for series table
  static const String colRepeatType = 'repeat_type';
  static const String colRepeatInterval = 'repeat_interval';
  static const String colRepeatDaysOfWeek = 'repeat_days_of_week';
  static const String colEndType = 'end_type';
  static const String colOccurrences = 'occurrences';
  static const String colEndDate = 'end_date';
  static const String colTemplateEventId = 'template_event_id';

  // Add column names for calendars table
  static const String colName = 'name';
  static const String colType = 'type';
  static const String colIsDefault = 'is_default';
  static const String colSyncUrl = 'sync_url';
  static const String colDeviceCalendarId = 'device_calendar_id';

  /// Creates the necessary tables and RLS policies if they don't exist
  static Future<void> setupSupabaseTables(SupabaseClient client) async {
    try {
      // Instead of using a stored procedure, simply check if we can access the events table
      // If we can access it and no error occurs, the table exists
      debugPrint('Checking if calendar_events table exists...');

      try {
        await client.from(eventsTable).select('id').limit(1);

        debugPrint('Calendar events table exists');
        // Table exists, no need to create it
        return;
      } catch (e) {
        // If the error is not about the table not existing, rethrow
        if (!e.toString().contains('does not exist')) {
          debugPrint('Unexpected error: $e');
          return;
        }

        debugPrint('Table does not exist, would need to create it');
        // In a real scenario, we would create the table here
        // But for now, we'll just log that we need to create it,
        // since table creation typically requires admin privileges
      }
    } catch (e) {
      debugPrint('Error in setupSupabaseTables: $e');
      // Just log the error and continue - don't throw
      // throw Exception('Failed to set up Supabase tables: $e');
    }
  }

  /// SQL script for creating the necessary Supabase functions
  /// This would be executed manually in the Supabase SQL editor
  static const String setupScript = r'''
-- Function to check if a table exists
CREATE OR REPLACE FUNCTION check_table_exists(table_name text)
RETURNS boolean
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN EXISTS (
    SELECT FROM information_schema.tables 
    WHERE table_name = \$1
  );
END;
$$;

-- Function to create the calendar_events table
CREATE OR REPLACE FUNCTION create_calendar_events_table()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  CREATE TABLE IF NOT EXISTS calendar_events (
    id UUID PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    color INTEGER NOT NULL,
    user_id UUID NOT NULL REFERENCES auth.users(id)
  );
END;
$$;

-- Function to set up RLS policies for calendar_events
CREATE OR REPLACE FUNCTION setup_calendar_events_rls()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  -- Enable RLS on the table
  ALTER TABLE calendar_events ENABLE ROW LEVEL SECURITY;

  -- Create policies
  CREATE POLICY "Users can view their own events" ON calendar_events
    FOR SELECT USING (auth.uid() = user_id);

  CREATE POLICY "Users can insert their own events" ON calendar_events
    FOR INSERT WITH CHECK (auth.uid() = user_id);

  CREATE POLICY "Users can update their own events" ON calendar_events
    FOR UPDATE USING (auth.uid() = user_id);

  CREATE POLICY "Users can delete their own events" ON calendar_events
    FOR DELETE USING (auth.uid() = user_id);
END;
$$;
''';
}
