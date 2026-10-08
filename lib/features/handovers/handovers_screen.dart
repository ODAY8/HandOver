import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/handover_card.dart';
import '../../core/widgets/segmented_tab_bar.dart';
import '../../core/widgets/filter_chips_bar.dart';
import '../../providers/auth_provider.dart';
import '../../providers/handover_provider.dart';

class HandoversScreen extends StatefulWidget {
  const HandoversScreen({super.key});

  @override
  State<HandoversScreen> createState() => _HandoversScreenState();
}

class _HandoversScreenState extends State<HandoversScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final auth = context.read<AuthProvider>();
    if (auth.isAuthenticated && auth.user.id.isNotEmpty) {
      context.read<HandoverProvider>().loadHandovers(
            userId: auth.user.id,
            userEmail: auth.user.email,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<HandoverProvider>();
    final items = provider.filteredHandovers;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'My handovers',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  // Plus Action Button
                  Material(
                    color: isDark ? AppColors.darkSurfaceLight : AppColors.primaryLight,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () => context.push('/create-handover/step1'),
                      customBorder: const CircleBorder(),
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(
                          Icons.add,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Segmented Tabs: Sent by me | Received by me
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: SegmentedTabBar(
                selectedIndex: provider.currentTab == HandoverTab.sentByMe ? 0 : 1,
                tabs: const ['Sent by me', 'Received by me'],
                onTabSelected: (index) {
                  provider.setTab(index == 0 ? HandoverTab.sentByMe : HandoverTab.receivedByMe);
                },
              ),
            ),
            const SizedBox(height: 12),

            // Filter Chips Bar: All | Active | Completed | Issues
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: FilterChipsBar(
                chips: const ['All', 'Active', 'Completed', 'Issues'],
                selectedChip: provider.currentFilter,
                onSelected: (chip) => provider.setFilter(chip),
              ),
            ),
            const SizedBox(height: 14),

            // Items List / Loading / Empty State
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  _loadData();
                },
                color: AppColors.primary,
                child: provider.isLoading && items.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      )
                    : items.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 56,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                              const SizedBox(height: 12),
                              Center(
                                child: Text(
                                  'No handovers in "${provider.currentFilter}"',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Center(
                                child: Text(
                                  'Try selecting another filter or create a new handover.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                            itemCount: items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = items[index];
                              return HandoverCard(
                                handover: item,
                                onTap: () => context.push('/handover-detail/${item.id}'),
                              );
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
