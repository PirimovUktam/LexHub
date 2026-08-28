/// TEZKOR KIRISH PANJARASI — bosh sahifadagi 2×4 plitka.
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
import 'package:lexhub/core/theme/section_header.dart';
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
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
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
        icon: Icons.forum_outlined,
        color: AppColors.indigo,
        onTap: () => onAskAITap?.call(),
      ),
      _QuickItem(
        label: l10n.navCommunity,
        icon: Icons.groups_outlined,
        color: AppColors.lexBlue,
        onTap: () => _push(
          context,
          CommunityForumPage(onSendQueryToAI: onSendQueryToAI),
        ),
      ),
      _QuickItem(
        label: l10n.navExperts,
        icon: Icons.workspace_premium_outlined,
        color: AppColors.amberDark,
        onTap: () => _push(context, const LegalExpertsPage()),
      ),
      _QuickItem(
        label: l10n.homeQuickDocuments,
        icon: Icons.description_outlined,
        color: AppColors.primaryContainer,
        onTap: () => _push(context, const DocumentTemplatesPage()),
      ),
      _QuickItem(
        label: l10n.navServices,
        icon: Icons.account_balance_outlined,
        color: AppColors.emeraldDark,
        onTap: () => _push(context, const CitizenServicesPage()),
      ),
      _QuickItem(
        label: l10n.homeQuickSaved,
        icon: Icons.bookmark_outline_rounded,
        color: AppColors.lexBlueDark,
        onTap: () => _push(context, const SavedCasesPage()),
      ),
      _QuickItem(
        label: l10n.homeQuickEmergency,
        icon: Icons.shield_outlined,
        color: AppColors.crimsonDark,
        onTap: () => _push(context, const EmergencyRightsPage()),
      ),
      _QuickItem(
        label: l10n.homeQuickMore,
        icon: Icons.apps_rounded,
        color: AppColors.textSecondaryLight,
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: context.l10n.homeQuickAccessTitle,
          actionLabel: context.l10n.actionSeeAll,
          onAction: () => _showMoreSheet(context),
        ),
        const Gap(AppSpacing.md),
        // `GridView` ATAYLAB ishlatilmadi: `childAspectRatio` fiksatsiyalangan
        // bo'ladi va katta shrift masshtabida (`textScaleFactor` 1.5+) ikki
        // qatorli yorliq plitkadan chiqib ketardi. Ikki `Row` esa balandligini
        // mazmuniga qarab o'zi oladi.
        _QuickRow(items: items.sublist(0, 4)),
        const Gap(AppSpacing.md),
        _QuickRow(items: items.sublist(4)),
      ],
    );
  }
}

class _QuickRow extends StatelessWidget {
  const _QuickRow({required this.items});

  final List<_QuickItem> items;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items) Expanded(child: _QuickTile(item: item)),
      ],
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({required this.item});

  final _QuickItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Semantics(
      button: true,
      // `label:` YO'Q: ostidagi `Text(item.label)` semantikasi shu qobiqqa
      // qo'shiladi va yorliq ekran o'quvchida ikki marta o'qilardi.
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxs,
            vertical: AppSpacing.xs,
          ),
          child: Column(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: isDark ? 0.22 : 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  item.icon,
                  size: AppIconSize.md,
                  color: isDark ? _lighten(item.color) : item.color,
                ),
              ),
              const Gap(AppSpacing.xs),
              Text(
                item.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                // RANG ATAYLAB OSHIRILGAN: mavzudagi `bodySmall`
                // (`textMutedLight`) bu izoh yozilganda #94A3B8 edi va oq fon
                // ustida 2.56:1 berardi — WCAG AA (4.5:1) dan past. Token
                // keyinroq #64748B ga tuzatildi (4.76:1) va endi AA'dan
                // o'tadi; bu yer esa `textSecondary*` da QOLADI, chunki
                // yorliq plitkaning YAGONA nomi va 10.5 px o'lchamda —
                // 7.58:1 zaxira ataylab saqlanadi.
                // Qulf: `test/core/theme/color_contrast_test.dart`.
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  fontSize: 10.5,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Qorong'i mavzuda to'q rang (masalan `crimsonDark`) fon ustida
  /// o'qilmaydi — kontrast uchun yoritiladi.
  Color _lighten(Color color) {
    return Color.lerp(color, Colors.white, 0.45) ?? color;
  }
}
