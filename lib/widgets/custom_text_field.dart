import 'package:flutter/material.dart';
import '../config/theme.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;
  final bool readOnly;
  final VoidCallback? onTap;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          maxLines: maxLines,
          readOnly: readOnly,
          onTap: onTap,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: AppTheme.navy.withOpacity(0.6), size: 20)
                : null,
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}

/// Converts Arabic-Indic / Persian digits to ASCII and normalizes separators for parsing (C6):
/// `1,000` -> `1000`, `1,500.25` -> `1500.25`, `١٬٥٠٠` -> `1500`, `٢٫٥` -> `2.5`,
/// while a lone comma used as a decimal mark keeps working: `12,5` -> `12.5`.
String normalizeArabicDigits(String input) {
  const arabicIndic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  const easternArabic = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
  var result = input;
  for (int i = 0; i < 10; i++) {
    result = result.replaceAll(arabicIndic[i], i.toString());
    result = result.replaceAll(easternArabic[i], i.toString());
  }

  // '٬' (U+066C) is always the Arabic thousands separator
  result = result.replaceAll('٬', '');

  // Commas grouping exactly three digits are thousands separators, not a decimal point
  final grouped = RegExp(r'^[-+]?[1-9]\d{0,2}([,،]\d{3})+([.٫]\d+)?$');
  final trimmed = result.trim();
  if (grouped.hasMatch(trimmed)) {
    return trimmed.replaceAll(',', '').replaceAll('،', '').replaceAll('٫', '.');
  }

  return result.replaceAll('٫', '.').replaceAll('،', '.').replaceAll(',', '.');
}

