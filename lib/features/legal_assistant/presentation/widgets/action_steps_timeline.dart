/// HARAKAT QADAMLARI TIMELINE'i — foydalanuvchi bajarganini belgilab boradi.
///
/// MA'LUMOT SOXTA EMAS: qadamlar `LegalResponse.actionableSteps` dan keladi.
/// Foizli ko'rsatkich ham SOXTA ANIQLIK EMAS — u foydalanuvchi O'ZI belgilagan
/// qadamlar ulushi (`completedCount / totalCount`), model bahosi emas.
///
/// ── BATCH 3 (dizayn brifi §3.3) — BEShTA O'LCHANGAN TUZATISH ──
///
/// 1. SARLAVHA IKONKASI o'z aksentining tinti ustida edi: `emerald` (#10B981)
///    `emerald@0.12`/`@0.20` ustida — o'lchov (alfa 0.00→0.20, to'rt yuza)
///    ENG YOMON 2.02:1 berdi, WCAG 1.4.11 grafik obyekt uchun 3:1 talab
///    qiladi. Endi `AppTone.success.on()`: 6.12:1 / 5.41:1.
///
/// 2. PROGRESS SUBTITRI VA FOIZ BELGISI matn edi (11–12 px yarim qalin =
///    "large text" EMAS, ya'ni 4.5:1 kerak). `emeraldDark` (#059669) oq karta
///    ustida 3.77:1, `emeraldLight` tint ustida 3.32:1 — IKKISI HAM PAST.
///    Endi subtitr `AppTone.success.on()`, foiz esa `StatusBadge` (u fonni va
///    matn rangini AYNI `AppTone` dan oladi, 11 px shrift poliga ega).
///
/// 3. PROGRESS BAR to'ldirishi `emerald` edi va yo'lakcha (`borderLight`)
///    ustida 2.06:1 berardi — holat ko'rsatkichi uchun 1.4.11 bo'yicha 3:1
///    kerak. `AppTone.success.on()`: yorug' 6.23:1, qorong'i 5.39:1.
///
/// 4. TUGUN RANGLARI. Ilgari tugallangan tugun `emerald` + OQ belgi = 2.54:1
///    va qorong'i mavzuda tugallanmagan tugun `indigo` + OQ raqam = 4.47:1
///    edi. Endi to'rt holat ham o'lchangan:
///      • yorug', tugallanmagan: `primary` fon + oq raqam 17.85:1 (qirra 17.85)
///      • yorug', tugallangan:  `emeraldStrong` + oq belgi 7.68:1 (qirra 7.68)
///      • qorong'i, tugallanmagan: `indigoOnDark` + `primary` raqam 5.98:1
///        (qirra `cardDark` ga nisbatan 4.90:1)
///      • qorong'i, tugallangan: `emeraldOnDark` + `primary` belgi 9.29:1
///        (qirra 7.61:1)
///    Ya'ni yorug'da "to'q fon + oq matn", qorong'ida "yorqin fon + to'q
///    matn" — har ikkisi ham o'z kartasida ajralib turadi.
///
/// 5. BOSISH MAYDONI 30 px edi. Endi tugun 44 px `SizedBox` ichida (aylana
///    o'lchami 30 px qoldi, ya'ni ko'rinish o'zgarmadi) va `AnimatedContainer`
///    davomiyligi `AppMotion.of` orqali — "reduce motion" yoqilganda
///    animatsiya BUTUNLAY o'chadi (ilgari qat'iy 250 ms edi).
///
/// O'ZGARMAGAN: `_completedStepIndices` mantiqi, `_toggleStep`, matnning
/// `lineThrough` bo'lishi, `shrinkWrap` + `NeverScrollableScrollPhysics`
/// (ota `SingleChildScrollView` ichida) va `steps.isEmpty` holati.
library;

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/app_dimens.dart';
import 'package:lexhub/core/theme/depth.dart';
import 'package:lexhub/core/theme/modern_container.dart';
import 'package:lexhub/core/theme/status_badge.dart';
import 'package:lexhub/core/theme/tone.dart';

class ActionStepsTimeline extends StatefulWidget {
  final List<String> steps;

  const ActionStepsTimeline({
    super.key,
    required this.steps,
  });

  @override
  State<ActionStepsTimeline> createState() => _ActionStepsTimelineState();
}

class _ActionStepsTimelineState extends State<ActionStepsTimeline> {
  final Set<int> _completedStepIndices = {};

  void _toggleStep(int index) {
    setState(() {
      if (_completedStepIndices.contains(index)) {
        _completedStepIndices.remove(index);
      } else {
        _completedStepIndices.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;
    final steps = widget.steps;

    if (steps.isEmpty) return const SizedBox.shrink();

    final completedCount = _completedStepIndices.length;
    final totalCount = steps.length;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

    return ModernContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Progress
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppTone.success.bg(isDark),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  Icons.playlist_add_check_circle_rounded,
                  // 1-BAND: ilgari `emerald` o'z tinti ustida 2.02:1 edi.
                  color: AppTone.success.on(isDark),
                  size: AppIconSize.sm,
                ),
              ),
              const Gap(AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.aiStepsTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      l10n.aiStepsProgress(completedCount, totalCount),
                      style: theme.textTheme.bodySmall?.copyWith(
                        // 2-BAND: `emeraldDark` oq karta ustida 3.77:1 edi.
                        color: AppTone.success.on(isDark),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(AppSpacing.xs),
              // FOIZ BELGISI — qo'lda qurilgan `Container` o'rniga `StatusBadge`:
              // fon, chegara va matn rangi ayni `AppTone.success` dan keladi va
              // 11 px shrift poli qulflangan. Matn — raqam, tarjima kerak emas.
              StatusBadge(
                label: '${(progress * 100).toInt()}%',
                tone: AppTone.success,
                dense: true,
              ),
            ],
          ),

          const Gap(AppSpacing.md),

          // Linear Progress indicator
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xs),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: isDark ? AppColors.borderDark : AppColors.borderLight,
              // 3-BAND: `emerald` yo'lakcha ustida 2.06:1 edi (3:1 kerak).
              valueColor: AlwaysStoppedAnimation<Color>(
                AppTone.success.on(isDark),
              ),
              minHeight: 5,
            ),
          ),

          const Gap(AppSpacing.lg),

          // Interactive Steps Timeline List
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: steps.length,
            itemBuilder: (context, index) {
              final isCompleted = _completedStepIndices.contains(index);
              final isLast = index == steps.length - 1;
              final stepNumber = index + 1;

              // 4-BAND: to'rt holatning HAR BIRI o'lchangan. Qoida —
              // yorug'da to'q fon + oq belgi, qorong'ida yorqin fon + to'q
              // belgi. Shunda tugun O'Z kartasida ham ajralib turadi.
              final Color nodeBg = isCompleted
                  ? (isDark ? AppColors.emeraldOnDark : AppColors.emeraldStrong)
                  : (isDark ? AppColors.indigoOnDark : AppColors.primary);
              final Color nodeFg =
                  isDark ? AppColors.primary : Colors.white;

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Timeline Node + Connecting Line
                    Column(
                      children: [
                        InkWell(
                          onTap: () => _toggleStep(index),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          child: SizedBox(
                            // 5-BAND: bosish maydoni 30 → 44 px. Material
                            // minimumi 48, lekin tugun IKKILAMCHI boshqaruv:
                            // ayni qadamning MATNI ham bosiladi va u kengroq.
                            width: 44,
                            height: 44,
                            child: Center(
                              child: AnimatedContainer(
                                // "Reduce motion" yoqilganda `Duration.zero`.
                                duration: AppMotion.of(context, AppMotion.base),
                                curve: AppMotion.curve,
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: nodeBg,
                                  shape: BoxShape.circle,
                                  boxShadow: AppShadows.glow(nodeBg, alpha: 0.25),
                                ),
                                child: Center(
                                  child: isCompleted
                                      ? Icon(
                                          Icons.check_rounded,
                                          color: nodeFg,
                                          size: AppIconSize.xs + 4,
                                        )
                                      : Text(
                                          '$stepNumber',
                                          style: TextStyle(
                                            color: nodeFg,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 2,
                              margin: const EdgeInsets.symmetric(
                                vertical: AppSpacing.xxs,
                              ),
                              color: isCompleted
                                  ? nodeBg.withValues(alpha: 0.5)
                                  : (isDark ? AppColors.borderDark : AppColors.borderLight),
                            ),
                          ),
                      ],
                    ),

                    const Gap(AppSpacing.sm),

                    // Step Content
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          bottom: isLast ? 0 : AppSpacing.md,
                        ),
                        child: InkWell(
                          onTap: () => _toggleStep(index),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          child: Padding(
                            // Tugun 44 px bo'lgani uchun matn endi vertikal
                            // markazga yaqinlashtiriladi: 30 px aylananing
                            // yuqori qirrasi 7 px pastda turadi.
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.sm + 1,
                            ),
                            child: Text(
                              steps[index],
                              style: theme.textTheme.bodyMedium?.copyWith(
                                decoration: isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: isCompleted
                                    ? (isDark ? AppColors.textMutedDark : AppColors.textMutedLight)
                                    : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                                fontWeight: isCompleted
                                    ? FontWeight.normal
                                    : FontWeight.w500,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
