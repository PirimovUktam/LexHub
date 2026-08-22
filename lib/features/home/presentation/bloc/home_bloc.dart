import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexhub/core/usecase/usecase.dart';
import 'package:lexhub/features/home/domain/usecases/get_home_data_usecase.dart';
import 'package:lexhub/features/home/presentation/bloc/home_event.dart';
import 'package:lexhub/features/home/presentation/bloc/home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final GetHomeDataUseCase getHomeDataUseCase;
  final FilterSeedQuestionsUseCase filterSeedQuestionsUseCase;
  final SearchSeedQuestionsUseCase searchSeedQuestionsUseCase;

  HomeBloc({
    required this.getHomeDataUseCase,
    required this.filterSeedQuestionsUseCase,
    required this.searchSeedQuestionsUseCase,
  }) : super(HomeInitial()) {
    on<LoadHomeDataEvent>(_onLoadHomeData);
    on<SelectCategoryFilterEvent>(_onSelectCategoryFilter);
    on<SearchHomeQuestionsEvent>(_onSearchHomeQuestions);
  }

  Future<void> _onLoadHomeData(
    LoadHomeDataEvent event,
    Emitter<HomeState> emit,
  ) async {
    emit(HomeLoading());
    final result = await getHomeDataUseCase(const NoParams());
    result.fold(
      (failure) => emit(HomeError(failure.message, code: failure.code)),
      (data) => emit(HomeLoaded(
        categories: data.categories,
        questions: data.trendingQuestions,
      )),
    );
  }

  Future<void> _onSelectCategoryFilter(
    SelectCategoryFilterEvent event,
    Emitter<HomeState> emit,
  ) async {
    if (state is HomeLoaded) {
      final current = state as HomeLoaded;
      final newCategoryId =
          current.selectedCategoryId == event.categoryId ? null : event.categoryId;

      final questionsResult = await filterSeedQuestionsUseCase(newCategoryId);
      questionsResult.fold(
        (failure) => emit(HomeError(failure.message, code: failure.code)),
        (questions) => emit(current.copyWith(
          questions: questions,
          selectedCategoryId: newCategoryId,
          clearCategory: newCategoryId == null,
        )),
      );
    }
  }

  Future<void> _onSearchHomeQuestions(
    SearchHomeQuestionsEvent event,
    Emitter<HomeState> emit,
  ) async {
    if (state is HomeLoaded) {
      final current = state as HomeLoaded;
      final searchResult = await searchSeedQuestionsUseCase(event.query);
      searchResult.fold(
        (failure) => emit(HomeError(failure.message, code: failure.code)),
        (questions) => emit(current.copyWith(
          questions: questions,
          searchQuery: event.query,
        )),
      );
    }
  }
}
