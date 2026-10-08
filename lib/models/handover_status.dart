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
}
