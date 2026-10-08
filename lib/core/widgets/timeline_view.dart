import 'package:flutter/material.dart';
import '../../models/handover_event.dart';
import '../constants/app_colors.dart';

class TimelineView extends StatelessWidget {
  final List<HandoverEvent> events;

  const TimelineView({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        final isLast = index == events.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Node & vertical connector line
            Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceLight : AppColors.lightCardSubtle,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Icon(
                    event.type.icon,
                    size: 16,
                    color: _getNodeIconColor(event.type),
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 36,
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
              ],
            ),
            const SizedBox(width: 14),

            // Event Details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(event.timestamp),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                    if (event.description != null && event.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        event.description!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Color _getNodeIconColor(HandoverEventType type) {
    switch (type) {
      case HandoverEventType.created:
        return AppColors.lightTextSecondary;
      case HandoverEventType.received:
        return AppColors.primary;
      case HandoverEventType.deadlinePassed:
        return AppColors.statusOverdueText;
      case HandoverEventType.issueRecorded:
        return AppColors.statusDisputedText;
      case HandoverEventType.issueResolved:
        return AppColors.statusReturnedText;
      case HandoverEventType.returned:
        return AppColors.statusReturnedText;
      case HandoverEventType.cancelled:
      case HandoverEventType.expired:
        return AppColors.statusMutedText;
    }
  }

  String _formatDate(DateTime dt) {
    // Exact format shown in Figma: "14 Oct 2026 • 9:00 AM"
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} • $hour:$minute $period';
  }
}
