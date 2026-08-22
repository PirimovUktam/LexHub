import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/localization/legal_ai_labels.dart';
import 'package:lexhub/core/theme/modern_container.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/risk_assessment.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/risk_level.dart';

/// Risk Matrix Gauge visual indicator showing risk levels, procedural limits, and win-rate factors
class RiskMatrixGauge extends StatelessWidget {
  final RiskAssessment assessment;

  const RiskMatrixGauge({
    super.key,
    required this.assessment,
  });

  Color _getRiskColor() {
    switch (assessment.level) {
      case RiskLevel.low:
        return AppColors.emerald;
      case RiskLevel.medium:
        return AppColors.amber;
      case RiskLevel.high:
        return AppColors.crimson;
      case RiskLevel.critical:
        return AppColors.riskCritical;
    }
  }

  Color _getRiskBgColor(bool isDark) {
    switch (assessment.level) {
      case RiskLevel.low:
        return isDark ? AppColors.emeraldDarkBg : AppColors.emeraldLight;
      case RiskLevel.medium:
        return isDark ? AppColors.amberDarkBg : AppColors.amberLight;
      case RiskLevel.high:
        return isDark ? AppColors.crimsonDarkBg : AppColors.crimsonLight;
      case RiskLevel.critical:
        return isDark ? AppColors.emergencyDarkBg : AppColors.riskCriticalBg;
    }
  }

  double _getRiskProgress() {
    switch (assessment.level) {
      case RiskLevel.low:
        return 0.25;
      case RiskLevel.medium:
        return 0.55;
      case RiskLevel.high:
        return 0.80;
      case RiskLevel.critical:
        return 1.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;
    final riskColor = _getRiskColor();
    final riskBg = _getRiskBgColor(isDark);
    final progress = _getRiskProgress();

    return ModernContainer(
      borderColor: riskColor.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: riskBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.shield_outlined,
                  color: riskColor,
                  size: 20,
                ),
              ),
              const Gap(10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.aiRiskTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      l10n.aiRiskSubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              // Risk Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: riskBg,
                  borderRadius: BorderRadius.circular(20),
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

          const Gap(14),

          // Gauge / Progress Visualizer
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.aiRiskGaugeLabel,
                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    "${(progress * 100).toInt()}%",
                    style: TextStyle(color: riskColor, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
              const Gap(6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: isDark ? AppColors.borderDark : AppColors.borderLight,
                  valueColor: AlwaysStoppedAnimation<Color>(riskColor),
                  minHeight: 8,
                ),
              ),
              const Gap(4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.riskScaleLow, style: TextStyle(fontSize: 10, color: isDark ? AppColors.emerald : AppColors.emeraldDark)),
                  Text(l10n.riskScaleMedium, style: TextStyle(fontSize: 10, color: isDark ? AppColors.amber : AppColors.amberDark)),
                  Text(l10n.riskScaleHigh, style: TextStyle(fontSize: 10, color: isDark ? AppColors.crimson : AppColors.crimsonDark)),
                  Text(l10n.riskScaleCritical, style: TextStyle(fontSize: 10, color: isDark ? AppColors.emergencyDark : AppColors.riskCritical)),
                ],
              ),
            ],
          ),

          const Gap(14),

          // Summary explanation
          Text(
            assessment.summary,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),

          // Procedural Deadline Countdown Badge
          if (assessment.deadlineDays != null) ...[
            const Gap(12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.amberDarkBg : AppColors.amberLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.amberDarkBorder : AppColors.amber.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    color: isDark ? AppColors.amber : AppColors.amberDark,
                    size: 20,
                  ),
                  const Gap(10),
                  Expanded(
                    child: Text(
                      l10n.aiDeadlineRemaining(assessment.deadlineDays ?? 0),
                      style: TextStyle(
                        color: isDark ? AppColors.amber : AppColors.amberDark,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Limitations & Disclaimers
          if (assessment.limitations.isNotEmpty) ...[
            const Gap(14),
            Text(
              l10n.aiLimitationsTitle,
              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Gap(6),
            ...assessment.limitations.map(
              (limitation) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: isDark ? AppColors.amber : AppColors.amberDark,
                    ),
                    const Gap(8),
                    Expanded(
                      child: Text(
                        limitation,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Mandatory Lawyer Alert (if critical or complex)
          if (assessment.requiresLawyer) ...[
            const Gap(14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.emergencyDarkBg : AppColors.crimsonLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.emergencyDarkBorder : AppColors.crimson.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.gavel_rounded,
                    color: isDark ? AppColors.crimson : AppColors.crimsonDark,
                    size: 22,
                  ),
                  const Gap(10),
                  Expanded(
                    child: Text(
                      l10n.aiLawyerRequiredWarning,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? AppColors.crimson : AppColors.crimsonDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
