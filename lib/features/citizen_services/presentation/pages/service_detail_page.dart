import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/theme/tone.dart';
import 'package:lexhub/core/localization/category_labels.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/modern_container.dart';
import 'package:lexhub/features/citizen_services/domain/entities/citizen_service.dart';
import 'package:url_launcher/url_launcher.dart';

class ServiceDetailPage extends StatelessWidget {
  final CitizenService service;

  const ServiceDetailPage({super.key, required this.service});

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.errorCannotOpenLink)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.serviceGuideTitle,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category & Authority Pill
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTone.accentIndigo.bg(isDark, alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    catalogCategoryLabel(l10n, service.category),
                    style: TextStyle(
                      // O'LCHANGAN: qorong'ida xom `indigo` o'z 20% tinti
                      // ustida 2.64:1 (12 px w700 — "large text" EMAS, talab
                      // 4.5:1). Ton: 4.86 / 5.91:1.
                      color: AppTone.accentIndigo.on(isDark),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                if (service.isFree)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.emeraldDarkBg
                          : AppColors.emeraldLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      l10n.serviceFreeBadge,
                      style: TextStyle(
                        // O'LCHANGAN: `emeraldDark` `emeraldLight` ustida
                        // 3.32:1 (11 px w700, talab 4.5:1). Ton: 6.78 / 8.16.
                        color: AppTone.success.on(isDark),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color:
                          isDark ? AppColors.amberDarkBg : AppColors.amberLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      l10n.serviceCostBhm(service.costBhmPercent.toString()),
                      style: TextStyle(
                        // O'LCHANGAN: `amberDark` `amberLight` ustida 2.86:1.
                        // Ton: 6.37 / 11.05:1.
                        color: AppTone.warning.on(isDark),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),

            const Gap(12),

            // Title
            Text(
              service.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),

            const Gap(8),

            // Department
            Row(
              children: [
                const Icon(Icons.account_balance_rounded, size: 16, color: AppColors.textMutedLight),
                const Gap(6),
                Expanded(
                  child: Text(
                    service.department,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const Gap(14),

            // Freshness & Verification Shield Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.emeraldDarkBg : AppColors.emeraldLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.emerald.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  // O'LCHANGAN: xom `emerald` `emeraldLight` tinti ustida
                  // 2.24:1 — ikonka uchun ham (3:1) past. Ton: 6.78 / 8.16.
                  Icon(Icons.verified_rounded,
                      size: 18, color: AppTone.success.on(isDark)),
                  const Gap(8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.serviceVerifiedByLaw,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            // O'LCHANGAN: 3.32:1 (11 px w700 -> 4.5:1 kerak).
                            color: AppTone.success.on(isDark),
                          ),
                        ),
                        Text(
                          service.lastVerifiedAt != null
                              ? l10n.serviceLastVerified(
                                  service.lastVerifiedAt!.year,
                                  service.lastVerifiedAt!.month,
                                )
                              : l10n.serviceLawUpdateActive,
                          style: TextStyle(
                            fontSize: 10,
                            // O'LCHANGAN: `textMutedLight` yashil tint ustida
                            // 4.20:1 — 10 px matn uchun AA'dan past (tint fonni
                            // yorishtiradi, shuning uchun tekis yuzadagi
                            // 4.55:1 bu yerda yetmaydi). `textSecondary*`:
                            // 6.68 / 6.11:1.
                            color: isDark
                                ? AppColors.textMutedDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (service.sourceUrl != null)
                    InkWell(
                      onTap: () => _openUrl(context, service.sourceUrl!),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          // O'LCHANGAN: oq matn xom `emerald` ustida 2.54:1 —
                          // 11 px w700 yorliq uchun AA qo'pol buzilgan edi.
                          // `emeraldStrong`: 7.68:1, rangi baribir yashil.
                          color: AppColors.emeraldStrong,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Lex.uz",
                              style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            Gap(3),
                            Icon(Icons.open_in_new_rounded, size: 11, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const Gap(16),

            // Key Info Cards Row (Processing time & Cost)
            Row(
              children: [
                Expanded(
                  child: ModernContainer(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.serviceProcessingTime, style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
                        const Gap(4),
                        Text(
                          l10n.serviceWorkDays(service.processingDays),
                          // O'LCHANGAN: xom `indigo` oq kartada 4.47:1,
                          // `cardDark` da 3.27:1. Ton: 6.29 / 7.34:1.
                          style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTone.accentIndigo.on(isDark)),
                        ),
                      ],
                    ),
                  ),
                ),
                const Gap(10),
                Expanded(
                  child: ModernContainer(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.serviceFeeLabel, style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
                        const Gap(4),
                        Text(
                          service.isFree
                              ? l10n.serviceNoFee
                              : l10n.serviceCostBhm(service.costBhmPercent.toString()),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            // O'LCHANGAN: `emerald` oq kartada 2.54:1,
                            // `amberDark` 3.19:1. Ton: 7.68 / 7.09 (yorug'),
                            // 7.61 / 10.15 (qorong'i).
                            color: service.isFree
                                ? AppTone.success.on(isDark)
                                : AppTone.warning.on(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const Gap(16),

            // Description
            ModernContainer(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.serviceDescriptionTitle, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const Gap(6),
                  Text(service.description, style: theme.textTheme.bodyMedium?.copyWith(height: 1.45)),
                  if (service.deadlineLawReference != null) ...[
                    const Gap(10),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTone.accentIndigo.bg(isDark, alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          // O'LCHANGAN: xom `indigo` o'z 10% tinti ustida
                          // yorug' 3.95:1, qorong'i 2.95:1 — 11 px w600 MATN
                          // uchun (4.5:1) va 16 px ikonka uchun ham past.
                          Icon(Icons.gavel_rounded,
                              size: 16, color: AppTone.accentIndigo.on(isDark)),
                          const Gap(8),
                          Expanded(
                            child: Text(
                              service.deadlineLawReference!,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTone.accentIndigo.on(isDark)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Legal Basis Decree Box
            if (service.legalBasis != null) ...[
              const Gap(16),
              ModernContainer(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // O'LCHANGAN: `primary` (#0F172A) `cardDark`
                        // (#1E293B) ustida 1.22:1 — ikonka qorong'i mavzuda
                        // deyarli KO'RINMASDI. Neytral ton: 17.85 / 13.98:1.
                        Icon(Icons.menu_book_rounded,
                            size: 16, color: AppTone.neutral.on(isDark)),
                        const Gap(8),
                        Text(l10n.serviceLegalBasisTitle, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Gap(6),
                    Text(
                      service.legalBasis!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const Gap(20),

            // Required Documents
            if (service.requiredDocuments.isNotEmpty) ...[
              Text(
                l10n.serviceRequiredDocsTitle,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Gap(10),
              ModernContainer(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: service.requiredDocuments.map((doc) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // O'LCHANGAN: xom `emerald` oq kartada 2.54:1 —
                          // ikonka uchun ham (3:1) past. Ton: 7.68 / 7.61.
                          Icon(Icons.check_circle_outline_rounded,
                              size: 16, color: AppTone.success.on(isDark)),
                          const Gap(8),
                          Expanded(child: Text(doc, style: theme.textTheme.bodyMedium)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const Gap(20),
            ],

            // Step-by-Step Procedure Timeline
            if (service.steps.isNotEmpty) ...[
              Text(
                l10n.serviceStepsTitle,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Gap(12),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: service.steps.length,
                separatorBuilder: (_, __) => const Gap(10),
                itemBuilder: (context, index) {
                  final step = service.steps[index];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.cardDark : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // O'LCHANGAN: fon `primary` (#0F172A) IKKI mavzuda
                        // ham bir xil edi — `cardDark` ustida 1.22:1, ya'ni
                        // qorong'ida doira YO'QOLIB, faqat oq raqam qolardi
                        // (raqamning o'zi 17.85:1 — o'qilardi, lekin "qadam
                        // nishoni" vizual guruhlashi ketardi). Qorong'ida
                        // nishon TESKARI qilinadi: yorug' indigo doira +
                        // to'q raqam — doira 7.34:1, raqam 8.96:1.
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: isDark
                              ? AppColors.indigoOnTintDark
                              : AppColors.primary,
                          child: Text(
                            "${step.stepNumber}",
                            style: TextStyle(
                                color:
                                    isDark ? AppColors.surfaceDark : Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const Gap(12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(step.title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                                  ),
                                  if (step.stepType == 'online')
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTone.accentIndigo
                                            .bg(isDark, alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      // O'LCHANGAN: 10 px w700, xom aksent o'z
                                      // 10% tintida — `indigo` 3.95 / 2.95:1.
                                      child: Text(l10n.serviceStepOnline,
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: AppTone.accentIndigo
                                                  .on(isDark),
                                              fontWeight: FontWeight.bold)),
                                    )
                                  else if (step.stepType == 'payment')
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTone.success
                                            .bg(isDark, alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      // O'LCHANGAN: `emerald` o'z tintida
                                      // 2.31:1 — eng yomon uchtalikdan biri.
                                      child: Text(l10n.serviceStepPayment,
                                          style: TextStyle(
                                              fontSize: 10,
                                              color:
                                                  AppTone.success.on(isDark),
                                              fontWeight: FontWeight.bold)),
                                    )
                                  else if (step.stepType == 'appeal')
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTone.warning
                                            .bg(isDark, alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      // O'LCHANGAN: `amberDark` o'z tintida
                                      // 2.86:1.
                                      child: Text(l10n.serviceStepAppeal,
                                          style: TextStyle(
                                              fontSize: 10,
                                              color:
                                                  AppTone.warning.on(isDark),
                                              fontWeight: FontWeight.bold)),
                                    ),
                                ],
                              ),
                              const Gap(4),
                              Text(step.description, style: theme.textTheme.bodySmall?.copyWith(height: 1.4)),
                              if (step.warningNote != null) ...[
                                const Gap(6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.amberDarkBg : AppColors.amberLight,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      // O'LCHANGAN: `amberDark` `amberLight`
                                      // ustida 2.86:1 (ikonka 3:1, matn 4.5:1
                                      // — ikkisi ham yiqilardi).
                                      Icon(Icons.warning_amber_rounded,
                                          size: 14,
                                          color: AppTone.warning.on(isDark)),
                                      const Gap(6),
                                      Expanded(
                                        child: Text(
                                          step.warningNote!,
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  AppTone.warning.on(isDark)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (step.actionUrl != null) ...[
                                const Gap(8),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: () => _openUrl(context, step.actionUrl!),
                                    icon: const Icon(Icons.launch_rounded, size: 14),
                                    label: Text(l10n.serviceStepOpenPortal),
                                    // `foregroundColor: AppColors.primary`
                                    // O'CHIRILDI: u mavzuning
                                    // `textButtonTheme` sini BOSIB o'tardi va
                                    // qorong'ida yorliq `cardDark` ustida
                                    // 1.22:1 — amalda KO'RINMASDI. Mavzu
                                    // qiymati: yorug' `electricBlue` 5.17:1,
                                    // qorong'i `blueOnTintDark` 8.11:1.
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const Gap(24),
            ],

            // Action Button to MyGov / Official portal
            if (service.onlineUrl != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _openUrl(context, service.onlineUrl!),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: Text(l10n.serviceOpenMyGov),
                  // FON O'CHIRILDI: `AppColors.primary` mavzudan QAT'IY
                  // NAZAR bir xil edi va qorong'ida sahifa foni
                  // (`backgroundDark` #0A192F) bilan 1.01:1 berardi — to'la
                  // to'ldirilgan tugma CHEGARASI yo'qolib, oq yorliq "havoda"
                  // qolardi. Mavzuning `elevatedButtonTheme` si qorong'ida
                  // `indigoDark` beradi (oq yorliq 6.29:1, fon 2.80:1).
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),

            const Gap(20),
          ],
        ),
      ),
    );
  }
}
