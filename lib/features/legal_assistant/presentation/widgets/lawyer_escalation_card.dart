/// AI -> ADVOKAT ESKALATSIYA KARTASI.
///
/// ── NIMA UCHUN BU WIDGET BOR ──
///
/// Auditda o'lchangan UZILISH (mahsulotning eng qimmat bo'g'ini):
///   * quvur `RiskAssessment.requiresLawyer = true` ni ishonchli beradi —
///     qamrovdan tashqari HAR BIR savol uchun `_applyCoverageHonesty`
///     uni MAJBURAN `true` qiladi
///     (`legal_assistant_remote_datasource.dart`);
///   * UI esa buni FAQAT qizil `Container` + matn bo'lib ko'rsatardi
///     (`risk_matrix_gauge.dart:296`) — ichida `onPressed` YO'Q;
///   * `LegalExpertsPage` ga kirish faqat `quick_access_grid.dart:91` va
///     `search_page.dart:601` da bor.
/// Natijada tizim "sizga advokat kerak" degan AYNI joyda foydalanuvchi
/// boshi berk ko'chaga kelardi: na havola, na tugma, na yo'nalish.
///
/// Bu karta shu bo'g'inni yopadi. Xatar o'lchagichi FAKTNI aytadi
/// ("mustaqil harakat xavfli"), bu karta esa YO'LNI beradi — shuning uchun
/// ikkisi ATAYLAB har xil tonda: `danger` (holat) va `accentIndigo`
/// (keyingi qadam). Ikki qizil blok ketma-ket kelsa ogohlantirish ham,
/// harakat ham kuchini yo'qotadi.
///
/// ── HALOLLIK CHEGARALARI ──
///
/// 1. YO'NALISH TAXMIN QILINMAYDI. `LawyerSpecializationMatcher` `null`
///    qaytarsa karta buni OSHKORA yozadi va ro'yxatni FILTRSIZ ochadi.
///    Soxta "sizga aynan mos advokat topildi" da'vosi YO'Q.
/// 2. ADVOKAT BORLIGI KAFOLATLANMAYDI. Karta faqat tasdiqlangan advokatlar
///    ro'yxatini ochadi; ro'yxat bo'sh bo'lsa `LegalExpertsPage` o'zining
///    empty state'ini ko'rsatadi (`expertsEmptyFiltered`) — bu yerda
///    to'qima advokat KO'RSATILMAYDI.
/// 3. `isMandatory` FAQAT `UncoveredTopic.isHardStop` dan keladi, ya'ni
///    "majburiy" so'zi o'lchangan qoidaga tayanadi, kartaning o'z
///    taxminiga emas.
library;

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/legal_safety/lawyer_specialization_matcher.dart';
import 'package:lexhub/core/localization/expert_labels.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/app_dimens.dart';
import 'package:lexhub/core/theme/modern_container.dart';
import 'package:lexhub/core/theme/tone.dart';
import 'package:lexhub/features/legal_experts/presentation/pages/legal_experts_page.dart';

class LawyerEscalationCard extends StatelessWidget {
  /// Foydalanuvchi so'rovi — yo'nalish shu matndan aniqlanadi.
  final String queryText;

  const LawyerEscalationCard({super.key, required this.queryText});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final isDark = theme.brightness == Brightness.dark;
    final match = LawyerSpecializationMatcher.forQuery(queryText);

    // Yo'nalish satri: aniqlangan bo'lsa — ixtisoslik YORLIG'I (tarjima
    // qilingan), aks holda — sababi. Xom qiymat ekranga CHIQMAYDI.
    final areaLine = match.hasSpecialization
        ? l10n.aiLawyerEscalationMatched(
            expertSpecializationChipLabel(l10n, match.specialization!),
          )
        : l10n.aiLawyerEscalationNoMatch;

    return ModernContainer(
      backgroundColor: AppTone.accentIndigo.bg(isDark),
      borderColor: AppTone.accentIndigo.border(isDark),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.gavel_rounded,
                size: AppIconSize.md,
                color: AppTone.accentIndigo.on(isDark),
              ),
              const Gap(AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.aiLawyerEscalationTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppTone.accentIndigo.on(isDark),
                  ),
                ),
              ),
            ],
          ),
          const Gap(AppSpacing.sm),
          Text(
            areaLine,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 12,
              height: 1.4,
              color: isDark
                  ? AppTone.neutral.on(true)
                  : AppTone.neutral.on(false),
            ),
          ),
          if (match.isMandatory) ...[
            const Gap(AppSpacing.xs),
            // MAJBURIY holat — bu tavsiya emas, talab. Shuning uchun bu
            // YAGONA joyda xavf toni ishlatiladi.
            Text(
              l10n.aiLawyerEscalationMandatory,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: AppTone.danger.on(isDark),
              ),
            ),
          ],
          const Gap(AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => LegalExpertsPage(
                    initialSpecialization: match.specialization,
                  ),
                ),
              ),
              icon: const Icon(Icons.person_search_rounded,
                  size: AppIconSize.xs + 2),
              label: Text(l10n.aiLawyerEscalationAction),
            ),
          ),
        ],
      ),
    );
  }
}
