import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
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
              const Icon(Icons.account_balance_rounded, color: AppColors.emerald, size: 22),
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
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                          ),
                        ),
                        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                        selectedColor: AppColors.primary,
                        checkmarkColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.primary
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
                    color: isDark ? AppColors.emerald.withValues(alpha: 0.15) : AppColors.emeraldLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    catalogCategoryLabel(l10n, service.category),
                    style: TextStyle(
                      color: isDark ? AppColors.emerald : AppColors.emeraldDark,
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
                      color: AppColors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, size: 12, color: AppColors.amberDark),
                        const Gap(2),
                        Text(
                          l10n.badgePopular,
                          style: const TextStyle(
                            color: AppColors.amberDark,
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
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.indigo),
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
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_outlined, size: 11, color: AppColors.emerald),
                        Gap(3),
                        Text("Lex.uz", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.emerald)),
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
