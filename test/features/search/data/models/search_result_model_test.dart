import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/features/search/data/models/search_result_model.dart';
import 'package:lexhub/features/search/domain/entities/search_result_item.dart';

void main() {
  group('SearchResultModel Unit Tests', () {
    test('1. fromJson maps all fields correctly for Law result', () {
      final json = {
        'id': 'law_1',
        'result_type': 'law',
        'title': 'Mehnat kodeksi — 161-modda',
        'subtitle': 'Mehnat shartnomasini bekor qilish',
        'snippet': 'Ish beruvchi tashabbusi bilan bekor qilish asoslari...',
        'category': 'O\'zbekiston Respublikasi',
        'metadata': {
          'lex_url': 'https://lex.uz/docs/6257288#6273110',
          'article_number': 161,
          'document_name': 'Mehnat kodeksi',
          'status': 'active',
        },
        'relevance_score': 0.95,
      };

      final model = SearchResultModel.fromJson(json);

      expect(model.id, 'law_1');
      expect(model.type, SearchResultType.law);
      expect(model.title, 'Mehnat kodeksi — 161-modda');
      expect(model.subtitle, 'Mehnat shartnomasini bekor qilish');
      expect(model.lexUrl, 'https://lex.uz/docs/6257288#6273110');
      expect(model.relevanceScore, 0.95);
    });

    test('2. fromJson maps Expert, Service, Template and Question results', () {
      // Expert
      final expertJson = {
        'id': 'exp_1',
        'result_type': 'expert',
        'title': 'Aziz Karimov',
        'subtitle': 'Mehnat huquqi • Toshkent sh.',
        'snippet': '10 yillik tajribaga ega advokat',
        'category': 'Mehnat',
        'metadata': {
          'is_verified': true,
          'rating': 4.9,
          'experience_years': 10,
          'reviews_count': 32,
        },
        'relevance_score': 0.9,
      };

      final expertModel = SearchResultModel.fromJson(expertJson);
      expect(expertModel.type, SearchResultType.expert);
      expect(expertModel.isVerified, true);
      expect(expertModel.rating, 4.9);

      // Service
      final serviceJson = {
        'id': 'srv_1',
        'result_type': 'service',
        'title': 'Pasport olish',
        'subtitle': 'IIV',
        'snippet': 'ID karta rasmiylashtirish',
        'category': 'Davlat xizmatlari',
        'metadata': {
          'cost_bhm_percent': 89.0,
          'is_free': false,
          'processing_days': 3,
        },
        'relevance_score': 0.85,
      };

      final serviceModel = SearchResultModel.fromJson(serviceJson);
      expect(serviceModel.type, SearchResultType.service);
      expect(serviceModel.costBhmPercent, 89.0);
      expect(serviceModel.isFree, false);

      // Template
      final templateJson = {
        'id': 'tpl_1',
        'result_type': 'template',
        'title': 'Aliment arizasi',
        'subtitle': 'Fuqarolik sudi',
        'snippet': 'Sud buyrug\'i chiqarish haqida',
        'category': 'Oila huquqi',
        'metadata': {
          'source_url': 'https://lex.uz/docs/104720',
          'is_popular': true,
        },
        'relevance_score': 0.9,
      };

      final templateModel = SearchResultModel.fromJson(templateJson);
      expect(templateModel.type, SearchResultType.template);
      expect(templateModel.lexUrl, 'https://lex.uz/docs/104720');

      // Question
      final questionJson = {
        'id': 'q_1',
        'result_type': 'question',
        'title': 'Ish haqim berilmayapti, nima qilsam bo\'ladi?',
        'subtitle': 'Hamjamiyat savoli',
        'snippet': '3 oydan beri oylik kechikmoqda',
        'category': 'Mehnat',
        'metadata': {
          'answers_count': 5,
          'upvotes_count': 12,
        },
        'relevance_score': 0.75,
      };

      final questionModel = SearchResultModel.fromJson(questionJson);
      expect(questionModel.type, SearchResultType.question);
      expect(questionModel.answersCount, 5);
    });

    test('3. toJson converts back faithfully', () {
      const model = SearchResultModel(
        id: 'law_100',
        type: SearchResultType.law,
        title: 'Konstitutsiya 27-modda',
        snippet: 'Shaxsiy daxlsizlik',
        category: 'Konstitutsiya',
        relevanceScore: 1.0,
      );

      final json = model.toJson();
      expect(json['id'], 'law_100');
      expect(json['result_type'], 'law');
      expect(json['relevance_score'], 1.0);
    });
  });
}
