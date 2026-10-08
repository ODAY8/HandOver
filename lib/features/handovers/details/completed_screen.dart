import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/timeline_view.dart';
import '../../../models/handover_status.dart';
import '../../../models/handover_event.dart';
import '../../../providers/handover_provider.dart';

class CompletedScreen extends StatelessWidget {
  final String handoverId;

  const CompletedScreen({super.key, required this.handoverId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<HandoverProvider>();

    final handover = provider.getHandoverById(handoverId) ?? provider.allHandovers.first;

    // Ensure we show complete event cycle as depicted in Figma screen 18
    final events = handover.events.isNotEmpty
        ? handover.events
        : [
            HandoverEvent(
              id: 'ev_c1',
              title: '${handover.senderName} created the record',
              timestamp: DateTime(2026, 10, 14, 9, 0),
              type: HandoverEventType.created,
            ),
            HandoverEvent(
              id: 'ev_c2',
              title: '${handover.receiverName} confirmed physical receipt',
              timestamp: DateTime(2026, 10, 14, 9, 12),
              type: HandoverEventType.received,
            ),
            HandoverEvent(
              id: 'ev_c3',
              title: 'Condition issue resolved',
              timestamp: DateTime(2026, 10, 18, 14, 25),
              type: HandoverEventType.issueResolved,
            ),
            HandoverEvent(
              id: 'ev_c4',
              title: '${handover.senderName} confirmed physical return',
              timestamp: DateTime(2026, 10, 18, 14, 30),
              type: HandoverEventType.returned,
            ),
          ];

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/handovers'),
        ),
        title: Text('${handover.token} • Completed'),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Center 3D Stamp Medal
              Center(
                child: SizedBox(
                  width: 90,
                  height: 90,
                  child: Image.asset(
                    'assets/images/stamp_badge.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.check_circle_outline,
                      size: 64,
                      color: AppColors.statusReturnedText,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Center(
                child: Column(
                  children: [
                    Text(
                      'All accounted for.',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const StatusBadge(status: HandoverStatus.returned),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Summary Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      handover.itemName,
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${handover.token} • ${handover.identifier} • ${handover.receiverOrg}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${handover.senderName}  →  item  →  ${handover.receiverName}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Divider(
                      height: 1,
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                    const SizedBox(height: 16),

                    // Chain of custody events
                    TimelineView(events: events),

                    const SizedBox(height: 12),
                    Divider(
                      height: 1,
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                    const SizedBox(height: 12),

                    Text(
                      'Return due: 16 Oct 2026 • 5:00 PM\nA complete receipt, from handover to return.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Action Buttons
              AppButton(
                text: 'Export receipt',
                icon: const Icon(Icons.download_outlined, size: 18, color: Colors.white),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Handover PDF receipt exported successfully!'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              AppButton(
                text: 'Back to handovers',
                variant: ButtonVariant.secondary,
                onPressed: () => context.go('/handovers'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
