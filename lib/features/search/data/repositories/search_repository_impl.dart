import 'package:dartz/dartz.dart';
import 'package:lexhub/core/errors/error_handler.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/features/search/data/datasources/search_local_datasource.dart';
import 'package:lexhub/features/search/data/datasources/search_remote_datasource.dart';
import 'package:lexhub/features/search/domain/entities/search_result_item.dart';
import 'package:lexhub/features/search/domain/repositories/search_repository.dart';

class SearchRepositoryImpl implements SearchRepository {
  final SearchRemoteDataSource remoteDataSource;
  final SearchLocalDataSource localDataSource;

  SearchRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<Either<Failure, List<SearchResultItem>>> search({
    required String query,
    SearchResultType filterType = SearchResultType.all,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final clean = query.trim();
      if (clean.isEmpty) {
        return const Right([]);
      }

      // Save to recent search history in background
      unawaitedSave(clean);

      final results = await remoteDataSource.search(
        query: clean,
        filterType: filterType,
        limit: limit,
        offset: offset,
      );

      return Right(results);
    } catch (e) {
      // §6: DB/RPC xatosi MUVAFFAQIYAT sifatida ko'rsatilmaydi. Ilgari bu
      // yerda `localDataSource.searchOffline(...)` ni `Right(...)` qilib
      // qaytarardi — ya'ni server xatosi foydalanuvchiga "natija" bo'lib
      // ko'rinardi. Ulanish uzilishi holati `SearchRemoteDataSourceImpl`
      // ichida (offline katalog) hal qilinadi.
      return Left(ErrorHandler.handle(e));
    }
  }

  void unawaitedSave(String query) {
    localDataSource.saveRecentSearch(query).catchError((_) {});
  }

  @override
  Future<Either<Failure, List<String>>> getRecentSearches() async {
    try {
      final list = await localDataSource.getRecentSearches();
      return Right(list);
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> saveRecentSearch(String query) async {
    try {
      await localDataSource.saveRecentSearch(query);
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> clearRecentSearches() async {
    try {
      await localDataSource.clearRecentSearches();
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }
}
