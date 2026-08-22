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
}
