/// HAMJAMIYAT SAVOLINING IXCHAM KARTASI — bosh sahifadagi gorizontal tasma.
///
/// NIMA UCHUN alohida widget: `CommunityPostCard` (349 qator) to'liq kartochka
/// — ovoz berish, ekspert javobi belgisi, muallif qatori, huquqiy tahlil
/// tugmasi. Uni bosh sahifaga qo'yish har bir savolni ~220 px balandlikda
/// ko'rsatardi va uchta savol butun ekranni egallardi. Bu karta faqat
/// SKANERLASH uchun: kategoriya, savol, javoblar soni.
///
/// MA'LUMOT SOXTA EMAS: barcha maydonlar `CommunityPost` entity'sidan keladi
/// (`getPosts()` -> Supabase). "Yangi" belgisi ham real `created_at` ga
/// qarab hisoblanadi, qo'lda yozilmaydi.
library;

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/category_labels.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/app_dimens.dart';
import 'package:lexhub/core/theme/modern_container.dart';
import 'package:lexhub/features/community_forum/domain/entities/community_post.dart';

class CommunityMiniCard extends StatelessWidget {
  const CommunityMiniCard({
    super.key,
    required this.post,
    required this.onTap,
    this.width = 260,
  });

  final CommunityPost post;
  final VoidCallback onTap;

  /// Gorizontal tasmada kartaning kengligi. `ListView` `shrinkWrap`siz
  /// ishlashi uchun aniq qiymat SHART.
  final double width;

  /// So'nggi 3 kun ichida yaratilgan savol "Yangi" deb belgilanadi.
  bool get _isNew =>
      DateTime.now().difference(post.createdAt).inDays < 3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    return SizedBox(
      width: width,
      child: ModernContainer(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: (isDark ? AppColors.indigo : AppColors.primary)
                          .withValues(alpha: isDark ? 0.22 : 0.08),
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    child: Text(
                      categoryLabel(l10n, post.category),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.indigoLight : AppColors.primary,
                      ),
                    ),
                  ),
                ),
                if (_isNew) ...[
                  const Gap(AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.emerald,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    child: Text(
                      l10n.communityNewBadge,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const Gap(AppSpacing.sm),
            Text(
              post.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Gap(AppSpacing.sm),
            Row(
              children: [
                Icon(
                  Icons.mode_comment_outlined,
                  size: AppIconSize.xs,
                  color: isDark
                      ? AppColors.textMutedDark
                      : AppColors.textMutedLight,
                ),
                const Gap(AppSpacing.xxs),
                Expanded(
                  child: Text(
                    l10n.communityAnswersCount(post.answersCount),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: AppIconSize.sm,
                  color: isDark ? AppColors.indigo : AppColors.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
