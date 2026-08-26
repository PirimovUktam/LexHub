import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/di/injection_container.dart';
import 'package:lexhub/core/localization/category_labels.dart';
import 'package:lexhub/core/localization/failure_text.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/modern_container.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_response.dart';
import 'package:lexhub/features/legal_assistant/presentation/widgets/action_steps_timeline.dart';
import 'package:lexhub/features/legal_assistant/presentation/widgets/emergency_banner_widget.dart';
import 'package:lexhub/features/legal_assistant/presentation/widgets/legal_basis_accordion.dart';
import 'package:lexhub/features/legal_assistant/presentation/widgets/relatable_summary_card.dart';
import 'package:lexhub/features/legal_assistant/presentation/widgets/risk_matrix_gauge.dart';
import 'package:lexhub/features/saved_cases/presentation/bloc/saved_cases_bloc.dart';

class SavedCasesPage extends StatelessWidget {
  const SavedCasesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return BlocProvider(
      create: (context) => sl<SavedCasesBloc>()..add(const LoadSavedCasesEvent()),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            l10n.savedCasesTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body: BlocBuilder<SavedCasesBloc, SavedCasesState>(
          builder: (context, state) {
            final isDark = theme.brightness == Brightness.dark;

            if (state is SavedCasesLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is SavedCasesError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.emergency,
                        size: 44,
                      ),
                      const Gap(12),
                      Text(errorStateText(context.l10n, state.message, state.code), textAlign: TextAlign.center),
                      const Gap(16),
                      ElevatedButton(
                        onPressed: () => context
                            .read<SavedCasesBloc>()
                            .add(const LoadSavedCasesEvent()),
                        child: Text(l10n.actionRetry),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (state is SavedCasesLoaded) {
              if (state.cases.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.indigo.withValues(alpha: 0.15)
                                : AppColors.primary.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.bookmark_border_rounded,
                            size: 48,
                            color: isDark ? AppColors.indigo : AppColors.primary,
                          ),
                        ),
                        const Gap(16),
                        Text(
                          l10n.savedCasesEmptyTitle,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Gap(8),
                        Text(
                          l10n.savedCasesEmptyBody,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: state.cases.length,
                separatorBuilder: (_, __) => const Gap(12),
                itemBuilder: (context, index) {
                  final item = state.cases[index];
                  final formattedDate =
                      DateFormat('dd.MM.yyyy HH:mm').format(item.createdAt);

                  return ModernContainer(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _SavedCaseDetailPage(response: item),
                        ),
                      );
                    },
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
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
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const Gap(8),
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 12,
                                  color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                                ),
                                const Gap(4),
                                Text(
                                  formattedDate,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: AppColors.crimson,
                                size: 20,
                              ),
                              onPressed: () {
                                context.read<SavedCasesBloc>().add(
                                      DeleteSavedCaseItemEvent(item.id),
                                    );
                              },
                            ),
                          ],
                        ),
                        if (item.userQuery.isNotEmpty) ...[
                          const Gap(6),
                          Text(
                            l10n.savedCaseQuestionQuoted(item.userQuery),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              fontStyle: FontStyle.italic,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const Gap(6),
                        Text(
                          item.relatableSummary,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.45,
                          ),
                        ),
                        const Gap(12),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.lexBlueDarkBg : AppColors.lexBlueLight,
                                borderRadius: BorderRadius.circular(8),
                                border: isDark ? Border.all(color: AppColors.lexBlueDarkBorder) : null,
                              ),
                              child: Text(
                                l10n.legalBasisCount(item.legalBasis.length),
                                style: const TextStyle(
                                  color: AppColors.lexBlue,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              l10n.actionViewDetails,
                              style: TextStyle(
                                color: isDark ? AppColors.indigo : AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Gap(4),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: isDark ? AppColors.indigo : AppColors.primary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

class _SavedCaseDetailPage extends StatelessWidget {
  final LegalResponse response;

  const _SavedCaseDetailPage({required this.response});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.savedCaseDetailTitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (response.emergencyProtocol != null && response.emergencyProtocol!.isEmergency) ...[
              EmergencyBannerWidget(protocol: response.emergencyProtocol!),
              const Gap(14),
            ],
            RelatableSummaryCard(
              summary: response.relatableSummary,
              source: response.source,
            ),
            const Gap(14),
            ActionStepsTimeline(steps: response.actionableSteps),
            const Gap(14),
            LegalBasisAccordion(articles: response.legalBasis),
            const Gap(14),
            RiskMatrixGauge(assessment: response.riskAssessment),
            const Gap(24),
          ],
        ),
      ),
    );
  }
}
