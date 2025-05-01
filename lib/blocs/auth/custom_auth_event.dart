part of 'custom_auth_bloc.dart';

abstract class CustomAuthEvent extends Equatable {
  const CustomAuthEvent();

  @override
  List<Object> get props => [];
}

class CustomAuthCheckRequested extends CustomAuthEvent {
  const CustomAuthCheckRequested();
}

class CustomAuthSignOutRequested extends CustomAuthEvent {
  const CustomAuthSignOutRequested();
}
