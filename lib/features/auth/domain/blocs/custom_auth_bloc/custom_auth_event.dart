import 'package:equatable/equatable.dart';

abstract class CustomAuthEvent extends Equatable {
  const CustomAuthEvent();

  @override
  List<Object> get props => [];
}

class LoadSavedCredentials extends CustomAuthEvent {
  const LoadSavedCredentials();
}

class LoginRequested extends CustomAuthEvent {
  final String supabaseUrl;
  final String supabaseApiKey;
  final String email;
  final String password;

  const LoginRequested({
    required this.supabaseUrl,
    required this.supabaseApiKey,
    required this.email,
    required this.password,
  });

  @override
  List<Object> get props => [supabaseUrl, supabaseApiKey, email, password];
}

class LogoutRequested extends CustomAuthEvent {
  const LogoutRequested();
}
