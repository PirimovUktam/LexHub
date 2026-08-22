import 'package:lexhub/core/legal_safety/law_article_chunk.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/law_article.dart';

/// Embedded verified knowledge base of active Uzbekistan legislation
/// Grounded strictly on official Lex.uz sources and 2023 legislative reforms
class UzbekLegalKnowledgeBase {
  UzbekLegalKnowledgeBase._();

  static const List<LawArticleChunk> verifiedLawChunks = [
    // 1. O'zbekiston Respublikasi Konstitutsiyasi (2023 Yangi Tahrir)
    LawArticleChunk(
      chunkId: 'const_art_27',
      documentName: "O'zbekiston Respublikasining Konstitutsiyasi",
      documentId: 'lex_const_2023',
      articleNumber: 27,
      articleTitle: "Shaxsiy daxlsizlik va erkinlik huquqi",
      content: "Har kim erkinlik va shaxsiy daxlsizlik huquqiga ega. Hech kim qonunga asoslanmagan holda hibsga olinishi, ushlab turilishi, qamoqqa olinishi yoki boshqacha tarzda ozodlikdan mahrum etilishi mumkin emas.",
      status: 'active',
      jurisdiction: 'Konstitutsiyaviy huquq',
      lastUpdated: '2023-05-01',
      lexUrl: 'https://lex.uz/docs/6445145#6445371',
    ),
    LawArticleChunk(
      chunkId: 'const_art_28',
      documentName: "O'zbekiston Respublikasining Konstitutsiyasi",
      documentId: 'lex_const_2023',
      articleNumber: 28,
      articleTitle: "Miranda qoidasi va sukut saqlash huquqi",
      content: "Shaxsni ushlash chog'ida unga tushunarli tilda uning huquqlari va ushlab turilishi asoslari tushuntirilishi shart. Ushlab turilgan shaxs sukut saqlash huquqiga ega va uning so'zlaridan unga qarshi sudda foydalanilishi mumkin.",
      status: 'active',
      jurisdiction: 'Konstitutsiyaviy huquq',
      lastUpdated: '2023-05-01',
      lexUrl: 'https://lex.uz/docs/6445145#6445375',
    ),
    LawArticleChunk(
      chunkId: 'const_art_29',
      documentName: "O'zbekiston Respublikasining Konstitutsiyasi",
      documentId: 'lex_const_2023',
      articleNumber: 29,
      articleTitle: "Malakali yuridik yordam olish va advokat huquqi",
      content: "Har kimga malakali yuridik yordam olish huquqi kafolatlanadi. Qonunda nazarda tutilgan hollarda yuridik yordam davlat hisobidan ko'rsatiladi. Shaxs ushlangan paytdan boshlab advokat xizmatidan foydalanish huquqiga ega.",
      status: 'active',
      jurisdiction: 'Konstitutsiyaviy huquq',
      lastUpdated: '2023-05-01',
      lexUrl: 'https://lex.uz/docs/6445145#6445380',
    ),
    LawArticleChunk(
      chunkId: 'const_art_42',
      documentName: "O'zbekiston Respublikasining Konstitutsiyasi",
      documentId: 'lex_const_2023',
      articleNumber: 42,
      articleTitle: "Munosib mehnat sharoitlari va adolatli haq olish huquqi",
      content: "Har kim munosib mehnat qilish, kasb va faoliyat turini erkin tanlash, xavfsizlik va gigiyena talablariga javob beradigan qulay mehnat sharoitlarida ishlash, mehnati uchun hech qanday kamsitishlarsiz adolatli haq olish huquqiga ega.",
      status: 'active',
      jurisdiction: 'Konstitutsiyaviy huquq',
      lastUpdated: '2023-05-01',
      lexUrl: 'https://lex.uz/docs/6445145#6445428',
    ),
    LawArticleChunk(
      chunkId: 'const_art_44',
      documentName: "O'zbekiston Respublikasining Konstitutsiyasi",
      documentId: 'lex_const_2023',
      articleNumber: 44,
      articleTitle: "Majburiy mehnatni taqiqlash",
      content: "Sud qarori bilan tayinlangan jazoni ijro etish tartibidan yoki qonunda nazarda tutilgan boshqa hollardan tashqari majburiy mehnat taqiqlanadi.",
      status: 'active',
      jurisdiction: 'Konstitutsiyaviy huquq',
      lastUpdated: '2023-05-01',
      lexUrl: 'https://lex.uz/docs/6445145#6445434',
    ),

    // 2. Yangi tahrirdagi Mehnat kodeksi (2023)
    LawArticleChunk(
      chunkId: 'labor_art_5',
      documentName: "O'zbekiston Respublikasining Mehnat kodeksi",
      documentId: 'lex_labor_2023',
      articleNumber: 5,
      articleTitle: "Majburiy mehnatni taqiqlash",
      content: "Majburiy mehnat, ya'ni biror-bir jazo qo'llash bilan tahdid qilish orqali biron-bir ishni bajarishga majburlash qat'iyan taqiqlanadi. Xodimni uning roziligisiz mehnat shartnomasida ko'rsatilmagan ishlarga jalb qilish man etiladi.",
      status: 'active',
      jurisdiction: 'Mehnat huquqi',
      lastUpdated: '2023-04-30',
      lexUrl: 'https://lex.uz/docs/6257288#6257320',
    ),
    LawArticleChunk(
      chunkId: 'labor_art_161',
      documentName: "O'zbekiston Respublikasining Mehnat kodeksi",
      documentId: 'lex_labor_2023',
      articleNumber: 161,
      articleTitle: "Mehnat shartnomasini ish beruvchining tashabbusi bilan bekor qilish asoslari",
      content: "Ish beruvchi tashabbusi bilan shartnoma faqat xodimlar soni yoki shtati o'zgarganda, malakasi yetarli bo'lmaganda yoki mehnat majburiyatlarini muntazam buzgan taqdirdagina bekor qilinishi mumkin. Boshqa sabablar noqonuniy hisoblanadi.",
      status: 'active',
      jurisdiction: 'Mehnat huquqi',
      lastUpdated: '2023-04-30',
      lexUrl: 'https://lex.uz/docs/6257288#6262483',
    ),
    LawArticleChunk(
      chunkId: 'labor_art_333',
      documentName: "O'zbekiston Respublikasining Mehnat kodeksi",
      documentId: 'lex_labor_2023',
      articleNumber: 333,
      articleTitle: "Ish haqini to'lash muddatlarini buzganlik uchun moddiy javobgarlik",
      content: "Ish beruvchi ish haqini, ta'til to'lovlarini to'lash muddatini buzgan taqdirda, kechiktirilgan har bir kun uchun Markaziy bank qayta moliyalashtirish stavkasining 10 foizi miqdorida foizlar (pul kompensatsiyasi) to'lashi shart.",
      status: 'active',
      jurisdiction: 'Mehnat huquqi',
      lastUpdated: '2023-04-30',
      lexUrl: 'https://lex.uz/docs/6257288#6266120',
    ),
    LawArticleChunk(
      chunkId: 'labor_art_560',
      documentName: "O'zbekiston Respublikasining Mehnat kodeksi",
      documentId: 'lex_labor_2023',
      articleNumber: 560,
      articleTitle: "Yakka mehnat nizolarini ko'rib chiqish uchun sudga murojaat qilish muddatlari",
      content: "Ishga tiklash to'g'risidagi nizolar bo'yicha sudga murojaat qilish muddati xodimga u bilan mehnat shartnomasi bekor qilinganligi haqidagi buyruq nusxasi topshirilgan kundan e'tiboran 1 oyni tashkil etadi.",
      status: 'active',
      jurisdiction: 'Mehnat huquqi',
      lastUpdated: '2023-04-30',
      lexUrl: 'https://lex.uz/docs/6257288#6270500',
    ),

    // 3. Oila kodeksi
    LawArticleChunk(
      chunkId: 'family_art_96',
      documentName: "O'zbekiston Respublikasining Oila kodeksi",
      documentId: 'lex_family',
      articleNumber: 96,
      articleTitle: "Ota-onaning voyaga yetmagan bolalariga ta'minot berish majburiyati",
      content: "Ota-ona voyaga yetmagan bolalariga ta'minot berishi shart. Voyaga yetmagan bolalariga ta'minot berish majburiyatini ixtiyoriy ravishda bajarmagan ota-onadan sudning hal qiluv qaroriga yoki sud buyrug'iga asosan aliment undiriladi.",
      status: 'active',
      jurisdiction: 'Oila huquqi',
      lastUpdated: '2023-01-01',
      lexUrl: 'https://lex.uz/docs/104720#107382',
    ),
    LawArticleChunk(
      chunkId: 'family_art_99',
      documentName: "O'zbekiston Respublikasining Oila kodeksi",
      documentId: 'lex_family',
      articleNumber: 99,
      articleTitle: "Voyaga yetmagan bolalarga suddan undiriladigan aliment miqdori",
      content: "Aliment ota-onaning har oydagi daromadining: 1 bola uchun — to'rtdan bir qismi (1/4); 2 bola uchun — uchdan bir qismi (1/3); 3 va undan ortiq bola uchun — yarmi (1/2) miqdorida undiriladi.",
      status: 'active',
      jurisdiction: 'Oila huquqi',
      lastUpdated: '2023-01-01',
      lexUrl: 'https://lex.uz/docs/104720#107412',
    ),
    LawArticleChunk(
      chunkId: 'family_art_136',
      documentName: "O'zbekiston Respublikasining Oila kodeksi",
      documentId: 'lex_family',
      articleNumber: 136,
      articleTitle: "Alimentni o'tgan davr uchun undirish muddati",
      content: "Aliment sudga murojaat qilingan paytdan boshlab undiriladi. O'tgan davr uchun aliment sudga murojaat qilishdan oldingi 3 yillik muddat doirasida undirilishi mumkin.",
      status: 'active',
      jurisdiction: 'Oila huquqi',
      lastUpdated: '2023-01-01',
      lexUrl: 'https://lex.uz/docs/104720#107580',
    ),

    // 4. Fuqarolik kodeksi
    LawArticleChunk(
      chunkId: 'civil_art_150',
      documentName: "O'zbekiston Respublikasining Fuqarolik kodeksi",
      documentId: 'lex_civil',
      articleNumber: 150,
      articleTitle: "Umumiy da'vo muddati (Iskovaya davnost)",
      content: "Fuqarolik munosabatlarida shaxs o'zining buzilgan huquqini himoya qilish uchun sudga da'vo taqdim etishi mumkin bo'lgan umumiy muddat uch yilni (3 yil) tashkil etadi.",
      status: 'active',
      jurisdiction: 'Fuqarolik huquqi',
      lastUpdated: '2023-01-01',
      lexUrl: 'https://lex.uz/docs/111189#111600',
    ),
    LawArticleChunk(
      chunkId: 'civil_art_732',
      documentName: "O'zbekiston Respublikasining Fuqarolik kodeksi",
      documentId: 'lex_civil',
      articleNumber: 732,
      articleTitle: "Qarz shartnomasi va uning shakli",
      content: "Qarz shartnomasi bo'yicha bir taraf (qarz beruvchi) ikkinchi tarafga (qarz oluvchiga) pul yoki boshqa ashyolarni mulk qilib beradi. Fuqarolar o'rtasida qarz summasi BHMning 10 baravaridan oshganda yozma shartnoma yoki tilxat tuzilishi shart.",
      status: 'active',
      jurisdiction: 'Fuqarolik huquqi',
      lastUpdated: '2023-01-01',
      lexUrl: 'https://lex.uz/docs/111189#161394',
    ),

    // 5. Ma'muriy javobgarlik to'g'risidagi kodeks (MJtK)
    LawArticleChunk(
      chunkId: 'admin_art_315',
      documentName: "Ma'muriy javobgarlik to'g'risidagi kodeks",
      documentId: 'lex_admin',
      articleNumber: 315,
      articleTitle: "Ma'muriy huquqbuzarlik to'g'risidagi qaror ustidan shikoyat berish muddati",
      content: "Ma'muriy huquqbuzarlik to'g'risidagi ish yuzasidan chiqarilgan qaror ustidan qaror nusxasi topshirilgan yoki e'lon qilingan kundan e'tiboran 10 kun ichida yuqori turuvchi organga yoki sudga shikoyat berilishi mumkin.",
      status: 'active',
      jurisdiction: "Ma'muriy huquq",
      lastUpdated: '2023-01-01',
      lexUrl: 'https://lex.uz/docs/97661#101250',
    ),

    // 6. Iste'molchilarning huquqlarini himoya qilish to'g'risidagi Qonun
    LawArticleChunk(
      chunkId: 'consumer_art_13',
      documentName: "Iste'molchilarning huquqlarini himoya qilish to'g'risidagi Qonun",
      documentId: 'lex_consumer',
      articleNumber: 13,
      articleTitle: "Nuqsonli tovar sotilganda iste'molchining huquqlari",
      content: "Iste'molchiga nuqsonli tovar sotilganda, u tovarni maqbul sifatlisiga almashtirish, bepul tuzatish yoki to'langan pulni to'liq qaytarib olish va yetkazilgan zararni qoplashni talab qilishga haqli.",
      status: 'active',
      jurisdiction: "Iste'molchilar huquqi",
      lastUpdated: '2023-01-01',
      lexUrl: 'https://lex.uz/docs/440#452',
    ),
    LawArticleChunk(
      chunkId: 'consumer_art_18',
      documentName: "Iste'molchilarning huquqlarini himoya qilish to'g'risidagi Qonun",
      documentId: 'lex_consumer',
      articleNumber: 18,
      articleTitle: "Maqbul sifatli tovarni almashtirish va qaytarish huquqi",
      content: "Iste'molchi nooziq-ovqat tovarini sotib olgan kundan e'tiboran 10 kun ichida xarid joyidagi sotuvchidan uni maqbul sifatlisiga almashtirish yoki pulini qaytarib olish huquqiga ega.",
      status: 'active',
      jurisdiction: "Iste'molchilar huquqi",
      lastUpdated: '2023-01-01',
      lexUrl: 'https://lex.uz/docs/440#465',
    ),
  ];
}

/// Legal Knowledge Retriever for Semantic & Keyword Matching
class LegalKnowledgeRetriever {
  /// Chunk "aloqador" hisoblanishi uchun kerakli minimal ball.
  ///
  /// Ballar: sarlavha mosligi +5, mazmun mosligi +3, hujjat nomi +2.
  /// 5 — bu ataylab tanlangan chegara: bitta tasodifiy MAZMUN mosligi (3)
  /// yetarli emas, lekin sarlavha mosligi (5) yoki ikki mazmun mosligi (6)
  /// yetadi. Chegara pasaytirilsa 96-modda regressiyasi qaytadi
  /// (`test/core/legal_safety/retrieval_relevance_test.dart`).
  static const int _minRelevanceScore = 5;

  static const Map<String, List<String>> _synonyms = {
    'maosh': ['ish haqi', 'to\'lov', 'mehnat', 'kompensatsiya'],
    'boshliq': ['ish beruvchi', 'rahbar', 'mehnat'],
    'bo\'shat': ['bekor qilish', 'mehnat shartnomasi', 'ishdan'],
    'radar': ['jarima', 'tezlik', 'qaror', 'ma\'muriy', 'yhq'],
    'jarima': ['radar', 'qaror', 'ma\'muriy', 'yhq', 'shikoyat'],
    'aliment': ['farzand', 'ta\'minot', 'bola', 'oila', 'sud buyrug\'i'],
    'tovar': ['iste\'molchi', 'do\'kon', 'nuqson', 'qaytarish'],
    'qarz': ['tilxat', 'shartnoma', 'fuqarolik'],
  };

  /// Retrieves relevant law article chunks matching the user query text
  static List<LawArticleChunk> retrieveRelevantChunks(String queryText, {int maxResults = 3}) {
    final lower = queryText.toLowerCase();
    final scored = <LawArticleChunk, int>{};

    final keywords = _extractKeywords(lower);
    final expandedKeywords = <String>{...keywords};
    for (final kw in keywords) {
      for (final entry in _synonyms.entries) {
        if (kw.contains(entry.key) || entry.key.contains(kw)) {
          expandedKeywords.addAll(entry.value);
        }
      }
    }

    for (final chunk in UzbekLegalKnowledgeBase.verifiedLawChunks) {
      if (!chunk.isActive) continue;

      int score = 0;
      final titleLower = chunk.articleTitle.toLowerCase();
      final docLower = chunk.documentName.toLowerCase();
      final contentLower = chunk.content.toLowerCase();

      for (final kw in expandedKeywords) {
        if (titleLower.contains(kw)) score += 5;
        if (contentLower.contains(kw)) score += 3;
        if (docLower.contains(kw)) score += 2;
      }

      // P1: FAQAT BITTA umumiy so'z ustma-ust tushgani "huquqiy asos" bo'la
      // olmaydi. Real qurilmada olingan nuqson: "ishdan bo'shatish" so'roviga
      // javobda Oila kodeksining 96-moddasi ("Ota-onaning voyaga yetmagan
      // bolalariga ta'minot berish majburiyati") huquqiy asos sifatida
      // ko'rsatildi. Sabab — so'rovdagi `ravishda` so'zi 96-modda matnidagi
      // "ixtiyoriy RAVISHDA bajarmagan" iborasiga tushib, +3 ball bergan.
      //
      // Shuning uchun eng kamida bitta SARLAVHA/HUJJAT darajasidagi moslik
      // (5 yoki 2+3) yoki ikkita mazmun mosligi (3+3) talab qilinadi.
      // `LegalGroundingValidator` bu ishni bajarmaydi — u modda HAQIQIY
      // ekanini tekshiradi, MAVZUGA ALOQADORLIGINI emas.
      if (score >= _minRelevanceScore) {
        scored[chunk] = score;
      }
    }

    if (scored.isEmpty) {
      // Default Constitutional & General protections
      return UzbekLegalKnowledgeBase.verifiedLawChunks.take(maxResults).toList();
    }

    final sorted = scored.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(maxResults).map((e) => e.key).toList();
  }

  /// Qidiruvda MA'NO tashimaydigan so'zlar.
  ///
  /// P1: bu ro'yxat ilgari faqat olmosh/bog'lovchilardan iborat edi, shu
  /// sababli qonun matnida tez uchraydigan RASMIY-USLUB so'zlari ("ravishda",
  /// "shart", "asosan", "boshqa") ham kalit so'z sifatida ball to'plardi va
  /// mavzuga aloqasiz moddalarni yuqoriga chiqarardi.
  static const Set<String> _stopWords = {
    'men', 'sen', 'biz', 'siz', 'ular', 'bilan', 'uchun', 'ham', 'yoki',
    'agar', 'lekin', 'ammo', 'chunki', 'nima', 'qanday', 'qilish', 'qilib',
    'haqida', 'kerak', 'mumkin', 'emas', 'bor', 'yoq', 'ushbu',
    'barcha', 'har', 'qaysi', 'tomonidan', 'yerda', 'keldi', 'edi',
    // Rasmiy-uslub va umumiy grammatik so'zlar (qonun matnida ham,
    // foydalanuvchi so'rovida ham uchraydi — ya'ni yolg'on moslik manbasi).
    'ravishda', 'ravish', 'asosan', 'asosida', 'boshqa', 'shuningdek',
    'hamda', 'yana', 'juda', 'faqat', 'shart', 'lozim', 'kabi', 'orqali',
    'keyin', 'oldin', 'meni', 'mening', 'menga', 'mendan', 'sizni', 'sizga',
    'uning', 'unga', 'bunda', 'buni', 'shu', 'esa', 'bo', 'ushbular',
    'yozishga', 'qanaqa', 'nechta', 'holda', 'holatda', 'bajarmagan',
  };

  static List<String> _extractKeywords(String text) {
    // P1: apostrof (`'`, `\u2019`) SO'Z ICHIDA qoldiriladi. Ilgari regex uni
    // ajratuvchi deb hisoblardi va o'zbek lotin yozuvidagi so'zlar bo'linib
    // ketardi: "bo'shatmoqchi" \u2192 ["bo", "shatmoqchi"]. Natijada `_synonyms`
    // dagi `bo'shat` kaliti HECH QACHON ishlamagan \u2014 ya'ni "ishdan bo'shatish"
    // so'rovlari uchun mehnat sinonimlari (bekor qilish, mehnat shartnomasi)
    // umuman qo'shilmagan. Endi so'z butun holda saqlanadi.
    final words = text
        .toLowerCase()
        .split(RegExp(r"[^a-z0-9_a-zA-Z'\u2019\u0400-\u04FF]+"));
    return words
        .map((w) => w.replaceAll('\u2019', "'"))
        .where((w) => w.length > 2 && !_stopWords.contains(w))
        .toList();
  }

  /// Converts matched chunks to Domain LawArticle entities
  static List<LawArticleChunk> retrieveByDomain(String domain, {int maxResults = 3}) {
    return UzbekLegalKnowledgeBase.verifiedLawChunks
        .where((c) => c.isActive && c.jurisdiction.toLowerCase().contains(domain.toLowerCase()))
        .take(maxResults)
        .toList();
  }

  /// Converts matched chunks to Domain LawArticle entities
  static List<LawArticle> toDomainArticles(List<LawArticleChunk> chunks) {
    return chunks.map((c) => c.toLawArticle()).toList();
  }
}
