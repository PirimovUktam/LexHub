/// XATAR O'LCHAGICHI — 4 bosqichli vizual shkala.
///
/// ── BATCH 3 (dizayn brifi §3.3) — TUZATISHLAR ──
///
/// A. SOXTA ANIQLIK OLIB TASHLANDI (§6 "fake claim qilma"). Ilgari bu widget
///    "25% / 55% / 80% / 100%" ko'rsatardi. Bu raqamlar HECH QAYERDAN
///    o'lchanmagan: `_getRiskProgress()` ularni 4 qiymatli `RiskLevel`
///    enum'idan QO'LDA xaritalagan edi. Foydalanuvchi esa "80%" ni haqiqiy
///    hisob-kitob deb o'qiydi. Endi foiz KO'RSATILMAYDI — o'rniga to'rt
///    segmentli shkala va `riskLevelLabel` (ya'ni aynan enum qiymati).
///
/// B. DOC CLAIM TUZATILDI: eski izohda "win-rate factors" deb yozilgan edi,
///    lekin `RiskAssessment` da bunday maydon YO'Q (`level`, `summary`,
///    `limitations`, `requiresLawyer`, `deadlineDays`). Isbotsiz da'vo
///    o'chirildi.
///
/// C. O'LCHANGAN KONTRAST DEFEKTLARI (WCAG 2.1). Ilgari HAMMA element
///    `riskColor` NING O'ZIDA bo'lib, AYNI rangning tinti ustida turardi:
///      • ikonka/badge/foiz: emerald 2.02:1, amber 1.78:1, crimson 2.78:1,
///        purple 3.81:1 (yorug') / 2.35:1 (qorong'i) — matn uchun 4.5:1,
///        grafik uchun 3:1 kerak;
///      • progress bar to'ldirishi yo'lakcha ustida 2.06:1;
///      • muddat yorlig'i `amberDark` + `amberLight` = 2.86:1;
///      • advokat ogohlantirishi `crimsonDark` + `crimsonLight` = 3.95:1;
///      • shkala yorliqlari 10 px (loyihadagi 11 px polidan past).
///    Endi rang tanlash `AppTone` ga topshirildi: `on()` qiymatlari
///    success 6.12/5.41, warning 5.86/7.07, danger 4.78/6.38,
///    critical 6.18/7.16; segment to'ldirishi yo'lakcha ustida 5.25–7.07.
///
/// O'ZGARMAGAN: `assessment` maydonlari, `deadlineDays` sharti,
/// `limitations` ro'yxati va `requiresLawyer` ogohlantirishi mantiqi.
library;

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/localization/legal_ai_labels.dart';
import 'package:lexhub/core/theme/app_dimens.dart';
import 'package:lexhub/core/theme/modern_container.dart';
import 'package:lexhub/core/theme/status_badge.dart';
import 'package:lexhub/core/theme/tone.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/risk_assessment.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/risk_level.dart';

class RiskMatrixGauge extends StatelessWidget {
  final RiskAssessment assessment;

  const RiskMatrixGauge({
    super.key,
    required this.assessment,
  });

  /// Bosqich → semantik rang jufti. `AppTone` ichida fon VA matn rangi
  /// birga keladi, ya'ni "aksentni matn qilib qo'yish" nuqsoni takrorlanmaydi.
  static AppTone _toneFor(RiskLevel level) {
    switch (level) {
      case RiskLevel.low:
        return AppTone.success;
      case RiskLevel.medium:
        return AppTone.warning;
      case RiskLevel.high:
        return AppTone.danger;
      case RiskLevel.critical:
        return AppTone.critical;
    }
  }

  /// Shkaladagi o'rin (0..3) — FOIZ EMAS, aynan enum tartibi.
  static int _slotFor(RiskLevel level) {
    switch (level) {
      case RiskLevel.low:
        return 0;
      case RiskLevel.medium:
        return 1;
      case RiskLevel.high:
        return 2;
      case RiskLevel.critical:
        return 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;
    final AppTone tone = _toneFor(assessment.level);
    final int activeSlot = _slotFor(assessment.level);
    final Color track = isDark ? AppColors.borderDark : AppColors.borderLight;
    // Shkala yorliqlari — tartib `RiskLevel.values` bilan AYNI bo'lishi shart.
    final List<String> scaleLabels = <String>[
      l10n.riskScaleLow,
      l10n.riskScaleMedium,
      l10n.riskScaleHigh,
      l10n.riskScaleCritical,
    ];

    return ModernContainer(
      borderColor: tone.border(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: tone.bg(isDark),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  Icons.shield_outlined,
                  // C-BAND: ilgari `riskColor` o'z tinti ustida — eng yomon
                  // 1.78:1 edi (grafik uchun 3:1 kerak).
                  color: tone.on(isDark),
                  size: AppIconSize.sm,
                ),
              ),
              const Gap(AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.aiRiskTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      l10n.aiRiskSubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(AppSpacing.xs),
              // Bosqich yorlig'i — matn rangi `AppTone` dan.
              StatusBadge(
                label: riskLevelLabel(l10n, assessment.level),
                tone: tone,
                dense: true,
              ),
            ],
          ),

          const Gap(AppSpacing.lg),

          // O'LCHAGICH — 4 SEGMENT. Foiz YO'Q (A-band): shkala aynan
          // `RiskLevel` ning to'rt qiymatini ko'rsatadi, ortiqcha aniqlik
          // qo'shmaydi. Faol bosqichgacha bo'lgan segmentlar to'ldiriladi.
          Text(
            l10n.aiRiskGaugeLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Gap(AppSpacing.sm),
          Row(
            children: List<Widget>.generate(4, (int slot) {
              final bool filled = slot <= activeSlot;
              final bool isActive = slot == activeSlot;
              final AppTone slotTone = _toneFor(RiskLevel.values[slot]);
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: slot == 3 ? 0 : AppSpacing.xxs,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // To'ldirilgan segment FAOL bosqich rangida — yo'lakcha
                      // ustida o'lchov 5.25–7.07:1 (1.4.11 uchun 3:1 kerak).
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: filled ? tone.on(isDark) : track,
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                        ),
                      ),
                      const Gap(AppSpacing.xs),
                      // Shkala yorliqlari: 10 px → 11 px va har biri O'Z
                      // bosqichining o'lchangan rangida.
                      Text(
                        scaleLabels[slot],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isActive ? FontWeight.w800 : FontWeight.w500,
                          color: isActive
                              ? slotTone.on(isDark)
                              : (isDark
                                  ? AppColors.textMutedDark
                                  : AppColors.textMutedLight),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),

          const Gap(AppSpacing.lg),

          // Summary explanation
          Text(
            assessment.summary,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),

          // Procedural Deadline Countdown Badge
          if (assessment.deadlineDays != null) ...[
            const Gap(AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm + 2,
              ),
              decoration: BoxDecoration(
                color: AppTone.warning.bg(isDark),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppTone.warning.border(isDark)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    // C-BAND: `amberDark` + `amberLight` = 2.86:1 edi.
                    color: AppTone.warning.on(isDark),
                    size: AppIconSize.sm,
                  ),
                  const Gap(AppSpacing.md),
                  Expanded(
                    child: Text(
                      l10n.aiDeadlineRemaining(assessment.deadlineDays ?? 0),
                      style: TextStyle(
                        color: AppTone.warning.on(isDark),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Limitations & Disclaimers
          if (assessment.limitations.isNotEmpty) ...[
            const Gap(AppSpacing.lg),
            Text(
              l10n.aiLimitationsTitle,
              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Gap(AppSpacing.xs),
            ...assessment.limitations.map(
              (limitation) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: AppIconSize.xs + 2,
                      color: AppTone.warning.on(isDark),
                    ),
                    const Gap(AppSpacing.sm),
                    Expanded(
                      child: Text(
                        limitation,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Mandatory Lawyer Alert (if critical or complex)
          if (assessment.requiresLawyer) ...[
            const Gap(AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppTone.danger.bg(isDark),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppTone.danger.border(isDark)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.gavel_rounded,
                    // C-BAND: `crimsonDark` + `crimsonLight` = 3.95:1 edi.
                    color: AppTone.danger.on(isDark),
                    size: AppIconSize.md,
                  ),
                  const Gap(AppSpacing.md),
                  Expanded(
                    child: Text(
                      l10n.aiLawyerRequiredWarning,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTone.danger.on(isDark),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
