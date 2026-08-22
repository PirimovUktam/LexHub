import 'package:equatable/equatable.dart';

/// Represents user legal query
class LegalQuery extends Equatable {
  final String id;
  final String queryText;
  final String? category;
  final DateTime createdAt;
  final bool isEmergency;

  const LegalQuery({
    required this.id,
    required this.queryText,
    this.category,
    required this.createdAt,
    this.isEmergency = false,
  });

  factory LegalQuery.fromJson(Map<String, dynamic> json) {
    return LegalQuery(
      id: json['id'] as String? ?? '',
      queryText: json['query_text'] as String? ?? json['queryText'] as String? ?? '',
      category: json['category'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : (json['createdAt'] != null
              ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
              : DateTime.now()),
      isEmergency: json['is_emergency'] as bool? ?? json['isEmergency'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'query_text': queryText,
      'category': category,
      'created_at': createdAt.toIso8601String(),
      'is_emergency': isEmergency,
    };
  }

  LegalQuery copyWith({
    String? id,
    String? queryText,
    String? category,
    DateTime? createdAt,
    bool? isEmergency,
  }) {
    return LegalQuery(
      id: id ?? this.id,
      queryText: queryText ?? this.queryText,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      isEmergency: isEmergency ?? this.isEmergency,
    );
  }

  @override
  List<Object?> get props => [
        id,
        queryText,
        category,
        createdAt,
        isEmergency,
      ];
}
