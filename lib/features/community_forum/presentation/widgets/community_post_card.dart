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
import 'package:lexhub/features/community_forum/presentation/pages/question_detail_page.dart';
import 'package:intl/intl.dart';

/// Munozara (savol) kartasi.
///
/// ── BATCH 4 (dizayn brifi §4) — O'LCHANGAN KONTRAST TUZATISHLARI ──
///
/// Bu kartada aksent rangi O'ZINING tint foni ustida matn qilib ishlatilgan
/// yetti joy bor edi; hammasi WCAG AA (4.5:1 matn / 3:1 grafik) dan past:
///   1. kategoriya chip'i qorong'ida `indigo` `indigo@0.15` ustida 2.80:1;
///   2. "Anonim" belgisi yorug'da `emeraldDark`+`emeraldLight` 3.32:1 va
///      shrifti 10 px (loyihadagi poli 11 px);
///   3. "Ekspert javobi" belgisi `emerald`+`emerald@0.15`: 2.19:1 (yorug'),
///      4.48:1 (qorong'i);
///   4. kategoriya eslatmasi yorlig'i `indigo`: 4.13:1 (yorug'), 2.95:1
///      (qorong'i);
///   5. muallif avatari — yorug'da `emerald` ikonka 2.10:1, qorong'ida esa
///      `primary` ikonka `primary@0.1` ustida 1.19:1, ya'ni AMALDA
///      KO'RINMAYDI;
///   6. "foydali" tugmasi bosilgan holatda qorong'ida `indigo` 3.27:1;
///   7. javoblar ikonkasi IKKI mavzuda ham `textMutedLight` bilan qotib
///      qolgan edi — `cardDark` ustida 3.07:1.
/// Endi rang faqat `AppTone` dan olinadi (tint fon, chegara va matn AYNI
/// tondan) yoki `StatusBadge` ishlatiladi; qulf `color_contrast_test.dart`.
///
/// Bosish: tashqi `InkWell` O'CHIRILDI va `ModernContainer.onTap` ishlatildi —
/// ilgari splash karta FONI OSTIDA chizilardi, ya'ni bosish qaytarma signali
/// ko'rinmasdi. Navigatsiya va `onLikeTap`/`onPostUpdated` shartnomasi
/// O'ZGARMADI.
///
/// §6: "uchqun" (`auto_awesome`) piktogrammasi olib tashlandi — u shartsiz
/// "AI" da'vosi; `post.aiSummary` esa MODEL javobi emas, kategoriya shabloni.

class CommunityPostCard extends StatefulWidget {
  final CommunityPost post;
  final VoidCallback? onConsultAITap;
  final VoidCallback? onPostUpdated;
  final VoidCallback? onLikeTap;

  const CommunityPostCard({
    super.key,
    required this.post,
    this.onConsultAITap,
    this.onPostUpdated,
    this.onLikeTap,
  });

  @override
  State<CommunityPostCard> createState() => _CommunityPostCardState();
}

class _CommunityPostCardState extends State<CommunityPostCard> {
  late bool _isLiked;
  late int _helpfulCount;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLikedByMe;
    _helpfulCount = widget.post.helpfulCount;
  }

  @override
  void didUpdateWidget(covariant CommunityPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.isLikedByMe != widget.post.isLikedByMe ||
        oldWidget.post.helpfulCount != widget.post.helpfulCount) {
      _isLiked = widget.post.isLikedByMe;
      _helpfulCount = widget.post.helpfulCount;
    }
  }

  void _toggleHelpful() {
    setState(() {
      _isLiked = !_isLiked;
      _helpfulCount += _isLiked ? 1 : -1;
    });
    widget.onLikeTap?.call();
  }

  void _openDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuestionDetailPage(
          post: widget.post,
          onAddAnswer: (ans, isExp) {
            widget.onPostUpdated?.call();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;
    final post = widget.post;
    final formattedDate = DateFormat('dd.MM.yyyy').format(post.createdAt);
    final hasExpertAnswer = post.answers.any((a) => a.isExpert);

    return ModernContainer(
      onTap: () => _openDetail(context),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Category tag & Date & Privacy Badge & Verified Expert Tag
            Row(
              children: [
                // 1-BAND: chip endi to'liq `AppTone.accentIndigo` da.
                // `Flexible` + ellipsis: uzun kategoriya nomi (inglizcha
                // "Administrative law") uchta belgi bilan birga Row'ni
                // to'ldirib overflow berardi.
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTone.accentIndigo.bg(isDark),
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                      border: Border.all(
                          color: AppTone.accentIndigo.border(isDark)),
                    ),
                    child: Text(
                      categoryLabel(l10n, post.category),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTone.accentIndigo.on(isDark),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                const Gap(AppSpacing.sm),
                // 2-BAND: qo'lda qurilgan 10 px belgi → `StatusBadge`
                // (11 px poli, fon/chegara/matn AYNI tondan).
                if (post.isAnonymous)
                  StatusBadge(
                    label: l10n.communityAnonymousBadge,
                    tone: AppTone.success,
                    icon: Icons.shield_outlined,
                    dense: true,
                  ),
                const Spacer(),
                // 3-BAND: "Ekspert javobi" — ishonch ko'ki, ya'ni
                // `expert_card_widget.dart` dagi "Tasdiqlangan" bilan AYNI
                // rang mantiqi (yashil = yutuq/maxfiylik, ko'k = ishonch).
                if (hasExpertAnswer)
                  StatusBadge(
                    label: l10n.communityExpertAnswerBadge,
                    tone: AppTone.info,
                    icon: Icons.verified_rounded,
                    dense: true,
                  ),
                if (!hasExpertAnswer)
                  Text(
                    formattedDate,
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
              ],
            ),

            const Gap(AppSpacing.sm + 2),

            // Title
            Text(
              post.title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const Gap(6),

            // Anonymized Question preview
            Text(
              post.anonymizedQuestion,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // Kategoriya bo'yicha avtomatik eslatma.
            //
            // HALOLLIK: `post.aiSummary` — MODEL javobi EMAS. U savol
            // yaratilganda `community_forum_remote_datasource.dart` ichida
            // kategoriya shabloni sifatida yoziladi ("Ushbu savol $category
            // doirasida ko'rib chiqiladi..."). Shuning uchun bu blokda
            // uchqun (`auto_awesome`) piktogrammasi ISHLATILMAYDI — u AI
            // da'vosini bildiradi. `Icons.rule_rounded` `legal_assistant_page`
            // dagi deterministik badge bilan bir xil.
            if (post.aiSummary.isNotEmpty) ...[
              const Gap(AppSpacing.sm + 2),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm + 2),
                decoration: BoxDecoration(
                  // 4-BAND: fon, chegara va matn AYNI tondan.
                  color: AppTone.accentIndigo.bg(isDark),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                      color: AppTone.accentIndigo.border(isDark)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.rule_rounded,
                      size: AppIconSize.xs + 1,
                      color: AppTone.accentIndigo.on(isDark),
                    ),
                    const Gap(AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.communityAiSummaryLabel,
                            style: TextStyle(
                              // 10 px → 11 px.
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTone.accentIndigo.on(isDark),
                            ),
                          ),
                          const Gap(2),
                          Text(
                            post.aiSummary,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              height: 1.3,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const Gap(AppSpacing.md),

            // Author metadata & answers
            Row(
              children: [
                // 5-BAND: qorong'ida `primary` ikonka `primary@0.1` ustida
                // 1.19:1 — amalda ko'rinmasdi. Endi ton bo'yicha.
                CircleAvatar(
                  radius: 10,
                  backgroundColor: post.isAnonymous
                      ? AppTone.success.bg(isDark)
                      : AppTone.neutral.bg(isDark),
                  child: Icon(
                    post.isAnonymous
                        ? Icons.shield_rounded
                        : Icons.person_rounded,
                    size: 12,
                    color: post.isAnonymous
                        ? AppTone.success.on(isDark)
                        : AppTone.neutral.on(isDark),
                  ),
                ),
                const Gap(AppSpacing.xs),
                Text(
                  post.isAnonymous
                      ? l10n.communityAnonymousAuthor
                      : post.authorName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),

            const Gap(AppSpacing.md),
            const Divider(height: 1),
            const Gap(AppSpacing.sm + 2),

            // Footer Action Bar
            Row(
              children: [
                InkWell(
                  onTap: _toggleHelpful,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Padding(
                    // Bosish balandligi: 16 ikonka + 2×8 = 32 px edi;
                    // 2×10 → 36 px. Karta ichidagi ikkilamchi harakat
                    // bo'lgani uchun 48 px poli qo'llanmaydi, lekin
                    // barmoq uchun kengaytirildi.
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.sm + 2,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isLiked
                              ? Icons.thumb_up_rounded
                              : Icons.thumb_up_alt_outlined,
                          size: AppIconSize.xs + 2,
                          // 6-BAND: bosilgan holat qorong'ida 3.27:1 edi.
                          color: _isLiked
                              ? AppTone.accentIndigo.on(isDark)
                              : (isDark
                                  ? AppColors.textMutedDark
                                  : AppColors.textMutedLight),
                        ),
                        const Gap(AppSpacing.xs),
                        Text(
                          "$_helpfulCount",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                _isLiked ? FontWeight.bold : FontWeight.w500,
                            color: _isLiked
                                ? AppTone.accentIndigo.on(isDark)
                                : (isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Gap(AppSpacing.md),
                Row(
                  children: [
                    // 7-BAND: ikonka IKKI mavzuda ham `textMutedLight` edi —
                    // `cardDark` ustida 3.07:1. Endi mavzuga bog'liq.
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: AppIconSize.xs + 1,
                      color: isDark
                          ? AppColors.textMutedDark
                          : AppColors.textMutedLight,
                    ),
                    const Gap(AppSpacing.xs - 1),
                    Text(
                      l10n.communityAnswersCount(post.answersCount),
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
                const Spacer(),
                if (widget.onConsultAITap != null)
                  TextButton.icon(
                    onPressed: widget.onConsultAITap,
                    style: TextButton.styleFrom(
                      // Standart `foregroundColor` = `colorScheme.primary`,
                      // qorong'ida `indigo` → `cardDark` ustida 3.27:1.
                      foregroundColor: AppTone.accentIndigo.on(isDark),
                      visualDensity: VisualDensity.compact,
                    ),
                    // §6: `auto_awesome` (uchqun) → `gavel` — pastki
                    // navigatsiyadagi "Maslahat" bilan AYNI piktogramma.
                    icon: const Icon(Icons.gavel_rounded,
                        size: AppIconSize.xs),
                    label: Text(l10n.communityAiAnalysis,
                        style: const TextStyle(fontSize: 11)),
                  ),
              ],
            ),
          ],
        ),
    );
  }
}
