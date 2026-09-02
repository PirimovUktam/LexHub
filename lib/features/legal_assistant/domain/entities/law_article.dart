import 'package:lexhub/core/utils/json_coerce.dart';
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
      lawName: jsonText(json['lawName']) ?? jsonText(json['law_name']) ?? '',
      // DIQQAT: model modda raqamini RAQAM sifatida yuborishi odatiy hol —
      // `as String?` bu yerda `type 'int' is not a subtype` bilan yiqilardi.
      articleNumber:
          jsonText(json['articleNumber']) ?? jsonText(json['article_number']) ?? '',
      articleTitle:
          jsonText(json['articleTitle']) ?? jsonText(json['article_title']) ?? '',
      articleText:
          jsonText(json['articleText']) ?? jsonText(json['article_text']) ?? '',
      lexUrl: jsonText(json['lexUrl']) ?? jsonText(json['lex_url']) ?? '',
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
