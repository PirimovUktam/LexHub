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
  String content = 'Matn',
  String lexUrl = 'https://lex.uz',
  String articleTitle = 'Sarlavha',
}) =>
    LawArticleChunk(
      chunkId: 'c$articleNumber',
      documentName: documentName,
      documentId: 'd1',
      articleNumber: articleNumber,
      articleTitle: articleTitle,
      content: content,
      status: status,
      jurisdiction: 'UZ',
      lastUpdated: '2026-01-01',
      lexUrl: lexUrl,
    );

LawArticle _article({
  required String lawName,
  required String articleNumber,
  String articleText = 'Matn',
  String lexUrl = 'https://lex.uz',
  String articleTitle = 'Sarlavha',
}) =>
    LawArticle(
      lawName: lawName,
      articleNumber: articleNumber,
      articleTitle: articleTitle,
      articleText: articleText,
      lexUrl: lexUrl,
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

    test('iqtibos eng kam uzunligi ikki tomonda BIR XIL', () {
      // Chegara farq qilsa, server rad etgan qisqa "iqtibos" klientda
      // TASDIQLANGAN bo'lib o'tib ketardi (yoki teskarisi) — ya'ni bir xil
      // javob qaysi shox ishlaganiga qarab boshqacha tekshiriladi.
      final raw = tsFile.readAsStringSync();
      final m = RegExp(r'MIN_QUOTE_CHARS\s*=\s*(\d+)').firstMatch(raw);
      expect(m, isNotNull,
          reason: '`MIN_QUOTE_CHARS` serverda topilmadi — iqtibos '
              'tekshiruvi olib tashlanganmi?');
      expect(int.parse(m!.group(1)!), LegalGroundingValidator.minQuoteChars);
    });
  });

  /// P1 — TASDIQLANGAN MODDA RAQAMI OSTIDA TO'QILGAN MATN VA HAVOLA.
  ///
  /// Modda raqamining tasdiqlanishi modelning o'sha modda MATNINI to'g'ri
  /// yozganini bildirmaydi. Ilgari `articleText`, `lexUrl`, `articleTitle` va
  /// `lawName` MODELDAN o'tib ketardi: foydalanuvchi to'g'ri raqam ostida
  /// to'qilgan iqtibosni va BOSHQA moddaga olib boradigan lex.uz havolasini
  /// "tasdiqlangan" ko'rinishida olardi. Bu shoxlar real:
  /// `legal_assistant_remote_datasource.dart` da `geminiService` va o'z
  /// backend'i javobi `LegalResponse.fromJson` bilan MODEL JSON'idan quriladi.
  group('ko\'rsatiladigan maydonlar CHUNK\'dan olinadi (P1)', () {
    final corpus = [
      _chunk(
        documentName: "O'zbekiston Respublikasi Mehnat kodeksi",
        articleNumber: 161,
        articleTitle: 'Ishga tiklash',
        content: "Noqonuniy bo'shatilgan xodim ishga tiklanadi.",
        lexUrl: 'https://lex.uz/docs/haqiqiy',
      ),
    ];

    test('TO\'QILGAN iqtibos rasmiy matn bilan almashtiriladi va SANALADI', () {
      final result = LegalGroundingValidator.groundArticles(
        articles: [
          _article(
            lawName: 'Mehnat kodeksi',
            articleNumber: '161-modda',
            articleText: 'Xodim uch oylik kompensatsiya oladi.',
          ),
        ],
        verifiedChunks: corpus,
      );
      expect(result.articles, hasLength(1));
      expect(result.articles.first.articleText, corpus.first.content);
      expect(result.replacedQuotes, 1);
    });

    test('AYNAN mos iqtibos SAQLANADI (registr/bo\'shliq farqi kechiriladi)',
        () {
      final result = LegalGroundingValidator.groundArticles(
        articles: [
          _article(
            lawName: 'Mehnat kodeksi',
            articleNumber: '161-modda',
            articleText: '  XODIM   ishga tiklanadi ',
          ),
        ],
        verifiedChunks: corpus,
      );
      expect(result.articles.first.articleText, '  XODIM   ishga tiklanadi ');
      expect(result.replacedQuotes, 0);
    });

    test('QISQA "iqtibos" tekshiruvni o\'tkazib yubormaydi', () {
      // `'a'` deyarli har qanday o'zbek matnida bor: `minQuoteChars` bo'lmasa
      // bu substring tekshiruvini bekorga o'tkazardi.
      final result = LegalGroundingValidator.groundArticles(
        articles: [
          _article(
              lawName: 'Mehnat kodeksi',
              articleNumber: '161-modda',
              articleText: 'a'),
        ],
        verifiedChunks: corpus,
      );
      expect(result.articles.first.articleText, corpus.first.content);
      expect(result.replacedQuotes, 1);
    });

    test('SOXTA lex.uz havolasi TASHLANADI, chunk havolasi qo\'yiladi', () {
      final result = LegalGroundingValidator.groundArticles(
        articles: [
          _article(
            lawName: 'Mehnat kodeksi',
            articleNumber: '161-modda',
            lexUrl: 'https://lex.uz/docs/soxta',
            articleTitle: "To'qilgan sarlavha",
          ),
        ],
        verifiedChunks: corpus,
      );
      expect(result.articles.first.lexUrl, 'https://lex.uz/docs/haqiqiy');
      expect(result.articles.first.articleTitle, 'Ishga tiklash');
      expect(result.articles.first.lawName, corpus.first.documentName);
      // Modda RAQAMI modelning yozilishida qoladi (server bilan bir xil):
      // foydalanuvchi so'ragan shakl saqlanadi.
      expect(result.articles.first.articleNumber, '161-modda');
    });

    test('chunk havolasi BO\'SH bo\'lsa BO\'SH qoladi (fail-closed)', () {
      final result = LegalGroundingValidator.groundArticles(
        articles: [
          _article(
            lawName: 'Mehnat kodeksi',
            articleNumber: '161-modda',
            lexUrl: 'https://lex.uz/docs/soxta',
          ),
        ],
        verifiedChunks: [
          _chunk(documentName: 'Mehnat kodeksi', articleNumber: 161, lexUrl: ''),
        ],
      );
      expect(result.articles.first.lexUrl, isEmpty,
          reason: 'noto\'g\'ri havoladan ko\'ra havolasizlik yaxshi');
    });

    test('iqtibos BO\'SH bo\'lsa almashtirish SANALMAYDI', () {
      // Model matn bermadi — bu YOLG'ON emas, kamchilik. Rasmiy matn
      // qo'yiladi, lekin hisoblagich AYNAN noto'g'ri iqtibos uchun.
      final result = LegalGroundingValidator.groundArticles(
        articles: [
          _article(
              lawName: 'Mehnat kodeksi',
              articleNumber: '161-modda',
              articleText: ''),
        ],
        verifiedChunks: corpus,
      );
      expect(result.articles.first.articleText, corpus.first.content);
      expect(result.replacedQuotes, 0);
    });

    test('korpus BERILMAGANDA maydonlar O\'ZGARTIRILMAYDI', () {
      // Tasdiqlovchi chunk yo'q, ya'ni almashtiradigan RASMIY matn ham yo'q.
      // Bu rejim faqat chegara evristikasi uchun (mavjud testlar shunga
      // tayanadi) va production yo'li HAR DOIM chunk beradi.
      final result = LegalGroundingValidator.groundArticles(
        articles: [
          _article(
            lawName: 'Mehnat kodeksi',
            articleNumber: '161-modda',
            articleText: 'Model matni',
            lexUrl: 'https://lex.uz/docs/model',
          ),
        ],
      );
      expect(result.articles.first.articleText, 'Model matni');
      expect(result.articles.first.lexUrl, 'https://lex.uz/docs/model');
      expect(result.replacedQuotes, 0);
    });

    test('`filterAndGroundArticles` eski imzosi ISHLASHDA DAVOM etadi', () {
      // Mavjud chaqiruvchilar va testlar buzilmasligi kerak.
      final grounded = LegalGroundingValidator.filterAndGroundArticles(
        articles: [_article(lawName: 'Mehnat kodeksi', articleNumber: '161')],
        verifiedChunks: corpus,
      );
      expect(grounded, hasLength(1));
      expect(grounded.first.articleText, corpus.first.content);
    });
  });

}
