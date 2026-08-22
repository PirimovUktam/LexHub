import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/features/search/domain/entities/search_result_item.dart';
import 'package:lexhub/features/search/domain/repositories/search_repository.dart';
import 'package:lexhub/features/search/domain/usecases/global_search_usecase.dart';
import 'package:lexhub/features/search/presentation/bloc/search_bloc.dart';
import 'package:lexhub/features/search/presentation/bloc/search_event.dart';
import 'package:lexhub/features/search/presentation/bloc/search_state.dart';

class MockSearchRepository implements SearchRepository {
  List<String> recent = ['Aliment', 'Mehnat'];

  @override
  Future<Either<Failure, List<SearchResultItem>>> search({
    required String query,
    SearchResultType filterType = SearchResultType.all,
    int limit = 20,
    int offset = 0,
  }) async {
    if (query == 'empty') {
      return const Right([]);
    }
    return Right([
      SearchResultItem(
        id: '1',
        type: SearchResultType.law,
        title: '$query natijasi',
        snippet: 'Snippet for $query',
        category: 'Qonun',
        relevanceScore: 0.9,
      ),
    ]);
  }

  @override
  Future<Either<Failure, List<String>>> getRecentSearches() async {
    return Right(recent);
  }

  @override
  Future<Either<Failure, void>> saveRecentSearch(String query) async {
    recent.insert(0, query);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> clearRecentSearches() async {
    recent.clear();
    return const Right(null);
  }
}

void main() {
  late MockSearchRepository mockRepo;
  late GlobalSearchUseCase useCase;
  late SearchBloc bloc;

  setUp(() {
    mockRepo = MockSearchRepository();
    useCase = GlobalSearchUseCase(mockRepo);
    bloc = SearchBloc(globalSearchUseCase: useCase);
  });

  tearDown(() {
    bloc.close();
  });

  group('SearchBloc Tests', () {
    test('1. Initial state is correct and LoadSearchInitialEvent loads recent searches', () async {
      expect(bloc.state.status, SearchStatus.initial);

      bloc.add(const LoadSearchInitialEvent());
      await expectLater(
        bloc.stream,
        emits(
          predicate<SearchState>((s) =>
              s.status == SearchStatus.initial &&
              s.recentSearches.contains('Aliment')),
        ),
      );
    });

    test('2. SearchQueryChangedEvent transitions to loading then success', () async {
      bloc.add(const SearchQueryChangedEvent(query: 'Aliment'));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<SearchState>((s) => s.status == SearchStatus.loading && s.query == 'Aliment'),
          predicate<SearchState>((s) => s.status == SearchStatus.success && s.results.isNotEmpty),
        ]),
      );
    });

    test('3. SearchQueryChangedEvent with empty query returns initial with recent searches', () async {
      bloc.add(const SearchQueryChangedEvent(query: ''));

      await expectLater(
        bloc.stream,
        emits(
          predicate<SearchState>((s) => s.status == SearchStatus.initial && s.results.isEmpty),
        ),
      );
    });

    test('4. ClearSearchHistoryEvent clears recent searches', () async {
      bloc.add(const ClearSearchHistoryEvent());

      await expectLater(
        bloc.stream,
        emits(
          predicate<SearchState>((s) => s.recentSearches.isEmpty),
        ),
      );
    });
  });
}
