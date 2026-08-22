import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexhub/features/search/domain/usecases/global_search_usecase.dart';
import 'package:lexhub/features/search/presentation/bloc/search_event.dart';
import 'package:lexhub/features/search/presentation/bloc/search_state.dart';

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final GlobalSearchUseCase globalSearchUseCase;

  SearchBloc({required this.globalSearchUseCase}) : super(const SearchState()) {
    on<LoadSearchInitialEvent>(_onLoadInitial);
    on<SearchQueryChangedEvent>(_onQueryChanged);
    on<ChangeSearchFilterEvent>(_onChangeFilter);
    on<ClearSearchHistoryEvent>(_onClearHistory);
  }

  Future<void> _onLoadInitial(
    LoadSearchInitialEvent event,
    Emitter<SearchState> emit,
  ) async {
    final recentRes = await globalSearchUseCase.getRecentSearches();
    recentRes.fold(
      (_) => emit(state.copyWith(status: SearchStatus.initial)),
      (searches) => emit(state.copyWith(
        status: SearchStatus.initial,
        recentSearches: searches,
      )),
    );
  }

  Future<void> _onQueryChanged(
    SearchQueryChangedEvent event,
    Emitter<SearchState> emit,
  ) async {
    final clean = event.query.trim();
    if (clean.isEmpty) {
      final recentRes = await globalSearchUseCase.getRecentSearches();
      final searches = recentRes.getOrElse(() => []);
      emit(state.copyWith(
        status: SearchStatus.initial,
        query: '',
        results: [],
        recentSearches: searches,
      ));
      return;
    }

    emit(state.copyWith(
      status: SearchStatus.loading,
      query: clean,
      selectedFilter: event.filterType,
    ));

    final result = await globalSearchUseCase(
      GlobalSearchParams(
        query: clean,
        filterType: event.filterType,
      ),
    );

    result.fold(
      (failure) => emit(state.copyWith(
        status: SearchStatus.error,
        errorMessage: failure.message,
      )),
      (items) {
        if (items.isEmpty) {
          emit(state.copyWith(
            status: SearchStatus.empty,
            results: [],
          ));
        } else {
          emit(state.copyWith(
            status: SearchStatus.success,
            results: items,
          ));
        }
      },
    );
  }

  Future<void> _onChangeFilter(
    ChangeSearchFilterEvent event,
    Emitter<SearchState> emit,
  ) async {
    if (state.selectedFilter == event.filterType) return;

    emit(state.copyWith(selectedFilter: event.filterType));

    if (state.query.trim().isNotEmpty) {
      add(SearchQueryChangedEvent(
        query: state.query,
        filterType: event.filterType,
      ));
    }
  }

  Future<void> _onClearHistory(
    ClearSearchHistoryEvent event,
    Emitter<SearchState> emit,
  ) async {
    await globalSearchUseCase.clearRecentSearches();
    emit(state.copyWith(recentSearches: []));
  }
}
