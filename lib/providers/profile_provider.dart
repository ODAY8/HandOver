// lib/providers/profile_provider.dart

import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../repositories/profile_repository.dart';

class ProfileProvider extends ChangeNotifier {
  final ProfileRepository _repository;

  UserProfile? _profile;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  ProfileProvider({ProfileRepository? profileRepository})
      : _repository = profileRepository ?? _createDefaultRepository();

  static ProfileRepository _createDefaultRepository() {
    try {
      return SupabaseProfileRepository();
    } catch (_) {
      // In test or non-initialized environments
      return MockProfileRepository();
    }
  }

  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  bool get hasProfile => _profile != null;

  void clearMessages() {
    if (_errorMessage != null || _successMessage != null) {
      _errorMessage = null;
      _successMessage = null;
      notifyListeners();
    }
  }

  void reset() {
    _profile = null;
    _isLoading = false;
    _isSaving = false;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  /// Load profile from repository
  Future<void> loadProfile({
    required String userId,
    String? authEmail,
  }) async {
    if (userId.isEmpty) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fetched = await _repository.fetchProfile(
        userId,
        authEmail: authEmail,
      );
      if (fetched != null) {
        _profile = fetched;
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update full name, phone, and optional avatarUrl
  Future<bool> updateProfile({
    required String userId,
    required String fullName,
    String? phone,
    String? avatarUrl,
    String? authEmail,
  }) async {
    if (userId.isEmpty) {
      _errorMessage = 'No authenticated user session found.';
      notifyListeners();
      return false;
    }

    _isSaving = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final updated = await _repository.saveProfile(
        userId: userId,
        fullName: fullName,
        phone: phone,
        avatarUrl: avatarUrl,
        authEmail: authEmail ?? _profile?.email,
      );

      _profile = updated;
      _successMessage = 'Profile updated successfully.';
      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }
}
