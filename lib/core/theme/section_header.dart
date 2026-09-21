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

    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3)),
        if (subtitle case final text?) ...[
          const Gap(AppSpacing.xxs),
          Text(text, style: theme.textTheme.bodySmall),
        ],
      ],
    );
    final action = actionLabel;
    final link = action != null && onAction != null
        ? TextButton.icon(
            onPressed: onAction,
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.arrow_forward_rounded, size: AppIconSize.sm),
            label: Text(action),
            style: TextButton.styleFrom(
              foregroundColor:
                  isDark ? AppColors.indigoOnTintDark : AppColors.indigoDark,
              minimumSize: const Size(48, 48),
            ),
          )
        : null;
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 360 ||
          MediaQuery.textScalerOf(context).scale(16) > 22) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [heading, if (link != null) link],
        );
      }
      return Row(children: [Expanded(child: heading), if (link != null) link]);
    });
  }
}
