import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class MetricsRow extends StatelessWidget {
  final int activeCount;
  final int awaitingReceiptCount;
  final int overdueCount;

  const MetricsRow({
    super.key,
    required this.activeCount,
    required this.awaitingReceiptCount,
    required this.overdueCount,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildMetricItem(
          context,
          count: '$activeCount',
          label: 'Active',
          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        ),
        _buildMetricItem(
          context,
          count: '$awaitingReceiptCount',
          label: 'Awaiting receipt',
          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        ),
        _buildMetricItem(
          context,
          count: '$overdueCount',
          label: 'Overdue',
          color: AppColors.statusOverdueText,
        ),
      ],
    );
  }

  Widget _buildMetricItem(
    BuildContext context, {
    required String count,
    required String label,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
