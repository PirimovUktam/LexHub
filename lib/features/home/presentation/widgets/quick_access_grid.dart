/// Bosh sahifadagi asosiy xizmatlar va barcha mavjud ekranlarga kirish.
///
/// NIMA UCHUN: ilgali bosh sahifada har bir bo'lim uchun alohida katta
/// banner bor edi (favqulodda banner, xizmatlar banneri, FAQ banneri,
/// hamjamiyat banneri...) — foydalanuvchi 4 marta skroll qilib ham
/// "ilova nima qila oladi" degan savolga javob topmasdi. Panjara barcha
/// asosiy yo'nalishlarni BITTA ekran maydonida ko'rsatadi.
///
/// MUHIM QOIDA: har bir plitka MAVJUD, ISHLAYDIGAN ekranga olib boradi.
/// Dizayn namunasidagi plitkalar orasida LexHub'da real backend'i bo'lmagani
/// (masalan "Huquqiy yangiliklar" tasmasi) ATAYLAB olinmadi — bo'sh yoki
/// soxta ekran ko'rsatish §21 ("no fake data") ga zid.
library;

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/app_dimens.dart';
import 'package:lexhub/core/theme/tone.dart';
import 'package:lexhub/features/citizen_services/presentation/pages/citizen_services_page.dart';
import 'package:lexhub/features/community_forum/presentation/pages/community_forum_page.dart';
import 'package:lexhub/features/consultations/presentation/pages/my_consultations_page.dart';
import 'package:lexhub/features/document_builder/presentation/pages/document_templates_page.dart';
import 'package:lexhub/features/emergency_rights/presentation/pages/emergency_rights_page.dart';
import 'package:lexhub/features/home/presentation/pages/faq_questions_page.dart';
import 'package:lexhub/features/legal_experts/presentation/pages/legal_experts_page.dart';
import 'package:lexhub/features/saved_cases/presentation/pages/saved_cases_page.dart';
import 'package:lexhub/features/settings/presentation/pages/settings_page.dart';

/// Bitta plitkaning ma'lumoti — `label` ARB'dan, `onTap` real navigatsiya.
class _QuickItem {
  const _QuickItem({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class QuickAccessGrid extends StatelessWidget {
  const QuickAccessGrid({
    super.key,
    required this.onAskAITap,
    this.onSendQueryToAI,
  });

  /// Markaziy "Maslahat" bo'limiga o'tish — `MainNavigationPage` beradi,
  /// shuning uchun `IndexedStack` holati saqlanadi (yangi sahifa PUSH
  /// qilinmaydi).
  final VoidCallback? onAskAITap;

  final ValueChanged<String>? onSendQueryToAI;

  void _push(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  List<_QuickItem> _items(BuildContext context) {
    final l10n = context.l10n;
    return [
      _QuickItem(
        // HALOLLIK (§6): yorliq "AI Yordamchi" EMAS. Server modeli faqat
        // tizimga kirgan foydalanuvchi uchun chaqiriladi, aks holda
        // qurilmadagi tekshirilgan qonun bazasi ishlaydi — shuning uchun
        // shartsiz "AI" da'vosi qilinmaydi.
        label: l10n.navAI,
        subtitle: l10n.homeQuickAdviceSubtitle,
        icon: Icons.chat_rounded,
        color: AppColors.lexBlue,
        onTap: () => onAskAITap?.call(),
      ),
      _QuickItem(
        label: l10n.navExperts,
        subtitle: l10n.homeQuickExpertsSubtitle,
        icon: Icons.groups_rounded,
        color: AppColors.amber,
        onTap: () => _push(context, const LegalExpertsPage()),
      ),
      _QuickItem(
        label: l10n.homeQuickDocuments,
        subtitle: l10n.homeQuickDocumentsSubtitle,
        icon: Icons.description_rounded,
        color: AppColors.indigo,
        onTap: () => _push(context, const DocumentTemplatesPage()),
      ),
      _QuickItem(
        label: l10n.navServices,
        subtitle: l10n.homeQuickServicesSubtitle,
        icon: Icons.account_balance_rounded,
        color: AppColors.emerald,
        onTap: () => _push(context, const CitizenServicesPage()),
      ),
      _QuickItem(
        label: l10n.homeQuickEmergency,
        subtitle: l10n.homeQuickEmergencySubtitle,
        icon: Icons.shield_rounded,
        color: AppColors.crimson,
        onTap: () => _push(context, const EmergencyRightsPage()),
      ),
      _QuickItem(
        label: l10n.homeQuickMore,
        subtitle: l10n.homeQuickMoreSubtitle,
        icon: Icons.grid_view_rounded,
        color: AppColors.lexBlueDark,
        onTap: () => _showMoreSheet(context),
      ),
    ];
  }

  /// "Ko'proq" varag'i — bu yerda ham FAQAT mavjud ekranlar bor.
  void _showMoreSheet(BuildContext context) {
    final l10n = context.l10n;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.groups_outlined),
                title: Text(l10n.navCommunity),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _push(
                    context,
                    CommunityForumPage(onSendQueryToAI: onSendQueryToAI),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.bookmark_outline_rounded),
                title: Text(l10n.homeQuickSaved),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _push(context, const SavedCasesPage());
                },
              ),
              ListTile(
                leading: const Icon(Icons.help_outline_rounded),
                title: Text(l10n.faqBannerTitle),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _push(context, const FaqQuestionsPage());
                },
              ),
              ListTile(
                leading: const Icon(Icons.event_note_outlined),
                title: Text(l10n.cabinetTabConsultations),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _push(context, const MyConsultationsPage());
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: Text(l10n.settingsTitle),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(context, SettingsPage.route());
                },
              ),
              const Gap(AppSpacing.sm),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _items(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final columns = constraints.maxWidth / textScale >= 320
            ? 3
            : constraints.maxWidth / textScale >= 220
                ? 2
                : 1;

        // Content sets the height; large text reflows into fewer columns.
        return Column(
          children: [
            for (var start = 0; start < items.length; start += columns) ...[
              if (start > 0) const Gap(AppSpacing.md),
              _QuickRow(items: items.skip(start).take(columns).toList()),
            ],
          ],
        );
      },
    );
  }
}

class _QuickRow extends StatelessWidget {
  const _QuickRow({required this.items});

  final List<_QuickItem> items;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < items.length; index++) ...[
            if (index > 0) const Gap(AppSpacing.md),
            Expanded(child: _QuickTile(item: items[index])),
          ],
        ],
      ),
    );
  }
}

/// Bitta tezkor kirish plitkasi.
///
/// `StatefulWidget` FAQAT bosish reaksiyasi uchun — plitka hech qanday
/// ma'lumot saqlamaydi. Reaksiya `InkWell.onHighlightChanged` dan olinadi;
/// tashqi `GestureDetector` qo'shilsa u `InkWell` bilan gesture arena'da
/// kurashadi va bosish YO'QOLISHI mumkin.
class _QuickTile extends StatefulWidget {
  const _QuickTile({required this.item});

  final _QuickItem item;

  @override
  State<_QuickTile> createState() => _QuickTileState();
}

class _QuickTileState extends State<_QuickTile> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final item = widget.item;
    final tone = AppTone.forRawAccent(item.color);
    final base = isDark ? AppColors.cardDark : AppColors.cardLight;
    final foreground = tone.on(isDark);

    return Semantics(
      button: true,
      // `label:` YO'Q: ostidagi `Text(item.label)` semantikasi shu qobiqqa
      // qo'shiladi va yorliq ekran o'quvchida ikki marta o'qilardi.
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: AppMotion.of(context, AppMotion.fast),
        curve: AppMotion.curve,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(tone.bg(isDark, alpha: 0.14), base),
                  Color.alphaBlend(tone.bg(isDark, alpha: 0.07), base),
                ],
              ),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: InkWell(
              onTap: item.onTap,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              onHighlightChanged: (bool value) {
                if (_down == value) return;
                setState(() => _down = value);
              },
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: AppIconSize.empty - AppSpacing.sm,
                      height: AppIconSize.empty - AppSpacing.sm,
                      decoration: BoxDecoration(
                        color: Color.alphaBlend(
                          tone.bg(isDark, alpha: 0.20),
                          base,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(
                        item.icon,
                        size: AppIconSize.lg,
                        color: foreground,
                      ),
                    ),
                    const Gap(AppSpacing.sm),
                    Text(
                      item.label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const Gap(AppSpacing.xxs),
                    Text(
                      item.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                        height: 1.3,
                      ),
                    ),
                    const Spacer(),
                    const Gap(AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.xxs),
                      decoration: BoxDecoration(
                        color: base,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: tone.border(isDark),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: AppIconSize.sm,
                        color: foreground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
