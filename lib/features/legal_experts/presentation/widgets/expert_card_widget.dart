import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/expert_labels.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/modern_container.dart';
import 'package:lexhub/features/legal_experts/domain/entities/legal_expert.dart';
import 'package:lexhub/features/legal_experts/presentation/widgets/expert_profile_modal.dart';

/// Advokat kartasi.
///
/// §6: bo'sh maydon uchun TO'QIMA qiymat ko'rsatilmaydi — baho/tajriba/
/// yutuqlar chip'lari faqat REAL raqam bo'lganda chiqadi, bo'sh bio esa
/// umuman render qilinmaydi.
class ExpertCardWidget extends StatelessWidget {
  final LegalExpert expert;

  const ExpertCardWidget({super.key, required this.expert});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;
    final bio = expert.bio.trim();
    final city = expert.city.trim();

    final metricChips = <Widget>[
      if (expert.reviewsCount > 0)
        _metricChip(
          text: '${expert.rating}',
          icon: Icons.star_rounded,
          background: isDark ? AppColors.amberDarkBg : AppColors.amberLight,
          foreground: isDark ? AppColors.amber : AppColors.amberDark,
          borderColor: isDark ? AppColors.amberDarkBorder : null,
        ),
      if (expert.experienceYears > 0)
        _metricChip(
          text: l10n.expertExperienceYears(expert.experienceYears),
          background: isDark
              ? AppColors.indigoDarkBg
              : AppColors.primary.withValues(alpha: 0.08),
          foreground: isDark ? AppColors.indigo : AppColors.primary,
          borderColor: isDark ? AppColors.indigoDarkBorder : null,
        ),
      if (expert.successfulCasesCount > 0)
        _metricChip(
          text: l10n.expertWonCases(expert.successfulCasesCount),
          background: isDark ? AppColors.emeraldDarkBg : AppColors.emeraldLight,
          foreground: isDark ? AppColors.emerald : AppColors.emeraldDark,
          borderColor: isDark ? AppColors.emeraldDarkBorder : null,
        ),
    ];

    return ModernContainer(
      onTap: () => ExpertProfileModal.show(context, expert),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              CircleAvatar(
                radius: 26,
                backgroundColor: isDark ? AppColors.indigo : AppColors.primary,
                child: Text(
                  expertAvatarInitial(expert),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
              const Gap(12),
              // Name & Specialization
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            expertDisplayName(l10n, expert),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (expert.isVerified) ...[
                          const Gap(4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.emeraldDarkBg : AppColors.emeraldLight,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.emeraldDarkBorder
                                    : AppColors.emerald.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.verified_rounded,
                                  color: isDark ? AppColors.emerald : AppColors.emeraldDark,
                                  size: 11,
                                ),
                                const Gap(3),
                                Text(
                                  l10n.expertVerifiedBadge,
                                  style: TextStyle(
                                    color: isDark ? AppColors.emerald : AppColors.emeraldDark,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const Gap(3),
                    Text(
                      expertSpecializationText(l10n, expert),
                      style: TextStyle(
                        color: isDark ? AppColors.textMutedDark : AppColors.primaryLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Hudud faqat bazada bo'lsa ko'rsatiladi (to'qima
                    // "Toshkent sh." endi YO'Q).
                    if (city.isNotEmpty) ...[
                      const Gap(2),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                          ),
                          const Gap(4),
                          Text(
                            city,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          // METRIK CHIP'LAR — FAQAT REAL raqamlar bilan (§6).
          //   * baho: `reviews_count == 0` bo'lsa chip UMUMAN chiqmaydi
          //     (ilgari baholanmagan advokat "⭐ 5.0" ko'rinardi);
          //   * tajriba / yutilgan ish: 0 bo'lsa chiqmaydi.
          // `Wrap`: inglizcha yorliqlar uzunroq, `Row` da overflow berardi.
          if (metricChips.isNotEmpty) ...[
            const Gap(12),
            Wrap(spacing: 8, runSpacing: 6, children: metricChips),
          ],

          // Bio snippet (bo'sh bo'lsa render qilinmaydi)
          if (bio.isNotEmpty) ...[
            const Gap(12),
            Text(
              bio,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                height: 1.4,
              ),
            ),
          ],

          const Gap(12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  expertPriceText(l10n, expert),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.primary,
                  ),
                ),
              ),
              const Gap(8),
              Row(
                children: [
                  Text(
                    l10n.expertContact,
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
        ],
      ),
    );
  }

  /// Bitta metrik chip'i (fon/hoshiya/matn rangi chaqiruvchida beriladi).
  Widget _metricChip({
    required String text,
    required Color background,
    required Color foreground,
    Color? borderColor,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: borderColor != null ? Border.all(color: borderColor) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: foreground, size: 14),
            const Gap(3),
          ],
          Text(
            text,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
