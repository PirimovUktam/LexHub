import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/modern_container.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/emergency_protocol.dart';
import 'package:url_launcher/url_launcher.dart';

/// Animated Emergency Banner for immediate legal self-defense and constitutional rights
class EmergencyBannerWidget extends StatefulWidget {
  final EmergencyProtocol protocol;

  const EmergencyBannerWidget({
    super.key,
    required this.protocol,
  });

  @override
  State<EmergencyBannerWidget> createState() => _EmergencyBannerWidgetState();
}

class _EmergencyBannerWidgetState extends State<EmergencyBannerWidget>
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

    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _callPhone(BuildContext context, String phone) async {
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

  void _showMirandaDialog(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.security_rounded, color: AppColors.emergency),
            const Gap(10),
            Expanded(
              child: Text(
                l10n.emergencyMirandaTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.emergencyMirandaArticleLabel,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Gap(8),
            const Text(
              "\"Ushlab turish chog'ida shaxsga uning huquqlari va ushlab turilishi asoslari tushunarli tilda tushuntirilishi shart.\"",
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
            const Gap(12),
            Text(
              l10n.emergencyMirandaScriptLabel,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.indigo : AppColors.primary,
              ),
            ),
            const Gap(4),
            const Text(
              "\"Men O'zbekiston Konstitutsiyasining 28 va 29-moddalariga asosan, advokatim yetib kelmaguncha har qanday ko'rsatma berishdan bosh tortaman va sukut saqlash huquqimdan foydalanaman.\"",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.actionOk),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;
    final protocol = widget.protocol;

    return ScaleTransition(
      scale: _pulseAnimation,
      child: ModernContainer(
        backgroundColor: isDark ? AppColors.emergencyDarkBg : AppColors.emergencyLight,
        borderColor: isDark ? AppColors.emergencyDarkBorder : AppColors.emergencyBorder,
        borderWidth: 1.5,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.emergency,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.aiEmergencyAlertTitle,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: isDark ? AppColors.crimson : AppColors.crimsonDark,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        protocol.title,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (protocol.redFlags.isNotEmpty) ...[
              const Gap(14),
              Text(
                l10n.emergencyRedFlagsTitle,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: isDark ? AppColors.crimson : AppColors.crimsonDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Gap(6),
              ...protocol.redFlags.map(
                (flag) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.cancel_rounded,
                        size: 16,
                        color: AppColors.emergency,
                      ),
                      const Gap(8),
                      Expanded(
                        child: Text(
                          flag,
                          style: theme.textTheme.bodyMedium?.copyWith(
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
              const Gap(12),
              Text(
                l10n.emergencyImmediateActionsTitle,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: isDark ? AppColors.crimson : AppColors.crimsonDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Gap(6),
              ...protocol.immediateActions.map(
                (action) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: isDark ? AppColors.emerald : AppColors.emeraldDark,
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

            const Gap(16),

            // Speed Dial & Miranda Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _callPhone(context, protocol.emergencyHotline),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emergency,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(46),
                    ),
                    icon: const Icon(Icons.phone_in_talk_rounded, size: 18),
                    label: Text(
                      l10n.emergencyCallAction(protocol.emergencyHotline),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const Gap(10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showMirandaDialog(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? AppColors.crimson : AppColors.crimsonDark,
                      side: BorderSide(
                        color: isDark ? AppColors.emergencyDarkBorder : AppColors.emergency,
                        width: 1.5,
                      ),
                      minimumSize: const Size.fromHeight(46),
                    ),
                    icon: const Icon(Icons.gavel_rounded, size: 18),
                    label: Text(
                      l10n.emergencyMirandaTitle,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
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
