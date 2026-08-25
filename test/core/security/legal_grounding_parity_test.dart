import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/legal_safety/law_article_chunk.dart';
import 'package:lexhub/core/legal_safety/legal_grounding_validator.dart';
import 'package:lexhub/core/legal_safety/uzbek_legal_knowledge_base.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/law_article.dart';

/// P1 REGRESSIYA QO'RIQCHISI — klient grounding filtri FAIL-OPEN edi.
///
/// ILGARI: `filterAndGroundArticles` mos chunk topilmasa
/// `orElse: () => LawArticleChunk(status: 'active')` bilan SUN'IY chunk yasab,
/// modelning kontekstda umuman bo'lmagan moddasini "tasdiqlangan" deb
/// qoldirib ketardi. Ya'ni "faqat RAG kontekstidagi moddalar ko'rsatiladi"
/// da'vosi klientda BAJARILMAYDI (`grounding.ts` izohida qayd etilgan P1).
///
/// Bu testlar aynan shu teshikni yopib turadi: filtr endi TASDIQ topilmasa
/// moddani TASHLAB YUBORISHI shart.
LawArticleChunk _chunk({
  required String documentName,
  required int articleNumber,
  String status = 'active',
}) =>
    LawArticleChunk(
      chunkId: 'c$articleNumber',
      documentName: documentName,
      documentId: 'd1',
      articleNumber: articleNumber,
      articleTitle: 'Sarlavha',
      content: 'Matn',
      status: status,
      jurisdiction: 'UZ',
      lastUpdated: '2026-01-01',
      lexUrl: 'https://lex.uz',
    );

LawArticle _article({
  required String lawName,
  required String articleNumber,
}) =>
    LawArticle(
      lawName: lawName,
      articleNumber: articleNumber,
      articleTitle: 'Sarlavha',
      articleText: 'Matn',
      lexUrl: 'https://lex.uz',
    );

void main() {
  group('filterAndGroundArticles — FAIL-CLOSED (P1 regressiya)', () {
    final corpus = [_chunk(documentName: 'Mehnat kodeksi', articleNumber: 161)];

    test('korpusda YO\'Q modda TASHLANADI (chegaradan o\'tsa ham)', () {
      // 200 <= 581, ya'ni `isValidArticleNumber` chegara filtri BUNI O'TKAZADI.
      // Demak moddani faqat grounding filtri to'sib qolishi mumkin. Fix'dan
      // oldin bu modda QOLIB ketardi.
      final grounded = LegalGroundingValidator.filterAndGroundArticles(
        articles: [
          _article(lawName: 'Mehnat kodeksi', articleNumber: '200-modda'),
        ],
        verifiedChunks: corpus,
      );
      expect(grounded, isEmpty);
    });

    test('BOSHQA hujjatning bir xil raqamli moddasi tasdiq bo\'lmaydi', () {
      // Korpusda faqat Mehnat kodeksi 161 bor. "Jinoyat kodeksi 161-modda"
      // (161 <= 302, chegaradan o'tadi) tasdiqlanmasligi kerak — aks holda
      // `kodeksi` umumiy tokeni orqali soxta tasdiq bo'lardi.
      final grounded = LegalGroundingValidator.filterAndGroundArticles(
        articles: [
          _article(lawName: 'Jinoyat kodeksi', articleNumber: '161-modda'),
        ],
        verifiedChunks: corpus,
      );
      expect(grounded, isEmpty);
    });

    test('korpusdagi modda QOLADI — nom prefiksi boshqa bo\'lsa ham', () {
      // Model hujjat nomini to'liq yozadi: "O'zbekiston Respublikasining
      // Mehnat kodeksi", chunk'da esa "Mehnat kodeksi". Ikkisi `mehnat`
      // tokenida mos keladi. (Eski `.split(' ').first` mantiqi bu yerda
      // "o'zbekiston" bo'yicha izlab MOS TOPMAGAN bo'lardi.)
      final grounded = LegalGroundingValidator.filterAndGroundArticles(
        articles: [
          _article(
            lawName: "O'zbekiston Respublikasining Mehnat kodeksi",
            articleNumber: '161-modda',
          ),
        ],
        verifiedChunks: corpus,
      );
      expect(grounded, hasLength(1));
      expect(grounded.first.articleNumber, '161-modda');
    });

    test('BEKOR QILINGAN chunk tasdiq bo\'lmaydi', () {
      final grounded = LegalGroundingValidator.filterAndGroundArticles(
        articles: [
          _article(lawName: 'Mehnat kodeksi', articleNumber: '161-modda'),
        ],
        verifiedChunks: [
          _chunk(
            documentName: 'Mehnat kodeksi',
            articleNumber: 161,
            status: 'repealed',
          ),
        ],
      );
      expect(grounded, isEmpty);
    });

    test('raqamsiz modda maydoni -> TASHLANADI', () {
      final grounded = LegalGroundingValidator.filterAndGroundArticles(
        articles: [
          _article(lawName: 'Mehnat kodeksi', articleNumber: 'Umumiy qoida'),
        ],
        verifiedChunks: corpus,
      );
      expect(grounded, isEmpty);
    });

    test('FARQLOVCHI tokeni yo\'q hujjat nomi -> TASHLANADI', () {
      // "Kodeks" -> barcha tokenlar stop-listda -> qaysi hujjat ekani
      // aniqlanmaydi -> tasdiqlanmaydi.
      final grounded = LegalGroundingValidator.filterAndGroundArticles(
        articles: [_article(lawName: 'Kodeks', articleNumber: '161-modda')],
        verifiedChunks: corpus,
      );
      expect(grounded, isEmpty);
    });

    test('"161" (modda so\'zisiz) ham tasdiqlanadi — server bilan bir xil', () {
      expect(
        LegalGroundingValidator.isGrounded(
          lawName: 'Mehnat kodeksi',
          articleNumber: '161',
          chunks: corpus,
        ),
        isTrue,
      );
    });

    test('korpus BERILMAGANDA faqat chegara filtri ishlaydi', () {
      // Bu rejim ataylab saqlangan (mavjud chegara testlari shunga tayanadi).
      final grounded = LegalGroundingValidator.filterAndGroundArticles(
        articles: [
          _article(lawName: 'Mehnat kodeksi', articleNumber: '161-modda'),
          _article(lawName: 'Mehnat kodeksi', articleNumber: '899-modda'),
        ],
      );
      expect(grounded, hasLength(1));
      expect(grounded.first.articleNumber, '161-modda');
    });

  });

  /// FAIL-CLOSED filtr faqat TO'QIMANI tashlashi kerak, HAQIQIY qonun bazasini
  /// EMAS. Agar stop-token ro'yxati yoki tokenizatsiya buzilsa, filtr o'zining
  /// tasdiqlangan korpusini ham rad etib, foydalanuvchiga huquqiy asossiz
  /// javob qaytarardi. Bu test aynan shu "over-dropping" xavfini qulflaydi.
  group('tasdiqlangan korpus O\'Z filtridan o\'tadi (over-dropping yo\'q)', () {
    test('barcha `verifiedLawChunks` moddalari grounded bo\'ladi', () {
      const chunks = UzbekLegalKnowledgeBase.verifiedLawChunks;
      expect(chunks, isNotEmpty);

      final grounded = LegalGroundingValidator.filterAndGroundArticles(
        articles: LegalKnowledgeRetriever.toDomainArticles(chunks),
        verifiedChunks: chunks,
      );

      final lost = chunks
          .where((c) => !grounded
              .any((a) => a.articleNumber.startsWith('${c.articleNumber}-')))
          .map((c) => '${c.documentName} ${c.articleNumber}')
          .toList();
      expect(lost, isEmpty, reason: 'Filtr HAQIQIY moddalarni tashladi: $lost');
      expect(grounded, hasLength(chunks.length));
    });
  });

  /// Klient filtri va server filtri BIR XIL hujjat-nomi mantiqiga tayanadi.
  /// Agar server `STOP_TOKENS`iga yangi token qo'shilsa va Dart nusxasi
  /// yangilanmasa, ikki tomon BOSHQA-BOSHQA moddalarni tasdiqlay boshlaydi —
  /// bu jimgina xavfsizlik farqi. Shuning uchun to'plam qulflanadi.
  group('grounding STOP_TOKENS pariteti (Dart ↔ Edge Function)', () {
    final tsFile = File('supabase/functions/legal-ai/grounding.ts');

    test('`grounding.ts` mavjud', () {
      expect(tsFile.existsSync(), isTrue,
          reason: 'Server grounding yadrosi yo\'q');
    });

    test('stop-token to\'plamlari AYNAN bir xil', () {
      final raw = tsFile.readAsStringSync();
      const anchor = 'STOP_TOKENS = new Set([';
      final at = raw.indexOf(anchor);
      expect(at, isNonNegative,
          reason: '`STOP_TOKENS = new Set([` deklaratsiyasi topilmadi');
      final end = raw.indexOf(']);', at);
      expect(end, isNonNegative, reason: '`]);` yopilishi topilmadi');

      final tsTokens = RegExp(r"'([^']*)'")
          .allMatches(raw.substring(at + anchor.length, end))
          .map((m) => m.group(1)!)
          .toSet();
      expect(tsTokens, isNotEmpty, reason: 'TS to\'plami bo\'sh o\'qildi');

      final dartTokens = LegalGroundingValidator.documentStopTokens;
      expect(
        tsTokens.difference(dartTokens),
        isEmpty,
        reason: 'Faqat SERVERda bor: ${tsTokens.difference(dartTokens)}',
      );
      expect(
        dartTokens.difference(tsTokens),
        isEmpty,
        reason: 'Faqat KLIENTda bor: ${dartTokens.difference(tsTokens)}',
      );
    });
  });

}
