// test/auth_unit_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:handover/features/auth/welcome_auth_screen.dart';
import 'package:handover/models/user_profile.dart';
import 'package:handover/providers/auth_provider.dart';
import 'package:handover/repositories/auth_repository.dart';
import 'package:handover/services/auth_service.dart';

void main() {
  group('AuthService & AuthFailure tests', () {
    test('AuthFailure holds message and optional code', () {
      const failure = AuthFailure('Invalid credentials', code: '400');
      expect(failure.message, 'Invalid credentials');
      expect(failure.code, '400');
      expect(failure.toString(), 'Invalid credentials');
    });
  });

  group('UserProfile model tests', () {
    test('extractInitials handles multi-word and single-word names', () {
      expect(UserProfile.extractInitials('Maya Chen'), 'MC');
      expect(UserProfile.extractInitials('Alex'), 'A');
      expect(UserProfile.extractInitials('   '), 'U');
      expect(UserProfile.extractInitials('John Robert Doe'), 'JR');
    });

    test('fromSupabaseUser extracts name and sets sensible defaults', () {
      final profile = UserProfile.fromSupabaseUser(
        'user-123',
        'tester@example.com',
        fullName: 'Jane Doe',
      );
      expect(profile.id, 'user-123');
      expect(profile.fullName, 'Jane Doe');
      expect(profile.email, 'tester@example.com');
      expect(profile.avatarInitials, 'JD');
    });
  });

  group('MockAuthRepository tests', () {
    late MockAuthRepository repo;

    setUp(() {
      repo = MockAuthRepository();
    });

    test('initial state is authenticated with default user', () {
      expect(repo.isAuthenticated, isTrue);
      expect(repo.getCurrentUser(), isNotNull);
    });

    test('signIn updates user and emits on authStateChanges', () async {
      final expectation = expectLater(
        repo.authStateChanges,
        emits(predicate<UserProfile?>((u) => u?.email == 'new@example.com')),
      );

      final user = await repo.signIn(email: 'new@example.com', password: 'password123');
      expect(user.email, 'new@example.com');
      await expectation;
    });

    test('signUp updates user name and email', () async {
      final user = await repo.signUp(
        email: 'signup@example.com',
        password: 'password123',
        fullName: 'New User',
      );
      expect(user.fullName, 'New User');
      expect(user.email, 'signup@example.com');
    });

    test('signOut clears user and emits null', () async {
      final expectation = expectLater(
        repo.authStateChanges,
        emits(isNull),
      );

      await repo.signOut();
      expect(repo.isAuthenticated, isFalse);
      expect(repo.getCurrentUser(), isNull);
      await expectation;
    });
  });

  group('AuthProvider with MockAuthRepository tests', () {
    late MockAuthRepository repo;
    late AuthProvider provider;

    setUp(() {
      repo = MockAuthRepository();
      provider = AuthProvider(authRepository: repo);
    });

    tearDown(() {
      provider.dispose();
    });

    test('initial state reflects repo state', () {
      expect(provider.isAuthenticated, isTrue);
      expect(provider.user.email, isNotEmpty);
      expect(provider.isLoading, isFalse);
      expect(provider.errorMessage, isNull);
    });

    test('signIn success transitions state cleanly', () async {
      final success = await provider.signIn(
        email: 'test@domain.com',
        password: 'Password123!',
      );
      expect(success, isTrue);
      expect(provider.isAuthenticated, isTrue);
      expect(provider.user.email, 'test@domain.com');
      expect(provider.errorMessage, isNull);
    });

    test('signUp success transitions state cleanly', () async {
      final success = await provider.signUp(
        email: 'created@domain.com',
        password: 'Password123!',
        fullName: 'Alex Stone',
      );
      expect(success, isTrue);
      expect(provider.isAuthenticated, isTrue);
      expect(provider.user.fullName, 'Alex Stone');
      expect(provider.user.email, 'created@domain.com');
    });

    test('signOut terminates session', () async {
      await provider.signOut();
      expect(provider.isAuthenticated, isFalse);
    });

    test('clearError resets errorMessage', () async {
      // Force an error via custom failing repo
      final failingRepo = _FailingAuthRepository();
      final failingProvider = AuthProvider(authRepository: failingRepo);

      final success = await failingProvider.signIn(email: 'fail@test.com', password: 'bad');
      expect(success, isFalse);
      expect(failingProvider.errorMessage, contains('Invalid credentials'));

      failingProvider.clearError();
      expect(failingProvider.errorMessage, isNull);
      failingProvider.dispose();
    });
  });

  group('WelcomeAuthScreen widget interaction tests', () {
    testWidgets('renders sign-in mode by default without full name field', (tester) async {
      final repo = MockAuthRepository();
      final provider = AuthProvider(authRepository: repo);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: provider,
            child: const WelcomeAuthScreen(),
          ),
        ),
      );

      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Continue with email'), findsOneWidget);
      // In sign-in mode, full name field is not shown
      expect(find.text('Full name'), findsNothing);
      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);

      provider.dispose();
    });

    testWidgets('switching to Create Account reveals Full name field', (tester) async {
      final repo = MockAuthRepository();
      final provider = AuthProvider(authRepository: repo);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: provider,
            child: const WelcomeAuthScreen(),
          ),
        ),
      );

      // Tap 'Create Account' tab
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      // Now Full name field is visible
      expect(find.text('Full name'), findsOneWidget);
      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);

      provider.dispose();
    });

    testWidgets('validation prevents submission with empty email', (tester) async {
      final repo = MockAuthRepository();
      final provider = AuthProvider(authRepository: repo);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthProvider>.value(
            value: provider,
            child: const WelcomeAuthScreen(),
          ),
        ),
      );

      // Scroll button into view inside SingleChildScrollView and tap
      await tester.ensureVisible(find.text('Continue with email'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue with email'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email address.'), findsOneWidget);

      provider.dispose();
    });
  });
}

class _FailingAuthRepository implements AuthRepository {
  @override
  bool get isAuthenticated => false;

  @override
  UserProfile? getCurrentUser() => null;

  @override
  Stream<UserProfile?> get authStateChanges => const Stream.empty();

  @override
  Future<UserProfile> signIn({required String email, required String password}) async {
    throw const AuthFailure('Invalid credentials provided.');
  }

  @override
  Future<UserProfile> signUp({required String email, required String password, required String fullName}) async {
    throw const AuthFailure('An account with this email already exists.');
  }

  @override
  Future<void> signOut() async {}
}
