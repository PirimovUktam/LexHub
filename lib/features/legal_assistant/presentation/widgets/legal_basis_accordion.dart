/// QONUNIY ASOSLAR AKKORDEONI — lex.uz moddalari "muhrlangan rasmiy hujjat"
/// ko'rinishida.
///
/// ── BATCH 3 (dizayn brifi §3.3) — TUZATISHLAR ──
///
/// A. MANTIQIY NUQSON (dizayn emas, XATTI-HARAKAT): `_isExpanded` ro'yxati
///    `late final` bo'lib FAQAT `initState` da qurilardi. `LegalAssistantPage`
///    yangi javob kelganda AYNI element'ni qayta ishlatadi (widget turi va
///    o'rni o'zgarmaydi), ya'ni `initState` QAYTA CHAQIRILMAYDI. Natijada
///    yangi javobda moddalar soni ko'proq bo'lsa, eski uzunlikdan katta
///    indekslar `if (index < _isExpanded.length)` bilan to'silib qolardi va
///    O'SHA MODDALARNI OCHISH MUTLAQO MUMKIN EMAS edi. Endi ro'yxat `final`
///    emas va `didUpdateWidget` da moddalar soni o'zgarganda qayta quriladi.
///
/// B. O'LCHANGAN KONTRAST DEFEKTLARI (WCAG 2.1):
///    1. Sarlavha ikonkasi `lexBlue` (#0284C7) O'Z tinti ustida edi — o'lchov
///       (alfa 0.00→0.20, to'rt yuza) 2.34:1, 1.4.11 bo'yicha 3:1 kerak.
///       Endi `AppTone.info.on()`: 5.61:1 / 5.44:1.
///    2. Subtitr ham `lexBlue` edi: oq karta ustida 4.10:1, `cardDark` ustida
///       3.57:1 — MATN uchun (11 px yarim qalin) 4.5:1 talab qilinadi.
///    3. "Kuchda" yorlig'i `emeraldDark` + `emeraldLight` = 3.32:1 edi.
///       Endi `StatusBadge` + `AppTone.success` (6.12:1 / 5.41:1).
///    4. Modda raqami chipi OQ matn + `lexBlue` fon = 4.10:1 edi. Endi
///       yorug'da `lexBlueStrong` (#075985) fon + oq matn 7.56:1, qorong'ida
///       `lexBlueOnDark` (#38BDF8) fon + `primary` matn 8.33:1.
///    5. "lex.uz'da ochish" tugmasi ham OQ + `lexBlue` = 4.10:1 edi — endi
///       `lexBlueStrong` (7.56:1) / `lexBlueDark` (5.93:1).
///
/// C. "HUJJAT" KO'RINISHI: modda matni ilgari KURSIV (`FontStyle.italic`) edi.
///    Kursiv uzun huquqiy matnni o'qishni qiyinlashtiradi va rasmiy hujjatga
///    o'xshamaydi. Endi to'g'ri shrift, `height: 1.6`, ozgina issiq "qog'oz"
///    foni (#FEFCF7 yorug'da — `primary` matn 17.41:1) va chap tomonda 3 px
///    lexBlue muhr chizig'i + qolgan tomonlarda soch chizig'i.
///
/// O'ZGARMAGAN: `_openLexUrl` (`canLaunchUrl`/`launchUrl`), `_copyArticle`
/// buferi formati, halol bo'sh holat (sabab OSHKORA aytiladi) va
/// `LawArticle` maydonlari.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/app_dimens.dart';
import 'package:lexhub/core/theme/depth.dart';
import 'package:lexhub/core/theme/modern_container.dart';
import 'package:lexhub/core/theme/status_badge.dart';
import 'package:lexhub/core/theme/tone.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/law_article.dart';
import 'package:url_launcher/url_launcher.dart';

/// "QOG'OZ" YUZASI — modda matni uchun ozgina issiq oq (#FEFCF7).
///
/// NIMA UCHUN `AppColors` da EMAS: bu rang FAQAT shu bir joyda, huquqiy hujjat
/// matnining foni sifatida ishlatiladi. Umumiy tokenlar katalogiga qo'yish uni
/// boshqa joylarda "yana bitta oq" sifatida ishlatishga yo'l ochadi.
///
/// O'LCHANGAN: `textPrimaryLight` (#0F172A) shu fon ustida 17.41:1;
/// `textSecondaryLight` 7.39:1. Fon `backgroundLight` dan farqi 1.02:1, ya'ni
/// u yuza sifatida KO'RINMAYDI — shuning uchun hujjat blokining chegarasi
/// soch chizig'i va chapdagi 3 px muhr chizig'i bilan beriladi.
const Color _paperLight = Color(0xFFFEFCF7);

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
  /// Har bir moddaning ochiq/yopiq holati (birinchisi ochiq).
  ///
  /// `final` EMAS: `didUpdateWidget` da qayta quriladi (A-band).
  late List<bool> _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = _freshFlags(widget.articles.length);
  }

  @override
  void didUpdateWidget(LegalBasisAccordion oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Yangi javobda moddalar soni o'zgarsa ro'yxatni QAYTA QURAMIZ. Aks holda
    // eski uzunlikdan katta indekslar hech qachon ochilmaydi (A-band).
    if (oldWidget.articles.length != widget.articles.length) {
      _isExpanded = _freshFlags(widget.articles.length);
    }
  }

  static List<bool> _freshFlags(int length) =>
      List<bool>.generate(length, (int index) => index == 0);

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
        borderColor: AppTone.warning.border(isDark),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppTone.warning.bg(isDark),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                Icons.info_outline_rounded,
                // O'LCHOV: `amberDark` amber tinti ustida 2.64:1 edi.
                // `warning.on()`: 5.86:1 / 7.07:1.
                color: AppTone.warning.on(isDark),
                size: AppIconSize.sm,
              ),
            ),
            const Gap(AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.aiLegalBasisNoneTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const Gap(AppSpacing.xxs),
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
      borderColor: AppTone.info.border(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppTone.info.bg(isDark),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  Icons.verified_rounded,
                  // B1: `lexBlue` o'z tinti ustida 2.34:1 edi.
                  color: AppTone.info.on(isDark),
                  size: AppIconSize.sm,
                ),
              ),
              const Gap(AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.aiLegalBasisTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      l10n.aiLexUzBaseSubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        // B2: `lexBlue` matn sifatida 4.10:1 / 3.57:1 edi.
                        color: AppTone.info.on(isDark),
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(AppSpacing.xs),
              // B3: qo'lda qurilgan yorliq o'rniga `StatusBadge` — matn rangi
              // `AppTone.success` dan keladi va o'lchangan.
              StatusBadge(
                label: l10n.statusInForce,
                tone: AppTone.success,
                icon: Icons.check_circle_rounded,
                dense: true,
              ),
            ],
          ),

          const Gap(AppSpacing.lg),

          // Accordion Item List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: articles.length,
            separatorBuilder: (_, __) => const Gap(AppSpacing.sm),
            itemBuilder: (context, index) {
              final article = articles[index];
              final isExpanded = _isExpanded.length > index ? _isExpanded[index] : false;

              // B4: modda raqami chipi. Yorug'da to'q ko'k fon + oq matn
              // (7.56:1), qorong'ida yorqin ko'k fon + to'q matn (8.33:1).
              final Color chipBg =
                  isDark ? AppColors.lexBlueOnDark : AppColors.lexBlueStrong;
              final Color chipFg =
                  isDark ? AppColors.primary : Colors.white;

              return Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: isExpanded
                        ? AppTone.info.border(isDark)
                        : AppBorders.hairline(isDark),
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
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.xxs,
                              ),
                              decoration: BoxDecoration(
                                color: chipBg,
                                borderRadius: BorderRadius.circular(AppRadius.xs),
                              ),
                              child: Text(
                                article.articleNumber,
                                style: TextStyle(
                                  color: chipFg,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Gap(AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    article.lawName,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      // O'LCHOV: yorug'da `lexBlueStrong`
                                      // (#075985) oq yuza ustida 7.56:1;
                                      // qorong'ida `lexBlueOnDark` (#38BDF8)
                                      // `cardDark` ustida 6.83:1.
                                      color: isDark
                                          ? AppColors.lexBlueOnDark
                                          : AppColors.lexBlueStrong,
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
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: AppBorders.hairline(isDark),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // C-BAND: "muhrlangan hujjat" yuzasi. Kursiv OLIB
                            // TASHLANDI, chap tomonda muhr chizig'i qoldi.
                            //
                            // TUZATILDI (test evidence: `legal_basis_accordion_
                            // _empty_test.dart` → "A borderRadius can only be
                            // given on borders with uniform colors"): muhr
                            // chizig'i AVVAL `Border(left: 3px ko'k, qolgani
                            // hairline)` edi va `borderRadius` bilan birga
                            // berilgan — Flutter buni paint() da assert bilan
                            // yiqitadi. Endi muhr ALOHIDA qatlam: tashqi
                            // `Container` ning foni muhr rangi, ichki
                            // `Container` esa BIR XIL rangli hairline chegara
                            // (ya'ni radius qo'yish mumkin).
                            Container(
                              color: isDark
                                  ? AppColors.lexBlueOnDark
                                  : AppColors.lexBlueStrong,
                              padding: const EdgeInsets.only(left: 3),
                              child: Container(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.backgroundDark
                                      : _paperLight,
                                  borderRadius: const BorderRadius.horizontal(
                                    right: Radius.circular(AppRadius.sm),
                                  ),
                                  border: Border.all(
                                    color: AppBorders.hairline(isDark),
                                  ),
                                ),
                                child: Text(
                                  article.articleText,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    // O'LCHOV: `textPrimaryLight` (#0F172A)
                                    // qog'oz foni (#FEFCF7) ustida 17.41:1;
                                    // `textPrimaryDark` `backgroundDark`
                                    // ustida 16.82:1.
                                    height: 1.6,
                                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                  ),
                                ),
                              ),
                            ),
                            const Gap(AppSpacing.md),
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
                                      // B5: ilgari `lexBlue` + oq = 4.10:1.
                                      // Endi 7.56:1 (yorug') / 5.93:1
                                      // (qorong'i) — YORLIQ matn, 4.5:1 kerak.
                                      backgroundColor: isDark
                                          ? AppColors.lexBlueDark
                                          : AppColors.lexBlueStrong,
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(120, 40),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.md,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(AppRadius.xs),
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
