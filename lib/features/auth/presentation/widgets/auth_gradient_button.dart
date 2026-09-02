import 'package:flutter/material.dart';
import 'package:lexhub/core/constants/app_colors.dart';

class AuthGradientButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  const AuthGradientButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          // O'LCHANGAN DEFEKT: gradientning O'NG chekkasi XOM `indigo` edi —
          // yorliq oq, 16 px w700, ya'ni KATTA matn EMAS (bold chegara
          // 18.66 px), demak AA 4.5:1 talab qiladi. Oq/`indigo` = 4.47:1 —
          // ilovaning ASOSIY auth tugmasi (Kirish / Ro'yxatdan o'tish)
          // chegaradan PASTDA edi. `indigoDark` bilan 6.29:1; chap chekka
          // `primary` allaqachon 17.85:1. Brend gradienti ko'zga bir xil
          // ko'rinadi, faqat bir qadam quyuqroq.
          colors: onPressed == null || isLoading
              ? [Colors.grey.shade400, Colors.grey.shade500]
              : [AppColors.primary, AppColors.indigoDark],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: onPressed == null || isLoading
            ? []
            : [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
