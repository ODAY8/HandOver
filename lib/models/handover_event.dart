import 'package:flutter/material.dart';

enum HandoverEventType {
  created,
  received,
  deadlinePassed,
  issueRecorded,
  issueResolved,
  returned,
  cancelled,
  expired;

  IconData get icon {
    switch (this) {
      case HandoverEventType.created:
        return Icons.description_outlined;
      case HandoverEventType.received:
        return Icons.verified_user_outlined;
      case HandoverEventType.deadlinePassed:
        return Icons.access_time_outlined;
      case HandoverEventType.issueRecorded:
        return Icons.flag_outlined;
      case HandoverEventType.issueResolved:
        return Icons.check_circle_outline;
      case HandoverEventType.returned:
        return Icons.call_received_outlined;
      case HandoverEventType.cancelled:
        return Icons.cancel_outlined;
      case HandoverEventType.expired:
        return Icons.timer_off_outlined;
    }
  }

  String toDbString() {
    switch (this) {
      case HandoverEventType.created:
        return 'CREATED';
      case HandoverEventType.received:
        return 'RECEIVED';
      case HandoverEventType.deadlinePassed:
        return 'DEADLINE_PASSED';
      case HandoverEventType.issueRecorded:
        return 'ISSUE_RECORDED';
      case HandoverEventType.issueResolved:
        return 'ISSUE_RESOLVED';
      case HandoverEventType.returned:
        return 'RETURNED';
      case HandoverEventType.cancelled:
        return 'CANCELLED';
      case HandoverEventType.expired:
        return 'EXPIRED';
    }
  }

  static HandoverEventType fromDbString(String? type) {
    if (type == null) return HandoverEventType.created;
    switch (type.toUpperCase().trim()) {
      case 'CREATED':
        return HandoverEventType.created;
      case 'RECEIVED':
        return HandoverEventType.received;
      case 'DEADLINE_PASSED':
        return HandoverEventType.deadlinePassed;
      case 'ISSUE_RECORDED':
      case 'DISPUTED':
        return HandoverEventType.issueRecorded;
      case 'ISSUE_RESOLVED':
        return HandoverEventType.issueResolved;
      case 'RETURNED':
        return HandoverEventType.returned;
      case 'CANCELLED':
        return HandoverEventType.cancelled;
      case 'EXPIRED':
        return HandoverEventType.expired;
      default:
        return HandoverEventType.created;
    }
  }
}

class HandoverEvent {
  final String id;
  final String title;
  final DateTime timestamp;
  final HandoverEventType type;
  final String? performedBy;
  final String? description;

  const HandoverEvent({
    required this.id,
    required this.title,
    required this.timestamp,
    required this.type,
    this.performedBy,
    this.description,
  });

  factory HandoverEvent.fromRow(Map<String, dynamic> row) {
    final eventType = HandoverEventType.fromDbString(row['event_type']?.toString());
    final meta = row['metadata'] is Map<String, dynamic>
        ? row['metadata'] as Map<String, dynamic>
        : <String, dynamic>{};

    final performer = meta['performer_name']?.toString() ??
        row['performed_by']?.toString();

    final title = meta['title']?.toString() ?? _defaultTitle(eventType, performer);
    final desc = meta['description']?.toString() ?? meta['note']?.toString();

    final createdAt = row['created_at'] != null
        ? DateTime.tryParse(row['created_at'].toString()) ?? DateTime.now()
        : DateTime.now();

    return HandoverEvent(
      id: row['id']?.toString() ?? '',
      title: title,
      timestamp: createdAt.toLocal(),
      type: eventType,
      performedBy: performer,
      description: desc,
    );
  }

  static String _defaultTitle(HandoverEventType type, String? performer) {
    final who = performer != null && performer.isNotEmpty ? performer : 'User';
    switch (type) {
      case HandoverEventType.created:
        return 'Record created by $who';
      case HandoverEventType.received:
        return '$who confirmed physical receipt';
      case HandoverEventType.deadlinePassed:
        return 'Expected return deadline passed';
      case HandoverEventType.issueRecorded:
        return '$who recorded a condition issue';
      case HandoverEventType.issueResolved:
        return 'Condition issue resolved by $who';
      case HandoverEventType.returned:
        return '$who confirmed physical return';
      case HandoverEventType.cancelled:
        return 'Handover cancelled by $who';
      case HandoverEventType.expired:
        return 'Confirmation code expired';
    }
  }

  /// Converts this event to an insert map for `public.handover_events`
  Map<String, dynamic> toInsertRow({
    required String handoverId,
    required String userId,
  }) {
    return {
      'handover_id': handoverId,
      'event_type': type.toDbString(),
      'performed_by': userId,
      'metadata': {
        'title': title,
        if (performedBy != null && performedBy!.isNotEmpty) 'performer_name': performedBy,
        if (description != null && description!.isNotEmpty) 'description': description,
      },
    };
  }
}

