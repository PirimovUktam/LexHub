import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/category_labels.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/modern_container.dart';
import 'package:lexhub/features/home/domain/entities/seed_question.dart';
import 'package:lexhub/features/legal_assistant/presentation/widgets/action_steps_timeline.dart';
import 'package:lexhub/features/legal_assistant/presentation/widgets/legal_basis_accordion.dart';
import 'package:lexhub/features/legal_assistant/presentation/widgets/relatable_summary_card.dart';
import 'package:lexhub/features/legal_assistant/presentation/widgets/risk_matrix_gauge.dart';

class TrendingQuestionsFeed extends StatelessWidget {
  final List<SeedQuestionModel> questions;
  final ValueChanged<SeedQuestionModel>? onQuestionTap;

  const TrendingQuestionsFeed({
    super.key,
    required this.questions,
    this.onQuestionTap,
  });

  void _showDetailModal(BuildContext context, SeedQuestionModel item) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const Gap(12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Gap(12),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(18),
                  children: [
                    // Category & Views
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.indigoDarkBg : AppColors.indigoLight,
                            borderRadius: BorderRadius.circular(8),
                            border: isDark ? Border.all(color: AppColors.indigoDarkBorder) : null,
                          ),
                          child: Text(
                            homeCategoryLabel(l10n, item.categoryName),
                            style: TextStyle(
                              color: isDark ? AppColors.indigo : AppColors.indigoDark,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.visibility_outlined,
                          size: 16,
                          color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                        ),
                        const Gap(4),
                        Text(
                          l10n.viewsCountLong(item.viewsCount),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                          ),
                        ),
                      ],
                    ),
                    const Gap(14),
                    Text(
                      item.questionText,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                    ),
                    const Gap(16),
                    RelatableSummaryCard(summary: item.relatableSummary),
                    const Gap(14),
                    ActionStepsTimeline(steps: item.actionableSteps),
                    const Gap(14),
                    LegalBasisAccordion(articles: item.legalBasis),
                    const Gap(14),
                    RiskMatrixGauge(assessment: item.riskAssessment),
                    const Gap(24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    if (questions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.trendingEmptyInCategory,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.trendingTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              l10n.casesCount(questions.length),
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
        const Gap(12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: questions.length,
          separatorBuilder: (_, __) => const Gap(12),
          itemBuilder: (context, index) {
            final item = questions[index];

            return ModernContainer(
              onTap: () {
                if (onQuestionTap != null) {
                  onQuestionTap!(item);
                } else {
                  _showDetailModal(context, item);
                }
              },
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category tag & Lex.uz article badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.indigo.withValues(alpha: 0.15)
                              : AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          homeCategoryLabel(l10n, item.categoryName),
                          style: TextStyle(
                            color: isDark ? AppColors.indigo : AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (item.legalBasis.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.lexBlueDarkBg : AppColors.lexBlueLight,
                            borderRadius: BorderRadius.circular(6),
                            border: isDark ? Border.all(color: AppColors.lexBlueDarkBorder) : null,
                          ),
                          child: Text(
                            item.legalBasis.first.articleNumber,
                            style: TextStyle(
                              color: isDark ? AppColors.lexBlue : AppColors.lexBlueDark,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const Gap(10),
                  Text(
                    item.questionText,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  const Gap(8),
                  Text(
                    item.relatableSummary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      height: 1.45,
                    ),
                  ),
                  const Gap(12),
                  Row(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.visibility_outlined,
                            size: 14,
                            color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                          ),
                          const Gap(4),
                          Text(
                            "${item.viewsCount}",
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        l10n.actionReadAnalysis,
                        style: TextStyle(
                          color: isDark ? AppColors.indigo : AppColors.indigoDark,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Gap(4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: isDark ? AppColors.indigo : AppColors.indigoDark,
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
