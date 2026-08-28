import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/app_dimens.dart';
import 'package:lexhub/core/theme/depth.dart';
import 'package:lexhub/core/theme/modern_container.dart';
import 'package:lexhub/core/theme/tone.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_response.dart';

/// Relatable Summary Card presenting plain-language takeaway with Audio Playback simulation and Copy actions
///
/// HALOLLIK (CLAUDE.md §0): bu karta xulosa MATNINI ko'rsatadi, lekin matn
/// server modelidan ham, qurilmadagi deterministik qonun bazasidan ham
/// kelishi mumkin. O'LCHANGAN (2026-08-26, production): proxy `ai_timeout`
/// qaytarganda `LegalAssistant` HAR SAFAR `_generateGroundedUzbekLegalResponse`
/// ga tushadi. Ilgari manba badge'i FAQAT `legal_assistant_page.dart` da
/// bo'lgani uchun `saved_cases_page`, `recent_cases_feed` va
/// `faq_questions_page` AYNI matnni manbasiz chiqarardi — foydalanuvchi
/// deterministik javobni model tahlili deb o'ylashi mumkin edi.
///
/// Shuning uchun `source` — MAJBURIY parametr: yangi chaqiruv joyi qo'shilsa
/// kompilyator manbani so'raydi, badge'ni unutib qo'yish MUMKIN EMAS.
/// Qiymat `LegalResponse.sourceLlm` yoki `LegalResponse.sourceDeterministic`.
///
/// ── BATCH 3 (dizayn brifi §3.3) — UCH O'ZGARISH ──
///
/// 1. O'LCHANGAN GRAFIK DEFEKTI: sarlavha ikonkasi AKSENTNING O'ZIDA edi va
///    AYNI aksentning 12% tinti ustida turardi. Deterministik javobda aksent
///    `amber` (#F59E0B) — o'lchov (alfa 0.00→0.20, `cardLight` VA
///    `backgroundLight`) ENG YOMON 1.78:1 berdi; WCAG 1.4.11 grafik obyekt
///    uchun 3:1 talab qiladi. Model javobida ham (`indigo` #6366F1) yorug'da
///    3.32:1, qorong'ida 2.64:1 — ikkinchisi TALABDAN PAST. Endi rang
///    `AppTone` dan: `warning.on()` 5.86/7.07, `accentIndigo.on()` 4.67/5.91.
///
/// 2. KARTA FONI SHAFFOFSIZ QILINDI. Ilgari `indigoLight@0.35` edi — yarim
///    shaffof fon ostidan sahifa foni ko'rinadi, ya'ni o'lchangan kontrast
///    karta QAYSI ekranda turishiga bog'liq bo'lardi. `Color.alphaBlend`
///    ayni ko'rinishni qat'iy qiymat sifatida beradi (#F9FAFF) va
///    `ModernContainer` ning ichki gradienti yana yoqiladi (u faqat
///    shaffofsiz fonda ishlaydi).
///
/// 3. XOM RAQAMLAR TOKENLARGA ko'chirildi (`AppSpacing`, `AppRadius`,
///    `AppIconSize`).
///
/// HALOL QAYD — TUZATILMAGAN: "tinglash" tugmasi HECH QANDAY audio
/// chiqarmaydi, faqat SnackBar ko'rsatadi (`_toggleAudio`). Bu §6 ("fake
/// claim qilma") buzilishi, ammo tugmani olib tashlash FUNKSIYANI o'chirish
/// demak — u dizayn refaktori chegarasidan tashqarida va hisobotda alohida
/// band sifatida ko'rsatilgan.
class RelatableSummaryCard extends StatefulWidget {
  final String summary;

  /// `LegalResponse.source` — javob QAYERDAN kelgani. Faqat haqiqiy server
  /// modeli javobi `sourceLlm` bo'ladi (`legal_response.dart:103` fail-closed
  /// parse qiladi: aynan `'llm'` satridan boshqasi deterministik hisoblanadi).
  final String source;

  const RelatableSummaryCard({
    super.key,
    required this.summary,
    required this.source,
  });

  @override
  State<RelatableSummaryCard> createState() => _RelatableSummaryCardState();
}

class _RelatableSummaryCardState extends State<RelatableSummaryCard> {
  bool _isPlayingAudio = false;

  void _toggleAudio() {
    setState(() {
      _isPlayingAudio = !_isPlayingAudio;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isPlayingAudio
              ? context.l10n.aiAudioStarted
              : context.l10n.aiAudioStopped,
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _copySummary() {
    Clipboard.setData(ClipboardData(text: widget.summary));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.aiSummaryCopied),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;
    final isLlm = widget.source == LegalResponse.sourceLlm;
    // HALOLLIK: uchqun (`auto_awesome`) piktogrammasi FAQAT javob haqiqatan
    // model tahlili bo'lganda ishlatiladi. Deterministik matn ustida u
    // "bu AI yozdi" degan yolg'on signal berardi.
    final accent = isLlm ? AppTone.accentIndigo : AppTone.warning;
    final Color onAccent = accent.on(isDark);

    return ModernContainer(
      borderColor: accent.border(isDark),
      // 2-BAND: shaffofsiz fon. `alphaBlend` ilgarigi ko'rinishni AYNAN
      // beradi (#F9FAFF), lekin qiymat sahifa fonidan mustaqil bo'ladi.
      backgroundColor: isDark
          ? AppColors.cardDark
          : Color.alphaBlend(
              AppColors.indigoLight.withValues(alpha: 0.35),
              AppColors.cardLight,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: accent.bg(isDark),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  isLlm ? Icons.auto_awesome_rounded : Icons.rule_rounded,
                  color: onAccent,
                  size: AppIconSize.md,
                ),
              ),
              const Gap(AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.aiSummaryTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        // O'LCHOV: `indigoDark` (#4F46E5) yangi shaffofsiz fon
                        // (#F9FAFF) ustida 6.03:1 — AA'dan o'tadi.
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.indigoDark,
                      ),
                    ),
                    Text(
                      l10n.aiSummarySubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        // `textSecondaryLight` (#475569) shu fon ustida
                        // 7.27:1, `textSecondaryDark` `cardDark` ustida 9.6:1.
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              // Audio Listen & Copy Buttons
              IconButton(
                icon: Icon(
                  _isPlayingAudio
                      ? Icons.pause_circle_filled_rounded
                      : Icons.volume_up_rounded,
                  // O'LCHANGAN TUZATISH: ilgari `indigo` (#6366F1) edi va
                  // qorong'i kartada 3.27:1 berardi — boshqaruv elementi
                  // uchun WCAG 1.4.11 (3:1) chegarasida turardi.
                  // `accentIndigo.on()`: 6.03:1 / 5.91:1.
                  color: AppTone.accentIndigo.on(isDark),
                  size: AppIconSize.lg - 2,
                ),
                tooltip: l10n.actionListenAudio,
                onPressed: _toggleAudio,
              ),
              IconButton(
                icon: Icon(
                  Icons.copy_rounded,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  size: AppIconSize.md - 2,
                ),
                tooltip: l10n.actionCopy,
                onPressed: _copySummary,
              ),
            ],
          ),

          const Gap(AppSpacing.md),

          // Summary Body — "hujjat" o'qilishi: 1.6 qator balandligi va
          // yarim qalin shrift uzun huquqiy matnni skanerlashni osonlashtiradi.
          Text(
            widget.summary,
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),

          const Gap(AppSpacing.md),

          // Hairline ajratgich — pastdagi qator FUTER ekanini ko'rsatadi.
          Divider(height: 1, thickness: 1, color: AppBorders.hairline(isDark)),
          const Gap(AppSpacing.sm),

          // HALOLLIK BADGE'i — matn QAYERDAN kelgani.
          //
          // Kartaning ICHIDA turadi, chunki u aynan SHU matnga tegishli:
          // karta qaysi ekranga qo'yilsa, oshkora ma'lumot ham birga ketadi.
          // Ilgari badge chaqiruvchi sahifada alohida turgani uchun 4 ta
          // joydan faqat bittasida ko'rinardi.
          Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: AppIconSize.xs, color: onAccent),
              const Gap(AppSpacing.xs),
              Expanded(
                child: Text(
                  isLlm ? l10n.legalSourceLlm : l10n.legalSourceDeterministic,
                  // `StatusBadge` EMAS: manba matni uzun bo'lishi mumkin va
                  // `StatusBadge` da `maxLines`/`ellipsis` yo'q — kartaning
                  // to'liq kengligida u qatordan chiqib ketardi.
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
