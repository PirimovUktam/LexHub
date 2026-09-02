/// KATEGORIYA PLITKALARI — bosh sahifadagi gorizontal filtr qatori.
///
/// UCH O'ZGARISH VA SABABLARI:
///
/// 1. "MIKRO-GRADIENT" plitka. Ilgari tanlanmagan plitka tekis oq quti edi va
///    13 ta plitka bir-biridan FAQAT ikonka rangi bilan farq qilardi. Endi
///    plitkaning YUQORI qismiga kategoriya rangi juda nozik singdiriladi
///    (yorug' 7%, qorong'i 14%) va 62% balandlikda asosiy yuzaga qaytadi.
///    NIMA UCHUN aynan yuqori qism: matn plitkaning PASTIDA turadi, ya'ni
///    matn ostidagi yuza O'ZGARMAYDI va o'lchangan kontrast siljimaydi.
///    Gradient ranglari `Color.alphaBlend` bilan OPAQUE qilinadi — yarim
///    shaffof rang ostidagi ro'yxat fonini "o'tkazib" yuborardi.
///
/// 2. TANLANGAN plitkada aksent GRADIENT + glow. Muhim O'LCHANGAN TUZATISH:
///    ilgari qorong'i mavzuda tanlangan plitka `indigo` (#6366F1) fonda oq
///    matn ko'rsatardi — 4.47:1, ya'ni WCAG AA (4.5:1) dan PAST. Endi
///    gradient `indigoDark` (#4F46E5, 6.29:1) → `indigoDarkBorder`
///    (#3730A3, 9.93:1): ikki uchi ham AA'dan o'tadi.
///
/// 3. BOSISH reaksiyasi (`AnimatedScale`) va `SectionHeader`. Sarlavha qatori
///    endi qo'lda qurilmaydi — ilovadagi barcha bo'lim sarlavhalari bilan
///    bir xil (`section_header.dart`).
///
/// O'LCHANMAGAN QOLGAN NUQTA (halol qayd): tanlanmagan plitkada ikonka
/// kategoriya rangida qoladi (masalan `amber` #F59E0B oq ustida 1.9:1). Bu
/// WCAG 1.4.11 (3:1) talabidan past, LEKIN ikonka MA'NO TASHIMAYDI — ayni
/// ma'no darhol ostidagi matn yorlig'ida bor (redundant). Ikonka rangini
/// to'qlashtirish 13 ta kategoriya uchun 13 yangi token talab qiladi va
/// §20 SCOPE FREEZE dan chiqadi. Bu xatti-harakat O'ZGARTIRILMADI.
library;

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/category_labels.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/app_dimens.dart';
import 'package:lexhub/core/theme/depth.dart';
import 'package:lexhub/core/theme/section_header.dart';
import 'package:lexhub/features/home/domain/entities/legal_category.dart';

class CategoryGridWidget extends StatelessWidget {
  final List<LegalCategory> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onCategorySelected;

  const CategoryGridWidget({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasFilter = selectedCategoryId != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: l10n.homeCategoriesTitle(categories.length),
          // Filtr YO'Q bo'lsa havola ham chiqmaydi — bosilganda hech narsa
          // qilmaydigan tugma ko'rsatilmaydi (`SectionHeader` izohiga qara).
          actionLabel: hasFilter ? l10n.categoryAll : null,
          onAction: hasFilter ? () => onCategorySelected(null) : null,
        ),
        const Gap(AppSpacing.md),
        // BALANDLIK 112: ichki `padding` 8 bo'lgani uchun matnga 96 px
        // qoladi. O'lchov: ikonka 34 + gap 8 + ikki qatorli 11 px matn
        // `textScaleFactor` 2.0 da 52.8 = 94.8 px — ya'ni eng katta shrift
        // masshtabida ham "BOTTOM OVERFLOWED" chiqmaydi.
        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const Gap(AppSpacing.md),
            itemBuilder: (context, index) {
              final cat = categories[index];
              return _CategoryTile(
                category: cat,
                isSelected: selectedCategoryId == cat.id,
                onTap: () => onCategorySelected(cat.id),
              );
            },
          ),
        ),
      ],
    );
  }
}
/// Bitta kategoriya plitkasi.
///
/// `StatefulWidget` FAQAT bosish reaksiyasi uchun — hech qanday ma'lumot
/// yoki filtr holati bu yerda saqlanmaydi (holat `HomeBloc` da).
class _CategoryTile extends StatefulWidget {
  const _CategoryTile({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  final LegalCategory category;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<_CategoryTile> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;
    final cat = widget.category;
    final selected = widget.isSelected;

    final Color base = isDark ? AppColors.cardDark : AppColors.cardLight;

    // TANLANGAN: aksent gradient. Yorug'da navy (oq matn 17.85 / 14.63),
    // qorong'ida to'q indigo (6.29 / 9.93) — ikkisi ham AA'dan o'tadi.
    final List<Color> selectedColors = isDark
        ? const <Color>[AppColors.indigoDark, AppColors.indigoDarkBorder]
        : const <Color>[AppColors.primary, AppColors.primaryLight];

    // TANLANMAGAN: kategoriya rangi yuqoridan singdiriladi, pastda esa
    // asosiy yuza — matn ostidagi rang O'ZGARMAYDI.
    final List<Color> tintColors = <Color>[
      Color.alphaBlend(cat.color.withValues(alpha: isDark ? 0.14 : 0.07), base),
      base,
    ];

    return AnimatedScale(
      scale: _down ? 0.97 : 1.0,
      duration: AppMotion.of(context, AppMotion.fast),
      curve: AppMotion.curve,
      child: AnimatedContainer(
        duration: AppMotion.of(context, AppMotion.base),
        curve: AppMotion.curve,
        width: 108,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: selected ? selectedColors : tintColors,
            stops: selected ? null : const <double>[0.0, 0.62],
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: selected
                ? (isDark ? AppColors.indigo : AppColors.primaryLight)
                : AppBorders.hairline(isDark),
            width: selected ? 1.5 : 1.0,
          ),
          boxShadow: selected
              ? AppShadows.glow(
                  isDark ? AppColors.indigo : AppColors.primary,
                  alpha: isDark ? 0.34 : 0.22,
                )
              : AppShadows.card(isDark),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onHighlightChanged: (bool value) {
              if (_down == value) return;
              setState(() => _down = value);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.18)
                          : cat.color.withValues(alpha: isDark ? 0.22 : 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      cat.icon,
                      color: selected ? Colors.white : cat.color,
                      size: 20,
                    ),
                  ),
                  const Gap(AppSpacing.sm),
                  Text(
                    homeCategoryLabel(l10n, cat.title),
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? Colors.white
                          : (isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight),
                      fontWeight:
                          selected ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 11,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
