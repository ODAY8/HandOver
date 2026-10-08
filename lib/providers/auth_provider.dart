// lib/providers/auth_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../repositories/auth_repository.dart';
import '../services/mock_data.dart';

class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepository;
  StreamSubscription<UserProfile?>? _authSubscription;

  UserProfile? _user;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _errorMessage;

  AuthProvider({AuthRepository? authRepository})
      : _authRepository = authRepository ?? _createDefaultRepository() {
    _init();
  }

  static AuthRepository _createDefaultRepository() {
    try {
      return SupabaseAuthRepository();
    } catch (_) {
      return MockAuthRepository();
    }
  }

  UserProfile get user => _user ?? MockData.defaultUser;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _init() {
    // Check initial user session
    final initialUser = _authRepository.getCurrentUser();
    if (initialUser != null) {
      _user = initialUser;
      _isAuthenticated = true;
    }

    // Subscribe to ongoing auth state changes
    _authSubscription = _authRepository.authStateChanges.listen((updatedUser) {
      if (updatedUser != null) {
        _user = updatedUser;
        _isAuthenticated = true;
      } else {
        _user = null;
        _isAuthenticated = false;
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// Sign in with email and password
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authRepository.signIn(
        email: email,
        password: password,
      );
      _user = user;
      _isAuthenticated = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign up with email, password, and full name
  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authRepository.signUp(
        email: email,
        password: password,
        fullName: fullName,
      );
      _user = user;
      _isAuthenticated = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authRepository.signOut();
    } finally {
      _user = null;
      _isAuthenticated = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateReminders(bool enabled) {
    if (_user != null) {
      _user = _user!.copyWith(returnRemindersEnabled: enabled);
      notifyListeners();
    }
  }

  void updateProfile({String? fullName, String? email, String? organization}) {
    if (_user != null) {
      _user = _user!.copyWith(
        fullName: fullName,
        email: email,
        organization: organization,
      );
      notifyListeners();
    }
  }
}
