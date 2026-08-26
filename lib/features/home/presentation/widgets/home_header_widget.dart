import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_assets.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/modern_container.dart';

class HomeHeaderWidget extends StatelessWidget {
  final ValueChanged<String>? onSearchSubmitted;
  final VoidCallback? onSearchTap;

  const HomeHeaderWidget({
    super.key,
    this.onSearchSubmitted,
    this.onSearchTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Greeting & Brand Title
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      l10n.homeGreeting,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Gap(6),
                    const Text("👋", style: TextStyle(fontSize: 16)),
                  ],
                ),
                const Gap(2),
                Text(
                  l10n.homePlatformTitle,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.primary,
                borderRadius: BorderRadius.circular(14),
                border: isDark ? Border.all(color: AppColors.borderDark) : null,
                boxShadow: [
                  BoxShadow(
                    color: (isDark ? AppColors.indigo : AppColors.primary).withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  AppAssets.appLogo,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.balance_rounded,
                    color: AppColors.accent,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),

        const Gap(16),

        // Search / Ask Bar
        ModernContainer(
          onTap: onSearchTap,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          backgroundColor: isDark
              ? AppColors.cardDark
              : Colors.white,
          borderColor: AppColors.indigo.withValues(alpha: 0.3),
          child: Row(
            children: [
              const Icon(
                Icons.search_rounded,
                color: AppColors.indigo,
                size: 22,
              ),
              const Gap(12),
              Expanded(
                child: Text(
                  l10n.homeQueryHint,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                  ),
                ),
              ),
              // HALOLLIK: bu badge ilgari uchqun piktogrammasi + "AI Tahlil"
              // matnini ko'rsatardi. Lekin panelning `onTap`i (yuqorida)
              // `SearchPage`ni ochadi — hech qanday model chaqirilmaydi.
              // Endi badge faqat haqiqiy harakatni bildiradi.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.indigo.withValues(alpha: isDark ? 0.22 : 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_forward_rounded, color: AppColors.indigo, size: 14),
                    const Gap(4),
                    Text(
                      l10n.homeAiAnalyzeButton,
                      style: TextStyle(
                        color: isDark ? AppColors.indigoLight : AppColors.indigoDark,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
