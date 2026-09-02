import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexhub/features/community_forum/domain/usecases/accept_community_answer_usecase.dart';
import 'package:lexhub/features/community_forum/domain/usecases/add_community_answer_usecase.dart';
import 'package:lexhub/features/community_forum/domain/usecases/create_community_question_usecase.dart';
import 'package:lexhub/features/community_forum/domain/usecases/get_community_posts_usecase.dart';
import 'package:lexhub/features/community_forum/domain/usecases/vote_community_answer_usecase.dart';
import 'package:lexhub/features/community_forum/domain/usecases/vote_community_post_usecase.dart';
import 'package:lexhub/features/community_forum/presentation/bloc/community_forum_event.dart';
import 'package:lexhub/features/community_forum/presentation/bloc/community_forum_state.dart';

class CommunityForumBloc extends Bloc<CommunityForumEvent, CommunityForumState> {
  final GetCommunityPostsUseCase getCommunityPostsUseCase;
  final CreateCommunityQuestionUseCase createCommunityQuestionUseCase;
  final VoteCommunityPostUseCase voteCommunityPostUseCase;
  final AddCommunityAnswerUseCase addCommunityAnswerUseCase;
  final VoteCommunityAnswerUseCase voteCommunityAnswerUseCase;
  final AcceptCommunityAnswerUseCase acceptCommunityAnswerUseCase;

  CommunityForumBloc({
    required this.getCommunityPostsUseCase,
    required this.createCommunityQuestionUseCase,
    required this.voteCommunityPostUseCase,
    required this.addCommunityAnswerUseCase,
    required this.voteCommunityAnswerUseCase,
    required this.acceptCommunityAnswerUseCase,
  }) : super(CommunityForumInitial()) {
    on<LoadCommunityPostsEvent>(_onLoadPosts);
    on<SelectCommunityCategoryEvent>(_onSelectCategory);
    on<SearchCommunityPostsEvent>(_onSearchPosts);
    on<VoteCommunityPostEvent>(_onVotePost);
    on<CreateCommunityQuestionEvent>(_onCreateQuestion);
    on<AddAnswerToQuestionEvent>(_onAddAnswer);
    on<VoteCommunityAnswerEvent>(_onVoteAnswer);
    on<AcceptCommunityAnswerEvent>(_onAcceptAnswer);
  }

  Future<void> _onLoadPosts(
    LoadCommunityPostsEvent event,
    Emitter<CommunityForumState> emit,
  ) async {
    emit(CommunityForumLoading());
    final result = await getCommunityPostsUseCase(
      GetCommunityPostsParams(
        category: event.category,
        searchQuery: event.searchQuery,
      ),
    );

    result.fold(
      (failure) => emit(CommunityForumError(failure.message, code: failure.code)),
      (posts) => emit(
        CommunityForumLoaded(
          posts: posts,
          selectedCategory: event.category ?? 'Barchasi',
          searchQuery: event.searchQuery ?? '',
        ),
      ),
    );
  }

  Future<void> _onSelectCategory(
    SelectCommunityCategoryEvent event,
    Emitter<CommunityForumState> emit,
  ) async {
    final currentSearch = state is CommunityForumLoaded ? (state as CommunityForumLoaded).searchQuery : '';
    emit(CommunityForumLoading());

    final result = await getCommunityPostsUseCase(
      GetCommunityPostsParams(
        category: event.category,
        searchQuery: currentSearch,
      ),
    );

    result.fold(
      (failure) => emit(CommunityForumError(failure.message, code: failure.code)),
      (posts) => emit(
        CommunityForumLoaded(
          posts: posts,
          selectedCategory: event.category,
          searchQuery: currentSearch,
        ),
      ),
    );
  }

  Future<void> _onSearchPosts(
    SearchCommunityPostsEvent event,
    Emitter<CommunityForumState> emit,
  ) async {
    final currentCategory = state is CommunityForumLoaded ? (state as CommunityForumLoaded).selectedCategory : 'Barchasi';

    final result = await getCommunityPostsUseCase(
      GetCommunityPostsParams(
        category: currentCategory,
        searchQuery: event.query,
      ),
    );

    result.fold(
      (failure) => emit(CommunityForumError(failure.message, code: failure.code)),
      (posts) => emit(
        CommunityForumLoaded(
          posts: posts,
          selectedCategory: currentCategory,
          searchQuery: event.query,
        ),
      ),
    );
  }

  Future<void> _onVotePost(
    VoteCommunityPostEvent event,
    Emitter<CommunityForumState> emit,
  ) async {
    // DIQQAT — bu ishlovchi endi `lib/` ichidan CHAQIRILMAYDI:
    // `community_forum_page.dart` dagi `onLikeTap` olib tashlandi, chunki jonli
    // `votes` jadvali savolga ovoz berishni QO'LLAB-QUVVATLAMAYDI
    // (`answer_id` NOT NULL, FK -> `answers(id)`; o'lchandi
    // 2026-08-30T17:13:23Z, `.runtime_evidence/votes_schema_facts.out.json`).
    // Zanjir (event -> usecase -> repository -> datasource) ATAYLAB
    // O'CHIRILMADI: sxema kelajakda savol ovozini qo'llab-quvvatlasa, faqat
    // DataSource va call site qaytariladi. Zanjir HALOL holatda qulflandi —
    // `votePost` 501 bilan SABABINI aytadi, quyidagi `fold` esa xatoni
    // KO'RSATADI (`community_forum_bloc_test.dart` da qulf bor).
    if (state is CommunityForumLoaded) {
      final currentState = state as CommunityForumLoaded;
      final result = await voteCommunityPostUseCase(event.postId);

      result.fold(
        // ILGARI: `(_) => null` — xato JIM YUTILARDI (§: "catch (_) {} silent
        // fallback" TAQIQI). Karta esa `_toggleHelpful()` da sonni oshirib
        // qo'yardi, ya'ni foydalanuvchi HECH QACHON YOZILMAGAN ovozni
        // ko'rardi (o'lchandi: `votes.answer_id` NOT NULL -> `23502`).
        //
        // Xato KO'RSATILADI, so'ng OLDINGI ro'yxat QAYTA emit qilinadi:
        // `CommunityForumError` holatida `community_forum_page.dart:283`
        // `SizedBox.shrink()` beradi, ya'ni faqat xato emit qilinsa savollar
        // ro'yxati EKRANDAN YO'QOLARDI.
        (failure) {
          emit(CommunityForumError(failure.message, code: failure.code));
          emit(currentState);
        },
        (updatedPost) {
          final updatedList = currentState.posts.map((p) {
            return p.id == updatedPost.id ? updatedPost : p;
          }).toList();

          emit(currentState.copyWith(posts: updatedList));
        },
      );
    }
  }

  Future<void> _onCreateQuestion(
    CreateCommunityQuestionEvent event,
    Emitter<CommunityForumState> emit,
  ) async {
    final currentState = state is CommunityForumLoaded ? state as CommunityForumLoaded : null;
    emit(CommunityForumLoading());

    final result = await createCommunityQuestionUseCase(
      CreateCommunityQuestionParams(
        title: event.title,
        rawQuestion: event.rawQuestion,
        category: event.category,
        isAnonymous: event.isAnonymous,
        authorName: event.authorName,
      ),
    );

    result.fold(
      (failure) => emit(CommunityForumError(failure.message, code: failure.code)),
      (newPost) {
        final updatedList = currentState != null ? [newPost, ...currentState.posts] : [newPost];
        emit(CommunityForumLoaded(
          posts: updatedList,
          selectedCategory: currentState?.selectedCategory ?? 'Barchasi',
        ));
      },
    );
  }

  Future<void> _onAddAnswer(
    AddAnswerToQuestionEvent event,
    Emitter<CommunityForumState> emit,
  ) async {
    if (state is CommunityForumLoaded) {
      final currentState = state as CommunityForumLoaded;
      final result = await addCommunityAnswerUseCase(
        AddCommunityAnswerParams(
          postId: event.postId,
          content: event.content,
          authorName: event.authorName,
          isExpert: event.isExpert,
          authorRole: event.authorRole,
        ),
      );

      result.fold(
        (_) => null,
        (newAnswer) {
          final updatedList = currentState.posts.map((p) {
            if (p.id == event.postId) {
              final newAnswers = [...p.answers, newAnswer];
              return p.copyWith(
                answers: newAnswers,
                answersCount: newAnswers.length,
              );
            }
            return p;
          }).toList();

          emit(currentState.copyWith(posts: updatedList));
        },
      );
    }
  }

  Future<void> _onVoteAnswer(
    VoteCommunityAnswerEvent event,
    Emitter<CommunityForumState> emit,
  ) async {
    if (state is CommunityForumLoaded) {
      final currentState = state as CommunityForumLoaded;
      final result = await voteCommunityAnswerUseCase(event.answerId);

      result.fold(
        (_) => null,
        (updatedAnswer) {
          final updatedList = currentState.posts.map((p) {
            if (p.id == event.questionId) {
              final newAnswers = p.answers.map((a) {
                return a.id == updatedAnswer.id ? updatedAnswer : a;
              }).toList();
              return p.copyWith(answers: newAnswers);
            }
            return p;
          }).toList();

          emit(currentState.copyWith(posts: updatedList));
        },
      );
    }
  }

  Future<void> _onAcceptAnswer(
    AcceptCommunityAnswerEvent event,
    Emitter<CommunityForumState> emit,
  ) async {
    if (state is CommunityForumLoaded) {
      final currentState = state as CommunityForumLoaded;
      final result = await acceptCommunityAnswerUseCase(
        AcceptCommunityAnswerParams(
          questionId: event.questionId,
          answerId: event.answerId,
        ),
      );

      result.fold(
        (_) => null,
        (_) {
          final updatedList = currentState.posts.map((p) {
            if (p.id == event.questionId) {
              final newAnswers = p.answers.map((a) {
                return a.copyWith(isAccepted: a.id == event.answerId);
              }).toList();
              return p.copyWith(answers: newAnswers);
            }
            return p;
          }).toList();

          emit(currentState.copyWith(posts: updatedList));
        },
      );
    }
  }
}
