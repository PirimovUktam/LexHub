/// AI -> ADVOKAT ESKALATSIYASI — QULF.
///
/// NUQSON (auditda o'lchangan, kod o'qish bilan uch tomondan tasdiqlangan):
/// quvur `RiskAssessment.requiresLawyer = true` ni ishonchli berardi, lekin
/// UI'da bu FAQAT matn edi:
///   (a) `requiresLawyer` yagona iste'molchisi — `risk_matrix_gauge.dart:296`;
///   (b) o'sha blok ichida hech qanday `onPressed` YO'Q;
///   (c) `LegalExpertsPage` ga kirish faqat `quick_access_grid.dart` va
///       `search_page.dart` dan.
/// Ya'ni "sizga advokat kerak" xulosasi BOSHI BERK KO'CHA edi — mahsulotning
/// eng qimmat bo'g'ini (`... -> HUJJAT -> ADVOKAT -> NATIJA`) uzilgan edi.
///
/// Bu fayl uchta narsani qulflaydi:
///   1. XARITALASH — o'lchangan qiymatlar (quyidagi guruhlardagi har bir
///      kutilma AYNAN `flutter test` da chiqqan natija, taxmin EMAS).
///   2. HALOLLIK — mos ixtisoslik bo'lmasa `null` qaytadi, ya'ni
///      foydalanuvchi NOTO'G'RI advokatga yuborilmaydi.
///   3. ULANISH — sahifa/karta manbasida eskalatsiya yo'li mavjud va
///      hujjat tanlashda "birinchi shablon" fallback'i QAYTMAYDI.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/legal_safety/lawyer_specialization_matcher.dart';
import 'package:lexhub/core/legal_safety/legal_coverage.dart';

void main() {
  /// Real mahsulot so'rovlari (`legal_assistant_page.dart` `_quickPromptChips`
  /// dan olingan) + qamrovdan tashqari uchta mavzu.
  const labor =
      "Ish beruvchi meni asossiz ravishda o'z xohishim bilan ariza yozishga "
      "majburlamoqda va ishdan bo'shatmoqchi. Qanday huquqlarim bor?";
  const consumer = "Do'kondan kiyim sotib olgandim, lekin o'lchami to'g'ri "
      "kelmadi. 10 kun ichida qaytarib pulimni olsam bo'ladimi?";
  const family = "Farzandlarim uchun aliment undirmoqchiman. Ota rasman "
      "ishlamaydi, aliment qanday hisoblanadi va sudga qanday ariza beriladi?";
  const traffic = "Radar orqali noo'rin jarima qarori keldi. Ushbu ma'muriy "
      "qaror ustidan 10 kun ichida qanday shikoyat qilsam bo'ladi?";
  const debt = "Tanishimga qarz bergan edim, tilxat yozib bergan. Pulni "
      "qaytarmayapti, sud orqali undirish tartibi qanday?";
  const criminal = "Meni jinoyat ishi bo'yicha guvoh sifatida so'roqqa "
      "chaqirdilar, tergovchi ayblanuvchi deb aytdi.";
  const tax = "Soliq inspeksiyasi kameral tekshiruv o'tkazib qo'shimcha soliq "
      "hisoblab chiqardi.";
  const migration = "Vatandoshlik va doimiy yashash uchun viza olish tartibi "
      "qanday?";
  const trademark = "Tovar belgisini ro'yxatdan o'tkazish tartibi qanday?";

  group('qamrovdagi soha -> ixtisoslik (O\'LCHANGAN)', () {
    test('mehnat so\'rovi -> Mehnat', () {
      final m = LawyerSpecializationMatcher.forQuery(labor);
      expect(LegalCoverage.classify(labor).domains,
          contains(LegalDomain.mehnat));
      expect(m.specialization, 'Mehnat');
      expect(m.isMandatory, isFalse);
    });

    test('iste\'molchi so\'rovi -> Iste\'molchi', () {
      expect(LawyerSpecializationMatcher.forQuery(consumer).specialization,
          "Iste'molchi");
    });

    test('oila (aliment) so\'rovi -> Oila', () {
      expect(
          LawyerSpecializationMatcher.forQuery(family).specialization, 'Oila');
    });

    test('ma\'muriy (jarima) so\'rovi -> Yo\'l harakati', () {
      expect(LawyerSpecializationMatcher.forQuery(traffic).specialization,
          "Yo'l harakati");
    });
  });

  group('HALOL null — taxmin qilinmaydi', () {
    test('fuqarolik (qarz/tilxat): ro\'yxatda mos ixtisoslik YO\'Q', () {
      final coverage = LegalCoverage.classify(debt);
      // Soha QAMROVDA — ya'ni null "topilmadi" degani emas, "bu sohaga mos
      // ixtisoslik chip'i yo'q" degani.
      expect(coverage.domains, contains(LegalDomain.fuqarolik));
      final m = LawyerSpecializationMatcher.forQuery(debt);
      expect(m.specialization, isNull);
      expect(m.hasSpecialization, isFalse);
      expect(m.isMandatory, isFalse);
    });

    test('migratsiya: xaritada YO\'Q -> filtrsiz ro\'yxat', () {
      expect(LegalCoverage.classify(migration).uncoveredTopic?.id,
          'migratsiya');
      expect(LawyerSpecializationMatcher.forQuery(migration).specialization,
          isNull);
    });

    test('intellektual mulk: xaritada YO\'Q -> filtrsiz ro\'yxat', () {
      expect(LegalCoverage.classify(trademark).uncoveredTopic?.id,
          'intellektual');
      expect(LawyerSpecializationMatcher.forQuery(trademark).specialization,
          isNull);
    });
  });

  group('HARD STOP — advokat MAJBURIY', () {
    test('jinoyat lug\'ati -> Jinoyat + isMandatory', () {
      final coverage = LegalCoverage.classify(criminal);
      expect(coverage.hardStopTopic?.id, 'jinoyat');
      expect(coverage.hardStopTopic?.isHardStop, isTrue);
      final m = LawyerSpecializationMatcher.forQuery(criminal);
      expect(m.specialization, 'Jinoyat');
      expect(m.isMandatory, isTrue,
          reason: 'hard stop mavzusida "tavsiya" emas, TALAB ko\'rsatiladi');
    });

    test('umumiy konstitutsiya sohasi O\'ZI jinoyatni OCHMAYDI', () {
      // Jinoyat lug'ati BO'LMAGAN konstitutsion savol jinoyat advokatiga
      // yuborilmaydi — aks holda har bir konstitutsion savol "jinoyat" deb
      // belgilanib, ro'yxat noto'g'ri filtrlanardi.
      final m = LawyerSpecializationMatcher.forCoverage(
        const CoverageResult(domains: {LegalDomain.konstitutsiya}),
      );
      expect(m.specialization, isNull);
      expect(m.isMandatory, isFalse);
    });
  });

  group('qamrovdan tashqari mavzu -> ixtisoslik', () {
    test('soliq -> Soliq', () {
      expect(LegalCoverage.classify(tax).uncoveredTopic?.id, 'soliq');
      expect(LawyerSpecializationMatcher.forQuery(tax).specialization, 'Soliq');
    });

    test('bojxona ham `Soliq` ixtisosligiga tushadi', () {
      // Ariza qiymati `Soliq va Bojxona huquqi` — `%Soliq%` ikkisini ham
      // qamrab oladi, ya'ni alohida chip kerak emas.
      final topic = LegalCoverage.uncoveredTopics
          .firstWhere((t) => t.id == 'bojxona');
      expect(
        LawyerSpecializationMatcher.forCoverage(
          CoverageResult(domains: const {}, uncoveredTopic: topic),
        ).specialization,
        'Soliq',
      );
    });
  });

  test('bir nechta soha ochilsa natija DETERMINISTIK', () {
    // `fuqarolik` ixtisosligi yo'q, `mehnat` bor — tartib bo'yicha `Mehnat`.
    final m = LawyerSpecializationMatcher.forCoverage(
      const CoverageResult(
        domains: {LegalDomain.fuqarolik, LegalDomain.mehnat},
      ),
    );
    expect(m.specialization, 'Mehnat');
    // Ikki marta chaqirilganda ham AYNI qiymat.
    expect(LawyerSpecializationMatcher.forQuery(labor).specialization,
        LawyerSpecializationMatcher.forQuery(labor).specialization);
  });

  test('qaytarilgan qiymat `LegalExpertsPage` filtr ro\'yxatida BOR', () {
    // Qiymat `.ilike('specialization', '%raw%')` ga ketadi, ya'ni bu BACKEND
    // kontrakti. Ro'yxatdan tushib qolgan qiymat "advokat topilmadi" beradi.
    final src = File(
      'lib/features/legal_experts/presentation/pages/legal_experts_page.dart',
    ).readAsStringSync();
    final listStart = src.indexOf('_specializations = [');
    expect(listStart, greaterThan(0), reason: 'filtr ro\'yxati nomi o\'zgargan');
    final listBlock = src.substring(listStart, src.indexOf(']', listStart));
    for (final raw in <String>[
      LawyerSpecializationMatcher.specLabor,
      LawyerSpecializationMatcher.specFamily,
      LawyerSpecializationMatcher.specCriminal,
      LawyerSpecializationMatcher.specTraffic,
      LawyerSpecializationMatcher.specConsumer,
      LawyerSpecializationMatcher.specTax,
      LawyerSpecializationMatcher.specBusiness,
    ]) {
      expect(listBlock.contains('"$raw"'), isTrue,
          reason: '$raw — `_specializations` ro\'yxatida yo\'q');
    }
  });

  group('ULANISH — manba qulfi', () {
    test('`LegalExpertsPage` oldindan tanlangan ixtisoslikni UZATADI', () {
      final src = File(
        'lib/features/legal_experts/presentation/pages/legal_experts_page.dart',
      ).readAsStringSync();
      expect(src.contains('this.initialSpecialization'), isTrue);
      expect(
          src.contains(
              'LoadLegalExpertsEvent(specialization: initialSpecialization)'),
          isTrue,
          reason: 'filtr yuklash hodisasiga ulanmagan — chip yonmaydi va '
              'ro\'yxat filtrlanmaydi');
    });

    test('eskalatsiya kartasi advokatlar sahifasini OCHADI', () {
      final src = File(
        'lib/features/legal_assistant/presentation/widgets/'
        'lawyer_escalation_card.dart',
      ).readAsStringSync();
      expect(src.contains('Navigator.of(context).push'), isTrue,
          reason: 'karta yana harakatsiz matn bo\'lib qolgan');
      expect(src.contains('initialSpecialization: match.specialization'),
          isTrue);
    });

    test('AI javobi `requiresLawyer` da kartani KO\'RSATADI', () {
      final src = File(
        'lib/features/legal_assistant/presentation/pages/'
        'legal_assistant_page.dart',
      ).readAsStringSync();
      expect(
          src.contains(
              'if (state.response.riskAssessment.requiresLawyer) ...['),
          isTrue,
          reason: 'eskalatsiya sharti olib tashlangan');
      expect(src.contains('LawyerEscalationCard(queryText:'), isTrue);
    });
  });

  group('ESKALATSIYA MANZILI — bo\'sh ekran boshi berk ko\'cha EMAS', () {
    /// Qurilmada o'lchangan ikkita nuqson uchun qulf. Izohlar olib tashlanadi:
    /// tuzatishning o'z izohlari aynan shu nomlarni tilga oladi.
    String code() {
      final raw = File(
        'lib/features/legal_experts/presentation/pages/legal_experts_page.dart',
      ).readAsStringSync();
      return raw
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');
    }

    test('tanlangan chip HAR QANDAY o\'zgarishda ko\'rinishga keltiriladi', () {
      // NUQSON: `if (target == null || ...) return;` — filtr tozalanganda
      // "Barchasi" 0-indeksda qolib, ro'yxat 6-indeksda turardi, ya'ni
      // ekranda YANA hech narsa tanlanmagandek ko'rinardi.
      final src = code();
      expect(src.contains('if (_hasRevealed && target == _revealed) return;'),
          isTrue,
          reason: '`null` (Barchasi) uchun skroll yana o\'chirilgan');
      expect(src.contains('if (target == null'), isFalse,
          reason: '`null` holati yana erta qaytarilmoqda');
      expect(src.contains('Scrollable.ensureVisible'), isTrue);
    });

    test('filtr YO\'Q holatda "parametrlar bo\'yicha topilmadi" YOZILMAYDI',
        () {
      // O'lchov (anon REST, `content-range: */0`): ro'yxatning O'ZI bo'sh.
      // Filtr yoqilmagan holda "tanlangan parametrlar" matni YOLG'ON bo'ladi.
      final src = code();
      expect(src.contains('l10n.expertsDirectoryEmpty'), isTrue,
          reason: 'bo\'sh ro\'yxat uchun halol matn olib tashlangan');
      expect(
          src.contains('state.selectedCity == null &&') &&
              src.contains('state.searchQuery.isEmpty'),
          isTrue,
          reason: 'uchinchi holat sharti (filtr umuman yo\'q) buzilgan');
    });
  });

  test('hujjat tanlashda "birinchi shablon" fallback\'i QAYTMAYDI', () {
    // NUQSON: `orElse: () => templates.first` kalit so'z topilmaganda
    // MAJBURAN `template_consumer_refund` ni ochib, uni javob matni bilan
    // to'ldirardi — soliq/migratsiya savoliga "iste'molchi pulini qaytarish
    // talabi" loyihasi berilardi.
    //
    // DIQQAT: qulf IZOHLARNI hisobga OLMAYDI. Tuzatishning o'z izohi aynan
    // shu qatorni "nima uchun ishlatilmaydi" deb tilga oladi, ya'ni oddiy
    // `contains` doim `true` beradi (`_lighten` qulfidagi bilan bir xil
    // tuzoq). Shuning uchun avval izoh qatorlari olib tashlanadi.
    final raw = File(
      'lib/features/legal_assistant/presentation/pages/'
      'legal_assistant_page.dart',
    ).readAsStringSync();
    final code = raw
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');

    expect(code.contains('orElse: () => templates.first'), isFalse,
        reason: 'noto\'g\'ri hujjat fallback\'i qaytgan');
    expect(code.contains('templates.first'), isFalse,
        reason: 'bo\'sh ro\'yxatda `StateError` beradigan qator qaytgan');
    expect(code.contains('const DocumentTemplatesPage()'), isTrue,
        reason: 'moslik topilmaganda tanlov foydalanuvchiga berilmaydi');
    expect(code.contains('l10n.aiDocumentLoadFailed'), isTrue,
        reason: 'shablon yuklash xatosi yana JIM yutilgan');
  });
}
