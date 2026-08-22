import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
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

void main() {
  late MockCommunityForumRepository repository;
  late GetCommunityPostsUseCase getCommunityPostsUseCase;
  late CreateCommunityQuestionUseCase createCommunityQuestionUseCase;
  late VoteCommunityPostUseCase voteCommunityPostUseCase;
  late AddCommunityAnswerUseCase addCommunityAnswerUseCase;
  late VoteCommunityAnswerUseCase voteCommunityAnswerUseCase;
  late AcceptCommunityAnswerUseCase acceptCommunityAnswerUseCase;

  setUp(() {
    repository = MockCommunityForumRepository();
    getCommunityPostsUseCase = GetCommunityPostsUseCase(repository);
    createCommunityQuestionUseCase = CreateCommunityQuestionUseCase(repository);
    voteCommunityPostUseCase = VoteCommunityPostUseCase(repository);
    addCommunityAnswerUseCase = AddCommunityAnswerUseCase(repository);
    voteCommunityAnswerUseCase = VoteCommunityAnswerUseCase(repository);
    acceptCommunityAnswerUseCase = AcceptCommunityAnswerUseCase(repository);
  });

  test('GetCommunityPostsUseCase returns posts list from repository', () async {
    final result = await getCommunityPostsUseCase(const GetCommunityPostsParams());
    expect(result.isRight(), true);
    result.fold((_) => fail('should not fail'), (posts) {
      expect(posts.length, 1);
      expect(posts.first.title, "Majburiy mehnat masalasi");
    });
  });

  test('CreateCommunityQuestionUseCase creates and prepends new question', () async {
    final result = await createCommunityQuestionUseCase(
      const CreateCommunityQuestionParams(
        title: "Kredit shartnomasi",
        rawQuestion: "Bank foizlarini asossiz oshirdi",
        category: "Bank va kredit",
        isAnonymous: false,
        authorName: "Ali Valiyev",
      ),
    );

    expect(result.isRight(), true);
    result.fold((_) => fail('should not fail'), (post) {
      expect(post.title, "Kredit shartnomasi");
      expect(post.category, "Bank va kredit");
    });
  });

  test('VoteCommunityPostUseCase toggles like count', () async {
    final result = await voteCommunityPostUseCase('test_post_1');
    expect(result.isRight(), true);
    result.fold((_) => fail('should not fail'), (post) {
      expect(post.isLikedByMe, true);
      expect(post.helpfulCount, 11);
    });
  });

  test('AddCommunityAnswerUseCase adds an answer', () async {
    final result = await addCommunityAnswerUseCase(
      const AddCommunityAnswerParams(
        postId: 'test_post_1',
        content: "Sudga murojaat qiling",
        authorName: "Yurist",
        isExpert: true,
      ),
    );

    expect(result.isRight(), true);
    result.fold((_) => fail('should not fail'), (ans) {
      expect(ans.content, "Sudga murojaat qiling");
      expect(ans.isExpert, true);
    });
  });

  test('VoteCommunityAnswerUseCase updates answer upvotes', () async {
    final result = await voteCommunityAnswerUseCase('test_ans_1');
    expect(result.isRight(), true);
    result.fold((_) => fail('should not fail'), (ans) {
      expect(ans.isUpvotedByMe, true);
      expect(ans.upvotesCount, 1);
    });
  });

  test('AcceptCommunityAnswerUseCase succeeds', () async {
    final result = await acceptCommunityAnswerUseCase(
      const AcceptCommunityAnswerParams(
        questionId: 'test_post_1',
        answerId: 'test_ans_1',
      ),
    );

    expect(result.isRight(), true);
  });
}
