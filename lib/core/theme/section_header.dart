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
    final accent = isDark ? AppColors.indigo : AppColors.primary;
    final showAction = actionLabel != null && onAction != null;

    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: accent,
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
                    color: accent,
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: AppIconSize.sm, color: accent),
              ],
            ),
          ),
      ],
    );
  }
}
