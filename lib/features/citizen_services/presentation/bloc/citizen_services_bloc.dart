import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lexhub/features/citizen_services/domain/usecases/get_citizen_services_usecase.dart';
import 'package:lexhub/features/citizen_services/presentation/bloc/citizen_services_event.dart';
import 'package:lexhub/features/citizen_services/presentation/bloc/citizen_services_state.dart';

class CitizenServicesBloc extends Bloc<CitizenServicesEvent, CitizenServicesState> {
  final GetCitizenServicesUseCase getCitizenServicesUseCase;

  CitizenServicesBloc({required this.getCitizenServicesUseCase}) : super(CitizenServicesInitial()) {
    on<LoadCitizenServicesEvent>(_onLoadServices);
    on<FilterServicesByCategoryEvent>(_onFilterCategory);
    on<SearchCitizenServicesEvent>(_onSearch);
  }

  Future<void> _onLoadServices(
    LoadCitizenServicesEvent event,
    Emitter<CitizenServicesState> emit,
  ) async {
    emit(CitizenServicesLoading());
    final result = await getCitizenServicesUseCase(
      GetCitizenServicesParams(
        category: event.category,
        searchQuery: event.searchQuery,
      ),
    );

    result.fold(
      (failure) => emit(CitizenServicesError(failure.message)),
      (services) => emit(
        CitizenServicesLoaded(
          services: services,
          selectedCategory: event.category ?? 'Barchasi',
          searchQuery: event.searchQuery ?? '',
        ),
      ),
    );
  }

  Future<void> _onFilterCategory(
    FilterServicesByCategoryEvent event,
    Emitter<CitizenServicesState> emit,
  ) async {
    final currentSearch = state is CitizenServicesLoaded ? (state as CitizenServicesLoaded).searchQuery : '';
    emit(CitizenServicesLoading());

    final result = await getCitizenServicesUseCase(
      GetCitizenServicesParams(
        category: event.category,
        searchQuery: currentSearch,
      ),
    );

    result.fold(
      (failure) => emit(CitizenServicesError(failure.message)),
      (services) => emit(
        CitizenServicesLoaded(
          services: services,
          selectedCategory: event.category,
          searchQuery: currentSearch,
        ),
      ),
    );
  }

  Future<void> _onSearch(
    SearchCitizenServicesEvent event,
    Emitter<CitizenServicesState> emit,
  ) async {
    final currentCat = state is CitizenServicesLoaded ? (state as CitizenServicesLoaded).selectedCategory : 'Barchasi';

    final result = await getCitizenServicesUseCase(
      GetCitizenServicesParams(
        category: currentCat,
        searchQuery: event.query,
      ),
    );

    result.fold(
      (failure) => emit(CitizenServicesError(failure.message)),
      (services) => emit(
        CitizenServicesLoaded(
          services: services,
          selectedCategory: currentCat,
          searchQuery: event.query,
        ),
      ),
    );
  }
}
