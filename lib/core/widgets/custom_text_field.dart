import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class CustomTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final String? initialValue;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final int maxLines;
  final TextInputType keyboardType;
  final bool readOnly;
  final bool obscureText;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;

  const CustomTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.initialValue,
    this.suffixIcon,
    this.prefixIcon,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.readOnly = false,
    this.obscureText = false,
    this.onTap,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          initialValue: initialValue,
          maxLines: maxLines,
          keyboardType: keyboardType,
          readOnly: readOnly,
          obscureText: obscureText,
          onTap: onTap,
          onChanged: onChanged,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            fillColor: isDark ? AppColors.darkSurface : AppColors.lightCardSubtle.withOpacity(0.6),
          ),
        ),
      ],
    );
  }
}
