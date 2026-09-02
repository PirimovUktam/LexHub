/// AI XULOSASI -> TASDIQLANGAN ADVOKAT: yo'nalish moslashtiruvchisi.
///
/// NIMA UCHUN BU FAYL BOR. Auditda o'lchangan UZILISH: quvur (pipeline)
/// `RiskAssessment.requiresLawyer = true` ni ISHONCHLI beradi
/// (`_applyCoverageHonesty` qamrovdan tashqari HAR BIR savol uchun uni
/// majburan `true` qiladi), UI esa buni `risk_matrix_gauge.dart:296` da
/// FAQAT qizil `Container` + matn bo'lib ko'rsatardi — ichida hech qanday
/// `onPressed` YO'Q edi. `LegalExpertsPage` ga esa faqat `quick_access_grid`
/// va `search_page` dan kirish bor. Ya'ni tizim "sizga advokat kerak" degan
/// joyda foydalanuvchi BOSHI BERK KO'CHAGA kelardi.
///
/// Bu klass shu bo'g'inni yopadi va FAQAT sof xaritalash qiladi:
/// `LegalCoverage.classify()` natijasi -> `LegalExpertsPage` dagi XOM filtr
/// qiymati.
///
/// ── QAT'IY CHEGARALAR ──
///
/// 1. QAYTARILADIGAN QIYMAT BACKEND KONTRAKTI. U `LegalExpertsPage`
///    `_specializations` ro'yxatidagi xom qiymat bo'lishi SHART, chunki
///    `getExperts()` uni `.ilike('specialization', '%$raw%')` ga uzatadi
///    (`legal_experts_remote_datasource.dart:78`). Bazada esa ariza
///    ro'yxatidagi TO'LIQ qiymat saqlanadi (`Mehnat huquqi`,
///    `Soliq va Bojxona huquqi` ...), shuning uchun xom qiymat shu to'liq
///    qiymatning QISM SATRI bo'lishi kerak. Tarjima QILINMAYDI — ekranda
///    ko'rsatish uchun `expertSpecializationChipLabel()` ishlatiladi.
///
/// 2. TAXMIN QILINMAYDI. Mos ixtisoslik ANIQ bo'lmasa `null` qaytadi va UI
///    filtrsiz ro'yxat ochadi. "Fuqarolik" (meros, qarz, shartnoma) va
///    umumiy "konstitutsiya" savollari uchun ro'yxatda mos ixtisoslik YO'Q —
///    ularni zo'rlab `Jinoyat` yoki `Biznes` ga yopishtirish foydalanuvchini
///    NOTO'G'RI advokatga yuboradi. `null` — halol javob.
///
/// 3. `konstitutsiya` sohasining O'ZI jinoyat ixtisosligini OCHMAYDI. Bu
///    soha triggerlari ichida hibs/tintuv/so'roq lug'ati ham bor
///    (`legal_coverage.dart:147`), lekin sohaning o'zi umumiy — konstitutsion
///    savol bergan har bir foydalanuvchini jinoyat advokatiga yuborish
///    asossiz. Jinoyat ixtisosligi FAQAT `hardStopTopic`/`uncoveredTopic`
///    `jinoyat` bo'lganda beriladi, ya'ni jinoyat lug'ati HAQIQATAN
///    aniqlanganda.
library;

import 'package:lexhub/core/legal_safety/legal_coverage.dart';

/// Advokat yo'naltirish qarori.
class LawyerMatch {
  /// `LegalExpertsPage` uchun XOM filtr qiymati. `null` — ishonchli
  /// moslik topilmadi, ro'yxat FILTRSIZ ochiladi.
  final String? specialization;

  /// `true` — mavzu `isHardStop` (litsenziyaga ega advokat MAJBURIY),
  /// ya'ni bu tavsiya emas, talab.
  final bool isMandatory;

  const LawyerMatch({this.specialization, this.isMandatory = false});

  static const LawyerMatch none = LawyerMatch();

  bool get hasSpecialization =>
      specialization != null && specialization!.isNotEmpty;
}

class LawyerSpecializationMatcher {
  LawyerSpecializationMatcher._();

  /// `LegalExpertsPage._specializations` dagi xom qiymatlar. Bu yerda
  /// nusxa saqlanmaydi — `lawyer_specialization_matcher_test.dart` ikkisining
  /// mosligini qulflaydi, ya'ni ro'yxat o'zgarsa test yiqiladi.
  static const String specLabor = 'Mehnat';
  static const String specFamily = 'Oila';
  static const String specCriminal = 'Jinoyat';
  static const String specTraffic = "Yo'l harakati";
  static const String specConsumer = "Iste'molchi";
  static const String specTax = 'Soliq';
  static const String specBusiness = 'Biznes';

  /// Qamrovdan TASHQARIDAGI mavzu -> ixtisoslik.
  ///
  /// Ro'yxatda YO'Q mavzular (`migratsiya`, `bank`, `intellektual`,
  /// `yer_qurilish`, `sugurta`, `ekologiya`) ATAYLAB yo'q: bu sohalar uchun
  /// `LegalExpertsPage` da ixtisoslik chip'i mavjud emas, taxminiy moslik
  /// esa foydalanuvchini noto'g'ri advokatga yuboradi.
  static const Map<String, String> _byUncoveredTopic = {
    'jinoyat': specCriminal,
    'soliq': specTax,
    // Ariza qiymati `Soliq va Bojxona huquqi` — `%Soliq%` bojxonani ham
    // qamrab oladi (bir ixtisoslik, ikki mavzu).
    'bojxona': specTax,
    'korporativ': specBusiness,
    // Litsenziyalash va davlat xaridlari — tadbirkorlik faoliyati masalasi,
    // `Biznes va Korporativ huquq` ixtisosligi ostida.
    'litsenziya': specBusiness,
    'davlat_xaridi': specBusiness,
  };

  /// Qamrovdagi soha -> ixtisoslik. `fuqarolik` va `konstitutsiya` ATAYLAB
  /// yo'q (fayl boshidagi 2- va 3-chegaraga qara).
  static const Map<LegalDomain, String> _byDomain = {
    LegalDomain.mehnat: specLabor,
    LegalDomain.oila: specFamily,
    LegalDomain.istemolchi: specConsumer,
    LegalDomain.mamuriy: specTraffic,
  };

  /// Bir nechta soha ochilganda TARTIB: maxsus soha umumiy sohadan ustun.
  /// `dominantDomain()` bilan bir xil mantiq — natija DETERMINISTIK.
  static const List<LegalDomain> _priority = [
    LegalDomain.mehnat,
    LegalDomain.oila,
    LegalDomain.istemolchi,
    LegalDomain.mamuriy,
    LegalDomain.fuqarolik,
    LegalDomain.konstitutsiya,
  ];

  /// So'rov matnidan yo'nalishni aniqlaydi.
  ///
  /// ATAYLAB `LegalResponse` dan EMAS, so'rov matnidan: qamrov qarori
  /// quvurda ham aynan shu funksiya (`LegalCoverage.classify`) bilan
  /// chiqariladi, ya'ni ikkinchi evristika PAYDO BO'LMAYDI va Domain
  /// entity'siga yangi maydon qo'shish kerak emas.
  static LawyerMatch forQuery(String queryText) =>
      forCoverage(LegalCoverage.classify(queryText));

  static LawyerMatch forCoverage(CoverageResult coverage) {
    // 1. HARD STOP eng ustun: yurist majburiy bo'lgan mavzu soha topilgan
    //    bo'lsa ham beriladi (`classify` `hardStopTopic` ni saqlab qoladi).
    final hardStop = coverage.hardStopTopic;
    if (hardStop != null) {
      return LawyerMatch(
        specialization: _byUncoveredTopic[hardStop.id],
        isMandatory: true,
      );
    }

    // 2. Qamrovdan tashqari ma'lum mavzu.
    final uncovered = coverage.uncoveredTopic;
    if (uncovered != null) {
      return LawyerMatch(
        specialization: _byUncoveredTopic[uncovered.id],
        isMandatory: uncovered.isHardStop,
      );
    }

    // 3. Qamrovdagi soha.
    for (final domain in _priority) {
      if (!coverage.domains.contains(domain)) continue;
      final spec = _byDomain[domain];
      if (spec != null) return LawyerMatch(specialization: spec);
      // Ro'yxatda mos ixtisosligi YO'Q soha (fuqarolik/konstitutsiya):
      // qolgan sohalarni tekshirishda davom etamiz, chunki so'rov bir
      // vaqtda ikki sohani ochishi mumkin ("qarz" + "mehnat").
    }
    return LawyerMatch.none;
  }
}
