import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/modern_container.dart';

/// Relatable Summary Card presenting plain-language takeaway with Audio Playback simulation and Copy actions
class RelatableSummaryCard extends StatefulWidget {
  final String summary;

  const RelatableSummaryCard({
    super.key,
    required this.summary,
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
                  color: AppColors.indigo.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.indigo,
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
        ],
      ),
    );
  }
}
