/// SO'NGGI ISHLAR TASMASI — Hive keshidagi oxirgi 4 huquqiy javob.
///
/// TO'RT O'ZGARISH VA SABABLARI:
///
/// 1. O'LCHANGAN AA DEFEKTI (matn, 11 px yarim qalin — "large text" EMAS):
///    "Qonuniy asos: N" yozuvi `emeraldDark` (#059669) edi va OQ karta ustida
///    3.77:1 berardi (talab 4.5:1). Endi `AppTone.success.on()` — yorug'da
///    `emeraldStrong` #065F46 = 7.68:1.
///
/// 2. O'LCHANGAN AA DEFEKTI (qorong'i mavzu): kategoriya chipi, "O'qish"
///    yorlig'i va "Barchasi" havolasi `indigo` (#6366F1) edi va `cardDark`
///    (#1E293B) ustida 3.27:1 berardi. Endi `AppTone.accentIndigo.on()` —
///    qorong'ida `indigoOnTintDark` #A5B4FC = 7.34:1, yorug'da `indigoDark`
///    #4F46E5 = 6.29:1.
///
/// 3. SARLAVHA QATORI qo'lda qurilmaydi. Ilgari shu faylda 4×16 tayoqcha va
///    `TextButton` qo'lda yozilgan edi — ilovadagi boshqa bo'limlardan
///    farq qilardi. Endi `SectionHeader` (`section_header.dart`).
///
/// 4. JIM `catch (_) {}` OLIB TASHLANDI (§13). Buzilgan bitta kesh yozuvi
///    butun Bosh sahifani yiqitmasligi kerak, shuning uchun yozuv baribir
///    O'TKAZIB YUBORILADI — lekin sabab endi debug log'da KO'RINADI, ya'ni
///    kesh formati buzilganini kimdir sezadi.
///
/// O'ZGARMAGAN: Hive `Box<String>` o'qilishi, `ValueListenableBuilder`,
/// saralash (yangi → eski), `take(4)`, bo'sh holatda `SizedBox.shrink()` va
/// ikkita navigatsiya (`SavedCasesPage`, `RecentCaseDetailPage`).
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/di/injection_container.dart';
import 'package:lexhub/core/localization/category_labels.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/app_dimens.dart';
import 'package:lexhub/core/theme/modern_container.dart';
import 'package:lexhub/core/theme/section_header.dart';
import 'package:lexhub/core/theme/status_badge.dart';
import 'package:lexhub/core/theme/tone.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_response.dart';
import 'package:lexhub/features/legal_assistant/presentation/widgets/action_steps_timeline.dart';
import 'package:lexhub/features/legal_assistant/presentation/widgets/emergency_banner_widget.dart';
import 'package:lexhub/features/legal_assistant/presentation/widgets/legal_basis_accordion.dart';
import 'package:lexhub/features/legal_assistant/presentation/widgets/relatable_summary_card.dart';
import 'package:lexhub/features/legal_assistant/presentation/widgets/risk_matrix_gauge.dart';
import 'package:lexhub/features/saved_cases/presentation/pages/saved_cases_page.dart';

class RecentCasesFeed extends StatelessWidget {
  const RecentCasesFeed({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final box = sl<Box<String>>();

    return ValueListenableBuilder<Box<String>>(
      valueListenable: box.listenable(),
      builder: (context, b, _) {
        final List<LegalResponse> cases = [];
        for (final key in b.keys) {
          final raw = b.get(key);
          if (raw != null) {
            try {
              final map = jsonDecode(raw) as Map<String, dynamic>;
              cases.add(LegalResponse.fromJson(map));
            } catch (e) {
              // Yozuv O'TKAZIB YUBORILADI (bitta buzilgan kesh yozuvi butun
              // Bosh sahifani yiqitmaydi), lekin JIM YUTILMAYDI: kesh
              // sxemasi mos kelmayotgani debug log'da qoladi.
              if (kDebugMode) {
                debugPrint('[recent-cases] kesh yozuvi o\'qilmadi ($key): $e');
              }
            }
          }
        }

        if (cases.isEmpty) {
          return const SizedBox.shrink();
        }

        // Yangi → eski.
        cases.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final recentCases = cases.take(4).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: l10n.recentCasesTitle,
              actionLabel: l10n.recentCasesSeeAll(cases.length),
              onAction: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SavedCasesPage(),
                  ),
                );
              },
            ),
            const Gap(AppSpacing.md),
            // BALANDLIK 154 SAQLANDI, lekin endi asoslangan. Ichki `padding`
            // 12×2 = 24. Fiksatsiyalangan qismlar `textScaleFactor` 2.0 da:
            // chip qatori 22 + gap 6 + futer 22 + gap 6 = 56. Ya'ni ikki
            // qatorli matnga 154 − 24 − 56 = 74 px qoladi, kerak esa
            // 2 × 11 × 1.35 × 2.0 = 59.4 px — sig'adi, "BOTTOM OVERFLOWED"
            // chiqmaydi.
            SizedBox(
              height: 154,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recentCases.length,
                separatorBuilder: (_, __) => const Gap(AppSpacing.md),
                itemBuilder: (context, index) {
                  return _RecentCaseCard(item: recentCases[index]);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Bitta so'nggi ish kartasi.
///
/// Alohida widget qilingani — `ListView.separated` ichida `itemBuilder`
/// har aylantirishda qayta chaqiriladi va `const` bo'lmagan uzun `build`
/// tanasi shu yerda izolyatsiya qilinadi. Bosish reaksiyasini
/// `ModernContainer` o'zi beradi (`_PressableCard`).
class _RecentCaseCard extends StatelessWidget {
  const _RecentCaseCard({required this.item});

  final LegalResponse item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    final dateStr = DateFormat('dd.MM • HH:mm').format(item.createdAt);
    final displayQuery =
        item.userQuery.isNotEmpty ? item.userQuery : item.relatableSummary;

    return SizedBox(
      width: 270,
      child: ModernContainer(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RecentCaseDetailPage(response: item),
            ),
          );
        },
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Kategoriya chipi endi qo'lda qurilmaydi: `StatusBadge` matn
                // rangini `AppTone` dan oladi va u O'LCHANGAN.
                Flexible(
                  child: StatusBadge(
                    label: homeCategoryLabel(l10n, item.category),
                    tone: AppTone.accentIndigo,
                    dense: true,
                  ),
                ),
                const Gap(AppSpacing.xxs),
                Text(
                  dateStr,
                  style: TextStyle(
                    // XOM 10.5 → 11: kasrli o'lcham shkalada yo'q va past DPI
                    // ekranda xiralashadi. Kontrast: `textMutedLight` #64748B
                    // oq ustida 4.76:1, `textMutedDark` #94A3B8 `cardDark`
                    // ustida 5.71:1 — ikkisi ham AA'dan o'tadi.
                    color: isDark
                        ? AppColors.textMutedDark
                        : AppColors.textMutedLight,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const Gap(AppSpacing.xs),
            Expanded(
              child: Text(
                displayQuery,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
            const Gap(AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.legalBasisCount(item.legalBasis.length),
                  style: TextStyle(
                    color: AppTone.success.on(isDark),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      l10n.actionRead,
                      style: TextStyle(
                        color: AppTone.accentIndigo.on(isDark),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Gap(2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: AppIconSize.xs,
                      color: AppTone.accentIndigo.on(isDark),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class RecentCaseDetailPage extends StatelessWidget {
  final LegalResponse response;

  const RecentCaseDetailPage({super.key, required this.response});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.recentCaseDetailTitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (response.emergencyProtocol != null &&
                response.emergencyProtocol!.isEmergency) ...[
              EmergencyBannerWidget(protocol: response.emergencyProtocol!),
              const Gap(AppSpacing.lg),
            ],
            RelatableSummaryCard(
              summary: response.relatableSummary,
              source: response.source,
            ),
            const Gap(AppSpacing.lg),
            ActionStepsTimeline(steps: response.actionableSteps),
            const Gap(AppSpacing.lg),
            LegalBasisAccordion(articles: response.legalBasis),
            const Gap(AppSpacing.lg),
            RiskMatrixGauge(assessment: response.riskAssessment),
            const Gap(AppSpacing.bottomSafe),
          ],
        ),
      ),
    );
  }
}


