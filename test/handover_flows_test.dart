import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:handover/features/onboarding/onboarding_screen.dart';
import 'package:handover/features/auth/welcome_auth_screen.dart';
import 'package:handover/features/home/home_screen.dart';
import 'package:handover/features/handovers/handovers_screen.dart';
import 'package:handover/features/handovers/create/create_step1_item_screen.dart';
import 'package:handover/features/handovers/details/handover_detail_screen.dart';
import 'package:handover/features/profile/profile_screen.dart';
import 'package:handover/providers/auth_provider.dart';
import 'package:handover/providers/handover_provider.dart';
import 'package:handover/providers/theme_provider.dart';

Widget createTestApp(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      ChangeNotifierProvider(create: (_) => HandoverProvider()),
    ],
    child: MaterialApp(
      home: child,
    ),
  );
}

void main() {
  testWidgets('OnboardingScreen renders title and navigation button', (tester) async {
    await tester.pumpWidget(createTestApp(const OnboardingScreen()));
    expect(find.text('Hand it over.\nKeep the proof.'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('WelcomeAuthScreen renders form fields and button', (tester) async {
    await tester.pumpWidget(createTestApp(const WelcomeAuthScreen()));
    expect(find.text('Your name. Your\naccountability.'), findsOneWidget);
    expect(find.text('Continue with email'), findsOneWidget);
  });

  testWidgets('HomeScreen renders greeting, metrics, and active handovers', (tester) async {
    await tester.pumpWidget(createTestApp(const HomeScreen()));
    expect(find.text('Good morning, Maya.'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Awaiting receipt'), findsOneWidget);
    expect(find.text('Overdue'), findsWidgets);
  });

  testWidgets('HandoversScreen renders segmented tabs and filter chips', (tester) async {
    await tester.pumpWidget(createTestApp(const HandoversScreen()));
    expect(find.text('My handovers'), findsOneWidget);
    expect(find.text('Sent by me'), findsOneWidget);
    expect(find.text('Received by me'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
  });

  testWidgets('CreateStep1ItemScreen renders item form', (tester) async {
    await tester.pumpWidget(createTestApp(const CreateStep1ItemScreen()));
    expect(find.text('What are you handing\nover?'), findsOneWidget);
    expect(find.text('Continue to receiver'), findsOneWidget);
  });

  testWidgets('HandoverDetailScreen renders item and custody chain', (tester) async {
    await tester.pumpWidget(createTestApp(const HandoverDetailScreen(handoverId: 'hn_01')));
    expect(find.text('MacBook Pro 14"'), findsWidgets);
    expect(find.text('SENDER'), findsOneWidget);
    expect(find.text('RECEIVER'), findsOneWidget);
  });

  testWidgets('ProfileScreen renders user profile and appearance settings', (tester) async {
    await tester.pumpWidget(createTestApp(const ProfileScreen()));
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Maya Chen'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
  });
}
