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
}
