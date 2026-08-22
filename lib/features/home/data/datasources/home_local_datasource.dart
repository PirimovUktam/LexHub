import 'package:flutter/material.dart';
import 'package:lexhub/core/constants/app_colors.dart';
import 'package:lexhub/features/home/domain/entities/legal_category.dart';
import 'package:lexhub/features/home/domain/entities/seed_question.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/law_article.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/risk_assessment.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/risk_level.dart';

abstract class HomeLocalDataSource {
  Future<List<LegalCategory>> getCategories();
  Future<List<SeedQuestionModel>> getSeedQuestions({String? categoryId});
  Future<List<SeedQuestionModel>> searchSeedQuestions(String query);
}

class HomeLocalDataSourceImpl implements HomeLocalDataSource {
  static const List<LegalCategory> _categories = [
    LegalCategory(
      id: 'mehnat',
      title: 'Mehnat huquqi',
      description: "Ishdan bo'shatish, ish haqi, mehnat shartnomasi va ta'tillar",
      icon: Icons.work_outline_rounded,
      color: AppColors.primary,
      caseCount: 42,
    ),
    LegalCategory(
      id: 'yhq',
      title: "Yo'l harakati",
      description: "YPX jarimalari, radarlar, haydovchilik huquqlari va YTH",
      icon: Icons.directions_car_rounded,
      color: AppColors.lexBlue,
      caseCount: 38,
    ),
    LegalCategory(
      id: 'oila',
      title: 'Oila huquqi',
      description: "Aliment, nikohdan ajrashish, bolalar ta'minoti va mulk",
      icon: Icons.family_restroom_rounded,
      color: AppColors.crimson,
      caseCount: 56,
    ),
    LegalCategory(
      id: 'jarimalar',
      title: "Ma'muriy jarimalar",
      description: "Bayonnomalar, ma'muriy javobgarlik va shikoyat berish",
      icon: Icons.receipt_long_rounded,
      color: AppColors.amber,
      caseCount: 29,
    ),
    LegalCategory(
      id: 'istemolchi',
      title: "Iste'molchi huquqi",
      description: "Sifatsiz tovar, 10 kunda qaytarish, kafolat va xizmatlar",
      icon: Icons.shopping_bag_outlined,
      color: AppColors.emerald,
      caseCount: 34,
    ),
    LegalCategory(
      id: 'uyjoy',
      title: 'Uy-joy va kadastr',
      description: "Ijara shartnomasi, ro'yxatdan o'tish (propiska) va kadastr",
      icon: Icons.home_work_outlined,
      color: AppColors.indigo,
      caseCount: 27,
    ),
    LegalCategory(
      id: 'soliq',
      title: 'Soliq masalalari',
      description: "Jismoniy va yuridik shaxslar soliqlari, imtiyozlar va deklaratsiya",
      icon: Icons.account_balance_outlined,
      color: AppColors.primaryLight,
      caseCount: 19,
    ),
    LegalCategory(
      id: 'bank',
      title: 'Bank va kredit',
      description: "Kredit shartnomalari, kafillik, foizlar va garov mulki",
      icon: Icons.credit_card_rounded,
      color: AppColors.lexBlueDark,
      caseCount: 23,
    ),
    LegalCategory(
      id: 'meros',
      title: 'Mulk va meros',
      description: "Vasiyatnoma, merosxo'rlik navbati va mulk huquqi",
      icon: Icons.real_estate_agent_outlined,
      color: AppColors.amberDark,
      caseCount: 31,
    ),
    LegalCategory(
      id: 'jinoyat',
      title: 'Jinoyat huquqi',
      description: "Tergov harakatlari, ushlab turish, advokatlik va sud",
      icon: Icons.gavel_rounded,
      color: AppColors.emergency,
      caseCount: 18,
    ),
    LegalCategory(
      id: 'davlat',
      title: 'Davlat xizmatlari',
      description: "my.gov.uz, fuqarolik, pasport va davlat organlari murojaatlari",
      icon: Icons.assured_workload_outlined,
      color: AppColors.emeraldDark,
      caseCount: 22,
    ),
    LegalCategory(
      id: 'sud',
      title: 'Sud masalalari',
      description: "Da'vo muddati, davlat boji, sud buyrug'i va apellyatsiya",
      icon: Icons.balance_rounded,
      color: AppColors.indigoDark,
      caseCount: 25,
    ),
    LegalCategory(
      id: 'biznes',
      title: 'Biznes va shartnomalar',
      description: "MCHJ ochish, kontragent tekshiruvi va shartnoma tuzish",
      icon: Icons.business_center_outlined,
      color: AppColors.primaryDark,
      caseCount: 20,
    ),
  ];

  static const List<SeedQuestionModel> _seedQuestions = [
    SeedQuestionModel(
      id: 'seed_1',
      categoryId: 'mehnat',
      categoryName: 'Mehnat huquqi',
      questionText: "Ish beruvchi xodimni majburan o'z xohishi bilan ariza yozdirib bo'shatishi qonuniymi?",
      relatableSummary: "Yo'q, mutlaqo noqonuniy. Yangi tahrirdagi Mehnat kodeksiga asosan xodimni ariza yozishga majburlash taqiqlanadi. Ish beruvchi tashabbusi bilan bo'shatishda 2 oy oldin yozma ogohlantirish va kompensatsiya talab etiladi.",
      actionableSteps: [
        "Hech qanday holatda 'o'z xohishim bilan' deb ariza yozmang.",
        "Majburlash holati bo'yicha Davlat mehnat inspeksiyasiga (1092) yozma ariza bering.",
        "Buyruq chiqqan kundan boshlab 1 oy ichida fuqarolik sudiga ishga tiklash da'vosini kiriting.",
      ],
      legalBasis: [
        LawArticle(
          lawName: "O'zbekiston Respublikasining Mehnat kodeksi",
          articleNumber: "161-modda",
          articleTitle: "Mehnat shartnomasini ish beruvchi tashabbusi bilan bekor qilish",
          articleText: "Mehnat shartnomasi faqat qonunda qat'iy ko'rsatilgan asoslar mavjud bo'lgandagina bekor qilinishi mumkin.",
          lexUrl: "https://lex.uz/docs/6257288#6262483",
        ),
      ],
      riskAssessment: RiskAssessment(
        level: RiskLevel.medium,
        summary: "Sudga murojaat qilish muddati — 1 oy. O'tkazib yubormaslik shart.",
        limitations: ["Da'vo muddati 30 kun."],
        deadlineDays: 30,
      ),
    ),
    SeedQuestionModel(
      id: 'seed_2',
      categoryId: 'istemolchi',
      categoryName: "Iste'molchi huquqi",
      questionText: "Xarid qilingan sifatli yoki nuqsonli kiyimni do'konga 10 kun ichida qaytarib pulni olsa bo'ladimi?",
      relatableSummary: "Ha, qonun bo'yicha iste'molchi kiyilmagan, yorlig'i saqlangan nooziq-ovqat tovarini 10 kun ichida boshqasiga almashtirish yoki pulni to'liq qaytarib olish huquqiga ega.",
      actionableSteps: [
        "Tovar cheki va kiyim yorliqlarini saqlangan holda do'konga boring.",
        "Do'kon qabul qilmasa, 2 nusxada yozma da'vo arizasi (pretenziya) topshiring.",
        "Iste'molchilar huquqlarini himoya qilish agentligining 1159 raqamiga xabar bering.",
      ],
      legalBasis: [
        LawArticle(
          lawName: "Iste'molchilarning huquqlarini himoya qilish to'g'risidagi Qonun",
          articleNumber: "18-modda",
          articleTitle: "Maqbul sifatli tovarni almashtirish huquqi",
          articleText: "Iste'molchi maqbul sifatli nooziq-ovqat tovarini xarid qilgan kundan e'tiboran 10 kun ichida almashtirishga haqlidir.",
          lexUrl: "https://lex.uz/docs/440",
        ),
      ],
      riskAssessment: RiskAssessment(
        level: RiskLevel.low,
        summary: "Tovar cheki mavjud bo'lsa, pulni qaytarib olish ehtimoli 95% dan yuqori.",
        deadlineDays: 10,
      ),
    ),
    SeedQuestionModel(
      id: 'seed_3',
      categoryId: 'oila',
      categoryName: 'Oila huquqi',
      questionText: "Ota rasman hech qayerda ishlamasa, 2 nafar farzand uchun aliment qanday hisoblanadi?",
      relatableSummary: "Agar ota rasman ishlamasa yoki daromadini yashirsa, aliment O'zbekiston Respublikasidagi o'rtacha oylik ish haqi miqdoridan kelib chiqib hisoblanadi (2 bola uchun daromadning 1/3 qismi).",
      actionableSteps: [
        "Fuqarolik ishlari bo'yicha tumanlararo sudga 'Sud buyrug'i chiqarish to'g'risida' ariza topshiring.",
        "Arizaga farzandlarning tug'ilganlik guvohnomalari nusxalarini ilova qiling.",
        "Sud buyrug'ini MIB bo'limiga ijroga topshiring.",
      ],
      legalBasis: [
        LawArticle(
          lawName: "O'zbekiston Respublikasining Oila kodeksi",
          articleNumber: "99-modda",
          articleTitle: "Voyaga yetmagan bolalarga suddan undiriladigan aliment miqdori",
          articleText: "Aliment ikki bola uchun ota-ona daromadining uchdan bir qismi miqdorida undiriladi.",
          lexUrl: "https://lex.uz/docs/104720#107412",
        ),
      ],
      riskAssessment: RiskAssessment(
        level: RiskLevel.low,
        summary: "Sud buyrug'i 3 kunda davlat bojisiz chiqariladi.",
      ),
    ),
    SeedQuestionModel(
      id: 'seed_4',
      categoryId: 'yhq',
      categoryName: "Yo'l harakati",
      questionText: "Radar orqali asossiz yuborilgan jarima qarori ustidan qancha vaqtda va qayerga shikoyat qilinadi?",
      relatableSummary: "Ma'muriy jarima qarori ustidan qaror nusxasi olingan kundan boshlab 10 kun ichida YHQ yuqori organiga yoki Ma'muriy sudga shikoyat arizasi berilishi lozim.",
      actionableSteps: [
        "Foto/videoradar suratidagi xatoliklarni (raqam noaniqligi, belgi yo'qligi) qayd eting.",
        "10 kunlik muddatni o'tkazmasdan my.gov.uz yoki YHXX portaliga elektron shikoyat yuboring.",
        "Natija bo'lmasa, tuman Ma'muriy sudiga ariza kiriting.",
      ],
      legalBasis: [
        LawArticle(
          lawName: "Ma'muriy javobgarlik to'g'risidagi kodeks",
          articleNumber: "315-modda",
          articleTitle: "Ma'muriy huquqbuzarlik to'g'risidagi ish yuzasidan chiqarilgan qaror ustidan shikoyat berish muddati",
          articleText: "Qaror ustidan shikoyat qaror nusxasi topshirilgan kundan e'tiboran o'n kun ichida berilishi mumkin.",
          lexUrl: "https://lex.uz/docs/97661#101569",
        ),
      ],
      riskAssessment: RiskAssessment(
        level: RiskLevel.medium,
        summary: "10 kunlik shikoyat muddatini o'tkazib yubormaslik shart.",
        deadlineDays: 10,
      ),
    ),
    SeedQuestionModel(
      id: 'seed_5',
      categoryId: 'bank',
      categoryName: 'Bank va kredit',
      questionText: "Tanishimga kafil (poruchitel) bo'lgan edim, u kreditni to'lamasa mendan majburiy undirishlari mumkinmi?",
      relatableSummary: "Ha, agar kafil sifatida birgalikdagi (solidar) javobgarlik shartnomasini imzolagan bo'lsangiz, bank asosiy qarzdor bilan bir qatorda sizning hisobingizdan ham qarzni undirishga haqli.",
      actionableSteps: [
        "Kafillik shartnomasi shartlarini va javobgarlik muddatini o'rganing.",
        "Qarz to'langach, siz to'lagan barcha summani asosiy qarzdordan sud orqali regress tartibida undirib olish huquqiga egasiz.",
      ],
      legalBasis: [
        LawArticle(
          lawName: "O'zbekiston Respublikasining Fuqarolik kodeksi",
          articleNumber: "293-modda",
          articleTitle: "Kafilning javobgarligi",
          articleText: "Qarzdor majburiyatni bajarmagan taqdirda kafil va qarzdor kreditor oldida solidar javob beradilar.",
          lexUrl: "https://lex.uz/docs/111189#153282",
        ),
      ],
      riskAssessment: RiskAssessment(
        level: RiskLevel.high,
        summary: "Kafillik bo'yicha bank hisoblari va ish haqiga taqiq qo'yilishi mumkin.",
        requiresLawyer: true,
      ),
    ),
    SeedQuestionModel(
      id: 'seed_6',
      categoryId: 'uyjoy',
      categoryName: 'Uy-joy va kadastr',
      questionText: "Ijara shartnomasisiz ijarada yashayotgan fuqaroni uy egasi bir kunda ko'chaga chiqarib yuborishi mumkinmi?",
      relatableSummary: "Uy egasining o'zboshimchalik bilan buyumlarni ko'chaga tashlashi noqonuniy. Fuqarolik qonunchiligiga ko'ra, har qanday nizoli ko'chirish faqat sud tartibida amalga oshiriladi.",
      actionableSteps: [
        "E-ijara tizimi (ijara.soliq.uz) orqali shartnomani rasmiylashtirishni talab qiling.",
        "Noqonuniy ko'chirish yoki tahdid bo'lsa, profilaktika inspektoriga (102) murojaat qiling.",
      ],
      legalBasis: [
        LawArticle(
          lawName: "O'zbekiston Respublikasining Uy-joy kodeksi",
          articleNumber: "86-modda",
          articleTitle: "Fuqarolarni turar joydan ko'chirish tartibi",
          articleText: "Fuqarolarni turar joydan ko'chirishga faqat sud qaroriga binoan yo'l qo'yiladi.",
          lexUrl: "https://lex.uz/docs/106134",
        ),
      ],
      riskAssessment: RiskAssessment(
        level: RiskLevel.medium,
        summary: "Yozma ijara shartnomasi bo'lishi har ikki taraf uchun himoya hisoblanadi.",
      ),
    ),
  ];

  @override
  Future<List<LegalCategory>> getCategories() async {
    return _categories;
  }

  @override
  Future<List<SeedQuestionModel>> getSeedQuestions({String? categoryId}) async {
    if (categoryId == null || categoryId.isEmpty) {
      return _seedQuestions;
    }
    return _seedQuestions.where((q) => q.categoryId == categoryId).toList();
  }

  @override
  Future<List<SeedQuestionModel>> searchSeedQuestions(String query) async {
    final lower = query.toLowerCase().trim();
    if (lower.isEmpty) return _seedQuestions;

    return _seedQuestions.where((q) {
      return q.questionText.toLowerCase().contains(lower) ||
          q.categoryName.toLowerCase().contains(lower) ||
          q.relatableSummary.toLowerCase().contains(lower);
    }).toList();
  }
}
