import 'package:flutter/material.dart';

class UserProfile {
  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final String organization;
  final String avatarInitials;
  final bool returnRemindersEnabled;
  final ThemeMode themeMode;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    this.avatarUrl,
    this.organization = 'HandOver Member',
    required this.avatarInitials,
    this.returnRemindersEnabled = true,
    this.themeMode = ThemeMode.light,
    this.createdAt,
    this.updatedAt,
  });

  UserProfile copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phone,
    String? avatarUrl,
    String? organization,
    String? avatarInitials,
    bool? returnRemindersEnabled,
    ThemeMode? themeMode,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      organization: organization ?? this.organization,
      avatarInitials: avatarInitials ?? this.avatarInitials,
      returnRemindersEnabled: returnRemindersEnabled ?? this.returnRemindersEnabled,
      themeMode: themeMode ?? this.themeMode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
    String? phone,
    String? avatarUrl,
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
      phone: phone ?? (rawMetadata?['phone'] as String?),
      avatarUrl: avatarUrl ?? (rawMetadata?['avatar_url'] as String?),
      organization: organization ?? (rawMetadata?['organization'] as String?) ?? 'HandOver Member',
      avatarInitials: initials.isEmpty ? 'HO' : initials,
      returnRemindersEnabled: true,
      themeMode: ThemeMode.system,
    );
  }

  /// Construct from public.profiles database table row
  factory UserProfile.fromRow(
    Map<String, dynamic> row, {
    String? authEmail,
    String? organization,
  }) {
    final id = row['id'] as String? ?? '';
    final fullName = (row['full_name'] as String?)?.trim() ?? '';
    final email = authEmail ?? (row['email'] as String?) ?? '';
    final phone = row['phone'] as String?;
    final avatarUrl = row['avatar_url'] as String?;
    final initials = extractInitials(fullName.isNotEmpty ? fullName : email);

    DateTime? createdAt;
    if (row['created_at'] != null) {
      createdAt = DateTime.tryParse(row['created_at'].toString());
    }

    DateTime? updatedAt;
    if (row['updated_at'] != null) {
      updatedAt = DateTime.tryParse(row['updated_at'].toString());
    }

    return UserProfile(
      id: id,
      fullName: fullName.isNotEmpty ? fullName : (email.isNotEmpty ? email.split('@').first : 'User'),
      email: email,
      phone: phone,
      avatarUrl: avatarUrl,
      organization: organization ?? 'HandOver Member',
      avatarInitials: initials.isEmpty ? 'HO' : initials,
      returnRemindersEnabled: true,
      themeMode: ThemeMode.system,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Convert to update payload for public.profiles table
  Map<String, dynamic> toUpdatePayload() {
    return {
      'full_name': fullName,
      if (phone != null) 'phone': phone,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }
}
