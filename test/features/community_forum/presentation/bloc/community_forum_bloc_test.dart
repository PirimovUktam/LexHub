import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/errors/failure_code.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/features/community_forum/domain/entities/community_post.dart';
import 'package:lexhub/features/community_forum/domain/entities/question_answer.dart';
import 'package:lexhub/features/community_forum/domain/repositories/community_forum_repository.dart';
import 'package:lexhub/features/community_forum/domain/usecases/accept_community_answer_usecase.dart';
import 'package:lexhub/features/community_forum/domain/usecases/add_community_answer_usecase.dart';
import 'package:lexhub/features/community_forum/domain/usecases/create_community_question_usecase.dart';
import 'package:lexhub/features/community_forum/domain/usecases/get_community_posts_usecase.dart';
import 'package:lexhub/features/community_forum/domain/usecases/vote_community_answer_usecase.dart';
import 'package:lexhub/features/community_forum/domain/usecases/vote_community_post_usecase.dart';
import 'package:lexhub/features/community_forum/presentation/bloc/community_forum_bloc.dart';
import 'package:lexhub/features/community_forum/presentation/bloc/community_forum_event.dart';
import 'package:lexhub/features/community_forum/presentation/bloc/community_forum_state.dart';

class MockCommunityForumRepository implements CommunityForumRepository {
  final List<CommunityPost> posts = [
    CommunityPost(
      id: 'test_post_1',
      title: "Majburiy mehnat masalasi",
      anonymizedQuestion: "Dam olish kunida ishlashga majburlashmoqda...",
      category: "Mehnat huquqi",
      aiSummary: "Mehnat kodeksi 5-moddasi bo'yicha majburiy mehnat taqiqlangan.",
      helpfulCount: 10,
      viewsCount: 50,
      answersCount: 1,
      createdAt: DateTime.now(),
      answers: [
        QuestionAnswer(
          id: 'test_ans_1',
          questionId: 'test_post_1',
          authorName: "Advokat X",
          isExpert: true,
          content: "Qonun bo'yicha bu taqiqlangan.",
          createdAt: DateTime.now(),
        ),
      ],
    ),
  ];

  @override
  Future<Either<Failure, List<CommunityPost>>> getPosts({String? category, String? searchQuery}) async {
    return Right(posts);
  }

  @override
  Future<Either<Failure, CommunityPost>> getPostById(String postId) async {
    return Right(posts.first);
  }

  @override
  Future<Either<Failure, CommunityPost>> createQuestion({
    required String title,
    required String rawQuestion,
    required String category,
    required bool isAnonymous,
    required String authorName,
  }) async {
    final newPost = CommunityPost(
      id: 'new_post_id',
      title: title,
      anonymizedQuestion: rawQuestion,
      category: category,
      aiSummary: "Xulosa",
      createdAt: DateTime.now(),
    );
    posts.insert(0, newPost);
    return Right(newPost);
  }

  @override
  Future<Either<Failure, CommunityPost>> votePost(String postId) async {
    final updated = posts.first.copyWith(
      isLikedByMe: true,
      helpfulCount: posts.first.helpfulCount + 1,
    );
    return Right(updated);
  }

  @override
  Future<Either<Failure, QuestionAnswer>> addAnswer({
    required String postId,
    required String content,
    required String authorName,
    required bool isExpert,
    String? authorRole,
  }) async {
    final newAns = QuestionAnswer(
      id: 'new_ans_id',
      questionId: postId,
      authorName: authorName,
      isExpert: isExpert,
      content: content,
      createdAt: DateTime.now(),
    );
    return Right(newAns);
  }

  @override
  Future<Either<Failure, QuestionAnswer>> voteAnswer(String answerId) async {
    final ans = posts.first.answers.first.copyWith(
      isUpvotedByMe: true,
      upvotesCount: posts.first.answers.first.upvotesCount + 1,
    );
    return Right(ans);
  }

  @override
  Future<Either<Failure, void>> acceptAnswer({
    required String questionId,
    required String answerId,
  }) async {
    return const Right(null);
  }
}

/// FAQAT `createQuestion` yiqiladigan variant.
///
/// NIMA UCHUN KERAK: bosh sahifadagi "Savol berish" CTA endi DataSource'ni
/// to'g'ridan chaqirmaydi — `CreateCommunityQuestionEvent` yuboradi. Demak
/// 422/503 xatosini foydalanuvchiga ko'rsatish BLoC'ning `CommunityForumError`
/// emit qilishiga BOG'LIQ. Muvaffaqiyat yo'li testda bor edi, xato yo'li esa
/// yo'q edi — shu bo'shliq shu yerda yopiladi.
class FailingCreateRepository extends MockCommunityForumRepository {
  @override
  Future<Either<Failure, CommunityPost>> createQuestion({
    required String title,
    required String rawQuestion,
    required String category,
    required bool isAnonymous,
    required String authorName,
  }) async {
    return const Left(
      ServerFailure(
        message: "body ustuni bo'sh bo'lishi mumkin emas",
        statusCode: 422,
        code: FailureCode.validation,
      ),
    );
  }
}

void main() {
  late MockCommunityForumRepository repository;
  late CommunityForumBloc bloc;

  setUp(() {
    repository = MockCommunityForumRepository();
    bloc = CommunityForumBloc(
      getCommunityPostsUseCase: GetCommunityPostsUseCase(repository),
      createCommunityQuestionUseCase: CreateCommunityQuestionUseCase(repository),
      voteCommunityPostUseCase: VoteCommunityPostUseCase(repository),
      addCommunityAnswerUseCase: AddCommunityAnswerUseCase(repository),
      voteCommunityAnswerUseCase: VoteCommunityAnswerUseCase(repository),
      acceptCommunityAnswerUseCase: AcceptCommunityAnswerUseCase(repository),
    );
  });

  tearDown(() {
    bloc.close();
  });

  test('initial state should be CommunityForumInitial', () {
    expect(bloc.state, isA<CommunityForumInitial>());
  });

  test('emits CommunityForumLoading then CommunityForumLoaded on LoadCommunityPostsEvent', () async {
    expectLater(
      bloc.stream,
      emitsInOrder([
        isA<CommunityForumLoading>(),
        isA<CommunityForumLoaded>(),
      ]),
    );

    bloc.add(const LoadCommunityPostsEvent());
  });

  test('creates new question and updates loaded list successfully', () async {
    expectLater(
      bloc.stream,
      emitsInOrder([
        isA<CommunityForumLoading>(),
        isA<CommunityForumLoaded>(),
      ]),
    );

    bloc.add(
      const CreateCommunityQuestionEvent(
        title: "Yangi savol",
        rawQuestion: "Men bilan bog'laning [Telefon yashirildi]",
        category: "Mehnat huquqi",
        isAnonymous: true,
        authorName: "Anonim",
      ),
    );
  });

  test('savol yaratish yiqilsa CommunityForumError kod bilan chiqadi', () async {
    final failing = FailingCreateRepository();
    final failingBloc = CommunityForumBloc(
      getCommunityPostsUseCase: GetCommunityPostsUseCase(failing),
      createCommunityQuestionUseCase: CreateCommunityQuestionUseCase(failing),
      voteCommunityPostUseCase: VoteCommunityPostUseCase(failing),
      addCommunityAnswerUseCase: AddCommunityAnswerUseCase(failing),
      voteCommunityAnswerUseCase: VoteCommunityAnswerUseCase(failing),
      acceptCommunityAnswerUseCase: AcceptCommunityAnswerUseCase(failing),
    );
    addTearDown(failingBloc.close);

    final done = expectLater(
      failingBloc.stream,
      emitsInOrder([
        isA<CommunityForumLoading>(),
        // `code` MUHIM: SnackBar matni `errorStateText(l10n, message, code)`
        // orqali tanlanadi — kod yo'qolsa ingliz UI'da o'zbekcha xom matn
        // chiqadi.
        predicate<CommunityForumError>(
          (state) =>
              state.code == FailureCode.validation && state.message.isNotEmpty,
          'CommunityForumError(code: validation)',
        ),
      ]),
    );

    failingBloc.add(
      const CreateCommunityQuestionEvent(
        title: "Yangi savol",
        rawQuestion: "Matn",
        category: "Mehnat huquqi",
        isAnonymous: true,
        authorName: "Anonim",
      ),
    );

    await done;
  });

  test('votes on answer and updates loaded question answer state', () async {
    bloc.emit(CommunityForumLoaded(posts: repository.posts));

    expectLater(
      bloc.stream,
      emitsInOrder([
        predicate<CommunityForumLoaded>((state) {
          final ans = state.posts.first.answers.first;
          return ans.isUpvotedByMe == true && ans.upvotesCount == 1;
        }),
      ]),
    );

    bloc.add(const VoteCommunityAnswerEvent(
      questionId: 'test_post_1',
      answerId: 'test_ans_1',
    ));
  });

  test('accepts answer and marks isAccepted = true in loaded state', () async {
    bloc.emit(CommunityForumLoaded(posts: repository.posts));

    expectLater(
      bloc.stream,
      emitsInOrder([
        predicate<CommunityForumLoaded>((state) {
          final ans = state.posts.first.answers.first;
          return ans.isAccepted == true;
        }),
      ]),
    );

    bloc.add(const AcceptCommunityAnswerEvent(
      questionId: 'test_post_1',
      answerId: 'test_ans_1',
    ));
  });
}
