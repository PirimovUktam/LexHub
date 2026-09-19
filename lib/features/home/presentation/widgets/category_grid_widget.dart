/// Bosh sahifaning ixcham kategoriya qatori; filtr holati HomeBloc'da qoladi.
library;

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/category_labels.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/app_dimens.dart';
import 'package:lexhub/core/theme/section_header.dart';
import 'package:lexhub/core/theme/tone.dart';
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
        // All catalog items remain reachable. Content determines the rail's
        // height, including when accessibility text scaling is enabled.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < categories.length; index++) ...[
                if (index > 0) const Gap(AppSpacing.sm),
                _CategoryTile(
                  category: categories[index],
                  isSelected: selectedCategoryId == categories[index].id,
                  onTap: () => onCategorySelected(categories[index].id),
                ),
              ],
            ],
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
    final tone = AppTone.forRawAccent(cat.color);
    final textScale = MediaQuery.textScalerOf(context).scale(12) / 12;
    final width =
        (AppIconSize.empty + AppSpacing.xl) * textScale.clamp(1.0, 2.0);

    return Semantics(
      button: true,
      selected: selected,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: AppMotion.of(context, AppMotion.fast),
        curve: AppMotion.curve,
        child: SizedBox(
          width: width,
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
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: AppMotion.of(context, AppMotion.base),
                      curve: AppMotion.curve,
                      width: AppIconSize.empty,
                      height: AppIconSize.empty,
                      decoration: BoxDecoration(
                        color: selected ? null : tone.bg(isDark, alpha: 0.14),
                        gradient: selected
                            ? const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.indigoDark,
                                  AppColors.indigoDarkBorder,
                                ],
                              )
                            : null,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Icon(
                        cat.icon,
                        color: selected ? Colors.white : tone.on(isDark),
                        size: AppIconSize.lg,
                      ),
                    ),
                    const Gap(AppSpacing.sm),
                    Text(
                      homeCategoryLabel(l10n, cat.title),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600,
                        height: 1.25,
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
