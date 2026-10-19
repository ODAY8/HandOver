// test/qr_receipt_dates_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:handover/features/qr/share_qr_screen.dart';
import 'package:handover/features/qr/receiver_verify_screen.dart';
import 'package:handover/features/qr/receipt_confirmed_screen.dart';
import 'package:handover/core/widgets/app_button.dart';
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
  group('ShareQrScreen Date Formatting', () {
    testWidgets(
      'renders calculated expiry date (+24h) from handover createdAt',
      (tester) async {
        final item = Handover(
          id: 'hn_share_1',
          token: 'HN-9999',
          itemName: 'Camera Lens',
          category: 'Optics',
          identifier: 'LENS-50',
          description: 'Prime lens',
          senderName: 'Maya Chen',
          senderOrg: 'Northline',
          receiverName: 'Jordan Lee',
          receiverOrg: 'Studio',
          receiverEmail: 'jordan@studio.com',
          returnExpected: true,
          createdAt: DateTime(
            2026,
            10,
            20,
            10,
            0,
          ), // Expire: 21 Oct 2026 at 10:00 AM
          status: HandoverStatus.pending,
        );

        await tester.pumpWidget(
          createTestApp(
            const ShareQrScreen(token: 'HN-9999'),
            handovers: [item],
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Code expires 21 Oct 2026 at 10:00 AM'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'renders safe fallback text when createdAt is null and no events exist',
      (tester) async {
        const item = Handover(
          id: 'hn_share_no_date',
          token: 'HN-NODATE',
          itemName: 'Drone Kit',
          category: 'Electronics',
          identifier: 'DRONE-01',
          description: 'Test',
          senderName: 'Maya',
          senderOrg: 'Northline',
          receiverName: 'Alex',
          receiverOrg: 'Lab',
          receiverEmail: 'alex@lab.com',
          returnExpected: false,
          createdAt: null,
          events: [],
          status: HandoverStatus.pending,
        );

        await tester.pumpWidget(
          createTestApp(
            const ShareQrScreen(token: 'HN-NODATE'),
            handovers: [item],
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Awaiting acknowledgment. Code expiry does not confirm receipt.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'tapping Share QR code executes share action safely without unhandled exceptions',
      (tester) async {
        final item = Handover(
          id: 'hn_share_tap',
          token: 'HN-TAP-SHARE',
          itemName: 'Field Recorder',
          category: 'Audio',
          identifier: 'REC-01',
          description: 'Recorder',
          senderName: 'Maya Chen',
          senderOrg: 'Northline',
          receiverName: 'Jordan Lee',
          receiverOrg: 'Studio',
          receiverEmail: 'jordan@studio.com',
          returnExpected: true,
          createdAt: DateTime(2026, 10, 20, 10, 0),
          status: HandoverStatus.pending,
        );

        await tester.pumpWidget(
          createTestApp(
            const ShareQrScreen(token: 'HN-TAP-SHARE'),
            handovers: [item],
          ),
        );
        await tester.pumpAndSettle();

        final shareBtn = find.widgetWithText(AppButton, 'Share QR code');
        expect(shareBtn, findsOneWidget);

        await tester.tap(shareBtn);
        await tester.pumpAndSettle();
      },
    );
  });

  group('ReceiverVerifyScreen Return Date Formatting', () {
    testWidgets('renders actual return deadline when return is expected', (
      tester,
    ) async {
      final item = Handover(
        id: 'hn_verify_1',
        token: 'HN-VERIFY',
        itemName: 'Studio Microphone',
        category: 'Audio',
        identifier: 'MIC-01',
        description: 'Condenser mic',
        senderName: 'Maya',
        senderOrg: 'Northline',
        receiverName: 'Jordan',
        receiverOrg: 'SoundLab',
        receiverEmail: 'jordan@soundlab.com',
        returnExpected: true,
        returnDueAt: DateTime(2026, 11, 5, 14, 30),
        status: HandoverStatus.pending,
      );

      await tester.pumpWidget(
        createTestApp(
          const ReceiverVerifyScreen(token: 'HN-VERIFY'),
          handovers: [item],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Return by'), findsOneWidget);
      expect(find.text('5 Nov 2026 • 2:30 PM'), findsOneWidget);
    });

    testWidgets(
      'hides return deadline row completely when returnExpected is false',
      (tester) async {
        const item = Handover(
          id: 'hn_no_return',
          token: 'HN-GIFT',
          itemName: 'Workshop Stickers',
          category: 'Supplies',
          identifier: 'STK-01',
          description: 'Permanent giveaway',
          senderName: 'Maya',
          senderOrg: 'Northline',
          receiverName: 'Jordan',
          receiverOrg: 'SoundLab',
          receiverEmail: 'jordan@soundlab.com',
          returnExpected: false,
          returnDueAt: null,
          status: HandoverStatus.pending,
        );

        await tester.pumpWidget(
          createTestApp(
            const ReceiverVerifyScreen(token: 'HN-GIFT'),
            handovers: [item],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Return by'), findsNothing);
      },
    );

    testWidgets(
      'renders safe dash fallback when returnExpected is true but returnDueAt is null',
      (tester) async {
        const item = Handover(
          id: 'hn_due_null',
          token: 'HN-NULLDUE',
          itemName: 'Tripod',
          category: 'Equipment',
          identifier: 'TRI-01',
          description: 'Tripod stand',
          senderName: 'Maya',
          senderOrg: 'Northline',
          receiverName: 'Jordan',
          receiverOrg: 'SoundLab',
          receiverEmail: 'jordan@soundlab.com',
          returnExpected: true,
          returnDueAt: null,
          status: HandoverStatus.pending,
        );

        await tester.pumpWidget(
          createTestApp(
            const ReceiverVerifyScreen(token: 'HN-NULLDUE'),
            handovers: [item],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Return by'), findsOneWidget);
        expect(find.text('—'), findsOneWidget);
      },
    );
  });

  group('ReceiptConfirmedScreen Confirmed Timestamp Formatting', () {
    testWidgets('renders actual receivedAt timestamp from handover', (
      tester,
    ) async {
      final item = Handover(
        id: 'hn_confirmed_1',
        token: 'HN-CONF1',
        itemName: '4K Monitor',
        category: 'Electronics',
        identifier: 'MON-4K',
        description: 'Display',
        senderName: 'Maya',
        senderOrg: 'Northline',
        receiverName: 'Jordan',
        receiverOrg: 'SoundLab',
        receiverEmail: 'jordan@soundlab.com',
        returnExpected: true,
        receivedAt: DateTime(2026, 10, 25, 11, 45),
        status: HandoverStatus.received,
      );

      await tester.pumpWidget(
        createTestApp(
          const ReceiptConfirmedScreen(handoverId: 'hn_confirmed_1'),
          handovers: [item],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('25 Oct 2026 • 11:45 AM'), findsOneWidget);
    });

    testWidgets(
      'renders event timestamp when receivedAt field is null but received event exists',
      (tester) async {
        final item = Handover(
          id: 'hn_confirmed_event',
          token: 'HN-CONFEV',
          itemName: 'Audio Interface',
          category: 'Audio',
          identifier: 'AUD-IF',
          description: 'Interface',
          senderName: 'Maya',
          senderOrg: 'Northline',
          receiverName: 'Jordan',
          receiverOrg: 'SoundLab',
          receiverEmail: 'jordan@soundlab.com',
          returnExpected: true,
          receivedAt: null,
          events: [
            HandoverEvent(
              id: 'ev_rec',
              title: 'Jordan confirmed receipt',
              timestamp: DateTime(2026, 10, 28, 16, 15),
              type: HandoverEventType.received,
            ),
          ],
          status: HandoverStatus.received,
        );

        await tester.pumpWidget(
          createTestApp(
            const ReceiptConfirmedScreen(handoverId: 'hn_confirmed_event'),
            handovers: [item],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Confirmed'), findsOneWidget);
        expect(find.text('28 Oct 2026 • 4:15 PM'), findsOneWidget);
      },
    );

    testWidgets(
      'renders safe dash fallback when receivedAt is null without inventing timestamp',
      (tester) async {
        const item = Handover(
          id: 'hn_confirmed_null',
          token: 'HN-CONFNULL',
          itemName: 'Tablet',
          category: 'Electronics',
          identifier: 'TAB-01',
          description: 'Drawing tablet',
          senderName: 'Maya',
          senderOrg: 'Northline',
          receiverName: 'Jordan',
          receiverOrg: 'SoundLab',
          receiverEmail: 'jordan@soundlab.com',
          returnExpected: true,
          receivedAt: null,
          events: [],
          status: HandoverStatus.received,
        );

        await tester.pumpWidget(
          createTestApp(
            const ReceiptConfirmedScreen(handoverId: 'hn_confirmed_null'),
            handovers: [item],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Confirmed'), findsOneWidget);
        expect(find.text('—'), findsOneWidget);
      },
    );

    testWidgets(
      'ReceiptConfirmedScreen selects latest received event timestamp when multiple exist',
      (tester) async {
        final earlier = DateTime(2026, 10, 20, 9, 0);
        final latest = DateTime(2026, 10, 22, 16, 30);
        final item = Handover(
          id: 'hn_multi_recv',
          token: 'HN-MREC',
          itemName: 'Microphone',
          category: 'Audio',
          identifier: 'MIC-02',
          description: 'Mic',
          senderName: 'Maya',
          senderOrg: 'Northline',
          receiverName: 'Jordan',
          receiverOrg: 'SoundLab',
          receiverEmail: 'jordan@soundlab.com',
          returnExpected: true,
          receivedAt: null,
          events: [
            HandoverEvent(
              id: 'ev_rec_early',
              title: 'Initial receipt scan',
              timestamp: earlier,
              type: HandoverEventType.received,
            ),
            HandoverEvent(
              id: 'ev_rec_late',
              title: 'Final receipt scan',
              timestamp: latest,
              type: HandoverEventType.received,
            ),
          ],
          status: HandoverStatus.received,
        );

        await tester.pumpWidget(
          createTestApp(
            const ReceiptConfirmedScreen(handoverId: 'hn_multi_recv'),
            handovers: [item],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('22 Oct 2026 • 4:30 PM'), findsOneWidget);
        expect(find.text('20 Oct 2026 • 9:00 AM'), findsNothing);
      },
    );
  });

  group('QR and Receipt Invalid Token Fallback Prevention', () {
    const existingItem = Handover(
      id: 'hn_qr_first_existing',
      token: 'HN-FIRST-QR',
      itemName: 'Existing QR Item',
      category: 'Electronics',
      identifier: 'QR-01',
      description: 'First',
      senderName: 'Maya',
      senderOrg: 'Northline',
      receiverName: 'Jordan',
      receiverOrg: 'SoundLab',
      receiverEmail: 'jordan@soundlab.com',
      returnExpected: true,
      status: HandoverStatus.pending,
    );

    testWidgets(
      'ShareQrScreen shows record not found on invalid token and does not fallback to first',
      (tester) async {
        await tester.pumpWidget(
          createTestApp(
            const ShareQrScreen(token: 'NON_EXISTENT_TOKEN'),
            handovers: [existingItem],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Handover record not found'), findsOneWidget);
        expect(find.text('Existing QR Item'), findsNothing);
      },
    );

    testWidgets(
      'ReceiverVerifyScreen shows record not found on invalid token and does not fallback to first',
      (tester) async {
        await tester.pumpWidget(
          createTestApp(
            const ReceiverVerifyScreen(token: 'NON_EXISTENT_TOKEN'),
            handovers: [existingItem],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Handover record not found'), findsOneWidget);
        expect(find.text('Existing QR Item'), findsNothing);
      },
    );

    testWidgets(
      'ReceiptConfirmedScreen shows record not found on invalid id and does not fallback to first',
      (tester) async {
        await tester.pumpWidget(
          createTestApp(
            const ReceiptConfirmedScreen(handoverId: 'non_existent_id'),
            handovers: [existingItem],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Handover record not found'), findsOneWidget);
        expect(find.text('Existing QR Item'), findsNothing);
      },
    );
  });

  group('ReceiverVerifyScreen Explicit Confirmation and Decline Flow', () {
    const testItem = Handover(
      id: 'hn_verify_action_item',
      token: 'HN-ACT-01',
      itemName: 'Studio Monitors',
      category: 'Audio',
      identifier: 'SM-01',
      description: 'Speakers',
      senderName: 'Maya',
      senderOrg: 'Northline',
      receiverName: 'Jordan',
      receiverOrg: 'SoundLab',
      receiverEmail: 'jordan@soundlab.com',
      returnExpected: true,
      status: HandoverStatus.pending,
    );

    testWidgets(
      'checkbox starts unchecked and Confirm receipt button is disabled until tapped',
      (tester) async {
        await tester.pumpWidget(
          createTestApp(
            const ReceiverVerifyScreen(token: 'HN-ACT-01'),
            handovers: [testItem],
          ),
        );
        await tester.pumpAndSettle();

        final checkIconFinder = find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.check && w.size == 16,
        );
        // Checkbox is unchecked (no 16px check icon)
        expect(checkIconFinder, findsNothing);

        // Button is disabled when unchecked
        final btnBefore = tester.widget<AppButton>(
          find.widgetWithText(AppButton, 'Confirm receipt'),
        );
        expect(btnBefore.onPressed, isNull);

        // Tap checkbox card
        await tester.tap(find.text('I received this item.'));
        await tester.pumpAndSettle();

        // Now checked
        expect(checkIconFinder, findsOneWidget);

        final btnAfter = tester.widget<AppButton>(
          find.widgetWithText(AppButton, 'Confirm receipt'),
        );
        expect(btnAfter.onPressed, isNotNull);
      },
    );

    testWidgets('tapping Decline handover opens confirmation dialog', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          const ReceiverVerifyScreen(token: 'HN-ACT-01'),
          handovers: [testItem],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Decline handover'));
      await tester.pumpAndSettle();

      expect(find.text('Decline handover?'), findsOneWidget);
      expect(find.text('Keep reviewing'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
    });
  });
}
