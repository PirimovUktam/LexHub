import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/modern_container.dart';

/// Interactive Action Steps Timeline where users can mark progress and follow step-by-step guidance
class ActionStepsTimeline extends StatefulWidget {
  final List<String> steps;

  const ActionStepsTimeline({
    super.key,
    required this.steps,
  });

  @override
  State<ActionStepsTimeline> createState() => _ActionStepsTimelineState();
}

class _ActionStepsTimelineState extends State<ActionStepsTimeline> {
  final Set<int> _completedStepIndices = {};

  void _toggleStep(int index) {
    setState(() {
      if (_completedStepIndices.contains(index)) {
        _completedStepIndices.remove(index);
      } else {
        _completedStepIndices.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;
    final steps = widget.steps;

    if (steps.isEmpty) return const SizedBox.shrink();

    final completedCount = _completedStepIndices.length;
    final totalCount = steps.length;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

    return ModernContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Progress
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.emerald.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.playlist_add_check_circle_rounded,
                  color: AppColors.emerald,
                  size: 20,
                ),
              ),
              const Gap(10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.aiStepsTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      l10n.aiStepsProgress(completedCount, totalCount),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? AppColors.emerald : AppColors.emeraldDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // Percentage Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.emeraldDarkBg : AppColors.emeraldLight,
                  borderRadius: BorderRadius.circular(20),
                  border: isDark ? Border.all(color: AppColors.emeraldDarkBorder) : null,
                ),
                child: Text(
                  "${(progress * 100).toInt()}%",
                  style: TextStyle(
                    color: isDark ? AppColors.emerald : AppColors.emeraldDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          const Gap(10),

          // Linear Progress indicator
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: isDark ? AppColors.borderDark : AppColors.borderLight,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.emerald),
              minHeight: 5,
            ),
          ),

          const Gap(16),

          // Interactive Steps Timeline List
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: steps.length,
            itemBuilder: (context, index) {
              final isCompleted = _completedStepIndices.contains(index);
              final isLast = index == steps.length - 1;
              final stepNumber = index + 1;

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Timeline Node + Connecting Line
                    Column(
                      children: [
                        InkWell(
                          onTap: () => _toggleStep(index),
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? AppColors.emerald
                                  : (isDark ? AppColors.indigo : AppColors.primary),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: (isCompleted
                                          ? AppColors.emerald
                                          : (isDark ? AppColors.indigo : AppColors.primary))
                                      .withValues(alpha: 0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: isCompleted
                                  ? const Icon(
                                      Icons.check_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    )
                                  : Text(
                                      '$stepNumber',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 2,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              color: isCompleted
                                  ? AppColors.emerald.withValues(alpha: 0.5)
                                  : (isDark ? AppColors.borderDark : AppColors.borderLight),
                            ),
                          ),
                      ],
                    ),

                    const Gap(14),

                    // Step Content
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
                        child: InkWell(
                          onTap: () => _toggleStep(index),
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              steps[index],
                              style: theme.textTheme.bodyMedium?.copyWith(
                                decoration: isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: isCompleted
                                    ? (isDark ? AppColors.textMutedDark : AppColors.textMutedLight)
                                    : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                                fontWeight: isCompleted
                                    ? FontWeight.normal
                                    : FontWeight.w500,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
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
