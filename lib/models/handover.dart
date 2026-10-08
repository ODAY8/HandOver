import 'handover_status.dart';
import 'handover_event.dart';

class Handover {
  final String id;
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
  final HandoverStatus status;
  final String? notes;
  final String? issueReason;
  final String? issueDescription;
  final List<HandoverEvent> events;

  const Handover({
    required this.id,
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
    required this.status,
    this.notes,
    this.issueReason,
    this.issueDescription,
    this.events = const [],
  });

  Handover copyWith({
    String? id,
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
    HandoverStatus? status,
    String? notes,
    String? issueReason,
    String? issueDescription,
    List<HandoverEvent>? events,
  }) {
    return Handover(
      id: id ?? this.id,
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
      status: status ?? this.status,
      notes: notes ?? this.notes,
      issueReason: issueReason ?? this.issueReason,
      issueDescription: issueDescription ?? this.issueDescription,
      events: events ?? this.events,
    );
  }
}
