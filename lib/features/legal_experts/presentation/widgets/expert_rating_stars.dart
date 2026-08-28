/// REYTING YULDUZLARI — advokat bahosining vizual ko'rinishi.
///
/// ── §6 HALOLLIK QOIDASI ──
/// Bu widget FAQAT `reviewsCount > 0` bo'lganda chaqirilishi kerak. Baho
/// yo'q advokatga "☆☆☆☆☆" ko'rsatish "0 ball" degan SOXTA da'vo bo'ladi —
/// bazada esa umuman baho YO'Q. Chaqiruvchi shartni o'zi tekshiradi
/// (`expert_card_widget.dart`, `expert_profile_modal.dart`).
///
/// ── O'LCHANGAN RANG ──
/// Yulduzlar `AppTone.warning.on(isDark)`: yorug' `amberOnTint`, qorong'i
/// `amberOnTintDark`. Bu qiymatlar alfa 0.00→0.20 bandida (ya'ni oddiy karta
/// va sahifa foni ham ichida) min 5.86:1 / 7.07:1 beradi. Ilgari loyihada
/// yulduz `amber` (#F59E0B) ning O'ZIDA edi — oq karta ustida 2.15:1, WCAG
/// 1.4.11 grafik minimumidan (3:1) past.
///
/// ── EKRAN O'QUVCHISI ──
/// Yulduzlar `ExcludeSemantics` ichida: AYNI ma'lumot yonidagi raqamli matnda
/// ("4.8" + "12 ta baho") allaqachon bor, ya'ni yulduzlarni ham o'qish
/// takrorlanish bo'ladi.
library;

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/app_dimens.dart';
import 'package:lexhub/core/theme/tone.dart';

class ExpertRatingStars extends StatelessWidget {
  /// Bazadan kelgan baho (0..5). Yaxlitlanmaydi — yarim yulduz ko'rsatiladi.
  final double rating;

  /// Baho SONI. 0 bo'lsa bu widget umuman chizilmaydi (§6).
  final int reviewsCount;

  /// Kichik o'lchov — karta ichida ishlatiladi.
  final bool dense;

  const ExpertRatingStars({
    super.key,
    required this.rating,
    required this.reviewsCount,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    if (reviewsCount <= 0) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;
    final Color starColor = AppTone.warning.on(isDark);
    final double starSize = dense ? AppIconSize.xs : AppIconSize.sm;
    // Band chegarasi: bazadan 5 dan katta yoki manfiy qiymat kelsa ham
    // yulduzlar soni 5 dan oshmaydi.
    final double clamped = rating.clamp(0.0, 5.0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List<Widget>.generate(5, (int index) {
              final double filled = clamped - index;
              final IconData icon = filled >= 0.75
                  ? Icons.star_rounded
                  : filled >= 0.25
                      ? Icons.star_half_rounded
                      : Icons.star_outline_rounded;
              return Padding(
                padding: EdgeInsets.only(right: index == 4 ? 0 : 1),
                child: Icon(icon, size: starSize, color: starColor),
              );
            }),
          ),
        ),
        const Gap(AppSpacing.xs),
        Text(
          clamped.toStringAsFixed(1),
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: dense ? 11 : 13,
            color: starColor,
          ),
        ),
        const Gap(AppSpacing.xs),
        Text(
          l10n.expertMetricReviews(reviewsCount),
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: dense ? 11 : 12,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }
}
