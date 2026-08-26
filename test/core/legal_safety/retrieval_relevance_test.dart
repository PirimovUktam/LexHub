import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/legal_safety/uzbek_legal_knowledge_base.dart';

/// Retrieval relevance regressiya testi.
///
/// REAL QURILMADA OLINGAN NUQSON (emulator-5554, release APK, 23-avgust):
/// "Ishdan nohaq bo'shatish" chip'i yuborilganda javobdagi "Huquqiy asos"
/// bo'limida Oila kodeksining 96-moddasi — "Ota-onaning voyaga yetmagan
/// bolalariga ta'minot berish majburiyati" — ko'rsatildi. Ishdan bo'shatish
/// masalasiga bu moddaning ALOQASI YO'Q.
///
/// Root cause: so'rovdagi `ravishda` ("asossiz RAVISHDA") so'zi 96-modda
/// matnidagi "ixtiyoriy RAVISHDA bajarmagan" iborasiga tushib +3 ball bergan,
/// `score > 0` sharti esa shuni yetarli deb hisoblagan.
///
/// `LegalGroundingValidator` bu xatoni TUTMAYDI: u modda haqiqiy bazada
/// bor-yo'qligini tekshiradi, mavzuga aloqadorligini emas. Ya'ni himoya
/// qatlami aynan SHU YERDA bo'lishi kerak.
void main() {
  group('LegalKnowledgeRetriever relevantlik', () {
    test('mehnat so\'rovi FAQAT mehnat moddalarini qaytaradi (96-modda YO\'Q)',
        () {
      const q =
          "Ish beruvchi meni asossiz ravishda o'z xohishim bilan ariza yozishga majburlamoqda va ishdan bo'shatmoqchi. Qanday huquqlarim bor?";

      final chunks =
          LegalKnowledgeRetriever.retrieveRelevantChunks(q, maxResults: 3);

      expect(chunks, isNotEmpty, reason: 'Mehnat moddalari topilishi shart');

      // Kutilgan asosiy modda: MK 161 (ish beruvchi tashabbusi bilan bekor qilish)
      expect(
        chunks.any((c) => c.articleNumber == 161),
        isTrue,
        reason: 'Mehnat kodeksi 161-moddasi qaytishi kerak',
      );

      // Regressiya qulfi: oila/aliment moddalari mehnat so'roviga tushmasin.
      for (final c in chunks) {
        expect(
          c.documentName.toLowerCase().contains('oila'),
          isFalse,
          reason:
              'Mehnat so\'roviga Oila kodeksi moddasi ilashdi: ${c.articleNumber} — ${c.articleTitle}',
        );
      }
    });

    test('aliment so\'rovi oila moddalarini qaytaradi (teskari tomon)', () {
      const q = "Eram aliment to'lamayapti, farzandim uchun ta'minot kerak.";

      final chunks =
          LegalKnowledgeRetriever.retrieveRelevantChunks(q, maxResults: 3);

      expect(chunks, isNotEmpty);
      expect(
        chunks.any((c) => c.documentName.toLowerCase().contains('oila')),
        isTrue,
        reason:
            'Chegara oshirilgandan keyin HAQIQIY oila moddalari ham yo\'qolmasligi kerak',
      );
    });

    test("apostrofli so'z bo'linib ketmaydi — `bo'shat` sinonimi ishlaydi", () {
      // Ilgari regex `'` ni ajratuvchi deb bilgani uchun "bo'shatmoqchi"
      // ["bo", "shatmoqchi"] ga bo'linardi va `_synonyms['bo\'shat']`
      // (bekor qilish / mehnat shartnomasi / ishdan) HECH QACHON qo'shilmasdi.
      const q = "Meni ishdan bo'shatmoqchi.";

      final chunks =
          LegalKnowledgeRetriever.retrieveRelevantChunks(q, maxResults: 3);

      expect(
        chunks.any((c) => c.documentName.toLowerCase().contains('mehnat')),
        isTrue,
        reason: 'Apostrofli so\'rov mehnat moddalarini topishi kerak',
      );
    });
  });

  /// FAIL-CLOSED regressiya guruhi (2026-08-26 audit).
  ///
  /// O'LCHANGAN DEFEKT: `retrieveRelevantChunks` nol ball holatida
  /// `verifiedLawChunks.take(maxResults)` — korpusning BIRINCHI 3 moddasini
  /// (Konstitutsiya) qaytarardi. Mahalliy korpus 17 moddadan iborat,
  /// serverdagi `law_article_chunks` production'da 0 qator. Demak korpusdan
  /// tashqaridagi HAR QANDAY savolga foydalanuvchi o'z holatiga aloqasi
  /// bo'lmagan Konstitutsiya moddalarini "Qonuniy asos" sifatida ko'rardi.
  ///
  /// Bu `_minRelevanceScore` himoyasi bilan bir xil defekt sinfi: o'sha yerda
  /// PAST ball tuzatilgan, bu yerda NOL ball holati qolib ketgan edi.
  group('LegalKnowledgeRetriever fail-closed (korpusdan tashqari so\'rov)', () {
    // Korpus qamrovi: Konstitutsiya, Mehnat, Oila, Fuqarolik, Iste'molchi
    // huquqlari, Ma'muriy javobgarlik. Quyidagi mavzular QAMRALMAGAN.
    const outOfCorpus = <String, String>{
      'bojxona/aksiz':
          "Bojxona deklaratsiyasida aksiz stavkasi qanday belgilanadi?",
      'litsenziya':
          "Farmatsevtika faoliyati uchun litsenziya olish tartibi qanday?",
      'valyuta': "Valyuta ayirboshlash operatsiyalari qanday cheklanadi?",
    };

    for (final entry in outOfCorpus.entries) {
      test('${entry.key} — BO\'SH qaytaradi, Konstitutsiya emas', () {
        final chunks = LegalKnowledgeRetriever.retrieveRelevantChunks(
          entry.value,
          maxResults: 3,
        );

        expect(
          chunks,
          isEmpty,
          reason: 'Korpusda mos modda yo\'q — fail-closed bo\'sh qaytarishi '
              'kerak. Qaytdi: '
              '${chunks.map((c) => "${c.documentName} ${c.articleNumber}").join(", ")}',
        );
      });
    }

    test('default Konstitutsiya moddalari HECH QACHON zaxira sifatida kelmaydi',
        () {
      // Defekt imzosi: aynan korpusning birinchi `maxResults` moddasi.
      final defaultSignature = UzbekLegalKnowledgeBase.verifiedLawChunks
          .take(3)
          .map((c) => c.articleNumber)
          .toList();

      final chunks = LegalKnowledgeRetriever.retrieveRelevantChunks(
        "Bojxona deklaratsiyasida aksiz stavkasi qanday belgilanadi?",
        maxResults: 3,
      );

      expect(
        chunks.map((c) => c.articleNumber).toList(),
        isNot(equals(defaultSignature)),
        reason: 'Korpusning birinchi 3 moddasi zaxira javob bo\'lib qaytdi — '
            'bu aynan tuzatilgan defekt',
      );
    });

    test('mavzuga mos so\'rov fail-closed tuzatishidan keyin ham ishlaydi', () {
      // Fail-closed haddan tashqari qattiq bo'lib ketmaganini qulflaydi.
      final chunks = LegalKnowledgeRetriever.retrieveRelevantChunks(
        "Ish beruvchi meni ishdan bo'shatdi, mehnat shartnomasi bekor qilindi.",
        maxResults: 3,
      );
      expect(chunks, isNotEmpty,
          reason: 'Korpus ICHIDAGI mavzu baribir topilishi shart');
    });
  });
}
