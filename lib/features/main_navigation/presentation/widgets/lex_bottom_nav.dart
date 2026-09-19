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
///
/// Panel foni markaziy tugmadan pastroqda boshlanadi. Tugmaning ko'tarilgan
/// qismi ham layout ichida qoladi, shuning uchun uning butun yuzasi bosiladi.
/// `Scaffold.extendBody` o'zgarmaydi: boshqa tablar kontenti panel ostida
/// qolmasligi uchun navigatsiya o'zining pastki maydonini saqlaydi.
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

    return Stack(
      children: [
        Positioned.fill(
          top: AppSpacing.lg,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl),
              ),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    color: AppColors.indigo.withValues(alpha: 0.10),
                    blurRadius: AppSpacing.xxl,
                    offset: const Offset(0, -AppSpacing.xxs),
                  ),
              ],
            ),
          ),
        ),
        Material(
          color: Colors.transparent,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final slot in left)
                    Expanded(
                      child: _NavItem(
                        slot: slot,
                        current: currentIndex,
                        onSelect: onSelect,
                      ),
                    ),
                  Expanded(
                    child: _CenterAction(
                      label: l10n.navAI,
                      selected: currentIndex == 1,
                      onTap: () => onSelect(1),
                    ),
                  ),
                  for (final slot in right)
                    Expanded(
                      child: _NavItem(
                        slot: slot,
                        current: currentIndex,
                        onSelect: onSelect,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selected = current == slot.stackIndex;
    final activeColor =
        isDark ? AppColors.indigoOnTintDark : AppColors.indigoDark;
    final idleColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Semantics(
      button: true,
      selected: selected,
      // Yorliq ostidagi Text'dan keladi; label takroran berilmaydi.
      child: InkWell(
        onTap: () => onSelect(slot.stackIndex),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: kMinInteractiveDimension,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: AppIconSize.empty,
                  height: AppSpacing.xl * 2,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.indigo.withValues(
                            alpha: isDark ? 0.18 : 0.10,
                          )
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Icon(
                    selected ? slot.activeIcon : slot.icon,
                    size: AppIconSize.lg,
                    color: selected ? activeColor : idleColor,
                  ),
                ),
                const Gap(AppSpacing.xxs),
                Text(
                  slot.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? activeColor : idleColor,
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

/// Markazdagi ko'tarilgan harakat.
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final labelAccent =
        isDark ? AppColors.indigoOnTintDark : AppColors.indigoDark;

    return Semantics(
      button: true,
      selected: selected,
      // `label:` yo'q — sabab `_NavItem` dagi kabi (takroriy o'qilish).
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: AppIconSize.empty + AppSpacing.sm,
                height: AppIconSize.empty + AppSpacing.sm,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.indigo, AppColors.indigoDark],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.indigo.withValues(alpha: 0.30),
                      blurRadius: AppSpacing.lg,
                      offset: const Offset(0, AppSpacing.xxs),
                    ),
                  ],
                  border: Border.all(
                    color:
                        isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                    width: AppSpacing.xxs / 2,
                  ),
                ),
                child: const Icon(
                  Icons.gavel_rounded,
                  size: AppIconSize.lg,
                  color: Colors.white,
                ),
              ),
              const Gap(AppSpacing.xxs),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                  color: selected
                      ? labelAccent
                      : (isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
