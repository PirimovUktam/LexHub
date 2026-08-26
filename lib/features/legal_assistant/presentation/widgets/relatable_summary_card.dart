import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/modern_container.dart';
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
    final accent = isLlm ? AppColors.indigo : AppColors.amber;

    return ModernContainer(
      borderColor: AppColors.indigo.withValues(alpha: 0.2),
      backgroundColor: isDark
          ? AppColors.cardDark
          : AppColors.indigoLight.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isLlm ? Icons.auto_awesome_rounded : Icons.rule_rounded,
                  color: accent,
                  size: 20,
                ),
              ),
              const Gap(10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.aiSummaryTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.indigoDark,
                      ),
                    ),
                    Text(
                      l10n.aiSummarySubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
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
                  color: AppColors.indigo,
                  size: 24,
                ),
                tooltip: l10n.actionListenAudio,
                onPressed: _toggleAudio,
              ),
              IconButton(
                icon: Icon(
                  Icons.copy_rounded,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  size: 20,
                ),
                tooltip: l10n.actionCopy,
                onPressed: _copySummary,
              ),
            ],
          ),

          const Gap(12),

          // Summary Body
          Text(
            widget.summary,
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),

          const Gap(12),

          // HALOLLIK BADGE'i — matn QAYERDAN kelgani.
          //
          // Kartaning ICHIDA turadi, chunki u aynan SHU matnga tegishli:
          // karta qaysi ekranga qo'yilsa, oshkora ma'lumot ham birga ketadi.
          // Ilgari badge chaqiruvchi sahifada alohida turgani uchun 4 ta
          // joydan faqat bittasida ko'rinardi.
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 14, color: accent),
              const Gap(6),
              Expanded(
                child: Text(
                  isLlm ? l10n.legalSourceLlm : l10n.legalSourceDeterministic,
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
