import 'package:flutter/material.dart';
import 'package:lexhub/core/constants/app_colors.dart';

class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hintText,
    required this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
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
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(
            fontSize: 15,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            // O'LCHANGAN DEFEKT: hint (placeholder) — WCAG bo'yicha MATN, ya'ni
            // 14 px uchun talab 4.5:1. `Colors.white30` maydon foni `cardDark`
            // ustida aralashib #626976 beradi — 2.65:1; `Colors.black26` esa
            // yorug' maydon (#F8FAFC) ustida #B8B9BA — 1.88:1. Ikkisi ham AA'dan
            // ANIQ past edi ("Ismingizni kiriting", "misol@email.com" kabi
            // yo'riqnomalar deyarli o'qilmasdi). Mavzuning ikkilamchi matn
            // tokeni: qorong'i 9.85:1, yorug' 7.24:1 — kiritilgan matn
            // (13.98 / 17.06) bilan ierarxiya farqi saqlanadi.
            hintStyle: TextStyle(
              fontSize: 14,
              color:
                  isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
            prefixIcon: Icon(
              prefixIcon,
              size: 20,
              color: isDark ? AppColors.indigoLight : AppColors.primary,
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: isDark ? AppColors.cardDark : const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            // 1.4.11 (3:1): `borderDark`/`borderLight` maydon foni ustida
            // 1.41 / 1.18:1 berardi — kontur KO'RINMAS darajada zaif edi.
            // Mavzu bilan bir xil `borderStrong*` juftligi: 3.36 / 3.30:1.
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark
                    ? AppColors.borderStrongDark
                    : AppColors.borderStrongLight,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark
                    ? AppColors.borderStrongDark
                    : AppColors.borderStrongLight,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? AppColors.indigo : AppColors.primary,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.crimson),
            ),
          ),
        ),
      ],
    );
  }
}
