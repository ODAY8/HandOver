// lib/repositories/handover_repository.dart

import 'dart:async';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/handover.dart';
import '../models/handover_status.dart';
import '../models/handover_event.dart';
import '../services/mock_data.dart';
import '../services/handover_service.dart';

abstract class HandoverRepository {
  Future<List<Handover>> fetchHandovers({
    required String currentUserId,
    required String currentUserEmail,
  });

  Future<Handover?> fetchHandoverById(
    String id, {
    required String currentUserId,
    required String currentUserEmail,
  });

  Future<Handover> createHandover({
    required Handover handover,
    required String ownerId,
    required String performerName,
  });

  Future<Handover> updateStatus({
    required String handoverId,
    required HandoverStatus currentStatus,
    required HandoverStatus newStatus,
    required String performerId,
    required String performerName,
    String? note,
    String? reason,
    String? description,
    DateTime? eventTime,
  });

  Future<Handover> renewToken({
    required String handoverId,
    required String newToken,
    required String performerId,
    required String performerName,
  });

  Future<Handover> cancelHandover({
    required String handoverId,
    required HandoverStatus currentStatus,
    required String performerId,
    required String performerName,
    String? reason,
  });
}

class SupabaseHandoverRepository implements HandoverRepository {
  final HandoverService _service;

  SupabaseHandoverRepository({HandoverService? service, SupabaseClient? client})
      : _service = service ?? SupabaseHandoverService(client: client);

  @override
  Future<List<Handover>> fetchHandovers({
    required String currentUserId,
    required String currentUserEmail,
  }) async {
    final rows = await _service.getHandovers();
    return rows.map((row) {
      return Handover.fromRow(
        row,
        currentUserId: currentUserId,
        currentUserEmail: currentUserEmail,
      );
    }).toList();
  }

  @override
  Future<Handover?> fetchHandoverById(
    String id, {
    required String currentUserId,
    required String currentUserEmail,
  }) async {
    final row = await _service.getHandoverById(id);
    if (row == null) return null;
    return Handover.fromRow(
      row,
      currentUserId: currentUserId,
      currentUserEmail: currentUserEmail,
    );
  }

  @override
  Future<Handover> createHandover({
    required Handover handover,
    required String ownerId,
    required String performerName,
  }) async {
    final handoverData = handover.toInsertRow(ownerId: ownerId);
    final initialEventData = {
      'event_type': HandoverEventType.created.toDbString(),
      'performed_by': ownerId,
      'metadata': {
        'title': 'Record created by $performerName',
        'performer_name': performerName,
      },
    };

    final savedRow = await _service.createHandover(
      handoverData: handoverData,
      initialEventData: initialEventData,
    );

    return Handover.fromRow(savedRow, currentUserId: ownerId);
  }

  @override
  Future<Handover> updateStatus({
    required String handoverId,
    required HandoverStatus currentStatus,
    required HandoverStatus newStatus,
    required String performerId,
    required String performerName,
    String? note,
    String? reason,
    String? description,
    DateTime? eventTime,
  }) async {
    // Validate transition
    if (!currentStatus.canTransitionTo(newStatus)) {
      throw HandoverFailure(
        'Invalid status transition from ${currentStatus.name} to ${newStatus.name}.',
      );
    }

    final extraFields = <String, dynamic>{};
    HandoverEventType eventType;
    String eventTitle;

    switch (newStatus) {
      case HandoverStatus.received:
        if (currentStatus == HandoverStatus.disputed) {
          eventType = HandoverEventType.issueResolved;
          eventTitle = 'Condition issue resolved by $performerName';
        } else {
          eventType = HandoverEventType.received;
          eventTitle = '$performerName confirmed physical receipt';
          extraFields['received_at'] = (eventTime ?? DateTime.now()).toUtc().toIso8601String();
        }
        break;
      case HandoverStatus.returned:
        eventType = HandoverEventType.returned;
        eventTitle = '$performerName confirmed physical return';
        extraFields['returned_at'] = (eventTime ?? DateTime.now()).toUtc().toIso8601String();
        break;
      case HandoverStatus.disputed:
        eventType = HandoverEventType.issueRecorded;
        eventTitle = '$performerName recorded a condition issue';
        break;
      case HandoverStatus.cancelled:
        eventType = HandoverEventType.cancelled;
        eventTitle = 'Handover cancelled by $performerName';
        break;
      case HandoverStatus.expired:
        eventType = HandoverEventType.expired;
        eventTitle = 'Confirmation code expired';
        break;
      case HandoverStatus.pending:
      case HandoverStatus.overdue:
        eventType = HandoverEventType.created;
        eventTitle = 'Status updated by $performerName';
        break;
    }

    final eventData = {
      'event_type': eventType.toDbString(),
      'performed_by': performerId,
      'metadata': {
        'title': eventTitle,
        'performer_name': performerName,
        if (description != null && description.isNotEmpty) 'description': description,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    };

    final savedRow = await _service.updateHandoverStatus(
      handoverId: handoverId,
      status: newStatus.toDbString(),
      eventData: eventData,
      extraFields: extraFields,
    );

    return Handover.fromRow(savedRow, currentUserId: performerId);
  }

  @override
  Future<Handover> renewToken({
    required String handoverId,
    required String newToken,
    required String performerId,
    required String performerName,
  }) async {
    final existingRow = await _service.getHandoverById(handoverId);
    if (existingRow == null) {
      throw const HandoverFailure('Handover record not found.');
    }

    final existingHandover = Handover.fromRow(existingRow);
    if (!existingHandover.status.canTransitionTo(HandoverStatus.pending)) {
      throw HandoverFailure(
        'Cannot renew token for handover in ${existingHandover.status.name} status.',
      );
    }

    Map<String, dynamic> meta = {};
    if (existingRow['purpose'] != null) {
      try {
        final decoded = jsonDecode(existingRow['purpose'].toString());
        if (decoded is Map<String, dynamic>) meta = decoded;
      } catch (_) {}
    }
    meta['token'] = newToken;

    final eventData = {
      'event_type': HandoverEventType.created.toDbString(),
      'performed_by': performerId,
      'metadata': {
        'title': 'New confirmation code generated by $performerName',
        'performer_name': performerName,
      },
    };

    final savedRow = await _service.updateHandoverStatus(
      handoverId: handoverId,
      status: HandoverStatus.pending.toDbString(),
      eventData: eventData,
      extraFields: {
        'purpose': jsonEncode(meta),
      },
    );

    return Handover.fromRow(savedRow, currentUserId: performerId);
  }

  @override
  Future<Handover> cancelHandover({
    required String handoverId,
    required HandoverStatus currentStatus,
    required String performerId,
    required String performerName,
    String? reason,
  }) async {
    return updateStatus(
      handoverId: handoverId,
      currentStatus: currentStatus,
      newStatus: HandoverStatus.cancelled,
      performerId: performerId,
      performerName: performerName,
      reason: reason,
    );
  }
}

class MockHandoverRepository implements HandoverRepository {
  final List<Handover> _items = [];

  MockHandoverRepository({List<Handover>? initialItems}) {
    if (initialItems != null) {
      _items.addAll(initialItems);
    } else {
      _items.addAll(MockData.getInitialHandovers());
      _items.addAll(MockData.getReceivedByMeHandovers());
    }
  }

  @override
  Future<List<Handover>> fetchHandovers({
    required String currentUserId,
    required String currentUserEmail,
  }) async {
    return List.unmodifiable(_items);
  }

  @override
  Future<Handover?> fetchHandoverById(
    String id, {
    required String currentUserId,
    required String currentUserEmail,
  }) async {
    try {
      return _items.firstWhere((h) => h.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Handover> createHandover({
    required Handover handover,
    required String ownerId,
    required String performerName,
  }) async {
    final createdEvent = HandoverEvent(
      id: 'ev_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Record created by $performerName',
      timestamp: DateTime.now(),
      type: HandoverEventType.created,
      performedBy: performerName,
    );

    final itemWithOwner = handover.copyWith(
      ownerId: ownerId,
      events: [createdEvent, ...handover.events],
    );

    _items.insert(0, itemWithOwner);
    return itemWithOwner;
  }

  @override
  Future<Handover> updateStatus({
    required String handoverId,
    required HandoverStatus currentStatus,
    required HandoverStatus newStatus,
    required String performerId,
    required String performerName,
    String? note,
    String? reason,
    String? description,
    DateTime? eventTime,
  }) async {
    if (!currentStatus.canTransitionTo(newStatus)) {
      throw HandoverFailure(
        'Invalid status transition from ${currentStatus.name} to ${newStatus.name}.',
      );
    }

    final index = _items.indexWhere((h) => h.id == handoverId);
    if (index == -1) {
      throw const HandoverFailure('Handover not found.');
    }

    final h = _items[index];
    HandoverEventType eventType;
    String eventTitle;

    switch (newStatus) {
      case HandoverStatus.received:
        eventType = currentStatus == HandoverStatus.disputed
            ? HandoverEventType.issueResolved
            : HandoverEventType.received;
        eventTitle = currentStatus == HandoverStatus.disputed
            ? 'Condition issue resolved by $performerName'
            : '$performerName confirmed physical receipt';
        break;
      case HandoverStatus.returned:
        eventType = HandoverEventType.returned;
        eventTitle = '$performerName confirmed physical return';
        break;
      case HandoverStatus.disputed:
        eventType = HandoverEventType.issueRecorded;
        eventTitle = '$performerName recorded a condition issue';
        break;
      case HandoverStatus.cancelled:
        eventType = HandoverEventType.cancelled;
        eventTitle = 'Handover cancelled by $performerName';
        break;
      case HandoverStatus.expired:
        eventType = HandoverEventType.expired;
        eventTitle = 'Confirmation code expired';
        break;
      case HandoverStatus.pending:
      case HandoverStatus.overdue:
        eventType = HandoverEventType.created;
        eventTitle = 'Status updated by $performerName';
        break;
    }

    final newEvent = HandoverEvent(
      id: 'ev_${DateTime.now().millisecondsSinceEpoch}',
      title: eventTitle,
      timestamp: eventTime ?? DateTime.now(),
      type: eventType,
      performedBy: performerName,
      description: description ?? note,
    );

    final updated = h.copyWith(
      status: newStatus,
      receivedAt: newStatus == HandoverStatus.received ? (eventTime ?? DateTime.now()) : h.receivedAt,
      returnedAt: newStatus == HandoverStatus.returned ? (eventTime ?? DateTime.now()) : h.returnedAt,
      issueReason: newStatus == HandoverStatus.disputed ? reason : h.issueReason,
      issueDescription: newStatus == HandoverStatus.disputed ? description : h.issueDescription,
      events: [...h.events, newEvent],
    );

    _items[index] = updated;
    return updated;
  }

  @override
  Future<Handover> renewToken({
    required String handoverId,
    required String newToken,
    required String performerId,
    required String performerName,
  }) async {
    final index = _items.indexWhere((h) => h.id == handoverId);
    if (index == -1) {
      throw const HandoverFailure('Handover not found.');
    }

    final h = _items[index];
    if (!h.status.canTransitionTo(HandoverStatus.pending)) {
      throw HandoverFailure(
        'Cannot renew token for handover in ${h.status.name} status.',
      );
    }

    final newEvent = HandoverEvent(
      id: 'ev_${DateTime.now().millisecondsSinceEpoch}',
      title: 'New confirmation code generated by $performerName',
      timestamp: DateTime.now(),
      type: HandoverEventType.created,
      performedBy: performerName,
    );

    final updated = h.copyWith(
      token: newToken,
      status: HandoverStatus.pending,
      events: [...h.events, newEvent],
    );

    _items[index] = updated;
    return updated;
  }

  @override
  Future<Handover> cancelHandover({
    required String handoverId,
    required HandoverStatus currentStatus,
    required String performerId,
    required String performerName,
    String? reason,
  }) async {
    return updateStatus(
      handoverId: handoverId,
      currentStatus: currentStatus,
      newStatus: HandoverStatus.cancelled,
      performerId: performerId,
      performerName: performerName,
      reason: reason,
    );
  }
}
