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
      (failure) => emit(CommunityForumError(failure.message)),
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
      (failure) => emit(CommunityForumError(failure.message)),
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
      (failure) => emit(CommunityForumError(failure.message)),
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
    if (state is CommunityForumLoaded) {
      final currentState = state as CommunityForumLoaded;
      final result = await voteCommunityPostUseCase(event.postId);

      result.fold(
        (_) => null,
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
      (failure) => emit(CommunityForumError(failure.message)),
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
