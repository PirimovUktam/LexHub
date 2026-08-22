import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/modern_container.dart';

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

    return ModernContainer(
      padding: const EdgeInsets.all(16),
      backgroundColor: isDark
          ? AppColors.indigo.withValues(alpha: 0.1)
          : AppColors.indigoLight.withValues(alpha: 0.25),
      borderColor: AppColors.indigo.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.indigo.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.help_outline_rounded,
                  color: AppColors.indigo,
                  size: 18,
                ),
              ),
              const Gap(10),
              Expanded(
                child: Text(
                  l10n.aiClarificationTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.indigo : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const Gap(12),
          Text(
            l10n.aiClarificationBody,
            style: theme.textTheme.bodySmall?.copyWith(
              height: 1.4,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          const Gap(10),
          Column(
            children: questions.map((q) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => onQuestionTapped?.call(q),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.cardDark : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.arrow_right_rounded, color: AppColors.indigo, size: 20),
                        const Gap(6),
                        Expanded(
                          child: Text(
                            q,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Icon(Icons.add_circle_outline_rounded, size: 16, color: AppColors.indigo),
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
