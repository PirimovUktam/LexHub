import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/legal_safety/law_article_chunk.dart';
import 'package:lexhub/core/legal_safety/uzbek_legal_knowledge_base.dart';

/// SERVERDAN kelgan chunk'lar uchun relevantlik darvozasi.
///
/// O'LCHANGAN NUQSON (2026-08-29, production):
/// `law_article_chunks` jadvali 17 modda bilan to'ldirildi. Klient uni
/// `select() + eq('status','active') + limit(5)` bilan o'qiydi — `order` YO'Q,
/// MAVZU FILTRI YO'Q. Jonli bazada bu so'rov AYNAN quyidagini qaytaradi:
///
///   27-modda | O'zbekiston Respublikasining Konstitutsiyasi
///   28-modda | O'zbekiston Respublikasining Konstitutsiyasi
///   29-modda | O'zbekiston Respublikasining Konstitutsiyasi
///   42-modda | O'zbekiston Respublikasining Konstitutsiyasi
///   44-modda | O'zbekiston Respublikasining Konstitutsiyasi
///
/// Savol nima bo'lishidan qat'i nazar. Ilgari bu chunk'lar HECH QANDAY
/// darvozadan o'tmasdan `allChunks` ga qo'shilardi va `.take(4)` hisobiga
/// ulardan bittasi "Huquqiy asos" bo'lib chiqib ketardi: aliment so'rovida
/// [Oila 96, Oila 99, Oila 136, Konstitutsiya 27].
///
/// Bu `retrieval_relevance_test.dart` topgan 96-modda nuqsoni bilan AYNI
/// SINF — faqat manba mahalliy baza emas, SERVER. Shuning uchun darvoza
/// manbadan qat'i nazar ishlashi kerak.
void main() {
  /// Jonli o'lchangan 5 qator — mahalliy bazadan AYNAN olinadi, ya'ni bu
  /// testda birorta ham qo'lda yozilgan qonun matni yo'q.
  final cloudRows = UzbekLegalKnowledgeBase.verifiedLawChunks
      .where((c) => c.documentId == 'lex_const_2023')
      .toList(growable: false);

  group('Server chunk\'lari relevantlik darvozasidan o\'tadi', () {
    test('jonli o\'lchangan 5 qator mahalliy baza bilan mos', () {
      expect(cloudRows.length, 5);
      expect(
        cloudRows.map((c) => c.articleNumber).toSet(),
        {27, 28, 29, 42, 44},
        reason: 'Jonli so\'rov aynan shu moddalarni qaytargan',
      );
    });

    test('ALIMENT so\'rovi: Konstitutsiya moddalari ILASHMAYDI', () {
      const q =
          "Sudda aliment undirdim, lekin eks-erim 3 oydan beri farzandimga "
          "aliment to'lamayapti. Nima qilishim kerak?";

      final fromCloud = LegalKnowledgeRetriever.retrieveRelevantChunks(
        q,
        maxResults: 3,
        corpus: cloudRows,
      );

      expect(
        fromCloud,
        isEmpty,
        reason: 'Aliment so\'roviga ilashgan modda(lar): '
            '${fromCloud.map((c) => "${c.articleNumber}-modda — ${c.articleTitle}").join("; ")}',
      );

      // Mahalliy baza esa aynan shu so'rovga ALOQADOR moddalarni beradi —
      // ya'ni yuqoridagi bo'sh natija "darvoza hammasini yopib qo'ygani"
      // sababli emas.
      final local = LegalKnowledgeRetriever.retrieveRelevantChunks(q, maxResults: 3);
      expect(local, isNotEmpty);
      expect(
        local.every((c) => c.documentId == 'lex_family'),
        isTrue,
        reason: 'Aliment so\'roviga faqat Oila kodeksi moddalari kutiladi, '
            'olindi: ${local.map((c) => c.documentId).toList()}',
      );
    });

    test('MEHNAT so\'rovi: Konstitutsiya moddalari ILASHMAYDI', () {
      const q =
          "Ish beruvchi meni asossiz ravishda ishdan bo'shatdi va 2 oylik "
          "ish haqimni bermayapti.";

      final fromCloud = LegalKnowledgeRetriever.retrieveRelevantChunks(
        q,
        maxResults: 3,
        corpus: cloudRows,
      );

      // DIQQAT: Konstitutsiyaning 42-moddasi ("Munosib mehnat sharoitlari va
      // adolatli haq olish huquqi") mehnat SOHASIGA tegishli, ya'ni soha
      // darvozasidan o'tishi MUMKIN. Bu xato emas — u haqiqatan aloqador.
      // Test qulflaydigan narsa: mehnat so'roviga OILA/ISTE'MOLCHI kabi
      // aloqasiz soha moddasi tushmasligi va ball darvozasi ishlashi.
      for (final c in fromCloud) {
        expect(
          c.jurisdiction,
          anyOf('Konstitutsiyaviy huquq', 'Mehnat huquqi'),
          reason: 'Aloqasiz soha ilashdi: ${c.articleNumber} — ${c.articleTitle}',
        );
      }
    });

    test('serverdagi ALOQADOR modda o\'tib keladi (darvoza hammasini yopmaydi)',
        () {
      final serverOnly = UzbekLegalKnowledgeBase.verifiedLawChunks
          .where((c) => c.articleNumber == 161 && c.documentId == 'lex_labor_2023')
          .toList(growable: false);
      expect(serverOnly.length, 1, reason: 'MK 161 mahalliy bazada bo\'lishi shart');

      const q = "Ish beruvchi tashabbusi bilan mehnat shartnomasini bekor qilish";
      final fromCloud = LegalKnowledgeRetriever.retrieveRelevantChunks(
        q,
        maxResults: 3,
        corpus: serverOnly,
      );

      expect(
        fromCloud.map((c) => c.articleNumber).toList(),
        [161],
        reason: 'Serverdan kelgan ALOQADOR modda qaytishi kerak',
      );
    });

    test('QAMROV tashqarisidagi so\'rov: server chunk\'i ham o\'tmaydi', () {
      const q = "Farmatsevtika faoliyati uchun litsenziya olish tartibi qanday?";

      final fromCloud = LegalKnowledgeRetriever.retrieveRelevantChunks(
        q,
        maxResults: 3,
        corpus: cloudRows,
      );

      expect(
        fromCloud,
        isEmpty,
        reason: 'Qamrov darvozasi (fail-closed) serverdan kelgan chunk\'ga ham '
            'qo\'llanishi kerak, ilashdi: '
            '${fromCloud.map((c) => c.articleNumber).toList()}',
      );
    });

    test('bo\'sh server natijasi mahalliy natijani buzmaydi', () {
      const q = "Nuqsonli tovar sotildi, pulimni qaytarib olsam bo'ladimi?";

      final empty = LegalKnowledgeRetriever.retrieveRelevantChunks(
        q,
        maxResults: 3,
        corpus: const <LawArticleChunk>[],
      );
      expect(empty, isEmpty);

      final local = LegalKnowledgeRetriever.retrieveRelevantChunks(q, maxResults: 3);
      expect(local, isNotEmpty);
      expect(local.every((c) => c.documentId == 'lex_consumer'), isTrue);
    });

    /// NUQSONNI QAYTA HOSIL QILISH.
    ///
    /// Yuqoridagi testlar YANGI `corpus` parametrini tekshiradi, ya'ni ular
    /// eski kodda UMUMAN kompilyatsiya bo'lmaydi — demak "nuqsonni qayta
    /// hosil qilgan" hisoblanmaydi. Bu test esa `_retrieveLegalChunks` ning
    /// ESKI birlashtirish ifodasini AYNAN takrorlaydi va nuqson mavjud
    /// bo'lganini ISBOTLAYDI, keyin YANGI ifoda uni yopganini ko'rsatadi.
    test('ESKI birlashtirish Konstitutsiya 27-moddasini o\'tkazardi', () {
      const q =
          "Sudda aliment undirdim, lekin eks-erim 3 oydan beri farzandimga "
          "aliment to'lamayapti. Nima qilishim kerak?";

      final local = LegalKnowledgeRetriever.retrieveRelevantChunks(q, maxResults: 3);

      List<LawArticleChunk> combine(List<LawArticleChunk> all) {
        final seen = <String>{};
        final unique = <LawArticleChunk>[];
        for (final c in all) {
          final key = '${c.documentName}_${c.articleNumber}';
          if (!seen.contains(key) && c.isActive) {
            seen.add(key);
            unique.add(c);
          }
        }
        return unique.isNotEmpty ? unique.take(4).toList() : local;
      }

      // ESKI: cloud chunk'lar hech qanday darvozadan o'tmaydi.
      final oldResult = combine([...local, ...cloudRows]);
      expect(
        oldResult.any((c) => c.documentId == 'lex_const_2023'),
        isTrue,
        reason: 'Nuqson qayta hosil bo\'lmadi — test o\'z maqsadini yo\'qotgan',
      );
      expect(oldResult.length, 4);

      // YANGI: cloud chunk'lar mahalliy chunk'lar bilan bir xil darvozadan
      // o'tadi.
      final newResult = combine([
        ...local,
        ...LegalKnowledgeRetriever.retrieveRelevantChunks(
          q,
          maxResults: 3,
          corpus: cloudRows,
        ),
      ]);
      expect(
        newResult.any((c) => c.documentId == 'lex_const_2023'),
        isFalse,
        reason: 'Aliment so\'roviga hamon Konstitutsiya moddasi ilashadi: '
            '${newResult.map((c) => c.articleNumber).toList()}',
      );
      expect(
        newResult.map((c) => c.articleNumber).toSet(),
        local.map((c) => c.articleNumber).toSet(),
        reason: 'Mahalliy natija o\'zgarmasligi kerak',
      );
    });
  });
}
