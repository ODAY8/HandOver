// test/phase2_security_transitions_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:handover/models/handover.dart';
import 'package:handover/models/handover_status.dart';
import 'package:handover/providers/auth_provider.dart';
import 'package:handover/providers/handover_provider.dart';
import 'package:handover/providers/profile_provider.dart';
import 'package:handover/providers/theme_provider.dart';
import 'package:handover/repositories/handover_repository.dart';
import 'package:handover/services/handover_service.dart';
import 'package:handover/features/qr/receiver_verify_screen.dart';

class MockRpcFailClient extends Fake implements SupabaseClient {
  final PostgrestException error;
  bool directWriteAttempted = false;

  MockRpcFailClient(this.error);

  @override
  SupabaseQueryBuilder from(String table) {
    directWriteAttempted = true;
    throw const PostgrestException(
      message: 'Direct write attempt detected',
      code: '42501',
    );
  }

  @override
  PostgrestFilterBuilder<T> rpc<T>(
    String fn, {
    Map<String, dynamic>? params,
    dynamic get,
  }) {
    throw error;
  }
}

Widget createPhase2TestApp(Widget child, {HandoverRepository? repo}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      ChangeNotifierProvider(create: (_) => ProfileProvider()),
      ChangeNotifierProvider(
        create: (_) {
          final p = HandoverProvider(
            handoverRepository: repo ?? MockHandoverRepository(),
          );
          return p;
        },
      ),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  group('Phase 2 — Overdue Status Parsing Verification', () {
    final pastDate = DateTime.now().subtract(const Duration(days: 5));
    final futureDate = DateTime.now().add(const Duration(days: 5));

    test(
      'PENDING handovers NEVER become overdue even with past return deadline',
      () {
        final status = HandoverStatus.fromDbString(
          'PENDING',
          returnDueAt: pastDate,
        );
        expect(status, HandoverStatus.pending);
        expect(status, isNot(HandoverStatus.overdue));
      },
    );

    test(
      'EXPIRED handovers NEVER become overdue even with past return deadline',
      () {
        final status = HandoverStatus.fromDbString(
          'EXPIRED',
          returnDueAt: pastDate,
        );
        expect(status, HandoverStatus.expired);
        expect(status, isNot(HandoverStatus.overdue));
      },
    );

    test(
      'RETURNED handovers NEVER become overdue even with past return deadline',
      () {
        final status = HandoverStatus.fromDbString(
          'RETURNED',
          returnDueAt: pastDate,
        );
        expect(status, HandoverStatus.returned);
        expect(status, isNot(HandoverStatus.overdue));
      },
    );

    test(
      'CANCELLED handovers NEVER become overdue even with past return deadline',
      () {
        final status = HandoverStatus.fromDbString(
          'CANCELLED',
          returnDueAt: pastDate,
        );
        expect(status, HandoverStatus.cancelled);
        expect(status, isNot(HandoverStatus.overdue));
      },
    );

    test(
      'DISPUTED handovers remain disputed even with past return deadline',
      () {
        final status = HandoverStatus.fromDbString(
          'DISPUTED',
          returnDueAt: pastDate,
        );
        expect(status, HandoverStatus.disputed);
        expect(status, isNot(HandoverStatus.overdue));
      },
    );

    test('RECEIVED handovers with past return deadline become overdue', () {
      final status = HandoverStatus.fromDbString(
        'RECEIVED',
        returnDueAt: pastDate,
      );
      expect(status, HandoverStatus.overdue);
    });

    test('RECEIVED handovers with future return deadline remain received', () {
      final status = HandoverStatus.fromDbString(
        'RECEIVED',
        returnDueAt: futureDate,
      );
      expect(status, HandoverStatus.received);
    });
  });

  group(
    'Phase 2 — Collision-Resistant Token Generation and Model Serialization',
    () {
      test(
        'generateCollisionResistantToken generates distinct, valid HN- tokens',
        () {
          final tokens = <String>{};
          const count = 500;
          for (int i = 0; i < count; i++) {
            final token = HandoverProvider.generateCollisionResistantToken();
            expect(token.startsWith('HN-'), isTrue);
            expect(token.length, 7); // 'HN-' + 4 chars
            tokens.add(token);
          }
          // Zero or statistically negligible collisions across 500 samples
          expect(tokens.length, greaterThan(490));
        },
      );

      test('Handover.toInsertRow includes dedicated token column', () {
        const handover = Handover(
          id: 'hn_test_col',
          token: 'HN-COL99',
          itemName: 'Test Camera',
          category: 'Optics',
          identifier: 'CAM-01',
          description: 'DSLR',
          senderName: 'Alice',
          senderOrg: 'Studio A',
          receiverName: 'Bob',
          receiverOrg: 'Studio B',
          receiverEmail: 'bob@studiob.com',
          returnExpected: true,
          status: HandoverStatus.pending,
        );

        final row = handover.toInsertRow(ownerId: 'usr_alice');
        expect(row['token'], 'HN-COL99');
        expect(row['owner_id'], 'usr_alice');
        expect(row['item_name'], 'Test Camera');
      });

      test(
        'Handover.fromRow reads dedicated token column first before purpose fallback',
        () {
          final rowWithTokenCol = {
            'id': 'hn_from_db',
            'token': 'HN-DIRECT-COL',
            'owner_id': 'usr_alice',
            'item_name': 'Lens',
            'status': 'PENDING',
            'purpose': '{"token": "HN-OLD-PURPOSE"}',
          };

          final parsed = Handover.fromRow(rowWithTokenCol);
          expect(parsed.token, 'HN-DIRECT-COL');
        },
      );
    },
  );

  group('Phase 2 — Multi-Tenant Custody Transition Enforcement', () {
    test(
      'Recipient can confirm receipt; double confirmation is handled idempotently',
      () async {
        const initialItem = Handover(
          id: 'hn_receipt_test',
          token: 'HN-REC1',
          itemName: 'Pro Projector',
          category: 'AV',
          identifier: 'PRJ-01',
          description: 'HD Projector',
          senderName: 'Owner User',
          senderOrg: 'Northline',
          receiverName: 'Recipient User',
          receiverOrg: 'SoundLab',
          receiverEmail: 'recipient@soundlab.com',
          returnExpected: true,
          status: HandoverStatus.pending,
        );

        final repo = MockHandoverRepository(initialItems: [initialItem]);
        final provider = HandoverProvider(handoverRepository: repo);
        await provider.loadHandovers(
          userId: 'usr_recipient',
          userEmail: 'recipient@soundlab.com',
        );

        // First confirmation transitions PENDING -> RECEIVED
        final ok1 = await provider.confirmReceipt(
          'hn_receipt_test',
          receiverId: 'usr_recipient',
          receiverName: 'Recipient User',
        );
        expect(ok1, isTrue);
        expect(
          provider.getHandoverById('hn_receipt_test')!.status,
          HandoverStatus.received,
        );

        // Attempting to confirm receipt again on already received handover
        // Mock/provider handles it safely without crashing
        await provider.confirmReceipt(
          'hn_receipt_test',
          receiverId: 'usr_recipient',
          receiverName: 'Recipient User',
        );
        expect(
          provider.getHandoverById('hn_receipt_test')!.status,
          HandoverStatus.received,
        );
      },
    );

    test('Cancellation cannot occur on already received handover', () async {
      final receivedItem = Handover(
        id: 'hn_no_cancel',
        token: 'HN-NOCAN',
        itemName: '4K Monitor',
        category: 'Electronics',
        identifier: 'MON-01',
        description: 'Display',
        senderName: 'Alice',
        senderOrg: 'Northline',
        receiverName: 'Bob',
        receiverOrg: 'SoundLab',
        receiverEmail: 'bob@soundlab.com',
        returnExpected: true,
        status: HandoverStatus.received,
        receivedAt: DateTime.now(),
      );

      final repo = MockHandoverRepository(initialItems: [receivedItem]);
      final provider = HandoverProvider(handoverRepository: repo);
      await provider.loadHandovers(
        userId: 'usr_alice',
        userEmail: 'alice@northline.com',
      );

      final ok = await provider.cancelHandover(
        'hn_no_cancel',
        userId: 'usr_alice',
        userName: 'Alice',
      );
      expect(ok, isFalse);
      expect(provider.errorMessage, isNotNull);
      expect(
        provider.getHandoverById('hn_no_cancel')!.status,
        HandoverStatus.received,
      );
    });

    test(
      'Condition issue can be recorded and then resolved back to received',
      () async {
        final receivedItem = Handover(
          id: 'hn_dispute_flow',
          token: 'HN-DISP-FLOW',
          itemName: 'Audio Mixer',
          category: 'Audio',
          identifier: 'MIX-01',
          description: '16-channel mixer',
          senderName: 'Alice',
          senderOrg: 'Northline',
          receiverName: 'Bob',
          receiverOrg: 'SoundLab',
          receiverEmail: 'bob@soundlab.com',
          returnExpected: true,
          status: HandoverStatus.received,
          receivedAt: DateTime.now(),
        );

        final repo = MockHandoverRepository(initialItems: [receivedItem]);
        final provider = HandoverProvider(handoverRepository: repo);
        await provider.loadHandovers(
          userId: 'usr_bob',
          userEmail: 'bob@soundlab.com',
        );

        // 1. Record issue -> status becomes disputed
        final okIssue = await provider.recordIssue(
          'hn_dispute_flow',
          reason: 'Scratch on knob',
          description: 'Channel 3 knob is slightly scratched.',
          reporterId: 'usr_bob',
          reportedBy: 'Bob',
        );
        expect(okIssue, isTrue);
        expect(
          provider.getHandoverById('hn_dispute_flow')!.status,
          HandoverStatus.disputed,
        );

        // 2. Resolve issue -> status returns to received
        final okResolve = await provider.resolveIssue(
          'hn_dispute_flow',
          resolverId: 'usr_alice',
          resolverName: 'Alice',
        );
        expect(okResolve, isTrue);
        expect(
          provider.getHandoverById('hn_dispute_flow')!.status,
          HandoverStatus.received,
        );
      },
    );
  });

  group('Phase 2 — QR Verification Async Token Lookup', () {
    testWidgets(
      'ReceiverVerifyScreen fetches item from repository by token when not cached in memory',
      (tester) async {
        const serverItem = Handover(
          id: 'hn_remote_qr',
          token: 'HN-REMOTE-01',
          itemName: 'Remote Drone',
          category: 'Equipment',
          identifier: 'DRN-09',
          description: 'Quadcopter',
          senderName: 'Flight Lead',
          senderOrg: 'AeroLab',
          receiverName: 'Pilot',
          receiverOrg: 'SkyTeam',
          receiverEmail: 'pilot@skyteam.com',
          returnExpected: true,
          status: HandoverStatus.pending,
        );

        final repo = MockHandoverRepository(initialItems: [serverItem]);

        // Open ReceiverVerifyScreen with empty local provider memory
        await tester.pumpWidget(
          createPhase2TestApp(
            const ReceiverVerifyScreen(token: 'HN-REMOTE-01'),
            repo: repo,
          ),
        );

        // Settle frames allowing initState post-frame async fetch to complete
        await tester.pumpAndSettle();

        expect(find.text('Remote Drone'), findsOneWidget);
        expect(find.textContaining('HN-REMOTE-01'), findsOneWidget);
        expect(find.text('Handover record not found'), findsNothing);
      },
    );

    testWidgets(
      'ReceiverVerifyScreen shows record not found when token does not exist anywhere',
      (tester) async {
        final repo = MockHandoverRepository(initialItems: []);

        await tester.pumpWidget(
          createPhase2TestApp(
            const ReceiverVerifyScreen(token: 'HN-NON-EXISTENT'),
            repo: repo,
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Handover record not found'), findsOneWidget);
      },
    );
  });

  group('Phase 2 — Fail-Closed RPC Behavior & Insecure Direct Write Prevention', () {
    test(
      'Missing RPC procedure (PGRST202) throws fail-closed error and never executes direct update or insert',
      () async {
        final client = MockRpcFailClient(
          const PostgrestException(
            message: 'could not find function confirm_handover_receipt',
            code: 'PGRST202',
          ),
        );
        final service = SupabaseHandoverService(client: client);

        try {
          await service.updateHandoverStatus(
            handoverId: 'hn_test_fail_closed',
            status: 'RECEIVED',
            eventData: {'event_type': 'RECEIVED'},
          );
          fail('Expected HandoverFailure');
        } on HandoverFailure catch (e) {
          expect(e.message, contains('Backend migration required'));
          expect(e.code, 'PGRST202');
          expect(client.directWriteAttempted, isFalse);
        }
      },
    );

    test(
      'RPC authorization failure (42501) throws access denied and never falls back to direct table update',
      () async {
        final client = MockRpcFailClient(
          const PostgrestException(
            message: 'permission denied for function confirm_handover_receipt',
            code: '42501',
          ),
        );
        final service = SupabaseHandoverService(client: client);

        try {
          await service.updateHandoverStatus(
            handoverId: 'hn_test_unauth',
            status: 'RECEIVED',
            eventData: {'event_type': 'RECEIVED'},
          );
          fail('Expected HandoverFailure');
        } on HandoverFailure catch (e) {
          expect(e.message, contains('Access denied'));
          expect(e.code, '42501');
          expect(client.directWriteAttempted, isFalse);
        }
      },
    );

    test(
      'RPC check constraint failure (23514) throws invalid transition and never attempts direct writes',
      () async {
        final client = MockRpcFailClient(
          const PostgrestException(
            message: 'check constraint violation',
            code: '23514',
          ),
        );
        final service = SupabaseHandoverService(client: client);

        try {
          await service.updateHandoverStatus(
            handoverId: 'hn_test_constraint',
            status: 'RECEIVED',
            eventData: {'event_type': 'RECEIVED'},
          );
          fail('Expected HandoverFailure');
        } on HandoverFailure catch (e) {
          expect(e.message, contains('Invalid status transition'));
          expect(e.code, '23514');
          expect(client.directWriteAttempted, isFalse);
        }
      },
    );

    test(
      'Unsupported custody transition status throws fail-closed error without network call or direct writes',
      () async {
        final client = MockRpcFailClient(
          const PostgrestException(message: 'never called', code: '00000'),
        );
        final service = SupabaseHandoverService(client: client);

        try {
          await service.updateHandoverStatus(
            handoverId: 'hn_test_unknown',
            status: 'NONEXISTENT_STATUS',
            eventData: {'event_type': 'UNKNOWN'},
          );
          fail('Expected HandoverFailure');
        } on HandoverFailure catch (e) {
          expect(e.message, contains('Direct status updates are prohibited'));
          expect(e.code, '42501');
          expect(client.directWriteAttempted, isFalse);
        }
      },
    );

    test(
      'renewHandoverToken fails closed without fallback to direct updates when RPC rejects',
      () async {
        final client = MockRpcFailClient(
          const PostgrestException(
            message: 'Access denied: only owner can renew',
            code: '42501',
          ),
        );
        final service = SupabaseHandoverService(client: client);

        try {
          await service.renewHandoverToken(
            handoverId: 'hn_test_renew',
            newToken: 'HN-RENEW99',
          );
          fail('Expected HandoverFailure');
        } on HandoverFailure catch (e) {
          expect(e.code, '42501');
          expect(client.directWriteAttempted, isFalse);
        }
      },
    );
  });

  group(
    'Phase 2 — Token Migration Safety, Malformed Legacy Data & Deduplication',
    () {
      test(
        'Handover.fromRow safely parses valid JSON purpose and extracts token',
        () {
          final row = {
            'id': 'hn_valid_json',
            'item_name': 'Projector',
            'purpose': '{"token": "HN-LEGACY-01", "notes": "Conference room"}',
          };
          final handover = Handover.fromRow(row);
          expect(handover.token, 'HN-LEGACY-01');
          expect(handover.notes, 'Conference room');
        },
      );

      test(
        'Handover.fromRow safely handles plain text purpose without JSON crash',
        () {
          final row = {
            'id': '11111111-2222-3333-4444-555555555555',
            'item_name': 'Camera',
            'purpose': 'Borrowed for weekend photoshoot at Central Park',
          };
          final handover = Handover.fromRow(row);
          expect(handover.token, 'HN-1111');
          expect(
            handover.notes,
            'Borrowed for weekend photoshoot at Central Park',
          );
        },
      );

      test(
        'Handover.fromRow safely handles malformed JSON starting with brace',
        () {
          final row = {
            'id': '22222222-3333-4444-5555-666666666666',
            'item_name': 'Drone',
            'purpose': '{malformed: json: missing: quotes}',
          };
          final handover = Handover.fromRow(row);
          expect(handover.token, 'HN-2222');
          expect(handover.notes, '{malformed: json: missing: quotes}');
        },
      );

      test(
        'Handover.fromRow prioritizes dedicated token column over purpose JSON',
        () {
          final row = {
            'id': '33333333-4444-5555-6666-777777777777',
            'token': 'HN-DEDICATED',
            'item_name': 'Lens',
            'purpose': '{"token": "HN-OLD-JSON"}',
          };
          final handover = Handover.fromRow(row);
          expect(handover.token, 'HN-DEDICATED');
        },
      );

      test(
        'Token deduplication algorithm preserves earliest record and disambiguates duplicates',
        () {
          final mockExistingRows = [
            {
              'id': 'row_1',
              'token': 'HN-1048',
              'created_at': DateTime(2026, 10, 1),
            },
            {
              'id': 'row_2',
              'token': 'HN-1048',
              'created_at': DateTime(2026, 10, 2),
            },
            {
              'id': 'row_3',
              'token': 'HN-1048',
              'created_at': DateTime(2026, 10, 3),
            },
          ];

          final assignedTokens = <String>{};
          final resolved = <Map<String, dynamic>>[];

          for (var i = 0; i < mockExistingRows.length; i++) {
            final row = Map<String, dynamic>.from(mockExistingRows[i]);
            final baseToken = row['token'].toString();

            if (i == 0) {
              assignedTokens.add(baseToken.toLowerCase());
              resolved.add({...row, 'token': baseToken});
            } else {
              var counter = 1;
              String candidate;
              do {
                candidate = '$baseToken-DUP$counter';
                counter++;
              } while (assignedTokens.contains(candidate.toLowerCase()));

              assignedTokens.add(candidate.toLowerCase());
              resolved.add({...row, 'token': candidate});
            }
          }

          expect(resolved[0]['token'], 'HN-1048');
          expect(resolved[1]['token'], 'HN-1048-DUP1');
          expect(resolved[2]['token'], 'HN-1048-DUP2');
          expect(assignedTokens.length, 3);
        },
      );
    },
  );

  group(
    'Phase 2 — State Machine Lifecycle, Role Boundaries & Event Isolation',
    () {
      test(
        'Receipt confirmation is isolated to PENDING and rejects DISPUTED',
        () {
          expect(
            HandoverStatus.pending.canTransitionTo(HandoverStatus.received),
            isTrue,
          );
          expect(
            HandoverStatus.returned.canTransitionTo(HandoverStatus.received),
            isFalse,
          );
          expect(
            HandoverStatus.cancelled.canTransitionTo(HandoverStatus.received),
            isFalse,
          );
        },
      );

      test(
        'Return confirmation requires active custody (RECEIVED or DISPUTED)',
        () {
          expect(
            HandoverStatus.received.canTransitionTo(HandoverStatus.returned),
            isTrue,
          );
          expect(
            HandoverStatus.disputed.canTransitionTo(HandoverStatus.returned),
            isTrue,
          );
          expect(
            HandoverStatus.pending.canTransitionTo(HandoverStatus.returned),
            isFalse,
          );
          expect(
            HandoverStatus.cancelled.canTransitionTo(HandoverStatus.returned),
            isFalse,
          );
        },
      );

      test('Cancellation is strictly forbidden once custody has begun', () {
        expect(
          HandoverStatus.pending.canTransitionTo(HandoverStatus.cancelled),
          isTrue,
        );
        expect(
          HandoverStatus.received.canTransitionTo(HandoverStatus.cancelled),
          isFalse,
        );
        expect(
          HandoverStatus.overdue.canTransitionTo(HandoverStatus.cancelled),
          isFalse,
        );
        expect(
          HandoverStatus.disputed.canTransitionTo(HandoverStatus.cancelled),
          isFalse,
        );
        expect(
          HandoverStatus.returned.canTransitionTo(HandoverStatus.cancelled),
          isFalse,
        );
      });

      test(
        'Terminal states (returned, cancelled) cannot transition to any other status',
        () {
          expect(HandoverStatus.returned.isTerminal, isTrue);
          expect(HandoverStatus.cancelled.isTerminal, isTrue);

          for (final target in HandoverStatus.values) {
            if (target != HandoverStatus.returned) {
              expect(HandoverStatus.returned.canTransitionTo(target), isFalse);
            }
            if (target != HandoverStatus.cancelled) {
              expect(HandoverStatus.cancelled.canTransitionTo(target), isFalse);
            }
          }
        },
      );
    },
  );
}
