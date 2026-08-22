import 'package:equatable/equatable.dart';
import 'package:lexhub/core/errors/failure_code.dart';
import 'package:lexhub/features/home/domain/entities/legal_category.dart';
import 'package:lexhub/features/home/domain/entities/seed_question.dart';

abstract class HomeState extends Equatable {
  const HomeState();

  @override
  List<Object?> get props => [];
}

class HomeInitial extends HomeState {}

class HomeLoading extends HomeState {}

class HomeLoaded extends HomeState {
  final List<LegalCategory> categories;
  final List<SeedQuestionModel> questions;
  final String? selectedCategoryId;
  final String searchQuery;

  const HomeLoaded({
    required this.categories,
    required this.questions,
    this.selectedCategoryId,
    this.searchQuery = '',
  });

  HomeLoaded copyWith({
    List<LegalCategory>? categories,
    List<SeedQuestionModel>? questions,
    String? selectedCategoryId,
    bool clearCategory = false,
    String? searchQuery,
  }) {
    return HomeLoaded(
      categories: categories ?? this.categories,
      questions: questions ?? this.questions,
      selectedCategoryId: clearCategory ? null : (selectedCategoryId ?? this.selectedCategoryId),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  List<Object?> get props => [
        categories,
        questions,
        selectedCategoryId,
        searchQuery,
      ];
}

class HomeError extends HomeState {
  final String message;

  /// P2: til'dan mustaqil xato sinfi (`failureMessageFor` uchun).
  final FailureCode code;

  const HomeError(this.message, {this.code = FailureCode.unknown});

  @override
  List<Object?> get props => [message, code];
}
