-- Calendar Events Table
CREATE TABLE IF NOT EXISTS calendar_events (
  id UUID PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ NOT NULL,
  color INTEGER NOT NULL,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  whole_day BOOLEAN DEFAULT FALSE,
  calendar_id UUID NOT NULL,
  reminder TIMESTAMPTZ,
  appendixes JSONB DEFAULT '[]'::jsonb,
  is_external_read_only BOOLEAN DEFAULT FALSE,
  series_id UUID -- Reference to event_series table
);

-- Calendars Table
CREATE TABLE IF NOT EXISTS calendars (
  id UUID PRIMARY KEY,
  name TEXT NOT NULL,
  color INTEGER NOT NULL,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  type SMALLINT NOT NULL DEFAULT 0, -- 0: local, 1: webdav, 2: device
  is_default BOOLEAN DEFAULT FALSE,
  sync_url TEXT,
  device_calendar_id TEXT
);

-- Event Series Table
CREATE TABLE IF NOT EXISTS event_series (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  repeat_type SMALLINT NOT NULL, -- 0: none, 1: daily, 2: weekly, 3: monthly, 4: yearly
  repeat_interval INTEGER NOT NULL DEFAULT 1,
  repeat_days_of_week INTEGER[] DEFAULT '{}', -- For weekly repeats, days 1-7 (Monday-Sunday)
  end_type SMALLINT NOT NULL, -- 0: never, 1: after occurrences, 2: on date
  occurrences INTEGER, -- For end_type = 1
  end_date TIMESTAMPTZ, -- For end_type = 2
  template_event_id UUID NOT NULL -- ID of the first event that serves as template
);

-- Row Level Security Policies

-- Enable RLS on all tables
ALTER TABLE calendar_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE calendars ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_series ENABLE ROW LEVEL SECURITY;

-- Calendar Events Policies
CREATE POLICY "Users can view their own events" ON calendar_events
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own events" ON calendar_events
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own events" ON calendar_events
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own events" ON calendar_events
  FOR DELETE USING (auth.uid() = user_id);

-- Calendars Policies
CREATE POLICY "Users can view their own calendars" ON calendars
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own calendars" ON calendars
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own calendars" ON calendars
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own calendars" ON calendars
  FOR DELETE USING (auth.uid() = user_id);

-- Event Series Policies
CREATE POLICY "Users can view their own series" ON event_series
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own series" ON event_series
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own series" ON event_series
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own series" ON event_series
  FOR DELETE USING (auth.uid() = user_id);

-- Functions

-- Function to ensure a default calendar exists for a user
CREATE OR REPLACE FUNCTION ensure_default_calendar()
RETURNS TRIGGER AS $$
BEGIN
  -- Check if user already has a default calendar
  IF NOT EXISTS (
    SELECT 1 FROM calendars 
    WHERE user_id = NEW.user_id AND is_default = TRUE
  ) THEN
    -- Set the new calendar as default
    NEW.is_default := TRUE;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create a trigger to ensure at least one default calendar
CREATE TRIGGER ensure_default_calendar_trigger
BEFORE INSERT ON calendars
FOR EACH ROW
EXECUTE FUNCTION ensure_default_calendar();

-- Function to maintain only one default calendar per user
CREATE OR REPLACE FUNCTION maintain_single_default_calendar()
RETURNS TRIGGER AS $$
BEGIN
  -- If setting a calendar as default
  IF NEW.is_default = TRUE AND OLD.is_default = FALSE THEN
    -- Clear default flag from other calendars for this user
    UPDATE calendars
    SET is_default = FALSE
    WHERE user_id = NEW.user_id 
      AND id != NEW.id 
      AND is_default = TRUE;
  END IF;
  
  -- Prevent removing default from the only default calendar
  IF NEW.is_default = FALSE AND OLD.is_default = TRUE THEN
    IF NOT EXISTS (
      SELECT 1 FROM calendars
      WHERE user_id = NEW.user_id
        AND id != NEW.id
        AND is_default = TRUE
    ) THEN
      -- Keep this calendar as default since there are no others
      NEW.is_default := TRUE;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create a trigger to maintain only one default calendar
CREATE TRIGGER maintain_single_default_calendar_trigger
BEFORE UPDATE ON calendars
FOR EACH ROW
EXECUTE FUNCTION maintain_single_default_calendar();

-- Function to delete all events when deleting a calendar
CREATE OR REPLACE FUNCTION delete_calendar_events()
RETURNS TRIGGER AS $$
BEGIN
  -- Delete all events associated with the calendar
  DELETE FROM calendar_events
  WHERE calendar_id = OLD.id;
  
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Create a trigger to delete events when deleting a calendar
CREATE TRIGGER delete_calendar_events_trigger
BEFORE DELETE ON calendars
FOR EACH ROW
EXECUTE FUNCTION delete_calendar_events();

-- Function to delete all events when deleting a series
CREATE OR REPLACE FUNCTION delete_series_events()
RETURNS TRIGGER AS $$
BEGIN
  -- Delete all events associated with the series
  DELETE FROM calendar_events
  WHERE series_id = OLD.id;
  
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Create a trigger to delete events when deleting a series
CREATE TRIGGER delete_series_events_trigger
BEFORE DELETE ON event_series
FOR EACH ROW
EXECUTE FUNCTION delete_series_events();