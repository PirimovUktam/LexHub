import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/modern_container.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/law_article.dart';
import 'package:url_launcher/url_launcher.dart';

/// Expandable Legal Basis Accordion displaying verified Lex.uz articles with Active status badge
class LegalBasisAccordion extends StatefulWidget {
  final List<LawArticle> articles;

  const LegalBasisAccordion({
    super.key,
    required this.articles,
  });

  @override
  State<LegalBasisAccordion> createState() => _LegalBasisAccordionState();
}

class _LegalBasisAccordionState extends State<LegalBasisAccordion> {
  // Track open/closed states for each article (first one opened by default)
  late final List<bool> _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = List.generate(
      widget.articles.length,
      (index) => index == 0,
    );
  }

  Future<void> _openLexUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.aiLexUzOpenFailed)),
        );
      }
    }
  }

  void _copyArticle(BuildContext context, LawArticle article) {
    final text = "${article.lawName}, ${article.articleNumber}: ${article.articleTitle}\n\n${article.articleText}\nManba: ${article.lexUrl}";
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.aiArticleCopied(article.articleNumber)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;
    final articles = widget.articles;

    // HALOL BO'SH HOLAT (2026-08-26).
    //
    // Ilgari bu yerda `return const SizedBox.shrink()` turardi — ya'ni modda
    // topilmasa blok JIMGINA yo'qolardi va foydalanuvchi javobning qonuniy
    // asosga ega emasligini bilmasdi. Bundan oldingi holat esa yanada yomon
    // edi: `retrieveRelevantChunks` nol ball holatida korpusning birinchi 3
    // moddasini qaytarardi va ALOQASIZ Konstitutsiya moddalari "Qonuniy
    // asoslar" sifatida ko'rsatilardi (ikkisi ham shu commit'da tuzatildi).
    //
    // Endi sabab OSHKORA aytiladi. Rang ataylab `lexBlue` EMAS — ko'k rang
    // tasdiqlangan manbani bildiradi, bu holat esa ogohlantirish.
    if (articles.isEmpty) {
      return ModernContainer(
        borderColor: AppColors.amber.withValues(alpha: 0.4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: isDark ? 0.2 : 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.info_outline_rounded,
                color: AppColors.amberDark,
                size: 20,
              ),
            ),
            const Gap(10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.aiLegalBasisNoneTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Gap(4),
                  Text(
                    l10n.aiLegalBasisNoneBody,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return ModernContainer(
      borderColor: AppColors.lexBlue.withValues(alpha: 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.lexBlue.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: AppColors.lexBlue,
                  size: 20,
                ),
              ),
              const Gap(10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.aiLegalBasisTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      l10n.aiLexUzBaseSubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.lexBlue,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              // Verified badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.emeraldDarkBg : AppColors.emeraldLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? AppColors.emeraldDarkBorder : AppColors.emerald.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: isDark ? AppColors.emerald : AppColors.emeraldDark,
                      size: 12,
                    ),
                    const Gap(4),
                    Text(
                      l10n.statusInForce,
                      style: TextStyle(
                        color: isDark ? AppColors.emerald : AppColors.emeraldDark,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Gap(14),

          // Accordion Item List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: articles.length,
            separatorBuilder: (_, __) => const Gap(10),
            itemBuilder: (context, index) {
              final article = articles[index];
              final isExpanded = _isExpanded.length > index ? _isExpanded[index] : false;

              return Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isExpanded
                        ? AppColors.lexBlue.withValues(alpha: 0.4)
                        : (isDark ? AppColors.borderDark : AppColors.borderLight),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    // Accordion Header Bar
                    InkWell(
                      onTap: () {
                        setState(() {
                          if (index < _isExpanded.length) {
                            _isExpanded[index] = !_isExpanded[index];
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.lexBlue,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                article.articleNumber,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Gap(10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    article.lawName,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? AppColors.lexBlueLight : AppColors.lexBlueDark,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (article.articleTitle.isNotEmpty)
                                    Text(
                                      article.articleTitle,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            Icon(
                              isExpanded
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Expandable Body
                    if (isExpanded) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
                                borderRadius: BorderRadius.circular(10),
                                border: const Border(
                                  left: BorderSide(color: AppColors.lexBlue, width: 3),
                                ),
                              ),
                              child: Text(
                                article.articleText,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  height: 1.5,
                                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                            const Gap(12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton.icon(
                                  onPressed: () => _copyArticle(context, article),
                                  icon: const Icon(Icons.copy_rounded, size: 16),
                                  label: Text(l10n.actionCopy, style: const TextStyle(fontSize: 12)),
                                ),
                                if (article.lexUrl.isNotEmpty)
                                  ElevatedButton.icon(
                                    onPressed: () => _openLexUrl(context, article.lexUrl),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.lexBlue,
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(120, 36),
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    icon: const Icon(Icons.open_in_new_rounded, size: 14),
                                    label: Text(
                                      l10n.actionOpenLexUz,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
