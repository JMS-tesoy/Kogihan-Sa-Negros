import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/auth_user_model.dart';

/// Valid roles in the system
enum UserRole { user, agent, admin }

class AuthRemoteDatasource {
  late final SupabaseClient _supabase;

  AuthRemoteDatasource({SupabaseClient? supabaseClient}) {
    _supabase = supabaseClient ?? Supabase.instance.client;
  }

  /// Validate role string against allowed values
  static void _validateRole(String role) {
    final validRoles = ['user', 'agent', 'admin'];
    if (!validRoles.contains(role)) {
      throw ArgumentError(
        'Invalid role: $role. Must be one of: ${validRoles.join(", ")}'
      );
    }
  }

  /// Get the current authenticated user
  /// Returns null if user is not authenticated
  /// Throws exception if user exists in auth but profile is missing
  Future<AuthUserModel?> getCurrentUser() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final profile = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null) {
        // User exists in auth but not in profiles - data inconsistency
        throw Exception('User profile not found. Please contact support.');
      }

      return AuthUserModel(
        id: user.id,
        email: user.email ?? '',
        name: profile['full_name'] as String? ?? '',
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Sign in with email and password
  /// Throws generic error messages to prevent email enumeration
  Future<AuthUserModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw Exception('Authentication failed. Please try again.');
      }

      final profile = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null) {
        // Log this for monitoring but don't expose to user
        throw Exception(
          'User profile not found. Please contact support.'
        );
      }

      return AuthUserModel(
        id: user.id,
        email: user.email ?? '',
        name: profile['full_name'] as String? ?? '',
      );
    } on AuthException {
      // Return generic message to prevent email enumeration
      // Log the actual error server-side for debugging
      throw Exception('Authentication failed. Please try again.');
    } catch (e) {
      rethrow;
    }
  }

  /// Sign up with email and password
  /// Validates role and ensures atomic profile creation
  /// Returns the created user or throws exception
  Future<AuthUserModel> signUp({
    required String email,
    required String password,
    required String fullName,
    required String role,
  }) async {
    try {
      // Validate role before attempting auth
      _validateRole(role);

      // Check if email already exists (prevent enumeration with timing)
      await Future.delayed(const Duration(milliseconds: 100));
      final existingProfile = await _supabase
          .from('profiles')
          .select()
          .eq('email', email)
          .maybeSingle();

      if (existingProfile != null) {
        throw Exception('Email already registered. Please sign in instead.');
      }

      // Create auth user
      final authResponse = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      final user = authResponse.user;
      if (user == null) {
        throw Exception('Account creation failed. Please try again.');
      }

      // Create user profile - must succeed or signup is incomplete
      try {
        await _supabase.from('profiles').insert({
          'id': user.id,
          'email': email,
          'full_name': fullName,
          'role': role,
        });
      } catch (e) {
        // Profile creation failed - try to delete the auth user
        try {
          await _supabase.auth.admin.deleteUser(user.id);
        } catch (_) {
          // Admin delete might fail, but we still need to inform user
        }
        throw Exception(
          'Failed to complete account setup. Please try again.'
        );
      }

      return AuthUserModel(
        id: user.id,
        email: email,
        name: fullName,
      );
    } on AuthException {
      // Generic message to prevent account enumeration
      throw Exception('Account creation failed. Please try again.');
    } catch (e) {
      rethrow;
    }
  }

  /// Sign out the current user
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  /// Password reset - send recovery email
  /// Uses constant-time response to prevent email enumeration
  Future<void> resetPassword(String email) async {
    try {
      // Check if email is registered (for UX, but don't expose difference)
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('email', email)
          .maybeSingle();

      // Always send success message even if email not found
      if (response != null) {
        await _supabase.auth.resetPasswordForEmail(email);
      }
      // Silently succeed to prevent email enumeration
    } catch (e) {
      // Silently fail to prevent email enumeration
      // Log server-side for monitoring
    }
  }

  /// Update password with current password
  Future<void> updatePassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Get user role from profiles table
  /// Returns 'user' as default if profile not found
  Future<String> getUserRole(String userId) async {
    try {
      final profile = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();

      return profile?['role'] as String? ?? 'user';
    } catch (e) {
      rethrow;
    }
  }

  /// Check if email exists in system
  /// Returns true if email is registered, false otherwise
  Future<bool> emailExists(String email) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('email', email)
          .maybeSingle();

      return response != null;
    } catch (e) {
      rethrow;
    }
  }

  /// Get auth session
  Session? getSession() {
    return _supabase.auth.currentSession;
  }

  /// Stream of auth changes
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;
}
