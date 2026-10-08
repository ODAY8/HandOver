// lib/services/auth_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Exception thrown when authentication operations fail.
class AuthFailure implements Exception {
  final String message;
  final String? code;

  const AuthFailure(this.message, {this.code});

  @override
  String toString() => message;
}

/// Abstract contract for authentication service
abstract class AuthService {
  User? get currentUser;
  Session? get currentSession;
  bool get isAuthenticated;
  Stream<AuthState> get onAuthStateChange;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  });

  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  });

  Future<void> signOut();
}

/// Supabase implementation of AuthService
class SupabaseAuthService implements AuthService {
  final SupabaseClient _client;

  SupabaseAuthService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  User? get currentUser => _client.auth.currentUser;

  @override
  Session? get currentSession => _client.auth.currentSession;

  @override
  bool get isAuthenticated => _client.auth.currentSession != null;

  @override
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'full_name': fullName.trim(),
        },
      );
      return response;
    } on AuthException catch (e) {
      throw _mapAuthException(e);
    } catch (e) {
      if (e is AuthFailure) rethrow;
      debugPrint('Unexpected error during signUp: $e');
      throw const AuthFailure(
        'Unable to complete registration. Please check your connection and try again.',
      );
    }
  }

  @override
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return response;
    } on AuthException catch (e) {
      throw _mapAuthException(e);
    } catch (e) {
      if (e is AuthFailure) rethrow;
      debugPrint('Unexpected error during signInWithPassword: $e');
      throw const AuthFailure(
        'Unable to sign in. Please check your internet connection.',
      );
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException catch (e) {
      throw _mapAuthException(e);
    } catch (e) {
      debugPrint('Error during signOut: $e');
      // Even if network fails, client session is cleaned locally by Supabase SDK
    }
  }

  AuthFailure _mapAuthException(AuthException e) {
    final msg = e.message.toLowerCase();
    final code = e.statusCode;

    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid credential') ||
        msg.contains('wrong password')) {
      return AuthFailure(
        'Invalid email or password. Please try again.',
        code: code,
      );
    }

    if (msg.contains('already registered') ||
        msg.contains('user already exists') ||
        msg.contains('email address already in use')) {
      return AuthFailure(
        'An account with this email already exists. Please sign in instead.',
        code: code,
      );
    }

    if (msg.contains('password') &&
        (msg.contains('short') || msg.contains('at least 6'))) {
      return AuthFailure(
        'Password must be at least 6 characters long.',
        code: code,
      );
    }

    if (msg.contains('email not confirmed')) {
      return AuthFailure(
        'Your email address is not yet confirmed. Please check your inbox.',
        code: code,
      );
    }

    if (msg.contains('network') ||
        msg.contains('connection') ||
        msg.contains('timeout')) {
      return AuthFailure(
        'Network error. Please check your internet connection and retry.',
        code: code,
      );
    }

    return AuthFailure(e.message, code: code);
  }
}
