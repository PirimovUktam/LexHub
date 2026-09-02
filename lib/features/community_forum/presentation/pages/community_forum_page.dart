import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/localization/category_labels.dart';
import 'package:lexhub/core/localization/failure_text.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/di/injection_container.dart';
import 'package:lexhub/core/theme/app_dimens.dart';
import 'package:lexhub/core/theme/shimmer_loading.dart';
import 'package:lexhub/core/theme/tone.dart';
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
              // O'LCHANGAN: `indigo` (#6366F1) qorong'i AppBar foni
              // (`surfaceDark` #0F172A) ustida 4.00:1 — grafik uchun
              // yetarli, lekin sarlavha ikonkasi bu yerda MATN bilan bir
              // qatorda va ayni urg'u rolini bajaradi; `pastki navigatsiya`
              // bilan bir xil qoida qo'llanadi (`indigoOnTintDark` 8.96:1).
              Icon(Icons.forum_rounded,
                  color: AppTone.accentIndigo.on(isDark),
                  size: AppIconSize.md),
              const Gap(AppSpacing.sm),
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
                  content: Text(errorStateText(context.l10n, state.message, state.code)),
                  // O'LCHANGAN: `crimson` (#EF4444) oq matn ostida 3.76:1
                  // berardi — AA (4.5:1) dan past. `emergencyStrong`
                  // (#B91C1C) bilan 6.47:1. `behavior`/`shape` endi
                  // markazdagi `snackBarTheme` dan keladi.
                  backgroundColor: AppColors.emergencyStrong,
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
                          // QURILMADA O'LCHANGAN NUQSON: yorliqning OXIRGI
                          // harfi yo'qolardi ("Barchasi" → "Barchas",
                          // "Mehnat huquqi" → "Mehnat huquq"). Sababi
                          // `RawChip`: u yorliqni birinchi o'lchovda olingan
                          // kenglikka TENG `maxWidth` bilan qayta layout
                          // qiladi (probe: CONSTR == INTR == 158.60 px), va
                          // `DefaultTextStyle(overflow: fade)` ni majburlaydi
                          // — ikki o'lchov orasidagi 0.x px farq darhol
                          // oxirgi glifni so'ndiradi. `visible` fade'ni
                          // o'chiradi; yorliq matni QAT'IY katalogdan
                          // (`kCommunityFilterCategories`), ya'ni cheksiz
                          // uzun bo'lib ketmaydi.
                          overflow: TextOverflow.visible,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                          ),
                        ),
                        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
                        // O'LCHANGAN: tanlangan fon `indigo` (#6366F1) edi va
                        // OQ 12 px yorliq bilan 4.47:1 berardi — 12 px bold
                        // "yirik matn" EMAS (yirik = 18.66 px bold), ya'ni AA
                        // 4.5:1 talab qiladi. `indigoDark` bilan 6.29:1.
                        selectedColor: isDark ? AppColors.indigoDark : AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          side: BorderSide(
                            // Tanlangan holatda chegara qorong'ida SAQLANADI:
                            // `indigoDark` fon `backgroundDark` ustida faqat
                            // 2.80:1 — 1.4.11 (3:1) dan past, ya'ni tanlangan
                            // chip'ning KONTURI ko'rinmasdi. `indigoOnTintDark`
                            // chegara ayni fonda 8.96:1. Yorug'da `primary`
                            // fon oq ustida 17.85:1 — chegara kerak emas.
                            color: isSelected
                                ? (isDark
                                    ? AppColors.indigoOnTintDark
                                    : Colors.transparent)
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
                        // `Expanded` shimmer'ga qat'iy balandlik beradi —
                        // scroll qobig'isiz overflow bo'ladi.
                        return const SingleChildScrollView(
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
                                // O'LCHANGAN: `emergency` (#EF4444) yorug'
                                // fonda (#F8FAFC) 3.60:1 — grafik uchun
                                // o'tadi, lekin ayni ikonka matn bloki bilan
                                // birga xato holatini bildiradi; ton bo'yicha
                                // olinganda ikki mavzuda ham AA matn
                                // darajasida bo'ladi.
                                Icon(Icons.error_outline_rounded,
                                    color: AppTone.danger.on(isDark),
                                    size: AppIconSize.empty),
                                const Gap(AppSpacing.md),
                                Text(errorStateText(context.l10n, state.message, state.code), textAlign: TextAlign.center),
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
                                // O'LCHANGAN: rang IKKI mavzuda ham
                                // `textMutedLight` (#64748B) da qotib qolgan
                                // edi — `backgroundDark` ustida 3.70:1, ya'ni
                                // grafik minimumidan arang yuqori. Endi
                                // mavzuga bog'liq (qorong'ida 6.87:1).
                                Icon(Icons.search_off_rounded,
                                    size: AppIconSize.empty,
                                    color: isDark
                                        ? AppColors.textMutedDark
                                        : AppColors.textMutedLight),
                                const Gap(AppSpacing.md),
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
                                // `onLikeTap` OLIB TASHLANDI. Sabab: jonli
                                // `votes` jadvali FAQAT javoblarga ovoz beradi
                                // (`answer_id` NOT NULL, FK -> `answers(id)`;
                                // o'lchandi 2026-08-30T17:13:23Z,
                                // `.runtime_evidence/votes_schema_facts.out.json`).
                                // Ilgari bu yer `VoteCommunityPostEvent`
                                // yuborardi, DataSource `23502` bilan
                                // yiqilardi, BLoC xatoni JIM YUTARDI va
                                // kartochka sonni O'ZI oshirib qo'yardi —
                                // ya'ni foydalanuvchi YOZILMAGAN ovozni
                                // ko'rardi. Ishlamaydigan tugma o'rniga
                                // serverdan kelgan son YORLIQ sifatida
                                // ko'rsatiladi.
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
            // O'LCHANGAN TUZATISH: qorong'i mavzuda fon `indigo` (#6366F1)
            // edi va OQ yorliq 4.47:1 berardi — FAB YORLIG'I matn, ya'ni
            // WCAG AA 4.5:1 talab qiladi. `indigoDark` (#4F46E5) 6.29:1
            // beradi. Yorug' mavzu (`primary`, 17.85:1) o'zgarmadi.
            backgroundColor: isDark ? AppColors.indigoDark : AppColors.primary,
            foregroundColor: Colors.white,
          ),
        ),
      ),
    );
  }
}
