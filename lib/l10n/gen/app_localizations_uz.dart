// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Uzbek (`uz`).
class AppL10nUz extends AppL10n {
  AppL10nUz([String locale = 'uz']) : super(locale);

  @override
  String get appName => 'LexHub';

  @override
  String get appTagline => 'O\'zbekiston fuqarolari uchun huquqiy ekotizim';

  @override
  String get appLegalPlatform => 'O\'zbekiston Huquqiy Platformasi';

  @override
  String get legalDisclaimer =>
      'Diqqat: LexHub yakuniy sud hukmi yoki litsenziyaga ega advokat o\'rnini bosmaydi. Tizim holatni tushunish va qonuniy yo\'lni aniqlashga ko\'maklashadi.';

  @override
  String get legalSourceLlm => 'Server AI modeli tahlili';

  @override
  String get legalSourceDeterministic =>
      'AI EMAS: qurilmadagi tekshirilgan qonun bazasi asosida';

  @override
  String get actionRetry => 'Qaytadan urinish';

  @override
  String get actionCancel => 'Bekor qilish';

  @override
  String get actionClose => 'Yopish';

  @override
  String get actionSend => 'Yuborish';

  @override
  String get actionSave => 'Saqlash';

  @override
  String get actionCopy => 'Nusxalash';

  @override
  String get actionCopied => 'Nusxalandi';

  @override
  String get actionContinue => 'Davom etish';

  @override
  String get actionOk => 'Tushunarli';

  @override
  String get actionSearch => 'Qidirish';

  @override
  String get actionShare => 'Ulashish';

  @override
  String get actionDelete => 'O\'chirish';

  @override
  String get actionOpen => 'Ochish';

  @override
  String get actionSeeAll => 'Barchasi';

  @override
  String get loadingLabel => 'Yuklanmoqda...';

  @override
  String get navHome => 'Bosh sahifa';

  @override
  String get navAI => 'Maslahat';

  @override
  String get navCommunity => 'Hamjamiyat';

  @override
  String get navServices => 'Xizmatlar';

  @override
  String get navExperts => 'Advokatlar';

  @override
  String get navCabinet => 'Kabinet';

  @override
  String get authLoginTitle => 'Tizimga kirish';

  @override
  String get authRegisterTitle => 'Ro\'yxatdan o\'tish';

  @override
  String get authRegisterSubtitle =>
      'LexHub orqali yuridik xizmatlar va jamoat forumidan to\'liq foydalaning';

  @override
  String get authFieldFullName => 'To\'liq ism-sharifingiz';

  @override
  String get authHintFullName => 'Bobur Mirzayev';

  @override
  String get authFieldEmail => 'Email pochta';

  @override
  String get authHintEmail => 'misol@domain.uz';

  @override
  String get authFieldPassword => 'Maxfiy parol';

  @override
  String get authFieldCreatePassword => 'Parol yaratish';

  @override
  String get authHintPassword => 'Parolni kiriting';

  @override
  String get authHintMinSixChars => 'Kamida 6 ta belgi';

  @override
  String get authFieldConfirmPassword => 'Parolni tasdiqlang';

  @override
  String get authHintConfirmPassword => 'Parolni qayta kiriting';

  @override
  String get authHaveAccount => 'Hisobingiz bormi? ';

  @override
  String get authNoAccount => 'Hisobingiz yo\'qmi? ';

  @override
  String get authGoToLogin => 'Kirish';

  @override
  String get authGoToRegister => 'Ro\'yxatdan o\'ting';

  @override
  String get authContinueAsGuest => 'Mehmon sifatida davom etish';

  @override
  String get authSignOut => 'Tizimdan chiqish';

  @override
  String get authLoginOrRegister => 'Tizimga kirish / Ro\'yxatdan o\'tish';

  @override
  String get authSignedOutTitle => 'Hisobingizga kiring';

  @override
  String get authSignedOutSubtitle =>
      'Savol berish, javoblarni baholash va advokatlar bilan maslahatlashish uchun tizimga kiring';

  @override
  String get authDefaultUserName => 'Foydalanuvchi';

  @override
  String get authEmailConfirmTitle => 'Email manzilingizni tasdiqlang';

  @override
  String get authEmailConfirmBody =>
      'Hisobingiz yaratildi. Tizimga kirish uchun pochtangizga yuborilgan tasdiqlash havolasini bosing.';

  @override
  String get authEmailConfirmHint =>
      'Xat ko\'rinmasa \"Spam\" papkasini ham tekshirib ko\'ring.';

  @override
  String get validationNameRequired => 'Ism-sharifingizni kiriting';

  @override
  String get validationNameTooShort => 'Ism juda qisqa';

  @override
  String get validationEmailRequired => 'Email manzilini kiriting';

  @override
  String get validationEmailInvalid => 'To\'g\'ri email formatini kiriting';

  @override
  String get validationPasswordRequired => 'Parolni kiriting';

  @override
  String get validationPasswordTooShort =>
      'Parol kamida 6 belgidan iborat bo\'lishi kerak';

  @override
  String get validationConfirmPasswordRequired => 'Parolni tasdiqlang';

  @override
  String get validationPasswordsMismatch =>
      'Kiritilgan parollar bir-biriga mos kelmadi';

  @override
  String get profileSecurityTitle => 'Xavfsizlik & RLS himoyasi';

  @override
  String get profileSecuritySubtitle => 'PostgreSQL Row Level Security faol';

  @override
  String profileReputationPoints(int points) {
    return '$points ball';
  }

  @override
  String get roleCitizen => 'Fuqaro';

  @override
  String get roleLawyer => 'Yurist / Advokat';

  @override
  String get roleVerifiedExpert => 'Verifikatsiyalangan ekspert';

  @override
  String get roleModerator => 'Moderator';

  @override
  String get roleAdmin => 'Administrator';

  @override
  String get settingsTitle => 'Sozlamalar';

  @override
  String get settingsLanguageTile => 'Ilova tili';

  @override
  String get settingsLanguageSubtitle => 'Interfeys tilini tanlang';

  @override
  String get languagePageTitle => 'Til';

  @override
  String get languagePageSubtitle =>
      'Tanlangan til butun ilovaga qo\'llanadi va ilova qayta ochilganda ham saqlanadi.';

  @override
  String get languageSaveFailed =>
      'Tilni saqlab bo\'lmadi. Qaytadan urinib ko\'ring.';

  @override
  String languageChangedTo(String language) {
    return 'Til o\'zgartirildi: $language';
  }

  @override
  String get categoryAll => 'Barchasi';

  @override
  String get categoryLabor => 'Mehnat huquqi';

  @override
  String get categoryFamily => 'Oila huquqi';

  @override
  String get categoryCivil => 'Fuqarolik huquqi';

  @override
  String get categoryCriminal => 'Jinoyat huquqi';

  @override
  String get categoryAdministrative => 'Ma\'muriy huquqi';

  @override
  String get categoryGeneral => 'Umumiy';

  @override
  String get communityTitle => 'Fuqarolar va Advokatlar minbari';

  @override
  String get communityAskTooltip => 'Hamjamiyatga savol berish';

  @override
  String get communityAskCta => 'Savol berish';

  @override
  String get communityEmptyInCategory =>
      'Ushbu kategoriyada savollar topilmadi';

  @override
  String communityAnswersCount(int count) {
    return '$count ta javob';
  }

  @override
  String get communityAiAnalysis => 'Huquqiy tahlil';

  @override
  String get communityAiSummaryLabel =>
      'Kategoriya bo\'yicha avtomatik eslatma:';

  @override
  String get communityExpertAnswerBadge => 'Advokat javobi bor';

  @override
  String get communityAnonymousBadge => 'Maxfiy (Anonim)';

  @override
  String get communityAnonymousShort => 'Anonim';

  @override
  String get communityAnonymousAuthor => 'Anonim fuqaro';

  @override
  String get communityPiiNotice =>
      'Shaxsiy ma\'lumotlar (telefon, pasport, karta) avtomatik yashiriladi';

  @override
  String get askDialogTitle => 'Hamjamiyatga savol berish';

  @override
  String get askDialogPrivacyGuard =>
      'Privacy Guard: telefon, pasport va karta raqamlari avtomatik yashiriladi';

  @override
  String get askDialogCategoryField => 'Kategoriya';

  @override
  String get askDialogTitleField => 'Savol sarlavhasi (qisqacha)';

  @override
  String get askDialogTitleHint =>
      'Masalan: Dam olish kunida majburiy ishlash...';

  @override
  String get askDialogBodyField => 'Batafsil ma\'lumot';

  @override
  String get askDialogBodyHint => 'Yuridik muammoingizni erkin bayon qiling...';

  @override
  String get askDialogAnonymousToggle => 'Anonim tarzda e\'lon qilish';

  @override
  String get askDialogAnonymousSubtitle =>
      'Ismingiz o\'rniga \'Anonim fuqaro\' ko\'rsatiladi';

  @override
  String get askDialogPiiDetected =>
      'Maxfiy ma\'lumotlar aniqlandi va yashirildi:';

  @override
  String get askDialogPublishAnonymously => 'Anonim tarzda chop etish';

  @override
  String get askDialogPublish => 'Savolni chop etish';

  @override
  String get askDialogEmptyBody => 'Iltimos, savol matnini kiriting';

  @override
  String get authRequiredTitle => 'Tizimga kirish talab etiladi';

  @override
  String authRequiredMessage(String action) {
    return '$action uchun avval tizimga kiring yoki yangi hisob oching.';
  }

  @override
  String get authActionAskQuestion => 'Savol berish';

  @override
  String get authActionWriteAnswer => 'Javob yozish';

  @override
  String get authActionVote => 'Ovoz berish';

  @override
  String get authActionAcceptAnswer => 'Javobni qabul qilish';

  @override
  String get questionDetailTitle => 'Savol tafsilotlari';

  @override
  String get questionDetailAiSummary =>
      'Kategoriya bo\'yicha avtomatik eslatma';

  @override
  String questionDetailAnswersSection(int count) {
    return 'Javoblar va maslahatlar ($count)';
  }

  @override
  String get questionDetailEmptyAnswers =>
      'Hali hech kim javob yozmadi.\nBirinchi bo\'lib o\'z tajribangiz yoki yuridik fikringizni bildiring!';

  @override
  String get answerAsLawyerChip => 'Advokat sifatida javob berish';

  @override
  String get answerInputHint => 'Fikr yoki qonuniy maslahat yozing...';

  @override
  String get answerSubmitSuccess =>
      'Javobingiz muvaffaqiyatli saqlandi va e\'lon qilindi!';

  @override
  String get answerSubmitDemoted =>
      'Javob saqlandi, lekin ODDIY javob sifatida: ekspert javobi uchun profilingiz tasdiqlanmagan.';

  @override
  String get answerAcceptSuccess =>
      'Javob foydali (hal qilingan) deb belgilandi!';

  @override
  String get answerAcceptedBadge => 'Foydali deb qabul qilingan';

  @override
  String get answerAcceptAction => 'Qabul qilish';

  @override
  String get answerRoleCommunityMember => 'Jamoat a\'zosi';

  @override
  String get answerRoleLicensedLawyer => 'Litsenziyaga ega advokat';

  @override
  String get homeGreeting => 'Assalomu alaykum';

  @override
  String get homeQueryHint => 'Muammongizni oddiy tilda yozing...';

  @override
  String get homeAiAnalyzeButton => 'Qidirish';

  @override
  String get homeServicesBannerTitle => 'Davlat xizmatlari va Jarayoni';

  @override
  String get homeServicesBannerSubtitle =>
      'my.gov.uz yo\'riqnomalari, to\'lovlar va rasmiy muddatlar';

  @override
  String get homeTopicMatters => 'Mavzuga oid masalalar';

  @override
  String get homeCommunityQuestions => 'Hamjamiyat Savollari';

  @override
  String get homePrivacyGuardBadge =>
      'Savolni ismingizni ko\'rsatmasdan yo\'llash mumkin';

  @override
  String get homeAskBannerTitle => 'Sizda ham huquqiy savol bormi?';

  @override
  String get homeAskBannerSubtitle =>
      'Shaxsiy ma\'lumotlaringiz yashirilgan holda savol yo\'llang';

  @override
  String homeCategoriesTitle(int count) {
    return 'Huquqiy Kategoriyalar ($count)';
  }

  @override
  String get homeHeroTitle => 'Huquqingizni biling, huquqingizni himoya qiling';

  @override
  String get homeHeroSubtitle => 'Bilim — eng yaxshi himoya';

  @override
  String get homeQuickAccessTitle => 'Tezkor kirish';

  @override
  String get homeQuickMore => 'Ko\'proq';

  @override
  String get homeQuickDocuments => 'Hujjatlar';

  @override
  String get homeQuickSaved => 'Saqlanganlar';

  @override
  String get homeQuickEmergency => 'Tezkor yordam';

  @override
  String get homeRecommendedTitle => 'Siz uchun tavsiya etamiz';

  @override
  String get communityNewBadge => 'Yangi';

  @override
  String get homeCommunityEmpty =>
      'Hamjamiyatda hali savol yo\'q — birinchi bo\'lib so\'rang';

  @override
  String get emergencyQuickTitle => 'Tezkor Huquqiy Himoya';

  @override
  String get emergencyQuickSubtitle =>
      'Hibs, tintuv, so\'roq va 102/1002 ishonch raqamlari';

  @override
  String get faqBannerTitle => 'Ko\'p beriladigan savollar';

  @override
  String get faqBannerBadge => 'TOP 20+';

  @override
  String get faqBannerSubtitle =>
      'Eng ommabop yuridik keyslar va tayyor yechimlar';

  @override
  String get cabinetTitle => 'Shaxsiy Kabinet';

  @override
  String get cabinetTabProfile => 'Profil';

  @override
  String get cabinetTabConsultations => 'Konsultatsiyalar';

  @override
  String get cabinetTabBuilder => 'Konstruktor';

  @override
  String get cabinetTabOfflineCases => 'Oflayn Keyslar';

  @override
  String get recentCasesTitle => 'Mening so\'nggi murojaatlarim';

  @override
  String recentCasesSeeAll(int count) {
    return 'Barchasi ($count)';
  }

  @override
  String legalBasisCount(int count) {
    return '$count ta Lex.uz moddasi';
  }

  @override
  String get actionRead => 'O\'qish';

  @override
  String get recentCaseDetailTitle => 'Murojaat Tahlili';

  @override
  String get trendingTitle => 'Ko\'p beriladigan yuridik savollar';

  @override
  String get trendingEmptyInCategory =>
      'Ushbu kategoriya bo\'yicha savollar topilmadi';

  @override
  String casesCount(int count) {
    return '$count ta keys';
  }

  @override
  String get actionReadAnalysis => 'Tahlilni o\'qish';

  @override
  String get faqAskAiAction => 'Ushbu masala bo\'yicha huquqiy tahlil olish';

  @override
  String get faqSearchHint =>
      'Savollarni qidirish (masalan: aliment, jarima)...';

  @override
  String faqLegalCasesCount(int count) {
    return '$count ta yuridik keys';
  }

  @override
  String get faqWithLexUz => 'Lex.uz moddalari bilan';

  @override
  String get faqNoMatches => 'Mos keluvchi savollar topilmadi';

  @override
  String get faqNoMatchesHint =>
      'Boshqa kalit so\'z yoki toifani tanlab ko\'ring';

  @override
  String get emergencyRightsTitle => 'Tezkor Huquqlar';

  @override
  String emergencyCallFailed(String phone) {
    return 'Qo\'ng\'iroq qilib bo\'lmadi: $phone';
  }

  @override
  String get emergencyHotlinesTitle => 'Tezkor Ishonch Telefonlari';

  @override
  String get emergencyProtocolsTitle =>
      'Favqulodda Huquqiy Himoya Protokollari';

  @override
  String get hotlineProsecutor => 'Bosh Prokuratura';

  @override
  String get hotlineInterior => 'Ichki Ishlar (IIV)';

  @override
  String get hotlineOmbudsman => 'Ombudsman';

  @override
  String get hotlineLaborInspection => 'Mehnat Inspeksiyasi';

  @override
  String get savedCasesTitle => 'Saqlangan keyslar';

  @override
  String get savedCasesEmptyTitle => 'Saqlangan keyslar mavjud emas';

  @override
  String get savedCasesEmptyBody =>
      'Yuridik maslahatlarni saqlab qo\'yish orqali ularni internetsiz, istalgan vaqtda qayta ko\'rishingiz mumkin.';

  @override
  String savedCaseQuestionQuoted(String query) {
    return 'Savol: \"$query\"';
  }

  @override
  String get actionViewDetails => 'Batafsil ko\'rish';

  @override
  String get savedCaseDetailTitle => 'Saqlangan Yuridik Keys';

  @override
  String get homeCatTraffic => 'Yo\'l harakati';

  @override
  String get homeCatAdminFines => 'Ma\'muriy jarimalar';

  @override
  String get homeCatConsumer => 'Iste\'molchi huquqi';

  @override
  String get homeCatHousing => 'Uy-joy va kadastr';

  @override
  String get homeCatTax => 'Soliq masalalari';

  @override
  String get homeCatBanking => 'Bank va kredit';

  @override
  String get homeCatInheritance => 'Mulk va meros';

  @override
  String get homeCatGovServices => 'Davlat xizmatlari';

  @override
  String get homeCatCourt => 'Sud masalalari';

  @override
  String get homeCatBusiness => 'Biznes va shartnomalar';

  @override
  String get aiAnalystSubtitle => 'O\'zbekiston huquqiy tahlilchisi';

  @override
  String get aiWriteSituationTitle => 'Huquqiy vaziyatingizni yozing';

  @override
  String get aiQueryHint =>
      'Vaziyatingizni batafsil yozing (masalan: \'Menga radar jarimasi keldi, 2 kundan keyin yana jarima yozildi...\')...';

  @override
  String get aiGetAdviceButton => 'Huquqiy tahlil olish';

  @override
  String get aiAnalyzingLexUz => 'Lex.uz moddalari tahlil qilinmoqda...';

  @override
  String get aiCommonSituations => 'Ko\'p uchraydigan huquqiy vaziyatlar';

  @override
  String get aiFullAnalysisCopied => 'To\'liq huquqiy tahlil nusxalandi!';

  @override
  String get aiBuildDocumentAction => 'Ariza shakllantirish';

  @override
  String get aiQueryEmptyError =>
      'Iltimos, huquqiy savol yoki vaziyatingizni yozing.';

  @override
  String get actionCopyAnalysis => 'Tahlilni nusxalash';

  @override
  String get aiChipUnfairDismissal => 'Ishdan nohaq bo\'shatish';

  @override
  String get aiChipConsumerReturn => 'Iste\'molchi huquqi (tovarni qaytarish)';

  @override
  String get aiChipAlimony => 'Aliment undirish';

  @override
  String get aiChipTrafficFine => 'Yo\'l harakati jarimasi';

  @override
  String get aiChipDebtReceipt => 'Qarz va tilxat';

  @override
  String get aiSummaryTitle => 'Oddiy tilda tushuntirish (Xulosa)';

  @override
  String get aiStepsTitle => 'Bosqichma-bosqich harakatlar';

  @override
  String get aiLegalBasisTitle => 'Qonuniy asoslar (Lex.uz)';

  @override
  String get aiLegalBasisNoneTitle => 'Mos keladigan modda topilmadi';

  @override
  String get aiLegalBasisNoneBody =>
      'Tasdiqlangan bazamizda ushbu savolga aniq mos keladigan qonun moddasi topilmadi. Quyidagi tahlil UMUMIY xarakterda va qonuniy asos sifatida ishlatilmasligi kerak. Aniq modda kerak bo\'lsa, Lex.uz saytiga yoki yurist maslahatiga murojaat qiling.';

  @override
  String get aiRiskTitle => 'Risk va Muddatlar tahlili';

  @override
  String get aiEmergencyAlertTitle => 'DIQQAT: Favqulodda Huquqiy Xavf';

  @override
  String get aiClarificationTitle =>
      'Aniqroq maslahat uchun qo\'shimcha savollar';

  @override
  String get aiClarificationBody =>
      'Vaziyatingizga yanada aniq va to\'g\'ri qonuniy maslahat berish uchun quyidagi tafsilotlarni kiritish tavsiya etiladi:';

  @override
  String get aiSummarySubtitle => 'Yuridik jargonsiz sodda tushuntirish';

  @override
  String get aiAudioStarted => 'Audio eshittirish boshlandi (Ovozli tahlil)...';

  @override
  String get aiAudioStopped => 'Audio to\'xtatildi';

  @override
  String get aiSummaryCopied => 'Xulosa matni nusxalandi!';

  @override
  String get actionListenAudio => 'Ovozli tinglash';

  @override
  String aiStepsProgress(int done, int total) {
    return '$total tadan $done tasi bajarildi';
  }

  @override
  String get aiLexUzBaseSubtitle => 'Lex.uz rasmiy qonunchilik bazasi';

  @override
  String get aiOfficialDocsSubtitle => 'Rasmiy qonunchilik hujjatlari';

  @override
  String get aiLexUzOpenFailed => 'Lex.uz havolasini ochib bo\'lmadi';

  @override
  String aiArticleCopied(String article) {
    return '$article matni nusxalandi!';
  }

  @override
  String get statusInForce => 'Amalda';

  @override
  String get actionOpenLexUz => 'Lex.uz\'da to\'liq o\'qish';

  @override
  String get aiRiskSubtitle => 'Xolis huquqiy tahlil & cheklovlar';

  @override
  String get aiRiskGaugeLabel => 'Xavf darajasi ko\'rsatkichi';

  @override
  String get riskScaleLow => 'Past xavf';

  @override
  String get riskScaleMedium => 'O\'rtacha';

  @override
  String get riskScaleHigh => 'Yuqori';

  @override
  String get riskScaleCritical => 'Kritik';

  @override
  String aiDeadlineRemaining(int days) {
    return 'Murojaat qilish uchun qolgan taxminiy muddat: $days kun';
  }

  @override
  String get aiLimitationsTitle => 'Muhim cheklovlar va ogohlantirishlar:';

  @override
  String get aiLawyerRequiredWarning =>
      'Ushbu ish bo\'yicha mustaqil harakat qilish yutqazish xavfini oshiradi. Malakali advokat bilan shartnoma tuzish tavsiya etiladi.';

  @override
  String get aiLawyerRecommendedWarning =>
      'Ushbu holatda mustaqil harakat qilish xavfli. Malakali advokat bilan maslahatlashish tavsiya etiladi.';

  @override
  String get aiLawyerEscalationTitle =>
      'Keyingi qadam: advokat bilan davom ettirish';

  @override
  String get aiLawyerEscalationAction => 'Tasdiqlangan advokatni ko\'rish';

  @override
  String aiLawyerEscalationMatched(String area) {
    return 'Mos yo\'nalish: $area';
  }

  @override
  String get aiLawyerEscalationNoMatch =>
      'Yo\'nalish avtomatik aniqlanmadi — ro\'yxatdan o\'zingiz tanlaysiz.';

  @override
  String get aiLawyerEscalationMandatory =>
      'Bu toifadagi ishda litsenziyaga ega advokat MAJBURIY.';

  @override
  String get aiDocumentPickTemplate =>
      'Bu javob uchun aniq hujjat shabloni tanlanmadi. Ro\'yxatdan o\'zingizga mosini tanlang.';

  @override
  String get aiDocumentLoadFailed =>
      'Hujjat shablonlarini yuklab bo\'lmadi. Qaytadan urinib ko\'ring.';

  @override
  String get riskLevelLow => 'Past xavf';

  @override
  String get riskLevelMedium => 'O\'rtacha xavf';

  @override
  String get riskLevelHigh => 'Yuqori xavf';

  @override
  String get riskLevelCritical => 'Kritik xavf (Favqulodda)';

  @override
  String get emergencyRedFlagsTitle => 'Xavfli holatlar (Red Flags):';

  @override
  String get emergencyConstitutionalRightsTitle =>
      'Konstitutsiyaviy huquqlaringiz:';

  @override
  String get emergencyImmediateActionsTitle =>
      'Zudlik bilan nima qilish kerak:';

  @override
  String get emergencyMirandaTitle => 'Miranda Qoidasi';

  @override
  String get emergencyMirandaArticleLabel =>
      'O\'zbekiston Respublikasi Konstitutsiyasi 28-moddasi:';

  @override
  String get emergencyMirandaScriptLabel =>
      'Tergovchi yoki xodimga aytiladigan rasmiy so\'z:';

  @override
  String get emergencyMirandaLawQuote =>
      '\"Ushlab turish chog\'ida shaxsga uning huquqlari va ushlab turilishi asoslari tushunarli tilda tushuntirilishi shart.\"';

  @override
  String get emergencyMirandaScriptText =>
      '\"Men O\'zbekiston Konstitutsiyasining 28 va 29-moddalariga asosan, advokatim yetib kelmaguncha har qanday ko\'rsatma berishdan bosh tortaman va sukut saqlash huquqimdan foydalanaman.\"';

  @override
  String emergencyCallAction(String phone) {
    return 'Qo\'ng\'iroq ($phone)';
  }

  @override
  String get actionCallHotline => 'Ishonch telefoniga qo\'ng\'iroq qilish';

  @override
  String get searchHint => 'Qonun, advokat, xizmat yoki shablon...';

  @override
  String get searchError => 'Qidiruvda xatolik yuz berdi';

  @override
  String get searchRecentTitle => 'So\'nggi qidiruvlar';

  @override
  String get actionClear => 'Tozalash';

  @override
  String get searchPopularTitle => 'Ommabop huquqiy mavzular';

  @override
  String get searchFilterLaws => 'Qonunlar';

  @override
  String get searchFilterTemplates => 'Shablonlar';

  @override
  String get searchTopicAlimonyTitle => 'Aliment undirish tartibi';

  @override
  String get searchTopicAlimonySubtitle =>
      'Oila kodeksi 96-moddasi va sud buyrug\'i arizasi';

  @override
  String get searchTopicDismissalTitle => 'Noqonuniy ishdan bo\'shatish';

  @override
  String get searchTopicDismissalSubtitle =>
      'Mehnat kodeksi kafolatlari va tiklash da\'vosi';

  @override
  String get searchTopicRefundTitle => 'Sifatsiz tovar pulini qaytarish';

  @override
  String get searchTopicRefundSubtitle =>
      'Iste\'molchilar huquqlarini himoya qilish qonuni';

  @override
  String get searchTopicFineTitle =>
      'Yo\'l harakati jarimalari ustidan shikoyat';

  @override
  String get searchTopicFineSubtitle =>
      'YPX qarorlari ustidan apellyatsiya berish';

  @override
  String get searchBadgeLaw => 'Qonun hujjati';

  @override
  String get searchBadgeService => 'Davlat xizmati';

  @override
  String get searchBadgeTemplate => 'Hujjat shabloni';

  @override
  String get searchBadgeQuestion => 'Hamjamiyat forumi';

  @override
  String get searchLexUzBadge => 'Lex.uz ↗';

  @override
  String get searchBuilderBadge => 'Konstruktor ⚡';

  @override
  String get searchOfficialLawyer => 'Rasmiy yurist';

  @override
  String get statusFree => 'Bepul';

  @override
  String searchCostBhmPercent(String percent) {
    return '$percent% BHM';
  }

  @override
  String searchTemplateAuthority(String authority) {
    return 'Organ: $authority';
  }

  @override
  String get searchEmptyTitle => 'Hech qanday natija topilmadi';

  @override
  String get searchEmptyBody =>
      'Boshqa kalit so\'zlar bilan qidirib ko\'ring yoki boshqa toifa filtrini tanlang.';

  @override
  String get actionReload => 'Qayta yuklash';

  @override
  String get actionSaved => 'Saqlandi';

  @override
  String get actionViewOnLexUz => 'Lex.uz da ko\'rish';

  @override
  String get badgePopular => 'Mashhur';

  @override
  String get errorCannotOpenLink => 'Havolani ochib bo\'lmadi';

  @override
  String get categorySocialProtection => 'Ijtimoiy himoya';

  @override
  String get servicesTitle => 'Davlat xizmatlari va Qo\'llanmalar';

  @override
  String get servicesSearchHint =>
      'Davlat xizmatlari yoki qo\'llanmalarni qidirish...';

  @override
  String get servicesEmptyTitle => 'Xizmatlar topilmadi';

  @override
  String serviceDaysShort(int days) {
    return '$days kun';
  }

  @override
  String get serviceGuideTitle => 'Xizmat qo\'llanmasi';

  @override
  String get serviceFreeBadge => 'Bepul xizmat';

  @override
  String serviceCostBhm(String amount) {
    return '$amount BHM';
  }

  @override
  String get serviceVerifiedByLaw =>
      'O\'zbekiston Qonunchiligi asosida tasdiqlangan';

  @override
  String serviceLastVerified(int year, int month) {
    return 'Oxirgi tekshiruv: $year-yil $month-oy';
  }

  @override
  String get serviceLawUpdateActive => 'Qonunchilik yangilanishi: Faol';

  @override
  String get serviceProcessingTime => 'Ko\'rib chiqish muddati';

  @override
  String serviceWorkDays(int days) {
    return '$days ish kuni';
  }

  @override
  String get serviceFeeLabel => 'Davlat boji / To\'lov';

  @override
  String get serviceNoFee => 'To\'lovsiz';

  @override
  String get serviceDescriptionTitle => 'Tavsif va Maqsad';

  @override
  String get serviceLegalBasisTitle => 'Rasmiy Huquqiy Asos';

  @override
  String get serviceRequiredDocsTitle => 'Kerakli hujjatlar';

  @override
  String get serviceStepsTitle => 'Bosqichma-bosqich harakatlar';

  @override
  String get serviceStepOnline => 'Onlayn';

  @override
  String get serviceStepPayment => 'To\'lov';

  @override
  String get serviceStepAppeal => 'Shikoyat';

  @override
  String get serviceStepOpenPortal => 'Ushbu bosqichni portalda bajarish';

  @override
  String get serviceOpenMyGov => 'my.gov.uz orqali ariza berish';

  @override
  String get documentBuilderTitle => 'Hujjatlar Konstruktori';

  @override
  String get templatesSearchHint =>
      'Shablon nomi, modda yoki sohani qidirish...';

  @override
  String get templatesEmptyTitle => 'Shablonlar topilmadi';

  @override
  String templateFieldsCount(int count) {
    return '$count ta maydon';
  }

  @override
  String get documentLegalBasisLabel => 'Rasmiy Yuridik Asos:';

  @override
  String get documentFillFieldsTitle => 'Maydonlarni to\'ldiring:';

  @override
  String get documentGenerateAction => 'Hujjatni shakllantirish va ko\'rish';

  @override
  String get documentPreviewTitle => 'Tayyor Hujjat Ko\'rinishi';

  @override
  String get documentSaveTooltip => 'Saqlanganlarga qo\'shish';

  @override
  String get documentCopiedSnack => 'Hujjat matni xotiraga nusxalandi!';

  @override
  String get documentSavedSnack => 'Hujjat muvaffaqiyatli saqlandi!';

  @override
  String documentLegalBasisWith(String basis) {
    return 'Yuridik Asos: $basis';
  }

  @override
  String get documentReadyToPrint =>
      'Rasmiy talablar asosida shakllantirilgan. Chop etishga tayyor.';

  @override
  String get expertsTitle => 'Tasdiqlangan Advokatlar';

  @override
  String get expertsApplyTooltip => 'Advokat sifatida a\'zo bo\'lish';

  @override
  String get expertsHeaderTitle => 'Rasmiy Litsenziyaga Ega Advokatlar';

  @override
  String get expertsHeaderSubtitle =>
      'Barcha mutaxassislar O\'zbekiston Advokatlar palatasi ro\'yxatidan tekshirilgan.';

  @override
  String get expertsSearchHint => 'Advokat ismi yoki soha bo\'yicha qidiruv...';

  @override
  String get expertsRegionLabel => 'Hudud bo\'yicha:';

  @override
  String get expertsAllRegions => 'Barcha viloyatlar';

  @override
  String get expertsEmptyFiltered =>
      'Tanlangan parametrlar bo\'yicha advokatlar topilmadi';

  @override
  String expertsEmptyForSpecialization(String area) {
    return '\"$area\" yo\'nalishi bo\'yicha tasdiqlangan advokat hozircha yo\'q.';
  }

  @override
  String get expertsClearSpecializationFilter =>
      'Barcha ixtisosliklarni ko\'rish';

  @override
  String get expertsDirectoryEmpty =>
      'Tasdiqlangan advokatlar ro\'yxati hozircha bo\'sh — advokatlar tekshiruvdan o\'tkazilib qo\'shilmoqda.';

  @override
  String get expertVerifiedBadge => 'Tasdiqlangan';

  @override
  String get expertNameUnknown => 'Ismi ko\'rsatilmagan';

  @override
  String get expertSpecializationUnknown => 'Mutaxassislik ko\'rsatilmagan';

  @override
  String get expertContact => 'Bog\'lanish';

  @override
  String expertExperienceYears(int count) {
    return '$count yil tajriba';
  }

  @override
  String expertWonCases(int count) {
    return '$count+ yutilgan ish';
  }

  @override
  String expertFeeAmount(String amount) {
    return '$amount so\'m';
  }

  @override
  String get expertFeeNegotiable => 'Kelishuv asosida';

  @override
  String expertLicenseLine(String number) {
    return 'Litsenziya: $number';
  }

  @override
  String get expertMetricRating => 'Reyting';

  @override
  String expertMetricReviews(int count) {
    return '$count ta baho';
  }

  @override
  String get expertNoRating => 'Baho yo\'q';

  @override
  String get expertMetricExperience => 'Tajriba';

  @override
  String expertMetricYears(int count) {
    return '$count yil';
  }

  @override
  String get expertMetricPractice => 'Amaliyot';

  @override
  String get expertMetricWins => 'Yutuqlar';

  @override
  String get expertMetricWonCases => 'Yutilgan ish';

  @override
  String get expertAboutTitle => 'Advokat haqida';

  @override
  String get expertBookConsultation => 'Konsultatsiyaga Yozilish';

  @override
  String get expertCall => 'Qo\'ng\'iroq';

  @override
  String get expertTelegram => 'Telegram';

  @override
  String get expertContactMissing => 'Aloqa ma\'lumotlari ko\'rsatilmagan';

  @override
  String expertCallFailed(String phone) {
    return 'Qo\'ng\'iroq qilib bo\'lmadi: $phone';
  }

  @override
  String expertTelegramFailed(String username) {
    return 'Telegram profilini ochib bo\'lmadi: @$username';
  }

  @override
  String get expertApplyTitle => 'Advokatlik A\'zoligi Uchun Ariza';

  @override
  String get expertApplyIntro =>
      'O\'zbekiston Advokatlar palatasi litsenziyasi ma\'lumotlarini kiriting. Tasdiqlangan mutaxassislar ro\'yxatiga kiritilasiz.';

  @override
  String get expertApplySpecializationLabel => 'Mutaxassislik sohasi *';

  @override
  String get expertApplySpecializationError => 'Ixtisoslikni tanlang';

  @override
  String get expertApplyLicenseLabel => 'Litsenziya raqami (ADV-XXXXX) *';

  @override
  String get expertApplyLicenseError => 'Litsenziya raqamini kiriting';

  @override
  String get expertApplyExperienceLabel => 'Yuridik staj (yillarda) *';

  @override
  String get expertApplyExperienceError => 'Tajribani kiriting';

  @override
  String get expertApplyWorkplaceLabel => 'Ish joyi / Advokatlik tuzilmasi';

  @override
  String get expertApplyFeeLabel => 'Maslahat narxi (so\'mda, ixtiyoriy)';

  @override
  String get expertApplySubmit => 'Ariza yuborish';

  @override
  String get expertSpecLabor => 'Mehnat huquqi';

  @override
  String get expertSpecFamilyProperty => 'Oila va Mulk huquqi';

  @override
  String get expertSpecCriminalDefense => 'Jinoyat va Tergov himoyasi';

  @override
  String get expertSpecTrafficAdmin => 'Yo\'l harakati va Ma\'muriy jarimalar';

  @override
  String get expertSpecConsumerContracts =>
      'Iste\'molchi huquqlari va Shartnomalar';

  @override
  String get expertSpecBusinessCorporate => 'Biznes va Korporativ huquq';

  @override
  String get expertSpecTaxCustoms => 'Soliq va Bojxona huquqi';

  @override
  String get consultationStatusPending => 'Kutilmoqda';

  @override
  String get consultationStatusAwaitingPayment => 'To\'lov kutilmoqda';

  @override
  String get consultationStatusConfirmed => 'Tasdiqlangan';

  @override
  String get consultationStatusInProgress => 'Jarayonda';

  @override
  String get consultationStatusCompleted => 'Tugallangan';

  @override
  String get consultationStatusCancelled => 'Bekor qilingan';

  @override
  String get consultationStatusExpired => 'Muddati o\'tgan';

  @override
  String get consultationStatusDisputed => 'E\'tirozli';

  @override
  String consultationAmountUzs(String amount) {
    return '$amount so\'m';
  }

  @override
  String get bookTitle => 'Konsultatsiya Bron Qilish';

  @override
  String get bookSelectSlotWarning => 'Iltimos, konsultatsiya vaqtini tanlang';

  @override
  String bookPriceLine(String amount) {
    return 'Narxi: $amount so\'m';
  }

  @override
  String bookPriceWithDuration(String amount, int minutes) {
    return 'Narxi: $amount so\'m / $minutes daqiqa';
  }

  @override
  String get bookSelectDate => 'Sana Tanlang';

  @override
  String get bookAvailableSlots => 'Mavjud Vaqt Slotlari';

  @override
  String get bookSlotsLoading => 'Slotlar yuklanmoqda...';

  @override
  String get bookNoSlots => 'Ushbu kunga bo\'sh slotlar mavjud emas.';

  @override
  String get bookMeetingTypeTitle => 'Konsultatsiya Turi';

  @override
  String get bookMeetingTypeOnline => 'Onlayn Video';

  @override
  String get bookMeetingTypePhone => 'Telefon';

  @override
  String get bookMeetingTypeOffice => 'Ofisda';

  @override
  String get bookNotesTitle => 'Masala haqida qisqacha (ixtiyoriy)';

  @override
  String get bookNotesHint =>
      'Masalan: Mehnat nizosi, ishdan asossiz bo\'shatish...';

  @override
  String bookProceedToPaymentAmount(String amount) {
    return '$amount so\'m — To\'lovga o\'tish';
  }

  @override
  String get bookProceedToPayment => 'To\'lovga o\'tish';

  @override
  String get bookSelectTime => 'Vaqtni tanlang';

  @override
  String get weekdayShortMon => 'Dush';

  @override
  String get weekdayShortTue => 'Sesh';

  @override
  String get weekdayShortWed => 'Chor';

  @override
  String get weekdayShortThu => 'Pay';

  @override
  String get weekdayShortFri => 'Jum';

  @override
  String get weekdayShortSat => 'Shan';

  @override
  String get weekdayShortSun => 'Yak';

  @override
  String get myConsultationsTitle => 'Mening Konsultatsiyalarim';

  @override
  String get myConsultationsTabUpcoming => 'Kutilayotgan';

  @override
  String get myConsultationsTabCompleted => 'Tugallangan';

  @override
  String get myConsultationsTabCancelled => 'Bekor qilingan';

  @override
  String get myConsultationsEmpty => 'Konsultatsiyalar topilmadi';

  @override
  String get consultationCancelTitle => 'Konsultatsiyani bekor qilish';

  @override
  String consultationCancelHoursLeft(int hours) {
    return 'Konsultatsiyagacha qolgan vaqt: $hours soat';
  }

  @override
  String consultationCancelRefundLine(String percent, String amount) {
    return 'Qaytariladigan summa: $percent% ($amount so\'m)';
  }

  @override
  String get consultationCancelReasonLabel => 'Bekor qilish sababi';

  @override
  String get consultationCancelReasonHint => 'Sababni yozing...';

  @override
  String get consultationCancelConfirm => 'Bekor Qilish';

  @override
  String consultationCancelledSnack(String amount) {
    return 'Konsultatsiya bekor qilindi. Qaytarilgan: $amount so\'m';
  }

  @override
  String consultationMeetingLinkSnack(String link) {
    return 'Xona havolasi: $link';
  }

  @override
  String get consultationJoinRoom => 'Xonaga Kirish';

  @override
  String get paymentTitle => 'To\'lovni Tasdiqlash';

  @override
  String get paymentProcessing => 'To\'lov tranzaksiyasi tekshirilmoqda...';

  @override
  String get paymentServiceLine => 'Huquqiy maslahat';

  @override
  String get paymentScheduledDateLabel => 'Belgilangan sana:';

  @override
  String get paymentTotalLabel => 'Jami to\'lov:';

  @override
  String get paymentGatewayUnavailableTitle =>
      'Onlayn to\'lov hozircha ulanmagan';

  @override
  String get paymentGatewayUnavailableBody =>
      'Bu versiyada Payme, Click va Uzum bilan real to\'lov integratsiyasi yo\'q. Bandligingiz \"to\'lov kutilmoqda\" holatida saqlandi — advokat siz bilan bog\'lanib to\'lovni kelishadi. Ilovada soxta to\'lov tasdig\'i ko\'rsatilmaydi.';

  @override
  String get paymentGatewayUnavailableAction => 'To\'lov hozircha mavjud emas';

  @override
  String get paymentMethodTitle => 'To\'lov Usulini Tanlang';

  @override
  String get paymentProviderPaymeSubtitle => 'Humo, Uzcard orqali to\'lov';

  @override
  String get paymentProviderClickSubtitle => 'ClickPass va QR to\'lov';

  @override
  String get paymentProviderUzumSubtitle => 'Uzum kartalari va nasiya';

  @override
  String paymentPayAmount(String amount) {
    return '$amount so\'m To\'lash';
  }

  @override
  String get paymentSuccessTitle => 'To\'lov Muvaffaqiyatli Bajarildi!';

  @override
  String get paymentSuccessWithLink =>
      'Advokat bilan konsultatsiyangiz tasdiqlandi. Belgilangan vaqtda quyidagi xona orqali ulanishingiz mumkin.';

  @override
  String get paymentSuccessNoLink =>
      'Advokat bilan konsultatsiyangiz tasdiqlandi. Uchrashuv havolasi tayyor bo\'lgach, \"Mening konsultatsiyalarim\" bo\'limida ko\'rinadi.';

  @override
  String get paymentGoToMyConsultations => 'Konsultatsiyalarimga O\'tish';

  @override
  String get moderationTitle => 'Advokat arizalari';

  @override
  String get moderationEntrySubtitle => 'Litsenziyani tekshirib tasdiqlash';

  @override
  String moderationPendingCount(int count) {
    return '$count ta ariza tekshirilmoqda';
  }

  @override
  String get moderationEmptyTitle => 'Tekshirishga ariza yo\'q';

  @override
  String get moderationEmptyBody =>
      'Yangi ariza topshirilganda u shu yerda ko\'rinadi.';

  @override
  String get moderationLicenseLabel => 'Litsenziya raqami';

  @override
  String get moderationSpecializationLabel => 'Yo\'nalish';

  @override
  String get moderationExperienceLabel => 'Tajriba';

  @override
  String moderationExperienceValue(int count) {
    return '$count yil';
  }

  @override
  String get moderationWorkplaceLabel => 'Ish joyi';

  @override
  String get moderationEducationLabel => 'Ma\'lumoti';

  @override
  String moderationSubmittedAt(String date) {
    return 'Topshirilgan: $date';
  }

  @override
  String get moderationFieldMissing => 'Ko\'rsatilmagan';

  @override
  String get moderationUnnamedApplicant => 'Ismi ko\'rsatilmagan arizachi';

  @override
  String get moderationOpenDocument => 'Litsenziya hujjatini ochish';

  @override
  String get moderationNoDocument => 'Litsenziya hujjati yuklanmagan';

  @override
  String get moderationDocumentOpenFailed => 'Hujjatni ochib bo\'lmadi.';

  @override
  String get moderationApprove => 'Tasdiqlash';

  @override
  String get moderationReject => 'Rad etish';

  @override
  String get moderationApproveTitle => 'Arizani tasdiqlaysizmi?';

  @override
  String moderationApproveBody(String name) {
    return '$name tasdiqlangan advokat bo\'ladi va katalogda ko\'rinadi. Litsenziya hujjatini ochib tekshirganingizga ishonch hosil qiling.';
  }

  @override
  String get moderationRejectTitle => 'Arizani rad etasizmi?';

  @override
  String moderationRejectBody(String name) {
    return '$name tasdiqlanmaydi va katalogga chiqmaydi.';
  }

  @override
  String get moderationRejectConsequence =>
      'Ariza rad etilgan deb belgilanadi va ro\'yxatdan chiqadi. Arizachi tuzatib qayta topshirishi mumkin.';

  @override
  String get moderationRejectReasonLabel => 'Rad etish sababi (majburiy emas)';

  @override
  String get moderationRejectReasonHint =>
      'Masalan: litsenziya raqami tekshiruvdan o\'tmadi';

  @override
  String get moderationRejectReasonDelivery =>
      'Sababni arizachi qayta topshirishga uringanda ko\'radi.';

  @override
  String get crashLogTitle => 'Xato jurnali';

  @override
  String get crashLogEntrySubtitle => 'Ilovadagi tutilmagan xatolar';

  @override
  String get crashLogEmpty => 'Xato yozuvi yo\'q.';

  @override
  String get crashLogPurgeAction => '30 kundan eskisini tozalash';

  @override
  String get crashLogPurgeConfirmBody =>
      '30 kundan eski yozuvlar butunlay o\'chiriladi. Bu amalni qaytarib bo\'lmaydi.';

  @override
  String crashLogPurgeDone(int count) {
    return '$count yozuv o\'chirildi.';
  }

  @override
  String get crashLogStackLabel => 'Stack trace';

  @override
  String moderationApprovedToast(String name) {
    return '$name tasdiqlandi.';
  }

  @override
  String moderationRejectedToast(String name) {
    return '$name arizasi rad etildi.';
  }

  @override
  String get moderationListStale =>
      'Amal serverda bajarildi, lekin ro\'yxatni yangilab bo\'lmadi.';

  @override
  String get moderationRoleReverted => 'Advokat maqomi ham bekor qilindi.';

  @override
  String get errorNetwork =>
      'Internet aloqasi yo\'q. Tarmoqni tekshirib, qaytadan urinib ko\'ring.';

  @override
  String get errorTimeout =>
      'Server javob bermadi. Iltimos, qaytadan urinib ko\'ring.';

  @override
  String get errorServer =>
      'Serverda xatolik yuz berdi. Keyinroq qaytadan urinib ko\'ring.';

  @override
  String get errorUnauthorized => 'Sessiya tugagan. Iltimos, qaytadan kiring.';

  @override
  String get errorForbidden => 'Bu amalni bajarishga ruxsat yo\'q.';

  @override
  String get errorNotFound => 'So\'ralgan ma\'lumot topilmadi.';

  @override
  String get errorRateLimited =>
      'Juda ko\'p urinish. Bir necha daqiqadan keyin qaytadan urinib ko\'ring.';

  @override
  String get errorApplicationCooldown =>
      'Ariza rad etilgan. Qayta topshirish qaror qabul qilinganidan 24 soat o\'tgach mumkin.';

  @override
  String get errorValidation =>
      'Kiritilgan ma\'lumotlar to\'g\'ri emas. Iltimos, tekshirib ko\'ring.';

  @override
  String get errorCache => 'Qurilmada saqlangan ma\'lumotni o\'qib bo\'lmadi.';

  @override
  String get errorCancelled => 'So\'rov bekor qilindi.';

  @override
  String get errorUnexpected =>
      'Kutilmagan xatolik yuz berdi. Iltimos, qaytadan urinib ko\'ring.';
}
