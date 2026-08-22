import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/modern_container.dart';
import 'package:lexhub/features/home/presentation/pages/faq_questions_page.dart';

class FaqEntryBanner extends StatelessWidget {
  const FaqEntryBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    return ModernContainer(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const FaqQuestionsPage(),
          ),
        );
      },
      padding: const EdgeInsets.all(14),
      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
      borderColor: isDark
          ? AppColors.amber.withValues(alpha: 0.35)
          : AppColors.amber.withValues(alpha: 0.3),
      borderWidth: 1.2,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.amberDarkBg
                  : AppColors.amberLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.lightbulb_rounded,
              color: AppColors.amber,
              size: 24,
            ),
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      l10n.faqBannerTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                    const Gap(6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.emerald.withValues(alpha: 0.2)
                            : AppColors.emeraldLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        l10n.faqBannerBadge,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.emerald : AppColors.emeraldDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const Gap(2),
                Text(
                  l10n.faqBannerSubtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const Gap(8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.amber.withValues(alpha: 0.15)
                  : AppColors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.categoryAll,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.amber : AppColors.amberDark,
                  ),
                ),
                const Gap(2),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: isDark ? AppColors.amber : AppColors.amberDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
