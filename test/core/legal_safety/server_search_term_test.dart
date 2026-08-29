import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/legal_safety/law_article_chunk.dart';
import 'package:lexhub/core/legal_safety/uzbek_legal_knowledge_base.dart';

/// `term` tushadigan tasdiqlangan moddalar — serverdagi RPC ILIKE'i bilan
/// AYNI mezon (`article_title / content / document_name`).
List<LawArticleChunk> _hits(String term) =>
    UzbekLegalKnowledgeBase.verifiedLawChunks
        .where((c) =>
            c.articleTitle.toLowerCase().contains(term) ||
            c.content.toLowerCase().contains(term) ||
            c.documentName.toLowerCase().contains(term))
        .toList();

/// SERVER RAG SO'ROVI MAVZUGA QARAB FILTRLANADI.
///
/// O'LCHANGAN NUQSON (2026-08-29, production): klient
/// `law_article_chunks` ni `select() + eq('status','active') + limit(5)` bilan
/// o'qirdi — `order` YO'Q, mavzu filtri YO'Q. Jonli bazada bu so'rov savol nima
/// bo'lishidan qat'i nazar Konstitutsiyaning 27/28/29/42/44 moddalarini
/// qaytardi. Jadval 17 qatordan oshsa, mahalliy bazada YO'Q lekin ALOQADOR
/// modda hech qachon olinmasligi STRUKTURAVIY edi.
///
/// Yechim: `search_law_articles(search_query, match_count, filter_jurisdiction)`
/// RPC + klientda termin ajratish ([LegalKnowledgeRetriever.serverSearchTerm]).
///
/// JONLI O'LCHOV (2026-08-29, `anon` kalit, HTTP 200):
///   'ish haqi' -> Mehnat kodeksi 333-modda
///   'aliment'  -> Oila kodeksi 96 / 99 / 136-moddalar
void main() {
  group('serverSearchTerm — termin ajratish', () {
    test('QAMROVDAN TASHQARI so\'rovga termin BERILMAYDI (so\'rov yuborilmaydi)',
        () {
      // Qamrovdan tashqari mavzu: server javobi baribir DARVOZA 0 da
      // tashlanadi, ya'ni so'rov faqat kechikish qo'shardi.
      expect(
        LegalKnowledgeRetriever.serverSearchTerm(
            'Kosmosga uchish uchun qanday ruxsat kerak?'),
        isNull,
      );
    });

    test('MEHNAT so\'rovi: termin MEHNAT moddalariga tushadi', () {
      final query =
          "Meni ishdan bo'shatmoqchi, ish haqim ham to'lanmagan. Nima qilaman?";
      final term = LegalKnowledgeRetriever.serverSearchTerm(query);

      expect(term, isNotNull);
      expect(term!.length, lessThanOrEqualTo(6));
      expect(term.length, greaterThanOrEqualTo(4));

      // MUHIM: termin mahalliy bazadagi HAQIQIY MEHNAT moddasiga tushishi
      // kerak. Ikki nuqson shu yerda qulflanadi (ikkisi ham o'lchangan):
      //   1) "eng uzun so'z" -> `bo'sha` / `to'lam`: korpusda 0 moslik,
      //      ya'ni server ILIKE'i ham bo'sh qaytaradi;
      //   2) "korpusda uchraydigan eng uzun prefiks" -> `ishdan`: FAQAT Oila
      //      kodeksi 136-moddasiga tushardi, so'rov esa MEHNAT sohasi — bunday
      //      chunk DARVOZA 1 da tashlanadi va so'rov bekorga ketardi.
      // Mahalliy baza serverga aynan shu holda eksport qilingan
      // (`tool/export_law_chunks.dart`), ya'ni bu tekshiruv server xatti-
      // harakatining ishonchli proksisi.
      final hits = _hits(term);
      expect(hits, isNotEmpty, reason: 'termin "$term" birorta moddaga tushmadi');
      expect(
        hits.map((c) => c.jurisdiction).toSet(),
        {'Mehnat huquqi'},
        reason: 'termin "$term" mehnat sohasidan TASHQARI moddalarga tushdi — '
            'ular qamrov darvozasida tashlanadi',
      );
      // JONLI O'LCHOV (anon kalit, HTTP 200): 'ish haqi' -> Mehnat kodeksi
      // 333-modda. Shu modda ro'yxatdan chiqib ketsa termin tanlash buzilgan.
      expect(hits.map((c) => c.articleNumber), contains(333));
    });

    test('ALIMENT so\'rovi: termin OILA moddalariga tushadi', () {
      final term = LegalKnowledgeRetriever.serverSearchTerm(
          "Eks-erim farzandimga aliment to'lamayapti, nima qilishim kerak?");

      expect(term, isNotNull);
      final hits = _hits(term!);
      expect(hits.map((c) => c.jurisdiction).toSet(), {'Oila huquqi'},
          reason: 'termin "$term" oila sohasidan tashqariga chiqdi');
      // JONLI O'LCHOV (anon kalit, HTTP 200): 'aliment' -> Oila kodeksi
      // 96 / 99 / 136-moddalar. Mahalliy korpus ham AYNI shu uchligini beradi.
      expect(hits.map((c) => c.articleNumber).toSet(),
          containsAll(<int>[96, 99, 136]));
    });

    test('APOSTROF varianti termin ajratishni BUZMAYDI', () {
      // Android o'zbek klaviaturasi U+02BB kiritadi, qonun matnida U+0027.
      // `LegalCoverage.normalize` ikkisini bitta shaklga keltiradi.
      final withModifier = LegalKnowledgeRetriever.serverSearchTerm(
          "Meni ishdan boʻshatishmoqchi, mehnat shartnomasi bekor qilinadi");
      final withApostrophe = LegalKnowledgeRetriever.serverSearchTerm(
          "Meni ishdan bo'shatishmoqchi, mehnat shartnomasi bekor qilinadi");
      expect(withModifier, isNotNull);
      expect(withModifier, withApostrophe);
    });

    test('juda qisqa so\'zlar termin BO\'LMAYDI', () {
      final term = LegalKnowledgeRetriever.serverSearchTerm(
          'Sud pul ish haqi olib berdi');
      // Qamrovda bo'lsa ham 4 belgidan qisqa so'z termin bo'lmaydi.
      if (term != null) {
        expect(term.length, greaterThanOrEqualTo(4));
      }
    });
  });

  group('manba qulfi — filtrlanmagan so\'rov QAYTMASIN', () {
    final source = File(
      'lib/features/legal_assistant/data/datasources/'
      'legal_assistant_remote_datasource.dart',
    ).readAsStringSync();

    test('RAG so\'rovi `search_law_articles` RPC orqali ketadi', () {
      expect(source.contains("'search_law_articles'"), isTrue);
    });

    test('filtrlanmagan `db(\'law_article_chunks\')` so\'rovi YO\'Q', () {
      expect(
        source.contains("db('law_article_chunks')"),
        isFalse,
        reason: 'mavzuga filtrlanmagan server so\'rovi qaytib kelgan — '
            'jadvaldagi BIRINCHI N qator har qanday savolga ilashadi',
      );
    });

    test('so\'rovda TIMEOUT bor (AI inferensiyasidan oldin turadi)', () {
      final idx = source.indexOf("'search_law_articles'");
      expect(idx, greaterThan(-1));
      final window = source.substring(idx, idx + 900);
      expect(window.contains('withTimeout'), isTrue);
    });
  });
}
