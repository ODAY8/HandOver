import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/splash/splash_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/auth/welcome_auth_screen.dart';
import '../features/navigation/main_scaffold.dart';
import '../features/home/home_screen.dart';
import '../features/handovers/handovers_screen.dart';
import '../features/handovers/create/create_step1_item_screen.dart';
import '../features/handovers/create/create_step2_receiver_screen.dart';
import '../features/handovers/create/create_step3_review_screen.dart';
import '../features/handovers/details/handover_detail_screen.dart';
import '../features/handovers/details/confirm_return_screen.dart';
import '../features/handovers/details/completed_screen.dart';
import '../features/handovers/details/record_issue_screen.dart';
import '../features/handovers/details/expired_code_screen.dart';
import '../features/qr/share_qr_screen.dart';
import '../features/qr/scan_qr_screen.dart';
import '../features/qr/receiver_verify_screen.dart';
import '../features/qr/receipt_confirmed_screen.dart';
import '../features/profile/profile_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    // Splash
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),

    // Onboarding
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),

    // Auth / Welcome
    GoRoute(
      path: '/auth',
      builder: (context, state) => const WelcomeAuthScreen(),
    ),

    // Shell Route with Bottom Navigation Bar
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => MainScaffold(child: child),
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/handovers',
          builder: (context, state) => const HandoversScreen(),
        ),
        GoRoute(
          path: '/scan',
          builder: (context, state) => const ScanQrScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    ),

    // Create Handover Flow
    GoRoute(
      path: '/create-handover/step1',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const CreateStep1ItemScreen(),
    ),
    GoRoute(
      path: '/create-handover/step2',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final itemData = state.extra as Map<String, dynamic>? ?? {};
        return CreateStep2ReceiverScreen(itemData: itemData);
      },
    ),
    GoRoute(
      path: '/create-handover/step3',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>? ?? {};
        return CreateStep3ReviewScreen(data: data);
      },
    ),

    // QR & Verification Flows
    GoRoute(
      path: '/share-qr/:token',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final token = state.pathParameters['token'] ?? 'HN-1048';
        return ShareQrScreen(token: token);
      },
    ),
    GoRoute(
      path: '/receiver-verify/:token',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final token = state.pathParameters['token'] ?? 'HN-1048';
        return ReceiverVerifyScreen(token: token);
      },
    ),
    GoRoute(
      path: '/receipt-confirmed/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? 'hn_01';
        return ReceiptConfirmedScreen(handoverId: id);
      },
    ),

    // Handover Details & Actions
    GoRoute(
      path: '/handover-detail/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? 'hn_01';
        return HandoverDetailScreen(handoverId: id);
      },
    ),
    GoRoute(
      path: '/confirm-return/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? 'hn_01';
        return ConfirmReturnScreen(handoverId: id);
      },
    ),
    GoRoute(
      path: '/completed/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? 'hn_01';
        return CompletedScreen(handoverId: id);
      },
    ),
    GoRoute(
      path: '/record-issue/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? 'hn_01';
        return RecordIssueScreen(handoverId: id);
      },
    ),
    GoRoute(
      path: '/expired-code/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? 'hn_02';
        return ExpiredCodeScreen(handoverId: id);
      },
    ),
  ],
);
