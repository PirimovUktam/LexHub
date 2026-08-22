import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/localization/legal_ai_labels.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/risk_assessment.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/risk_level.dart';

class RiskAssessmentCard extends StatelessWidget {
  final RiskAssessment assessment;

  const RiskAssessmentCard({
    super.key,
    required this.assessment,
  });

  Color _getRiskColor() {
    switch (assessment.level) {
      case RiskLevel.low:
        return AppColors.riskLow;
      case RiskLevel.medium:
        return AppColors.riskMedium;
      case RiskLevel.high:
        return AppColors.riskHigh;
      case RiskLevel.critical:
        return AppColors.riskCritical;
    }
  }

  Color _getRiskBgColor(bool isDark) {
    switch (assessment.level) {
      case RiskLevel.low:
        return isDark ? AppColors.emeraldDarkBg : AppColors.riskLowBg;
      case RiskLevel.medium:
        return isDark ? AppColors.amberDarkBg : AppColors.riskMediumBg;
      case RiskLevel.high:
        return isDark ? AppColors.crimsonDarkBg : AppColors.riskHighBg;
      case RiskLevel.critical:
        return isDark ? AppColors.emergencyDarkBg : AppColors.riskCriticalBg;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;
    final riskColor = _getRiskColor();
    final riskBgColor = _getRiskBgColor(isDark);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: riskBgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.shield_outlined,
                    color: riskColor,
                    size: 22,
                  ),
                ),
                const Gap(10),
                Expanded(
                  child: Text(
                    l10n.aiRiskTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: riskBgColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: riskColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    riskLevelLabel(l10n, assessment.level),
                    style: TextStyle(
                      color: riskColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Gap(12),
            Text(
              assessment.summary,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.5,
              ),
            ),
            if (assessment.limitations.isNotEmpty) ...[
              const Gap(12),
              Text(
                l10n.aiLimitationsTitle,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Gap(6),
              ...assessment.limitations.map(
                (limitation) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: isDark ? AppColors.amber : AppColors.riskMedium,
                      ),
                      const Gap(8),
                      Expanded(
                        child: Text(
                          limitation,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (assessment.requiresLawyer) ...[
              const Gap(12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.emergencyDarkBg : AppColors.riskHighBg,
                  borderRadius: BorderRadius.circular(8),
                  border: isDark ? Border.all(color: AppColors.emergencyDarkBorder) : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_rounded,
                      color: isDark ? AppColors.crimson : AppColors.riskHigh,
                      size: 18,
                    ),
                    const Gap(8),
                    Expanded(
                      child: Text(
                        l10n.aiLawyerRecommendedWarning,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? AppColors.crimson : AppColors.riskHigh,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
