import 'package:flutter/material.dart';

class AppColors {
  // Brand & Primary
  static const Color primary = Color(0xFF4F46E5); // Indigo 600
  static const Color primaryHover = Color(0xFF4338CA); // Indigo 700
  static const Color primaryLight = Color(0xFFEEF2FF); // Indigo 50
  static const Color navyDark = Color(0xFF0D1527); // Dark navy banner / splash
  static const Color navyBackground = Color(0xFF0B132B);

  // Light Theme
  static const Color lightBg = Color(0xFFF8FAFC); // Slate 50
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0); // Slate 200
  static const Color lightCardSubtle = Color(0xFFF1F5F9); // Slate 100
  static const Color lightTextPrimary = Color(0xFF0F172A); // Slate 900
  static const Color lightTextSecondary = Color(0xFF64748B); // Slate 500
  static const Color lightTextMuted = Color(0xFF94A3B8); // Slate 400

  // Dark Theme
  static const Color darkBg = Color(0xFF0B1120); // Deep night navy
  static const Color darkSurface = Color(0xFF1E293B); // Slate 800
  static const Color darkSurfaceLight = Color(0xFF243047);
  static const Color darkBorder = Color(0xFF334155); // Slate 700
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);

  // Status Colors
  // Received (Blue)
  static const Color statusReceivedBg = Color(0xFFEFF6FF);
  static const Color statusReceivedText = Color(0xFF2563EB);
  static const Color statusReceivedDarkBg = Color(0xFF172554);

  // Pending (Amber)
  static const Color statusPendingBg = Color(0xFFFEF3C7);
  static const Color statusPendingText = Color(0xFFD97706);
  static const Color statusPendingDarkBg = Color(0xFF451A03);

  // Overdue (Red)
  static const Color statusOverdueBg = Color(0xFFFEF2F2);
  static const Color statusOverdueText = Color(0xFFDC2626);
  static const Color statusOverdueDarkBg = Color(0xFF450A0A);

  // Returned (Green/Emerald)
  static const Color statusReturnedBg = Color(0xFFECFDF5);
  static const Color statusReturnedText = Color(0xFF059669);
  static const Color statusReturnedDarkBg = Color(0xFF064E3B);

  // Disputed (Orange)
  static const Color statusDisputedBg = Color(0xFFFFF7ED);
  static const Color statusDisputedText = Color(0xFFEA580C);
  static const Color statusDisputedDarkBg = Color(0xFF431407);

  // Cancelled & Expired (Gray)
  static const Color statusMutedBg = Color(0xFFF1F5F9);
  static const Color statusMutedText = Color(0xFF64748B);
  static const Color statusMutedDarkBg = Color(0xFF334155);
}
