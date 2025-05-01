import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_sync_calendar/features/calendar/domain/blocs/calendar_management_bloc/calendar_management_bloc.dart';
import 'package:supabase_sync_calendar/features/calendar/domain/blocs/event_series_bloc/event_series_bloc.dart';
import 'package:supabase_sync_calendar/core/services/network_service.dart';

import 'features/auth/domain/blocs/custom_auth_bloc/custom_auth_bloc.dart';
import 'features/auth/domain/blocs/custom_auth_bloc/custom_auth_state.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/calendar/domain/blocs/calendar_bloc/calendar_bloc.dart';
import 'features/calendar/presentation/pages/calendar_dashboard_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('🚀 APP: Starting app initialization...');

  // Create a secure storage with Windows-compatible options
  // Since Windows doesn't support encryption directly in secure storage,
  // we'll just use the standard implementation without encryption options
  const secureStorage = FlutterSecureStorage();
  debugPrint('🚀 APP: Secure storage initialized');

  // Initialize network service for connectivity monitoring
  final networkService = NetworkService();
  await networkService.initialize();
  debugPrint('🚀 APP: Network service initialized');

  // Register Hive adapters - This is done in CustomAuthBloc upon login
  // HiveService.registerHiveAdapters(); // Removed redundant call

  debugPrint('🚀 APP: Starting UI - Note: No Supabase client has been initialized yet');
  runApp(MyApp(
    secureStorage: secureStorage,
    networkService: networkService,
  ));
}

class MyApp extends StatelessWidget {
  final FlutterSecureStorage secureStorage;
  final NetworkService networkService;

  const MyApp({
    super.key,
    required this.secureStorage,
    required this.networkService,
  });

  @override
  Widget build(BuildContext context) {
    debugPrint('🚀 APP: Building MyApp widget');
    final calendarBloc = CalendarBloc();
    debugPrint('🚀 APP: Created CalendarBloc instance');

    return MultiBlocProvider(
      providers: [
        BlocProvider<CustomAuthBloc>(
          create: (context) {
            debugPrint('🚀 APP: Creating CustomAuthBloc');
            return CustomAuthBloc(secureStorage);
          },
        ),
        BlocProvider<CalendarBloc>(
          create: (context) {
            debugPrint('🚀 APP: Providing CalendarBloc to widget tree');
            return calendarBloc;
          },
        ),
        BlocProvider<EventSeriesBloc>(
          create: (context) {
            final authState = context.read<CustomAuthBloc>().state;
            if (authState is AuthAuthenticated) {
              debugPrint('🚀 APP: Creating EventSeriesBloc with authentication state - Offline mode: ${authState.isOfflineMode}');
              return EventSeriesBloc(
                supabaseClient: authState.supabaseClient,
                userId: authState.user.id,
                isOfflineMode: authState.isOfflineMode,
              );
            }
            // Return a placeholder that will be replaced when authenticated
            debugPrint('🚀 APP: Creating placeholder EventSeriesBloc (not authenticated yet)');
            return EventSeriesBloc(
              supabaseClient: null,
              userId: '',
              isOfflineMode: true,
            );
          },
        ),
        BlocProvider<CalendarManagementBloc>(
          create: (context) {
            final authState = context.read<CustomAuthBloc>().state;
            if (authState is AuthAuthenticated) {
              debugPrint('🚀 APP: Creating CalendarManagementBloc with authentication state - Offline mode: ${authState.isOfflineMode}');
              return CalendarManagementBloc(
                supabaseClient: authState.supabaseClient,
                userId: authState.user.id,
                calendarBloc: calendarBloc,
                isOfflineMode: authState.isOfflineMode,
              );
            }
            // Return a placeholder that will be replaced when authenticated
            debugPrint('🚀 APP: Creating placeholder CalendarManagementBloc (not authenticated yet)');
            return CalendarManagementBloc(
              supabaseClient: null,
              userId: '',
              calendarBloc: calendarBloc,
              isOfflineMode: true,
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
            home: state is AuthAuthenticated
                ? CalendarDashboardPage(
                    supabaseClient: state.supabaseClient,
                    user: state.user,
                    isOfflineMode: state.isOfflineMode,
                  )
                : const LoginPage(),
            routes: {
              '/login': (context) => const LoginPage(),
            },
            // Generate routes dynamically based on the current auth state
            onGenerateRoute: (settings) {
              debugPrint('Generating route for: ${settings.name}');

              // Handle dynamic routes for authenticated pages
              if (settings.name == '/calendar_dashboard') {
                if (state is AuthAuthenticated) {
                  final authState = state;
                  debugPrint('Creating route for calendar dashboard with user ${authState.user.id} - Offline mode: ${authState.isOfflineMode}');
                  return MaterialPageRoute(
                    builder: (context) => CalendarDashboardPage(
                      supabaseClient: authState.supabaseClient,
                      user: authState.user,
                      isOfflineMode: authState.isOfflineMode,
                    ),
                  );
                } else {
                  // If not authenticated, redirect to login
                  debugPrint('Not authenticated, redirecting to login');
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
