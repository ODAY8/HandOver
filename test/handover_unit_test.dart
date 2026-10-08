// test/handover_unit_test.dart

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:handover/models/handover.dart';
import 'package:handover/models/handover_event.dart';
import 'package:handover/models/handover_status.dart';
import 'package:handover/repositories/handover_repository.dart';
import 'package:handover/providers/handover_provider.dart';
import 'package:handover/services/handover_service.dart';

void main() {
  group('Handover and HandoverStatus model tests', () {
    test('HandoverStatus toDbString and fromDbString mapping', () {
      expect(HandoverStatus.pending.toDbString(), 'PENDING');
      expect(HandoverStatus.received.toDbString(), 'RECEIVED');
      expect(HandoverStatus.returned.toDbString(), 'RETURNED');
      expect(HandoverStatus.disputed.toDbString(), 'DISPUTED');
      expect(HandoverStatus.cancelled.toDbString(), 'CANCELLED');
      expect(HandoverStatus.expired.toDbString(), 'EXPIRED');

      expect(HandoverStatus.fromDbString('PENDING'), HandoverStatus.pending);
      expect(HandoverStatus.fromDbString('RECEIVED'), HandoverStatus.received);
      expect(HandoverStatus.fromDbString('RETURNED'), HandoverStatus.returned);
      expect(HandoverStatus.fromDbString('DISPUTED'), HandoverStatus.disputed);
      expect(HandoverStatus.fromDbString('CANCELLED'), HandoverStatus.cancelled);
      expect(HandoverStatus.fromDbString('EXPIRED'), HandoverStatus.expired);
      expect(HandoverStatus.fromDbString('UNKNOWN'), HandoverStatus.pending);
    });

    test('HandoverStatus detects overdue based on return deadline', () {
      final pastDate = DateTime.now().subtract(const Duration(days: 2));
      final futureDate = DateTime.now().add(const Duration(days: 2));

      // Active status with past deadline is overdue
      expect(
        HandoverStatus.fromDbString('RECEIVED', returnDueAt: pastDate),
        HandoverStatus.overdue,
      );

      // Active status with future deadline remains received
      expect(
        HandoverStatus.fromDbString('RECEIVED', returnDueAt: futureDate),
        HandoverStatus.received,
      );

      // Returned item even with past deadline is returned, not overdue
      expect(
        HandoverStatus.fromDbString('RETURNED', returnDueAt: pastDate),
        HandoverStatus.returned,
      );
    });

    test('HandoverStatus transition rules prevent invalid status changes', () {
      // 1. Pending transitions
      expect(HandoverStatus.pending.canTransitionTo(HandoverStatus.received), isTrue);
      expect(HandoverStatus.pending.canTransitionTo(HandoverStatus.cancelled), isTrue);
      expect(HandoverStatus.pending.canTransitionTo(HandoverStatus.expired), isTrue);
      // Returning before receipt is strictly prohibited
      expect(HandoverStatus.pending.canTransitionTo(HandoverStatus.returned), isFalse);

      // 2. Received transitions
      expect(HandoverStatus.received.canTransitionTo(HandoverStatus.returned), isTrue);
      expect(HandoverStatus.received.canTransitionTo(HandoverStatus.disputed), isTrue);
      expect(HandoverStatus.received.canTransitionTo(HandoverStatus.expired), isTrue);
      expect(HandoverStatus.received.canTransitionTo(HandoverStatus.pending), isFalse);

      // 3. Disputed transitions
      expect(HandoverStatus.disputed.canTransitionTo(HandoverStatus.received), isTrue);
      expect(HandoverStatus.disputed.canTransitionTo(HandoverStatus.returned), isTrue);
      expect(HandoverStatus.disputed.canTransitionTo(HandoverStatus.cancelled), isFalse);

      // 4. Expired transitions
      expect(HandoverStatus.expired.canTransitionTo(HandoverStatus.pending), isTrue);
      expect(HandoverStatus.expired.canTransitionTo(HandoverStatus.returned), isFalse);

      // 5. Terminal states cannot transition
      expect(HandoverStatus.returned.isTerminal, isTrue);
      expect(HandoverStatus.returned.canTransitionTo(HandoverStatus.received), isFalse);
      expect(HandoverStatus.cancelled.isTerminal, isTrue);
      expect(HandoverStatus.cancelled.canTransitionTo(HandoverStatus.pending), isFalse);
    });

    test('Handover.fromRow parses database columns and purpose JSON correctly', () {
      final row = {
        'id': '784a1bc9-5ad9-47da-ac39-a519578ef8f9',
        'owner_id': '0927b9aa-3b33-44e9-870a-523890ad968c',
        'item_name': 'MacBook Pro 14"',
        'item_type': 'Electronics',
        'description': 'Space Gray with charger',
        'recipient_name': 'Test Receiver',
        'recipient_email': 'receiver@example.com',
        'recipient_phone': '+15551234567',
        'status': 'RECEIVED',
        'created_at': '2026-10-14T09:00:00Z',
        'expected_return_at': '2026-10-20T17:00:00Z',
        'received_at': '2026-10-14T10:00:00Z',
        'purpose': jsonEncode({
          'token': 'HN-1048',
          'identifier': 'NL-MBP-014',
          'notes': 'Studio gear intake',
          'sender_name': 'Maya Chen',
          'sender_org': 'Northline Studio',
          'receiver_org': 'Sound Lab',
        }),
        'handover_events': [
          {
            'id': 'ev-1',
            'event_type': 'CREATED',
            'created_at': '2026-10-14T09:00:00Z',
            'performed_by': '0927b9aa-3b33-44e9-870a-523890ad968c',
            'metadata': {
              'title': 'Record created by Maya Chen',
              'performer_name': 'Maya Chen',
            },
          },
          {
            'id': 'ev-2',
            'event_type': 'RECEIVED',
            'created_at': '2026-10-14T10:00:00Z',
            'performed_by': '283765c4-2ddc-4a37-afae-bd6521ce5d7f',
            'metadata': {
              'title': 'Test Receiver confirmed physical receipt',
              'performer_name': 'Test Receiver',
            },
          },
        ],
      };

      final handover = Handover.fromRow(
        row,
        currentUserId: '0927b9aa-3b33-44e9-870a-523890ad968c',
      );

      expect(handover.id, '784a1bc9-5ad9-47da-ac39-a519578ef8f9');
      expect(handover.ownerId, '0927b9aa-3b33-44e9-870a-523890ad968c');
      expect(handover.token, 'HN-1048');
      expect(handover.itemName, 'MacBook Pro 14"');
      expect(handover.category, 'Electronics');
      expect(handover.identifier, 'NL-MBP-014');
      expect(handover.status, HandoverStatus.received);
      expect(handover.receiverName, 'Test Receiver');
      expect(handover.receiverEmail, 'receiver@example.com');
      expect(handover.notes, 'Studio gear intake');
      expect(handover.events.length, 2);
      expect(handover.events.first.type, HandoverEventType.created);
      expect(handover.events.last.type, HandoverEventType.received);
    });

    test('Handover.toInsertRow serializes fields and metadata for database insert', () {
      final handover = Handover(
        id: 'temp_id',
        token: 'HN-1048',
        itemName: 'Dell Monitor',
        category: 'Electronics',
        identifier: 'NL-MON-01',
        description: '4K 27-inch display',
        senderName: 'Maya Chen',
        senderOrg: 'Northline Studio',
        receiverName: 'Jordan Lee',
        receiverOrg: 'Design Co',
        receiverEmail: 'jordan@design.co',
        receiverPhone: '+1234567890',
        returnExpected: true,
        returnDueAt: DateTime.utc(2026, 10, 25, 12, 0),
        status: HandoverStatus.pending,
        notes: 'With HDMI cable',
      );

      final insertRow = handover.toInsertRow(ownerId: 'owner_uuid_123');

      expect(insertRow['owner_id'], 'owner_uuid_123');
      expect(insertRow['item_name'], 'Dell Monitor');
      expect(insertRow['item_type'], 'Electronics');
      expect(insertRow['recipient_email'], 'jordan@design.co');
      expect(insertRow['status'], 'PENDING');
      expect(insertRow['expected_return_at'], isNotNull);

      final meta = jsonDecode(insertRow['purpose'] as String) as Map<String, dynamic>;
      expect(meta['token'], 'HN-1048');
      expect(meta['identifier'], 'NL-MON-01');
      expect(meta['notes'], 'With HDMI cable');
      expect(meta['sender_name'], 'Maya Chen');
    });

    test('HandoverEvent model parsing and insert generation', () {
      final row = {
        'id': 'ev_test_1',
        'event_type': 'ISSUE_RECORDED',
        'created_at': '2026-10-15T12:00:00Z',
        'performed_by': 'user_abc',
        'metadata': {
          'title': 'Maya Chen recorded an issue',
          'performer_name': 'Maya Chen',
          'description': 'Lid scratch detected',
        },
      };

      final event = HandoverEvent.fromRow(row);
      expect(event.id, 'ev_test_1');
      expect(event.type, HandoverEventType.issueRecorded);
      expect(event.performedBy, 'Maya Chen');
      expect(event.description, 'Lid scratch detected');

      final insertMap = event.toInsertRow(
        handoverId: 'handover_123',
        userId: 'user_abc',
      );
      expect(insertMap['handover_id'], 'handover_123');
      expect(insertMap['event_type'], 'ISSUE_RECORDED');
      expect(insertMap['performed_by'], 'user_abc');
    });
  });

  group('MockHandoverRepository CRUD & Lifecycle tests', () {
    late MockHandoverRepository repo;

    setUp(() {
      repo = MockHandoverRepository(initialItems: []);
    });

    test('createHandover adds record and generates initial CREATED event', () async {
      const newHandover = Handover(
        id: 'hn_new_1',
        token: 'HN-1048',
        itemName: 'Camera Kit',
        category: 'Equipment',
        identifier: 'CAM-01',
        description: 'Sony A7IV',
        senderName: 'Maya Chen',
        senderOrg: 'Northline Studio',
        receiverName: 'Sam Patel',
        receiverOrg: 'Photo Co',
        receiverEmail: 'sam@photo.co',
        returnExpected: true,
        status: HandoverStatus.pending,
      );

      final created = await repo.createHandover(
        handover: newHandover,
        ownerId: 'owner_user_1',
        performerName: 'Maya Chen',
      );

      expect(created.ownerId, 'owner_user_1');
      expect(created.events.length, 1);
      expect(created.events.first.type, HandoverEventType.created);
      expect(created.events.first.performedBy, 'Maya Chen');

      final fetched = await repo.fetchHandovers(
        currentUserId: 'owner_user_1',
        currentUserEmail: 'maya@northline.studio',
      );
      expect(fetched.length, 1);
      expect(fetched.first.id, 'hn_new_1');
    });

    test('permitted status transitions: pending -> received -> disputed -> resolved -> returned', () async {
      const item = Handover(
        id: 'hn_lifecycle_1',
        token: 'HN-1048',
        itemName: 'Tablet',
        category: 'Electronics',
        identifier: 'TAB-01',
        description: 'iPad Pro',
        senderName: 'Maya Chen',
        senderOrg: 'Studio',
        receiverName: 'Alex',
        receiverOrg: 'Lab',
        receiverEmail: 'alex@lab.io',
        returnExpected: true,
        status: HandoverStatus.pending,
      );

      await repo.createHandover(handover: item, ownerId: 'user_maya', performerName: 'Maya Chen');

      // 1. Confirm receipt: pending -> received
      final received = await repo.updateStatus(
        handoverId: 'hn_lifecycle_1',
        currentStatus: HandoverStatus.pending,
        newStatus: HandoverStatus.received,
        performerId: 'user_alex',
        performerName: 'Alex',
      );
      expect(received.status, HandoverStatus.received);
      expect(received.events.last.type, HandoverEventType.received);

      // 2. Record issue: received -> disputed
      final disputed = await repo.updateStatus(
        handoverId: 'hn_lifecycle_1',
        currentStatus: HandoverStatus.received,
        newStatus: HandoverStatus.disputed,
        performerId: 'user_maya',
        performerName: 'Maya Chen',
        reason: 'Cosmetic scratch',
      );
      expect(disputed.status, HandoverStatus.disputed);
      expect(disputed.events.last.type, HandoverEventType.issueRecorded);

      // 3. Resolve issue: disputed -> received
      final resolved = await repo.updateStatus(
        handoverId: 'hn_lifecycle_1',
        currentStatus: HandoverStatus.disputed,
        newStatus: HandoverStatus.received,
        performerId: 'user_maya',
        performerName: 'Maya Chen',
      );
      expect(resolved.status, HandoverStatus.received);
      expect(resolved.events.last.type, HandoverEventType.issueResolved);

      // 4. Confirm return: received -> returned
      final returned = await repo.updateStatus(
        handoverId: 'hn_lifecycle_1',
        currentStatus: HandoverStatus.received,
        newStatus: HandoverStatus.returned,
        performerId: 'user_maya',
        performerName: 'Maya Chen',
      );
      expect(returned.status, HandoverStatus.returned);
      expect(returned.events.last.type, HandoverEventType.returned);
      expect(returned.events.length, 5); // CREATED, RECEIVED, DISPUTED, RESOLVED, RETURNED
    });

    test('prevent invalid status transitions and throws HandoverFailure', () async {
      const item = Handover(
        id: 'hn_invalid_1',
        token: 'HN-1049',
        itemName: 'Monitor',
        category: 'Electronics',
        identifier: 'MON-01',
        description: 'Display',
        senderName: 'Maya Chen',
        senderOrg: 'Studio',
        receiverName: 'Alex',
        receiverOrg: 'Lab',
        receiverEmail: 'alex@lab.io',
        returnExpected: true,
        status: HandoverStatus.pending,
      );

      await repo.createHandover(handover: item, ownerId: 'user_maya', performerName: 'Maya Chen');

      // Attempting to return directly from pending must fail
      expect(
        () => repo.updateStatus(
          handoverId: 'hn_invalid_1',
          currentStatus: HandoverStatus.pending,
          newStatus: HandoverStatus.returned,
          performerId: 'user_maya',
          performerName: 'Maya Chen',
        ),
        throwsA(isA<HandoverFailure>()),
      );
    });

    test('renewToken regenerates token from expired to pending', () async {
      const expiredItem = Handover(
        id: 'hn_exp_1',
        token: 'HN-1050',
        itemName: 'Keys',
        category: 'Keys & Access',
        identifier: 'KEY-01',
        description: 'Office key',
        senderName: 'Maya Chen',
        senderOrg: 'Studio',
        receiverName: 'Bob',
        receiverOrg: 'Staff',
        receiverEmail: 'bob@staff.com',
        returnExpected: true,
        status: HandoverStatus.expired,
      );

      await repo.createHandover(handover: expiredItem, ownerId: 'user_maya', performerName: 'Maya Chen');

      final renewed = await repo.renewToken(
        handoverId: 'hn_exp_1',
        newToken: 'HN-9999',
        performerId: 'user_maya',
        performerName: 'Maya Chen',
      );

      expect(renewed.status, HandoverStatus.pending);
      expect(renewed.token, 'HN-9999');
    });

    test('cancelHandover cancels a pending handover record', () async {
      const pendingItem = Handover(
        id: 'hn_cancel_1',
        token: 'HN-1051',
        itemName: 'Contract',
        category: 'Documents',
        identifier: 'DOC-01',
        description: 'Paper contract',
        senderName: 'Maya Chen',
        senderOrg: 'Studio',
        receiverName: 'Charlie',
        receiverOrg: 'Client',
        receiverEmail: 'charlie@client.com',
        returnExpected: false,
        status: HandoverStatus.pending,
      );

      await repo.createHandover(handover: pendingItem, ownerId: 'user_maya', performerName: 'Maya Chen');

      final cancelled = await repo.cancelHandover(
        handoverId: 'hn_cancel_1',
        currentStatus: HandoverStatus.pending,
        performerId: 'user_maya',
        performerName: 'Maya Chen',
        reason: 'Signed electronically instead',
      );

      expect(cancelled.status, HandoverStatus.cancelled);
      expect(cancelled.status.isTerminal, isTrue);
    });
  });

  group('HandoverProvider state and filtering tests', () {
    late MockHandoverRepository repo;
    late HandoverProvider provider;

    setUp(() {
      repo = MockHandoverRepository(initialItems: []);
      provider = HandoverProvider(handoverRepository: repo);
    });

    test('initial state is clean and empty when repo is empty', () {
      expect(provider.allHandovers, isEmpty);
      expect(provider.receivedHandovers, isEmpty);
      expect(provider.isLoading, isFalse);
      expect(provider.isSubmitting, isFalse);
      expect(provider.currentTab, HandoverTab.sentByMe);
      expect(provider.currentFilter, 'All');
    });

    test('loadHandovers partitions records into sent by me and received by me', () async {
      const sentItem = Handover(
        id: 'h_sent',
        ownerId: 'my_user_id',
        token: 'HN-1001',
        itemName: 'My Laptop',
        category: 'Electronics',
        identifier: 'LP-01',
        description: 'Work machine',
        senderName: 'Me',
        senderOrg: 'Studio',
        receiverName: 'Other Person',
        receiverOrg: 'Studio',
        receiverEmail: 'other@studio.com',
        returnExpected: true,
        status: HandoverStatus.received,
      );

      const receivedItem = Handover(
        id: 'h_received',
        ownerId: 'other_user_id',
        token: 'HN-2001',
        itemName: 'Lab Equipment',
        category: 'Equipment',
        identifier: 'EQ-01',
        description: 'Microphone',
        senderName: 'Other Person',
        senderOrg: 'Sound Lab',
        receiverName: 'Me',
        receiverOrg: 'Studio',
        receiverEmail: 'me@studio.com',
        returnExpected: true,
        status: HandoverStatus.received,
      );

      await repo.createHandover(handover: sentItem, ownerId: 'my_user_id', performerName: 'Me');
      await repo.createHandover(handover: receivedItem, ownerId: 'other_user_id', performerName: 'Other');

      await provider.loadHandovers(userId: 'my_user_id', userEmail: 'me@studio.com');

      expect(provider.allHandovers.length, 1);
      expect(provider.allHandovers.first.id, 'h_sent');

      expect(provider.receivedHandovers.length, 1);
      expect(provider.receivedHandovers.first.id, 'h_received');
    });

    test('filtering by status tabs: All, Active, Completed, Issues', () async {
      const activeItem = Handover(
        id: 'h_active',
        ownerId: 'user_1',
        token: 'HN-1001',
        itemName: 'Active Item',
        category: 'Electronics',
        identifier: 'ACT-01',
        description: '...',
        senderName: 'User',
        senderOrg: 'Studio',
        receiverName: 'Recv',
        receiverOrg: 'Studio',
        receiverEmail: 'recv@studio.com',
        returnExpected: true,
        status: HandoverStatus.received,
      );

      const completedItem = Handover(
        id: 'h_completed',
        ownerId: 'user_1',
        token: 'HN-1002',
        itemName: 'Completed Item',
        category: 'Electronics',
        identifier: 'CMP-01',
        description: '...',
        senderName: 'User',
        senderOrg: 'Studio',
        receiverName: 'Recv',
        receiverOrg: 'Studio',
        receiverEmail: 'recv@studio.com',
        returnExpected: true,
        status: HandoverStatus.returned,
      );

      const disputedItem = Handover(
        id: 'h_disputed',
        ownerId: 'user_1',
        token: 'HN-1003',
        itemName: 'Disputed Item',
        category: 'Electronics',
        identifier: 'DSP-01',
        description: '...',
        senderName: 'User',
        senderOrg: 'Studio',
        receiverName: 'Recv',
        receiverOrg: 'Studio',
        receiverEmail: 'recv@studio.com',
        returnExpected: true,
        status: HandoverStatus.disputed,
      );

      await repo.createHandover(handover: activeItem, ownerId: 'user_1', performerName: 'User');
      await repo.createHandover(handover: completedItem, ownerId: 'user_1', performerName: 'User');
      await repo.createHandover(handover: disputedItem, ownerId: 'user_1', performerName: 'User');

      await provider.loadHandovers(userId: 'user_1', userEmail: 'user@studio.com');

      provider.setFilter('All');
      expect(provider.filteredHandovers.length, 3);

      provider.setFilter('Active');
      expect(provider.filteredHandovers.length, 1);
      expect(provider.filteredHandovers.first.id, 'h_active');

      provider.setFilter('Completed');
      expect(provider.filteredHandovers.length, 1);
      expect(provider.filteredHandovers.first.id, 'h_completed');

      provider.setFilter('Issues');
      expect(provider.filteredHandovers.length, 1);
      expect(provider.filteredHandovers.first.id, 'h_disputed');
    });

    test('search query filters items by itemName, receiverName, and token', () async {
      const item1 = Handover(
        id: 'h_search_1',
        ownerId: 'user_1',
        token: 'HN-7777',
        itemName: 'MacBook Air',
        category: 'Electronics',
        identifier: 'MBA-01',
        description: '...',
        senderName: 'User',
        senderOrg: 'Studio',
        receiverName: 'Jordan Lee',
        receiverOrg: 'Studio',
        receiverEmail: 'jordan@studio.com',
        returnExpected: true,
        status: HandoverStatus.received,
      );

      await repo.createHandover(handover: item1, ownerId: 'user_1', performerName: 'User');
      await provider.loadHandovers(userId: 'user_1', userEmail: 'user@studio.com');

      // Search by itemName
      provider.setSearchQuery('MacBook');
      expect(provider.filteredHandovers.length, 1);

      // Search by token
      provider.setSearchQuery('7777');
      expect(provider.filteredHandovers.length, 1);

      // Search by receiver
      provider.setSearchQuery('Jordan');
      expect(provider.filteredHandovers.length, 1);

      // Search non-existent
      provider.setSearchQuery('NonExistentTerm');
      expect(provider.filteredHandovers.length, 0);
    });

    test('metrics calculation counts active, awaiting receipt, and overdue correctly', () async {
      final pastDate = DateTime.now().subtract(const Duration(days: 1));

      const itemReceived = Handover(
        id: 'h_m1',
        ownerId: 'user_1',
        token: 'HN-01',
        itemName: 'Item 1',
        category: 'E',
        identifier: 'I-1',
        description: '',
        senderName: 'U',
        senderOrg: 'O',
        receiverName: 'R',
        receiverOrg: 'O',
        receiverEmail: 'r@o.com',
        returnExpected: true,
        status: HandoverStatus.received,
      );

      const itemPending = Handover(
        id: 'h_m2',
        ownerId: 'user_1',
        token: 'HN-02',
        itemName: 'Item 2',
        category: 'E',
        identifier: 'I-2',
        description: '',
        senderName: 'U',
        senderOrg: 'O',
        receiverName: 'R',
        receiverOrg: 'O',
        receiverEmail: 'r@o.com',
        returnExpected: true,
        status: HandoverStatus.pending,
      );

      final itemOverdue = Handover(
        id: 'h_m3',
        ownerId: 'user_1',
        token: 'HN-03',
        itemName: 'Item 3',
        category: 'E',
        identifier: 'I-3',
        description: '',
        senderName: 'U',
        senderOrg: 'O',
        receiverName: 'R',
        receiverOrg: 'O',
        receiverEmail: 'r@o.com',
        returnExpected: true,
        returnDueAt: pastDate,
        status: HandoverStatus.overdue,
      );

      await repo.createHandover(handover: itemReceived, ownerId: 'user_1', performerName: 'U');
      await repo.createHandover(handover: itemPending, ownerId: 'user_1', performerName: 'U');
      await repo.createHandover(handover: itemOverdue, ownerId: 'user_1', performerName: 'U');

      await provider.loadHandovers(userId: 'user_1', userEmail: 'u@o.com');

      expect(provider.activeCount, 1);
      expect(provider.awaitingReceiptCount, 1);
      expect(provider.overdueCount, 1);
      expect(provider.activeHandovers.length, 2); // received + overdue
    });

    test('createHandover sets success message and inserts into allHandovers', () async {
      final created = await provider.createHandover(
        ownerId: 'user_test_99',
        itemName: 'Studio Keys',
        category: 'Keys & Access',
        identifier: 'KEY-99',
        description: 'Main gate',
        senderName: 'Maya Chen',
        senderOrg: 'Studio',
        receiverName: 'Alex',
        receiverOrg: 'Sound Lab',
        receiverEmail: 'alex@soundlab.design',
        returnExpected: true,
      );

      expect(created, isNotNull);
      expect(provider.allHandovers.length, 1);
      expect(provider.allHandovers.first.itemName, 'Studio Keys');
      expect(provider.successMessage, isNotNull);
    });
  });

  group('HandoverService and error mapping tests', () {
    test('HandoverFailure contains descriptive error and optional code', () {
      const failure = HandoverFailure('RLS denied', code: '42501');
      expect(failure.message, 'RLS denied');
      expect(failure.code, '42501');
      expect(failure.toString(), 'RLS denied');
    });

    test('PostgrestException mapping to user-friendly HandoverFailure', () {
      final service = SupabaseHandoverService(client: null);

      // Access denied / RLS error 42501
      const rlsException = PostgrestException(message: 'permission denied for table handovers', code: '42501');
      final mappedRls = service.mapPostgrestException(rlsException);
      expect(mappedRls.message, contains('Access denied'));

      // Check constraint violation (e.g. invalid status string)
      const checkException = PostgrestException(message: 'check constraint failed', code: '23514');
      final mappedCheck = service.mapPostgrestException(checkException);
      expect(mappedCheck.message, contains('Invalid status'));

      // Network error
      const networkException = PostgrestException(message: 'connection timeout error');
      final mappedNetwork = service.mapPostgrestException(networkException);
      expect(mappedNetwork.message, contains('Network error'));
    });
  });
}
