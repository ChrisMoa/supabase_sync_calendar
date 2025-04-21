import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class CustomAuthState extends Equatable {
  const CustomAuthState();

  @override
  List<Object> get props => [];
}

class AuthInitial extends CustomAuthState {
  const AuthInitial();
}

class AuthLoading extends CustomAuthState {
  const AuthLoading();
}

class CredentialsLoaded extends CustomAuthState {
  final String supabaseUrl;
  final String supabaseApiKey;
  final String email;
  final String password;
  final bool hasBeenLoggedInBefore;

  const CredentialsLoaded({
    required this.supabaseUrl,
    required this.supabaseApiKey,
    required this.email,
    required this.password,
    required this.hasBeenLoggedInBefore,
  });

  @override
  List<Object> get props =>
      [supabaseUrl, supabaseApiKey, email, password, hasBeenLoggedInBefore];
}

class AuthAuthenticated extends CustomAuthState {
  final User user;
  final SupabaseClient supabaseClient;

  const AuthAuthenticated({
    required this.user,
    required this.supabaseClient,
  });

  @override
  List<Object> get props => [user, supabaseClient];
}

class AuthUnauthenticated extends CustomAuthState {
  const AuthUnauthenticated();
}

class AuthError extends CustomAuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object> get props => [message];
}
