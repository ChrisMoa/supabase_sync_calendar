part of 'custom_auth_bloc.dart';

abstract class CustomAuthState extends Equatable {
  const CustomAuthState();

  @override
  List<Object> get props => [];
}

class CustomAuthInitial extends CustomAuthState {
  const CustomAuthInitial();
}

class CustomAuthAuthenticated extends CustomAuthState {
  final User user;

  const CustomAuthAuthenticated(this.user);

  @override
  List<Object> get props => [user];
}

class CustomAuthUnauthenticated extends CustomAuthState {
  const CustomAuthUnauthenticated();
}

class CustomAuthError extends CustomAuthState {
  final String message;

  const CustomAuthError(this.message);

  @override
  List<Object> get props => [message];
}
