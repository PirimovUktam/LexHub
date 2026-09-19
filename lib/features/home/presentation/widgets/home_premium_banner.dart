import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/app_dimens.dart';

/// Informational until a subscription product exists; no purchase affordance.
class HomePremiumBanner extends StatelessWidget {
  const HomePremiumBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryLight, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(
            color: AppColors.indigo.withValues(alpha: 0.18),
            blurRadius: AppSpacing.xxl,
            offset: const Offset(0, AppSpacing.sm),
          )
        ],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.amber.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: const Icon(Icons.workspace_premium_rounded,
              color: AppColors.amberOnTintDark, size: AppIconSize.lg),
        ),
        const Gap(AppSpacing.md),
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.homePremiumTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.amberOnTintDark,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Gap(AppSpacing.xxs),
            Text(
              l10n.homePremiumSubtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondaryDark,
              ),
            ),
            const Gap(AppSpacing.xxs),
            Text(
              l10n.homePremiumComingSoon,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.indigoOnTintDark,
              ),
            ),
          ],
        )),
      ]),
    );
  }
}
