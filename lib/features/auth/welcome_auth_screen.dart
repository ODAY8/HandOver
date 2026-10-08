// lib/features/auth/welcome_auth_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../providers/auth_provider.dart';

class WelcomeAuthScreen extends StatefulWidget {
  const WelcomeAuthScreen({super.key});

  @override
  State<WelcomeAuthScreen> createState() => _WelcomeAuthScreenState();
}

class _WelcomeAuthScreenState extends State<WelcomeAuthScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSignUp = false;
  bool _obscurePassword = true;
  String? _localError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _clearErrors() {
    if (_localError != null) {
      setState(() => _localError = null);
    }
    context.read<AuthProvider>().clearError();
  }

  Future<void> _handleSubmit() async {
    _clearErrors();
    final auth = context.read<AuthProvider>();

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    // Input Validation
    if (email.isEmpty) {
      setState(() => _localError = 'Please enter your email address.');
      return;
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      setState(() => _localError = 'Please enter a valid email address.');
      return;
    }
    if (password.isEmpty) {
      setState(() => _localError = 'Please enter your password.');
      return;
    }
    if (password.length < 6) {
      setState(() => _localError = 'Password must be at least 6 characters.');
      return;
    }
    if (_isSignUp && name.isEmpty) {
      setState(() => _localError = 'Please enter your full name.');
      return;
    }

    bool success = false;
    if (_isSignUp) {
      success = await auth.signUp(
        email: email,
        password: password,
        fullName: name,
      );
    } else {
      success = await auth.signIn(
        email: email,
        password: password,
      );
    }

    if (!mounted) return;

    if (success) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProvider = context.watch<AuthProvider>();
    final activeError = _localError ?? authProvider.errorMessage;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/onboarding'),
        ),
        title: const Text('Welcome to HANDOVER'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Sign in or register to secure item custody records.'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 3D Folder / Wallet illustration
              Center(
                child: SizedBox(
                  width: 130,
                  height: 130,
                  child: Image.asset(
                    'assets/images/auth_wallet.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.folder_shared_outlined,
                      size: 80,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Mode Switcher Tabs (Sign in vs Create account)
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightCardSubtle,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (_isSignUp) {
                            setState(() => _isSignUp = false);
                            _clearErrors();
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !_isSignUp
                                ? AppColors.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: !_isSignUp
                                ? [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              'Sign In',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: !_isSignUp
                                    ? Colors.white
                                    : (isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (!_isSignUp) {
                            setState(() => _isSignUp = true);
                            _clearErrors();
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _isSignUp
                                ? AppColors.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _isSignUp
                                ? [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              'Create Account',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: _isSignUp
                                    ? Colors.white
                                    : (isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                'Your name. Your\naccountability.',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                _isSignUp
                    ? 'Create your verified identity. Every handover starts with real accountability.'
                    : 'Sign in or create an account with your email. Every receipt starts with a real identity.',
                style: TextStyle(
                  fontSize: 13.5,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // Error Banner (if error occurred)
              if (activeError != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.statusOverdueBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.statusOverdueText.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 20,
                        color: AppColors.statusOverdueText,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          activeError,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.statusOverdueText,
                            height: 1.35,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _clearErrors,
                        child: const Icon(
                          Icons.close,
                          size: 18,
                          color: AppColors.statusOverdueText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Full name field (Sign Up only)
              if (_isSignUp) ...[
                CustomTextField(
                  label: 'Full name',
                  hint: 'e.g. Alex Morgan',
                  controller: _nameController,
                  suffixIcon: Icon(
                    Icons.person_outline,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                  onChanged: (_) => _clearErrors(),
                ),
                const SizedBox(height: 16),
              ],

              // Email field
              CustomTextField(
                label: 'Email address',
                hint: 'you@domain.com',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                suffixIcon: Icon(
                  Icons.mail_outline,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
                onChanged: (_) => _clearErrors(),
              ),
              const SizedBox(height: 16),

              // Password field
              CustomTextField(
                label: 'Password',
                hint: _isSignUp ? 'At least 6 characters' : 'Enter your password',
                controller: _passwordController,
                obscureText: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
                onChanged: (_) => _clearErrors(),
              ),
              const SizedBox(height: 16),

              // Privacy / Security Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lock_outline,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your handover records stay securely between the parties involved.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Action Button (Sign In / Create Account)
              AppButton(
                text: 'Continue with email',
                isLoading: authProvider.isLoading,
                trailingIcon: const Icon(Icons.arrow_forward, size: 18, color: Colors.white),
                onPressed: _handleSubmit,
              ),
              const SizedBox(height: 18),

              // Switch mode link
              Center(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _isSignUp = !_isSignUp);
                    _clearErrors();
                  },
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                      children: [
                        TextSpan(
                          text: _isSignUp
                              ? 'Already have an account? '
                              : "Don't have an account? ",
                        ),
                        TextSpan(
                          text: _isSignUp ? 'Sign in' : 'Create one',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Terms Footer
              Center(
                child: Text(
                  'By continuing, you agree to our Terms of use and Privacy policy.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
