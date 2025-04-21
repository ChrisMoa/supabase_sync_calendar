# Supabase Sync Calendar

A Flutter calendar application that uses Supabase as a backend database.

## Features

- User authentication with Supabase
- Secure credential storage
- Calendar event management (add, edit, delete)
- Different calendar views (day, week, month)
- Drag and drop event scheduling

## Project Structure

This project follows a feature-based clean architecture:

```
lib/
  ├── core/                 # Shared models and utilities
  │   ├── models/
  │   ├── utils/
  │   └── widgets/
  ├── features/
  │   ├── auth/             # Authentication feature
  │   │   ├── data/
  │   │   ├── domain/
  │   │   └── presentation/
  │   └── calendar/         # Calendar feature
  │       ├── data/ 
  │       ├── domain/
  │       └── presentation/
  └── main.dart
```

## Setup Instructions

### 1. Supabase Setup

1. Create a Supabase account and project at [supabase.com](https://supabase.com)
2. Set up authentication with email/password
3. Create a `calendar_events` table with the following schema:

```sql
CREATE TABLE calendar_events (
  id UUID PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ NOT NULL,
  color INTEGER NOT NULL,
  user_id UUID NOT NULL REFERENCES auth.users(id)
);

-- Add RLS policies
ALTER TABLE calendar_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own events" ON calendar_events
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own events" ON calendar_events
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own events" ON calendar_events
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own events" ON calendar_events
  FOR DELETE USING (auth.uid() = user_id);
```

### 2. Flutter Setup

1. Clone this repository
2. Clone the draggable_calendar repository and place it in the same parent directory as this project
3. Install dependencies:

```bash
flutter pub get
```

4. Run the app:

```bash
flutter run
```

### 3. First Login

When you first launch the app, you'll need to enter:
- Supabase URL (from your Supabase project settings)
- API Key (from your Supabase project settings)
- Your registered email and password

These credentials will be securely stored for future use.

## Dependencies

- flutter_bloc: State management
- supabase_flutter: Supabase client
- flutter_secure_storage: Secure credential storage
- uuid: Generate unique IDs
- draggable_calendar: Custom calendar UI (local package)

## Note