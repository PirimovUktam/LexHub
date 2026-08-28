import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/modern_container.dart';
import 'package:lexhub/core/theme/tone.dart';
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
            Text(
              l10n.emergencyMirandaLawQuote,
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
            const Gap(12),
            // O'LCHANGAN DEFEKT: qorong'ida `indigo` dialog foni
            // (`surfaceDark`) ustida 4.00:1 — 14 px QALIN matn KATTA matn
            // EMAS (bold uchun chegara 18.66 px), ya'ni AA 4.5:1 dan past.
            // Ton: 8.96:1. Yorug' tomon `primary` bilan 17.85:1 — o'zgarmadi.
            Text(
              l10n.emergencyMirandaScriptLabel,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? AppTone.accentIndigo.on(true) : AppColors.primary,
              ),
            ),
            const Gap(4),
            // §16: `en` tarjimasi O'ZBEK matnini SAQLAYDI va tagiga inglizcha
            // izoh qo'shadi. Sababi: bu — foydalanuvchi xodimga AYTADIGAN
            // so'z. Uni faqat inglizchaga o'girish foydalanuvchini O'zbekiston
            // militsiyasi xodimiga tushunarsiz gap aytishga majbur qilardi,
            // ya'ni tarjima UNGA ZARAR yetkazardi.
            Text(
              l10n.emergencyMirandaScriptText,
              style: const TextStyle(fontWeight: FontWeight.w600),
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
                      // O'LCHANGAN DEFEKT: sarlavha XOM aksent, foni esa
                      // qizil tint (`emergencyLight` / `emergencyDarkBg`) edi
                      // — yorug'da 3.95:1, ya'ni 14 px w800 matn uchun AA
                      // (4.5:1) dan PAST. Ton: 5.30 / 8.98.
                      Text(
                        l10n.aiEmergencyAlertTitle,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: AppTone.danger.on(isDark),
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
              // AYNI DEFEKT (yorug' 3.95:1 -> 5.30:1).
              Text(
                l10n.emergencyRedFlagsTitle,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppTone.danger.on(isDark),
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
                      // O'LCHANGAN: ikonka IKKI mavzuda ham bir xil XOM
                      // `emergency` edi — qizil tint ustida yorug'da 3.08:1,
                      // ya'ni 1.4.11 (3:1) chegarasida turardi: tint alfasi
                      // bir qadam quyuqlashsa yiqilardi. Ton: 5.30 / 8.98.
                      Icon(
                        Icons.cancel_rounded,
                        size: 16,
                        color: AppTone.danger.on(isDark),
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
              // AYNI DEFEKT (yorug' 3.95:1 -> 5.30:1).
              Text(
                l10n.emergencyImmediateActionsTitle,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppTone.danger.on(isDark),
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
                      // O'LCHANGAN: yorug'da `emeraldDark` qizil tint ustida
                      // 3.08:1 — 1.4.11 chegarasida. Ton: 6.29 / 8.87.
                      Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: AppTone.success.on(isDark),
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
                      // `emergency` (#EF4444) EMAS: oq matn ustida 3.76:1 —
                      // WCAG AA'dan past. Bu ilovadagi eng muhim tugma
                      // (hibsga olinganda ishonch telefoni), shuning uchun
                      // matn kontrasti bo'yicha yon berilmaydi: 6.47:1.
                      backgroundColor: AppColors.emergencyStrong,
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
                    // O'LCHANGAN DEFEKT (ikkita):
                    //  1) yorliq (13 px qalin) yorug'da 3.95:1 — AA'dan past;
                    //     ton bilan 5.30 / 8.98.
                    //  2) CHEGARA — tugmaning yagona chekka signali, chunki
                    //     foni banner tinti bilan AYNI. `emergencyBorder`
                    //     `emergencyLight` ustida 1.55:1, qorong'ida
                    //     `emergencyDarkBorder` `emergencyDarkBg` ustida
                    //     1.40:1 — 1.4.11 (3:1) BUZILGAN, ya'ni tugma chekkasi
                    //     amalda ko'rinmasdi. Aksent bilan 3.95 / 4.53.
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTone.danger.on(isDark),
                      side: BorderSide(
                        color: isDark
                            ? AppColors.crimson
                            : AppColors.crimsonDark,
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
