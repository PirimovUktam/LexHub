import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/di/injection_container.dart';
import 'package:lexhub/core/localization/category_labels.dart';
import 'package:lexhub/core/localization/failure_text.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/modern_container.dart';
import 'package:lexhub/features/document_builder/presentation/bloc/document_builder_bloc.dart';
import 'package:lexhub/features/document_builder/presentation/bloc/document_builder_event.dart';
import 'package:lexhub/features/document_builder/presentation/bloc/document_builder_state.dart';
import 'package:lexhub/features/document_builder/presentation/pages/document_generator_page.dart';
import 'package:shimmer/shimmer.dart';

class DocumentTemplatesPage extends StatefulWidget {
  const DocumentTemplatesPage({super.key});

  static const List<String> categories = [
    "Barchasi",
    "Iste'molchi huquqlari",
    "Mehnat huquqi",
    "Oila huquqi",
    "Yo'l harakati",
  ];

  @override
  State<DocumentTemplatesPage> createState() => _DocumentTemplatesPageState();
}

class _DocumentTemplatesPageState extends State<DocumentTemplatesPage> {
  Timer? _searchDebounce;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    return BlocProvider(
      create: (context) => sl<DocumentBuilderBloc>()..add(const LoadTemplatesListEvent()),
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const Icon(Icons.description_rounded, color: AppColors.emerald, size: 22),
              const Gap(8),
              Text(
                l10n.documentBuilderTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        body: BlocBuilder<DocumentBuilderBloc, DocumentBuilderState>(
          builder: (context, state) {
            String selectedCat = 'Barchasi';
            if (state is DocumentTemplatesLoaded) {
              selectedCat = state.selectedCategory ?? 'Barchasi';
            }

            return Column(
              children: [
                // Search Input with 300ms Debounce
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      _searchDebounce?.cancel();
                      _searchDebounce = Timer(const Duration(milliseconds: 300), () {
                        if (context.mounted) {
                          context.read<DocumentBuilderBloc>().add(SearchTemplatesEvent(val));
                        }
                      });
                    },
                    decoration: InputDecoration(
                      hintText: l10n.templatesSearchHint,
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

                // Category Filter Chips
                Container(
                  height: 44,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: DocumentTemplatesPage.categories.length,
                    separatorBuilder: (_, __) => const Gap(8),
                    itemBuilder: (context, index) {
                      final cat = DocumentTemplatesPage.categories[index];
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
                          context.read<DocumentBuilderBloc>().add(LoadTemplatesListEvent(
                                category: cat == 'Barchasi' ? null : cat,
                              ));
                        },
                      );
                    },
                  ),
                ),

                // Templates List
                Expanded(
                  child: Builder(
                    builder: (context) {
                      if (state is DocumentTemplatesLoading) {
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

                      if (state is DocumentBuilderError) {
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
                                      .read<DocumentBuilderBloc>()
                                      .add(const LoadTemplatesListEvent()),
                                  child: Text(l10n.actionReload),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      if (state is DocumentTemplatesLoaded) {
                        if (state.templates.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.manage_search_rounded, size: 48, color: AppColors.textMutedLight),
                                const Gap(12),
                                Text(l10n.templatesEmptyTitle, style: theme.textTheme.bodyMedium),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: state.templates.length,
                          separatorBuilder: (_, __) => const Gap(12),
                          itemBuilder: (context, index) {
                            final template = state.templates[index];

                            return InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DocumentGeneratorPage(template: template),
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
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: template.color.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(template.icon, color: template.color, size: 20),
                                        ),
                                        const Gap(10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: isDark ? AppColors.surfaceDark : AppColors.backgroundLight,
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      catalogCategoryLabel(l10n, template.category),
                                                      style: TextStyle(
                                                        color: template.color,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 10,
                                                      ),
                                                    ),
                                                  ),
                                                  if (template.isPopular) ...[
                                                    const Gap(6),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.amber.withValues(alpha: 0.15),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          const Icon(Icons.star_rounded, size: 10, color: AppColors.amberDark),
                                                          const Gap(2),
                                                          Text(
                                                            l10n.badgePopular,
                                                            style: const TextStyle(
                                                              color: AppColors.amberDark,
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 9,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              const Gap(4),
                                              Text(
                                                template.title,
                                                style: theme.textTheme.titleSmall?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  height: 1.3,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Gap(10),
                                    Text(
                                      template.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                        height: 1.35,
                                      ),
                                    ),
                                    const Gap(12),
                                    Row(
                                      children: [
                                        const Icon(Icons.verified_outlined, size: 13, color: AppColors.emerald),
                                        const Gap(4),
                                        Expanded(
                                          child: Text(
                                            template.legalBasisSummary,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              fontSize: 11,
                                              color: AppColors.emeraldDark,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        const Gap(8),
                                        Text(
                                          l10n.templateFieldsCount(template.fields.length),
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            fontSize: 11,
                                            color: AppColors.indigo,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const Gap(4),
                                        const Icon(Icons.arrow_forward_ios_rounded, size: 11, color: AppColors.textMutedLight),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
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
}
