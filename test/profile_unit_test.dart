// test/profile_unit_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:handover/features/profile/profile_screen.dart';
import 'package:handover/models/user_profile.dart';
import 'package:handover/providers/auth_provider.dart';
import 'package:handover/providers/profile_provider.dart';
import 'package:handover/providers/theme_provider.dart';
import 'package:handover/repositories/auth_repository.dart';
import 'package:handover/repositories/profile_repository.dart';
import 'package:handover/services/profile_service.dart';

void main() {
  group('UserProfile model mapping tests', () {
    test('fromRow parses public.profiles database row correctly', () {
      final now = DateTime.now().toUtc();
      final row = {
        'id': 'user_123_abc',
        'full_name': 'Sarah Connor',
        'phone': '+1 555-0144',
        'avatar_url': 'https://example.com/avatar.jpg',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final profile = UserProfile.fromRow(row, authEmail: 'sarah@resistance.org');
      expect(profile.id, 'user_123_abc');
      expect(profile.fullName, 'Sarah Connor');
      expect(profile.email, 'sarah@resistance.org');
      expect(profile.phone, '+1 555-0144');
      expect(profile.avatarUrl, 'https://example.com/avatar.jpg');
      expect(profile.avatarInitials, 'SC');
      expect(profile.createdAt, isNotNull);
    });

    test('toUpdatePayload serializes expected fields', () {
      const profile = UserProfile(
        id: 'user_xyz',
        fullName: 'John Connor',
        email: 'john@future.com',
        phone: '+1 555-9999',
        avatarUrl: 'https://example.com/john.png',
        avatarInitials: 'JC',
      );

      final payload = profile.toUpdatePayload();
      expect(payload['full_name'], 'John Connor');
      expect(payload['phone'], '+1 555-9999');
      expect(payload['avatar_url'], 'https://example.com/john.png');
      expect(payload['updated_at'], isNotNull);
      // Ensure email is not in update payload
      expect(payload.containsKey('email'), isFalse);
    });
  });

  group('MockProfileRepository tests', () {
    late MockProfileRepository repo;

    setUp(() {
      repo = MockProfileRepository(
        initialUser: const UserProfile(
          id: 'user_test_01',
          fullName: 'Test User',
          email: 'test@handover.app',
          phone: '+1 234-5678',
          avatarInitials: 'TU',
        ),
      );
    });

    test('fetchProfile returns user matching requested ID', () async {
      final profile = await repo.fetchProfile('user_test_01', authEmail: 'test@handover.app');
      expect(profile, isNotNull);
      expect(profile!.id, 'user_test_01');
      expect(profile.fullName, 'Test User');
      expect(profile.phone, '+1 234-5678');
    });

    test('saveProfile updates full name, phone, and avatar URL', () async {
      final updated = await repo.saveProfile(
        userId: 'user_test_01',
        fullName: 'Updated Name',
        phone: '+1 999-8888',
        avatarUrl: 'https://example.com/new.png',
      );

      expect(updated.fullName, 'Updated Name');
      expect(updated.phone, '+1 999-8888');
      expect(updated.avatarUrl, 'https://example.com/new.png');
      expect(updated.avatarInitials, 'UN');
    });
  });

  group('ProfileProvider state tests', () {
    late MockProfileRepository repo;
    late ProfileProvider provider;

    setUp(() {
      repo = MockProfileRepository(
        initialUser: const UserProfile(
          id: 'u_100',
          fullName: 'Alice Walker',
          email: 'alice@books.org',
          phone: '+1 555-1234',
          avatarInitials: 'AW',
        ),
      );
      provider = ProfileProvider(profileRepository: repo);
    });

    tearDown(() {
      provider.dispose();
    });

    test('initial state has no profile and no errors', () {
      expect(provider.profile, isNull);
      expect(provider.isLoading, isFalse);
      expect(provider.isSaving, isFalse);
      expect(provider.errorMessage, isNull);
    });

    test('loadProfile loads and updates profile state', () async {
      await provider.loadProfile(userId: 'u_100', authEmail: 'alice@books.org');

      expect(provider.isLoading, isFalse);
      expect(provider.hasProfile, isTrue);
      expect(provider.profile?.fullName, 'Alice Walker');
      expect(provider.profile?.email, 'alice@books.org');
    });

    test('updateProfile saves changes and sets successMessage', () async {
      final success = await provider.updateProfile(
        userId: 'u_100',
        fullName: 'Alice B. Walker',
        phone: '+1 555-9876',
      );

      expect(success, isTrue);
      expect(provider.isSaving, isFalse);
      expect(provider.profile?.fullName, 'Alice B. Walker');
      expect(provider.profile?.phone, '+1 555-9876');
      expect(provider.successMessage, 'Profile updated successfully.');
      expect(provider.errorMessage, isNull);
    });

    test('unauthenticated update (empty userId) fails gracefully', () async {
      final success = await provider.updateProfile(
        userId: '',
        fullName: 'No User',
      );

      expect(success, isFalse);
      expect(provider.errorMessage, contains('No authenticated user session found'));
    });

    test('handles failure from failing repository', () async {
      final failingRepo = _FailingProfileRepository();
      final failingProvider = ProfileProvider(profileRepository: failingRepo);

      final success = await failingProvider.updateProfile(
        userId: 'u_fail',
        fullName: 'Fail Test',
      );

      expect(success, isFalse);
      expect(failingProvider.errorMessage, contains('Database write failed'));
      failingProvider.dispose();
    });
  });

  group('ProfileScreen widget rendering and edit dialog tests', () {
    testWidgets('renders profile fields and displays phone status', (tester) async {
      final authRepo = MockAuthRepository();
      final profileRepo = MockProfileRepository(
        initialUser: const UserProfile(
          id: 'user_render_test',
          fullName: 'David Bowie',
          email: 'david@stardust.com',
          phone: '+1 555-8888',
          avatarInitials: 'DB',
        ),
      );

      final authProv = AuthProvider(authRepository: authRepo);
      final profileProv = ProfileProvider(profileRepository: profileRepo);
      final themeProv = ThemeProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeProvider>.value(value: themeProv),
            ChangeNotifierProvider<AuthProvider>.value(value: authProv),
            ChangeNotifierProvider<ProfileProvider>.value(value: profileProv),
          ],
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('David Bowie'), findsWidgets);
      expect(find.text('+1 555-8888'), findsOneWidget);
      expect(find.text('Receipt identity'), findsOneWidget);

      authProv.dispose();
      profileProv.dispose();
    });

    testWidgets('tapping edit button opens dialog and saves new full name and phone', (tester) async {
      final authRepo = MockAuthRepository();
      final profileRepo = MockProfileRepository(
        initialUser: const UserProfile(
          id: 'user_edit_test',
          fullName: 'Miles Davis',
          email: 'miles@jazz.org',
          phone: '+1 555-4321',
          avatarInitials: 'MD',
        ),
      );

      final authProv = AuthProvider(authRepository: authRepo);
      final profileProv = ProfileProvider(profileRepository: profileRepo);
      final themeProv = ThemeProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeProvider>.value(value: themeProv),
            ChangeNotifierProvider<AuthProvider>.value(value: authProv),
            ChangeNotifierProvider<ProfileProvider>.value(value: profileProv),
          ],
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Tap edit icon button
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Edit receipt identity'), findsOneWidget);
      expect(find.text('Email (Read-only)'), findsOneWidget);

      // Find full name input and enter new name
      final nameFinder = find.widgetWithText(TextField, 'Full name');
      await tester.enterText(nameFinder, 'Miles Dewey Davis');

      // Tap Save button
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Verify updated profile reflected in UI
      expect(find.text('Miles Dewey Davis'), findsWidgets);

      authProv.dispose();
      profileProv.dispose();
    });

    testWidgets('sign out button invokes auth sign out', (tester) async {
      final authRepo = MockAuthRepository();
      final profileRepo = MockProfileRepository();

      final authProv = AuthProvider(authRepository: authRepo);
      final profileProv = ProfileProvider(profileRepository: profileRepo);
      final themeProv = ThemeProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeProvider>.value(value: themeProv),
            ChangeNotifierProvider<AuthProvider>.value(value: authProv),
            ChangeNotifierProvider<ProfileProvider>.value(value: profileProv),
          ],
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Scroll to sign out button
      await tester.ensureVisible(find.text('Sign out'));
      await tester.pumpAndSettle();

      // Tap Sign out
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      expect(authProv.isAuthenticated, isFalse);

      authProv.dispose();
      profileProv.dispose();
    });
  });
}

class _FailingProfileRepository implements ProfileRepository {
  @override
  Future<UserProfile?> fetchProfile(String userId, {String? authEmail}) async {
    throw const ProfileFailure('Database read failed due to network timeout.');
  }

  @override
  Future<UserProfile> saveProfile({
    required String userId,
    required String fullName,
    String? phone,
    String? avatarUrl,
    String? authEmail,
  }) async {
    throw const ProfileFailure('Database write failed. Permission denied.');
  }
}
