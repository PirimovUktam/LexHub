import 'package:equatable/equatable.dart';

enum SearchResultType {
  all,
  law,
  expert,
  service,
  template,
  question;

  // UI YORLIG'I ATAYLAB BU YERDA YO'Q.
  // Yorliqlar `lib/core/localization/search_labels.dart` -> searchResultTypeLabel().
  // `fromString()` qabul qiladigan xom qiymatlar — kontrakt, o'zgartirilmaydi.

  static SearchResultType fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'law':
        return SearchResultType.law;
      case 'expert':
        return SearchResultType.expert;
      case 'service':
        return SearchResultType.service;
      case 'template':
        return SearchResultType.template;
      case 'question':
        return SearchResultType.question;
      default:
        return SearchResultType.all;
    }
  }
}

class SearchResultItem extends Equatable {
  final String id;
  final SearchResultType type;
  final String title;
  final String? subtitle;
  final String snippet;
  final String category;
  final Map<String, dynamic> metadata;
  final double relevanceScore;

  const SearchResultItem({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle,
    required this.snippet,
    required this.category,
    this.metadata = const {},
    this.relevanceScore = 0.0,
  });

  String? get lexUrl => metadata['lex_url'] as String? ?? metadata['source_url'] as String?;
  bool get isVerified => metadata['is_verified'] == true;
  double get rating => (metadata['rating'] as num?)?.toDouble() ?? 0.0;
  bool get isFree => metadata['is_free'] == true;
  double get costBhmPercent => (metadata['cost_bhm_percent'] as num?)?.toDouble() ?? 0.0;
  int get answersCount => (metadata['answers_count'] as num?)?.toInt() ?? 0;

  @override
  List<Object?> get props => [
        id,
        type,
        title,
        subtitle,
        snippet,
        category,
        metadata,
        relevanceScore,
      ];
}
