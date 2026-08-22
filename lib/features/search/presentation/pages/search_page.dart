import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/di/injection_container.dart';
import 'package:lexhub/core/localization/failure_text.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/localization/search_labels.dart';
import 'package:lexhub/core/theme/modern_container.dart';
import 'package:lexhub/core/theme/shimmer_loading.dart';
import 'package:lexhub/features/citizen_services/presentation/pages/citizen_services_page.dart';
import 'package:lexhub/features/community_forum/presentation/pages/community_forum_page.dart';
import 'package:lexhub/features/document_builder/presentation/pages/document_templates_page.dart';
import 'package:lexhub/features/legal_experts/presentation/pages/legal_experts_page.dart';
import 'package:lexhub/features/search/domain/entities/search_result_item.dart';
import 'package:lexhub/features/search/presentation/bloc/search_bloc.dart';
import 'package:lexhub/features/search/presentation/bloc/search_event.dart';
import 'package:lexhub/features/search/presentation/bloc/search_state.dart';
import 'package:url_launcher/url_launcher.dart';

class SearchPage extends StatefulWidget {
  final String? initialQuery;

  const SearchPage({super.key, this.initialQuery});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final TextEditingController _searchController;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery ?? '');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query, BuildContext context, SearchResultType filterType) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      context.read<SearchBloc>().add(
            SearchQueryChangedEvent(
              query: query,
              filterType: filterType,
            ),
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BlocProvider(
      create: (context) {
        final bloc = sl<SearchBloc>()..add(const LoadSearchInitialEvent());
        if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
          bloc.add(SearchQueryChangedEvent(query: widget.initialQuery!));
        }
        return bloc;
      },
      child: BlocBuilder<SearchBloc, SearchState>(
        builder: (context, state) {
          return Scaffold(
            backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
            appBar: AppBar(
              backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: _buildSearchInputField(context, state, isDark),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(54),
                child: _buildFilterChipsBar(context, state, isDark),
              ),
            ),
            body: _buildBody(context, state, isDark),
          );
        },
      ),
    );
  }

  Widget _buildSearchInputField(BuildContext context, SearchState state, bool isDark) {
    final l10n = context.l10n;
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: TextField(
        controller: _searchController,
        autofocus: widget.initialQuery == null || widget.initialQuery!.isEmpty,
        textInputAction: TextInputAction.search,
        onChanged: (val) => _onSearchChanged(val, context, state.selectedFilter),
        decoration: InputDecoration(
          hintText: l10n.searchHint,
          hintStyle: TextStyle(
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            fontSize: 14,
          ),
          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.indigo),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    context.read<SearchBloc>().add(
                          SearchQueryChangedEvent(
                            query: '',
                            filterType: state.selectedFilter,
                          ),
                        );
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        ),
      ),
    );
  }

  Widget _buildFilterChipsBar(BuildContext context, SearchState state, bool isDark) {
    final l10n = context.l10n;
    final filters = SearchResultType.values;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const Gap(8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = state.selectedFilter == filter;

          return FilterChip(
            selected: isSelected,
            label: Text(
              searchResultTypeLabel(l10n, filter),
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
              ),
            ),
            selectedColor: AppColors.indigo,
            backgroundColor: isDark ? AppColors.cardDark : AppColors.surfaceLight,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected
                    ? AppColors.indigo
                    : (isDark ? AppColors.borderDark : AppColors.borderLight),
              ),
            ),
            showCheckmark: false,
            onSelected: (_) {
              context.read<SearchBloc>().add(ChangeSearchFilterEvent(filter));
            },
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, SearchState state, bool isDark) {
    final l10n = context.l10n;
    if (state.status == SearchStatus.loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: LegalAnalysisShimmer(),
      );
    }

    if (state.status == SearchStatus.initial) {
      return _buildInitialHistoryView(context, state, isDark);
    }

    if (state.status == SearchStatus.empty) {
      return _buildEmptyState(context, isDark);
    }

    if (state.status == SearchStatus.error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.emergency, size: 48),
              const Gap(12),
              Text(
                state.errorMessage == null
                    ? l10n.searchError
                    : errorStateText(l10n, state.errorMessage!, state.errorCode),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: state.results.length,
      separatorBuilder: (_, __) => const Gap(12),
      itemBuilder: (context, index) {
        final item = state.results[index];
        return _buildSearchResultCard(context, item, isDark);
      },
    );
  }

  Widget _buildInitialHistoryView(BuildContext context, SearchState state, bool isDark) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (state.recentSearches.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.searchRecentTitle,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
              TextButton(
                onPressed: () {
                  context.read<SearchBloc>().add(const ClearSearchHistoryEvent());
                },
                child: Text(l10n.actionClear, style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const Gap(8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: state.recentSearches.map((query) {
              return ActionChip(
                avatar: const Icon(Icons.history_rounded, size: 16, color: AppColors.indigo),
                label: Text(query, style: const TextStyle(fontSize: 13)),
                backgroundColor: isDark ? AppColors.cardDark : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                onPressed: () {
                  _searchController.text = query;
                  context.read<SearchBloc>().add(
                        SearchQueryChangedEvent(
                          query: query,
                          filterType: state.selectedFilter,
                        ),
                      );
                },
              );
            }).toList(),
          ),
          const Gap(24),
        ],
        Text(
          l10n.searchPopularTitle,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
        const Gap(12),
        // §16: `title`/`subtitle` — EKRAN YORLIG'I, tarjimalanadi.
        // `query` — TARJIMA QILINMAYDI: bu qiymat `SearchQueryChangedEvent`
        // orqali qidiruv backendiga uzatiladi va O'ZBEK tilidagi korpusga
        // (`document_templates_local_datasource`, `citizen_services_local_
        // datasource`, qonun matnlari) qarshi solishtiriladi. "Aliment"ni
        // "Alimony"ga o'girsak, qidiruv 0 natija qaytaradi — ya'ni bu DB
        // qiymati bilan bir xil toifadagi KALIT, yorliq emas.
        _buildPopularTopicTile(
          context,
          icon: Icons.family_restroom_rounded,
          color: AppColors.amber,
          title: l10n.searchTopicAlimonyTitle,
          subtitle: l10n.searchTopicAlimonySubtitle,
          query: "Aliment",
        ),
        const Gap(8),
        _buildPopularTopicTile(
          context,
          icon: Icons.work_outline_rounded,
          color: AppColors.indigo,
          title: l10n.searchTopicDismissalTitle,
          subtitle: l10n.searchTopicDismissalSubtitle,
          query: "Mehnat",
        ),
        const Gap(8),
        _buildPopularTopicTile(
          context,
          icon: Icons.shopping_bag_outlined,
          color: AppColors.emerald,
          title: l10n.searchTopicRefundTitle,
          subtitle: l10n.searchTopicRefundSubtitle,
          query: "Iste'molchi",
        ),
        const Gap(8),
        _buildPopularTopicTile(
          context,
          icon: Icons.drive_eta_rounded,
          color: AppColors.crimson,
          title: l10n.searchTopicFineTitle,
          subtitle: l10n.searchTopicFineSubtitle,
          query: "Jarima",
        ),
      ],
    );
  }

  Widget _buildPopularTopicTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String query,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ModernContainer(
      onTap: () {
        _searchController.text = query;
        context.read<SearchBloc>().add(
              SearchQueryChangedEvent(
                query: query,
                filterType: SearchResultType.all,
              ),
            );
      },
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
      borderColor: isDark ? AppColors.borderDark : AppColors.borderLight,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const Gap(2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.indigo),
        ],
      ),
    );
  }

  Widget _buildSearchResultCard(BuildContext context, SearchResultItem item, bool isDark) {
    switch (item.type) {
      case SearchResultType.law:
        return _buildLawResultCard(context, item, isDark);
      case SearchResultType.expert:
        return _buildExpertResultCard(context, item, isDark);
      case SearchResultType.service:
        return _buildServiceResultCard(context, item, isDark);
      case SearchResultType.template:
        return _buildTemplateResultCard(context, item, isDark);
      case SearchResultType.question:
      case SearchResultType.all:
        return _buildQuestionResultCard(context, item, isDark);
    }
  }

  Widget _buildLawResultCard(BuildContext context, SearchResultItem item, bool isDark) {
    final l10n = context.l10n;
    return ModernContainer(
      onTap: () {
        if (item.lexUrl != null) {
          launchUrl(Uri.parse(item.lexUrl!), mode: LaunchMode.externalApplication);
        }
      },
      padding: const EdgeInsets.all(14),
      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
      borderColor: AppColors.indigo.withValues(alpha: 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.indigo.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.gavel_rounded, size: 12, color: AppColors.indigo),
                    const Gap(4),
                    Text(
                      l10n.searchBadgeLaw,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.indigo,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (item.lexUrl != null)
                Text(
                  l10n.searchLexUzBadge,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.emerald,
                  ),
                ),
            ],
          ),
          const Gap(8),
          Text(
            item.title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          if (item.subtitle != null) ...[
            const Gap(2),
            Text(
              item.subtitle!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ],
          const Gap(6),
          Text(
            item.snippet,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpertResultCard(BuildContext context, SearchResultItem item, bool isDark) {
    final l10n = context.l10n;
    return ModernContainer(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LegalExpertsPage()),
        );
      },
      padding: const EdgeInsets.all(14),
      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
      borderColor: AppColors.emerald.withValues(alpha: 0.25),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.emerald.withValues(alpha: 0.12),
            child: const Icon(Icons.person_rounded, color: AppColors.emerald, size: 26),
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.title,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                    if (item.isVerified) ...[
                      const Gap(4),
                      const Icon(Icons.verified_rounded, size: 16, color: AppColors.emerald),
                    ],
                  ],
                ),
                if (item.subtitle != null) ...[
                  const Gap(2),
                  Text(
                    item.subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
                const Gap(4),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 14, color: AppColors.amber),
                    const Gap(2),
                    Text(
                      item.rating.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    const Gap(8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.emerald.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        l10n.searchOfficialLawyer,
                        style: const TextStyle(fontSize: 10, color: AppColors.emerald, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.emerald),
        ],
      ),
    );
  }

  Widget _buildServiceResultCard(BuildContext context, SearchResultItem item, bool isDark) {
    final l10n = context.l10n;
    return ModernContainer(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CitizenServicesPage()),
        );
      },
      padding: const EdgeInsets.all(14),
      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
      borderColor: AppColors.amber.withValues(alpha: 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_rounded, size: 12, color: AppColors.amber),
                    const Gap(4),
                    Text(
                      l10n.searchBadgeService,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.amber,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (item.isFree)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.emerald.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    l10n.statusFree,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.emerald),
                  ),
                )
              else if (item.costBhmPercent > 0)
                Text(
                  l10n.searchCostBhmPercent(item.costBhmPercent.toString()),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.amber),
                ),
            ],
          ),
          const Gap(8),
          Text(
            item.title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          if (item.subtitle != null) ...[
            const Gap(2),
            Text(
              item.subtitle!,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ],
          const Gap(4),
          Text(
            item.snippet,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateResultCard(BuildContext context, SearchResultItem item, bool isDark) {
    final l10n = context.l10n;
    return ModernContainer(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const DocumentTemplatesPage()),
        );
      },
      padding: const EdgeInsets.all(14),
      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
      borderColor: AppColors.crimson.withValues(alpha: 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.crimson.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.description_rounded, size: 12, color: AppColors.crimson),
                    const Gap(4),
                    Text(
                      l10n.searchBadgeTemplate,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.crimson,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                l10n.searchBuilderBadge,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.crimson,
                ),
              ),
            ],
          ),
          const Gap(8),
          Text(
            item.title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          if (item.subtitle != null) ...[
            const Gap(2),
            Text(
              l10n.searchTemplateAuthority(item.subtitle!),
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ],
          const Gap(4),
          Text(
            item.snippet,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionResultCard(BuildContext context, SearchResultItem item, bool isDark) {
    final l10n = context.l10n;
    return ModernContainer(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CommunityForumPage()),
        );
      },
      padding: const EdgeInsets.all(14),
      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
      borderColor: isDark ? AppColors.borderDark : AppColors.borderLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.forum_rounded, size: 12, color: AppColors.primary),
                    const Gap(4),
                    Text(
                      l10n.searchBadgeQuestion,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                l10n.communityAnswersCount(item.answersCount),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const Gap(8),
          Text(
            item.title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const Gap(4),
          Text(
            item.snippet,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.indigo.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 48,
                color: AppColors.indigo,
              ),
            ),
            const Gap(16),
            Text(
              l10n.searchEmptyTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const Gap(8),
            Text(
              l10n.searchEmptyBody,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
