/// FAVQULODDA HOLAT KLASSIFIKATORI — sof (pure), testlanadigan qatlam.
///
/// NIMA UCHUN AJRATILDI: klassifikator `legal_assistant_remote_datasource.dart`
/// ichida, tarmoq chaqiruvlari bilan bir joyda yashagan. Ya'ni uni test qilish
/// uchun datasource'ni qurish kerak edi va mantiq o'zi hech qachon alohida
/// o'lchanmagan. Bu qatlam Flutter'ga ham, tarmoqqa ham bog'lanmaydi.
///
/// O'LCHANGAN NUQSON (2026-08-29): `tekshiruv` YOLG'IZ O'ZI jinoyat-protsessual
/// tintuv belgisi deb qabul qilingan. Natijada:
///   "Soliq inspeksiyasi kameral tekshiruv o'tkazib qo'shimcha soliq hisoblab
///    chiqardi"
/// so'rovi Miranda qoidasi + 1002 ishonch telefoni bilan "FAVQULODDA HUQUQIY
/// XAVF" bannerini ochardi. Soliq tekshiruvi, tibbiy ko'rik, texnik ko'rik,
/// audit — hech biri hibs emas. Bu ikki tomonlama zarar: (a) foydalanuvchini
/// asossiz qo'rqitadi; (b) banner qadrsizlanadi, ya'ni HAQIQIY hibs holatida
/// unga ishonmay qo'yadi.
///
/// IKKINCHI NUQSON: `organ` substring'i `isInterrogation` ni ochardi. Bu
/// O'ZBEK HUQUQIY TILIDA eng neytral so'zlardan biri — "vakolatli organ",
/// "soliq organiga", "davlat organlari". Hatto bizning qamrov darvozasi
/// javobimiz ("Muddat va tartibni vakolatli organdan aniqlang") ham unga
/// tushardi.
///
/// DIZAYN QOIDASI — ASIMMETRIK EHTIYOTKORLIK:
/// false negative (haqiqiy hibsni o'tkazib yuborish) false positive'dan
/// QIMMATROQ. Shuning uchun atamalar ikki guruhga bo'linadi:
///   * KUCHLI (`_arrest`, `_searchStrong`, `_violence`) — o'zi yetarli, chunki
///     bu atamalar o'zbek huquqiy tilida faqat protsessual majburlash
///     ma'nosida keladi;
///   * KUCHSIZ (`_searchWeak`) — jinoyat-protsessual kontekst TALAB qiladi va
///     neytral kontekst topilsa bostiriladi.
library;

/// Bannerni ochgan sabab. Diagnostika uchun ochiq saqlanadi — §20:
/// "jim yutish yo'q", ya'ni nima uchun ochilgani/ochilmagani o'lchanadi.
enum EmergencyTrigger {
  /// Hibs, ushlab turish, qamoq — erkinlik cheklangan.
  arrest,

  /// Tintuv, musodara, shaxsiy ko'rik.
  search,

  /// Advokatsiz yoki majburlab so'roq qilish.
  coercedInterrogation,

  /// Jismoniy zo'ravonlik yoki tahdid.
  violence,
}

/// Klassifikator natijasi.
class EmergencySignal {
  const EmergencySignal({
    required this.triggers,
    this.suppressedTerm,
    this.suppressedBy,
  });

  /// Bo'sh bo'lsa — favqulodda holat aniqlanmagan.
  final Set<EmergencyTrigger> triggers;

  /// Kuchsiz atama topilgan, lekin bostirilgan bo'lsa — aynan qaysi atama.
  final String? suppressedTerm;

  /// Bostirgan neytral kontekst (masalan `soliq`). `null` — kontekst topilmadi,
  /// ya'ni atama shunchaki jinoyat-protsessual kontekstga ega bo'lmagan.
  final String? suppressedBy;

  bool get isEmergency => triggers.isNotEmpty;

  /// Kuchsiz atama uchrab, lekin banner ochilmagan holat. Faqat o'lchov va
  /// test uchun — UI bu holatda hech narsa ko'rsatmaydi.
  bool get wasSuppressed => suppressedTerm != null && !isEmergency;
}

class EmergencyDetector {
  EmergencyDetector._();

  /// Erkinlikdan mahrum qilish. `qamab` ALOHIDA kerak: "qamab qo'yish"
  /// `qamash` substring'iga TUSHMAYDI (o'lchangan — `test/integration/
  /// real_supabase_legal_rag_verification_test.dart:215` scenariysi shu
  /// sababli faqat `so'roq + majburiy` orqali ishlagan).
  static const Set<String> _arrest = {
    'hibs',
    'ushlab tur',
    'qamoq',
    'qamash',
    'qamab',
    'ozodlikdan mahrum',
    'hurriyatdan mahrum',
    'izolyator',
    'qamoqxona',
  };

  /// Jinoyat-protsessual ma'nosi YAGONA bo'lgan atamalar — kontekst kerak
  /// emas. `tintuv` JPK atamasi; uy-joy tintuvi sud qarori bilan o'tkaziladi.
  static const Set<String> _searchStrong = {
    'tintuv',
    'musodara',
    "shaxsiy ko'rik",
    'shaxsiy korik',
  };

  /// NEYTRAL ma'noda ham keladigan atamalar — jinoyat-protsessual kontekst
  /// TALAB qiladi. Aynan shu ro'yxat o'lchangan false positive manbasi edi.
  static const Set<String> _searchWeak = {
    'tekshiruv',
    'tekshirish',
    'tekshirib',
    'reyd',
    "ko'rik",
    'korik',
  };

  /// Kuchsiz atamani ochadigan kontekst. Bittasi yetarli.
  static const Set<String> _criminalContext = {
    'militsiya',
    'ichki ishlar',
    'prokuratura',
    'tergov',
    'jinoyat',
    'operativ',
    'nazorat xarid',
    'guvoh',
    'gumonlanuvchi',
    'ayblanuvchi',
    'sud qarori',
    'uyimga',
    'uyimda',
    'uyimni',
    'kvartira',
    'yashash joyi',
    'avtomobil',
    'mashinam',
    'telefonim',
  };

  /// Kuchsiz atamani BOSTIRADIGAN neytral kontekst. Jinoyat konteksti bilan
  /// birga kelsa jinoyat ustun turadi (asimmetrik ehtiyotkorlik).
  static const Set<String> _neutralContext = {
    'soliq',
    'kameral',
    'qqs',
    'deklaratsiya',
    'bojxona',
    'tibbiy',
    'texnik',
    'sertifikat',
    'audit',
    'sanitariya',
    'litsenziya',
    'buxgalter',
    'hisobot',
    'moliyaviy',
    'imtihon',
    'sifat',
    'ekspertiza',
  };

  /// `organ` OLIB TASHLANDI — o'rniga aniq iboralar. "vakolatli organ",
  /// "soliq organiga", "davlat organlari" endi bannerni ochmaydi.
  static const Set<String> _interrogation = {
    "so'roq",
    'soroq',
    'tergovchi',
    'tergov organ',
    'ichki ishlar organ',
    'huquqni muhofaza',
    'prokuratura',
    'militsiya',
    'ichki ishlar',
    'guvoh sifatida',
    'gumonlanuvchi',
    'ayblanuvchi',
  };

  /// So'roqni MAJBURLASHGA aylantiradigan belgi. Hozirgi kodda faqat
  /// `majburiy` bor edi; `majburla`/`advokatsiz` shu ma'noning aynan o'zi va
  /// TRUE POSITIVE ni kengaytiradi (bostirish emas).
  static const Set<String> _coercion = {
    'majburiy',
    'majburla',
    'advokatsiz',
    'advokat bermay',
    'advokatim yo',
    "qo'rqit",
    'qorqit',
  };

  static const Set<String> _violence = {
    "zo'ravonlik",
    'zoravonlik',
    'tahdid',
    'kaltak',
    'urib',
    "do'pposla",
  };

  /// So'rovni klassifikatsiya qiladi. Hech qanday I/O yo'q — sof funksiya,
  /// ya'ni natija AYNI kirishda DOIM ayni chiqishni beradi.
  static EmergencySignal classify(String queryText) {
    final lower = queryText.toLowerCase();
    bool has(Set<String> terms) => terms.any(lower.contains);
    String? firstIn(Set<String> terms) {
      for (final term in terms) {
        if (lower.contains(term)) return term;
      }
      return null;
    }

    final triggers = <EmergencyTrigger>{};
    if (has(_arrest)) triggers.add(EmergencyTrigger.arrest);
    if (has(_searchStrong)) triggers.add(EmergencyTrigger.search);
    if (has(_interrogation) && has(_coercion)) {
      triggers.add(EmergencyTrigger.coercedInterrogation);
    }
    if (has(_violence)) triggers.add(EmergencyTrigger.violence);

    // KUCHSIZ ATAMA DARVOZASI. Tartib muhim: jinoyat konteksti neytral
    // kontekstdan USTUN — "Uyimda soliq xodimlari tintuv o'tkazdi" kabi
    // aralash so'rovda banner O'CHIRILMAYDI.
    final weak = firstIn(_searchWeak);
    String? suppressedBy;
    if (weak != null && !triggers.contains(EmergencyTrigger.search)) {
      if (has(_criminalContext)) {
        triggers.add(EmergencyTrigger.search);
      } else {
        suppressedBy = firstIn(_neutralContext);
      }
    }

    return EmergencySignal(
      triggers: triggers,
      suppressedTerm:
          triggers.contains(EmergencyTrigger.search) ? null : weak,
      suppressedBy: suppressedBy,
    );
  }
}
