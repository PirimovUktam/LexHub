// DUSHMANONA PAYLOAD TESTLARI (P2 — hard cast) .
//
// NIMANI ISBOTLAYDI: model yoki Hive cache NOTO'G'RI TUR yuborganda
// `fromJson` exception TASHLAMAYDI va maydon standart qiymatga tushadi.
//
// NIMA UCHUN MUHIM: ilgari entity'lar `json['x'] as String?` shaklidan
// foydalanardi. Real xavflar O'LCHANGAN:
//   * Gemini `"article_number": 161` (RAQAM) yuboradi -> `type 'int' is not
//     a subtype of type 'String?'` -> butun huquqiy javob `ServerException`;
//   * `"deadline_days": "30"` (SATR) -> `int?` cast yiqiladi;
//   * Hive cache'dan o'qilgan ichki obyektlar `Map<dynamic, dynamic>` —
//     `whereType<Map<String, dynamic>>()` ularni JIMGINA tashlab yuborardi,
//     natijada `legal_basis` BO'SH qolib javob asossiz ko'rinardi.
//
// Bu yerdagi har bir `expect` shu stsenariylardan BIRINI qulflaydi.

import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/emergency_protocol.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/law_article.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_query.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_response.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/risk_assessment.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/risk_level.dart';

void main() {
  group('LawArticle — modda raqami RAQAM sifatida kelsa', () {
    test('article_number: 161 (int) -> "161"', () {
      final article = LawArticle.fromJson(<String, dynamic>{
        'law_name': 'Mehnat kodeksi',
        'article_number': 161,
        'article_title': 'Asoslar',
        'article_text': 'Matn',
        'lex_url': 'https://lex.uz/docs/6257288',
      });
      expect(article.articleNumber, '161');
      expect(article.lawName, 'Mehnat kodeksi');
    });

    test('barcha maydonlar noto\'g\'ri turda -> bo\'sh satr, exception YO\'Q',
        () {
      late LawArticle article;
      expect(
        () => article = LawArticle.fromJson(<String, dynamic>{
          'law_name': true,
          'article_number': <String, dynamic>{'a': 1},
          'article_title': <int>[1],
          'article_text': null,
          'lex_url': false,
        }),
        returnsNormally,
      );
      expect(article.lawName, '');
      expect(article.articleNumber, '');
      expect(article.articleTitle, '');
      expect(article.articleText, '');
      expect(article.lexUrl, '');
    });
  });

  group('RiskAssessment — muddat va bayroq turlari', () {
    test('deadline_days: "30" (satr) va 30.0 (double) -> 30', () {
      expect(
        RiskAssessment.fromJson(<String, dynamic>{'deadline_days': '30'})
            .deadlineDays,
        30,
      );
      expect(
        RiskAssessment.fromJson(<String, dynamic>{'deadlineDays': 30.0})
            .deadlineDays,
        30,
      );
    });

    test('deadline_days ma\'nosiz bo\'lsa -> null (soxta muddat ko\'rsatilmaydi)',
        () {
      expect(
        RiskAssessment.fromJson(
                <String, dynamic>{'deadline_days': "o'ttiz kun"})
            .deadlineDays,
        isNull,
      );
    });

    test('requires_lawyer: "true" / 1 -> true; summary: 42 -> "42"', () {
      expect(
        RiskAssessment.fromJson(<String, dynamic>{'requires_lawyer': 'true'})
            .requiresLawyer,
        isTrue,
      );
      expect(
        RiskAssessment.fromJson(<String, dynamic>{'requiresLawyer': 1})
            .requiresLawyer,
        isTrue,
      );
      expect(
        RiskAssessment.fromJson(<String, dynamic>{'summary': 42}).summary,
        '42',
      );
    });

    test('requires_lawyer noaniq bo\'lsa -> false (fail-closed)', () {
      expect(
        RiskAssessment.fromJson(<String, dynamic>{'requires_lawyer': 'ha'})
            .requiresLawyer,
        isFalse,
      );
    });
  });

  group('EmergencyProtocol — bayroq va ishonch telefoni', () {
    test('is_emergency: "true" -> true; hotline RAQAM kelsa matnga o\'giriladi',
        () {
      final protocol = EmergencyProtocol.fromJson(<String, dynamic>{
        'is_emergency': 'true',
        'title': 'Tezkor himoya',
        'emergency_hotline': 1002,
      });
      expect(protocol.isEmergency, isTrue);
      expect(protocol.emergencyHotline, '1002');
    });

    test('hotline noto\'g\'ri turda -> standart "1002" SAQLANADI', () {
      // Ishonch telefoni bo'sh qolsa favqulodda holatda foydalanuvchi
      // qo'ng'iroq qila olmaydi — shuning uchun standart qiymat majburiy.
      final protocol = EmergencyProtocol.fromJson(<String, dynamic>{
        'title': 'Holat',
        'emergency_hotline': <String, dynamic>{},
      });
      expect(protocol.emergencyHotline, '1002');
      expect(protocol.isEmergency, isFalse);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // HIVE CACHE REGRESSIYASI: ichki obyektlar `Map<dynamic, dynamic>` bo'ladi
  // ══════════════════════════════════════════════════════════════════════
  group('LegalResponse — Hive cache\'dan o\'qilgan payload', () {
    /// Hive `Map<String, dynamic>`ni QAYTA O'QIGANDA ichki obyektlarni
    /// `Map<dynamic, dynamic>` sifatida beradi. Aynan shu shakl.
    Map<String, dynamic> hiveLike() => <String, dynamic>{
          'id': 'resp_1',
          'query_id': 'q_1',
          'relatable_summary': 'Ishdan bo\'shatish noqonuniy',
          'actionable_steps': <dynamic>['Sudga ariza bering', 42],
          'legal_basis': <dynamic>[
            <dynamic, dynamic>{
              'law_name': 'Mehnat kodeksi',
              'article_number': 161,
              'article_title': 'Asoslar',
              'article_text': 'Matn',
              'lex_url': 'https://lex.uz',
            },
            <dynamic, dynamic>{
              'law_name': 'Mehnat kodeksi',
              'article_number': '333-modda',
            },
          ],
          'risk_assessment': <dynamic, dynamic>{
            'level': 'high',
            'summary': 'Yuqori xavf',
            'deadline_days': '30',
            'requires_lawyer': 1,
          },
          'emergency_protocol': <dynamic, dynamic>{
            'is_emergency': 'true',
            'title': 'Tezkor himoya',
          },
          'created_at': '2026-08-26T10:00:00.000Z',
          'is_saved': 'true',
          'is_completed': 1,
        };

    test('legal_basis JIMGINA TASHLANMAYDI — 2 modda ham parse qilinadi', () {
      final response = LegalResponse.fromJson(hiveLike());
      // Ilgari bu yerda 0 bo'lardi: `whereType<Map<String, dynamic>>()`
      // Hive elementlarini filtrlab tashlardi va javob asossiz ko'rinardi.
      expect(response.legalBasis.length, 2);
      expect(response.legalBasis.first.articleNumber, '161');
      expect(response.legalBasis[1].articleNumber, '333-modda');
    });

    test('ichki risk_assessment va emergency_protocol ham o\'qiladi', () {
      final response = LegalResponse.fromJson(hiveLike());
      expect(response.riskAssessment.level, RiskLevel.high);
      expect(response.riskAssessment.summary, 'Yuqori xavf');
      expect(response.riskAssessment.deadlineDays, 30);
      expect(response.riskAssessment.requiresLawyer, isTrue);
      expect(response.emergencyProtocol, isNotNull);
      expect(response.emergencyProtocol!.isEmergency, isTrue);
      expect(response.emergencyProtocol!.emergencyHotline, '1002');
    });

    test('bayroqlar "true"/1 shaklida ham tushuniladi', () {
      final response = LegalResponse.fromJson(hiveLike());
      expect(response.isSaved, isTrue);
      expect(response.isCompleted, isTrue);
      expect(response.actionableSteps, ['Sudga ariza bering', '42']);
      // Cache'da `source` yo'q -> "AI" da'vosi QILINMAYDI.
      expect(response.isAiGenerated, isFalse);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // ENG QATTIQ DA'VO: HAR BIR maydon noto'g'ri turda bo'lsa ham parse
  // qilinadi. Bu — "bitta buzuq maydon butun javobni yo'q qilmaydi"
  // prinsipining testi.
  // ══════════════════════════════════════════════════════════════════════
  group('LegalResponse — TO\'LIQ buzuq payload', () {
    final chaos = <String, dynamic>{
      'id': <int>[1],
      'query_id': true,
      'user_query': <String, dynamic>{'a': 1},
      'category': false,
      'relatable_summary': <int>[],
      'actionable_steps': <String, dynamic>{'1': 'x'},
      'legal_basis': 'matn',
      'risk_assessment': 'matn',
      'emergency_protocol': 42,
      'created_at': <int>[2026],
      'is_saved': 'ha',
      'is_completed': 7,
      'source': 3.14,
    };

    test('exception TASHLAMAYDI', () {
      expect(() => LegalResponse.fromJson(chaos), returnsNormally);
    });

    test('har bir maydon xavfsiz standart qiymatga tushadi', () {
      final response = LegalResponse.fromJson(chaos);
      expect(response.id, '');
      expect(response.queryId, '');
      expect(response.userQuery, '');
      expect(response.category, 'Umumiy huquq');
      expect(response.relatableSummary, '');
      expect(response.actionableSteps, isEmpty);
      expect(response.legalBasis, isEmpty);
      expect(response.riskAssessment.level, RiskLevel.low);
      expect(response.riskAssessment.summary, 'Risk tahlili mavjud emas');
      expect(response.emergencyProtocol, isNull);
      expect(response.isSaved, isFalse);
      expect(response.isCompleted, isFalse);
      // HALOLLIK: buzuq payload HECH QACHON "AI" yorlig'ini olmaydi.
      expect(response.source, LegalResponse.sourceDeterministic);
      expect(response.isAiGenerated, isFalse);
    });

    test('buzuq created_at -> parse qilinadi, sana tushib qolmaydi', () {
      // `DateTime` majburiy maydon; parse bo'lmasa `DateTime.now()`ga
      // tushadi (javobni yo'qotishdan afzal).
      final before = DateTime.now().subtract(const Duration(seconds: 5));
      final response = LegalResponse.fromJson(chaos);
      expect(response.createdAt.isAfter(before), isTrue);
    });
  });

  group('LegalQuery — buzuq payload', () {
    test('id: 7 -> "7"; is_emergency: 1 -> true; query_text RAQAM', () {
      final query = LegalQuery.fromJson(<String, dynamic>{
        'id': 7,
        'query_text': 161,
        'category': 'Mehnat huquqi',
        'created_at': '2026-08-26T10:00:00.000Z',
        'is_emergency': 1,
      });
      expect(query.id, '7');
      expect(query.queryText, '161');
      expect(query.category, 'Mehnat huquqi');
      expect(query.isEmergency, isTrue);
    });

    test('barcha maydonlar buzuq -> exception YO\'Q, standart qiymatlar', () {
      late LegalQuery query;
      expect(
        () => query = LegalQuery.fromJson(<String, dynamic>{
          'id': <String, dynamic>{},
          'query_text': true,
          'category': <int>[1],
          'created_at': 'sana emas',
          'is_emergency': 'balki',
        }),
        returnsNormally,
      );
      expect(query.id, '');
      expect(query.queryText, '');
      expect(query.category, isNull);
      expect(query.isEmergency, isFalse);
    });
  });
}
