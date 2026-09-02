import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/legal_safety/legal_coverage.dart';
import 'package:lexhub/core/legal_safety/uzbek_legal_knowledge_base.dart';
import 'package:lexhub/features/legal_assistant/data/datasources/legal_assistant_remote_datasource.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_query.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/risk_level.dart';

/// QAMROV MANIFESTI INVARIANTLARI.
///
/// Bu testlar "kod bor" degan da'voni emas, MANIFEST bilan BAZA orasidagi
/// mosligini qulflaydi. Sabab: `LegalCoverage` ilovaning nimani bilishini
/// E'LON QILADI, `UzbekLegalKnowledgeBase` esa nimani HAQIQATAN biladi.
/// Ikkisi ajralib ketsa ilova o'zi haqida yolg'on ma'lumot beradi:
///  * e'lon qilingan, lekin moddasi yo'q soha -> "javob beraman" deb bo'sh
///    natija qaytaradi;
///  * e'lon qilinmagan `jurisdiction` -> modda hech qachon topilmaydi (jim
///    yo'qolgan kontent).
void main() {
  group('LegalCoverage manifesti <-> knowledge base pariteti', () {
    test('1. Qamrov da\'vo qilingan HAR BIR sohada kamida bitta faol modda bor',
        () {
      final empty = <LegalDomain>[];
      for (final spec in LegalCoverage.domains) {
        if (LegalKnowledgeRetriever.retrieveByDomain(spec.domain).isEmpty) {
          empty.add(spec.domain);
        }
      }

      expect(
        empty,
        isEmpty,
        reason: 'Bu sohalar qamrovda e\'lon qilingan, lekin bazada moddasi '
            'yo\'q: $empty. Yoki modda qo\'shing, yoki sohani '
            'LegalCoverage.domains dan olib tashlang — aks holda ilova '
            'javob berishga urinib bo\'sh natija qaytaradi.',
      );
    });

    test('2. Bazadagi HAR BIR chunk aynan bitta sohaga tegishli (yetim yo\'q)',
        () {
      final orphans = <String>{};
      for (final chunk in UzbekLegalKnowledgeBase.verifiedLawChunks) {
        if (LegalCoverage.domainOfJurisdiction(chunk.jurisdiction) == null) {
          orphans.add('${chunk.chunkId} -> "${chunk.jurisdiction}"');
        }
      }

      expect(
        orphans,
        isEmpty,
        reason: 'Bu chunk\'larning jurisdiction qiymati hech qanday sohaga '
            'bog\'lanmagan, ya\'ni DARVOZA 1 ularni HAR DOIM rad etadi va '
            'modda foydalanuvchiga hech qachon ko\'rinmaydi: $orphans',
      );
    });

    test('3. Sohalar jurisdiction bo\'yicha kesishmaydi', () {
      final owner = <String, LegalDomain>{};
      for (final spec in LegalCoverage.domains) {
        for (final j in spec.jurisdictions) {
          expect(
            owner.containsKey(j),
            false,
            reason: '"$j" ikki sohaga tegishli: ${owner[j]} va ${spec.domain}. '
                'domainOfJurisdiction birinchi topilganini qaytaradi — bu '
                'yashirin, tartibga bog\'liq xatti-harakat.',
          );
          owner[j] = spec.domain;
        }
      }
      expect(owner.length, LegalCoverage.domains.length);
    });

    test('4. Triggerlar normalizatsiya qilingan shaklda saqlanadi', () {
      // Trigger apostrof yoki bosh harf bilan saqlansa, u HECH QACHON mos
      // kelmaydi (so'rov normalizatsiyadan o'tadi, trigger esa o'tmaydi) —
      // ya'ni jim ishlamaydigan qamrov.
      for (final spec in LegalCoverage.domains) {
        for (final t in spec.triggers) {
          expect(t, LegalCoverage.normalize(t),
              reason: '${spec.domain} triggeri normalizatsiyalanmagan: "$t"');
        }
        for (final j in spec.jurisdictions) {
          expect(j, LegalCoverage.normalize(j),
              reason: '${spec.domain} jurisdiction qiymati '
                  'normalizatsiyalanmagan: "$j"');
        }
      }
      for (final topic in LegalCoverage.uncoveredTopics) {
        for (final t in topic.triggers) {
          expect(t, LegalCoverage.normalize(t),
              reason: '${topic.id} triggeri normalizatsiyalanmagan: "$t"');
        }
      }
    });

    test('5. Apostrofning 4 varianti ham, apostrofsiz shakl ham bir xil ishlaydi',
        () {
      // O'zbek lotin yozuvida amalda 4 xil belgi uchraydi + foydalanuvchi
      // umuman yozmasligi mumkin. Beshtasi ham bir xil sohani ochishi shart,
      // aks holda "bo'shatish" ishlaydi-yu "boshatish" ishlamaydi.
      const variants = [
        "Ish beruvchi meni ishdan bo'shatdi",
        'Ish beruvchi meni ishdan bo’shatdi',
        'Ish beruvchi meni ishdan boʻshatdi',
        'Ish beruvchi meni ishdan bo`shatdi',
        'Ish beruvchi meni ishdan boshatdi',
      ];
      for (final q in variants) {
        expect(LegalCoverage.classify(q).domains, contains(LegalDomain.mehnat),
            reason: 'Variant qamrovni ochmadi: "$q"');
      }
    });
  });

  group('DARVOZA 0 — qamrovdan tashqari mavzular fail-closed', () {
    // Har biri REAL foydalanuvchi savoli shaklida. Hech biri bazada mavjud
    // emas, demak hech biri modda OLMASLIGI kerak.
    const outOfCoverage = <String, String>{
      'soliq': 'Yakka tartibdagi tadbirkor uchun soliq deklaratsiyasini qanday '
          'topshirish kerak?',
      'bojxona': 'Xorijdan olib kelingan avtomobil uchun bojxona to\'lovi '
          'qancha?',
      'litsenziya': 'Farmatsevtika faoliyati uchun litsenziya olish tartibi '
          'qanday belgilanadi?',
      'valyuta': 'Bankdan ipoteka krediti olish shartlari qanday?',
      'migratsiya': 'Chet elga ishlashga ketish uchun migratsiya hujjatlari '
          'qanday rasmiylashtiriladi?',
      'intellektual': 'Tovar belgisini ro\'yxatdan o\'tkazish uchun nima '
          'qilish kerak?',
      'qurilish': 'Yer maydonini kadastr organida qanday hisobga qo\'yiladi?',
      'ekologiya': 'Hovlimdagi daraxt kesish uchun ruxsat qanday olinadi?',
      'korporativ': 'MChJ ustav fondi eng kam miqdori qancha bo\'lishi kerak?',
      'bank_hisob': 'Bank hisobi raqamini qanday o\'zgartirsam bo\'ladi?',
      'sugurta': 'OSAGO sug\'urta polisi bo\'yicha to\'lov qancha vaqtda '
          'beriladi?',
      'tender': 'Davlat xaridi tenderida qanday ishtirok etiladi?',
    };

    test('6. Barchasi BO\'SH natija qaytaradi (aloqasiz modda ko\'rsatilmaydi)',
        () {
      final leaked = <String, List<String>>{};
      outOfCoverage.forEach((id, query) {
        final chunks = LegalKnowledgeRetriever.retrieveRelevantChunks(query);
        if (chunks.isNotEmpty) {
          leaked[id] = chunks
              .map((c) => '${c.documentName} ${c.articleNumber}-modda')
              .toList();
        }
      });

      expect(
        leaked,
        isEmpty,
        reason: 'Qamrovdan tashqaridagi savolga modda qaytarildi — ya\'ni '
            'foydalanuvchiga ALOQASIZ modda "qonuniy asos" bo\'lib '
            'ko\'rsatiladi: $leaked',
      );
    });

    test('7. Har biri vakolatli organga yo\'naltiriladi (boshi berk ko\'cha yo\'q)',
        () {
      final unrouted = <String>[];
      outOfCoverage.forEach((id, query) {
        final coverage = LegalCoverage.classify(query);
        if (coverage.uncoveredTopic == null) unrouted.add(id);
      });

      expect(
        unrouted,
        isEmpty,
        reason: 'Bu mavzular fail-closed bo\'ladi, lekin foydalanuvchiga '
            'kimga murojaat qilishini AYTMAYDI: $unrouted',
      );
    });
  });

  group('POZITIV NAZORAT — qamrov haddan ziyod qisilmadi', () {
    // Darvoza qo'shishning real xavfi — TESKARI regressiya: haqiqiy savolga
    // ham modda chiqmay qolishi. Har bir soha uchun kamida bitta savol.
    const covered = <String, LegalDomain>{
      'Ish beruvchi meni asossiz ishdan bo\'shatmoqchi': LegalDomain.mehnat,
      'Farzandim uchun aliment undirish tartibi qanday?': LegalDomain.oila,
      'Do\'kondan sotib olingan nuqsonli tovarni qaytarish':
          LegalDomain.istemolchi,
      'Radar jarima qarori keldi, shikoyat berish mumkinmi?':
          LegalDomain.mamuriy,
      'Qarz berdim, tilxat bor, lekin pulni qaytarmadi': LegalDomain.fuqarolik,
      'Meni militsiya ushlab turishibdi, advokat talab qildim':
          LegalDomain.konstitutsiya,
    };

    test('8. Har bir soha savoliga modda topiladi va u AYNAN o\'sha sohadan',
        () {
      covered.forEach((query, expected) {
        final chunks = LegalKnowledgeRetriever.retrieveRelevantChunks(query);
        expect(chunks, isNotEmpty, reason: 'Modda topilmadi: "$query"');

        final domains = chunks
            .map((c) => LegalCoverage.domainOfJurisdiction(c.jurisdiction))
            .toSet();
        expect(
          domains,
          contains(expected),
          reason: '"$query" uchun kutilgan soha $expected, topilgani: $domains',
        );
      });
    });

    test('9. Faol Mehnat kodeksi 161-moddasi ishdan bo\'shatish so\'rovida birinchi',
        () {
      final chunks = LegalKnowledgeRetriever.retrieveRelevantChunks(
        'Ish beruvchi meni asossiz ravishda ishdan bo\'shatmoqchi',
      );
      expect(chunks.first.articleNumber, 161);
      expect(chunks.first.documentName, contains('Mehnat kodeksi'));
    });
  });

  group('HARD STOP — jinoyat huquqi', () {
    test('10. Ayblanish lug\'ati advokat talabini majburiy qiladi', () {
      final coverage = LegalCoverage.classify(
        'Menga o\'g\'irlik uchun ayb qo\'yishmoqda, jinoyat ishi qo\'zg\'atilgan',
      );
      expect(coverage.hardStopTopic, isNotNull);
      expect(coverage.hardStopTopic!.isHardStop, true);
    });

    test('11. Hibsga olish HARD STOP emas — konstitutsiyaviy huquqlar beriladi',
        () {
      // MUHIM: `tergov`/`hibs` ataylab jinoyat triggerlariga KIRITILMAGAN.
      // Ushlab turilgan odamga kerak bo'lgan narsa — Konstitutsiyaning
      // 27/28/29-moddalari, "mavzu qamrovda emas" xabari emas.
      final coverage = LegalCoverage.classify(
        'Meni ichki ishlar bo\'limida ushlab turishibdi',
      );
      expect(coverage.domains, contains(LegalDomain.konstitutsiya));
      expect(coverage.uncoveredTopic, isNull);

      final chunks = LegalKnowledgeRetriever.retrieveRelevantChunks(
        'Meni ichki ishlar bo\'limida ushlab turishibdi, advokat talab qilaman',
      );
      expect(chunks, isNotEmpty);
      expect(chunks.every((c) => c.documentName.contains('Konstitutsiya')), true,
          reason: 'Favqulodda holatda faqat Konstitutsiya moddalari kutiladi, '
              'topilgani: ${chunks.map((c) => c.documentName).toList()}');
    });
  });

  group('NORMALIZATSIYA REGRESSIYALARI (ikkisi ham o\'lchangan xato)', () {
    test('12. "bo\'l-" yordamchi fe\'li OILA sohasini OCHMAYDI', () {
      // O'LCHANGAN XATO: normalizatsiya apostrofni O'CHIRIB tashlaganda
      // "bo'ladi" -> "boladi" bo'lib, `bola` (oila) triggeriga tushardi.
      // "bo'l-" — o'zbek tilidagi eng chastotali yordamchi fe'l, ya'ni bu
      // xato deyarli har uchinchi so'rovda takrorlanardi va foydalanuvchiga
      // Oila kodeksi moddalari "qonuniy asos" bo'lib ko'rsatilardi.
      //
      // Bu test normalize() ni apostrof O'CHIRADIGAN holatga qaytarishni
      // to'sadi — apostrof MA'NO FARQLOVCHI belgi.
      const neutral = [
        'Bank hisobi raqamini qanday o\'zgartirsam bo\'ladi?',
        'MChJ ustav fondi eng kam miqdori qancha bo\'lishi kerak?',
        'Bu holatda nima qilsam bo\'lar ekan?',
      ];
      for (final q in neutral) {
        expect(
          LegalCoverage.classify(q).domains,
          isNot(contains(LegalDomain.oila)),
          reason: '"bo\'l-" fe\'li oila sohasini ochib qo\'ydi: "$q"',
        );
      }

      // Teskari tomon: haqiqiy "bola" so'zi HAMON sohani ochishi shart —
      // aks holda tuzatish recall'ni buzgan bo'lardi.
      expect(
        LegalCoverage.classify('Bolamning aliment nafaqasi to\'lanmayapti')
            .domains,
        contains(LegalDomain.oila),
      );
    });

    test('13. Uzunroq TASHQI atama qisqa umumiy triggerni bekor qiladi', () {
      // O'LCHANGAN XATO (6-test bilan bir xil sinf): "tovar belgisi" (tovar
      // markasi = intellektual mulk) so'rovi `tovar` triggeri orqali
      // ISTE'MOLCHI sohasini ochardi va foydalanuvchiga Iste'molchilar
      // huquqi qonunining 13/18-moddalari ko'rsatilardi.
      final trademark = LegalCoverage.classify(
        'Tovar belgisini ro\'yxatdan o\'tkazish uchun nima qilish kerak?',
      );
      expect(trademark.domains, isEmpty,
          reason: 'Intellektual mulk savoli iste\'molchi sohasini ochdi: '
              '${trademark.domains}');
      expect(trademark.uncoveredTopic?.id, 'intellektual');

      // Xuddi shu sinf: "davlat xaridi" (13) `xarid` (5) dan uzunroq.
      final tender =
          LegalCoverage.classify('Davlat xaridi tenderida qanday ishtirok etiladi?');
      expect(tender.domains, isEmpty);
      expect(tender.uncoveredTopic?.id, 'davlat_xaridi');

      // TESKARI NAZORAT: tashqi atama YO'Q bo'lsa, qisqa trigger o'z ishini
      // bajarishi shart (spesifiklik qoidasi qamrovni qisib qo'ymasin).
      expect(
        LegalCoverage.classify('Do\'kondan olgan tovarim nuqsonli chiqdi')
            .domains,
        contains(LegalDomain.istemolchi),
      );
    });

    test('14. HARD STOP qamrovdagi sohani SIQIB CHIQARMAYDI', () {
      // Jinoyat lug'ati spesifiklik raqobatiga qatnashmasligi shart: aks
      // holda "jinoyat ishi bo'yicha ishdan bo'shatishdi" so'rovida
      // foydalanuvchi kerakli MEHNAT moddalarini YO'QOTARDI.
      final coverage = LegalCoverage.classify(
        'Menga jinoyat ishi qo\'zg\'atilgani uchun ish beruvchi ishdan bo\'shatdi',
      );
      expect(coverage.domains, contains(LegalDomain.mehnat));
      expect(coverage.hardStopTopic, isNotNull,
          reason: 'Advokat majburiy bo\'lgan mavzu jim o\'tkazib yuborildi');
      expect(coverage.uncoveredTopic, isNull);

      final chunks = LegalKnowledgeRetriever.retrieveRelevantChunks(
        'Menga jinoyat ishi qo\'zg\'atilgani uchun ish beruvchi ishdan bo\'shatdi',
      );
      expect(chunks, isNotEmpty,
          reason: 'Mehnat moddalari qaytmadi — hard stop qamrovni yopib qo\'ydi');
    });
  });

  group('QAMROVDAN TASHQARI JAVOBDA PROTSESSUAL DA\'VO BO\'LMAYDI', () {
    // REAL QURILMADA O'LCHANGAN DEFEKT (Pixel_9, 2026-08-27):
    // "Mos keladigan modda topilmadi" deb yozilgan ekranda AYNI PAYTDA
    // "Murojaat qilish uchun qolgan taxminiy muddat: 10 kun" va
    // "Javob berish muddati 15 kundan 1 oygacha." ko'rsatilgan edi.
    // Muddat `DeadlinesGuard`dan kelgan — u kalit so'zga qarab ishlaydi va
    // BOSHQA sohaning muddatini beradi. Bu "aloqasiz modda" defektining
    // aynan o'zi, faqat "Risk va Muddatlar" blokida.
    test('15. Modda topilmasa: muddat YO\'Q, daraja pasaytirilmaydi', () async {
      final dataSource = LegalAssistantRemoteDataSourceImpl();
      final response = await dataSource.getLegalAdvice(LegalQuery(
        id: 'coverage_deadline_regression',
        queryText:
            'Tovar belgisini ro\'yxatdan o\'tkazish uchun nima qilish kerak?',
        category: 'Umumiy huquq',
        createdAt: DateTime.now(),
      ));

      expect(response.legalBasis, isEmpty,
          reason: 'Qamrovdan tashqari savolga modda ko\'rsatildi');

      final risk = response.riskAssessment;
      expect(risk.deadlineDays, isNull,
          reason: 'Asossiz protsessual muddat ko\'rsatildi: '
              '${risk.deadlineDays} kun');
      expect(risk.requiresLawyer, true);
      expect(risk.level, isNot(RiskLevel.low),
          reason: '"Past xavf" yorlig\'i foydalanuvchini asossiz xotirjam '
              'qiladi — fail-closed prinsipiga teskari');

      // Evristik protsessual da'volar TASHLANGANIGA ishonch: baho matnida
      // "sudgacha hal etish ehtimoli yuqori" kabi asossiz prognoz qolmasin.
      expect(risk.summary, contains('BAHOLANMADI'));
      expect(
        risk.limitations.any((l) => l.contains('15 kundan')),
        false,
        reason: 'RiskMatrixEvaluator cheklovlari asossiz holda saqlanib qolgan',
      );
    });

    test('16. Modda TOPILGANDA muddat va baho SAQLANADI (teskari nazorat)',
        () async {
      final dataSource = LegalAssistantRemoteDataSourceImpl();
      final response = await dataSource.getLegalAdvice(LegalQuery(
        id: 'coverage_deadline_positive',
        queryText: 'Ish beruvchi meni asossiz ravishda ishdan bo\'shatdi',
        category: 'Mehnat huquqi',
        createdAt: DateTime.now(),
      ));

      expect(response.legalBasis, isNotEmpty);
      expect(response.riskAssessment.summary, isNot(contains('BAHOLANMADI')),
          reason: 'Asos bor, lekin baho o\'chirilgan — tuzatish haddan ziyod '
              'keng ishlagan');
    });
  });
}
