import 'package:flutter/material.dart';
import '../../models/handover.dart';
import '../../models/handover_event.dart';
import '../../models/handover_status.dart';
import '../constants/app_colors.dart';
import '../utils/date_formatter.dart';
import 'status_badge.dart';

class HandoverCard extends StatelessWidget {
  final Handover handover;
  final VoidCallback? onTap;

  const HandoverCard({super.key, required this.handover, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isNotOverdueStatus =
        handover.status == HandoverStatus.pending ||
        handover.status == HandoverStatus.expired ||
        handover.status == HandoverStatus.returned ||
        handover.status == HandoverStatus.cancelled;

    final isOverdue =
        !isNotOverdueStatus &&
        (handover.status == HandoverStatus.overdue ||
            (handover.status == HandoverStatus.received &&
                handover.returnExpected &&
                handover.returnDueAt != null &&
                DateTime.now().isAfter(handover.returnDueAt!)));

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
                  color: isDark
                      ? AppColors.darkSurfaceLight
                      : AppColors.lightCardSubtle,
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
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'To ${handover.receiverName} • ${handover.receiverOrg}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    if (isOverdue)
                      Builder(
                        builder: (context) {
                          final dueStr = AppDateFormatter.formatShortDate(
                            handover.returnDueAt,
                            fallback: '',
                          );
                          final overdueStr =
                              AppDateFormatter.formatOverdueShort(
                                handover.returnDueAt,
                                fallback: 'Overdue',
                              );
                          final text = dueStr.isNotEmpty
                              ? 'Return due $dueStr • $overdueStr'
                              : overdueStr;
                          return Text(
                            text,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: AppColors.statusOverdueText,
                            ),
                          );
                        },
                      )
                    else if (handover.status == HandoverStatus.received)
                      Builder(
                        builder: (context) {
                          final text =
                              handover.returnExpected &&
                                  handover.returnDueAt != null
                              ? 'Return due ${AppDateFormatter.formatShortDate(handover.returnDueAt)}'
                              : 'In ${handover.receiverName}\'s care';
                          return Text(
                            text,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted,
                            ),
                          );
                        },
                      )
                    else if (handover.status == HandoverStatus.pending)
                      Builder(
                        builder: (context) {
                          DateTime? createdDate = handover.createdAt;
                          if (createdDate == null) {
                            for (final ev in handover.events) {
                              if (ev.type == HandoverEventType.created) {
                                createdDate = ev.timestamp;
                                break;
                              }
                            }
                          }
                          final expiry = AppDateFormatter.calculateQrExpiry(
                            createdDate,
                          );
                          final expiryShort = AppDateFormatter.formatShortDate(
                            expiry,
                            fallback: '',
                          );
                          final text = expiryShort.isNotEmpty
                              ? 'Code expires $expiryShort'
                              : 'Awaiting acknowledgment';
                          return Text(
                            text,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted,
                            ),
                          );
                        },
                      )
                    else if (handover.status == HandoverStatus.returned)
                      Builder(
                        builder: (context) {
                          DateTime? returnedDate = handover.returnedAt;
                          if (returnedDate == null) {
                            for (final ev in handover.events) {
                              if (ev.type == HandoverEventType.returned) {
                                if (returnedDate == null ||
                                    ev.timestamp.isAfter(returnedDate)) {
                                  returnedDate = ev.timestamp;
                                }
                              }
                            }
                          }
                          final text = returnedDate != null
                              ? 'Returned ${AppDateFormatter.formatShortDate(returnedDate)}'
                              : 'Returned';
                          return Text(
                            text,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted,
                            ),
                          );
                        },
                      )
                    else if (handover.status == HandoverStatus.disputed)
                      Builder(
                        builder: (context) {
                          DateTime? issueDate;
                          for (final ev in handover.events) {
                            if (ev.type == HandoverEventType.issueRecorded) {
                              if (issueDate == null ||
                                  ev.timestamp.isAfter(issueDate)) {
                                issueDate = ev.timestamp;
                              }
                            }
                          }
                          final text = issueDate != null
                              ? 'Issue recorded ${AppDateFormatter.formatShortDate(issueDate)}'
                              : 'Issue recorded';
                          return Text(
                            text,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.statusDisputedText,
                            ),
                          );
                        },
                      )
                    else if (handover.status == HandoverStatus.cancelled)
                      Builder(
                        builder: (context) {
                          DateTime? cancelDate;
                          for (final ev in handover.events) {
                            if (ev.type == HandoverEventType.cancelled) {
                              if (cancelDate == null ||
                                  ev.timestamp.isAfter(cancelDate)) {
                                cancelDate = ev.timestamp;
                              }
                            }
                          }
                          final text = cancelDate != null
                              ? 'Cancelled ${AppDateFormatter.formatShortDate(cancelDate)}'
                              : 'Cancelled';
                          return Text(
                            text,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted,
                            ),
                          );
                        },
                      )
                    else if (handover.status == HandoverStatus.expired)
                      Builder(
                        builder: (context) {
                          DateTime? createdDate = handover.createdAt;
                          if (createdDate == null) {
                            for (final ev in handover.events) {
                              if (ev.type == HandoverEventType.created) {
                                createdDate = ev.timestamp;
                                break;
                              }
                            }
                          }
                          final expiry = AppDateFormatter.calculateQrExpiry(
                            createdDate,
                          );
                          final expiryShort = AppDateFormatter.formatShortDate(
                            expiry,
                            fallback: '',
                          );
                          final text = expiryShort.isNotEmpty
                              ? 'Code expired $expiryShort'
                              : 'Code expired';
                          return Text(
                            text,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted,
                            ),
                          );
                        },
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
