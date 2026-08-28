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
/// UCH O'LCHANGAN TUZATISH (bu fayl shu refaktoring ichida yozilgan edi va
/// o'lchov faqat keyin qilindi — halol qayd):
///
/// 1. "Yangi" belgisi TO'LDIRILGAN `emerald` (#10B981) fon + OQ matn edi:
///    2.54:1, ya'ni WCAG AA (4.5:1) dan JUDA past. Endi `StatusBadge` +
///    `AppTone.success`: tintli fon + o'lchangan matn (yorug' 6.36:1,
///    qorong'i 5.41:1). Yon ta'siri: 9 px shrift ham yo'qoldi — `StatusBadge`
///    11 px dan past tushmaydi.
///
/// 2. Kategoriya chipi 10 px edi. `textScaleFactor` 1.0 da ham chegaraviy
///    o'qiladi; endi 11 px va rang `AppTone.accentIndigo` dan.
///
/// 3. SARLAVHA `Expanded` ichiga olindi. Ilgari uch qatorli sarlavha
///    fiksatsiyalangan 148 px tasmada `textScaleFactor` 2.0 da "BOTTOM
///    OVERFLOWED" berardi (hisob: chip 28 + gap 16 + futer 22 = 66, qolgan
///    58 px ga 3 × 14 × 1.3 × 2.0 = 109 px matn sig'masdi). `Expanded`
///    matnga QOLGAN joyni beradi va u kesiladi — `RenderFlex` yiqilmaydi.
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
                      color: AppTone.accentIndigo.bg(isDark),
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    child: Text(
                      categoryLabel(l10n, post.category),
                      maxLines: 1,
                      // `StatusBadge` EMAS: kategoriya nomi uzun bo'lishi
                      // mumkin va bu yerda `ellipsis` SHART (karta kengligi
                      // 260 px). `StatusBadge` esa qisqa yorliqlar uchun.
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTone.accentIndigo.on(isDark),
                      ),
                    ),
                  ),
                ),
                if (_isNew) ...[
                  const Gap(AppSpacing.xs),
                  StatusBadge(
                    label: l10n.communityNewBadge,
                    tone: AppTone.success,
                    dense: true,
                  ),
                ],
              ],
            ),
            const Gap(AppSpacing.sm),
            Expanded(
              child: Text(
                post.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                ),
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
                  color: AppTone.accentIndigo.on(isDark),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
