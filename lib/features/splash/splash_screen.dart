import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    // Auto-advance after 2.5 seconds
    _timer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        final isAuthenticated = context.read<AuthProvider>().isAuthenticated;
        context.go(isAuthenticated ? '/home' : '/onboarding');
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080E1A), // Deep navy background
      body: GestureDetector(
        onTap: () {
          final isAuthenticated = context.read<AuthProvider>().isAuthenticated;
          context.go(isAuthenticated ? '/home' : '/onboarding');
        },
        child: SafeArea(
          child: Stack(
            children: [
              // Glowing Concentric Circles in Background
              Center(
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 280 * _pulseAnimation.value,
                          height: 280 * _pulseAnimation.value,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF1E2D4A).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                        ),
                        Container(
                          width: 210 * _pulseAnimation.value,
                          height: 210 * _pulseAnimation.value,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF273A60).withOpacity(0.4),
                              width: 1.2,
                            ),
                          ),
                        ),
                        Container(
                          width: 140 * _pulseAnimation.value,
                          height: 140 * _pulseAnimation.value,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF16233B).withOpacity(0.5),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              // Center Logo & Title
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Opposing arrows badge
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B273E),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: const Color(0xFF334A70),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.compare_arrows_rounded,
                            size: 42,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),

                    // App Title
                    const Text(
                      'HANDOVER',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.5,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Subtitle
                    const Text(
                      'Keep every handover accountable.',
                      style: TextStyle(
                        color: Color(0xFF8E9AAF),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Caption & Accent Line
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 28,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'PHYSICAL ITEMS. DIGITAL PROOF.',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
