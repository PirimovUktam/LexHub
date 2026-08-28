/// ANIQLASHTIRUVCHI SAVOLLAR KARTASI — javobni aniqlashtirish uchun taklif.
///
/// ── BATCH 3 (dizayn brifi §3.3) — TUZATISHLAR ──
///
/// 1. KARTA FONI SHAFFOFSIZ QILINDI. Ilgari `indigo@0.10` (qorong'i) va
///    `indigoLight@0.25` (yorug') edi — yarim shaffof fon ostidan SAHIFA foni
///    ko'rinadi, ya'ni o'lchangan kontrast karta qaysi ekranda turishiga
///    bog'liq bo'lardi. `Color.alphaBlend` ayni ko'rinishni qat'iy qiymat
///    sifatida beradi: yorug' #FBFCFF, qorong'i #252F4D. Yon foyda —
///    `ModernContainer` ning ichki gradienti yana yoqiladi (u faqat
///    shaffofsiz fonda ishlaydi).
///
/// 2. IKONKA VA SARLAVHA `indigo` (#6366F1) edi: yangi fonlar ustida o'lchov
///    yorug'da 3.32:1, qorong'ida 2.64:1 — matn uchun 4.5:1, grafik uchun
///    3:1 kerak. Endi `AppTone.accentIndigo.on()`: yorug' `indigoDark`
///    (#4F46E5) 6.13:1, qorong'i `indigoOnTintDark` (#A5B4FC) 6.62:1.
///
/// 3. SAVOL QATORLARI BOSILADIGAN, ya'ni WCAG 1.4.11 bo'yicha ular
///    KO'RINADIGAN chegaraga ega bo'lishi kerak. Ilgari chegara `borderDark`
///    edi va yangi karta foni ustida 1.27:1 berardi. Endi chegara ayni
///    aksentda (6.13:1 / 6.62:1) va qator balandligi 48 px ga yetkazildi
///    (ilgari ~40 px — Material minimumidan past).
library;

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/app_dimens.dart';
import 'package:lexhub/core/theme/modern_container.dart';
import 'package:lexhub/core/theme/tone.dart';

class AiClarificationCard extends StatelessWidget {
  final List<String> questions;
  final ValueChanged<String>? onQuestionTapped;

  const AiClarificationCard({
    super.key,
    required this.questions,
    this.onQuestionTapped,
  });

  @override
  Widget build(BuildContext context) {
    if (questions.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;
    final Color onAccent = AppTone.accentIndigo.on(isDark);

    return ModernContainer(
      padding: const EdgeInsets.all(AppSpacing.lg),
      // 1-BAND: shaffof fon → qat'iy qiymat (#252F4D / #FBFCFF).
      backgroundColor: isDark
          ? Color.alphaBlend(
              AppColors.indigo.withValues(alpha: 0.1),
              AppColors.cardDark,
            )
          : Color.alphaBlend(
              AppColors.indigoLight.withValues(alpha: 0.25),
              AppColors.cardLight,
            ),
      borderColor: AppTone.accentIndigo.border(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppTone.accentIndigo.bg(isDark),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Icon(
                  Icons.help_outline_rounded,
                  color: onAccent,
                  size: AppIconSize.sm,
                ),
              ),
              const Gap(AppSpacing.md),
              Expanded(
                child: Text(
                  l10n.aiClarificationTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    // O'LCHOV: yorug'da `primary` yangi fon ustida 17.40:1,
                    // qorong'ida `indigoOnTintDark` 6.62:1.
                    color: isDark ? onAccent : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const Gap(AppSpacing.md),
          Text(
            l10n.aiClarificationBody,
            style: theme.textTheme.bodySmall?.copyWith(
              height: 1.4,
              // O'LCHOV: `textSecondaryLight` #FBFCFF ustida 7.39:1,
              // `textSecondaryDark` #252F4D ustida 8.88:1.
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          const Gap(AppSpacing.md),
          Column(
            children: questions.map((q) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: InkWell(
                  onTap: () => onQuestionTapped?.call(q),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  child: Container(
                    // 3-BAND: 48 px minimal bosish balandligi.
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      // Qorong'ida `surfaceDark` — karta fonidan PASTROQ,
                      // ya'ni qator "botgan maydon" bo'lib ko'rinadi.
                      color: isDark ? AppColors.surfaceDark : AppColors.cardLight,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                      border: Border.all(color: onAccent),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.arrow_right_rounded,
                            color: onAccent, size: AppIconSize.sm),
                        const Gap(AppSpacing.xs),
                        Expanded(
                          child: Text(
                            q,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(Icons.add_circle_outline_rounded,
                            size: AppIconSize.xs + 2, color: onAccent),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
