// lib/repositories/auth_repository.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/mock_data.dart';

abstract class AuthRepository {
  UserProfile? getCurrentUser();
  Stream<UserProfile?> get authStateChanges;
  bool get isAuthenticated;

  Future<UserProfile> signUp({
    required String email,
    required String password,
    required String fullName,
  });

  Future<UserProfile> signIn({
    required String email,
    required String password,
  });

  Future<void> signOut();
}

class SupabaseAuthRepository implements AuthRepository {
  final AuthService _authService;
  final SupabaseClient _client;

  SupabaseAuthRepository({
    AuthService? authService,
    SupabaseClient? client,
  })  : _client = client ?? Supabase.instance.client,
        _authService = authService ?? SupabaseAuthService(client: client ?? Supabase.instance.client);

  @override
  bool get isAuthenticated => _authService.isAuthenticated;

  @override
  UserProfile? getCurrentUser() {
    final user = _authService.currentUser;
    if (user == null) return null;
    return _mapUserToProfile(user);
  }

  @override
  Stream<UserProfile?> get authStateChanges {
    return _authService.onAuthStateChange.map((state) {
      final user = state.session?.user;
      if (user == null) return null;
      return _mapUserToProfile(user);
    });
  }

  @override
  Future<UserProfile> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final response = await _authService.signUp(
      email: email,
      password: password,
      fullName: fullName,
    );

    final user = response.user;
    if (user == null) {
      throw const AuthFailure(
        'Registration could not be completed. Please check your email or try signing in.',
      );
    }

    return _mapUserToProfile(user, explicitFullName: fullName);
  }

  @override
  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _authService.signInWithPassword(
      email: email,
      password: password,
    );

    final user = response.user;
    if (user == null) {
      throw const AuthFailure('Failed to sign in. Please verify your credentials.');
    }

    // Try fetching database profile if available
    UserProfile? profile;
    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (data != null) {
        profile = UserProfile.fromSupabaseUser(
          user.id,
          user.email,
          fullName: data['full_name'] as String?,
          rawMetadata: user.userMetadata,
        );
      }
    } catch (e) {
      debugPrint('Note: Could not query profiles table (fallback to JWT metadata): $e');
    }

    return profile ?? _mapUserToProfile(user);
  }

  @override
  Future<void> signOut() async {
    await _authService.signOut();
  }

  UserProfile _mapUserToProfile(User user, {String? explicitFullName}) {
    return UserProfile.fromSupabaseUser(
      user.id,
      user.email,
      fullName: explicitFullName,
      rawMetadata: user.userMetadata,
    );
  }
}

class MockAuthRepository implements AuthRepository {
  UserProfile? _currentUser = MockData.defaultUser;
  final StreamController<UserProfile?> _controller = StreamController<UserProfile?>.broadcast();

  @override
  bool get isAuthenticated => _currentUser != null;

  @override
  UserProfile? getCurrentUser() => _currentUser;

  @override
  Stream<UserProfile?> get authStateChanges => _controller.stream;

  @override
  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) async {
    _currentUser = MockData.defaultUser.copyWith(email: email);
    _controller.add(_currentUser);
    return _currentUser!;
  }

  @override
  Future<UserProfile> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    _currentUser = MockData.defaultUser.copyWith(
      fullName: fullName,
      email: email,
    );
    _controller.add(_currentUser);
    return _currentUser!;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _controller.add(null);
  }
}
