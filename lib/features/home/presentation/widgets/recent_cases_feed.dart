import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/di/injection_container.dart';
import 'package:lexhub/core/localization/category_labels.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/modern_container.dart';
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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
            } catch (_) {}
          }
        }

        if (cases.isEmpty) {
          return const SizedBox.shrink();
        }

        // Sort newest first
        cases.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final recentCases = cases.take(4).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 16,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.indigo : AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const Gap(8),
                    Text(
                      l10n.recentCasesTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SavedCasesPage(),
                      ),
                    );
                  },
                  child: Text(
                    l10n.recentCasesSeeAll(cases.length),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.indigo : AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const Gap(10),
            SizedBox(
              height: 154,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recentCases.length,
                separatorBuilder: (_, __) => const Gap(12),
                itemBuilder: (context, index) {
                  final item = recentCases[index];
                  final dateStr = DateFormat('dd.MM • HH:mm').format(item.createdAt);
                  final displayQuery = item.userQuery.isNotEmpty
                      ? item.userQuery
                      : item.relatableSummary;

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
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.indigo.withValues(alpha: 0.2)
                                      : AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  homeCategoryLabel(l10n, item.category),
                                  style: TextStyle(
                                    color: isDark ? AppColors.indigo : AppColors.primary,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                dateStr,
                                style: TextStyle(
                                  color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                          const Gap(6),
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
                          const Gap(6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                l10n.legalBasisCount(item.legalBasis.length),
                                style: TextStyle(
                                  color: isDark ? AppColors.emerald : AppColors.emeraldDark,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    l10n.actionRead,
                                    style: TextStyle(
                                      color: isDark ? AppColors.indigo : AppColors.primary,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Gap(2),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 16,
                                    color: isDark ? AppColors.indigo : AppColors.primary,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (response.emergencyProtocol != null && response.emergencyProtocol!.isEmergency) ...[
              EmergencyBannerWidget(protocol: response.emergencyProtocol!),
              const Gap(14),
            ],
            RelatableSummaryCard(summary: response.relatableSummary),
            const Gap(14),
            ActionStepsTimeline(steps: response.actionableSteps),
            const Gap(14),
            LegalBasisAccordion(articles: response.legalBasis),
            const Gap(14),
            RiskMatrixGauge(assessment: response.riskAssessment),
            const Gap(32),
          ],
        ),
      ),
    );
  }
}
