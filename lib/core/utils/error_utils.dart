import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ErrorUtils {
  /// Get a user-friendly error message from Supabase exceptions
  static String getMessageFromSupabaseError(dynamic error) {
    if (error is AuthException) {
      return _handleAuthException(error);
    } else if (error is PostgrestException) {
      return _handlePostgrestException(error);
    } else {
      return 'An unexpected error occurred: ${error.toString()}';
    }
  }

  static String _handleAuthException(AuthException error) {
    switch (error.message) {
      case 'Invalid login credentials':
        return 'Invalid email or password. Please try again.';
      case 'Email not confirmed':
        return 'Please confirm your email before logging in.';
      case 'Password recovery requires an email':
        return 'Please enter your email address to reset your password.';
      default:
        return 'Authentication error: ${error.message}';
    }
  }

  static String _handlePostgrestException(PostgrestException error) {
    // Handle common database errors
    if (error.message.contains('unique constraint')) {
      return 'This record already exists.';
    } else if (error.message.contains('foreign key constraint')) {
      return 'This operation references a record that does not exist.';
    } else {
      return 'Database error: ${error.message}';
    }
  }

  /// Show a generic error snackbar
  static void showErrorSnackBar(BuildContext context, String message) {
    // This method should now only be called in a safe context (not during build)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'DISMISS',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Show a success snackbar
  static void showSuccessSnackBar(BuildContext context, String message) {
    // This method should now only be called in a safe context (not during build)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
