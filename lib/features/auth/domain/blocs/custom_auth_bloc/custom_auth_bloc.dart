import 'package:bloc/bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/utils/supabase_utils.dart';
import 'custom_auth_event.dart';
import 'custom_auth_state.dart';

class CustomAuthBloc extends Bloc<CustomAuthEvent, CustomAuthState> {
  final FlutterSecureStorage _secureStorage;
  SupabaseClient? _supabaseClient;

  CustomAuthBloc(this._secureStorage) : super(const AuthInitial()) {
    on<LoadSavedCredentials>(_onLoadSavedCredentials);
    on<LoginRequested>(_onLoginRequested);
    on<LogoutRequested>(_onLogoutRequested);
  }

  Future<void> _onLoadSavedCredentials(
    LoadSavedCredentials event,
    Emitter<CustomAuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      final savedUrl = await _secureStorage.read(key: 'supabase_url');
      final savedApiKey = await _secureStorage.read(key: 'supabase_api_key');
      final savedEmail = await _secureStorage.read(key: 'supabase_email');
      final savedPassword = await _secureStorage.read(key: 'supabase_password');

      // Check if we have saved credentials
      final hasBeenLoggedInBefore = savedUrl != null && savedApiKey != null;

      emit(CredentialsLoaded(
        supabaseUrl: savedUrl ?? '',
        supabaseApiKey: savedApiKey ?? '',
        email: savedEmail ?? '',
        password: savedPassword ?? '',
        hasBeenLoggedInBefore: hasBeenLoggedInBefore,
      ));
    } catch (e) {
      emit(AuthError('Failed to load saved credentials: $e'));
    }
  }

  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<CustomAuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      print('Starting Supabase initialization...');

      // Check if Supabase is already initialized
      try {
        _supabaseClient = Supabase.instance.client;
        print('Supabase already initialized, using existing client');
      } catch (e) {
        // Initialize Supabase with the provided credentials
        print('Initializing Supabase with the provided credentials');
        await Supabase.initialize(
          url: event.supabaseUrl,
          anonKey: event.supabaseApiKey,
        );

        _supabaseClient = Supabase.instance.client;
        print('Supabase initialized successfully');
      }

      // Attempt to log in with email and password
      print('Attempting to sign in with ${event.email}');
      final response = await _supabaseClient!.auth.signInWithPassword(
        email: event.email,
        password: event.password,
      );
      print('Sign in successful');

      // Try to initialize the Supabase tables (this may fail if the user doesn't have enough permissions)
      try {
        await SupabaseUtils.setupSupabaseTables(_supabaseClient!);
        print('Tables set up successfully');
      } catch (tableError) {
        // Just log the error, don't fail the login process
        print('Failed to set up tables: $tableError');
      }

      // Save credentials to secure storage
      await _secureStorage.write(key: 'supabase_url', value: event.supabaseUrl);
      await _secureStorage.write(
          key: 'supabase_api_key', value: event.supabaseApiKey);
      await _secureStorage.write(key: 'supabase_email', value: event.email);
      await _secureStorage.write(
          key: 'supabase_password', value: event.password);

      print('Emitting AuthAuthenticated state');
      emit(AuthAuthenticated(
        user: response.user!,
        supabaseClient: _supabaseClient!,
      ));
      print('Auth state emitted successfully');
    } catch (e) {
      print('Authentication failed: $e');
      emit(AuthError('Authentication failed: $e'));
    }
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<CustomAuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      if (_supabaseClient != null) {
        await _supabaseClient!.auth.signOut();
      }

      // Only clear the password, keep other credentials for convenience
      await _secureStorage.delete(key: 'supabase_password');

      emit(const AuthUnauthenticated());
    } catch (e) {
      emit(AuthError('Logout failed: $e'));
    }
  }
}
