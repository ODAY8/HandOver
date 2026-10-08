import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/handover_card.dart';
import '../../core/widgets/segmented_tab_bar.dart';
import '../../providers/auth_provider.dart';
import '../../providers/handover_provider.dart';
import 'widgets/hero_banner_card.dart';
import 'widgets/metrics_row.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();
    final handoverProv = context.watch<HandoverProvider>();

    final user = auth.user;
    final activeList = handoverProv.activeHandovers;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Header: Date, Greeting, Avatar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WEDNESDAY, 14 OCTOBER',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Good morning, ${user.fullName.split(" ").first}.',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  // Avatar circle
                  GestureDetector(
                    onTap: () => context.go('/profile'),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceLight : AppColors.primaryLight,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          user.avatarInitials,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Hero Banner
              HeroBannerCard(
                onCreatePressed: () => context.push('/create-handover/step1'),
              ),
              const SizedBox(height: 22),

              // Quick Metrics Row (3 Active | 1 Awaiting receipt | 1 Overdue)
              MetricsRow(
                activeCount: handoverProv.activeCount,
                awaitingReceiptCount: handoverProv.awaitingReceiptCount,
                overdueCount: handoverProv.overdueCount,
              ),
              const SizedBox(height: 20),

              // Segmented Tab Bar: Sent by me | Received by me
              SegmentedTabBar(
                selectedIndex: handoverProv.currentTab == HandoverTab.sentByMe ? 0 : 1,
                tabs: const ['Sent by me', 'Received by me'],
                onTabSelected: (index) {
                  handoverProv.setTab(index == 0 ? HandoverTab.sentByMe : HandoverTab.receivedByMe);
                },
              ),
              const SizedBox(height: 22),

              // Section Header: Active handovers
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Active handovers',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.go('/handovers'),
                    child: const Text(
                      'View all',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Active Cards List
              if (activeList.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Text(
                    'No active handovers right now.',
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextSecondary,
                      fontSize: 14,
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: activeList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = activeList[index];
                    return HandoverCard(
                      handover: item,
                      onTap: () => context.push('/handover-detail/${item.id}'),
                    );
                  },
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
