import 'dart:convert';

import 'package:bloc/bloc.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_sync_calendar/core/services/hive_service.dart';
import 'package:supabase_sync_calendar/core/services/sync_service.dart';

import '../../../../../core/utils/supabase_utils.dart';
import 'custom_auth_event.dart';
import 'custom_auth_state.dart';

class CustomAuthBloc extends Bloc<CustomAuthEvent, CustomAuthState> {
  final FlutterSecureStorage _secureStorage;
  SupabaseClient? _supabaseClient;
  bool _isHiveInitialized = false;
  SyncService? _syncService;

  CustomAuthBloc(this._secureStorage) : super(const AuthInitial()) {
    on<LoadSavedCredentials>(_onLoadSavedCredentials);
    on<LoginRequested>(_onLoginRequested);
    on<LogoutRequested>(_onLogoutRequested);
  }

  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<CustomAuthState> emit,
  ) async {
    emit(const AuthLoading());

    try {
      // Initialize Supabase and authenticate
      try {
        // Check if Supabase is already initialized
        _supabaseClient = Supabase.instance.client;
        debugPrint('Using existing Supabase instance');
      } catch (e) {
        // If not initialized yet, initialize it
        debugPrint('Initializing new Supabase instance');
        await Supabase.initialize(
          url: event.supabaseUrl,
          anonKey: event.supabaseApiKey,
        );
        _supabaseClient = Supabase.instance.client;
      }

      // Log in with email and password
      final response = await _supabaseClient!.auth.signInWithPassword(
        email: event.email,
        password: event.password,
      );

      if (response.user == null) {
        throw Exception('Authentication failed - user is null');
      }

      // Initialize Hive if not already initialized
      if (!_isHiveInitialized) {
        // Generate an encryption key from the password
        final bytes = utf8.encode(event.password);
        final encryptionKey = sha256.convert(bytes).toString();
        await HiveService.init(encryptionKey);
        _isHiveInitialized = true;
        debugPrint('Hive initialized successfully');
      }

      // Save credentials
      await _secureStorage.write(key: 'supabase_url', value: event.supabaseUrl);
      await _secureStorage.write(key: 'supabase_api_key', value: event.supabaseApiKey);
      await _secureStorage.write(key: 'supabase_email', value: event.email);
      await _secureStorage.write(key: 'supabase_password', value: event.password);

      // Initialize and run initial sync to fetch all data from Supabase
      _syncService = SyncService(
        supabaseClient: _supabaseClient!,
        userId: response.user!.id,
      );

      // Perform initial data sync
      debugPrint('Starting initial data sync...');
      await _syncService!.syncAll();
      debugPrint('Initial sync completed');

      // Emit authenticated state
      emit(AuthAuthenticated(
        supabaseClient: _supabaseClient!,
        user: response.user!,
      ));

      debugPrint('Authentication successful');
    } catch (e) {
      debugPrint('Authentication failed: $e');
      emit(AuthError('Authentication failed: $e'));
    }
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

      // If we have complete credentials, try to auto-login
      if (hasBeenLoggedInBefore && savedEmail != null && savedPassword != null) {
        // Try to use saved credentials to login automatically
        try {
          // Add a small delay for better UX
          await Future.delayed(const Duration(milliseconds: 500));

          // Login with the saved credentials
          add(LoginRequested(
            supabaseUrl: savedUrl,
            supabaseApiKey: savedApiKey,
            email: savedEmail,
            password: savedPassword,
          ));
          return;
        } catch (loginError) {
          // If auto-login fails, just show the login form with saved credentials
          debugPrint('Auto-login failed: $loginError');
        }
      }

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
