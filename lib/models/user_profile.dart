import 'package:flutter/material.dart';

class UserProfile {
  final String id;
  final String fullName;
  final String email;
  final String organization;
  final String avatarInitials;
  final bool returnRemindersEnabled;
  final ThemeMode themeMode;

  const UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.organization,
    required this.avatarInitials,
    this.returnRemindersEnabled = true,
    this.themeMode = ThemeMode.light,
  });

  UserProfile copyWith({
    String? id,
    String? fullName,
    String? email,
    String? organization,
    String? avatarInitials,
    bool? returnRemindersEnabled,
    ThemeMode? themeMode,
  }) {
    return UserProfile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      organization: organization ?? this.organization,
      avatarInitials: avatarInitials ?? this.avatarInitials,
      returnRemindersEnabled: returnRemindersEnabled ?? this.returnRemindersEnabled,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  static String extractInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'U';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  factory UserProfile.fromSupabaseUser(
    String id,
    String? email, {
    String? fullName,
    String? organization,
    Map<String, dynamic>? rawMetadata,
  }) {
    final name = (fullName != null && fullName.trim().isNotEmpty)
        ? fullName.trim()
        : (rawMetadata?['full_name'] as String?)?.trim() ??
            (email != null && email.contains('@') ? email.split('@').first : 'User');
    final initials = extractInitials(name);
    return UserProfile(
      id: id,
      fullName: name,
      email: email ?? '',
      organization: organization ?? (rawMetadata?['organization'] as String?) ?? 'HandOver Member',
      avatarInitials: initials.isEmpty ? 'HO' : initials,
      returnRemindersEnabled: true,
      themeMode: ThemeMode.system,
    );
  }
}

