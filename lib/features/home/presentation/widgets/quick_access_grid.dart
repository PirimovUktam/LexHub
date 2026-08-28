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

    return Semantics(
      button: true,
      // `label:` YO'Q: ostidagi `Text(item.label)` semantikasi shu qobiqqa
      // qo'shiladi va yorliq ekran o'quvchida ikki marta o'qilardi.
      child: AnimatedScale(
        scale: _down ? 0.95 : 1.0,
        duration: AppMotion.of(context, AppMotion.fast),
        curve: AppMotion.curve,
        child: InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          onHighlightChanged: (bool value) {
            if (_down == value) return;
            setState(() => _down = value);
          },
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
                    // MIKRO-GRADIENT: tekis tint o'rniga yuqoridan pastga
                    // zaiflashuvchi aksent. Ikkisi ham AYNI rang, faqat alfa
                    // farq qiladi — ya'ni matn kontrasti o'lchoviga TEGMAYDI
                    // (matn bu konteynerning ICHIDA emas).
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        item.color.withValues(alpha: isDark ? 0.28 : 0.14),
                        item.color.withValues(alpha: isDark ? 0.16 : 0.07),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    item.icon,
                    size: AppIconSize.md,
                    // O'LCHANGAN DEFEKT (1.4.11 -> ikonka uchun 3:1): ikonka
                    // XOM aksent, foni esa AYNI aksentning 7-14% tinti edi.
                    // Yorug' mavzuda "Ekspertlar" (`amberDark`) 2.64:1 berardi
                    // — talabdan PAST; `emeraldDark` 3.05, `lexBlue` 3.28
                    // ya'ni butun qator chegarada turardi (bir alfa qadami
                    // ularni ham yiqitadi). Qorong'i tomon esa `_lighten()`
                    // — 45% oqartirish evristikasiga tayanardi, ya'ni yangi
                    // rang qo'shilganda kontrast KAFOLATLANMASDI.
                    // Ton ko'chirishidan keyin eng yomon qiymat: yorug'
                    // 4.97:1, qorong'i 4.93:1 (8 plitka, 4 yuza, alfa 0.07..
                    // 0.28 bo'ylab). Fon tinti va rang kodlash O'ZGARMAYDI.
                    // Qulf: `test/core/theme/raw_accent_tone_test.dart`.
                    color: AppTone.forRawAccent(item.color).on(isDark),
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
                  // yorliq plitkaning YAGONA nomi — 7.58:1 zaxira ataylab
                  // saqlanadi.
                  // Qulf: `test/core/theme/color_contrast_test.dart`.
                  //
                  // O'LCHAM 10.5 → 11: kasrli shrift o'lchami hech qanday
                  // shkalada yo'q edi (`labelSmall` 11) va past DPI ekranda
                  // yarim piksel yumaloqlanib yorliqni xiralashtirardi.
                  // Balandlik oshishi xavfsiz: bu ustunda fiksatsiyalangan
                  // balandlik YO'Q (`GridView` ataylab ishlatilmagan).
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    fontSize: 11,
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
