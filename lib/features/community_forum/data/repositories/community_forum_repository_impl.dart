import 'package:dartz/dartz.dart';
import 'package:lexhub/core/errors/error_handler.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/features/community_forum/data/datasources/community_forum_remote_datasource.dart';
import 'package:lexhub/features/community_forum/domain/entities/community_post.dart';
import 'package:lexhub/features/community_forum/domain/entities/question_answer.dart';
import 'package:lexhub/features/community_forum/domain/repositories/community_forum_repository.dart';

/// XATO MAPPINGI MARKAZDAN (`ErrorHandler.handle`) o'tadi.
///
/// Ilgari har bir metod ikki shoxli edi va IKKALASI ham nuqsonli:
///   * `on ServerException -> ServerFailure(message: e.message)` — `code`
///     (`FailureCode`) va `statusCode` TASHLAB KETILARDI, ya'ni ingliz UI
///     ARB'dan to'g'ri matnni tanlay olmasdi va 401/403/408 farqi yo'qolardi;
///   * `catch (e) -> ServerFailure(message: "...: $e")` — XOM texnik matn
///     (`TimeoutException after 0:00:20.000000: rest/v1/questions`) TO'G'RIDAN
///     TO'G'RI foydalanuvchi ekraniga chiqardi.
///
/// `ErrorHandler` matnni sanitizatsiya qiladi, `FailureCode` ni o'rnatadi
/// (timeout -> `FailureCode.timeout`) va texnik tafsilotni `details` ga
/// yuboradi. Datasource'ning foydalanuvchiga mos xabarlari SAQLANADI:
/// `ErrorHandler` `ServerException.message` ni qayta ishlatadi
/// (`error_handler.dart` ServerException shoxi).
class CommunityForumRepositoryImpl implements CommunityForumRepository {
  final CommunityForumDataSource dataSource;

  CommunityForumRepositoryImpl({required this.dataSource});

  @override
  Future<Either<Failure, List<CommunityPost>>> getPosts({String? category, String? searchQuery}) async {
    try {
      final posts = await dataSource.getPosts(category: category, searchQuery: searchQuery);
      return Right(posts);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  @override
  Future<Either<Failure, CommunityPost>> getPostById(String postId) async {
    try {
      final post = await dataSource.getPostById(postId);
      return Right(post);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  @override
  Future<Either<Failure, CommunityPost>> createQuestion({
    required String title,
    required String rawQuestion,
    required String category,
    required bool isAnonymous,
    required String authorName,
  }) async {
    try {
      final newPost = await dataSource.createQuestion(
        title: title,
        rawQuestion: rawQuestion,
        category: category,
        isAnonymous: isAnonymous,
        authorName: authorName,
      );
      return Right(newPost);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  @override
  Future<Either<Failure, CommunityPost>> votePost(String postId) async {
    try {
      final updated = await dataSource.votePost(postId);
      return Right(updated);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  @override
  Future<Either<Failure, QuestionAnswer>> addAnswer({
    required String postId,
    required String content,
    required String authorName,
    required bool isExpert,
    String? authorRole,
  }) async {
    try {
      final answer = await dataSource.addAnswer(
        postId: postId,
        content: content,
        authorName: authorName,
        isExpert: isExpert,
        authorRole: authorRole,
      );
      return Right(answer);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  @override
  Future<Either<Failure, QuestionAnswer>> voteAnswer(String answerId) async {
    try {
      final answer = await dataSource.voteAnswer(answerId);
      return Right(answer);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }

  @override
  Future<Either<Failure, void>> acceptAnswer({
    required String questionId,
    required String answerId,
  }) async {
    try {
      await dataSource.acceptAnswer(
        questionId: questionId,
        answerId: answerId,
      );
      return const Right(null);
    } catch (e) {
      return Left(ErrorHandler.handle(e));
    }
  }
}
