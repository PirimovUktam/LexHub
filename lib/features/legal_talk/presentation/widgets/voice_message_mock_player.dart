import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';

class VoiceMessageMockPlayer extends StatefulWidget {
  final String duration;
  final bool isLawyer;

  const VoiceMessageMockPlayer({
    super.key,
    required this.duration,
    this.isLawyer = false,
  });

  @override
  State<VoiceMessageMockPlayer> createState() => _VoiceMessageMockPlayerState();
}

class _VoiceMessageMockPlayerState extends State<VoiceMessageMockPlayer> {
  bool _isPlaying = false;

  void _togglePlay() {
    setState(() {
      _isPlaying = !_isPlaying;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = widget.isLawyer
        ? (isDark ? AppColors.accent : AppColors.accentDark)
        : (isDark ? AppColors.indigo : AppColors.primary);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: primaryColor.withValues(alpha: isDark ? 0.3 : 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: _togglePlay,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: primaryColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const Gap(10),
          // Waveform bars simulation
          Row(
            children: [4, 12, 8, 16, 20, 14, 10, 18, 12, 6, 14, 8].map((h) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                width: 3,
                height: h.toDouble(),
                decoration: BoxDecoration(
                  color: _isPlaying
                      ? primaryColor
                      : primaryColor.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }).toList(),
          ),
          const Gap(10),
          Text(
            widget.duration,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}
