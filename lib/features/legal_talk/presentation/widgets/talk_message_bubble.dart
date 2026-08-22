import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/theme/modern_container.dart';
import 'package:lexhub/features/legal_talk/domain/entities/talk_message.dart';
import 'package:lexhub/features/legal_talk/presentation/widgets/voice_message_mock_player.dart';
import 'package:intl/intl.dart';

class TalkMessageBubble extends StatelessWidget {
  final TalkMessage message;
  final VoidCallback onLikeTap;

  const TalkMessageBubble({
    super.key,
    required this.message,
    required this.onLikeTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final formattedTime = DateFormat('HH:mm').format(message.timestamp);

    final isLawyer = message.senderRole == TalkSenderRole.verifiedLawyer;
    final isModerator = message.senderRole == TalkSenderRole.moderator;

    // Moderator Announcement Card
    if (isModerator) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ModernContainer(
          padding: const EdgeInsets.all(12),
          backgroundColor: isDark
              ? AppColors.indigo.withValues(alpha: 0.12)
              : AppColors.indigoLight.withValues(alpha: 0.5),
          borderColor: isDark
              ? AppColors.indigo.withValues(alpha: 0.3)
              : AppColors.indigo.withValues(alpha: 0.2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.campaign_rounded,
                color: AppColors.indigo,
                size: 20,
              ),
              const Gap(10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          message.senderName,
                          style: const TextStyle(
                            color: AppColors.indigo,
                            fontWeight: FontWeight.bold,
                            fontSize: 11.5,
                          ),
                        ),
                        if (message.isPinned) ...[
                          const Gap(6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.indigo.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              "Qadalgan",
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppColors.indigo,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        Text(
                          formattedTime,
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                          ),
                        ),
                      ],
                    ),
                    const Gap(4),
                    Text(
                      message.messageText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Lawyer or Citizen Message
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ModernContainer(
        padding: const EdgeInsets.all(14),
        backgroundColor: isLawyer
            ? (isDark
                ? AppColors.amberDarkBg.withValues(alpha: 0.8)
                : const Color(0xFFFFFBEB))
            : (isDark
                ? AppColors.cardDark
                : Colors.white),
        borderColor: isLawyer
            ? (isDark
                ? AppColors.amber.withValues(alpha: 0.45)
                : AppColors.amber.withValues(alpha: 0.35))
            : (isDark
                ? AppColors.borderDark
                : AppColors.borderLight),
        borderWidth: isLawyer ? 1.5 : 1.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sender info & Verified badge & Time
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: isLawyer
                      ? (isDark ? AppColors.amberDarkBg : AppColors.amberLight)
                      : (isDark ? AppColors.indigo.withValues(alpha: 0.2) : AppColors.primary.withValues(alpha: 0.08)),
                  child: Icon(
                    isLawyer ? Icons.gavel_rounded : Icons.person_rounded,
                    size: 16,
                    color: isLawyer
                        ? (isDark ? AppColors.amber : AppColors.amberDark)
                        : (isDark ? AppColors.indigo : AppColors.primary),
                  ),
                ),
                const Gap(8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              message.senderName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (isLawyer) ...[
                            const Gap(6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.amberDarkBg : AppColors.amberLight,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isDark ? AppColors.amberDarkBorder : AppColors.amber.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.verified_rounded,
                                    size: 11,
                                    color: isDark ? AppColors.amber : AppColors.amberDark,
                                  ),
                                  const Gap(3),
                                  Text(
                                    "Verified Advokat",
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? AppColors.amber : AppColors.amberDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  formattedTime,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                  ),
                ),
              ],
            ),

            const Gap(10),

            // Message text
            SelectableText(
              message.messageText,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.45,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),

            if (message.isAudioMessage && message.audioDuration != null) ...[
              const Gap(10),
              VoiceMessageMockPlayer(
                duration: message.audioDuration!,
                isLawyer: isLawyer,
              ),
            ],

            const Gap(10),

            // Footer: Like action & Privacy indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 12,
                      color: isDark ? AppColors.emerald : AppColors.emeraldDark,
                    ),
                    const Gap(4),
                    Text(
                      "Privacy Guard",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.emerald : AppColors.emeraldDark,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: onLikeTap,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          message.isLikedByMe
                              ? Icons.thumb_up_rounded
                              : Icons.thumb_up_alt_outlined,
                          size: 15,
                          color: message.isLikedByMe
                              ? (isDark ? AppColors.indigo : AppColors.primary)
                              : (isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                        ),
                        const Gap(4),
                        Text(
                          "${message.likesCount}",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: message.isLikedByMe
                                ? (isDark ? AppColors.indigo : AppColors.primary)
                                : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
