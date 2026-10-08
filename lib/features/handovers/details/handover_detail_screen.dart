import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/custody_stepper.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/timeline_view.dart';
import '../../../models/handover_status.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/handover_provider.dart';

class HandoverDetailScreen extends StatelessWidget {
  final String handoverId;

  const HandoverDetailScreen({super.key, required this.handoverId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<HandoverProvider>();

    final handover = provider.getHandoverById(handoverId) ??
        (provider.allHandovers.isNotEmpty ? provider.allHandovers.first : null);

    if (handover == null) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: const Text('Handover detail'),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.primary),
              const SizedBox(height: 12),
              Text(
                'Handover record not found',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Go back'),
              ),
            ],
          ),
        ),
      );
    }

    final isOverdue = handover.status == HandoverStatus.overdue;
    final isDisputed = handover.status == HandoverStatus.disputed;
    final isReceived = handover.status == HandoverStatus.received;
    final isPending = handover.status == HandoverStatus.pending;
    final isReturned = handover.status == HandoverStatus.returned;
    final isExpired = handover.status == HandoverStatus.expired;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text('${handover.token} • Handover detail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Item Header Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkSurfaceLight : Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: const EdgeInsets.all(8),
                                child: Image.asset(
                                  handover.photoAsset ?? 'assets/images/item_laptop.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.laptop_mac_outlined,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
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
                                      'Space gray • ${handover.identifier}',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    StatusBadge(status: handover.status),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'HANDOVER ${handover.token} • ${handover.returnExpected ? "RETURN EXPECTED" : "NO RETURN REQUIRED"}',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Overdue Banner
                    if (isOverdue) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.statusOverdueDarkBg : AppColors.statusOverdueBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.statusOverdueText.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: AppColors.statusOverdueText,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '1 day, 19 hours overdue',
                                    style: TextStyle(
                                      color: AppColors.statusOverdueText,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'As of 18 Oct 2026, 12:00 PM. This ${handover.itemName.toLowerCase()} has not been confirmed returned.',
                                    style: TextStyle(
                                      color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
                                      fontSize: 12,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Disputed Banner
                    if (isDisputed) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.statusDisputedDarkBg : AppColors.statusDisputedBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.statusDisputedText.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: AppColors.statusDisputedText,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    handover.issueReason ?? 'Item condition differs',
                                    style: const TextStyle(
                                      color: AppColors.statusDisputedText,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Recorded by ${handover.senderName}, 18 Oct at 12:10 PM. Receipt remains verified; return is not yet confirmed.',
                                    style: TextStyle(
                                      color: isDark ? Colors.white70 : AppColors.lightTextSecondary,
                                      fontSize: 12,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Custody Details Card
                    CustodyStepperCard(handover: handover),
                    const SizedBox(height: 20),

                    // Chain of custody / History header
                    Text(
                      isOverdue || isDisputed ? 'Record history' : 'A clear chain of custody',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Timeline View
                    TimelineView(events: handover.events),

                    // Custody completion footnote
                    if (!isReturned) ...[
                      const SizedBox(height: 6),
                      Text(
                        'In ${handover.receiverName}\'s care until returned. Only your acknowledgment will complete this record.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Bottom Actions Bar
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isReceived) ...[
                    AppButton(
                      text: 'Confirm physical return',
                      icon: const Icon(Icons.call_received, size: 18, color: Colors.white),
                      onPressed: () => context.push('/confirm-return/${handover.id}'),
                    ),
                    const SizedBox(height: 8),
                    AppButton(
                      text: 'Record an issue',
                      variant: ButtonVariant.secondary,
                      onPressed: () => context.push('/record-issue/${handover.id}'),
                    ),
                  ] else if (isOverdue) ...[
                    AppButton(
                      text: 'Send return reminder',
                      icon: const Icon(Icons.notifications_active_outlined, size: 18, color: Colors.white),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Reminder sent to ${handover.receiverName}!'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    AppButton(
                      text: 'Confirm physical return',
                      variant: ButtonVariant.secondary,
                      onPressed: () => context.push('/confirm-return/${handover.id}'),
                    ),
                  ] else if (isDisputed) ...[
                    AppButton(
                      text: 'Resolve recorded issue',
                      icon: const Icon(Icons.check_circle_outline, size: 18, color: Colors.white),
                      onPressed: () async {
                        final auth = context.read<AuthProvider>();
                        final ok = await provider.resolveIssue(
                          handover.id,
                          resolverId: auth.user.id,
                          resolverName: auth.user.fullName,
                        );
                        if (context.mounted) {
                          if (ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Disputed issue resolved! Status is now active.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(provider.errorMessage ?? 'Failed to resolve issue.'),
                                backgroundColor: AppColors.error,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    AppButton(
                      text: 'Confirm physical return',
                      variant: ButtonVariant.secondary,
                      onPressed: () => context.push('/confirm-return/${handover.id}'),
                    ),
                  ] else if (isPending) ...[
                    AppButton(
                      text: 'Show QR code',
                      icon: const Icon(Icons.qr_code, size: 18, color: Colors.white),
                      onPressed: () => context.push('/share-qr/${handover.token}'),
                    ),
                  ] else if (isExpired) ...[
                    AppButton(
                      text: 'View expired code',
                      variant: ButtonVariant.secondary,
                      onPressed: () => context.push('/expired-code/${handover.id}'),
                    ),
                  ] else if (isReturned) ...[
                    AppButton(
                      text: 'View completed receipt',
                      icon: const Icon(Icons.receipt_long, size: 18, color: Colors.white),
                      onPressed: () => context.push('/completed/${handover.id}'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
