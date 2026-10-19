// test/return_details_dates_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:handover/features/handovers/details/confirm_return_screen.dart';
import 'package:handover/features/handovers/details/expired_code_screen.dart';
import 'package:handover/features/handovers/details/completed_screen.dart';
import 'package:handover/features/handovers/details/handover_detail_screen.dart';
import 'package:handover/features/handovers/details/record_issue_screen.dart';
import 'package:handover/core/widgets/app_button.dart';
import 'package:handover/core/widgets/custody_stepper.dart';
import 'package:handover/core/widgets/handover_card.dart';
import 'package:handover/models/handover.dart';
import 'package:handover/models/handover_status.dart';
import 'package:handover/models/handover_event.dart';
import 'package:handover/providers/auth_provider.dart';
import 'package:handover/providers/handover_provider.dart';
import 'package:handover/providers/profile_provider.dart';
import 'package:handover/providers/theme_provider.dart';
import 'package:handover/repositories/handover_repository.dart';

Widget createTestApp(Widget child, {List<Handover>? handovers}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      ChangeNotifierProvider(create: (_) => ProfileProvider()),
      ChangeNotifierProvider(
        create: (_) {
          final repo = MockHandoverRepository(initialItems: handovers);
          final p = HandoverProvider(handoverRepository: repo);
          p.loadHandovers(userId: 'test_user', userEmail: 'test@user.com');
          return p;
        },
      ),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  group('ConfirmReturnScreen Date Formatting', () {
    testWidgets(
      'renders "Recorded upon confirmation" when return is not yet confirmed (preview state)',
      (tester) async {
        const item = Handover(
          id: 'hn_confirm_preview',
          token: 'HN-PREVIEW',
          itemName: 'MacBook Pro',
          category: 'Electronics',
          identifier: 'MBP-14',
          description: 'Laptop',
          senderName: 'Maya',
          senderOrg: 'Northline',
          receiverName: 'Jordan',
          receiverOrg: 'SoundLab',
          receiverEmail: 'jordan@soundlab.com',
          returnExpected: true,
          returnedAt: null,
          status: HandoverStatus.received,
        );

        await tester.pumpWidget(
          createTestApp(
            const ConfirmReturnScreen(handoverId: 'hn_confirm_preview'),
            handovers: [item],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Return date'), findsOneWidget);
        expect(find.text('Recorded upon confirmation'), findsOneWidget);
        expect(find.text('18 Oct 2026 • 2:30 PM'), findsNothing);
      },
    );

    testWidgets(
      'renders formatted return date when returnedAt is already recorded',
      (tester) async {
        final returnedDate = DateTime(2026, 11, 20, 16, 45);
        final item = Handover(
          id: 'hn_confirm_done',
          token: 'HN-DONE',
          itemName: 'MacBook Pro',
          category: 'Electronics',
          identifier: 'MBP-14',
          description: 'Laptop',
          senderName: 'Maya',
          senderOrg: 'Northline',
          receiverName: 'Jordan',
          receiverOrg: 'SoundLab',
          receiverEmail: 'jordan@soundlab.com',
          returnExpected: true,
          returnedAt: returnedDate,
          status: HandoverStatus.returned,
        );

        await tester.pumpWidget(
          createTestApp(
            const ConfirmReturnScreen(handoverId: 'hn_confirm_done'),
            handovers: [item],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Return date'), findsOneWidget);
        expect(find.text('20 Nov 2026 • 4:45 PM'), findsOneWidget);
      },
    );
  });

  group('ExpiredCodeScreen Date Formatting', () {
    testWidgets(
      'calculates and renders expiry timestamp (+24h) from createdAt',
      (tester) async {
        final created = DateTime(2026, 10, 10, 8, 30);
        final item = Handover(
          id: 'hn_expired_date',
          token: 'HN-EXP1',
          itemName: 'Hard Drive',
          category: 'Storage',
          identifier: 'HDD-01',
          description: 'Backup drive',
          senderName: 'Maya',
          senderOrg: 'Northline',
          receiverName: 'Alex',
          receiverOrg: 'Studio',
          receiverEmail: 'alex@studio.com',
          returnExpected: false,
          createdAt: created,
          status: HandoverStatus.expired,
        );

        await tester.pumpWidget(
          createTestApp(
            const ExpiredCodeScreen(handoverId: 'hn_expired_date'),
            handovers: [item],
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Expired 11 Oct 2026 at 8:30 AM'),
          findsOneWidget,
        );
      },
    );

    testWidgets('renders safe fallback text when createdAt is null', (
      tester,
    ) async {
      const item = Handover(
        id: 'hn_expired_null',
        token: 'HN-EXPNULL',
        itemName: 'Hard Drive',
        category: 'Storage',
        identifier: 'HDD-01',
        description: 'Backup drive',
        senderName: 'Maya',
        senderOrg: 'Northline',
        receiverName: 'Alex',
        receiverOrg: 'Studio',
        receiverEmail: 'alex@studio.com',
        returnExpected: false,
        createdAt: null,
        events: [],
        status: HandoverStatus.expired,
      );

      await tester.pumpWidget(
        createTestApp(
          const ExpiredCodeScreen(handoverId: 'hn_expired_null'),
          handovers: [item],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Code expired. Code expiry is not a cancellation'),
        findsOneWidget,
      );
    });
  });

  group('CompletedScreen Date Formatting and Fallbacks', () {
    testWidgets(
      'renders actual returnDueAt formatted and actual events without fabricated fallback events',
      (tester) async {
        final due = DateTime(2026, 12, 1, 17, 0);
        final ev = HandoverEvent(
          id: 'ev_real_1',
          title: 'Maya created the record',
          timestamp: DateTime(2026, 11, 28, 10, 0),
          type: HandoverEventType.created,
        );
        final item = Handover(
          id: 'hn_completed_real',
          token: 'HN-COMP1',
          itemName: 'Synthesizer',
          category: 'Audio',
          identifier: 'SYN-88',
          description: 'Keyboard',
          senderName: 'Maya',
          senderOrg: 'Northline',
          receiverName: 'Jordan',
          receiverOrg: 'SoundLab',
          receiverEmail: 'jordan@soundlab.com',
          returnExpected: true,
          returnDueAt: due,
          events: [ev],
          status: HandoverStatus.returned,
        );

        await tester.pumpWidget(
          createTestApp(
            const CompletedScreen(handoverId: 'hn_completed_real'),
            handovers: [item],
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Return due: 1 Dec 2026 • 5:00 PM'),
          findsOneWidget,
        );
        expect(find.text('Maya created the record'), findsOneWidget);
        // Ensure fabricated hardcoded events are NOT present
        expect(find.text('Condition issue resolved'), findsNothing);
      },
    );

    testWidgets('renders "No return required" when returnExpected is false', (
      tester,
    ) async {
      const item = Handover(
        id: 'hn_completed_gift',
        token: 'HN-GIFT2',
        itemName: 'Poster',
        category: 'Print',
        identifier: 'PST-01',
        description: 'Conference poster',
        senderName: 'Maya',
        senderOrg: 'Northline',
        receiverName: 'Jordan',
        receiverOrg: 'SoundLab',
        receiverEmail: 'jordan@soundlab.com',
        returnExpected: false,
        returnDueAt: null,
        events: [],
        status: HandoverStatus.returned,
      );

      await tester.pumpWidget(
        createTestApp(
          const CompletedScreen(handoverId: 'hn_completed_gift'),
          handovers: [item],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('No return required'), findsOneWidget);
      expect(find.text('No custody events recorded'), findsOneWidget);
    });
  });

  group('HandoverDetailScreen Overdue and Disputed Dates', () {
    testWidgets('renders dynamic overdue banner when handover is overdue', (
      tester,
    ) async {
      // Due in past
      final due = DateTime.now().subtract(const Duration(days: 2, hours: 3));
      final item = Handover(
        id: 'hn_detail_overdue',
        token: 'HN-OD1',
        itemName: 'Audio Interface',
        category: 'Audio',
        identifier: 'AUD-02',
        description: 'Interface',
        senderName: 'Maya',
        senderOrg: 'Northline',
        receiverName: 'Jordan',
        receiverOrg: 'SoundLab',
        receiverEmail: 'jordan@soundlab.com',
        returnExpected: true,
        returnDueAt: due,
        status: HandoverStatus.overdue,
      );

      await tester.pumpWidget(
        createTestApp(
          const HandoverDetailScreen(handoverId: 'hn_detail_overdue'),
          handovers: [item],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('overdue'), findsWidgets);
      expect(
        find.textContaining('has not been confirmed returned'),
        findsOneWidget,
      );
    });

    testWidgets(
      'does not show overdue banner when handover status is returned even if returnDueAt is in the past',
      (tester) async {
        final due = DateTime.now().subtract(const Duration(days: 5));
        final item = Handover(
          id: 'hn_detail_returned',
          token: 'HN-RET1',
          itemName: 'Audio Interface',
          category: 'Audio',
          identifier: 'AUD-02',
          description: 'Interface',
          senderName: 'Maya',
          senderOrg: 'Northline',
          receiverName: 'Jordan',
          receiverOrg: 'SoundLab',
          receiverEmail: 'jordan@soundlab.com',
          returnExpected: true,
          returnDueAt: due,
          status: HandoverStatus.returned,
        );

        await tester.pumpWidget(
          createTestApp(
            const HandoverDetailScreen(handoverId: 'hn_detail_returned'),
            handovers: [item],
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('has not been confirmed returned'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'does not show overdue banner when handover status is cancelled even if returnDueAt is in the past',
      (tester) async {
        final due = DateTime.now().subtract(const Duration(days: 5));
        final item = Handover(
          id: 'hn_detail_cancelled',
          token: 'HN-CNC1',
          itemName: 'Audio Interface',
          category: 'Audio',
          identifier: 'AUD-02',
          description: 'Interface',
          senderName: 'Maya',
          senderOrg: 'Northline',
          receiverName: 'Jordan',
          receiverOrg: 'SoundLab',
          receiverEmail: 'jordan@soundlab.com',
          returnExpected: true,
          returnDueAt: due,
          status: HandoverStatus.cancelled,
        );

        await tester.pumpWidget(
          createTestApp(
            const HandoverDetailScreen(handoverId: 'hn_detail_cancelled'),
            handovers: [item],
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('has not been confirmed returned'),
          findsNothing,
        );
      },
    );

    testWidgets('renders dynamic issue recorded timestamp in disputed banner', (
      tester,
    ) async {
      final issueTime = DateTime(2026, 10, 22, 11, 15);
      final ev = HandoverEvent(
        id: 'ev_issue_1',
        title: 'Item condition differs',
        timestamp: issueTime,
        type: HandoverEventType.issueRecorded,
      );
      final item = Handover(
        id: 'hn_detail_disputed',
        token: 'HN-DISP1',
        itemName: 'Monitor',
        category: 'Display',
        identifier: 'MON-27',
        description: '4K Screen',
        senderName: 'Maya',
        senderOrg: 'Northline',
        receiverName: 'Jordan',
        receiverOrg: 'SoundLab',
        receiverEmail: 'jordan@soundlab.com',
        returnExpected: true,
        issueReason: 'Scratch on screen',
        events: [ev],
        status: HandoverStatus.disputed,
      );

      await tester.pumpWidget(
        createTestApp(
          const HandoverDetailScreen(handoverId: 'hn_detail_disputed'),
          handovers: [item],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Scratch on screen'), findsOneWidget);
      expect(find.textContaining('22 Oct 2026 at 11:15 AM'), findsOneWidget);
    });

    testWidgets(
      'does not show overdue banner for pending handover even if returnDueAt is in the past',
      (tester) async {
        final pastDue = DateTime.now().subtract(const Duration(days: 3));
        final item = Handover(
          id: 'hn_pending_past_due',
          token: 'HN-PND1',
          itemName: 'Projector',
          category: 'Electronics',
          identifier: 'PRJ-01',
          description: 'HD Projector',
          senderName: 'Maya',
          senderOrg: 'Northline',
          receiverName: 'Jordan',
          receiverOrg: 'SoundLab',
          receiverEmail: 'jordan@soundlab.com',
          returnExpected: true,
          returnDueAt: pastDue,
          receivedAt: null,
          status: HandoverStatus.pending,
        );

        await tester.pumpWidget(
          createTestApp(
            const HandoverDetailScreen(handoverId: 'hn_pending_past_due'),
            handovers: [item],
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('has not been confirmed returned'),
          findsNothing,
        );
        expect(find.text('Show QR code'), findsOneWidget);
        expect(find.text('Cancel handover'), findsOneWidget);
      },
    );

    testWidgets(
      'does not show overdue banner for expired handover even if returnDueAt is in the past',
      (tester) async {
        final pastDue = DateTime.now().subtract(const Duration(days: 4));
        final item = Handover(
          id: 'hn_expired_past_due',
          token: 'HN-EXP2',
          itemName: 'Projector',
          category: 'Electronics',
          identifier: 'PRJ-02',
          description: 'HD Projector',
          senderName: 'Maya',
          senderOrg: 'Northline',
          receiverName: 'Jordan',
          receiverOrg: 'SoundLab',
          receiverEmail: 'jordan@soundlab.com',
          returnExpected: true,
          returnDueAt: pastDue,
          receivedAt: null,
          status: HandoverStatus.expired,
        );

        await tester.pumpWidget(
          createTestApp(
            const HandoverDetailScreen(handoverId: 'hn_expired_past_due'),
            handovers: [item],
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('has not been confirmed returned'),
          findsNothing,
        );
        expect(find.text('View expired code'), findsOneWidget);
      },
    );

    testWidgets(
      'picks the latest issueRecorded timestamp when multiple issue events exist',
      (tester) async {
        final firstIssue = DateTime(2026, 10, 15, 9, 0);
        final secondIssue = DateTime(2026, 10, 25, 14, 30);
        final item = Handover(
          id: 'hn_multi_issue',
          token: 'HN-MULTI-ISSUE',
          itemName: 'Camera',
          category: 'Optics',
          identifier: 'CAM-99',
          description: 'DSLR',
          senderName: 'Maya',
          senderOrg: 'Northline',
          receiverName: 'Jordan',
          receiverOrg: 'SoundLab',
          receiverEmail: 'jordan@soundlab.com',
          returnExpected: true,
          issueReason: 'Lens scratch',
          events: [
            HandoverEvent(
              id: 'ev_1',
              title: 'Initial minor scuff',
              timestamp: firstIssue,
              type: HandoverEventType.issueRecorded,
            ),
            HandoverEvent(
              id: 'ev_2',
              title: 'Lens scratch recorded',
              timestamp: secondIssue,
              type: HandoverEventType.issueRecorded,
            ),
          ],
          status: HandoverStatus.disputed,
        );

        await tester.pumpWidget(
          createTestApp(
            const HandoverDetailScreen(handoverId: 'hn_multi_issue'),
            handovers: [item],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('25 Oct 2026 at 2:30 PM'), findsOneWidget);
        expect(find.textContaining('15 Oct 2026 at 9:00 AM'), findsNothing);
      },
    );
  });

  group('Invalid Handover ID Lookup & Fallback Prevention', () {
    const existingItem = Handover(
      id: 'hn_first_real_id',
      token: 'HN-FIRST-EXISTING',
      itemName: 'First Existing Item',
      category: 'Electronics',
      identifier: 'EXIST-01',
      description: 'First',
      senderName: 'Maya',
      senderOrg: 'Northline',
      receiverName: 'Jordan',
      receiverOrg: 'SoundLab',
      receiverEmail: 'jordan@soundlab.com',
      returnExpected: true,
      status: HandoverStatus.received,
    );

    testWidgets(
      'HandoverDetailScreen displays empty state and does not fallback to first handover',
      (tester) async {
        await tester.pumpWidget(
          createTestApp(
            const HandoverDetailScreen(handoverId: 'invalid_id_999'),
            handovers: [existingItem],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Handover record not found'), findsOneWidget);
        expect(find.text('First Existing Item'), findsNothing);
      },
    );

    testWidgets(
      'ExpiredCodeScreen displays empty state and does not fallback to first handover',
      (tester) async {
        await tester.pumpWidget(
          createTestApp(
            const ExpiredCodeScreen(handoverId: 'invalid_id_999'),
            handovers: [existingItem],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Handover record not found'), findsOneWidget);
        expect(find.text('First Existing Item'), findsNothing);
      },
    );

    testWidgets(
      'ConfirmReturnScreen displays empty state and does not fallback to first handover',
      (tester) async {
        await tester.pumpWidget(
          createTestApp(
            const ConfirmReturnScreen(handoverId: 'invalid_id_999'),
            handovers: [existingItem],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Handover record not found'), findsOneWidget);
        expect(find.text('First Existing Item'), findsNothing);
      },
    );

    testWidgets(
      'CompletedScreen displays empty state and does not fallback to first handover',
      (tester) async {
        await tester.pumpWidget(
          createTestApp(
            const CompletedScreen(handoverId: 'invalid_id_999'),
            handovers: [existingItem],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Handover record not found'), findsOneWidget);
        expect(find.text('First Existing Item'), findsNothing);
      },
    );

    testWidgets(
      'RecordIssueScreen displays empty state and does not fallback to first handover',
      (tester) async {
        await tester.pumpWidget(
          createTestApp(
            const RecordIssueScreen(handoverId: 'invalid_id_999'),
            handovers: [existingItem],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Handover record not found'), findsOneWidget);
        expect(find.text('First Existing Item'), findsNothing);
      },
    );
  });

  group('Event Ordering & Multiple Event Resolution', () {
    testWidgets(
      'ExpiredCodeScreen finds created event even when not at index 0',
      (tester) async {
        final createdTime = DateTime(2026, 10, 12, 10, 0);
        final item = Handover(
          id: 'hn_reversed_events',
          token: 'HN-REV',
          itemName: 'Audio Cable',
          category: 'Accessories',
          identifier: 'CBL-01',
          description: 'Cable',
          senderName: 'Maya',
          senderOrg: 'Northline',
          receiverName: 'Jordan',
          receiverOrg: 'SoundLab',
          receiverEmail: 'jordan@soundlab.com',
          returnExpected: false,
          createdAt: null,
          events: [
            HandoverEvent(
              id: 'ev_deadline',
              title: 'Deadline passed',
              timestamp: DateTime(2026, 10, 13, 12, 0),
              type: HandoverEventType.deadlinePassed,
            ),
            HandoverEvent(
              id: 'ev_created',
              title: 'Created',
              timestamp: createdTime,
              type: HandoverEventType.created,
            ),
          ],
          status: HandoverStatus.expired,
        );

        await tester.pumpWidget(
          createTestApp(
            const ExpiredCodeScreen(handoverId: 'hn_reversed_events'),
            handovers: [item],
          ),
        );
        await tester.pumpAndSettle();

        // Expire is created + 24 hours = 13 Oct 2026 at 10:00 AM
        expect(
          find.textContaining('Expired 13 Oct 2026 at 10:00 AM'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'ConfirmReturnScreen selects latest returned event when multiple returned events exist',
      (tester) async {
        final firstReturn = DateTime(2026, 11, 1, 10, 0);
        final secondReturn = DateTime(2026, 11, 3, 15, 30);
        final item = Handover(
          id: 'hn_multi_return',
          token: 'HN-MRET',
          itemName: 'Headphones',
          category: 'Audio',
          identifier: 'HP-01',
          description: 'Studio headphones',
          senderName: 'Maya',
          senderOrg: 'Northline',
          receiverName: 'Jordan',
          receiverOrg: 'SoundLab',
          receiverEmail: 'jordan@soundlab.com',
          returnExpected: true,
          returnedAt: null,
          events: [
            HandoverEvent(
              id: 'ev_ret_1',
              title: 'First return attempt',
              timestamp: firstReturn,
              type: HandoverEventType.returned,
            ),
            HandoverEvent(
              id: 'ev_ret_2',
              title: 'Final return confirmed',
              timestamp: secondReturn,
              type: HandoverEventType.returned,
            ),
          ],
          status: HandoverStatus.returned,
        );

        await tester.pumpWidget(
          createTestApp(
            const ConfirmReturnScreen(handoverId: 'hn_multi_return'),
            handovers: [item],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('3 Nov 2026 • 3:30 PM'), findsOneWidget);
        expect(find.text('1 Nov 2026 • 10:00 AM'), findsNothing);
      },
    );
  });

  group('Physical Return Confirmation Checkbox Behavior', () {
    testWidgets(
      'confirmation checkbox initializes to false and requires user interaction to enable submit',
      (tester) async {
        const item = Handover(
          id: 'hn_checkbox_test',
          token: 'HN-CHK',
          itemName: 'Microphone',
          category: 'Audio',
          identifier: 'MIC-99',
          description: 'Mic',
          senderName: 'Maya',
          senderOrg: 'Northline',
          receiverName: 'Jordan',
          receiverOrg: 'SoundLab',
          receiverEmail: 'jordan@soundlab.com',
          returnExpected: true,
          status: HandoverStatus.received,
        );

        await tester.pumpWidget(
          createTestApp(
            const ConfirmReturnScreen(handoverId: 'hn_checkbox_test'),
            handovers: [item],
          ),
        );
        await tester.pumpAndSettle();

        final checkIconFinder = find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.check && w.size == 16,
        );
        // Checkbox starts unchecked (does not find 16px check icon)
        expect(checkIconFinder, findsNothing);

        // Button is disabled when unchecked
        final btnBefore = tester.widget<AppButton>(
          find.widgetWithText(AppButton, 'Confirm item is back in my hands'),
        );
        expect(btnBefore.onPressed, isNull);

        // Tap checkbox to check it
        await tester.tap(
          find.text('I confirm this item has physically been returned to me.'),
        );
        await tester.pumpAndSettle();

        expect(checkIconFinder, findsOneWidget);

        final btnAfter = tester.widget<AppButton>(
          find.widgetWithText(AppButton, 'Confirm item is back in my hands'),
        );
        expect(btnAfter.onPressed, isNotNull);
      },
    );
  });

  group('CustodyStepperCard and HandoverCard Lifecycle Rules', () {
    testWidgets(
      'CustodyStepperCard does not show overdue state for pending handovers with past deadline',
      (tester) async {
        final pastDue = DateTime.now().subtract(const Duration(days: 3));
        final item = Handover(
          id: 'hn_step_pending',
          token: 'HN-STP1',
          itemName: 'Tablet',
          category: 'Electronics',
          identifier: 'TAB-5',
          description: 'Tablet',
          senderName: 'Maya',
          senderOrg: 'Northline',
          receiverName: 'Jordan',
          receiverOrg: 'SoundLab',
          receiverEmail: 'jordan@soundlab.com',
          returnExpected: true,
          returnDueAt: pastDue,
          status: HandoverStatus.pending,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: CustodyStepperCard(handover: item)),
          ),
        );
        await tester.pumpAndSettle();

        // Overdue indicator not shown
        expect(find.textContaining('OVERDUE'), findsNothing);
      },
    );

    testWidgets(
      'HandoverCard formats dynamic subtitles for multiple lifecycle statuses',
      (tester) async {
        final now = DateTime.now();
        final overdueItem = Handover(
          id: 'hn_card_od',
          token: 'HN-C-OD',
          itemName: 'Overdue Item',
          category: 'Gear',
          identifier: 'G-1',
          description: 'Test',
          senderName: 'Maya',
          senderOrg: 'Northline',
          receiverName: 'Jordan',
          receiverOrg: 'SoundLab',
          receiverEmail: 'jordan@soundlab.com',
          returnExpected: true,
          receivedAt: now.subtract(const Duration(days: 5)),
          returnDueAt: now.subtract(const Duration(days: 2)),
          status: HandoverStatus.overdue,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: HandoverCard(handover: overdueItem)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('2 days overdue'), findsOneWidget);
      },
    );
  });
}
