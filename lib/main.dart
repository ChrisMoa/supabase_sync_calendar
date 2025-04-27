import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_sync_calendar/features/calendar/domain/blocs/calendar_management_bloc/calendar_management_bloc.dart';

import 'features/auth/domain/blocs/custom_auth_bloc/custom_auth_bloc.dart';
import 'features/auth/domain/blocs/custom_auth_bloc/custom_auth_state.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/calendar/domain/blocs/calendar_bloc/calendar_bloc.dart';
import 'features/calendar/presentation/pages/calendar_dashboard_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize secure storage for credentials
  const secureStorage = FlutterSecureStorage();

  runApp(MyApp(secureStorage: secureStorage));
}

class MyApp extends StatelessWidget {
  final FlutterSecureStorage secureStorage;

  const MyApp({super.key, required this.secureStorage});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<CustomAuthBloc>(
          create: (context) => CustomAuthBloc(secureStorage),
        ),
        BlocProvider<CalendarBloc>(
          create: (context) => CalendarBloc(),
        ),
        BlocProvider<CalendarManagementBloc>(
          create: (context) {
            final authState = context.read<CustomAuthBloc>().state;
            if (authState is AuthAuthenticated) {
              return CalendarManagementBloc(
                supabaseClient: authState.supabaseClient,
                userId: authState.user.id,
              );
            }
            // Return a placeholder that will be replaced when authenticated
            return CalendarManagementBloc(
              supabaseClient: Supabase.instance.client,
              userId: '',
            );
          },
        ),
      ],
      child: BlocBuilder<CustomAuthBloc, CustomAuthState>(
        builder: (context, state) {
          return MaterialApp(
            title: 'Supabase Sync Calendar',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
              useMaterial3: true,
            ),
            home: const LoginPage(),
            routes: {
              '/login': (context) => const LoginPage(),
            },
            // Generate routes dynamically based on the current auth state
            onGenerateRoute: (settings) {
              print('Generating route for: ${settings.name}');

              // Handle dynamic routes for authenticated pages
              if (settings.name == '/calendar_dashboard') {
                if (state is AuthAuthenticated) {
                  final authState = state;
                  print(
                      'Creating route for calendar dashboard with user ${authState.user.id}');
                  return MaterialPageRoute(
                    builder: (context) => CalendarDashboardPage(
                      supabaseClient: authState.supabaseClient,
                      user: authState.user,
                    ),
                  );
                } else {
                  // If not authenticated, redirect to login
                  print('Not authenticated, redirecting to login');
                  return MaterialPageRoute(
                    builder: (context) => const LoginPage(),
                  );
                }
              }

              // Default case - return null to let the framework handle it
              return null;
            },
          );
        },
      ),
    );
  }
}
