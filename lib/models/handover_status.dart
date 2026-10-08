import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

enum HandoverStatus {
  received,
  pending,
  overdue,
  returned,
  disputed,
  cancelled,
  expired;

  String get label {
    switch (this) {
      case HandoverStatus.received:
        return 'Received';
      case HandoverStatus.pending:
        return 'Pending';
      case HandoverStatus.overdue:
        return 'Overdue';
      case HandoverStatus.returned:
        return 'Returned';
      case HandoverStatus.disputed:
        return 'Disputed';
      case HandoverStatus.cancelled:
        return 'Cancelled';
      case HandoverStatus.expired:
        return 'Expired';
    }
  }

  Color bgColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (this) {
      case HandoverStatus.received:
        return isDark ? AppColors.statusReceivedDarkBg : AppColors.statusReceivedBg;
      case HandoverStatus.pending:
        return isDark ? AppColors.statusPendingDarkBg : AppColors.statusPendingBg;
      case HandoverStatus.overdue:
        return isDark ? AppColors.statusOverdueDarkBg : AppColors.statusOverdueBg;
      case HandoverStatus.returned:
        return isDark ? AppColors.statusReturnedDarkBg : AppColors.statusReturnedBg;
      case HandoverStatus.disputed:
        return isDark ? AppColors.statusDisputedDarkBg : AppColors.statusDisputedBg;
      case HandoverStatus.cancelled:
      case HandoverStatus.expired:
        return isDark ? AppColors.statusMutedDarkBg : AppColors.statusMutedBg;
    }
  }

  Color textColor(BuildContext context) {
    switch (this) {
      case HandoverStatus.received:
        return AppColors.statusReceivedText;
      case HandoverStatus.pending:
        return AppColors.statusPendingText;
      case HandoverStatus.overdue:
        return AppColors.statusOverdueText;
      case HandoverStatus.returned:
        return AppColors.statusReturnedText;
      case HandoverStatus.disputed:
        return AppColors.statusDisputedText;
      case HandoverStatus.cancelled:
      case HandoverStatus.expired:
        return AppColors.statusMutedText;
    }
  }

  /// Converts Dart enum to database CHECK constraint string
  String toDbString() {
    switch (this) {
      case HandoverStatus.received:
      case HandoverStatus.overdue:
        return 'RECEIVED';
      case HandoverStatus.pending:
        return 'PENDING';
      case HandoverStatus.returned:
        return 'RETURNED';
      case HandoverStatus.disputed:
        return 'DISPUTED';
      case HandoverStatus.cancelled:
        return 'CANCELLED';
      case HandoverStatus.expired:
        return 'EXPIRED';
    }
  }

  /// Parses database status string into HandoverStatus enum, checking deadline for overdue
  static HandoverStatus fromDbString(String? dbStatus, {DateTime? returnDueAt}) {
    if (dbStatus == null) return HandoverStatus.pending;
    final upper = dbStatus.toUpperCase().trim();

    // Check if return deadline has passed for active items
    if ((upper == 'RECEIVED' || upper == 'PENDING') &&
        returnDueAt != null &&
        returnDueAt.isBefore(DateTime.now())) {
      return HandoverStatus.overdue;
    }

    switch (upper) {
      case 'RECEIVED':
        return HandoverStatus.received;
      case 'PENDING':
        return HandoverStatus.pending;
      case 'RETURNED':
        return HandoverStatus.returned;
      case 'DISPUTED':
        return HandoverStatus.disputed;
      case 'CANCELLED':
        return HandoverStatus.cancelled;
      case 'EXPIRED':
        return HandoverStatus.expired;
      default:
        return HandoverStatus.pending;
    }
  }

  /// Validates whether transitioning from this status to target status is permitted
  bool canTransitionTo(HandoverStatus target) {
    if (this == target) return true;

    switch (this) {
      case HandoverStatus.pending:
        // Before receipt: can be confirmed, cancelled, or expired
        return target == HandoverStatus.received ||
            target == HandoverStatus.cancelled ||
            target == HandoverStatus.expired;

      case HandoverStatus.received:
      case HandoverStatus.overdue:
        // Once received: can be returned, disputed, or marked expired
        return target == HandoverStatus.returned ||
            target == HandoverStatus.disputed ||
            target == HandoverStatus.expired;

      case HandoverStatus.disputed:
        // Disputed: can be resolved back to received or confirmed returned
        return target == HandoverStatus.received ||
            target == HandoverStatus.returned;

      case HandoverStatus.expired:
        // Expired confirmation code: can be renewed back to pending
        return target == HandoverStatus.pending;

      case HandoverStatus.returned:
      case HandoverStatus.cancelled:
        // Terminal states cannot transition to other states
        return false;
    }
  }

  /// Whether this status represents a completed/closed lifecycle state
  bool get isTerminal => this == HandoverStatus.returned || this == HandoverStatus.cancelled;
}
