import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/theme/modern_container.dart';
import 'package:shimmer/shimmer.dart';

/// Skeleton Shimmer Loading UI with dynamic legal status animation
class LegalAnalysisShimmer extends StatefulWidget {
  const LegalAnalysisShimmer({super.key});

  @override
  State<LegalAnalysisShimmer> createState() => _LegalAnalysisShimmerState();
}

class _LegalAnalysisShimmerState extends State<LegalAnalysisShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _currentStepIndex = 0;

  final List<String> _stages = [
    "Qonunchilik bazasidan moddalar qidirilmoqda...",
    "Lex.uz me'yoriy hujjatlari taqqoslanmoqda...",
    "Protsessual muddatlar va xavflar baholanmoqda...",
    "Oddiy tildagi xulosa va harakatlar rejasi tayyorlanmoqda...",
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..addListener(() {
        final step = (_controller.value * _stages.length).floor();
        if (step != _currentStepIndex && step < _stages.length) {
          setState(() {
            _currentStepIndex = step;
          });
        }
      });
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final baseColor = isDark ? AppColors.cardDark : Colors.grey.shade200;
    final highlightColor = isDark ? AppColors.borderDark : Colors.grey.shade50;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Live animated status banner
        ModernContainer(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          backgroundColor: AppColors.indigo.withValues(alpha: 0.08),
          borderColor: AppColors.indigo.withValues(alpha: 0.25),
          child: Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.indigo),
                ),
              ),
              const Gap(12),
              Expanded(
                child: Text(
                  _stages[_currentStepIndex],
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? AppColors.indigoLight : AppColors.indigoDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        const Gap(16),

        // Shimmer Skeleton Blocks
        Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: Column(
            children: [
              // Summary card skeleton
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              const Gap(14),

              // Actionable steps skeleton
              Container(
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              const Gap(14),

              // Legal basis skeleton
              Container(
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              const Gap(14),

              // Risk assessment skeleton
              Container(
                height: 110,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
