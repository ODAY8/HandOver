import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/segmented_tab_bar.dart';

class CreateStep2ReceiverScreen extends StatefulWidget {
  final Map<String, dynamic> itemData;

  const CreateStep2ReceiverScreen({super.key, required this.itemData});

  @override
  State<CreateStep2ReceiverScreen> createState() => _CreateStep2ReceiverScreenState();
}

class _CreateStep2ReceiverScreenState extends State<CreateStep2ReceiverScreen> {
  int _recipientTypeIndex = 0; // 0: Person, 1: Organization
  final _receiverNameController = TextEditingController(text: 'Jordan Lee');
  final _receiverEmailController = TextEditingController(text: 'jordan@northline.studio');
  final _receiverOrgController = TextEditingController(text: 'Northline Studio');
  final _notesController = TextEditingController(
    text: 'For the studio workshop. Please return with the charger.',
  );
  bool _returnExpected = true;
  DateTime _returnDueDate = DateTime(2026, 10, 16, 17, 0);

  @override
  void dispose() {
    _receiverNameController.dispose();
    _receiverEmailController.dispose();
    _receiverOrgController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onReview() {
    if (_receiverNameController.text.trim().isEmpty) return;

    final combinedData = {
      ...widget.itemData,
      'receiverName': _receiverNameController.text.trim(),
      'receiverEmail': _receiverEmailController.text.trim(),
      'receiverOrg': _receiverOrgController.text.trim(),
      'returnExpected': _returnExpected,
      'returnDueAt': _returnExpected ? _returnDueDate : null,
      'notes': _notesController.text.trim(),
    };

    context.push('/create-handover/step3', extra: combinedData);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Create handover'),
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
            // Top Stepper Indicator (Step 2 of 3)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Form content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Overline
                    const Text(
                      'STEP 2 OF 3 • RECEIVER & RETURN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Title
                    Text(
                      'Who’s receiving it?',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Recipient Type Segmented Control: Person | Organization
                    SegmentedTabBar(
                      selectedIndex: _recipientTypeIndex,
                      tabs: const ['Person', 'Organization'],
                      onTabSelected: (index) {
                        setState(() => _recipientTypeIndex = index);
                      },
                    ),
                    const SizedBox(height: 20),

                    // Receiver Name
                    CustomTextField(
                      label: 'Receiver name',
                      controller: _receiverNameController,
                    ),
                    const SizedBox(height: 18),

                    // Receiver Email
                    CustomTextField(
                      label: 'Receiver email',
                      controller: _receiverEmailController,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 22),

                    // Return Expected Switch Container
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Return expected',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                              ),
                              Switch.adaptive(
                                value: _returnExpected,
                                activeColor: AppColors.primary,
                                onChanged: (val) {
                                  setState(() => _returnExpected = val);
                                },
                              ),
                            ],
                          ),
                          if (_returnExpected) ...[
                            const SizedBox(height: 12),
                            // Date Picker selector
                            InkWell(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _returnDueDate,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (date != null) {
                                  setState(() {
                                    _returnDueDate = DateTime(
                                      date.year,
                                      date.month,
                                      date.day,
                                      17,
                                      0,
                                    );
                                  });
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkSurfaceLight : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today_outlined,
                                      size: 18,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      '16 Oct 2026 • 5:00 PM',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Your confirmation is required to mark it returned.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Handover note
                    CustomTextField(
                      label: 'Handover note (optional)',
                      controller: _notesController,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Bottom Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: AppButton(
                text: 'Review handover',
                trailingIcon: const Icon(Icons.arrow_forward, size: 18, color: Colors.white),
                onPressed: _onReview,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
