import 'package:dartz/dartz.dart';
import 'package:lexhub/core/errors/exceptions.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/features/community_forum/data/datasources/community_forum_remote_datasource.dart';
import 'package:lexhub/features/community_forum/domain/entities/community_post.dart';
import 'package:lexhub/features/community_forum/domain/entities/question_answer.dart';
import 'package:lexhub/features/community_forum/domain/repositories/community_forum_repository.dart';

class CommunityForumRepositoryImpl implements CommunityForumRepository {
  final CommunityForumDataSource dataSource;

  CommunityForumRepositoryImpl({required this.dataSource});

  @override
  Future<Either<Failure, List<CommunityPost>>> getPosts({String? category, String? searchQuery}) async {
    try {
      final posts = await dataSource.getPosts(category: category, searchQuery: searchQuery);
      return Right(posts);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: "Jamiyat savollarini yuklab bo'lmadi: $e"));
    }
  }

  @override
  Future<Either<Failure, CommunityPost>> getPostById(String postId) async {
    try {
      final post = await dataSource.getPostById(postId);
      return Right(post);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: "Savol ma'lumotlarini yuklab bo'lmadi: $e"));
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
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: "Savol joylashda xatolik yuz berdi: $e"));
    }
  }

  @override
  Future<Either<Failure, CommunityPost>> votePost(String postId) async {
    try {
      final updated = await dataSource.votePost(postId);
      return Right(updated);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: "Ovoz berishda xatolik: $e"));
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
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: "Javob yuborishda xatolik: $e"));
    }
  }

  @override
  Future<Either<Failure, QuestionAnswer>> voteAnswer(String answerId) async {
    try {
      final answer = await dataSource.voteAnswer(answerId);
      return Right(answer);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: "Javobga ovoz berishda xatolik: $e"));
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
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: "Javobni qabul qilishda xatolik: $e"));
    }
  }
}
