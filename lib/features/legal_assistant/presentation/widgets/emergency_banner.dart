import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/emergency_protocol.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyBanner extends StatelessWidget {
  final EmergencyProtocol protocol;

  const EmergencyBanner({
    super.key,
    required this.protocol,
  });

  Future<void> _callHotline(BuildContext context, String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.emergencyCallFailed(phone)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.emergencyDarkBg : AppColors.emergencyLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.emergencyDarkBorder : AppColors.emergencyBorder,
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.emergency,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.aiEmergencyAlertTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: isDark ? AppColors.crimson : AppColors.emergency,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      protocol.title,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? AppColors.textPrimaryDark : AppColors.primaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (protocol.redFlags.isNotEmpty) ...[
            const Gap(12),
            Text(
              l10n.emergencyRedFlagsTitle,
              style: theme.textTheme.labelLarge?.copyWith(
                color: isDark ? AppColors.crimson : AppColors.emergency,
              ),
            ),
            const Gap(4),
            ...protocol.redFlags.map(
              (flag) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.cancel,
                      size: 16,
                      color: AppColors.emergency,
                    ),
                    const Gap(8),
                    Expanded(
                      child: Text(
                        flag,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (protocol.constitutionalRights.isNotEmpty) ...[
            const Gap(10),
            Text(
              l10n.emergencyConstitutionalRightsTitle,
              style: theme.textTheme.labelLarge?.copyWith(
                color: isDark ? AppColors.indigo : AppColors.primary,
              ),
            ),
            const Gap(4),
            ...protocol.constitutionalRights.map(
              (right) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.gavel_rounded,
                      size: 16,
                      color: isDark ? AppColors.indigo : AppColors.primary,
                    ),
                    const Gap(8),
                    Expanded(
                      child: Text(
                        right,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (protocol.immediateActions.isNotEmpty) ...[
            const Gap(10),
            Text(
              l10n.emergencyImmediateActionsTitle,
              style: theme.textTheme.labelLarge?.copyWith(
                color: isDark ? AppColors.crimson : AppColors.emergency,
              ),
            ),
            const Gap(4),
            ...protocol.immediateActions.map(
              (action) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: isDark ? AppColors.emerald : AppColors.emergency,
                    ),
                    const Gap(8),
                    Expanded(
                      child: Text(
                        action,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const Gap(14),
          ElevatedButton.icon(
            onPressed: () => _callHotline(context, protocol.emergencyHotline),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emergency,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.phone_in_talk_rounded, size: 20),
            label: Text(
              "${l10n.actionCallHotline} (${protocol.emergencyHotline})",
            ),
          ),
        ],
      ),
    );
  }
}
