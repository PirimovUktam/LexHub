import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
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
                    color: isDark ? AppColors.indigo.withValues(alpha: 0.2) : AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    catalogCategoryLabel(l10n, service.category),
                    style: TextStyle(
                      color: isDark ? AppColors.indigo : AppColors.primary,
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
                      color: isDark ? AppColors.emeraldDarkBg : AppColors.emeraldLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      l10n.serviceFreeBadge,
                      style: TextStyle(
                        color: isDark ? AppColors.emerald : AppColors.emeraldDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.amberDarkBg : AppColors.amberLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      l10n.serviceCostBhm(service.costBhmPercent.toString()),
                      style: const TextStyle(
                        color: AppColors.amberDark,
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
                  const Icon(Icons.verified_rounded, size: 18, color: AppColors.emerald),
                  const Gap(8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.serviceVerifiedByLaw,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.emeraldDark,
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
                            color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
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
                          color: AppColors.emerald,
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
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: AppColors.indigo),
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
                            color: service.isFree ? AppColors.emerald : AppColors.amberDark,
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
                        color: AppColors.indigo.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.gavel_rounded, size: 16, color: AppColors.indigo),
                          const Gap(8),
                          Expanded(
                            child: Text(
                              service.deadlineLawReference!,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.indigo),
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
                        const Icon(Icons.menu_book_rounded, size: 16, color: AppColors.primary),
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
                          const Icon(Icons.check_circle_outline_rounded, size: 16, color: AppColors.emerald),
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
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.primary,
                          child: Text(
                            "${step.stepNumber}",
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
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
                                        color: AppColors.indigo.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(l10n.serviceStepOnline, style: const TextStyle(fontSize: 10, color: AppColors.indigo, fontWeight: FontWeight.bold)),
                                    )
                                  else if (step.stepType == 'payment')
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.emerald.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(l10n.serviceStepPayment, style: const TextStyle(fontSize: 10, color: AppColors.emerald, fontWeight: FontWeight.bold)),
                                    )
                                  else if (step.stepType == 'appeal')
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.amberDark.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(l10n.serviceStepAppeal, style: const TextStyle(fontSize: 10, color: AppColors.amberDark, fontWeight: FontWeight.bold)),
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
                                      const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.amberDark),
                                      const Gap(6),
                                      Expanded(
                                        child: Text(
                                          step.warningNote!,
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.amberDark),
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
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      visualDensity: VisualDensity.compact,
                                      foregroundColor: AppColors.primary,
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
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
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
