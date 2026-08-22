import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/category_labels.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/di/injection_container.dart';
import 'package:lexhub/core/theme/shimmer_loading.dart';
import 'package:lexhub/features/community_forum/data/datasources/question_category_resolver.dart';
import 'package:lexhub/features/community_forum/presentation/bloc/community_forum_bloc.dart';
import 'package:lexhub/features/community_forum/presentation/bloc/community_forum_event.dart';
import 'package:lexhub/features/community_forum/presentation/bloc/community_forum_state.dart';
import 'package:lexhub/features/community_forum/presentation/widgets/ask_community_dialog.dart';
import 'package:lexhub/features/community_forum/presentation/widgets/community_post_card.dart';

class CommunityForumPage extends StatelessWidget {
  final ValueChanged<String>? onSendQueryToAI;

  const CommunityForumPage({
    super.key,
    this.onSendQueryToAI,
  });

  /// "Barchasi" + `public.categories`da REAL mavjud nomlar.
  ///
  /// Katalogda yo'q nomni filtr sifatida ko'rsatish 22P02 (nomni uuid
  /// ustuniga yuborish) yoki 422 (rezolyutsiya xatosi) beradi.
  static const List<String> categories = kCommunityFilterCategories;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    return BlocProvider(
      create: (context) => sl<CommunityForumBloc>()..add(const LoadCommunityPostsEvent()),
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const Icon(Icons.forum_rounded, color: AppColors.indigo, size: 22),
              const Gap(8),
              Text(
                l10n.communityTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          actions: [
            Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.add_comment_rounded),
                tooltip: l10n.communityAskTooltip,
                onPressed: () {
                  AskCommunityDialog.show(
                    ctx,
                    onPostSubmitted: (post) {
                      ctx.read<CommunityForumBloc>().add(
                            CreateCommunityQuestionEvent(
                              title: post.title,
                              rawQuestion: post.anonymizedQuestion,
                              category: post.category,
                              isAnonymous: post.isAnonymous,
                              authorName: post.authorName,
                            ),
                          );
                    },
                  );
                },
              ),
            ),
          ],
        ),
        body: BlocConsumer<CommunityForumBloc, CommunityForumState>(
          listener: (context, state) {
            if (state is CommunityForumError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppColors.crimson,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            }
          },
          builder: (context, state) {
            String selectedCat = 'Barchasi';
            if (state is CommunityForumLoaded) {
              selectedCat = state.selectedCategory;
            }

            return Column(
              children: [
                // Category Pills Filter Bar
                Container(
                  height: 48,
                  margin: const EdgeInsets.only(top: 8, bottom: 8),
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
                          categoryLabel(l10n, cat),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                          ),
                        ),
                        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
                        selectedColor: isDark ? AppColors.indigo : AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected
                                ? Colors.transparent
                                : (isDark ? AppColors.borderDark : AppColors.borderLight),
                          ),
                        ),
                        onSelected: (_) {
                          context
                              .read<CommunityForumBloc>()
                              .add(SelectCommunityCategoryEvent(cat));
                        },
                      );
                    },
                  ),
                ),

                // Posts Feed
                Expanded(
                  child: Builder(
                    builder: (context) {
                      if (state is CommunityForumLoading) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: LegalAnalysisShimmer(),
                        );
                      }

                      if (state is CommunityForumError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline_rounded, color: AppColors.emergency, size: 48),
                                const Gap(12),
                                Text(state.message, textAlign: TextAlign.center),
                                const Gap(16),
                                ElevatedButton(
                                  onPressed: () => context
                                      .read<CommunityForumBloc>()
                                      .add(const LoadCommunityPostsEvent()),
                                  child: Text(l10n.actionRetry),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      if (state is CommunityForumLoaded) {
                        if (state.posts.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.search_off_rounded, size: 48, color: AppColors.textMutedLight),
                                const Gap(12),
                                Text(
                                  l10n.communityEmptyInCategory,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          );
                        }

                        return RefreshIndicator(
                          onRefresh: () async {
                            context
                                .read<CommunityForumBloc>()
                                .add(const LoadCommunityPostsEvent());
                          },
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: state.posts.length,
                            separatorBuilder: (_, __) => const Gap(12),
                            itemBuilder: (context, index) {
                              final post = state.posts[index];
                              return CommunityPostCard(
                                post: post,
                                onConsultAITap: () {
                                  onSendQueryToAI?.call(post.anonymizedQuestion);
                                },
                                onLikeTap: () {
                                  context
                                      .read<CommunityForumBloc>()
                                      .add(VoteCommunityPostEvent(post.id));
                                },
                                onPostUpdated: () {
                                  context
                                      .read<CommunityForumBloc>()
                                      .add(const LoadCommunityPostsEvent());
                                },
                              );
                            },
                          ),
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
        floatingActionButton: Builder(
          builder: (ctx) => FloatingActionButton.extended(
            onPressed: () {
              AskCommunityDialog.show(
                ctx,
                onPostSubmitted: (post) {
                  ctx.read<CommunityForumBloc>().add(
                        CreateCommunityQuestionEvent(
                          title: post.title,
                          rawQuestion: post.anonymizedQuestion,
                          category: post.category,
                          isAnonymous: post.isAnonymous,
                          authorName: post.authorName,
                        ),
                      );
                },
              );
            },
            icon: const Icon(Icons.edit_note_rounded),
            label: Text(l10n.communityAskCta),
            backgroundColor: isDark ? AppColors.indigo : AppColors.primary,
            foregroundColor: Colors.white,
          ),
        ),
      ),
    );
  }
}
