import 'package:equatable/equatable.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/law_article.dart';

/// Database Article Chunk Schema for Vector RAG (Lex.uz Grounding)
class LawArticleChunk extends Equatable {
  final String chunkId;
  final String documentName;
  final String documentId;
  final int articleNumber;
  final String articleTitle;
  final String content;
  final String status;
  final String jurisdiction;
  final String lastUpdated;
  final String lexUrl;

  const LawArticleChunk({
    required this.chunkId,
    required this.documentName,
    required this.documentId,
    required this.articleNumber,
    required this.articleTitle,
    required this.content,
    required this.status,
    required this.jurisdiction,
    required this.lastUpdated,
    required this.lexUrl,
  });

  bool get isActive => status.toLowerCase() == 'active';

  factory LawArticleChunk.fromJson(Map<String, dynamic> json) {
    return LawArticleChunk(
      chunkId: json['chunk_id'] as String? ?? '',
      documentName: json['document_name'] as String? ?? '',
      documentId: json['document_id'] as String? ?? '',
      articleNumber: json['article_number'] is int
          ? json['article_number'] as int
          : int.tryParse(json['article_number'].toString()) ?? 0,
      articleTitle: json['article_title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
      jurisdiction: json['jurisdiction'] as String? ?? 'General',
      lastUpdated: json['last_updated'] as String? ?? '',
      lexUrl: json['lex_url'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'chunk_id': chunkId,
      'document_name': documentName,
      'document_id': documentId,
      'article_number': articleNumber,
      'article_title': articleTitle,
      'content': content,
      'status': status,
      'jurisdiction': jurisdiction,
      'last_updated': lastUpdated,
      'lex_url': lexUrl,
    };
  }

  LawArticle toLawArticle() {
    return LawArticle(
      lawName: documentName,
      articleNumber: "$articleNumber-modda",
      articleTitle: articleTitle,
      articleText: content,
      lexUrl: lexUrl,
    );
  }

  @override
  List<Object?> get props => [
        chunkId,
        documentName,
        documentId,
        articleNumber,
        articleTitle,
        content,
        status,
        jurisdiction,
        lastUpdated,
        lexUrl,
      ];
}
