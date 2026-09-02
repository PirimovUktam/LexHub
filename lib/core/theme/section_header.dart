/// BO'LIM SARLAVHASI — "nom + Barchasi ›" qatorining YAGONA manbasi.
///
/// NIMA UCHUN: bu qator ilovada kamida 6 joyda qo'lda takrorlangan
/// (`recent_cases_feed`, `home_page` hamjamiyat bloki, `faq_questions_page`,
/// ...) va har biri boshqacha edi — biri `TextButton.icon`, biri oddiy
/// `TextButton`, uchinchisi umuman havolasiz. Natijada bir ekranda bo'limlar
/// bir-biriga o'xshamasdi.
///
/// MATN YO'Q: barcha satrlar chaqiruvchidan (`context.l10n.*`) keladi —
/// shuning uchun bu fayl `no_hardcoded_ui_strings_test` ZONA A talabini
/// avtomatik qanoatlantiradi.
library;

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/theme/app_dimens.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  /// Bo'lim nomi — ARB'dan keladi.
  final String title;

  /// Ixtiyoriy izoh (masalan maxfiylik eslatmasi).
  final String? subtitle;

  /// "Barchasi" kabi havola matni. `null` bo'lsa havola CHIQMAYDI —
  /// bosilganda hech narsa qilmaydigan tugma ko'rsatilmaydi.
  final String? actionLabel;

  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // DEKORATIV chizib qo'yilgan tayoqcha — ma'no tashimaydi, shuning uchun
    // aksentning O'ZIDA qoladi (`indigo` #6366F1 `backgroundDark` ustida
    // 3.94:1, ya'ni WCAG 1.4.11 grafik talabidan (3:1) o'tadi).
    final Color barAccent = isDark ? AppColors.indigo : AppColors.primary;

    // O'LCHANGAN TUZATISH: havola MATNI ilgari ham `indigo` edi va qorong'i
    // mavzuda 3.94:1 (fon) / 3.27:1 (karta ustida) berardi — 12 px yarim
    // qalin matn uchun bu WCAG AA (4.5:1) dan PAST. Endi qorong'ida
    // `indigoOnTintDark` (#A5B4FC): 8.83:1 fon, 7.34:1 karta ustida.
    // Yorug'da `primary` (#0F172A) 17.85:1 — o'zgarmadi.
    // Bu sarlavha 6+ bo'limda ishlatiladi, ya'ni tuzatish bir joyda.
    final Color linkAccent =
        isDark ? AppColors.indigoOnTintDark : AppColors.primary;
    final showAction = actionLabel != null && onAction != null;

    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: barAccent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const Gap(AppSpacing.sm),
        // `Expanded` SHART: ingliz tilidagi sarlavha o'zbekchadan uzunroq
        // bo'ladi va katta shrift masshtabida "Barchasi" tugmasi bilan
        // to'qnashib overflow berardi.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        if (showAction)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Row(
              children: [
                Text(
                  actionLabel!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: linkAccent,
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: AppIconSize.sm, color: linkAccent),
              ],
            ),
          ),
      ],
    );
  }
}
