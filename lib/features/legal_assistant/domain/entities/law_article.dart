import 'package:equatable/equatable.dart';

/// Represents a specific law article from Uzbekistan legal database (Lex.uz)
class LawArticle extends Equatable {
  final String lawName;
  final String articleNumber;
  final String articleTitle;
  final String articleText;
  final String lexUrl;

  const LawArticle({
    required this.lawName,
    required this.articleNumber,
    required this.articleTitle,
    required this.articleText,
    required this.lexUrl,
  });

  factory LawArticle.fromJson(Map<String, dynamic> json) {
    return LawArticle(
      lawName: json['lawName'] as String? ?? json['law_name'] as String? ?? '',
      articleNumber: json['articleNumber'] as String? ?? json['article_number'] as String? ?? '',
      articleTitle: json['articleTitle'] as String? ?? json['article_title'] as String? ?? '',
      articleText: json['articleText'] as String? ?? json['article_text'] as String? ?? '',
      lexUrl: json['lexUrl'] as String? ?? json['lex_url'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'law_name': lawName,
      'article_number': articleNumber,
      'article_title': articleTitle,
      'article_text': articleText,
      'lex_url': lexUrl,
    };
  }

  LawArticle copyWith({
    String? lawName,
    String? articleNumber,
    String? articleTitle,
    String? articleText,
    String? lexUrl,
  }) {
    return LawArticle(
      lawName: lawName ?? this.lawName,
      articleNumber: articleNumber ?? this.articleNumber,
      articleTitle: articleTitle ?? this.articleTitle,
      articleText: articleText ?? this.articleText,
      lexUrl: lexUrl ?? this.lexUrl,
    );
  }

  @override
  List<Object?> get props => [
        lawName,
        articleNumber,
        articleTitle,
        articleText,
        lexUrl,
      ];
}
