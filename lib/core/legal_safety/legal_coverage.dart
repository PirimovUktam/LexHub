/// LEXHUB QAMROV MANIFESTI — "ilova nimani bilishini BILADI".
///
/// NIMA UCHUN BU FAYL BOR (o'lchangan defekt zanjiri, 2026-08-26/27 audit):
///
/// `LegalGroundingValidator` xato moddadan HIMOYA QILMAYDI. Sababi
/// `legal_assistant_remote_datasource.dart`da tekshiriluvchi ro'yxat va
/// tekshiruv korpusi bir xil obyekt:
///
///     articles: LegalKnowledgeRetriever.toDomainArticles(relevantChunks),
///     verifiedChunks: relevantChunks,
///
/// Ya'ni validator "bu modda BORMI?" savoliga javob beradi — "bu modda
/// SAVOLGA TEGISHLIMI?" savoliga emas. Demak aloqasiz moddadan himoya
/// qiladigan YAKKA qatlam — qidiruv relevantligi.
///
/// Ilgari u qatlam faqat kalit so'z ballari va `_stopWords` QORA RO'YXATi
/// edi. Bu whack-a-mole: "olish" tuzatildi, keyingi so'rov "muddati",
/// "shakli", "javobgarligi" bilan yana teshib chiqadi — chunki har bir
/// o'zbek huquqiy moddasining sarlavhasida shu turdagi so'z bor va
/// SARLAVHA mosligi yakka o'zi `_minRelevanceScore`ga yetadi.
///
/// Shu fayl qora ro'yxatni OQ RO'YXATga aylantiradi: ilova qaysi huquqiy
/// sohalarni bilishini oshkora e'lon qiladi va boshqa hech qanday mavzuga
/// modda chiqarmaydi — so'z 100% mos tushsa ham. Nuqson sinfi
/// STRUKTURAVIY yopiladi, ro'yxatga qator qo'shish bilan emas.
///
/// QULFLANGAN INVARIANTLAR (`test/core/legal_safety/legal_coverage_test.dart`):
///  * qamrov da'vo qilingan har bir sohada bazada >= 1 modda bor;
///  * bazadagi har bir chunk aynan bitta sohaga tegishli (yetim chunk yo'q);
///  * qamrovdan tashqari mavzular fail-closed bo'ladi.
library;

import 'package:lexhub/core/legal_safety/law_article_chunk.dart';

/// Ilova QAMRAB OLGAN huquqiy sohalar. Yangi soha qo'shish — bu enum'ga
/// qiymat qo'shish EMAS, balki [LegalCoverage.domains]ga spec + bazaga
/// real modda qo'shish. Modda bo'lmasa invariant testi yiqiladi.
enum LegalDomain {
  konstitutsiya,
  mehnat,
  oila,
  fuqarolik,
  istemolchi,
  mamuriy,
}

/// Bitta sohaning e'loni: qaysi `jurisdiction` qiymatlariga tegishli va
/// so'rovda qanday FARQLOVCHI so'zlar uni ochadi.
class LegalDomainSpec {
  final LegalDomain domain;

  /// `LawArticleChunk.jurisdiction` bilan solishtirish uchun — [LegalCoverage.normalize]
  /// formatida (kichik harf, apostrof `'` (U+0027) shaklida SAQLANGAN).
  final Set<String> jurisdictions;

  /// Sohani ochadigan so'zlar. TALAB: FARQLOVCHI bo'lishi shart.
  ///
  /// Bu yerga "olish", "berish", "tartibi", "muddati", "shart" kabi umumiy
  /// protsedura so'zlarini QO'SHISH TAQIQLANADI — ular deyarli har bir
  /// huquqiy matnda bor, ya'ni farqlovchi kuchi nol. Aynan shu so'zlar
  /// tuzatilgan defektning sababi bo'lgan.
  ///
  /// Barcha qiymat [LegalCoverage.normalize] formatida bo'lishi shart
  /// (`legal_coverage_test.dart` 4-test buni qulflaydi). Apostrof SAQLANADI —
  /// sababi [LegalCoverage.normalize] izohida.
  final Set<String> triggers;

  const LegalDomainSpec({
    required this.domain,
    required this.jurisdictions,
    required this.triggers,
  });
}

/// Qamrovdan TASHQARIDAGI ma'lum mavzu + uni ko'radigan vakolatli organ.
///
/// Maqsad: halol rad etish BOSHI BERK KO'CHA bo'lmasligi. Foydalanuvchi
/// "topilmadi" o'rniga kimga murojaat qilishini biladi.
class UncoveredTopic {
  final String id;
  final Set<String> triggers;

  /// Vakolatli organ nomi. Faqat NOM — bu qiymat matnda ishlatiladi.
  final String organName;

  /// Portal manzili.
  ///
  /// DIQQAT: bu maydon Faza 1'da FAQAT ma'lumot sifatida saqlanadi va
  /// bosiladigan havola sifatida KO'RSATILMAYDI. Har bir manzil UI'ga
  /// chiqarilishidan oldin qo'lda tekshirilishi shart — noto'g'ri davlat
  /// portali havolasi foydalanuvchini yo'ldan uradi. Aniq bilinmagan
  /// hollarda ataylab yagona portal (`my.gov.uz`) ko'rsatilgan.
  final String portalUrl;

  /// `true` — mavzu shunchaki qamrovdan tashqarida emas, balki YURIST
  /// ARALASHUVI MAJBURIY bo'lgan yuqori xavfli soha. Bunda boshqa soha
  /// topilgan bo'lsa ham ogohlantirish beriladi.
  final bool isHardStop;

  const UncoveredTopic({
    required this.id,
    required this.triggers,
    required this.organName,
    required this.portalUrl,
    this.isHardStop = false,
  });
}

/// Bitta so'rov uchun qamrov qarori.
class CoverageResult {
  /// So'rov ochgan sohalar. Bo'sh bo'lsa — qidiruv umuman boshlanmaydi.
  final Set<LegalDomain> domains;

  /// Hech qanday soha topilmaganda aniqlangan ma'lum tashqi mavzu.
  final UncoveredTopic? uncoveredTopic;

  /// Yurist majburiy bo'lgan mavzu — soha topilgan bo'lsa ham beriladi.
  final UncoveredTopic? hardStopTopic;

  const CoverageResult({
    required this.domains,
    this.uncoveredTopic,
    this.hardStopTopic,
  });

  bool get isCovered => domains.isNotEmpty;

  /// Chunk shu so'rov uchun NOMZOD bo'la oladimi.
  ///
  /// DARVOZA 1: ball hisoblanishidan OLDIN chaqiriladi. Sohaga kirmagan
  /// chunk ball to'plash imkoniga EGA BO'LMAYDI — tasodifiy so'z mosligi
  /// soha chegarasini kesib o'tolmaydi.
  bool allowsChunk(LawArticleChunk chunk) {
    final domain = LegalCoverage.domainOfJurisdiction(chunk.jurisdiction);
    return domain != null && domains.contains(domain);
  }
}

class LegalCoverage {
  LegalCoverage._();

  /// QAMRAB OLINGAN sohalar ro'yxati.
  static const List<LegalDomainSpec> domains = [
    LegalDomainSpec(
      domain: LegalDomain.konstitutsiya,
      jurisdictions: {'konstitutsiyaviy huquq'},
      // Favqulodda holat lug'ati SHU YERDA bo'lishi HAYOTIY muhim:
      // hibsga olish/tintuv so'rovida foydalanuvchi Konstitutsiyaning
      // 27/28/29-moddalarini qonuniy asos sifatida ko'rishi kerak. Bu
      // triggerlar tushib qolsa `detectEmergency` ishlagani bilan
      // `legalBasis` bo'sh qoladi — ya'ni eng kritik scenariyda regressiya.
      triggers: {
        'hibs', 'ushlab tur', 'qamoq', 'qamash', 'tintuv',
        "so'roq", 'soroq',
        'advokat', 'sukut saqla', 'militsiya', 'ichki ishlar', 'daxlsizlik',
        'majburiy mehnat', 'yuridik yordam', 'tergov', 'ozodlik',
        "zo'ravonlik", 'zoravonlik',
        'tahdid', 'kaltak', 'konstitutsiya', 'musodara',
      },
    ),
    LegalDomainSpec(
      domain: LegalDomain.mehnat,
      jurisdictions: {'mehnat huquqi'},
      triggers: {
        'mehnat', 'ish beruvchi', 'ishdan',
        "bo'shat", 'boshat',
        'maosh', 'ish haqi', 'oylik', 'xodim', 'shtat',
        "ta'til", 'tatil',
        'ishga tikla', 'ish joyi', 'ishga qabul', 'sinov muddati',
        'mehnat daftarcha', 'ishchi', 'ish vaqti', 'ish kuni', 'ortiqcha ish',
      },
    ),
    LegalDomainSpec(
      domain: LegalDomain.oila,
      jurisdictions: {'oila huquqi'},
      triggers: {
        'aliment', 'nikoh', 'ajrash', 'ajrim', 'ajralish', 'farzand',
        // "bola" APOSTROFSIZ shakli xavfli emas — chunki normalize() apostrofni
        // SAQLAYDI, ya'ni "bo'ladi"/"bo'lishi" bu triggerga TUSHMAYDI.
        // Apostrof o'chirilgan variantda ("boladi") tushardi va bu real
        // o'lchangan xato bo'lgan (legal_coverage_test.dart 12-test).
        'bola', 'ota-ona', 'oila', 'er-xotin', 'xotin',
        "turmush o'rtog", 'turmush ortog',
        'nafaqa', 'vasiylik', 'farzandlikka',
      },
    ),
    LegalDomainSpec(
      domain: LegalDomain.fuqarolik,
      jurisdictions: {'fuqarolik huquqi'},
      triggers: {
        'qarz', 'tilxat',
        "da'vo muddati", 'davo muddati',
        'iskovaya', 'qarzdor', 'pulni qaytar', 'shartnoma',
        "sudga da'vo", 'sudga davo',
        'zarar qopla',
      },
    ),
    LegalDomainSpec(
      domain: LegalDomain.istemolchi,
      jurisdictions: {"iste'molchilar huquqi"},
      triggers: {
        'tovar',
        "iste'molchi", 'istemolchi',
        "do'kon", 'dokon',
        'xarid', 'nuqson', 'kafolat', 'sotuvchi', 'mahsulot', 'sifatsiz',
        'brak', 'xarid cheki', 'kassa cheki', 'almashtir',
      },
    ),
    LegalDomainSpec(
      domain: LegalDomain.mamuriy,
      jurisdictions: {"ma'muriy huquq"},
      triggers: {
        'jarima', 'radar', 'yhq',
        "ma'muriy", 'mamuriy',
        'tezlik', 'huquqbuzarlik', 'protokol', 'patrul', 'qaror ustidan',
        'shikoyat berish',
      },
    ),
  ];

  /// QAMROVDAN TASHQARIDAGI ma'lum mavzular.
  ///
  /// Bu ro'yxat qamrovni KENGAYTIRMAYDI — u faqat halol rad etishni
  /// FOYDALI qiladi (kimga borishni aytadi). Ro'yxatda yo'q mavzu ham
  /// baribir fail-closed bo'ladi, shunchaki umumiy yo'naltirish beriladi.
  static const List<UncoveredTopic> uncoveredTopics = [
    UncoveredTopic(
      id: 'jinoyat',
      // ATAYLAB `tergov`/`hibs` YO'Q: ular konstitutsiyaviy huquqlar
      // scenariysi va foydalanuvchi 27/28/29-moddalarni olishi kerak.
      // Bu yerda AYBLANISH lug'ati — unda advokat majburiy.
      triggers: {
        'jinoyat', 'jinoiy', 'ayblanuvchi',
        "ayb qo'y", 'ayb qoy',
        'gumondor', 'sudlangan', 'jazo tayinla', 'firibgarlik', 'talonchilik',
      },
      organName: 'Litsenziyaga ega advokat (majburiy)',
      portalUrl: 'https://my.gov.uz',
      isHardStop: true,
    ),
    UncoveredTopic(
      id: 'soliq',
      triggers: {'soliq', 'qqs', 'aksiz', 'deklaratsiya', 'inps'},
      organName: 'Davlat soliq qomitasi',
      portalUrl: 'https://soliq.uz',
    ),
    UncoveredTopic(
      id: 'litsenziya',
      triggers: {'litsenziya', 'ruxsatnoma', 'litsenziyalash'},
      organName: 'Litsenziyalash organi (faoliyat turiga qarab)',
      portalUrl: 'https://my.gov.uz',
    ),
    UncoveredTopic(
      id: 'bojxona',
      triggers: {
        'bojxona', 'import', 'eksport',
        "boj to'lovi", 'boj tolovi',
      },
      organName: 'Davlat bojxona qomitasi',
      portalUrl: 'https://my.gov.uz',
    ),
    UncoveredTopic(
      id: 'migratsiya',
      // 'patent olib' ATAYLAB YO'Q: mehnat migratsiyasidagi "patent" va
      // intellektual mulkdagi "patent" bir xil so'z. Ikkisi ham qamrovdan
      // tashqarida (ya'ni ikkalasi ham fail-closed), farq faqat ko'rsatilgan
      // organda. Uzunroq noaniq trigger 'patent'ni bekor qilmasligi uchun
      // olib tashlangan — noto'g'ri organ nomi ham foydalanuvchini yo'ldan uradi.
      triggers: {'migratsiya', 'viza', 'propiska', 'fuqarolikka'},
      organName: 'Tashqi migratsiya va fuqarolik masalalari agentligi',
      portalUrl: 'https://my.gov.uz',
    ),
    UncoveredTopic(
      id: 'bank',
      triggers: {'valyuta', 'kredit', 'ipoteka', 'bank hisobi', 'mikroqarz'},
      organName: "O'zbekiston Respublikasi Markaziy banki",
      portalUrl: 'https://cbu.uz',
    ),
    UncoveredTopic(
      id: 'intellektual',
      triggers: {'patent', 'tovar belgisi', 'mualliflik huquqi', 'intellektual mulk'},
      organName: 'Intellektual mulk agentligi',
      portalUrl: 'https://my.gov.uz',
    ),
    UncoveredTopic(
      id: 'yer_qurilish',
      // 'koplab qurilish' OLIB TASHLANGAN: "ko'plab" umumiy ravish, apostrofsiz
      // shakli boshqa so'zlar ichida uchraydi va spesifiklik qoidasida
      // uzunligi bilan haqiqiy sohani bekor qilib qo'yishi mumkin edi.
      triggers: {'kadastr', 'yer maydoni', 'qurilish ruxsati'},
      organName: 'Kadastr agentligi yoki mahalliy hokimlik',
      portalUrl: 'https://my.gov.uz',
    ),
    UncoveredTopic(
      id: 'korporativ',
      // 'yatt royxatdan' OLIB TASHLANGAN: so'zlashuv shaklidagi "-yatti"
      // qo'shimchasi ("qilyatti", "boryatti") ichida "yatt" bo'lagi bor.
      // Bunday trigger tasodifiy so'rovni korporativ mavzuga burib yuboradi.
      triggers: {'mchj', 'ustav fondi', 'aksiyadorlik'},
      organName: 'Davlat xizmatlari markazi',
      portalUrl: 'https://my.gov.uz',
    ),
    UncoveredTopic(
      id: 'sugurta',
      triggers: {
        "sug'urta", 'sugurta',
        'osago', 'polis',
      },
      organName: "Moliya vazirligi (sug'urta nazorati)",
      portalUrl: 'https://my.gov.uz',
    ),
    UncoveredTopic(
      id: 'ekologiya',
      triggers: {'ekologiya', 'atrof-muhit', 'chiqindi', 'daraxt kesish'},
      organName: 'Ekologiya va atrof-muhitni muhofaza qilish vazirligi',
      portalUrl: 'https://my.gov.uz',
    ),
    UncoveredTopic(
      id: 'davlat_xaridi',
      triggers: {'tender', 'davlat xaridi', 'ommaviy xarid'},
      organName: 'Davlat xaridlari agentligi',
      portalUrl: 'https://my.gov.uz',
    ),
  ];

  /// O'zbek lotin yozuvida apostrof uchun amalda TO'RT xil belgi ishlatiladi:
  /// `'` (U+0027), `’` (U+2019), `ʻ` (U+02BB, rasmiy tutuq belgisi) va
  /// `` ` `` (U+0060). Ular BITTA belgiga (U+0027) keltiriladi.
  ///
  /// APOSTROF O'CHIRILMAYDI — SAQLANADI. Bu ataylab qilingan tanlov:
  ///
  /// O'LCHANGAN XATO (`legal_coverage_test.dart` 12-test): normalizatsiya
  /// apostrofni O'CHIRIB tashlaganda "bo'ladi" -> "boladi" bo'lardi va
  /// `bola` (oila sohasi) triggeriga TUSHARDI. Ya'ni "MChJ ustav fondi
  /// qancha bo'lishi kerak?" degan korporativ savol OILA huquqi sohasini
  /// ochardi. "bo'l-" o'zbek tilidagi eng chastotali yordamchi fe'l, demak
  /// bu xato deyarli har uchinchi so'rovda takrorlanardi.
  ///
  /// Apostrof — MA'NO FARQLOVCHI belgi ("bola" != "bo'la", "tatil" !=
  /// "ta'til"), uni tashlab yuborish ma'lumot yo'qotish bilan teng.
  ///
  /// Foydalanuvchi apostrofni umuman yozmasligi mumkin ("boshatish"). Bu
  /// holat ALIAS bilan qoplanadi: triggerlar ro'yxatida ikkala shakl ham
  /// bor ("bo'shat" va "boshat"). Alias FAQAT apostrofsiz shakli boshqa
  /// haqiqiy so'z bo'lmaganda qo'shiladi — shu sababli "bola" bor, "bo'la"
  /// uchun alias YO'Q.
  static final RegExp _apostrophes = RegExp('[’ʻ`´]');

  static String normalize(String value) =>
      value.toLowerCase().replaceAll(_apostrophes, "'");

  /// `jurisdiction` maydonidan sohani aniqlaydi. Mos soha yo'q — `null`
  /// (bu holda chunk hech qanday so'rovga nomzod bo'lmaydi).
  static LegalDomain? domainOfJurisdiction(String jurisdiction) {
    final norm = normalize(jurisdiction);
    for (final spec in domains) {
      if (spec.jurisdictions.contains(norm)) return spec.domain;
    }
    return null;
  }

  /// Matnda mos tushgan ENG UZUN triggerning uzunligi (0 — moslik yo'q).
  ///
  /// Uzunlik SPESIFIKLIK o'lchovi sifatida ishlatiladi — pastdagi
  /// [classify] izohiga qarang.
  static int _bestMatchLength(Set<String> triggers, String text) {
    int best = 0;
    for (final t in triggers) {
      if (t.length > best && text.contains(t)) best = t.length;
    }
    return best;
  }

  /// DARVOZA 0 — so'rovni sohaga ajratadi.
  ///
  /// SPESIFIKLIK QOIDASI (o'lchangan xato, `legal_coverage_test.dart` 6-test):
  /// "Tovar belgisini ro'yxatdan o'tkazish" (tovar markasi = intellektual
  /// mulk) so'rovi `tovar` triggeri orqali ISTE'MOLCHI sohasini ochardi va
  /// foydalanuvchiga Iste'molchilar huquqi qonunining 13/18-moddalari
  /// "qonuniy asos" bo'lib ko'rsatilardi. Sabab — "tovar belgisi" huquqiy
  /// ATAMA, "tovar" esa uning bo'lagi; oddiy `contains` ularni ajratmaydi.
  ///
  /// Yechim: qamrovdan tashqaridagi mavzu ANIQROQ (uzunroq) atama bilan mos
  /// tushsa, u qisqa umumiy trigger ustidan g'olib bo'ladi. Bu lingvistik
  /// jihatdan to'g'ri model (aniqroq atama umumiyni bekor qiladi) va yangi
  /// nuqson uchun ro'yxatga qator qo'shishni TALAB QILMAYDI.
  static CoverageResult classify(String queryText) {
    final text = normalize(queryText);

    UncoveredTopic? uncovered;
    UncoveredTopic? hardStop;
    int uncoveredLength = 0;

    for (final topic in uncoveredTopics) {
      final length = _bestMatchLength(topic.triggers, text);
      if (length == 0) continue;
      if (topic.isHardStop) {
        // HARD STOP spesifiklik raqobatiga QATNASHMAYDI: jinoyat lug'ati
        // qamrovdagi sohani SIQIB CHIQARMASLIGI kerak. "Jinoyat ishi
        // bo'yicha meni ishdan bo'shatishdi" so'rovida foydalanuvchi
        // MEHNAT moddalarini ham, advokat ogohlantirishini HAM oladi.
        hardStop ??= topic;
        continue;
      }
      if (length > uncoveredLength) {
        uncoveredLength = length;
        uncovered = topic;
      }
    }

    final matched = <LegalDomain>{};
    for (final spec in domains) {
      final length = _bestMatchLength(spec.triggers, text);
      if (length == 0) continue;
      // SPESIFIKLIK: qisqaroq umumiy trigger uzunroq tashqi atamaga yon beradi.
      if (length < uncoveredLength) continue;
      matched.add(spec.domain);
    }

    return CoverageResult(
      domains: matched,
      // Soha topilgan bo'lsa tashqi mavzu haqida gapirmaymiz — javob
      // topilgan moddalar asosida beriladi. `hardStop` esa HAR HOLDA
      // qoladi: yurist majburiy bo'lgan mavzuni jim o'tkazib bo'lmaydi.
      uncoveredTopic: matched.isEmpty ? (uncovered ?? hardStop) : null,
      hardStopTopic: hardStop,
    );
  }

  /// TOPILGAN chunk'lar asosida yetakchi sohani aniqlaydi.
  ///
  /// NIMA UCHUN SO'ROVDAN EMAS, TOPILGAN MODDALARDAN: soha qamrovda
  /// bo'lishi shu sohaning HAR BIR savoliga modda borligini bildirmaydi.
  /// Misol: "meros" so'rovi `fuqarolik` sohasini ochadi, lekin bazada
  /// meros moddasi YO'Q (faqat 150 va 732). Javob matni so'rov sohasiga
  /// qarab yozilsa — asossiz "qarz" maslahati beriladi. Shuning uchun
  /// matn HAR DOIM haqiqatan topilgan moddalarga bog'lanadi.
  static LegalDomain? dominantDomain(List<LawArticleChunk> chunks) {
    final counts = <LegalDomain, int>{};
    for (final chunk in chunks) {
      final domain = domainOfJurisdiction(chunk.jurisdiction);
      if (domain == null) continue;
      counts[domain] = (counts[domain] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;

    // Konstitutsiya moddalari ko'p so'rovda YONDOSH bo'lib keladi
    // (masalan 42-modda mehnat so'rovida). Tenglik holatida MAXSUS soha
    // ustun bo'lishi kerak, aks holda javob matni umumiy bo'lib qoladi.
    LegalDomain best = counts.keys.first;
    int bestCount = -1;
    for (final entry in counts.entries) {
      final isBetter = entry.value > bestCount ||
          (entry.value == bestCount &&
              best == LegalDomain.konstitutsiya &&
              entry.key != LegalDomain.konstitutsiya);
      if (isBetter) {
        best = entry.key;
        bestCount = entry.value;
      }
    }
    return best;
  }
}
