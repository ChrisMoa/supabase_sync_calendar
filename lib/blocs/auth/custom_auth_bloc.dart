import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:equatable/equatable.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';

part 'custom_auth_event.dart';
part 'custom_auth_state.dart';

class CustomAuthBloc extends Bloc<CustomAuthEvent, CustomAuthState> {
  final SupabaseClient supabaseClient;
  final Box<dynamic> userBox;
  final bool isOfflineMode;

  CustomAuthBloc({
    required this.supabaseClient,
    required this.userBox,
    this.isOfflineMode = false,
  }) : super(CustomAuthInitial()) {
    on<CustomAuthCheckRequested>(_onAuthCheckRequested);
    on<CustomAuthSignOutRequested>(_onSignOutRequested);
  }

  Future<void> _onAuthCheckRequested(
    CustomAuthCheckRequested event,
    Emitter<CustomAuthState> emit,
  ) async {
    try {
      if (isOfflineMode) {
        final user = _getUserFromHive();
        if (user != null) {
          emit(CustomAuthAuthenticated(user));
        } else {
          emit(const CustomAuthUnauthenticated());
        }
      } else {
        final session = supabaseClient.auth.currentSession;
        if (session != null) {
          emit(CustomAuthAuthenticated(session.user));
        } else {
          emit(const CustomAuthUnauthenticated());
        }
      }
    } catch (e) {
      emit(CustomAuthError(e.toString()));
    }
  }

  Future<void> _onSignOutRequested(
    CustomAuthSignOutRequested event,
    Emitter<CustomAuthState> emit,
  ) async {
    try {
      if (!isOfflineMode) {
        await supabaseClient.auth.signOut();
      }
      await userBox.clear();
      emit(const CustomAuthUnauthenticated());
    } catch (e) {
      emit(CustomAuthError(e.toString()));
    }
  }

  User? _getUserFromHive() {
    try {
      final userData = userBox.get('user');
      if (userData == null) return null;

      // If the data is already a Map, convert it to Map<String, dynamic>
      if (userData is Map) {
        final Map<String, dynamic> typedMap = {};
        userData.forEach((key, value) {
          if (key is String) {
            typedMap[key] = value;
          }
        });
        return User.fromJson(typedMap);
      }

      // If the data is a String, try to parse it as JSON
      if (userData is String) {
        final Map<String, dynamic> userMap = json.decode(userData);
        return User.fromJson(userMap);
      }

      return null;
    } catch (e) {
      print('Error getting user from Hive: $e');
      return null;
    }
  }
}
