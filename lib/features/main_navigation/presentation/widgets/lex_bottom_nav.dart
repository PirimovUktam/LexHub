/// PASTKI NAVIGATSIYA — 5 slot, markazda ko'tarilgan asosiy harakat.
///
/// NIMA UCHUN maxsus widget: M3 `NavigationBar` beshta teng slotni bir xil
/// ko'rinishda beradi, ya'ni "Maslahat" bo'limi qolganlari bilan bir xil
/// vaznda ko'rinardi. §3 talabi bo'yicha ENG KO'P ISHLATILADIGAN harakat
/// ENG KO'RINADIGAN bo'lishi kerak.
///
/// MUHIM — INDEKSLAR O'ZGARMADI: `MainNavigationPage` ichidagi `IndexedStack`
/// tartibi (0 Bosh sahifa, 1 Maslahat, 2 Hamjamiyat, 3 Xizmatlar, 4 Kabinet)
/// ATAYLAB saqlangan. Faqat KO'RSATISH tartibi o'zgardi. Aks holda
/// `onAskAITap: () => _navigateToTab(1)` kabi mavjud chaqiruvlar boshqa
/// ekranga olib borib, jimgina regressiya berardi.
///
/// IKONKA TANLOVI (§6): markazda `auto_awesome` (uchqun = "AI") EMAS,
/// `gavel` ishlatiladi. Server modeli faqat tizimga kirgan foydalanuvchi
/// uchun chaqiriladi; uchqun piktogrammasi shartsiz "AI" da'vosi bo'lardi.
library;

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/app_dimens.dart';

/// Bitta slotning tavsifi.
class _NavSlot {
  const _NavSlot({
    required this.stackIndex,
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  /// `IndexedStack` dagi HAQIQIY indeks — ko'rsatish tartibidan mustaqil.
  final int stackIndex;

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

class LexBottomNav extends StatelessWidget {
  const LexBottomNav({
    super.key,
    required this.currentIndex,
    required this.onSelect,
  });

  /// `IndexedStack` indeksi (0..4).
  final int currentIndex;

  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    // Ko'rsatish tartibi: chapda ikkita, markazda ko'tarilgan harakat,
    // o'ngda ikkita. `stackIndex` esa asl tartibni ushlab turadi.
    final left = <_NavSlot>[
      _NavSlot(
        stackIndex: 0,
        label: l10n.navHome,
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
      ),
      _NavSlot(
        stackIndex: 2,
        label: l10n.navCommunity,
        icon: Icons.groups_outlined,
        activeIcon: Icons.groups_rounded,
      ),
    ];
    final right = <_NavSlot>[
      _NavSlot(
        stackIndex: 3,
        label: l10n.navServices,
        icon: Icons.account_balance_outlined,
        activeIcon: Icons.account_balance_rounded,
      ),
      _NavSlot(
        stackIndex: 4,
        label: l10n.navCabinet,
        icon: Icons.folder_open_rounded,
        activeIcon: Icons.folder_rounded,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.md,
            bottom: AppSpacing.xs,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final slot in left)
                Expanded(child: _NavItem(slot: slot, current: currentIndex, onSelect: onSelect)),
              Expanded(
                child: _CenterAction(
                  label: l10n.navAI,
                  selected: currentIndex == 1,
                  onTap: () => onSelect(1),
                ),
              ),
              for (final slot in right)
                Expanded(child: _NavItem(slot: slot, current: currentIndex, onSelect: onSelect)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.slot,
    required this.current,
    required this.onSelect,
  });

  final _NavSlot slot;
  final int current;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = current == slot.stackIndex;
    final activeColor = isDark ? AppColors.indigo : AppColors.primary;
    // TANLANMAGAN RANG: `textMuted*` EMAS. O'lchov tarixi: bu izoh yozilganda
    // `textMutedLight` #94A3B8 edi va oq panel ustida 2.56:1 berardi — WCAG AA
    // (4.5:1) dan past. Token keyinroq #64748B ga tuzatildi (4.76:1) va endi
    // AA'dan o'tadi; navigatsiya yorliqlari esa `textSecondary*` da QOLADI:
    // 10.5 px matn uchun 4.76:1 chegaradagi qiymat, 7.58:1 esa zaxira beradi.
    // Tanlangan holat baribir ajralib turadi: to'ldirilgan ikonka + w800 +
    // ancha to'q `activeColor`.
    // Qulf: `test/core/theme/color_contrast_test.dart`.
    final idleColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Semantics(
      button: true,
      selected: selected,
      // `label:` ATAYLAB BERILMAYDI: ostidagi `Text(slot.label)` semantikasi
      // shu qobiqqa QO'SHILADI va ekran o'quvchi yorliqni ikki marta
      // o'qiydi ("Maslahat\nMaslahat" — `lex_bottom_nav_test.dart` da
      // o'lchangan). Yagona manba — ko'rinadigan matnning o'zi.
      child: InkWell(
        onTap: () => onSelect(slot.stackIndex),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? slot.activeIcon : slot.icon,
                size: AppIconSize.md,
                color: selected ? activeColor : idleColor,
              ),
              const Gap(AppSpacing.xxs),
              Text(
                slot.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? activeColor : idleColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Markazdagi ko'tarilgan harakat.
///
/// `Transform.translate` ATAYLAB ishlatilgan: doira panel chizig'idan
/// yuqoriga chiqib ko'rinadi, lekin panelning LAYOUT balandligi
/// o'zgarmaydi — shuning uchun katta shrift masshtabida ham panel
/// ekran maydonini yeb qo'ymaydi. Bosish maydoni butun slot bo'lgani
/// uchun doiraning yuqori qismi tashqarida qolsa ham harakat bajariladi.
class _CenterAction extends StatelessWidget {
  const _CenterAction({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.indigo : AppColors.primary;

    return Semantics(
      button: true,
      selected: selected,
      // `label:` yo'q — sabab `_NavItem` dagi kabi (takroriy o'qilish).
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.translate(
                offset: const Offset(0, -10),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [accent, AppColors.indigoDark],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.38),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: isDark
                          ? AppColors.surfaceDark
                          : AppColors.surfaceLight,
                      width: 3,
                    ),
                  ),
                  child: const Icon(
                    Icons.gavel_rounded,
                    size: AppIconSize.lg,
                    color: Colors.white,
                  ),
                ),
              ),
              // `-10` siljish tufayli hosil bo'lgan bo'shliqni qaytarish:
              // aks holda yorliq qolgan slotlardan yuqorida turardi.
              Transform.translate(
                offset: const Offset(0, -6),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                    color: selected
                        ? accent
                        : (isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
