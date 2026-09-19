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
///
/// Karta ikkala mavzuda ham to'q navy yuzada chiqadi. Badge va matnlar shu
/// yuzaning dark rang juftlarini oladi. `Expanded` sarlavhaga tasma ichidagi
/// qolgan balandlikni beradi; katta matnda ham karta tashqarisiga chiqmaydi.
library;

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/category_labels.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/app_dimens.dart';
import 'package:lexhub/core/theme/modern_container.dart';
import 'package:lexhub/core/theme/status_badge.dart';
import 'package:lexhub/core/theme/tone.dart';
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
    final l10n = context.l10n;

    return SizedBox(
      width: width,
      child: ModernContainer(
        onTap: onTap,
        padding: EdgeInsets.zero,
        backgroundColor: AppColors.primaryLight,
        borderColor: AppColors.borderDark,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Stack(
            children: [
              Positioned.fill(
                child: Ink(
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.all(
                      Radius.circular(AppRadius.card),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [
                        AppColors.primaryLight,
                        AppColors.primary,
                        AppColors.primaryDark,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -AppSpacing.sm,
                right: -AppSpacing.lg,
                child: ExcludeSemantics(
                  child: Icon(
                    Icons.gavel_rounded,
                    size: AppIconSize.empty * 2,
                    color: AppColors.textPrimaryDark.withValues(alpha: 0.06),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xxs,
                            ),
                            decoration: BoxDecoration(
                              color: AppTone.accentIndigo.bg(true),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(
                              categoryLabel(l10n, post.category),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppTone.accentIndigo.on(true),
                              ),
                            ),
                          ),
                        ),
                        if (_isNew) ...[
                          const Gap(AppSpacing.xs),
                          Theme(
                            data: theme.copyWith(brightness: Brightness.dark),
                            child: StatusBadge(
                              label: l10n.communityNewBadge,
                              tone: AppTone.success,
                              dense: true,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const Gap(AppSpacing.md),
                    Expanded(
                      child: Text(
                        post.title,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimaryDark,
                        ),
                      ),
                    ),
                    const Gap(AppSpacing.sm),
                    Row(
                      children: [
                        const Icon(
                          Icons.mode_comment_outlined,
                          size: AppIconSize.xs,
                          color: AppColors.textSecondaryDark,
                        ),
                        const Gap(AppSpacing.xxs),
                        Expanded(
                          child: Text(
                            l10n.communityAnswersCount(post.answersCount),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondaryDark,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: AppIconSize.sm,
                          color: AppColors.textSecondaryDark,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
