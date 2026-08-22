import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/theme/modern_container.dart';
import 'package:lexhub/features/legal_talk/domain/entities/talk_room.dart';

class LiveRoomCard extends StatefulWidget {
  final TalkRoom room;
  final VoidCallback onTap;

  const LiveRoomCard({
    super.key,
    required this.room,
    required this.onTap,
  });

  @override
  State<LiveRoomCard> createState() => _LiveRoomCardState();
}

class _LiveRoomCardState extends State<LiveRoomCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final room = widget.room;

    return SizedBox(
      width: 280,
      child: ModernContainer(
        onTap: widget.onTap,
        padding: const EdgeInsets.all(16),
        backgroundColor: isDark
            ? AppColors.cardDark
            : Colors.white,
        borderColor: isDark
            ? AppColors.crimson.withValues(alpha: 0.35)
            : AppColors.crimson.withValues(alpha: 0.25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
          // Top Row: Live Pulse Badge & Active count
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.emergencyDarkBg
                      : AppColors.emergencyLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? AppColors.emergencyDarkBorder
                        : AppColors.crimson.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: AppColors.crimson,
                              shape: BoxShape.circle,
                            ),
                          ),
                        );
                      },
                    ),
                    const Gap(6),
                    Text(
                      "JONLI EFIR",
                      style: TextStyle(
                        color: isDark ? AppColors.emergencyDark : AppColors.crimsonDark,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Icon(
                    Icons.headphones_rounded,
                    size: 14,
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                  ),
                  const Gap(4),
                  Text(
                    "${room.activeNowCount} onlayn",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const Gap(10),

          // Title
          Text(
            room.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),

          const Gap(4),

          // Description preview
          Text(
            room.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              fontSize: 11,
              height: 1.35,
            ),
          ),

          const Gap(12),

          // Bottom: Category chip and Join CTA
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.indigo.withValues(alpha: 0.15)
                      : AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  room.category,
                  style: TextStyle(
                    color: isDark ? AppColors.indigo : AppColors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Row(
                children: [
                  Text(
                    "Kirish",
                    style: TextStyle(
                      color: isDark ? AppColors.indigo : AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Gap(2),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: isDark ? AppColors.indigo : AppColors.primary,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
}
