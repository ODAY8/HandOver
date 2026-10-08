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
}
