import 'package:lexhub/features/search/domain/entities/search_result_item.dart';

class SearchResultModel extends SearchResultItem {
  const SearchResultModel({
    required super.id,
    required super.type,
    required super.title,
    super.subtitle,
    required super.snippet,
    required super.category,
    super.metadata,
    super.relevanceScore,
  });

  factory SearchResultModel.fromJson(Map<String, dynamic> json) {
    final typeStr = json['result_type'] as String? ?? json['type'] as String?;
    final meta = json['metadata'] is Map<String, dynamic>
        ? json['metadata'] as Map<String, dynamic>
        : <String, dynamic>{};

    return SearchResultModel(
      id: json['id']?.toString() ?? '',
      type: SearchResultType.fromString(typeStr),
      title: json['title'] as String? ?? 'Nomsiz',
      subtitle: json['subtitle'] as String?,
      snippet: json['snippet'] as String? ?? '',
      category: json['category'] as String? ?? 'Umumiy',
      metadata: meta,
      relevanceScore: (json['relevance_score'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'result_type': type.name,
      'title': title,
      'subtitle': subtitle,
      'snippet': snippet,
      'category': category,
      'metadata': metadata,
      'relevance_score': relevanceScore,
    };
  }
}
