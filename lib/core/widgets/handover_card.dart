import 'package:flutter/material.dart';
import '../../models/handover.dart';
import '../../models/handover_status.dart';
import '../constants/app_colors.dart';
import 'status_badge.dart';

class HandoverCard extends StatelessWidget {
  final Handover handover;
  final VoidCallback? onTap;

  const HandoverCard({
    super.key,
    required this.handover,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isOverdue = handover.status == HandoverStatus.overdue;

    return Material(
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Item thumbnail container
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceLight : AppColors.lightCardSubtle,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(6),
                child: _buildItemThumbnail(),
              ),
              const SizedBox(width: 14),

              // Title and details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      handover.itemName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'To ${handover.receiverName} • ${handover.receiverOrg}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    if (isOverdue)
                      const Text(
                        'Return due 12 Oct • 2 days overdue',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.statusOverdueText,
                        ),
                      )
                    else if (handover.status == HandoverStatus.received && handover.returnDueAt != null)
                      Text(
                        'Return due 16 Oct 2026',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      )
                    else if (handover.status == HandoverStatus.pending)
                      Text(
                        'Code expires 15 Oct',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      )
                    else if (handover.status == HandoverStatus.returned)
                      Text(
                        'Returned 10 Oct 2026',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      )
                    else if (handover.status == HandoverStatus.disputed)
                      const Text(
                        'Issue recorded 13 Oct',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.statusDisputedText,
                        ),
                      )
                    else if (handover.status == HandoverStatus.cancelled)
                      Text(
                        'Cancelled 11 Oct 2026',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      )
                    else if (handover.status == HandoverStatus.expired)
                      Text(
                        'Code expired 12 Oct',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Status badge
              StatusBadge(status: handover.status),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemThumbnail() {
    if (handover.photoAsset != null) {
      return Image.asset(
        handover.photoAsset!,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _defaultIcon(),
      );
    }
    return _defaultIcon();
  }

  Widget _defaultIcon() {
    return const Icon(
      Icons.inventory_2_outlined,
      size: 24,
      color: AppColors.primary,
    );
  }
}
