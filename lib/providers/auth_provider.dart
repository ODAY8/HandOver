import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/mock_data.dart';

class AuthProvider extends ChangeNotifier {
  UserProfile _user = MockData.defaultUser;
  bool _isAuthenticated = true; // Set to true for convenient browsing, toggleable

  UserProfile get user => _user;
  bool get isAuthenticated => _isAuthenticated;

  void signIn({required String name, required String email}) {
    final initials = name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase();
    _user = _user.copyWith(
      fullName: name,
      email: email,
      avatarInitials: initials.isEmpty ? 'MC' : initials,
    );
    _isAuthenticated = true;
    notifyListeners();
  }

  void signOut() {
    _isAuthenticated = false;
    notifyListeners();
  }

  void updateReminders(bool enabled) {
    _user = _user.copyWith(returnRemindersEnabled: enabled);
    notifyListeners();
  }

  void updateProfile({String? fullName, String? email, String? organization}) {
    _user = _user.copyWith(
      fullName: fullName,
      email: email,
      organization: organization,
    );
    notifyListeners();
  }
}
