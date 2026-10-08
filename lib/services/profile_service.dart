// lib/services/profile_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Exception thrown when profile operations fail
class ProfileFailure implements Exception {
  final String message;
  final String? code;

  const ProfileFailure(this.message, {this.code});

  @override
  String toString() => message;
}

abstract class ProfileService {
  Future<Map<String, dynamic>?> getProfile(String userId);

  Future<Map<String, dynamic>> updateProfile({
    required String userId,
    required Map<String, dynamic> updates,
  });
}

class SupabaseProfileService implements ProfileService {
  final SupabaseClient _client;

  SupabaseProfileService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  Future<Map<String, dynamic>?> getProfile(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      return response;
    } on PostgrestException catch (e) {
      throw _mapPostgrestException(e);
    } catch (e) {
      if (e is ProfileFailure) rethrow;
      debugPrint('Unexpected error fetching profile: $e');
      throw const ProfileFailure(
        'Unable to load profile. Please check your network connection.',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> updateProfile({
    required String userId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      final payload = Map<String, dynamic>.from(updates);
      payload['id'] = userId;
      payload['updated_at'] = DateTime.now().toUtc().toIso8601String();

      // Ensure email cannot be updated through public.profiles update
      payload.remove('email');

      final response = await _client
          .from('profiles')
          .upsert(payload)
          .select()
          .single();

      return response;
    } on PostgrestException catch (e) {
      throw _mapPostgrestException(e);
    } catch (e) {
      if (e is ProfileFailure) rethrow;
      debugPrint('Unexpected error updating profile: $e');
      throw const ProfileFailure(
        'Unable to save profile changes. Please try again.',
      );
    }
  }

  ProfileFailure _mapPostgrestException(PostgrestException e) {
    final msg = e.message.toLowerCase();
    final code = e.code;

    if (code == '42501' || msg.contains('row-level security') || msg.contains('permission denied')) {
      return ProfileFailure(
        'Access denied. You can only view and update your own profile.',
        code: code,
      );
    }

    if (msg.contains('network') || msg.contains('timeout') || msg.contains('connection')) {
      return ProfileFailure(
        'Network error. Please check your internet connection.',
        code: code,
      );
    }

    return ProfileFailure(e.message, code: code);
  }
}
