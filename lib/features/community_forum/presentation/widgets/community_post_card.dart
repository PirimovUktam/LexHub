import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/category_labels.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/modern_container.dart';
import 'package:lexhub/features/community_forum/domain/entities/community_post.dart';
import 'package:lexhub/features/community_forum/presentation/pages/question_detail_page.dart';
import 'package:intl/intl.dart';

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

    return InkWell(
      onTap: () => _openDetail(context),
      borderRadius: BorderRadius.circular(16),
      child: ModernContainer(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Category tag & Date & Privacy Badge & Verified Expert Tag
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.indigo.withValues(alpha: 0.15)
                        : AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    categoryLabel(l10n, post.category),
                    style: TextStyle(
                      color: isDark ? AppColors.indigo : AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                const Gap(8),
                if (post.isAnonymous)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.emeraldDarkBg : AppColors.emeraldLight,
                      borderRadius: BorderRadius.circular(4),
                      border: isDark ? Border.all(color: AppColors.emeraldDarkBorder) : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.shield_outlined, size: 10, color: AppColors.emeraldDark),
                        const Gap(3),
                        Text(
                          l10n.communityAnonymousBadge,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.emerald : AppColors.emeraldDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                if (hasExpertAnswer)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.emerald.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_rounded, size: 11, color: AppColors.emerald),
                        const Gap(3),
                        Text(
                          l10n.communityExpertAnswerBadge,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.emerald,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (!hasExpertAnswer)
                  Text(
                    formattedDate,
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
              ],
            ),

            const Gap(10),

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
              const Gap(10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.indigo.withValues(alpha: 0.1)
                      : AppColors.primary.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark
                        ? AppColors.indigo.withValues(alpha: 0.2)
                        : AppColors.primary.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.rule_rounded,
                      size: 15,
                      color: AppColors.indigo,
                    ),
                    const Gap(8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.communityAiSummaryLabel,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.indigo,
                            ),
                          ),
                          const Gap(2),
                          Text(
                            post.aiSummary,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              height: 1.3,
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

            const Gap(12),

            // Author metadata & answers
            Row(
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: post.isAnonymous
                      ? AppColors.emerald.withValues(alpha: 0.2)
                      : AppColors.primary.withValues(alpha: 0.1),
                  child: Icon(
                    post.isAnonymous ? Icons.shield_rounded : Icons.person_rounded,
                    size: 12,
                    color: post.isAnonymous ? AppColors.emerald : AppColors.primary,
                  ),
                ),
                const Gap(6),
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

            const Gap(12),
            const Divider(height: 1),
            const Gap(10),

            // Footer Action Bar
            Row(
              children: [
                InkWell(
                  onTap: _toggleHelpful,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          _isLiked
                              ? Icons.thumb_up_rounded
                              : Icons.thumb_up_alt_outlined,
                          size: 16,
                          color: _isLiked
                              ? (isDark ? AppColors.indigo : AppColors.primary)
                              : (isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                        ),
                        const Gap(6),
                        Text(
                          "$_helpfulCount",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                _isLiked ? FontWeight.bold : FontWeight.w500,
                            color: _isLiked
                                ? (isDark ? AppColors.indigo : AppColors.primary)
                                : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Gap(16),
                Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline_rounded, size: 15, color: AppColors.textMutedLight),
                    const Gap(5),
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
                    icon: const Icon(Icons.auto_awesome_rounded, size: 14),
                    label: Text(l10n.communityAiAnalysis,
                        style: const TextStyle(fontSize: 11)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
