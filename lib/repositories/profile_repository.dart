// lib/repositories/profile_repository.dart

import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import '../services/mock_data.dart';
import '../services/profile_service.dart';

abstract class ProfileRepository {
  Future<UserProfile?> fetchProfile(String userId, {String? authEmail});

  Future<UserProfile> saveProfile({
    required String userId,
    required String fullName,
    String? phone,
    String? avatarUrl,
    String? authEmail,
  });
}

class SupabaseProfileRepository implements ProfileRepository {
  final ProfileService _service;

  SupabaseProfileRepository({ProfileService? service, SupabaseClient? client})
      : _service = service ?? SupabaseProfileService(client: client);

  @override
  Future<UserProfile?> fetchProfile(String userId, {String? authEmail}) async {
    final row = await _service.getProfile(userId);
    if (row == null) return null;
    return UserProfile.fromRow(row, authEmail: authEmail);
  }

  @override
  Future<UserProfile> saveProfile({
    required String userId,
    required String fullName,
    String? phone,
    String? avatarUrl,
    String? authEmail,
  }) async {
    final updates = <String, dynamic>{
      'full_name': fullName.trim(),
      if (phone != null) 'phone': phone.trim(),
      if (avatarUrl != null) 'avatar_url': avatarUrl.trim(),
    };

    final savedRow = await _service.updateProfile(
      userId: userId,
      updates: updates,
    );

    return UserProfile.fromRow(savedRow, authEmail: authEmail);
  }
}

class MockProfileRepository implements ProfileRepository {
  UserProfile _user;

  MockProfileRepository({UserProfile? initialUser})
      : _user = initialUser ?? MockData.defaultUser;

  @override
  Future<UserProfile?> fetchProfile(String userId, {String? authEmail}) async {
    return _user.copyWith(
      id: userId,
      email: authEmail ?? _user.email,
    );
  }

  @override
  Future<UserProfile> saveProfile({
    required String userId,
    required String fullName,
    String? phone,
    String? avatarUrl,
    String? authEmail,
  }) async {
    _user = _user.copyWith(
      id: userId,
      fullName: fullName,
      phone: phone,
      avatarUrl: avatarUrl,
      email: authEmail ?? _user.email,
      avatarInitials: UserProfile.extractInitials(fullName),
    );
    return _user;
  }
}
