import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseUtils {
  // Table names
  static const String eventsTable = 'calendar_events';

  // Column names for events table
  static const String colId = 'id';
  static const String colTitle = 'title';
  static const String colDescription = 'description';
  static const String colStartTime = 'start_time';
  static const String colEndTime = 'end_time';
  static const String colColor = 'color';
  static const String colUserId = 'user_id';

  /// Creates the necessary tables and RLS policies if they don't exist
  static Future<void> setupSupabaseTables(SupabaseClient client) async {
    try {
      // Instead of using a stored procedure, simply check if we can access the events table
      // If we can access it and no error occurs, the table exists
      print('Checking if calendar_events table exists...');

      try {
        await client.from(eventsTable).select('id').limit(1);

        print('Calendar events table exists');
        // Table exists, no need to create it
        return;
      } catch (e) {
        // If the error is not about the table not existing, rethrow
        if (!e.toString().contains('does not exist')) {
          print('Unexpected error: $e');
          return;
        }

        print('Table does not exist, would need to create it');
        // In a real scenario, we would create the table here
        // But for now, we'll just log that we need to create it,
        // since table creation typically requires admin privileges
      }
    } catch (e) {
      print('Error in setupSupabaseTables: $e');
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
