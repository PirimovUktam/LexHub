/// BOSH SAHIFA.
///
/// ARXITEKTURA TUZATISHI (§9): bu ekran ilgari `StatefulWidget` bo'lib,
/// hamjamiyat savollarini `sl<CommunityForumDataSource>()` orqali TO'G'RIDAN
/// oldirardi va natijani `setState` bilan mahalliy ro'yxatda saqlardi —
/// ya'ni Repository/UseCase/BLoC zanjiri chetlab o'tilgan edi. Xato esa
/// `catch (_) {}` ichida jimgina yo'qolardi (§13) va bitta o'zbekcha matn
/// widget ichida qotib qolgan edi (§7).
///
/// Endi hamjamiyat bloki `CommunityForumBloc` ustida ishlaydi:
///   Presentation -> Bloc -> UseCase -> Repository -> DataSource -> Supabase
/// `CommunityForumBloc` DI'da `registerFactory` — shuning uchun bu yerdagi
/// nusxa `CommunityForumPage` nusxasiga xalaqit bermaydi.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/core/di/injection_container.dart';
import 'package:lexhub/core/errors/failure_code.dart';
import 'package:lexhub/core/localization/failure_text.dart';
import 'package:lexhub/core/localization/l10n.dart';
import 'package:lexhub/core/theme/app_dimens.dart';
import 'package:lexhub/core/theme/modern_container.dart';
import 'package:lexhub/core/theme/section_header.dart';
import 'package:lexhub/core/theme/shimmer_loading.dart';
import 'package:lexhub/features/community_forum/presentation/bloc/community_forum_bloc.dart';
import 'package:lexhub/features/community_forum/presentation/bloc/community_forum_event.dart';
import 'package:lexhub/features/community_forum/presentation/bloc/community_forum_state.dart';
import 'package:lexhub/features/community_forum/presentation/pages/community_forum_page.dart';
import 'package:lexhub/features/community_forum/presentation/pages/question_detail_page.dart';
import 'package:lexhub/features/community_forum/presentation/widgets/ask_community_dialog.dart';
import 'package:lexhub/features/community_forum/presentation/widgets/community_mini_card.dart';
import 'package:lexhub/features/home/domain/entities/seed_question.dart';
import 'package:lexhub/features/home/presentation/bloc/home_bloc.dart';
import 'package:lexhub/features/home/presentation/bloc/home_event.dart';
import 'package:lexhub/features/home/presentation/bloc/home_state.dart';
import 'package:lexhub/features/home/presentation/pages/faq_questions_page.dart';
import 'package:lexhub/features/home/presentation/widgets/category_grid_widget.dart';
import 'package:lexhub/features/home/presentation/widgets/emergency_quick_button.dart';
import 'package:lexhub/features/home/presentation/widgets/faq_entry_banner.dart';
import 'package:lexhub/features/home/presentation/widgets/home_hero_card.dart';
import 'package:lexhub/features/home/presentation/widgets/quick_access_grid.dart';
import 'package:lexhub/features/home/presentation/widgets/recent_cases_feed.dart';
import 'package:lexhub/features/legal_assistant/presentation/pages/legal_assistant_page.dart';
import 'package:lexhub/features/search/presentation/pages/search_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    this.onAskAITap,
    this.onSendQueryToAI,
  });

  /// Pastki navigatsiyadagi markaziy bo'limga o'tish.
  final VoidCallback? onAskAITap;

  final ValueChanged<String>? onSendQueryToAI;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => sl<HomeBloc>()..add(const LoadHomeDataEvent()),
        ),
        BlocProvider(
          create: (_) =>
              sl<CommunityForumBloc>()..add(const LoadCommunityPostsEvent()),
        ),
      ],
      child: _HomeView(
        onAskAITap: onAskAITap,
        onSendQueryToAI: onSendQueryToAI,
      ),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView({this.onAskAITap, this.onSendQueryToAI});

  final VoidCallback? onAskAITap;
  final ValueChanged<String>? onSendQueryToAI;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<HomeBloc, HomeState>(
          builder: (context, state) {
            if (state is HomeError) {
              return _HomeErrorView(message: state.message, code: state.code);
            }
            if (state is HomeLoaded) {
              return _HomeContent(
                state: state,
                onAskAITap: onAskAITap,
                onSendQueryToAI: onSendQueryToAI,
              );
            }
            // `HomeInitial` va `HomeLoading` bir xil ko'rinadi — foydalanuvchi
            // uchun ikkisi ham "yuklanmoqda". Bo'sh oq ekran QOLDIRILMAYDI
            // (§14).
            return const SingleChildScrollView(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: LegalAnalysisShimmer(),
            );
          },
        ),
      ),
    );
  }
}

class _HomeErrorView extends StatelessWidget {
  const _HomeErrorView({required this.message, required this.code});

  final String message;
  final FailureCode code;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.emergency,
              size: AppIconSize.empty,
            ),
            const Gap(AppSpacing.md),
            Text(
              errorStateText(l10n, message, code),
              textAlign: TextAlign.center,
            ),
            const Gap(AppSpacing.lg),
            ElevatedButton(
              onPressed: () {
                context.read<HomeBloc>().add(const LoadHomeDataEvent());
                context
                    .read<CommunityForumBloc>()
                    .add(const LoadCommunityPostsEvent());
              },
              child: Text(l10n.actionRetry),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.state,
    this.onAskAITap,
    this.onSendQueryToAI,
  });

  final HomeLoaded state;
  final VoidCallback? onAskAITap;
  final ValueChanged<String>? onSendQueryToAI;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return RefreshIndicator(
      onRefresh: () async {
        context.read<HomeBloc>().add(const LoadHomeDataEvent());
        context
            .read<CommunityForumBloc>()
            .add(const LoadCommunityPostsEvent());
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Hero — salomlashish, rol, va ASOSIY harakat (qidiruv).
            HomeHeroCard(
              onSearchTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchPage()),
              ),
            ),

            const Gap(AppSpacing.xxl),

            // 2. Tezkor kirish — 8 ta REAL yo'nalish.
            QuickAccessGrid(
              onAskAITap: onAskAITap,
              onSendQueryToAI: onSendQueryToAI,
            ),

            const Gap(AppSpacing.xxl),

            // 3. Hamjamiyat savollari — BLoC ustida (§9).
            _CommunityPreview(onSendQueryToAI: onSendQueryToAI),

            const Gap(AppSpacing.xxl),

            // 4. Kategoriya filtri — 5-bo'limdagi ro'yxatni boshqaradi.
            CategoryGridWidget(
              categories: state.categories,
              selectedCategoryId: state.selectedCategoryId,
              onCategorySelected: (catId) {
                context.read<HomeBloc>().add(SelectCategoryFilterEvent(catId));
              },
            ),

            const Gap(AppSpacing.xxl),

            // 5. Savollar ro'yxati. Sarlavha filtr holatiga qarab
            // o'zgaradi — "tavsiya" so'zi ishlatilmaydi, chunki saralash
            // profilga qarab EMAS.
            _SeedQuestionsSection(
              questions: state.questions,
              isFiltered: state.selectedCategoryId != null,
            ),

            const Gap(AppSpacing.xxl),

            // 6. Mening so'nggi murojaatlarim — keys bo'lmasa o'zini
            // yashiradi (`SizedBox.shrink`).
            const RecentCasesFeed(),

            const Gap(AppSpacing.lg),

            const FaqEntryBanner(),

            const Gap(AppSpacing.lg),

            const EmergencyQuickButton(),

            const Gap(AppSpacing.lg),

            _AskCommunityBanner(l10n: l10n),

            const Gap(AppSpacing.bottomSafe),
          ],
        ),
      ),
    );
  }
}

/// Hamjamiyat bloki — `CommunityForumBloc` ustida.
///
/// `BlocConsumer` TANLANDI: xato holatida karta o'rnida bo'sh joy
/// qoldirilmaydi (builder), qo'shimchasiga sabab SnackBar'da ko'rsatiladi
/// (listener) — ilgari xato `catch (_) {}` ichida yo'qolardi (§13).
class _CommunityPreview extends StatelessWidget {
  const _CommunityPreview({this.onSendQueryToAI});

  final ValueChanged<String>? onSendQueryToAI;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: l10n.homeRecommendedTitle,
          subtitle: l10n.homePrivacyGuardBadge,
          actionLabel: l10n.actionSeeAll,
          onAction: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  CommunityForumPage(onSendQueryToAI: onSendQueryToAI),
            ),
          ),
        ),
        const Gap(AppSpacing.md),
        BlocConsumer<CommunityForumBloc, CommunityForumState>(
          listenWhen: (_, current) => current is CommunityForumError,
          listener: (context, state) {
            if (state is! CommunityForumError) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  errorStateText(context.l10n, state.message, state.code),
                ),
                backgroundColor: AppColors.crimson,
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          builder: (context, state) {
            if (state is CommunityForumError) {
              return _CommunityInlineNotice(
                icon: Icons.wifi_off_rounded,
                text: errorStateText(context.l10n, state.message, state.code),
                actionLabel: context.l10n.actionRetry,
                onAction: () => context
                    .read<CommunityForumBloc>()
                    .add(const LoadCommunityPostsEvent()),
              );
            }

            if (state is CommunityForumLoaded) {
              if (state.posts.isEmpty) {
                return _CommunityInlineNotice(
                  icon: Icons.forum_outlined,
                  text: context.l10n.homeCommunityEmpty,
                );
              }
              final posts = state.posts.take(6).toList();
              return SizedBox(
                height: 148,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  itemCount: posts.length,
                  separatorBuilder: (_, __) => const Gap(AppSpacing.md),
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    return CommunityMiniCard(
                      post: post,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => QuestionDetailPage(post: post),
                        ),
                      ),
                    );
                  },
                ),
              );
            }

            return const _CommunityLoadingRow();
          },
        ),
      ],
    );
  }
}

/// Yuklanish holati — `LegalAnalysisShimmer` ATAYLAB ishlatilmadi: u to'liq
/// tahlil skeleti (bir necha yuz piksel balandlik) va 148 px tasmada
/// overflow berardi.
class _CommunityLoadingRow extends StatelessWidget {
  const _CommunityLoadingRow();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 148,
      child: Row(
        children: [
          for (var i = 0; i < 2; i++) ...[
            Container(
              width: 260,
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : AppColors.dividerLight,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
            ),
            const Gap(AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

/// Bo'sh yoki xato holati uchun ixcham qator — bo'sh joy QOLDIRILMAYDI (§14).
class _CommunityInlineNotice extends StatelessWidget {
  const _CommunityInlineNotice({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ModernContainer(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Icon(
            icon,
            size: AppIconSize.md,
            color: isDark
                ? AppColors.textMutedDark
                : AppColors.textMutedLight,
          ),
          const Gap(AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// Seed savollar ro'yxati.
///
/// SARLAVHA HALOL: filtr yoqilganda "Mavzuga oid masalalar", aks holda
/// "Ko'p beriladigan yuridik savollar". Ikkalasi ham ma'lumot manbasini
/// to'g'ri ta'riflaydi — bu ro'yxat `HomeBloc` bergan REAL seed savollar,
/// shaxsiylashtirish yo'q.
class _SeedQuestionsSection extends StatelessWidget {
  const _SeedQuestionsSection({
    required this.questions,
    required this.isFiltered,
  });

  final List<SeedQuestionModel> questions;
  final bool isFiltered;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final visible = questions.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: isFiltered ? l10n.homeTopicMatters : l10n.trendingTitle,
          actionLabel: l10n.actionSeeAll,
          onAction: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FaqQuestionsPage()),
          ),
        ),
        const Gap(AppSpacing.md),
        if (visible.isEmpty)
          _CommunityInlineNotice(
            icon: Icons.search_off_rounded,
            text: l10n.trendingEmptyInCategory,
          )
        else
          for (final question in visible)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _SeedQuestionCard(question: question),
            ),
      ],
    );
  }
}

class _SeedQuestionCard extends StatelessWidget {
  const _SeedQuestionCard({required this.question});

  final SeedQuestionModel question;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ModernContainer(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LegalAssistantPage(
            initialQuery: question.questionText,
            initialCategory: question.categoryName,
          ),
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const Gap(AppSpacing.xxs),
                Text(
                  question.relatableSummary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          const Gap(AppSpacing.sm),
          Icon(
            Icons.chevron_right_rounded,
            size: AppIconSize.sm,
            color: isDark ? AppColors.indigo : AppColors.primary,
          ),
        ],
      ),
    );
  }
}

/// "Savol berish" CTA — §3 dagi birinchi vazifa.
///
/// ILGARI: bu tugma `sl<CommunityForumDataSource>().createQuestion(...)` ni
/// TO'G'RIDAN chaqirardi va xatoni o'zi `SnackBar`da ko'rsatardi (kodda
/// qotib qolgan o'zbekcha matn bilan). Endi `CreateCommunityQuestionEvent`
/// yuboriladi — muvaffaqiyat ham, xato ham `CommunityForumBloc` orqali
/// o'tadi, ya'ni yuqoridagi `_CommunityPreview` yangi savolni darhol
/// ko'rsatadi va xato matni `errorStateText` orqali TARJIMALANADI.
class _AskCommunityBanner extends StatelessWidget {
  const _AskCommunityBanner({required this.l10n});

  final AppL10n l10n;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.indigo : AppColors.primary;

    return ModernContainer(
      onTap: () {
        final bloc = context.read<CommunityForumBloc>();
        AskCommunityDialog.show(
          context,
          onPostSubmitted: (post) {
            bloc.add(
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
      backgroundColor: accent.withValues(alpha: isDark ? 0.12 : 0.05),
      borderColor: accent.withValues(alpha: isDark ? 0.30 : 0.20),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.edit_outlined,
              color: Colors.white,
              size: AppIconSize.md,
            ),
          ),
          const Gap(AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.homeAskBannerTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                Text(
                  l10n.homeAskBannerSubtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_rounded, color: accent, size: AppIconSize.sm),
        ],
      ),
    );
  }
}
