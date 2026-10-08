import 'dart:convert';
import 'handover_status.dart';
import 'handover_event.dart';

class Handover {
  final String id;
  final String? ownerId;
  final String token;
  final String itemName;
  final String category;
  final String identifier;
  final String description;
  final String? photoAsset;
  final String senderName;
  final String senderOrg;
  final String receiverName;
  final String receiverOrg;
  final String receiverEmail;
  final String? receiverPhone;
  final bool returnExpected;
  final DateTime? returnDueAt;
  final DateTime? receivedAt;
  final DateTime? returnedAt;
  final DateTime? createdAt;
  final HandoverStatus status;
  final String? notes;
  final String? issueReason;
  final String? issueDescription;
  final List<HandoverEvent> events;

  const Handover({
    required this.id,
    this.ownerId,
    required this.token,
    required this.itemName,
    required this.category,
    required this.identifier,
    required this.description,
    this.photoAsset,
    required this.senderName,
    required this.senderOrg,
    required this.receiverName,
    required this.receiverOrg,
    required this.receiverEmail,
    this.receiverPhone,
    required this.returnExpected,
    this.returnDueAt,
    this.receivedAt,
    this.returnedAt,
    this.createdAt,
    required this.status,
    this.notes,
    this.issueReason,
    this.issueDescription,
    this.events = const [],
  });

  Handover copyWith({
    String? id,
    String? ownerId,
    String? token,
    String? itemName,
    String? category,
    String? identifier,
    String? description,
    String? photoAsset,
    String? senderName,
    String? senderOrg,
    String? receiverName,
    String? receiverOrg,
    String? receiverEmail,
    String? receiverPhone,
    bool? returnExpected,
    DateTime? returnDueAt,
    DateTime? receivedAt,
    DateTime? returnedAt,
    DateTime? createdAt,
    HandoverStatus? status,
    String? notes,
    String? issueReason,
    String? issueDescription,
    List<HandoverEvent>? events,
  }) {
    return Handover(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      token: token ?? this.token,
      itemName: itemName ?? this.itemName,
      category: category ?? this.category,
      identifier: identifier ?? this.identifier,
      description: description ?? this.description,
      photoAsset: photoAsset ?? this.photoAsset,
      senderName: senderName ?? this.senderName,
      senderOrg: senderOrg ?? this.senderOrg,
      receiverName: receiverName ?? this.receiverName,
      receiverOrg: receiverOrg ?? this.receiverOrg,
      receiverEmail: receiverEmail ?? this.receiverEmail,
      receiverPhone: receiverPhone ?? this.receiverPhone,
      returnExpected: returnExpected ?? this.returnExpected,
      returnDueAt: returnDueAt ?? this.returnDueAt,
      receivedAt: receivedAt ?? this.receivedAt,
      returnedAt: returnedAt ?? this.returnedAt,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      issueReason: issueReason ?? this.issueReason,
      issueDescription: issueDescription ?? this.issueDescription,
      events: events ?? this.events,
    );
  }

  /// Parses a Supabase row from `public.handovers` with optional joined `handover_events`
  factory Handover.fromRow(
    Map<String, dynamic> row, {
    String? currentUserId,
    String? currentUserEmail,
  }) {
    Map<String, dynamic> meta = {};
    String? plainNotes;

    if (row['purpose'] != null) {
      final rawPurpose = row['purpose'].toString();
      try {
        final decoded = jsonDecode(rawPurpose);
        if (decoded is Map<String, dynamic>) {
          meta = decoded;
        } else {
          plainNotes = rawPurpose;
        }
      } catch (_) {
        plainNotes = rawPurpose;
      }
    }

    final id = row['id']?.toString() ?? '';
    final shortId = id.length >= 4 ? id.substring(0, 4).toUpperCase() : '1048';
    final token = meta['token']?.toString() ?? 'HN-$shortId';
    final identifier = meta['identifier']?.toString() ??
        (id.length >= 8 ? id.substring(0, 8).toUpperCase() : 'ITM-$shortId');

    final returnDueAt = row['expected_return_at'] != null
        ? DateTime.tryParse(row['expected_return_at'].toString())?.toLocal()
        : null;
    final receivedAt = row['received_at'] != null
        ? DateTime.tryParse(row['received_at'].toString())?.toLocal()
        : null;
    final returnedAt = row['returned_at'] != null
        ? DateTime.tryParse(row['returned_at'].toString())?.toLocal()
        : null;
    final createdAt = row['created_at'] != null
        ? DateTime.tryParse(row['created_at'].toString())?.toLocal()
        : null;

    final status = HandoverStatus.fromDbString(
      row['status']?.toString(),
      returnDueAt: returnDueAt,
    );

    // Parse joined events if present
    List<HandoverEvent> events = [];
    if (row['handover_events'] is List) {
      events = (row['handover_events'] as List)
          .map((e) => HandoverEvent.fromRow(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }

    // Default CREATED event if none recorded yet
    if (events.isEmpty) {
      events = [
        HandoverEvent(
          id: 'ev_created_$id',
          title: 'Record created',
          timestamp: createdAt ?? DateTime.now(),
          type: HandoverEventType.created,
          performedBy: meta['sender_name']?.toString(),
        ),
      ];
    }

    final ownerId = row['owner_id']?.toString();
    final senderName = meta['sender_name']?.toString() ??
        (ownerId != null && ownerId == currentUserId ? 'You' : 'Sender');

    return Handover(
      id: id,
      ownerId: ownerId,
      token: token,
      itemName: row['item_name']?.toString() ?? 'Item',
      category: row['item_type']?.toString() ?? 'Equipment',
      identifier: identifier,
      description: row['description']?.toString() ?? '',
      photoAsset: row['photo_url']?.toString() ?? 'assets/images/item_laptop.png',
      senderName: senderName,
      senderOrg: meta['sender_org']?.toString() ?? 'Northline Studio',
      receiverName: row['recipient_name']?.toString() ?? 'Recipient',
      receiverOrg: meta['receiver_org']?.toString() ?? 'Northline Studio',
      receiverEmail: row['recipient_email']?.toString() ?? '',
      receiverPhone: row['recipient_phone']?.toString(),
      returnExpected: meta['return_expected'] == true || returnDueAt != null,
      returnDueAt: returnDueAt,
      receivedAt: receivedAt,
      returnedAt: returnedAt,
      createdAt: createdAt,
      status: status,
      notes: meta['notes']?.toString() ?? plainNotes,
      issueReason: meta['issue_reason']?.toString(),
      issueDescription: meta['issue_description']?.toString(),
      events: events,
    );
  }

  /// Converts this instance to a map ready for insertion into `public.handovers`
  Map<String, dynamic> toInsertRow({required String ownerId}) {
    final meta = <String, dynamic>{
      'token': token,
      'identifier': identifier,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
      if (senderName.isNotEmpty) 'sender_name': senderName,
      if (senderOrg.isNotEmpty) 'sender_org': senderOrg,
      if (receiverOrg.isNotEmpty) 'receiver_org': receiverOrg,
      'return_expected': returnExpected,
      if (issueReason != null) 'issue_reason': issueReason,
      if (issueDescription != null) 'issue_description': issueDescription,
    };

    return {
      'owner_id': ownerId,
      'item_name': itemName,
      'item_type': category,
      'description': description,
      'photo_url': photoAsset,
      'recipient_name': receiverName,
      'recipient_email': receiverEmail,
      if (receiverPhone != null && receiverPhone!.isNotEmpty) 'recipient_phone': receiverPhone,
      'purpose': jsonEncode(meta),
      'status': status.toDbString(),
      if (returnDueAt != null) 'expected_return_at': returnDueAt!.toUtc().toIso8601String(),
      if (receivedAt != null) 'received_at': receivedAt!.toUtc().toIso8601String(),
      if (returnedAt != null) 'returned_at': returnedAt!.toUtc().toIso8601String(),
    };
  }
}
