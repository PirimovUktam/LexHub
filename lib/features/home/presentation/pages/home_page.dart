import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/di/injection_container.dart';
import 'package:lexhub/core/errors/exceptions.dart';
import 'package:lexhub/core/localization/failure_text.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/modern_container.dart';
import 'package:lexhub/core/theme/shimmer_loading.dart';
import 'package:lexhub/features/citizen_services/presentation/pages/citizen_services_page.dart';
import 'package:lexhub/features/community_forum/data/datasources/community_forum_remote_datasource.dart';
import 'package:lexhub/features/community_forum/domain/entities/community_post.dart';
import 'package:lexhub/features/community_forum/presentation/pages/community_forum_page.dart';
import 'package:lexhub/features/community_forum/presentation/widgets/ask_community_dialog.dart';
import 'package:lexhub/features/community_forum/presentation/widgets/community_post_card.dart';
import 'package:lexhub/features/home/domain/entities/seed_question.dart';
import 'package:lexhub/features/home/presentation/bloc/home_bloc.dart';
import 'package:lexhub/features/home/presentation/bloc/home_event.dart';
import 'package:lexhub/features/home/presentation/bloc/home_state.dart';
import 'package:lexhub/features/home/presentation/widgets/category_grid_widget.dart';
import 'package:lexhub/features/home/presentation/widgets/emergency_quick_button.dart';
import 'package:lexhub/features/home/presentation/widgets/faq_entry_banner.dart';
import 'package:lexhub/features/home/presentation/widgets/home_header_widget.dart';
import 'package:lexhub/features/home/presentation/widgets/recent_cases_feed.dart';
import 'package:lexhub/features/legal_assistant/presentation/pages/legal_assistant_page.dart';
import 'package:lexhub/features/search/presentation/pages/search_page.dart';

class HomePage extends StatefulWidget {
  final VoidCallback? onAskAITap;
  final ValueChanged<String>? onSendQueryToAI;

  const HomePage({
    super.key,
    this.onAskAITap,
    this.onSendQueryToAI,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<CommunityPost> _communityPosts = [];
  bool _isLoadingPosts = true;

  @override
  void initState() {
    super.initState();
    _loadRecentCommunityPosts();
  }

  Future<void> _loadRecentCommunityPosts() async {
    try {
      final ds = sl<CommunityForumDataSource>();
      final posts = await ds.getPosts();
      if (mounted) {
        setState(() {
          _communityPosts = posts.take(3).toList();
          _isLoadingPosts = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingPosts = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    return BlocProvider(
      create: (context) => sl<HomeBloc>()..add(const LoadHomeDataEvent()),
      child: Scaffold(
        body: SafeArea(
          child: BlocBuilder<HomeBloc, HomeState>(
            builder: (context, state) {
              if (state is HomeLoading) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: LegalAnalysisShimmer(),
                );
              }

              if (state is HomeError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.emergency,
                          size: 48,
                        ),
                        const Gap(12),
                        Text(errorStateText(context.l10n, state.message, state.code), textAlign: TextAlign.center),
                        const Gap(16),
                        ElevatedButton(
                          onPressed: () => context
                              .read<HomeBloc>()
                              .add(const LoadHomeDataEvent()),
                          child: Text(l10n.actionRetry),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (state is HomeLoaded) {
                return RefreshIndicator(
                  onRefresh: () async {
                    context.read<HomeBloc>().add(const LoadHomeDataEvent());
                    await _loadRecentCommunityPosts();
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Header & Unified Global Search trigger
                        HomeHeaderWidget(
                          onSearchTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SearchPage(),
                              ),
                            );
                          },
                        ),

                        const Gap(16),

                        // Emergency Quick Button
                        const EmergencyQuickButton(),

                        const Gap(18),

                        // Citizen Services Quick Entry Banner
                        ModernContainer(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CitizenServicesPage(),
                              ),
                            );
                          },
                          backgroundColor: isDark
                              ? AppColors.emerald.withValues(alpha: 0.12)
                              : AppColors.emeraldLight.withValues(alpha: 0.4),
                          borderColor: isDark
                              ? AppColors.emerald.withValues(alpha: 0.3)
                              : AppColors.emerald.withValues(alpha: 0.2),
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.emerald,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.account_balance_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const Gap(12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.homeServicesBannerTitle,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      l10n.homeServicesBannerSubtitle,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_rounded, color: AppColors.emerald, size: 18),
                            ],
                          ),
                        ),

                        const Gap(18),

                        // 2. Category Grid
                        CategoryGridWidget(
                          categories: state.categories,
                          selectedCategoryId: state.selectedCategoryId,
                          onCategorySelected: (catId) {
                            context.read<HomeBloc>().add(SelectCategoryFilterEvent(catId));
                          },
                        ),

                        const Gap(18),

                        // 3. Category Context Questions
                        if (state.selectedCategoryId != null) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                l10n.homeTopicMatters,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const Gap(10),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: state.questions.length,
                            separatorBuilder: (_, __) => const Gap(8),
                            itemBuilder: (context, index) {
                              final q = state.questions[index];
                              return _buildQuestionCard(context, q, isDark);
                            },
                          ),
                        ],

                        const Gap(18),

                        // 4. FaqEntryBanner
                        const FaqEntryBanner(),

                        const Gap(18),

                        // 5. Mening so'nggi murojaatlarim
                        const RecentCasesFeed(),

                        const Gap(22),

                        // 6. Privacy Guarded Community Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.homeCommunityQuestions,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  l10n.homePrivacyGuardBadge,
                                  style: TextStyle(
                                    color: isDark ? AppColors.emerald : AppColors.emeraldDark,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            TextButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CommunityForumPage(
                                      onSendQueryToAI: widget.onSendQueryToAI,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                              label: Text(l10n.actionSeeAll),
                            ),
                          ],
                        ),

                        const Gap(10),

                        if (_isLoadingPosts)
                          const LegalAnalysisShimmer()
                        else
                          ..._communityPosts.map(
                            (post) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: CommunityPostCard(
                                post: post,
                                onConsultAITap: () {
                                  widget.onSendQueryToAI?.call(post.anonymizedQuestion);
                                },
                                onPostUpdated: _loadRecentCommunityPosts,
                              ),
                            ),
                          ),

                        const Gap(12),

                        // Ask Community Action Banner
                        ModernContainer(
                          onTap: () {
                            AskCommunityDialog.show(
                              context,
                              onPostSubmitted: (newPost) async {
                                // Bu call site BLoC'dan o'tmaydi, shuning uchun
                                // xato (masalan kategoriya rezolyutsiyasi 422 /
                                // katalog 503) foydalanuvchiga shu joyda
                                // ko'rsatiladi — jimjitlikda yo'qolmaydi.
                                final messenger =
                                    ScaffoldMessenger.of(context);
                                try {
                                  final ds = sl<CommunityForumDataSource>();
                                  await ds.createQuestion(
                                    title: newPost.title,
                                    rawQuestion: newPost.anonymizedQuestion,
                                    category: newPost.category,
                                    isAnonymous: newPost.isAnonymous,
                                    authorName: newPost.authorName,
                                  );
                                  if (!mounted) return;
                                  _loadRecentCommunityPosts();
                                } catch (e) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        e is ServerException
                                            ? e.message
                                            : "Savolni yuborib bo'lmadi. "
                                                "Keyinroq qayta urinib ko'ring.",
                                      ),
                                      backgroundColor: AppColors.crimson,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                            );
                          },
                          backgroundColor: isDark
                              ? AppColors.indigo.withValues(alpha: 0.12)
                              : AppColors.primary.withValues(alpha: 0.05),
                          borderColor: isDark
                              ? AppColors.indigo.withValues(alpha: 0.3)
                              : AppColors.primary.withValues(alpha: 0.2),
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(
                                Icons.people_outline_rounded,
                                color: isDark ? AppColors.indigo : AppColors.primary,
                                size: 24,
                              ),
                              const Gap(12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.homeAskBannerTitle,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      l10n.homeAskBannerSubtitle,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_rounded,
                                color: isDark ? AppColors.indigo : AppColors.primary,
                                size: 18,
                              ),
                            ],
                          ),
                        ),

                        const Gap(32),
                      ],
                    ),
                  ),
                );
              }

              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard(BuildContext context, SeedQuestionModel question, bool isDark) {
    return ModernContainer(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LegalAssistantPage(
              initialQuery: question.questionText,
              initialCategory: question.categoryName,
            ),
          ),
        );
      },
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question.questionText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const Gap(4),
                Text(
                  question.relatableSummary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.textMutedLight),
        ],
      ),
    );
  }
}
