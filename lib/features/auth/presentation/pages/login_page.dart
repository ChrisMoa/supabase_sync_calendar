import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_sync_calendar/features/calendar/presentation/pages/calendar_dashboard_page.dart';

import '../../../../core/utils/error_utils.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../domain/blocs/custom_auth_bloc/custom_auth_bloc.dart';
import '../../domain/blocs/custom_auth_bloc/custom_auth_event.dart';
import '../../domain/blocs/custom_auth_bloc/custom_auth_state.dart';
import '../widgets/login_form.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  @override
  void initState() {
    super.initState();
    // Load saved credentials when the page initializes
    context.read<CustomAuthBloc>().add(const LoadSavedCredentials());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supabase Sync Calendar Login'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: BlocConsumer<CustomAuthBloc, CustomAuthState>(
        listener: (context, state) {
          debugPrint('Auth state changed: ${state.runtimeType}');

          if (state is AuthError) {
            // Use post frame callback to show error snackbar
            SchedulerBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ErrorUtils.showErrorSnackBar(context, state.message);
              }
            });
          } else if (state is AuthAuthenticated) {
            // Use post frame callback to show success message and navigate
            SchedulerBinding.instance.addPostFrameCallback((_) {
              // Only proceed if the widget is still mounted
              if (!mounted) return;

              // Show success message
              ErrorUtils.showSuccessSnackBar(context, 'Successfully logged in');

              debugPrint('Navigating to calendar dashboard with direct route');

              // Navigate directly to dashboard
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => CalendarDashboardPage(
                    supabaseClient: state.supabaseClient,
                    user: state.user,
                  ),
                ),
              );
            });
          }
        },
        builder: (context, state) {
          if (state is AuthLoading) {
            return const LoadingIndicator(message: 'Authenticating...');
          } else if (state is CredentialsLoaded) {
            return LoginForm(
              initialSupabaseUrl: state.supabaseUrl,
              initialSupabaseApiKey: state.supabaseApiKey,
              initialEmail: state.email,
              initialPassword: state.password,
              hasBeenLoggedInBefore: state.hasBeenLoggedInBefore,
            );
          }
          // Default case or AuthInitial
          return const LoadingIndicator(message: 'Loading saved credentials...');
        },
      ),
    );
  }
}
