import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/theme/tone.dart';
import 'package:lexhub/core/di/injection_container.dart';
import 'package:lexhub/core/localization/category_labels.dart';
import 'package:lexhub/core/localization/failure_text.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/modern_container.dart';
import 'package:lexhub/features/citizen_services/domain/entities/citizen_service.dart';
import 'package:lexhub/features/citizen_services/presentation/bloc/citizen_services_bloc.dart';
import 'package:lexhub/features/citizen_services/presentation/bloc/citizen_services_event.dart';
import 'package:lexhub/features/citizen_services/presentation/bloc/citizen_services_state.dart';
import 'package:lexhub/features/citizen_services/presentation/pages/service_detail_page.dart';
import 'package:shimmer/shimmer.dart';

class CitizenServicesPage extends StatelessWidget {
  const CitizenServicesPage({super.key});

  static const List<String> categories = [
    "Barchasi",
    "Yo'l harakati",
    "Mehnat huquqi",
    "Ijtimoiy himoya",
    "Iste'molchi huquqi",
    "Kadastr va Uy-joy",
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    return BlocProvider(
      create: (context) => sl<CitizenServicesBloc>()..add(const LoadCitizenServicesEvent()),
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              // O'LCHANGAN: xom `emerald` oq AppBar ustida 2.54:1 — ikonka
              // uchun ham (1.4.11 -> 3:1) PAST edi. Ton: 7.68 / 7.04:1.
              Icon(Icons.account_balance_rounded,
                  color: AppTone.success.on(isDark), size: 22),
              const Gap(8),
              Text(
                l10n.servicesTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        body: BlocBuilder<CitizenServicesBloc, CitizenServicesState>(
          builder: (context, state) {
            String selectedCat = 'Barchasi';
            if (state is CitizenServicesLoaded) {
              selectedCat = state.selectedCategory;
            }

            return Column(
              children: [
                // Search Field
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    onChanged: (val) {
                      context
                          .read<CitizenServicesBloc>()
                          .add(SearchCitizenServicesEvent(val));
                    },
                    decoration: InputDecoration(
                      hintText: l10n.servicesSearchHint,
                      prefixIcon: const Icon(Icons.search_rounded),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        ),
                      ),
                    ),
                  ),
                ),

                // Category Chips
                Container(
                  height: 48,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const Gap(8),
                    itemBuilder: (context, index) {
                      final cat = categories[index];
                      final isSelected = cat == selectedCat;

                      return FilterChip(
                        selected: isSelected,
                        label: Text(
                          catalogCategoryLabel(l10n, cat),
                          // `RawChip` yorliqni o'lchangan kengligiga TENG
                          // `maxWidth` bilan qayta layout qiladi va
                          // `TextOverflow.fade` ni majburlaydi — oxirgi glif
                          // so'nib ketadi (qurilmada tasdiqlangan). Yorliq
                          // qat'iy katalogdan keladi, shuning uchun fade
                          // o'chiriladi.
                          overflow: TextOverflow.visible,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                          ),
                        ),
                        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                        // O'LCHANGAN: tanlangan fon IKKI mavzuda ham
                        // `primary` (#0F172A) edi — qorong'i mavzuda sahifa
                        // foni (`backgroundDark` #0A192F) bilan 1.01:1, ya'ni
                        // TANLANGAN chip butunlay ko'rinmasdi (chegara ham
                        // `primary` bo'lgani uchun kontur ham yo'q edi).
                        // Qorong'ida `indigoDark` fon: oq yorliq 6.29:1,
                        // `indigoOnTintDark` chegara fon ustida 8.83:1.
                        // Yorug' mavzu o'zgarmadi (17.85:1 / 17.06:1).
                        selectedColor:
                            isDark ? AppColors.indigoDark : AppColors.primary,
                        checkmarkColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected
                                ? (isDark
                                    ? AppColors.indigoOnTintDark
                                    : AppColors.primary)
                                : (isDark ? AppColors.borderDark : AppColors.borderLight),
                          ),
                        ),
                        onSelected: (_) {
                          context
                              .read<CitizenServicesBloc>()
                              .add(FilterServicesByCategoryEvent(cat));
                        },
                      );
                    },
                  ),
                ),

                // Services List
                Expanded(
                  child: Builder(
                    builder: (context) {
                      if (state is CitizenServicesLoading) {
                        return ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: 4,
                          separatorBuilder: (_, __) => const Gap(12),
                          itemBuilder: (_, __) => Shimmer.fromColors(
                            baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                            highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
                            child: Container(
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        );
                      }

                      if (state is CitizenServicesError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline_rounded, color: AppColors.emergency, size: 48),
                                const Gap(12),
                                Text(errorStateText(context.l10n, state.message, state.code), textAlign: TextAlign.center),
                                const Gap(16),
                                ElevatedButton(
                                  onPressed: () => context
                                      .read<CitizenServicesBloc>()
                                      .add(const LoadCitizenServicesEvent()),
                                  child: Text(l10n.actionRetry),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      if (state is CitizenServicesLoaded) {
                        if (state.services.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.manage_search_rounded, size: 48, color: AppColors.textMutedLight),
                                const Gap(12),
                                Text(l10n.servicesEmptyTitle, style: theme.textTheme.bodyMedium),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: state.services.length,
                          separatorBuilder: (_, __) => const Gap(12),
                          itemBuilder: (context, index) {
                            final service = state.services[index];
                            return _buildServiceCard(context, service, isDark);
                          },
                        );
                      }

                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildServiceCard(BuildContext context, CitizenService service, bool isDark) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ServiceDetailPage(service: service),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: ModernContainer(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTone.success.bg(isDark, alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    catalogCategoryLabel(l10n, service.category),
                    style: TextStyle(
                      // O'LCHANGAN: 11 px w700 badge — WCAG "large text"
                      // EMAS, talab 4.5:1. Eski juftlik: yorug' 3.32:1,
                      // qorong'i 4.48:1. Ton: 6.65 / 5.91:1.
                      color: AppTone.success.on(isDark),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                if (service.isPopular) ...[
                  const Gap(6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTone.warning.bg(isDark, alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded,
                            size: 12, color: AppTone.warning.on(isDark)),
                        const Gap(2),
                        Text(
                          l10n.badgePopular,
                          style: TextStyle(
                            // O'LCHANGAN: 10 px w700 `amberDark` amber tintida
                            // yorug' 2.84:1, qorong'i 3.51:1. Ton: 6.31 / 7.75.
                            color: AppTone.warning.on(isDark),
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  l10n.serviceDaysShort(service.processingDays),
                  // O'LCHANGAN: xom `indigo` yorug' kartada 4.47:1 (AA'dan
                  // sal past), qorong'ida 3.27:1. Ton: 6.29 / 7.34:1.
                  style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTone.accentIndigo.on(isDark)),
                ),
              ],
            ),

            const Gap(10),

            Text(
              service.title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                height: 1.35,
              ),
            ),

            const Gap(6),

            Text(
              service.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                height: 1.4,
              ),
            ),

            const Gap(12),

            Row(
              children: [
                Icon(Icons.account_balance_outlined, size: 14, color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                const Gap(6),
                Expanded(
                  child: Text(
                    service.department,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
                ),
                if (service.sourceUrl != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    // O'LCHANGAN: xom `emerald` yorug' `backgroundLight`
                    // plashkada 2.42:1 — 10 px w600 MATN uchun ham, 11 px
                    // ikonka uchun ham past. Ton: 7.34 / 7.04:1.
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_outlined,
                            size: 11, color: AppTone.success.on(isDark)),
                        const Gap(3),
                        Text("Lex.uz",
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppTone.success.on(isDark))),
                      ],
                    ),
                  ),
                  const Gap(6),
                ],
                const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.textMutedLight),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
