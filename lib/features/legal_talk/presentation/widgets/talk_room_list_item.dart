import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/theme/modern_container.dart';
import 'package:lexhub/features/legal_talk/domain/entities/talk_room.dart';

class TalkRoomListItem extends StatelessWidget {
  final TalkRoom room;
  final VoidCallback onTap;

  const TalkRoomListItem({
    super.key,
    required this.room,
    required this.onTap,
  });

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case "Mehnat":
        return Icons.work_outline_rounded;
      case "Haydovchilar":
        return Icons.directions_car_outlined;
      case "Advokat bilan":
        return Icons.gavel_rounded;
      case "Uy-joy":
        return Icons.home_work_outlined;
      default:
        return Icons.forum_outlined;
    }
  }

  Color _getCategoryColor(String category, bool isDark) {
    switch (category) {
      case "Mehnat":
        return isDark ? AppColors.indigo : AppColors.indigoDark;
      case "Haydovchilar":
        return isDark ? AppColors.lexBlueLight : AppColors.lexBlue;
      case "Advokat bilan":
        return isDark ? AppColors.emerald : AppColors.emeraldDark;
      case "Uy-joy":
        return isDark ? AppColors.amber : AppColors.amberDark;
      default:
        return isDark ? AppColors.indigo : AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final catColor = _getCategoryColor(room.category, isDark);

    return ModernContainer(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Category Icon & Title & Live status
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getCategoryIcon(room.category),
                  color: catColor,
                  size: 22,
                ),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: catColor.withValues(alpha: isDark ? 0.15 : 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            room.category,
                            style: TextStyle(
                              color: catColor,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (room.isLive) ...[
                          const Gap(6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.emergencyDarkBg : AppColors.emergencyLight,
                              borderRadius: BorderRadius.circular(4),
                              border: isDark ? Border.all(color: AppColors.emergencyDarkBorder) : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: const BoxDecoration(
                                    color: AppColors.crimson,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const Gap(4),
                                Text(
                                  "JONLI",
                                  style: TextStyle(
                                    color: isDark ? AppColors.emergencyDark : AppColors.crimsonDark,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const Gap(6),
                    Text(
                      room.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Gap(10),

          // Description
          Text(
            room.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              height: 1.4,
            ),
          ),

          const Gap(12),

          // Footer: Stats & CTA
          Row(
            children: [
              Icon(
                Icons.people_alt_outlined,
                size: 14,
                color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
              ),
              const Gap(4),
              Text(
                "${room.participantsCount} ishtirokchi",
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                "Munozaraga qo'shilish",
                style: TextStyle(
                  color: isDark ? AppColors.indigo : AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Gap(4),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: isDark ? AppColors.indigo : AppColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
