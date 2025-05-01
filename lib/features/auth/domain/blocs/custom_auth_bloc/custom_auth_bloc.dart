import 'dart:convert';

import 'package:bloc/bloc.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_sync_calendar/core/services/hive_service.dart';
import 'package:supabase_sync_calendar/core/services/sync_service.dart';
import 'package:supabase_sync_calendar/core/services/network_service.dart';

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
      // Check if we need to initialize Hive
      if (!_isHiveInitialized) {
        // Generate an encryption key from the password
        final bytes = utf8.encode(event.password);
        final encryptionKey = sha256.convert(bytes).toString();

        // Initialize Hive first, regardless of connectivity
        await HiveService.init(encryptionKey);
        _isHiveInitialized = true;
        debugPrint('Hive initialized successfully');

        // Save credentials
        await _secureStorage.write(key: 'supabase_url', value: event.supabaseUrl);
        await _secureStorage.write(key: 'supabase_api_key', value: event.supabaseApiKey);
        await _secureStorage.write(key: 'supabase_email', value: event.email);
        await _secureStorage.write(key: 'supabase_password', value: event.password);
      }

      // Check network connectivity FIRST before any Supabase initialization
      final networkService = NetworkService();
      final isOnline = await networkService.isOnline;
      debugPrint('Network connectivity check: ${isOnline ? 'ONLINE' : 'OFFLINE'}');

      // If testing offline mode, uncomment the next line and comment out the one after it
      // final bool forceOfflineMode = true;
      final bool forceOfflineMode = false;

      // If online, try to authenticate with Supabase
      if (isOnline && !forceOfflineMode) {
        debugPrint('🌐 SUPABASE: Online authentication attempt - preparing to initialize client');
        try {
          // Check if Supabase is already initialized
          _supabaseClient = Supabase.instance.client;
          debugPrint('🌐 SUPABASE: Using existing Supabase instance');
        } catch (e) {
          // If not initialized yet, initialize it
          debugPrint('🌐 SUPABASE: Initializing new Supabase instance - this might be slow');
          await Supabase.initialize(
            url: event.supabaseUrl,
            anonKey: event.supabaseApiKey,
          );
          _supabaseClient = Supabase.instance.client;
          debugPrint('🌐 SUPABASE: Initialization complete');
        }

        // Log in with email and password
        debugPrint('🌐 SUPABASE: Attempting to sign in with password');
        final response = await _supabaseClient!.auth.signInWithPassword(
          email: event.email,
          password: event.password,
        );
        debugPrint('🌐 SUPABASE: Sign-in response received');

        if (response.user == null) {
          throw Exception('Authentication failed - user is null');
        }

        // Save the user ID for offline login
        await _secureStorage.write(key: 'user_id', value: response.user!.id);

        // Save user data to Hive for offline login
        final userData = {
          'id': response.user!.id,
          'email': response.user!.email,
          'appMetadata': response.user!.appMetadata,
          'userMetadata': response.user!.userMetadata,
          'aud': response.user!.aud,
          'phone': response.user!.phone,
          'createdAt': response.user!.createdAt,
          'emailConfirmedAt': response.user!.emailConfirmedAt,
        };
        await HiveService.saveUserData(response.user!.id, userData);
        debugPrint('Saved user data for offline login');

        // Initialize and run initial sync to fetch all data from Supabase
        _syncService = SyncService(
          supabaseClient: _supabaseClient!,
          userId: response.user!.id,
        );
        debugPrint('🌐 SUPABASE: Created sync service with client');

        // Perform initial data sync
        debugPrint('🌐 SUPABASE: Starting initial data sync...');
        await _syncService!.syncAll();
        debugPrint('🌐 SUPABASE: Initial sync completed');

        // Emit authenticated state
        emit(AuthAuthenticated(
          supabaseClient: _supabaseClient!,
          user: response.user!,
        ));

        debugPrint('Online authentication successful');
      } else {
        // Offline authentication
        debugPrint('🔌 OFFLINE: Attempting offline authentication');

        // Get the saved user ID
        final savedUserId = await _secureStorage.read(key: 'user_id');

        if (savedUserId == null) {
          throw Exception('No saved credentials for offline login. Please login online first.');
        }

        // Try to get the user data from Hive
        final userData = HiveService.getUserData(savedUserId);

        if (userData == null) {
          // Create a minimal user object with the saved ID
          debugPrint('🔌 OFFLINE: Creating offline user with ID: $savedUserId');

          // Create offline Supabase client (mock) without initializing the full client
          final offlineClient = createOfflineSupabaseClient(event.supabaseUrl, event.supabaseApiKey);

          // Create a mock User with the saved ID and email
          final mockUser = User(
            id: savedUserId,
            appMetadata: {},
            userMetadata: {},
            aud: 'offline',
            email: event.email,
            phone: '',
            createdAt: DateTime.now().toIso8601String(),
            emailConfirmedAt: DateTime.now().toIso8601String(),
          );

          // Emit authenticated state with the offline user
          emit(AuthAuthenticated(
            supabaseClient: offlineClient,
            user: mockUser,
            isOfflineMode: true,
          ));

          debugPrint('🔌 OFFLINE: Offline authentication successful');
        } else {
          // Use the saved userData to create a User object
          debugPrint('🔌 OFFLINE: Using saved user data for offline login');

          // Create offline Supabase client without initializing the full client
          final offlineClient = createOfflineSupabaseClient(event.supabaseUrl, event.supabaseApiKey);

          // Convert userData to Map<String, dynamic> to ensure correct typing
          final Map<String, dynamic> typedUserData = {};
          userData.forEach((key, value) {
            if (key is String) {
              typedUserData[key] = value;
            }
          });

          // Create a User with the saved data
          final offlineUser = User(
            id: savedUserId,
            appMetadata: typedUserData['appMetadata'] is Map ? Map<String, dynamic>.from(typedUserData['appMetadata']) : {},
            userMetadata: typedUserData['userMetadata'] is Map ? Map<String, dynamic>.from(typedUserData['userMetadata']) : {},
            aud: typedUserData['aud']?.toString() ?? 'offline',
            email: typedUserData['email']?.toString() ?? event.email,
            phone: typedUserData['phone']?.toString() ?? '',
            createdAt: typedUserData['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
            emailConfirmedAt: typedUserData['emailConfirmedAt']?.toString() ?? DateTime.now().toIso8601String(),
          );

          // Emit authenticated state with the offline user
          emit(AuthAuthenticated(
            supabaseClient: offlineClient,
            user: offlineUser,
            isOfflineMode: true,
          ));

          debugPrint('🔌 OFFLINE: Offline authentication successful using saved data');
        }
      }
    } catch (e) {
      debugPrint('Authentication failed: $e');
      emit(AuthError('Authentication failed: $e'));
    }
  }

  // Helper method to create an offline Supabase client without initializing the full client
  SupabaseClient createOfflineSupabaseClient(String url, String key) {
    debugPrint('🔌 OFFLINE: Creating offline Supabase client (no initialization)');
    // Create a client without actually connecting to Supabase
    return SupabaseClient(url, key);
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
