import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_uz.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n)!;
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('uz')
  ];

  /// No description provided for @appName.
  ///
  /// In uz, this message translates to:
  /// **'LexHub'**
  String get appName;

  /// No description provided for @appTagline.
  ///
  /// In uz, this message translates to:
  /// **'O\'zbekiston fuqarolari uchun huquqiy ekotizim'**
  String get appTagline;

  /// No description provided for @appLegalPlatform.
  ///
  /// In uz, this message translates to:
  /// **'O\'zbekiston Huquqiy Platformasi'**
  String get appLegalPlatform;

  /// HALOLLIK: 'LexHub AI' EMAS, shunchaki 'LexHub'. Javob model tahlilidan ham, qurilmadagi deterministik qonun bazasidan ham kelishi mumkin; haqiqiy manba `legalSourceLlm`/`legalSourceDeterministic` badge'ida ko'rsatiladi.
  ///
  /// In uz, this message translates to:
  /// **'Diqqat: LexHub yakuniy sud hukmi yoki litsenziyaga ega advokat o\'rnini bosmaydi. Tizim holatni tushunish va qonuniy yo\'lni aniqlashga ko\'maklashadi.'**
  String get legalDisclaimer;

  /// No description provided for @legalSourceLlm.
  ///
  /// In uz, this message translates to:
  /// **'Server AI modeli tahlili'**
  String get legalSourceLlm;

  /// No description provided for @legalSourceDeterministic.
  ///
  /// In uz, this message translates to:
  /// **'AI EMAS: qurilmadagi tekshirilgan qonun bazasi asosida'**
  String get legalSourceDeterministic;

  /// No description provided for @actionRetry.
  ///
  /// In uz, this message translates to:
  /// **'Qaytadan urinish'**
  String get actionRetry;

  /// No description provided for @actionCancel.
  ///
  /// In uz, this message translates to:
  /// **'Bekor qilish'**
  String get actionCancel;

  /// No description provided for @actionClose.
  ///
  /// In uz, this message translates to:
  /// **'Yopish'**
  String get actionClose;

  /// No description provided for @actionSend.
  ///
  /// In uz, this message translates to:
  /// **'Yuborish'**
  String get actionSend;

  /// No description provided for @actionSave.
  ///
  /// In uz, this message translates to:
  /// **'Saqlash'**
  String get actionSave;

  /// No description provided for @actionCopy.
  ///
  /// In uz, this message translates to:
  /// **'Nusxalash'**
  String get actionCopy;

  /// No description provided for @actionCopied.
  ///
  /// In uz, this message translates to:
  /// **'Nusxalandi'**
  String get actionCopied;

  /// No description provided for @actionContinue.
  ///
  /// In uz, this message translates to:
  /// **'Davom etish'**
  String get actionContinue;

  /// No description provided for @actionOk.
  ///
  /// In uz, this message translates to:
  /// **'Tushunarli'**
  String get actionOk;

  /// No description provided for @actionSearch.
  ///
  /// In uz, this message translates to:
  /// **'Qidirish'**
  String get actionSearch;

  /// No description provided for @actionShare.
  ///
  /// In uz, this message translates to:
  /// **'Ulashish'**
  String get actionShare;

  /// No description provided for @actionDelete.
  ///
  /// In uz, this message translates to:
  /// **'O\'chirish'**
  String get actionDelete;

  /// No description provided for @actionOpen.
  ///
  /// In uz, this message translates to:
  /// **'Ochish'**
  String get actionOpen;

  /// No description provided for @actionSeeAll.
  ///
  /// In uz, this message translates to:
  /// **'Barchasi'**
  String get actionSeeAll;

  /// No description provided for @loadingLabel.
  ///
  /// In uz, this message translates to:
  /// **'Yuklanmoqda...'**
  String get loadingLabel;

  /// No description provided for @navHome.
  ///
  /// In uz, this message translates to:
  /// **'Bosh sahifa'**
  String get navHome;

  /// HALOLLIK: ilgari 'LexHub AI' edi. Bu tab huquqiy tahlil ekranini ochadi; javob model chaqiruvisiz (deterministik) ham kelishi mumkin, shuning uchun tab nomi AI da'vosini QILMAYDI.
  ///
  /// In uz, this message translates to:
  /// **'Maslahat'**
  String get navAI;

  /// No description provided for @navCommunity.
  ///
  /// In uz, this message translates to:
  /// **'Hamjamiyat'**
  String get navCommunity;

  /// No description provided for @navServices.
  ///
  /// In uz, this message translates to:
  /// **'Xizmatlar'**
  String get navServices;

  /// No description provided for @navExperts.
  ///
  /// In uz, this message translates to:
  /// **'Advokatlar'**
  String get navExperts;

  /// No description provided for @navCabinet.
  ///
  /// In uz, this message translates to:
  /// **'Kabinet'**
  String get navCabinet;

  /// No description provided for @authLoginTitle.
  ///
  /// In uz, this message translates to:
  /// **'Tizimga kirish'**
  String get authLoginTitle;

  /// No description provided for @authRegisterTitle.
  ///
  /// In uz, this message translates to:
  /// **'Ro\'yxatdan o\'tish'**
  String get authRegisterTitle;

  /// No description provided for @authRegisterSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'LexHub orqali yuridik xizmatlar va jamoat forumidan to\'liq foydalaning'**
  String get authRegisterSubtitle;

  /// No description provided for @authFieldFullName.
  ///
  /// In uz, this message translates to:
  /// **'To\'liq ism-sharifingiz'**
  String get authFieldFullName;

  /// No description provided for @authHintFullName.
  ///
  /// In uz, this message translates to:
  /// **'Bobur Mirzayev'**
  String get authHintFullName;

  /// No description provided for @authFieldEmail.
  ///
  /// In uz, this message translates to:
  /// **'Email pochta'**
  String get authFieldEmail;

  /// No description provided for @authHintEmail.
  ///
  /// In uz, this message translates to:
  /// **'misol@domain.uz'**
  String get authHintEmail;

  /// No description provided for @authFieldPassword.
  ///
  /// In uz, this message translates to:
  /// **'Maxfiy parol'**
  String get authFieldPassword;

  /// No description provided for @authFieldCreatePassword.
  ///
  /// In uz, this message translates to:
  /// **'Parol yaratish'**
  String get authFieldCreatePassword;

  /// No description provided for @authHintPassword.
  ///
  /// In uz, this message translates to:
  /// **'Parolni kiriting'**
  String get authHintPassword;

  /// No description provided for @authHintMinSixChars.
  ///
  /// In uz, this message translates to:
  /// **'Kamida 6 ta belgi'**
  String get authHintMinSixChars;

  /// No description provided for @authFieldConfirmPassword.
  ///
  /// In uz, this message translates to:
  /// **'Parolni tasdiqlang'**
  String get authFieldConfirmPassword;

  /// No description provided for @authHintConfirmPassword.
  ///
  /// In uz, this message translates to:
  /// **'Parolni qayta kiriting'**
  String get authHintConfirmPassword;

  /// No description provided for @authHaveAccount.
  ///
  /// In uz, this message translates to:
  /// **'Hisobingiz bormi? '**
  String get authHaveAccount;

  /// No description provided for @authNoAccount.
  ///
  /// In uz, this message translates to:
  /// **'Hisobingiz yo\'qmi? '**
  String get authNoAccount;

  /// No description provided for @authGoToLogin.
  ///
  /// In uz, this message translates to:
  /// **'Kirish'**
  String get authGoToLogin;

  /// No description provided for @authGoToRegister.
  ///
  /// In uz, this message translates to:
  /// **'Ro\'yxatdan o\'ting'**
  String get authGoToRegister;

  /// No description provided for @authContinueAsGuest.
  ///
  /// In uz, this message translates to:
  /// **'Mehmon sifatida davom etish'**
  String get authContinueAsGuest;

  /// No description provided for @authSignOut.
  ///
  /// In uz, this message translates to:
  /// **'Tizimdan chiqish'**
  String get authSignOut;

  /// No description provided for @authLoginOrRegister.
  ///
  /// In uz, this message translates to:
  /// **'Tizimga kirish / Ro\'yxatdan o\'tish'**
  String get authLoginOrRegister;

  /// No description provided for @authSignedOutTitle.
  ///
  /// In uz, this message translates to:
  /// **'Hisobingizga kiring'**
  String get authSignedOutTitle;

  /// No description provided for @authSignedOutSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Savol berish, javoblarni baholash va advokatlar bilan maslahatlashish uchun tizimga kiring'**
  String get authSignedOutSubtitle;

  /// No description provided for @authDefaultUserName.
  ///
  /// In uz, this message translates to:
  /// **'Foydalanuvchi'**
  String get authDefaultUserName;

  /// Ro'yxatdan o'tish muvaffaqiyatli, lekin sessiya berilmagan (server 'Confirm email' yoqilgan) holatdagi panel sarlavhasi.
  ///
  /// In uz, this message translates to:
  /// **'Email manzilingizni tasdiqlang'**
  String get authEmailConfirmTitle;

  /// Email tasdiqlash paneli matni. `FailureCode.emailConfirmationRequired` uchun ham ishlatiladi.
  ///
  /// In uz, this message translates to:
  /// **'Hisobingiz yaratildi. Tizimga kirish uchun pochtangizga yuborilgan tasdiqlash havolasini bosing.'**
  String get authEmailConfirmBody;

  /// Email tasdiqlash panelidagi qo'shimcha ko'rsatma.
  ///
  /// In uz, this message translates to:
  /// **'Xat ko\'rinmasa \"Spam\" papkasini ham tekshirib ko\'ring.'**
  String get authEmailConfirmHint;

  /// No description provided for @validationNameRequired.
  ///
  /// In uz, this message translates to:
  /// **'Ism-sharifingizni kiriting'**
  String get validationNameRequired;

  /// No description provided for @validationNameTooShort.
  ///
  /// In uz, this message translates to:
  /// **'Ism juda qisqa'**
  String get validationNameTooShort;

  /// No description provided for @validationEmailRequired.
  ///
  /// In uz, this message translates to:
  /// **'Email manzilini kiriting'**
  String get validationEmailRequired;

  /// No description provided for @validationEmailInvalid.
  ///
  /// In uz, this message translates to:
  /// **'To\'g\'ri email formatini kiriting'**
  String get validationEmailInvalid;

  /// No description provided for @validationPasswordRequired.
  ///
  /// In uz, this message translates to:
  /// **'Parolni kiriting'**
  String get validationPasswordRequired;

  /// No description provided for @validationPasswordTooShort.
  ///
  /// In uz, this message translates to:
  /// **'Parol kamida 6 belgidan iborat bo\'lishi kerak'**
  String get validationPasswordTooShort;

  /// No description provided for @validationConfirmPasswordRequired.
  ///
  /// In uz, this message translates to:
  /// **'Parolni tasdiqlang'**
  String get validationConfirmPasswordRequired;

  /// No description provided for @validationPasswordsMismatch.
  ///
  /// In uz, this message translates to:
  /// **'Kiritilgan parollar bir-biriga mos kelmadi'**
  String get validationPasswordsMismatch;

  /// No description provided for @profileSecurityTitle.
  ///
  /// In uz, this message translates to:
  /// **'Xavfsizlik & RLS himoyasi'**
  String get profileSecurityTitle;

  /// No description provided for @profileSecuritySubtitle.
  ///
  /// In uz, this message translates to:
  /// **'PostgreSQL Row Level Security faol'**
  String get profileSecuritySubtitle;

  /// No description provided for @profileReputationPoints.
  ///
  /// In uz, this message translates to:
  /// **'{points} ball'**
  String profileReputationPoints(int points);

  /// No description provided for @roleCitizen.
  ///
  /// In uz, this message translates to:
  /// **'Fuqaro'**
  String get roleCitizen;

  /// No description provided for @roleLawyer.
  ///
  /// In uz, this message translates to:
  /// **'Yurist / Advokat'**
  String get roleLawyer;

  /// No description provided for @roleVerifiedExpert.
  ///
  /// In uz, this message translates to:
  /// **'Verifikatsiyalangan ekspert'**
  String get roleVerifiedExpert;

  /// No description provided for @roleModerator.
  ///
  /// In uz, this message translates to:
  /// **'Moderator'**
  String get roleModerator;

  /// No description provided for @roleAdmin.
  ///
  /// In uz, this message translates to:
  /// **'Administrator'**
  String get roleAdmin;

  /// No description provided for @settingsTitle.
  ///
  /// In uz, this message translates to:
  /// **'Sozlamalar'**
  String get settingsTitle;

  /// No description provided for @settingsLanguageTile.
  ///
  /// In uz, this message translates to:
  /// **'Ilova tili'**
  String get settingsLanguageTile;

  /// No description provided for @settingsLanguageSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Interfeys tilini tanlang'**
  String get settingsLanguageSubtitle;

  /// No description provided for @languagePageTitle.
  ///
  /// In uz, this message translates to:
  /// **'Til'**
  String get languagePageTitle;

  /// No description provided for @languagePageSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Tanlangan til butun ilovaga qo\'llanadi va ilova qayta ochilganda ham saqlanadi.'**
  String get languagePageSubtitle;

  /// No description provided for @languageSaveFailed.
  ///
  /// In uz, this message translates to:
  /// **'Tilni saqlab bo\'lmadi. Qaytadan urinib ko\'ring.'**
  String get languageSaveFailed;

  /// No description provided for @languageChangedTo.
  ///
  /// In uz, this message translates to:
  /// **'Til o\'zgartirildi: {language}'**
  String languageChangedTo(String language);

  /// No description provided for @categoryAll.
  ///
  /// In uz, this message translates to:
  /// **'Barchasi'**
  String get categoryAll;

  /// No description provided for @categoryLabor.
  ///
  /// In uz, this message translates to:
  /// **'Mehnat huquqi'**
  String get categoryLabor;

  /// No description provided for @categoryFamily.
  ///
  /// In uz, this message translates to:
  /// **'Oila huquqi'**
  String get categoryFamily;

  /// No description provided for @categoryCivil.
  ///
  /// In uz, this message translates to:
  /// **'Fuqarolik huquqi'**
  String get categoryCivil;

  /// No description provided for @categoryCriminal.
  ///
  /// In uz, this message translates to:
  /// **'Jinoyat huquqi'**
  String get categoryCriminal;

  /// No description provided for @categoryAdministrative.
  ///
  /// In uz, this message translates to:
  /// **'Ma\'muriy huquqi'**
  String get categoryAdministrative;

  /// No description provided for @categoryGeneral.
  ///
  /// In uz, this message translates to:
  /// **'Umumiy'**
  String get categoryGeneral;

  /// No description provided for @communityTitle.
  ///
  /// In uz, this message translates to:
  /// **'Fuqarolar va Advokatlar minbari'**
  String get communityTitle;

  /// No description provided for @communityAskTooltip.
  ///
  /// In uz, this message translates to:
  /// **'Hamjamiyatga savol berish'**
  String get communityAskTooltip;

  /// No description provided for @communityAskCta.
  ///
  /// In uz, this message translates to:
  /// **'Savol berish'**
  String get communityAskCta;

  /// No description provided for @communityEmptyInCategory.
  ///
  /// In uz, this message translates to:
  /// **'Ushbu kategoriyada savollar topilmadi'**
  String get communityEmptyInCategory;

  /// No description provided for @communityAnswersCount.
  ///
  /// In uz, this message translates to:
  /// **'{count} ta javob'**
  String communityAnswersCount(int count);

  /// HALOLLIK: ilgari 'AI tahlil' edi. Bu tugma tahlil ekranini ochadi, natijani KAFOLATLAMAYDI — model javob bermasa deterministik javob ko'rsatiladi.
  ///
  /// In uz, this message translates to:
  /// **'Huquqiy tahlil'**
  String get communityAiAnalysis;

  /// HALOLLIK: ilgari 'AI tahlil xulosasi:' edi, LEKIN `post.aiSummary` matni model tomonidan YARATILMAYDI — u `community_forum_remote_datasource.dart` ichidagi kategoriya shabloni. Shuning uchun yorliq uni AI xulosasi deb ATAMAYDI.
  ///
  /// In uz, this message translates to:
  /// **'Kategoriya bo\'yicha avtomatik eslatma:'**
  String get communityAiSummaryLabel;

  /// No description provided for @communityExpertAnswerBadge.
  ///
  /// In uz, this message translates to:
  /// **'Advokat javobi bor'**
  String get communityExpertAnswerBadge;

  /// No description provided for @communityAnonymousBadge.
  ///
  /// In uz, this message translates to:
  /// **'Maxfiy (Anonim)'**
  String get communityAnonymousBadge;

  /// No description provided for @communityAnonymousShort.
  ///
  /// In uz, this message translates to:
  /// **'Anonim'**
  String get communityAnonymousShort;

  /// No description provided for @communityAnonymousAuthor.
  ///
  /// In uz, this message translates to:
  /// **'Anonim fuqaro'**
  String get communityAnonymousAuthor;

  /// No description provided for @communityPiiNotice.
  ///
  /// In uz, this message translates to:
  /// **'Shaxsiy ma\'lumotlar (telefon, pasport, karta) avtomatik yashiriladi'**
  String get communityPiiNotice;

  /// No description provided for @askDialogTitle.
  ///
  /// In uz, this message translates to:
  /// **'Hamjamiyatga savol berish'**
  String get askDialogTitle;

  /// No description provided for @askDialogPrivacyGuard.
  ///
  /// In uz, this message translates to:
  /// **'Privacy Guard: telefon, pasport va karta raqamlari avtomatik yashiriladi'**
  String get askDialogPrivacyGuard;

  /// No description provided for @askDialogCategoryField.
  ///
  /// In uz, this message translates to:
  /// **'Kategoriya'**
  String get askDialogCategoryField;

  /// No description provided for @askDialogTitleField.
  ///
  /// In uz, this message translates to:
  /// **'Savol sarlavhasi (qisqacha)'**
  String get askDialogTitleField;

  /// No description provided for @askDialogTitleHint.
  ///
  /// In uz, this message translates to:
  /// **'Masalan: Dam olish kunida majburiy ishlash...'**
  String get askDialogTitleHint;

  /// No description provided for @askDialogBodyField.
  ///
  /// In uz, this message translates to:
  /// **'Batafsil ma\'lumot'**
  String get askDialogBodyField;

  /// No description provided for @askDialogBodyHint.
  ///
  /// In uz, this message translates to:
  /// **'Yuridik muammoingizni erkin bayon qiling...'**
  String get askDialogBodyHint;

  /// No description provided for @askDialogAnonymousToggle.
  ///
  /// In uz, this message translates to:
  /// **'Anonim tarzda e\'lon qilish'**
  String get askDialogAnonymousToggle;

  /// No description provided for @askDialogAnonymousSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Ismingiz o\'rniga \'Anonim fuqaro\' ko\'rsatiladi'**
  String get askDialogAnonymousSubtitle;

  /// No description provided for @askDialogPiiDetected.
  ///
  /// In uz, this message translates to:
  /// **'Maxfiy ma\'lumotlar aniqlandi va yashirildi:'**
  String get askDialogPiiDetected;

  /// No description provided for @askDialogPublishAnonymously.
  ///
  /// In uz, this message translates to:
  /// **'Anonim tarzda chop etish'**
  String get askDialogPublishAnonymously;

  /// No description provided for @askDialogPublish.
  ///
  /// In uz, this message translates to:
  /// **'Savolni chop etish'**
  String get askDialogPublish;

  /// No description provided for @askDialogEmptyBody.
  ///
  /// In uz, this message translates to:
  /// **'Iltimos, savol matnini kiriting'**
  String get askDialogEmptyBody;

  /// No description provided for @authRequiredTitle.
  ///
  /// In uz, this message translates to:
  /// **'Tizimga kirish talab etiladi'**
  String get authRequiredTitle;

  /// No description provided for @authRequiredMessage.
  ///
  /// In uz, this message translates to:
  /// **'{action} uchun avval tizimga kiring yoki yangi hisob oching.'**
  String authRequiredMessage(String action);

  /// No description provided for @authActionAskQuestion.
  ///
  /// In uz, this message translates to:
  /// **'Savol berish'**
  String get authActionAskQuestion;

  /// No description provided for @authActionWriteAnswer.
  ///
  /// In uz, this message translates to:
  /// **'Javob yozish'**
  String get authActionWriteAnswer;

  /// No description provided for @authActionVote.
  ///
  /// In uz, this message translates to:
  /// **'Ovoz berish'**
  String get authActionVote;

  /// No description provided for @authActionAcceptAnswer.
  ///
  /// In uz, this message translates to:
  /// **'Javobni qabul qilish'**
  String get authActionAcceptAnswer;

  /// No description provided for @questionDetailTitle.
  ///
  /// In uz, this message translates to:
  /// **'Savol tafsilotlari'**
  String get questionDetailTitle;

  /// HALOLLIK: ilgari 'LexHub AI tezkor xulosasi' edi. Matn manbasi — `ai_summary` ustuni, unga savol yaratilganda KATEGORIYA SHABLONI yoziladi (model chaqirilmaydi).
  ///
  /// In uz, this message translates to:
  /// **'Kategoriya bo\'yicha avtomatik eslatma'**
  String get questionDetailAiSummary;

  /// No description provided for @questionDetailAnswersSection.
  ///
  /// In uz, this message translates to:
  /// **'Javoblar va maslahatlar ({count})'**
  String questionDetailAnswersSection(int count);

  /// No description provided for @questionDetailEmptyAnswers.
  ///
  /// In uz, this message translates to:
  /// **'Hali hech kim javob yozmadi.\nBirinchi bo\'lib o\'z tajribangiz yoki yuridik fikringizni bildiring!'**
  String get questionDetailEmptyAnswers;

  /// No description provided for @answerAsLawyerChip.
  ///
  /// In uz, this message translates to:
  /// **'Advokat sifatida javob berish'**
  String get answerAsLawyerChip;

  /// No description provided for @answerInputHint.
  ///
  /// In uz, this message translates to:
  /// **'Fikr yoki qonuniy maslahat yozing...'**
  String get answerInputHint;

  /// No description provided for @answerSubmitSuccess.
  ///
  /// In uz, this message translates to:
  /// **'Javobingiz muvaffaqiyatli saqlandi va e\'lon qilindi!'**
  String get answerSubmitSuccess;

  /// No description provided for @answerSubmitDemoted.
  ///
  /// In uz, this message translates to:
  /// **'Javob saqlandi, lekin ODDIY javob sifatida: ekspert javobi uchun profilingiz tasdiqlanmagan.'**
  String get answerSubmitDemoted;

  /// No description provided for @answerAcceptSuccess.
  ///
  /// In uz, this message translates to:
  /// **'Javob foydali (hal qilingan) deb belgilandi!'**
  String get answerAcceptSuccess;

  /// No description provided for @answerAcceptedBadge.
  ///
  /// In uz, this message translates to:
  /// **'Foydali deb qabul qilingan'**
  String get answerAcceptedBadge;

  /// No description provided for @answerAcceptAction.
  ///
  /// In uz, this message translates to:
  /// **'Qabul qilish'**
  String get answerAcceptAction;

  /// No description provided for @answerRoleCommunityMember.
  ///
  /// In uz, this message translates to:
  /// **'Jamoat a\'zosi'**
  String get answerRoleCommunityMember;

  /// No description provided for @answerRoleLicensedLawyer.
  ///
  /// In uz, this message translates to:
  /// **'Litsenziyaga ega advokat'**
  String get answerRoleLicensedLawyer;

  /// No description provided for @homeGreeting.
  ///
  /// In uz, this message translates to:
  /// **'Assalomu alaykum'**
  String get homeGreeting;

  /// No description provided for @homeQueryHint.
  ///
  /// In uz, this message translates to:
  /// **'Muammongizni oddiy tilda yozing...'**
  String get homeQueryHint;

  /// HALOLLIK: ilgari 'AI Tahlil' edi. O'LCHANGAN: bu badge `home_hero_card.dart` ichidagi qidiruv panelida turadi (ilgari `home_header_widget.dart` — u UI redesign'da o'chirildi), panelning `onTap`i `home_page.dart` da `SearchPage`ni ochadi — bu YO'LDA hech qanday model chaqirilmaydi va huquqiy tahlil ham berilmaydi. Shuning uchun yorliq faqat haqiqiy harakatni (qidiruv) nomlaydi. Kalit nomi eski, qiymat esa to'g'ri.
  ///
  /// In uz, this message translates to:
  /// **'Qidirish'**
  String get homeAiAnalyzeButton;

  /// No description provided for @homeServicesBannerTitle.
  ///
  /// In uz, this message translates to:
  /// **'Davlat xizmatlari va Jarayoni'**
  String get homeServicesBannerTitle;

  /// No description provided for @homeServicesBannerSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'my.gov.uz yo\'riqnomalari, to\'lovlar va rasmiy muddatlar'**
  String get homeServicesBannerSubtitle;

  /// No description provided for @homeTopicMatters.
  ///
  /// In uz, this message translates to:
  /// **'Mavzuga oid masalalar'**
  String get homeTopicMatters;

  /// No description provided for @homeCommunityQuestions.
  ///
  /// In uz, this message translates to:
  /// **'Hamjamiyat Savollari'**
  String get homeCommunityQuestions;

  /// No description provided for @homePrivacyGuardBadge.
  ///
  /// In uz, this message translates to:
  /// **'Savolni ismingizni ko\'rsatmasdan yo\'llash mumkin'**
  String get homePrivacyGuardBadge;

  /// No description provided for @homeAskBannerTitle.
  ///
  /// In uz, this message translates to:
  /// **'Sizda ham huquqiy savol bormi?'**
  String get homeAskBannerTitle;

  /// No description provided for @homeAskBannerSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Shaxsiy ma\'lumotlaringiz yashirilgan holda savol yo\'llang'**
  String get homeAskBannerSubtitle;

  /// No description provided for @homeCategoriesTitle.
  ///
  /// In uz, this message translates to:
  /// **'Huquqiy Kategoriyalar ({count})'**
  String homeCategoriesTitle(int count);

  /// No description provided for @homeHeroTitle.
  ///
  /// In uz, this message translates to:
  /// **'Huquqingizni biling, huquqingizni himoya qiling'**
  String get homeHeroTitle;

  /// No description provided for @homeHeroSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Bilim — eng yaxshi himoya'**
  String get homeHeroSubtitle;

  /// No description provided for @homeQuickAccessTitle.
  ///
  /// In uz, this message translates to:
  /// **'Tezkor kirish'**
  String get homeQuickAccessTitle;

  /// No description provided for @homeQuickMore.
  ///
  /// In uz, this message translates to:
  /// **'Ko\'proq'**
  String get homeQuickMore;

  /// No description provided for @homeQuickDocuments.
  ///
  /// In uz, this message translates to:
  /// **'Hujjatlar'**
  String get homeQuickDocuments;

  /// No description provided for @homeQuickSaved.
  ///
  /// In uz, this message translates to:
  /// **'Saqlanganlar'**
  String get homeQuickSaved;

  /// No description provided for @homeQuickEmergency.
  ///
  /// In uz, this message translates to:
  /// **'Tezkor yordam'**
  String get homeQuickEmergency;

  /// HALOLLIK: bu bo'lim shaxsiylashtirilgan tavsiya EMAS — `getPosts()` qaytargan eng yangi hamjamiyat savollari ko'rsatiladi. Reyting yoki profil bo'yicha saralash mavjud emas, shuning uchun matn 'siz uchun tanlandi' degan da'voni qilmaydi.
  ///
  /// In uz, this message translates to:
  /// **'Siz uchun tavsiya etamiz'**
  String get homeRecommendedTitle;

  /// Savol oxirgi 3 kun ichida yaratilgan bo'lsa ko'rinadi (`created_at` bo'yicha, real qiymat).
  ///
  /// In uz, this message translates to:
  /// **'Yangi'**
  String get communityNewBadge;

  /// No description provided for @homeCommunityEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Hamjamiyatda hali savol yo\'q — birinchi bo\'lib so\'rang'**
  String get homeCommunityEmpty;

  /// No description provided for @emergencyQuickTitle.
  ///
  /// In uz, this message translates to:
  /// **'Tezkor Huquqiy Himoya'**
  String get emergencyQuickTitle;

  /// No description provided for @emergencyQuickSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Hibs, tintuv, so\'roq va 102/1002 ishonch raqamlari'**
  String get emergencyQuickSubtitle;

  /// No description provided for @faqBannerTitle.
  ///
  /// In uz, this message translates to:
  /// **'Ko\'p beriladigan savollar'**
  String get faqBannerTitle;

  /// No description provided for @faqBannerBadge.
  ///
  /// In uz, this message translates to:
  /// **'TOP 20+'**
  String get faqBannerBadge;

  /// No description provided for @faqBannerSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Eng ommabop yuridik keyslar va tayyor yechimlar'**
  String get faqBannerSubtitle;

  /// No description provided for @cabinetTitle.
  ///
  /// In uz, this message translates to:
  /// **'Shaxsiy Kabinet'**
  String get cabinetTitle;

  /// No description provided for @cabinetTabProfile.
  ///
  /// In uz, this message translates to:
  /// **'Profil'**
  String get cabinetTabProfile;

  /// No description provided for @cabinetTabConsultations.
  ///
  /// In uz, this message translates to:
  /// **'Konsultatsiyalar'**
  String get cabinetTabConsultations;

  /// No description provided for @cabinetTabBuilder.
  ///
  /// In uz, this message translates to:
  /// **'Konstruktor'**
  String get cabinetTabBuilder;

  /// No description provided for @cabinetTabOfflineCases.
  ///
  /// In uz, this message translates to:
  /// **'Oflayn Keyslar'**
  String get cabinetTabOfflineCases;

  /// No description provided for @recentCasesTitle.
  ///
  /// In uz, this message translates to:
  /// **'Mening so\'nggi murojaatlarim'**
  String get recentCasesTitle;

  /// No description provided for @recentCasesSeeAll.
  ///
  /// In uz, this message translates to:
  /// **'Barchasi ({count})'**
  String recentCasesSeeAll(int count);

  /// No description provided for @legalBasisCount.
  ///
  /// In uz, this message translates to:
  /// **'{count} ta Lex.uz moddasi'**
  String legalBasisCount(int count);

  /// No description provided for @actionRead.
  ///
  /// In uz, this message translates to:
  /// **'O\'qish'**
  String get actionRead;

  /// No description provided for @recentCaseDetailTitle.
  ///
  /// In uz, this message translates to:
  /// **'Murojaat Tahlili'**
  String get recentCaseDetailTitle;

  /// No description provided for @trendingTitle.
  ///
  /// In uz, this message translates to:
  /// **'Ko\'p beriladigan yuridik savollar'**
  String get trendingTitle;

  /// No description provided for @trendingEmptyInCategory.
  ///
  /// In uz, this message translates to:
  /// **'Ushbu kategoriya bo\'yicha savollar topilmadi'**
  String get trendingEmptyInCategory;

  /// No description provided for @casesCount.
  ///
  /// In uz, this message translates to:
  /// **'{count} ta keys'**
  String casesCount(int count);

  /// No description provided for @actionReadAnalysis.
  ///
  /// In uz, this message translates to:
  /// **'Tahlilni o\'qish'**
  String get actionReadAnalysis;

  /// HALOLLIK: ilgari 'AI maslahat olish' edi. Tugma tahlil ekranini savol bilan to'ldirib ochadi; javobni model bermasligi mumkin.
  ///
  /// In uz, this message translates to:
  /// **'Ushbu masala bo\'yicha huquqiy tahlil olish'**
  String get faqAskAiAction;

  /// No description provided for @faqSearchHint.
  ///
  /// In uz, this message translates to:
  /// **'Savollarni qidirish (masalan: aliment, jarima)...'**
  String get faqSearchHint;

  /// No description provided for @faqLegalCasesCount.
  ///
  /// In uz, this message translates to:
  /// **'{count} ta yuridik keys'**
  String faqLegalCasesCount(int count);

  /// No description provided for @faqWithLexUz.
  ///
  /// In uz, this message translates to:
  /// **'Lex.uz moddalari bilan'**
  String get faqWithLexUz;

  /// No description provided for @faqNoMatches.
  ///
  /// In uz, this message translates to:
  /// **'Mos keluvchi savollar topilmadi'**
  String get faqNoMatches;

  /// No description provided for @faqNoMatchesHint.
  ///
  /// In uz, this message translates to:
  /// **'Boshqa kalit so\'z yoki toifani tanlab ko\'ring'**
  String get faqNoMatchesHint;

  /// No description provided for @emergencyRightsTitle.
  ///
  /// In uz, this message translates to:
  /// **'Tezkor Huquqlar'**
  String get emergencyRightsTitle;

  /// No description provided for @emergencyCallFailed.
  ///
  /// In uz, this message translates to:
  /// **'Qo\'ng\'iroq qilib bo\'lmadi: {phone}'**
  String emergencyCallFailed(String phone);

  /// No description provided for @emergencyHotlinesTitle.
  ///
  /// In uz, this message translates to:
  /// **'Tezkor Ishonch Telefonlari'**
  String get emergencyHotlinesTitle;

  /// No description provided for @emergencyProtocolsTitle.
  ///
  /// In uz, this message translates to:
  /// **'Favqulodda Huquqiy Himoya Protokollari'**
  String get emergencyProtocolsTitle;

  /// No description provided for @hotlineProsecutor.
  ///
  /// In uz, this message translates to:
  /// **'Bosh Prokuratura'**
  String get hotlineProsecutor;

  /// No description provided for @hotlineInterior.
  ///
  /// In uz, this message translates to:
  /// **'Ichki Ishlar (IIV)'**
  String get hotlineInterior;

  /// No description provided for @hotlineOmbudsman.
  ///
  /// In uz, this message translates to:
  /// **'Ombudsman'**
  String get hotlineOmbudsman;

  /// No description provided for @hotlineLaborInspection.
  ///
  /// In uz, this message translates to:
  /// **'Mehnat Inspeksiyasi'**
  String get hotlineLaborInspection;

  /// No description provided for @savedCasesTitle.
  ///
  /// In uz, this message translates to:
  /// **'Saqlangan keyslar'**
  String get savedCasesTitle;

  /// No description provided for @savedCasesEmptyTitle.
  ///
  /// In uz, this message translates to:
  /// **'Saqlangan keyslar mavjud emas'**
  String get savedCasesEmptyTitle;

  /// No description provided for @savedCasesEmptyBody.
  ///
  /// In uz, this message translates to:
  /// **'Yuridik maslahatlarni saqlab qo\'yish orqali ularni internetsiz, istalgan vaqtda qayta ko\'rishingiz mumkin.'**
  String get savedCasesEmptyBody;

  /// No description provided for @savedCaseQuestionQuoted.
  ///
  /// In uz, this message translates to:
  /// **'Savol: \"{query}\"'**
  String savedCaseQuestionQuoted(String query);

  /// No description provided for @actionViewDetails.
  ///
  /// In uz, this message translates to:
  /// **'Batafsil ko\'rish'**
  String get actionViewDetails;

  /// No description provided for @savedCaseDetailTitle.
  ///
  /// In uz, this message translates to:
  /// **'Saqlangan Yuridik Keys'**
  String get savedCaseDetailTitle;

  /// No description provided for @homeCatTraffic.
  ///
  /// In uz, this message translates to:
  /// **'Yo\'l harakati'**
  String get homeCatTraffic;

  /// No description provided for @homeCatAdminFines.
  ///
  /// In uz, this message translates to:
  /// **'Ma\'muriy jarimalar'**
  String get homeCatAdminFines;

  /// No description provided for @homeCatConsumer.
  ///
  /// In uz, this message translates to:
  /// **'Iste\'molchi huquqi'**
  String get homeCatConsumer;

  /// No description provided for @homeCatHousing.
  ///
  /// In uz, this message translates to:
  /// **'Uy-joy va kadastr'**
  String get homeCatHousing;

  /// No description provided for @homeCatTax.
  ///
  /// In uz, this message translates to:
  /// **'Soliq masalalari'**
  String get homeCatTax;

  /// No description provided for @homeCatBanking.
  ///
  /// In uz, this message translates to:
  /// **'Bank va kredit'**
  String get homeCatBanking;

  /// No description provided for @homeCatInheritance.
  ///
  /// In uz, this message translates to:
  /// **'Mulk va meros'**
  String get homeCatInheritance;

  /// No description provided for @homeCatGovServices.
  ///
  /// In uz, this message translates to:
  /// **'Davlat xizmatlari'**
  String get homeCatGovServices;

  /// No description provided for @homeCatCourt.
  ///
  /// In uz, this message translates to:
  /// **'Sud masalalari'**
  String get homeCatCourt;

  /// No description provided for @homeCatBusiness.
  ///
  /// In uz, this message translates to:
  /// **'Biznes va shartnomalar'**
  String get homeCatBusiness;

  /// No description provided for @aiAnalystSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'O\'zbekiston huquqiy tahlilchisi'**
  String get aiAnalystSubtitle;

  /// No description provided for @aiWriteSituationTitle.
  ///
  /// In uz, this message translates to:
  /// **'Huquqiy vaziyatingizni yozing'**
  String get aiWriteSituationTitle;

  /// No description provided for @aiQueryHint.
  ///
  /// In uz, this message translates to:
  /// **'Vaziyatingizni batafsil yozing (masalan: \'Menga radar jarimasi keldi, 2 kundan keyin yana jarima yozildi...\')...'**
  String get aiQueryHint;

  /// No description provided for @aiGetAdviceButton.
  ///
  /// In uz, this message translates to:
  /// **'Huquqiy tahlil olish'**
  String get aiGetAdviceButton;

  /// No description provided for @aiAnalyzingLexUz.
  ///
  /// In uz, this message translates to:
  /// **'Lex.uz moddalari tahlil qilinmoqda...'**
  String get aiAnalyzingLexUz;

  /// No description provided for @aiCommonSituations.
  ///
  /// In uz, this message translates to:
  /// **'Ko\'p uchraydigan huquqiy vaziyatlar'**
  String get aiCommonSituations;

  /// No description provided for @aiFullAnalysisCopied.
  ///
  /// In uz, this message translates to:
  /// **'To\'liq huquqiy tahlil nusxalandi!'**
  String get aiFullAnalysisCopied;

  /// No description provided for @aiBuildDocumentAction.
  ///
  /// In uz, this message translates to:
  /// **'Ariza shakllantirish'**
  String get aiBuildDocumentAction;

  /// No description provided for @aiQueryEmptyError.
  ///
  /// In uz, this message translates to:
  /// **'Iltimos, huquqiy savol yoki vaziyatingizni yozing.'**
  String get aiQueryEmptyError;

  /// No description provided for @actionCopyAnalysis.
  ///
  /// In uz, this message translates to:
  /// **'Tahlilni nusxalash'**
  String get actionCopyAnalysis;

  /// No description provided for @aiChipUnfairDismissal.
  ///
  /// In uz, this message translates to:
  /// **'Ishdan nohaq bo\'shatish'**
  String get aiChipUnfairDismissal;

  /// No description provided for @aiChipConsumerReturn.
  ///
  /// In uz, this message translates to:
  /// **'Iste\'molchi huquqi (tovarni qaytarish)'**
  String get aiChipConsumerReturn;

  /// No description provided for @aiChipAlimony.
  ///
  /// In uz, this message translates to:
  /// **'Aliment undirish'**
  String get aiChipAlimony;

  /// No description provided for @aiChipTrafficFine.
  ///
  /// In uz, this message translates to:
  /// **'Yo\'l harakati jarimasi'**
  String get aiChipTrafficFine;

  /// No description provided for @aiChipDebtReceipt.
  ///
  /// In uz, this message translates to:
  /// **'Qarz va tilxat'**
  String get aiChipDebtReceipt;

  /// No description provided for @aiSummaryTitle.
  ///
  /// In uz, this message translates to:
  /// **'Oddiy tilda tushuntirish (Xulosa)'**
  String get aiSummaryTitle;

  /// No description provided for @aiStepsTitle.
  ///
  /// In uz, this message translates to:
  /// **'Bosqichma-bosqich harakatlar'**
  String get aiStepsTitle;

  /// No description provided for @aiLegalBasisTitle.
  ///
  /// In uz, this message translates to:
  /// **'Qonuniy asoslar (Lex.uz)'**
  String get aiLegalBasisTitle;

  /// HALOLLIK: tasdiqlangan qonun bazasida so'rovga aniq mos keladigan modda topilmaganda ko'rsatiladi. Ilgari bu holatda korpusning birinchi 3 moddasi (Konstitutsiya) 'Huquqiy asos' sifatida ko'rsatilardi — aloqasi bo'lmasa ham.
  ///
  /// In uz, this message translates to:
  /// **'Mos keladigan modda topilmadi'**
  String get aiLegalBasisNoneTitle;

  /// Modda topilmagan holatning tushuntirishi. Foydalanuvchini noto'g'ri qonuniy asosga tayanishdan ogohlantiradi.
  ///
  /// In uz, this message translates to:
  /// **'Tasdiqlangan bazamizda ushbu savolga aniq mos keladigan qonun moddasi topilmadi. Quyidagi tahlil UMUMIY xarakterda va qonuniy asos sifatida ishlatilmasligi kerak. Aniq modda kerak bo\'lsa, Lex.uz saytiga yoki yurist maslahatiga murojaat qiling.'**
  String get aiLegalBasisNoneBody;

  /// No description provided for @aiRiskTitle.
  ///
  /// In uz, this message translates to:
  /// **'Risk va Muddatlar tahlili'**
  String get aiRiskTitle;

  /// No description provided for @aiEmergencyAlertTitle.
  ///
  /// In uz, this message translates to:
  /// **'DIQQAT: Favqulodda Huquqiy Xavf'**
  String get aiEmergencyAlertTitle;

  /// No description provided for @aiClarificationTitle.
  ///
  /// In uz, this message translates to:
  /// **'Aniqroq maslahat uchun qo\'shimcha savollar'**
  String get aiClarificationTitle;

  /// No description provided for @aiClarificationBody.
  ///
  /// In uz, this message translates to:
  /// **'Vaziyatingizga yanada aniq va to\'g\'ri qonuniy maslahat berish uchun quyidagi tafsilotlarni kiritish tavsiya etiladi:'**
  String get aiClarificationBody;

  /// No description provided for @aiSummarySubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Yuridik jargonsiz sodda tushuntirish'**
  String get aiSummarySubtitle;

  /// No description provided for @aiAudioStarted.
  ///
  /// In uz, this message translates to:
  /// **'Audio eshittirish boshlandi (Ovozli tahlil)...'**
  String get aiAudioStarted;

  /// No description provided for @aiAudioStopped.
  ///
  /// In uz, this message translates to:
  /// **'Audio to\'xtatildi'**
  String get aiAudioStopped;

  /// No description provided for @aiSummaryCopied.
  ///
  /// In uz, this message translates to:
  /// **'Xulosa matni nusxalandi!'**
  String get aiSummaryCopied;

  /// No description provided for @actionListenAudio.
  ///
  /// In uz, this message translates to:
  /// **'Ovozli tinglash'**
  String get actionListenAudio;

  /// No description provided for @aiStepsProgress.
  ///
  /// In uz, this message translates to:
  /// **'{total} tadan {done} tasi bajarildi'**
  String aiStepsProgress(int done, int total);

  /// No description provided for @aiLexUzBaseSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Lex.uz rasmiy qonunchilik bazasi'**
  String get aiLexUzBaseSubtitle;

  /// No description provided for @aiOfficialDocsSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Rasmiy qonunchilik hujjatlari'**
  String get aiOfficialDocsSubtitle;

  /// No description provided for @aiLexUzOpenFailed.
  ///
  /// In uz, this message translates to:
  /// **'Lex.uz havolasini ochib bo\'lmadi'**
  String get aiLexUzOpenFailed;

  /// No description provided for @aiArticleCopied.
  ///
  /// In uz, this message translates to:
  /// **'{article} matni nusxalandi!'**
  String aiArticleCopied(String article);

  /// No description provided for @statusInForce.
  ///
  /// In uz, this message translates to:
  /// **'Amalda'**
  String get statusInForce;

  /// No description provided for @actionOpenLexUz.
  ///
  /// In uz, this message translates to:
  /// **'Lex.uz\'da to\'liq o\'qish'**
  String get actionOpenLexUz;

  /// No description provided for @aiRiskSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Xolis huquqiy tahlil & cheklovlar'**
  String get aiRiskSubtitle;

  /// No description provided for @aiRiskGaugeLabel.
  ///
  /// In uz, this message translates to:
  /// **'Xavf darajasi ko\'rsatkichi'**
  String get aiRiskGaugeLabel;

  /// No description provided for @riskScaleLow.
  ///
  /// In uz, this message translates to:
  /// **'Past xavf'**
  String get riskScaleLow;

  /// No description provided for @riskScaleMedium.
  ///
  /// In uz, this message translates to:
  /// **'O\'rtacha'**
  String get riskScaleMedium;

  /// No description provided for @riskScaleHigh.
  ///
  /// In uz, this message translates to:
  /// **'Yuqori'**
  String get riskScaleHigh;

  /// No description provided for @riskScaleCritical.
  ///
  /// In uz, this message translates to:
  /// **'Kritik'**
  String get riskScaleCritical;

  /// No description provided for @aiDeadlineRemaining.
  ///
  /// In uz, this message translates to:
  /// **'Murojaat qilish uchun qolgan taxminiy muddat: {days} kun'**
  String aiDeadlineRemaining(int days);

  /// No description provided for @aiLimitationsTitle.
  ///
  /// In uz, this message translates to:
  /// **'Muhim cheklovlar va ogohlantirishlar:'**
  String get aiLimitationsTitle;

  /// No description provided for @aiLawyerRequiredWarning.
  ///
  /// In uz, this message translates to:
  /// **'Ushbu ish bo\'yicha mustaqil harakat qilish yutqazish xavfini oshiradi. Malakali advokat bilan shartnoma tuzish tavsiya etiladi.'**
  String get aiLawyerRequiredWarning;

  /// No description provided for @aiLawyerRecommendedWarning.
  ///
  /// In uz, this message translates to:
  /// **'Ushbu holatda mustaqil harakat qilish xavfli. Malakali advokat bilan maslahatlashish tavsiya etiladi.'**
  String get aiLawyerRecommendedWarning;

  /// No description provided for @aiLawyerEscalationTitle.
  ///
  /// In uz, this message translates to:
  /// **'Keyingi qadam: advokat bilan davom ettirish'**
  String get aiLawyerEscalationTitle;

  /// No description provided for @aiLawyerEscalationAction.
  ///
  /// In uz, this message translates to:
  /// **'Tasdiqlangan advokatni ko\'rish'**
  String get aiLawyerEscalationAction;

  /// No description provided for @aiLawyerEscalationMatched.
  ///
  /// In uz, this message translates to:
  /// **'Mos yo\'nalish: {area}'**
  String aiLawyerEscalationMatched(String area);

  /// No description provided for @aiLawyerEscalationNoMatch.
  ///
  /// In uz, this message translates to:
  /// **'Yo\'nalish avtomatik aniqlanmadi — ro\'yxatdan o\'zingiz tanlaysiz.'**
  String get aiLawyerEscalationNoMatch;

  /// No description provided for @aiLawyerEscalationMandatory.
  ///
  /// In uz, this message translates to:
  /// **'Bu toifadagi ishda litsenziyaga ega advokat MAJBURIY.'**
  String get aiLawyerEscalationMandatory;

  /// No description provided for @aiDocumentPickTemplate.
  ///
  /// In uz, this message translates to:
  /// **'Bu javob uchun aniq hujjat shabloni tanlanmadi. Ro\'yxatdan o\'zingizga mosini tanlang.'**
  String get aiDocumentPickTemplate;

  /// No description provided for @aiDocumentLoadFailed.
  ///
  /// In uz, this message translates to:
  /// **'Hujjat shablonlarini yuklab bo\'lmadi. Qaytadan urinib ko\'ring.'**
  String get aiDocumentLoadFailed;

  /// No description provided for @riskLevelLow.
  ///
  /// In uz, this message translates to:
  /// **'Past xavf'**
  String get riskLevelLow;

  /// No description provided for @riskLevelMedium.
  ///
  /// In uz, this message translates to:
  /// **'O\'rtacha xavf'**
  String get riskLevelMedium;

  /// No description provided for @riskLevelHigh.
  ///
  /// In uz, this message translates to:
  /// **'Yuqori xavf'**
  String get riskLevelHigh;

  /// No description provided for @riskLevelCritical.
  ///
  /// In uz, this message translates to:
  /// **'Kritik xavf (Favqulodda)'**
  String get riskLevelCritical;

  /// No description provided for @emergencyRedFlagsTitle.
  ///
  /// In uz, this message translates to:
  /// **'Xavfli holatlar (Red Flags):'**
  String get emergencyRedFlagsTitle;

  /// No description provided for @emergencyConstitutionalRightsTitle.
  ///
  /// In uz, this message translates to:
  /// **'Konstitutsiyaviy huquqlaringiz:'**
  String get emergencyConstitutionalRightsTitle;

  /// No description provided for @emergencyImmediateActionsTitle.
  ///
  /// In uz, this message translates to:
  /// **'Zudlik bilan nima qilish kerak:'**
  String get emergencyImmediateActionsTitle;

  /// No description provided for @emergencyMirandaTitle.
  ///
  /// In uz, this message translates to:
  /// **'Miranda Qoidasi'**
  String get emergencyMirandaTitle;

  /// No description provided for @emergencyMirandaArticleLabel.
  ///
  /// In uz, this message translates to:
  /// **'O\'zbekiston Respublikasi Konstitutsiyasi 28-moddasi:'**
  String get emergencyMirandaArticleLabel;

  /// No description provided for @emergencyMirandaScriptLabel.
  ///
  /// In uz, this message translates to:
  /// **'Tergovchi yoki xodimga aytiladigan rasmiy so\'z:'**
  String get emergencyMirandaScriptLabel;

  /// No description provided for @emergencyMirandaLawQuote.
  ///
  /// In uz, this message translates to:
  /// **'\"Ushlab turish chog\'ida shaxsga uning huquqlari va ushlab turilishi asoslari tushunarli tilda tushuntirilishi shart.\"'**
  String get emergencyMirandaLawQuote;

  /// No description provided for @emergencyMirandaScriptText.
  ///
  /// In uz, this message translates to:
  /// **'\"Men O\'zbekiston Konstitutsiyasining 28 va 29-moddalariga asosan, advokatim yetib kelmaguncha har qanday ko\'rsatma berishdan bosh tortaman va sukut saqlash huquqimdan foydalanaman.\"'**
  String get emergencyMirandaScriptText;

  /// No description provided for @emergencyCallAction.
  ///
  /// In uz, this message translates to:
  /// **'Qo\'ng\'iroq ({phone})'**
  String emergencyCallAction(String phone);

  /// No description provided for @actionCallHotline.
  ///
  /// In uz, this message translates to:
  /// **'Ishonch telefoniga qo\'ng\'iroq qilish'**
  String get actionCallHotline;

  /// No description provided for @searchHint.
  ///
  /// In uz, this message translates to:
  /// **'Qonun, advokat, xizmat yoki shablon...'**
  String get searchHint;

  /// No description provided for @searchError.
  ///
  /// In uz, this message translates to:
  /// **'Qidiruvda xatolik yuz berdi'**
  String get searchError;

  /// No description provided for @searchRecentTitle.
  ///
  /// In uz, this message translates to:
  /// **'So\'nggi qidiruvlar'**
  String get searchRecentTitle;

  /// No description provided for @actionClear.
  ///
  /// In uz, this message translates to:
  /// **'Tozalash'**
  String get actionClear;

  /// No description provided for @searchPopularTitle.
  ///
  /// In uz, this message translates to:
  /// **'Ommabop huquqiy mavzular'**
  String get searchPopularTitle;

  /// No description provided for @searchFilterLaws.
  ///
  /// In uz, this message translates to:
  /// **'Qonunlar'**
  String get searchFilterLaws;

  /// No description provided for @searchFilterTemplates.
  ///
  /// In uz, this message translates to:
  /// **'Shablonlar'**
  String get searchFilterTemplates;

  /// No description provided for @searchTopicAlimonyTitle.
  ///
  /// In uz, this message translates to:
  /// **'Aliment undirish tartibi'**
  String get searchTopicAlimonyTitle;

  /// No description provided for @searchTopicAlimonySubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Oila kodeksi 96-moddasi va sud buyrug\'i arizasi'**
  String get searchTopicAlimonySubtitle;

  /// No description provided for @searchTopicDismissalTitle.
  ///
  /// In uz, this message translates to:
  /// **'Noqonuniy ishdan bo\'shatish'**
  String get searchTopicDismissalTitle;

  /// No description provided for @searchTopicDismissalSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Mehnat kodeksi kafolatlari va tiklash da\'vosi'**
  String get searchTopicDismissalSubtitle;

  /// No description provided for @searchTopicRefundTitle.
  ///
  /// In uz, this message translates to:
  /// **'Sifatsiz tovar pulini qaytarish'**
  String get searchTopicRefundTitle;

  /// No description provided for @searchTopicRefundSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Iste\'molchilar huquqlarini himoya qilish qonuni'**
  String get searchTopicRefundSubtitle;

  /// No description provided for @searchTopicFineTitle.
  ///
  /// In uz, this message translates to:
  /// **'Yo\'l harakati jarimalari ustidan shikoyat'**
  String get searchTopicFineTitle;

  /// No description provided for @searchTopicFineSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'YPX qarorlari ustidan apellyatsiya berish'**
  String get searchTopicFineSubtitle;

  /// No description provided for @searchBadgeLaw.
  ///
  /// In uz, this message translates to:
  /// **'Qonun hujjati'**
  String get searchBadgeLaw;

  /// No description provided for @searchBadgeService.
  ///
  /// In uz, this message translates to:
  /// **'Davlat xizmati'**
  String get searchBadgeService;

  /// No description provided for @searchBadgeTemplate.
  ///
  /// In uz, this message translates to:
  /// **'Hujjat shabloni'**
  String get searchBadgeTemplate;

  /// No description provided for @searchBadgeQuestion.
  ///
  /// In uz, this message translates to:
  /// **'Hamjamiyat forumi'**
  String get searchBadgeQuestion;

  /// No description provided for @searchLexUzBadge.
  ///
  /// In uz, this message translates to:
  /// **'Lex.uz ↗'**
  String get searchLexUzBadge;

  /// No description provided for @searchBuilderBadge.
  ///
  /// In uz, this message translates to:
  /// **'Konstruktor ⚡'**
  String get searchBuilderBadge;

  /// No description provided for @searchOfficialLawyer.
  ///
  /// In uz, this message translates to:
  /// **'Rasmiy yurist'**
  String get searchOfficialLawyer;

  /// No description provided for @statusFree.
  ///
  /// In uz, this message translates to:
  /// **'Bepul'**
  String get statusFree;

  /// No description provided for @searchCostBhmPercent.
  ///
  /// In uz, this message translates to:
  /// **'{percent}% BHM'**
  String searchCostBhmPercent(String percent);

  /// No description provided for @searchTemplateAuthority.
  ///
  /// In uz, this message translates to:
  /// **'Organ: {authority}'**
  String searchTemplateAuthority(String authority);

  /// No description provided for @searchEmptyTitle.
  ///
  /// In uz, this message translates to:
  /// **'Hech qanday natija topilmadi'**
  String get searchEmptyTitle;

  /// No description provided for @searchEmptyBody.
  ///
  /// In uz, this message translates to:
  /// **'Boshqa kalit so\'zlar bilan qidirib ko\'ring yoki boshqa toifa filtrini tanlang.'**
  String get searchEmptyBody;

  /// No description provided for @actionReload.
  ///
  /// In uz, this message translates to:
  /// **'Qayta yuklash'**
  String get actionReload;

  /// No description provided for @actionSaved.
  ///
  /// In uz, this message translates to:
  /// **'Saqlandi'**
  String get actionSaved;

  /// No description provided for @actionViewOnLexUz.
  ///
  /// In uz, this message translates to:
  /// **'Lex.uz da ko\'rish'**
  String get actionViewOnLexUz;

  /// No description provided for @badgePopular.
  ///
  /// In uz, this message translates to:
  /// **'Mashhur'**
  String get badgePopular;

  /// No description provided for @errorCannotOpenLink.
  ///
  /// In uz, this message translates to:
  /// **'Havolani ochib bo\'lmadi'**
  String get errorCannotOpenLink;

  /// No description provided for @categorySocialProtection.
  ///
  /// In uz, this message translates to:
  /// **'Ijtimoiy himoya'**
  String get categorySocialProtection;

  /// No description provided for @servicesTitle.
  ///
  /// In uz, this message translates to:
  /// **'Davlat xizmatlari va Qo\'llanmalar'**
  String get servicesTitle;

  /// No description provided for @servicesSearchHint.
  ///
  /// In uz, this message translates to:
  /// **'Davlat xizmatlari yoki qo\'llanmalarni qidirish...'**
  String get servicesSearchHint;

  /// No description provided for @servicesEmptyTitle.
  ///
  /// In uz, this message translates to:
  /// **'Xizmatlar topilmadi'**
  String get servicesEmptyTitle;

  /// No description provided for @serviceDaysShort.
  ///
  /// In uz, this message translates to:
  /// **'{days} kun'**
  String serviceDaysShort(int days);

  /// No description provided for @serviceGuideTitle.
  ///
  /// In uz, this message translates to:
  /// **'Xizmat qo\'llanmasi'**
  String get serviceGuideTitle;

  /// No description provided for @serviceFreeBadge.
  ///
  /// In uz, this message translates to:
  /// **'Bepul xizmat'**
  String get serviceFreeBadge;

  /// No description provided for @serviceCostBhm.
  ///
  /// In uz, this message translates to:
  /// **'{amount} BHM'**
  String serviceCostBhm(String amount);

  /// No description provided for @serviceVerifiedByLaw.
  ///
  /// In uz, this message translates to:
  /// **'O\'zbekiston Qonunchiligi asosida tasdiqlangan'**
  String get serviceVerifiedByLaw;

  /// No description provided for @serviceLastVerified.
  ///
  /// In uz, this message translates to:
  /// **'Oxirgi tekshiruv: {year}-yil {month}-oy'**
  String serviceLastVerified(int year, int month);

  /// No description provided for @serviceLawUpdateActive.
  ///
  /// In uz, this message translates to:
  /// **'Qonunchilik yangilanishi: Faol'**
  String get serviceLawUpdateActive;

  /// No description provided for @serviceProcessingTime.
  ///
  /// In uz, this message translates to:
  /// **'Ko\'rib chiqish muddati'**
  String get serviceProcessingTime;

  /// No description provided for @serviceWorkDays.
  ///
  /// In uz, this message translates to:
  /// **'{days} ish kuni'**
  String serviceWorkDays(int days);

  /// No description provided for @serviceFeeLabel.
  ///
  /// In uz, this message translates to:
  /// **'Davlat boji / To\'lov'**
  String get serviceFeeLabel;

  /// No description provided for @serviceNoFee.
  ///
  /// In uz, this message translates to:
  /// **'To\'lovsiz'**
  String get serviceNoFee;

  /// No description provided for @serviceDescriptionTitle.
  ///
  /// In uz, this message translates to:
  /// **'Tavsif va Maqsad'**
  String get serviceDescriptionTitle;

  /// No description provided for @serviceLegalBasisTitle.
  ///
  /// In uz, this message translates to:
  /// **'Rasmiy Huquqiy Asos'**
  String get serviceLegalBasisTitle;

  /// No description provided for @serviceRequiredDocsTitle.
  ///
  /// In uz, this message translates to:
  /// **'Kerakli hujjatlar'**
  String get serviceRequiredDocsTitle;

  /// No description provided for @serviceStepsTitle.
  ///
  /// In uz, this message translates to:
  /// **'Bosqichma-bosqich harakatlar'**
  String get serviceStepsTitle;

  /// No description provided for @serviceStepOnline.
  ///
  /// In uz, this message translates to:
  /// **'Onlayn'**
  String get serviceStepOnline;

  /// No description provided for @serviceStepPayment.
  ///
  /// In uz, this message translates to:
  /// **'To\'lov'**
  String get serviceStepPayment;

  /// No description provided for @serviceStepAppeal.
  ///
  /// In uz, this message translates to:
  /// **'Shikoyat'**
  String get serviceStepAppeal;

  /// No description provided for @serviceStepOpenPortal.
  ///
  /// In uz, this message translates to:
  /// **'Ushbu bosqichni portalda bajarish'**
  String get serviceStepOpenPortal;

  /// No description provided for @serviceOpenMyGov.
  ///
  /// In uz, this message translates to:
  /// **'my.gov.uz orqali ariza berish'**
  String get serviceOpenMyGov;

  /// No description provided for @documentBuilderTitle.
  ///
  /// In uz, this message translates to:
  /// **'Hujjatlar Konstruktori'**
  String get documentBuilderTitle;

  /// No description provided for @templatesSearchHint.
  ///
  /// In uz, this message translates to:
  /// **'Shablon nomi, modda yoki sohani qidirish...'**
  String get templatesSearchHint;

  /// No description provided for @templatesEmptyTitle.
  ///
  /// In uz, this message translates to:
  /// **'Shablonlar topilmadi'**
  String get templatesEmptyTitle;

  /// No description provided for @templateFieldsCount.
  ///
  /// In uz, this message translates to:
  /// **'{count} ta maydon'**
  String templateFieldsCount(int count);

  /// No description provided for @documentLegalBasisLabel.
  ///
  /// In uz, this message translates to:
  /// **'Rasmiy Yuridik Asos:'**
  String get documentLegalBasisLabel;

  /// No description provided for @documentFillFieldsTitle.
  ///
  /// In uz, this message translates to:
  /// **'Maydonlarni to\'ldiring:'**
  String get documentFillFieldsTitle;

  /// No description provided for @documentGenerateAction.
  ///
  /// In uz, this message translates to:
  /// **'Hujjatni shakllantirish va ko\'rish'**
  String get documentGenerateAction;

  /// No description provided for @documentPreviewTitle.
  ///
  /// In uz, this message translates to:
  /// **'Tayyor Hujjat Ko\'rinishi'**
  String get documentPreviewTitle;

  /// No description provided for @documentSaveTooltip.
  ///
  /// In uz, this message translates to:
  /// **'Saqlanganlarga qo\'shish'**
  String get documentSaveTooltip;

  /// No description provided for @documentCopiedSnack.
  ///
  /// In uz, this message translates to:
  /// **'Hujjat matni xotiraga nusxalandi!'**
  String get documentCopiedSnack;

  /// No description provided for @documentSavedSnack.
  ///
  /// In uz, this message translates to:
  /// **'Hujjat muvaffaqiyatli saqlandi!'**
  String get documentSavedSnack;

  /// No description provided for @documentLegalBasisWith.
  ///
  /// In uz, this message translates to:
  /// **'Yuridik Asos: {basis}'**
  String documentLegalBasisWith(String basis);

  /// No description provided for @documentReadyToPrint.
  ///
  /// In uz, this message translates to:
  /// **'Rasmiy talablar asosida shakllantirilgan. Chop etishga tayyor.'**
  String get documentReadyToPrint;

  /// No description provided for @expertsTitle.
  ///
  /// In uz, this message translates to:
  /// **'Tasdiqlangan Advokatlar'**
  String get expertsTitle;

  /// No description provided for @expertsApplyTooltip.
  ///
  /// In uz, this message translates to:
  /// **'Advokat sifatida a\'zo bo\'lish'**
  String get expertsApplyTooltip;

  /// No description provided for @expertsHeaderTitle.
  ///
  /// In uz, this message translates to:
  /// **'Rasmiy Litsenziyaga Ega Advokatlar'**
  String get expertsHeaderTitle;

  /// No description provided for @expertsHeaderSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Barcha mutaxassislar O\'zbekiston Advokatlar palatasi ro\'yxatidan tekshirilgan.'**
  String get expertsHeaderSubtitle;

  /// No description provided for @expertsSearchHint.
  ///
  /// In uz, this message translates to:
  /// **'Advokat ismi yoki soha bo\'yicha qidiruv...'**
  String get expertsSearchHint;

  /// No description provided for @expertsRegionLabel.
  ///
  /// In uz, this message translates to:
  /// **'Hudud bo\'yicha:'**
  String get expertsRegionLabel;

  /// No description provided for @expertsAllRegions.
  ///
  /// In uz, this message translates to:
  /// **'Barcha viloyatlar'**
  String get expertsAllRegions;

  /// No description provided for @expertsEmptyFiltered.
  ///
  /// In uz, this message translates to:
  /// **'Tanlangan parametrlar bo\'yicha advokatlar topilmadi'**
  String get expertsEmptyFiltered;

  /// AI eskalatsiyasidan kelgan filtr bo'sh natija berganda: qaysi yo'nalish bo'yicha bo'shligini OSHKORA aytadi, aks holda foydalanuvchi 'umuman advokat yo'q' deb tushunadi.
  ///
  /// In uz, this message translates to:
  /// **'\"{area}\" yo\'nalishi bo\'yicha tasdiqlangan advokat hozircha yo\'q.'**
  String expertsEmptyForSpecialization(String area);

  /// Bo'sh filtrlangan ro'yxatdan chiqish harakati — eskalatsiya yo'li boshi berk ko'chaga aylanmasligi uchun.
  ///
  /// In uz, this message translates to:
  /// **'Barcha ixtisosliklarni ko\'rish'**
  String get expertsClearSpecializationFilter;

  /// Hech qanday filtr yoqilmagan holda ro'yxat bo'sh chiqqanda. Bu 'filtr bo'yicha topilmadi' EMAS: ma'lumot bazasida hali tasdiqlangan advokat yo'q.
  ///
  /// In uz, this message translates to:
  /// **'Tasdiqlangan advokatlar ro\'yxati hozircha bo\'sh — advokatlar tekshiruvdan o\'tkazilib qo\'shilmoqda.'**
  String get expertsDirectoryEmpty;

  /// No description provided for @expertVerifiedBadge.
  ///
  /// In uz, this message translates to:
  /// **'Tasdiqlangan'**
  String get expertVerifiedBadge;

  /// No description provided for @expertNameUnknown.
  ///
  /// In uz, this message translates to:
  /// **'Ismi ko\'rsatilmagan'**
  String get expertNameUnknown;

  /// No description provided for @expertSpecializationUnknown.
  ///
  /// In uz, this message translates to:
  /// **'Mutaxassislik ko\'rsatilmagan'**
  String get expertSpecializationUnknown;

  /// No description provided for @expertContact.
  ///
  /// In uz, this message translates to:
  /// **'Bog\'lanish'**
  String get expertContact;

  /// No description provided for @expertExperienceYears.
  ///
  /// In uz, this message translates to:
  /// **'{count} yil tajriba'**
  String expertExperienceYears(int count);

  /// No description provided for @expertWonCases.
  ///
  /// In uz, this message translates to:
  /// **'{count}+ yutilgan ish'**
  String expertWonCases(int count);

  /// No description provided for @expertFeeAmount.
  ///
  /// In uz, this message translates to:
  /// **'{amount} so\'m'**
  String expertFeeAmount(String amount);

  /// No description provided for @expertFeeNegotiable.
  ///
  /// In uz, this message translates to:
  /// **'Kelishuv asosida'**
  String get expertFeeNegotiable;

  /// No description provided for @expertLicenseLine.
  ///
  /// In uz, this message translates to:
  /// **'Litsenziya: {number}'**
  String expertLicenseLine(String number);

  /// No description provided for @expertMetricRating.
  ///
  /// In uz, this message translates to:
  /// **'Reyting'**
  String get expertMetricRating;

  /// No description provided for @expertMetricReviews.
  ///
  /// In uz, this message translates to:
  /// **'{count} ta baho'**
  String expertMetricReviews(int count);

  /// No description provided for @expertNoRating.
  ///
  /// In uz, this message translates to:
  /// **'Baho yo\'q'**
  String get expertNoRating;

  /// No description provided for @expertMetricExperience.
  ///
  /// In uz, this message translates to:
  /// **'Tajriba'**
  String get expertMetricExperience;

  /// No description provided for @expertMetricYears.
  ///
  /// In uz, this message translates to:
  /// **'{count} yil'**
  String expertMetricYears(int count);

  /// No description provided for @expertMetricPractice.
  ///
  /// In uz, this message translates to:
  /// **'Amaliyot'**
  String get expertMetricPractice;

  /// No description provided for @expertMetricWins.
  ///
  /// In uz, this message translates to:
  /// **'Yutuqlar'**
  String get expertMetricWins;

  /// No description provided for @expertMetricWonCases.
  ///
  /// In uz, this message translates to:
  /// **'Yutilgan ish'**
  String get expertMetricWonCases;

  /// No description provided for @expertAboutTitle.
  ///
  /// In uz, this message translates to:
  /// **'Advokat haqida'**
  String get expertAboutTitle;

  /// No description provided for @expertBookConsultation.
  ///
  /// In uz, this message translates to:
  /// **'Konsultatsiyaga Yozilish'**
  String get expertBookConsultation;

  /// No description provided for @expertCall.
  ///
  /// In uz, this message translates to:
  /// **'Qo\'ng\'iroq'**
  String get expertCall;

  /// No description provided for @expertTelegram.
  ///
  /// In uz, this message translates to:
  /// **'Telegram'**
  String get expertTelegram;

  /// No description provided for @expertContactMissing.
  ///
  /// In uz, this message translates to:
  /// **'Aloqa ma\'lumotlari ko\'rsatilmagan'**
  String get expertContactMissing;

  /// No description provided for @expertCallFailed.
  ///
  /// In uz, this message translates to:
  /// **'Qo\'ng\'iroq qilib bo\'lmadi: {phone}'**
  String expertCallFailed(String phone);

  /// No description provided for @expertTelegramFailed.
  ///
  /// In uz, this message translates to:
  /// **'Telegram profilini ochib bo\'lmadi: @{username}'**
  String expertTelegramFailed(String username);

  /// No description provided for @expertApplyTitle.
  ///
  /// In uz, this message translates to:
  /// **'Advokatlik A\'zoligi Uchun Ariza'**
  String get expertApplyTitle;

  /// No description provided for @expertApplyIntro.
  ///
  /// In uz, this message translates to:
  /// **'O\'zbekiston Advokatlar palatasi litsenziyasi ma\'lumotlarini kiriting. Tasdiqlangan mutaxassislar ro\'yxatiga kiritilasiz.'**
  String get expertApplyIntro;

  /// No description provided for @expertApplySpecializationLabel.
  ///
  /// In uz, this message translates to:
  /// **'Mutaxassislik sohasi *'**
  String get expertApplySpecializationLabel;

  /// No description provided for @expertApplySpecializationError.
  ///
  /// In uz, this message translates to:
  /// **'Ixtisoslikni tanlang'**
  String get expertApplySpecializationError;

  /// No description provided for @expertApplyLicenseLabel.
  ///
  /// In uz, this message translates to:
  /// **'Litsenziya raqami (ADV-XXXXX) *'**
  String get expertApplyLicenseLabel;

  /// No description provided for @expertApplyLicenseError.
  ///
  /// In uz, this message translates to:
  /// **'Litsenziya raqamini kiriting'**
  String get expertApplyLicenseError;

  /// No description provided for @expertApplyExperienceLabel.
  ///
  /// In uz, this message translates to:
  /// **'Yuridik staj (yillarda) *'**
  String get expertApplyExperienceLabel;

  /// No description provided for @expertApplyExperienceError.
  ///
  /// In uz, this message translates to:
  /// **'Tajribani kiriting'**
  String get expertApplyExperienceError;

  /// No description provided for @expertApplyWorkplaceLabel.
  ///
  /// In uz, this message translates to:
  /// **'Ish joyi / Advokatlik tuzilmasi'**
  String get expertApplyWorkplaceLabel;

  /// No description provided for @expertApplyFeeLabel.
  ///
  /// In uz, this message translates to:
  /// **'Maslahat narxi (so\'mda, ixtiyoriy)'**
  String get expertApplyFeeLabel;

  /// No description provided for @expertApplySubmit.
  ///
  /// In uz, this message translates to:
  /// **'Ariza yuborish'**
  String get expertApplySubmit;

  /// Ariza qabul qilinganda SnackBar. Server o'z matnini (`apply_for_expert_verification` javobidagi `message`) yuboradi — o'zbek UI aynan uni ko'rsatadi, boshqa tillar SHU matnni oladi. Ilgari bu matn `legal_experts_bloc.dart` ichida hardcoded edi va ingliz UI'da o'zbekcha chiqardi.
  ///
  /// In uz, this message translates to:
  /// **'Ariza muvaffaqiyatli topshirildi.'**
  String get expertApplySuccess;

  /// No description provided for @expertSpecLabor.
  ///
  /// In uz, this message translates to:
  /// **'Mehnat huquqi'**
  String get expertSpecLabor;

  /// No description provided for @expertSpecFamilyProperty.
  ///
  /// In uz, this message translates to:
  /// **'Oila va Mulk huquqi'**
  String get expertSpecFamilyProperty;

  /// No description provided for @expertSpecCriminalDefense.
  ///
  /// In uz, this message translates to:
  /// **'Jinoyat va Tergov himoyasi'**
  String get expertSpecCriminalDefense;

  /// No description provided for @expertSpecTrafficAdmin.
  ///
  /// In uz, this message translates to:
  /// **'Yo\'l harakati va Ma\'muriy jarimalar'**
  String get expertSpecTrafficAdmin;

  /// No description provided for @expertSpecConsumerContracts.
  ///
  /// In uz, this message translates to:
  /// **'Iste\'molchi huquqlari va Shartnomalar'**
  String get expertSpecConsumerContracts;

  /// No description provided for @expertSpecBusinessCorporate.
  ///
  /// In uz, this message translates to:
  /// **'Biznes va Korporativ huquq'**
  String get expertSpecBusinessCorporate;

  /// No description provided for @expertSpecTaxCustoms.
  ///
  /// In uz, this message translates to:
  /// **'Soliq va Bojxona huquqi'**
  String get expertSpecTaxCustoms;

  /// No description provided for @consultationStatusPending.
  ///
  /// In uz, this message translates to:
  /// **'Kutilmoqda'**
  String get consultationStatusPending;

  /// No description provided for @consultationStatusAwaitingPayment.
  ///
  /// In uz, this message translates to:
  /// **'To\'lov kutilmoqda'**
  String get consultationStatusAwaitingPayment;

  /// No description provided for @consultationStatusConfirmed.
  ///
  /// In uz, this message translates to:
  /// **'Tasdiqlangan'**
  String get consultationStatusConfirmed;

  /// No description provided for @consultationStatusInProgress.
  ///
  /// In uz, this message translates to:
  /// **'Jarayonda'**
  String get consultationStatusInProgress;

  /// No description provided for @consultationStatusCompleted.
  ///
  /// In uz, this message translates to:
  /// **'Tugallangan'**
  String get consultationStatusCompleted;

  /// No description provided for @consultationStatusCancelled.
  ///
  /// In uz, this message translates to:
  /// **'Bekor qilingan'**
  String get consultationStatusCancelled;

  /// No description provided for @consultationStatusExpired.
  ///
  /// In uz, this message translates to:
  /// **'Muddati o\'tgan'**
  String get consultationStatusExpired;

  /// No description provided for @consultationStatusDisputed.
  ///
  /// In uz, this message translates to:
  /// **'E\'tirozli'**
  String get consultationStatusDisputed;

  /// No description provided for @consultationAmountUzs.
  ///
  /// In uz, this message translates to:
  /// **'{amount} so\'m'**
  String consultationAmountUzs(String amount);

  /// No description provided for @bookTitle.
  ///
  /// In uz, this message translates to:
  /// **'Konsultatsiya Bron Qilish'**
  String get bookTitle;

  /// No description provided for @bookSelectSlotWarning.
  ///
  /// In uz, this message translates to:
  /// **'Iltimos, konsultatsiya vaqtini tanlang'**
  String get bookSelectSlotWarning;

  /// No description provided for @bookPriceLine.
  ///
  /// In uz, this message translates to:
  /// **'Narxi: {amount} so\'m'**
  String bookPriceLine(String amount);

  /// No description provided for @bookPriceWithDuration.
  ///
  /// In uz, this message translates to:
  /// **'Narxi: {amount} so\'m / {minutes} daqiqa'**
  String bookPriceWithDuration(String amount, int minutes);

  /// No description provided for @bookSelectDate.
  ///
  /// In uz, this message translates to:
  /// **'Sana Tanlang'**
  String get bookSelectDate;

  /// No description provided for @bookAvailableSlots.
  ///
  /// In uz, this message translates to:
  /// **'Mavjud Vaqt Slotlari'**
  String get bookAvailableSlots;

  /// No description provided for @bookSlotsLoading.
  ///
  /// In uz, this message translates to:
  /// **'Slotlar yuklanmoqda...'**
  String get bookSlotsLoading;

  /// No description provided for @bookNoSlots.
  ///
  /// In uz, this message translates to:
  /// **'Ushbu kunga bo\'sh slotlar mavjud emas.'**
  String get bookNoSlots;

  /// No description provided for @bookMeetingTypeTitle.
  ///
  /// In uz, this message translates to:
  /// **'Konsultatsiya Turi'**
  String get bookMeetingTypeTitle;

  /// No description provided for @bookMeetingTypeOnline.
  ///
  /// In uz, this message translates to:
  /// **'Onlayn Video'**
  String get bookMeetingTypeOnline;

  /// No description provided for @bookMeetingTypePhone.
  ///
  /// In uz, this message translates to:
  /// **'Telefon'**
  String get bookMeetingTypePhone;

  /// No description provided for @bookMeetingTypeOffice.
  ///
  /// In uz, this message translates to:
  /// **'Ofisda'**
  String get bookMeetingTypeOffice;

  /// No description provided for @bookNotesTitle.
  ///
  /// In uz, this message translates to:
  /// **'Masala haqida qisqacha (ixtiyoriy)'**
  String get bookNotesTitle;

  /// No description provided for @bookNotesHint.
  ///
  /// In uz, this message translates to:
  /// **'Masalan: Mehnat nizosi, ishdan asossiz bo\'shatish...'**
  String get bookNotesHint;

  /// No description provided for @bookProceedToPaymentAmount.
  ///
  /// In uz, this message translates to:
  /// **'{amount} so\'m — To\'lovga o\'tish'**
  String bookProceedToPaymentAmount(String amount);

  /// No description provided for @bookProceedToPayment.
  ///
  /// In uz, this message translates to:
  /// **'To\'lovga o\'tish'**
  String get bookProceedToPayment;

  /// No description provided for @bookSelectTime.
  ///
  /// In uz, this message translates to:
  /// **'Vaqtni tanlang'**
  String get bookSelectTime;

  /// No description provided for @weekdayShortMon.
  ///
  /// In uz, this message translates to:
  /// **'Dush'**
  String get weekdayShortMon;

  /// No description provided for @weekdayShortTue.
  ///
  /// In uz, this message translates to:
  /// **'Sesh'**
  String get weekdayShortTue;

  /// No description provided for @weekdayShortWed.
  ///
  /// In uz, this message translates to:
  /// **'Chor'**
  String get weekdayShortWed;

  /// No description provided for @weekdayShortThu.
  ///
  /// In uz, this message translates to:
  /// **'Pay'**
  String get weekdayShortThu;

  /// No description provided for @weekdayShortFri.
  ///
  /// In uz, this message translates to:
  /// **'Jum'**
  String get weekdayShortFri;

  /// No description provided for @weekdayShortSat.
  ///
  /// In uz, this message translates to:
  /// **'Shan'**
  String get weekdayShortSat;

  /// No description provided for @weekdayShortSun.
  ///
  /// In uz, this message translates to:
  /// **'Yak'**
  String get weekdayShortSun;

  /// No description provided for @myConsultationsTitle.
  ///
  /// In uz, this message translates to:
  /// **'Mening Konsultatsiyalarim'**
  String get myConsultationsTitle;

  /// No description provided for @myConsultationsTabUpcoming.
  ///
  /// In uz, this message translates to:
  /// **'Kutilayotgan'**
  String get myConsultationsTabUpcoming;

  /// No description provided for @myConsultationsTabCompleted.
  ///
  /// In uz, this message translates to:
  /// **'Tugallangan'**
  String get myConsultationsTabCompleted;

  /// No description provided for @myConsultationsTabCancelled.
  ///
  /// In uz, this message translates to:
  /// **'Bekor qilingan'**
  String get myConsultationsTabCancelled;

  /// No description provided for @myConsultationsEmpty.
  ///
  /// In uz, this message translates to:
  /// **'Konsultatsiyalar topilmadi'**
  String get myConsultationsEmpty;

  /// No description provided for @consultationCancelTitle.
  ///
  /// In uz, this message translates to:
  /// **'Konsultatsiyani bekor qilish'**
  String get consultationCancelTitle;

  /// No description provided for @consultationCancelHoursLeft.
  ///
  /// In uz, this message translates to:
  /// **'Konsultatsiyagacha qolgan vaqt: {hours} soat'**
  String consultationCancelHoursLeft(int hours);

  /// No description provided for @consultationCancelRefundLine.
  ///
  /// In uz, this message translates to:
  /// **'Qaytariladigan summa: {percent}% ({amount} so\'m)'**
  String consultationCancelRefundLine(String percent, String amount);

  /// No description provided for @consultationCancelReasonLabel.
  ///
  /// In uz, this message translates to:
  /// **'Bekor qilish sababi'**
  String get consultationCancelReasonLabel;

  /// No description provided for @consultationCancelReasonHint.
  ///
  /// In uz, this message translates to:
  /// **'Sababni yozing...'**
  String get consultationCancelReasonHint;

  /// No description provided for @consultationCancelConfirm.
  ///
  /// In uz, this message translates to:
  /// **'Bekor Qilish'**
  String get consultationCancelConfirm;

  /// No description provided for @consultationCancelledSnack.
  ///
  /// In uz, this message translates to:
  /// **'Konsultatsiya bekor qilindi. Qaytarilgan: {amount} so\'m'**
  String consultationCancelledSnack(String amount);

  /// No description provided for @consultationMeetingLinkSnack.
  ///
  /// In uz, this message translates to:
  /// **'Xona havolasi: {link}'**
  String consultationMeetingLinkSnack(String link);

  /// No description provided for @consultationJoinRoom.
  ///
  /// In uz, this message translates to:
  /// **'Xonaga Kirish'**
  String get consultationJoinRoom;

  /// No description provided for @paymentTitle.
  ///
  /// In uz, this message translates to:
  /// **'To\'lovni Tasdiqlash'**
  String get paymentTitle;

  /// No description provided for @paymentProcessing.
  ///
  /// In uz, this message translates to:
  /// **'To\'lov tranzaksiyasi tekshirilmoqda...'**
  String get paymentProcessing;

  /// No description provided for @paymentServiceLine.
  ///
  /// In uz, this message translates to:
  /// **'Huquqiy maslahat'**
  String get paymentServiceLine;

  /// No description provided for @paymentScheduledDateLabel.
  ///
  /// In uz, this message translates to:
  /// **'Belgilangan sana:'**
  String get paymentScheduledDateLabel;

  /// No description provided for @paymentTotalLabel.
  ///
  /// In uz, this message translates to:
  /// **'Jami to\'lov:'**
  String get paymentTotalLabel;

  /// No description provided for @paymentGatewayUnavailableTitle.
  ///
  /// In uz, this message translates to:
  /// **'Onlayn to\'lov hozircha ulanmagan'**
  String get paymentGatewayUnavailableTitle;

  /// No description provided for @paymentGatewayUnavailableBody.
  ///
  /// In uz, this message translates to:
  /// **'Bu versiyada Payme, Click va Uzum bilan real to\'lov integratsiyasi yo\'q. Bandligingiz \"to\'lov kutilmoqda\" holatida saqlandi — advokat siz bilan bog\'lanib to\'lovni kelishadi. Ilovada soxta to\'lov tasdig\'i ko\'rsatilmaydi.'**
  String get paymentGatewayUnavailableBody;

  /// No description provided for @paymentGatewayUnavailableAction.
  ///
  /// In uz, this message translates to:
  /// **'To\'lov hozircha mavjud emas'**
  String get paymentGatewayUnavailableAction;

  /// No description provided for @paymentMethodTitle.
  ///
  /// In uz, this message translates to:
  /// **'To\'lov Usulini Tanlang'**
  String get paymentMethodTitle;

  /// No description provided for @paymentProviderPaymeSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Humo, Uzcard orqali to\'lov'**
  String get paymentProviderPaymeSubtitle;

  /// No description provided for @paymentProviderClickSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'ClickPass va QR to\'lov'**
  String get paymentProviderClickSubtitle;

  /// No description provided for @paymentProviderUzumSubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Uzum kartalari va nasiya'**
  String get paymentProviderUzumSubtitle;

  /// No description provided for @paymentPayAmount.
  ///
  /// In uz, this message translates to:
  /// **'{amount} so\'m To\'lash'**
  String paymentPayAmount(String amount);

  /// No description provided for @paymentSuccessTitle.
  ///
  /// In uz, this message translates to:
  /// **'To\'lov Muvaffaqiyatli Bajarildi!'**
  String get paymentSuccessTitle;

  /// No description provided for @paymentSuccessWithLink.
  ///
  /// In uz, this message translates to:
  /// **'Advokat bilan konsultatsiyangiz tasdiqlandi. Belgilangan vaqtda quyidagi xona orqali ulanishingiz mumkin.'**
  String get paymentSuccessWithLink;

  /// No description provided for @paymentSuccessNoLink.
  ///
  /// In uz, this message translates to:
  /// **'Advokat bilan konsultatsiyangiz tasdiqlandi. Uchrashuv havolasi tayyor bo\'lgach, \"Mening konsultatsiyalarim\" bo\'limida ko\'rinadi.'**
  String get paymentSuccessNoLink;

  /// No description provided for @paymentGoToMyConsultations.
  ///
  /// In uz, this message translates to:
  /// **'Konsultatsiyalarimga O\'tish'**
  String get paymentGoToMyConsultations;

  /// No description provided for @moderationTitle.
  ///
  /// In uz, this message translates to:
  /// **'Advokat arizalari'**
  String get moderationTitle;

  /// No description provided for @moderationEntrySubtitle.
  ///
  /// In uz, this message translates to:
  /// **'Litsenziyani tekshirib tasdiqlash'**
  String get moderationEntrySubtitle;

  /// No description provided for @moderationPendingCount.
  ///
  /// In uz, this message translates to:
  /// **'{count} ta ariza tekshirilmoqda'**
  String moderationPendingCount(int count);

  /// No description provided for @moderationEmptyTitle.
  ///
  /// In uz, this message translates to:
  /// **'Tekshirishga ariza yo\'q'**
  String get moderationEmptyTitle;

  /// No description provided for @moderationEmptyBody.
  ///
  /// In uz, this message translates to:
  /// **'Yangi ariza topshirilganda u shu yerda ko\'rinadi.'**
  String get moderationEmptyBody;

  /// No description provided for @moderationLicenseLabel.
  ///
  /// In uz, this message translates to:
  /// **'Litsenziya raqami'**
  String get moderationLicenseLabel;

  /// No description provided for @moderationSpecializationLabel.
  ///
  /// In uz, this message translates to:
  /// **'Yo\'nalish'**
  String get moderationSpecializationLabel;

  /// No description provided for @moderationExperienceLabel.
  ///
  /// In uz, this message translates to:
  /// **'Tajriba'**
  String get moderationExperienceLabel;

  /// No description provided for @moderationExperienceValue.
  ///
  /// In uz, this message translates to:
  /// **'{count} yil'**
  String moderationExperienceValue(int count);

  /// No description provided for @moderationWorkplaceLabel.
  ///
  /// In uz, this message translates to:
  /// **'Ish joyi'**
  String get moderationWorkplaceLabel;

  /// No description provided for @moderationEducationLabel.
  ///
  /// In uz, this message translates to:
  /// **'Ma\'lumoti'**
  String get moderationEducationLabel;

  /// No description provided for @moderationSubmittedAt.
  ///
  /// In uz, this message translates to:
  /// **'Topshirilgan: {date}'**
  String moderationSubmittedAt(String date);

  /// HALOLLIK (§6): bo'sh maydon SOXTA qiymat bilan to'ldirilmaydi. Moderator nuqsonni KO'RISHI kerak — aks holda yolg'on asosda tasdiqlaydi.
  ///
  /// In uz, this message translates to:
  /// **'Ko\'rsatilmagan'**
  String get moderationFieldMissing;

  /// No description provided for @moderationUnnamedApplicant.
  ///
  /// In uz, this message translates to:
  /// **'Ismi ko\'rsatilmagan arizachi'**
  String get moderationUnnamedApplicant;

  /// No description provided for @moderationOpenDocument.
  ///
  /// In uz, this message translates to:
  /// **'Litsenziya hujjatini ochish'**
  String get moderationOpenDocument;

  /// No description provided for @moderationNoDocument.
  ///
  /// In uz, this message translates to:
  /// **'Litsenziya hujjati yuklanmagan'**
  String get moderationNoDocument;

  /// No description provided for @moderationDocumentOpenFailed.
  ///
  /// In uz, this message translates to:
  /// **'Hujjatni ochib bo\'lmadi.'**
  String get moderationDocumentOpenFailed;

  /// No description provided for @moderationApprove.
  ///
  /// In uz, this message translates to:
  /// **'Tasdiqlash'**
  String get moderationApprove;

  /// No description provided for @moderationReject.
  ///
  /// In uz, this message translates to:
  /// **'Rad etish'**
  String get moderationReject;

  /// No description provided for @moderationApproveTitle.
  ///
  /// In uz, this message translates to:
  /// **'Arizani tasdiqlaysizmi?'**
  String get moderationApproveTitle;

  /// No description provided for @moderationApproveBody.
  ///
  /// In uz, this message translates to:
  /// **'{name} tasdiqlangan advokat bo\'ladi va katalogda ko\'rinadi. Litsenziya hujjatini ochib tekshirganingizga ishonch hosil qiling.'**
  String moderationApproveBody(String name);

  /// No description provided for @moderationRejectTitle.
  ///
  /// In uz, this message translates to:
  /// **'Arizani rad etasizmi?'**
  String get moderationRejectTitle;

  /// No description provided for @moderationRejectBody.
  ///
  /// In uz, this message translates to:
  /// **'{name} tasdiqlanmaydi va katalogga chiqmaydi.'**
  String moderationRejectBody(String name);

  /// RUNTIME'DA O'LCHANGAN (2026-08-29, `20260829_expert_rejection_and_revocation.sql` JONLI bazaga qo'llangandan keyin): rad etish `rejected_at` yozadi va ariza kutayotganlar filtridan chiqadi (o'lchov: kutayotganlar 1 -> 0), qayta topshirish esa `rejected_at` ni tozalab arizani yana ro'yxatga qaytaradi (o'lchov: 0 -> 1). Kalit ilgari `moderationRejectKeepsPending` deb nomlanib, rad etish JIM NO-OP ekanini ogohlantirardi; server holati o'zgargani uchun matn ham o'zgardi — eski matnni saqlash endi YOLG'ON bo'lardi (§20).
  ///
  /// In uz, this message translates to:
  /// **'Ariza rad etilgan deb belgilanadi va ro\'yxatdan chiqadi. Arizachi tuzatib qayta topshirishi mumkin.'**
  String get moderationRejectConsequence;

  /// Rad etish dialogidagi matn maydoni yorlig'i. SABAB MAJBURIY EMAS: server `p_rejection_reason` ni `DEFAULT NULL` bilan qabul qiladi (`20260830030000_expert_rejection_reason_and_withdraw.sql`), ya'ni moderator sababsiz ham rad etishi mumkin. Majburiy qilish moderatorni har safar matn yozishga majburlab, rad etishni sekinlashtirardi.
  ///
  /// In uz, this message translates to:
  /// **'Rad etish sababi (majburiy emas)'**
  String get moderationRejectReasonLabel;

  /// Namuna sabab. ATAYLAB atoqli nom, ism va raqam YO'Q — namuna soxta ma'lumot manbasi bo'lmasligi kerak.
  ///
  /// In uz, this message translates to:
  /// **'Masalan: litsenziya raqami tekshiruvdan o\'tmadi'**
  String get moderationRejectReasonHint;

  /// MODERATORGA HALOL OGOHLANTIRISH: yozilgan sabab arizachiga DARHOL (push/xat bilan) BORMAYDI. Arizachi uchun "mening arizam holati" ekrani YO'Q; sabab faqat qayta topshirishga uringanda serverning `LX429` xabari ichida ko'rinadi. Bu matn bo'lmasa moderator sabab yetkazildi deb o'ylardi (§20: jim yolg'on yo'q).
  ///
  /// In uz, this message translates to:
  /// **'Sababni arizachi qayta topshirishga uringanda ko\'radi.'**
  String get moderationRejectReasonDelivery;

  /// Xodimlar uchun diagnostika ekrani sarlavhasi: ilovada tutilmagan xatolar ro'yxati (`public.client_error_logs`).
  ///
  /// In uz, this message translates to:
  /// **'Xato jurnali'**
  String get crashLogTitle;

  /// Profil sahifasidagi kirish plitkasining izohi.
  ///
  /// In uz, this message translates to:
  /// **'Ilovadagi tutilmagan xatolar'**
  String get crashLogEntrySubtitle;

  /// Bo'sh holat. TO'QIMA yozuv KO'RSATILMAYDI — jurnal bo'sh bo'lsa shunday deyiladi (§20).
  ///
  /// In uz, this message translates to:
  /// **'Xato yozuvi yo\'q.'**
  String get crashLogEmpty;

  /// AppBar amali. Serverdagi `purge_client_error_logs(30)` ni chaqiradi.
  ///
  /// In uz, this message translates to:
  /// **'30 kundan eskisini tozalash'**
  String get crashLogPurgeAction;

  /// Tasdiqlash dialogi matni. Amal QAYTARILMAYDI — foydalanuvchi buni bilishi kerak.
  ///
  /// In uz, this message translates to:
  /// **'30 kundan eski yozuvlar butunlay o\'chiriladi. Bu amalni qaytarib bo\'lmaydi.'**
  String get crashLogPurgeConfirmBody;

  /// Tozalash natijasi. Son SERVERDAN qaytadi (klient o'zi hisoblamaydi).
  ///
  /// In uz, this message translates to:
  /// **'{count} yozuv o\'chirildi.'**
  String crashLogPurgeDone(int count);

  /// Yig'iladigan bo'lim sarlavhasi. Texnik atama ATAYLAB tarjima qilinmaydi.
  ///
  /// In uz, this message translates to:
  /// **'Stack trace'**
  String get crashLogStackLabel;

  /// No description provided for @moderationApprovedToast.
  ///
  /// In uz, this message translates to:
  /// **'{name} tasdiqlandi.'**
  String moderationApprovedToast(String name);

  /// No description provided for @moderationRejectedToast.
  ///
  /// In uz, this message translates to:
  /// **'{name} arizasi rad etildi.'**
  String moderationRejectedToast(String name);

  /// No description provided for @moderationListStale.
  ///
  /// In uz, this message translates to:
  /// **'Amal serverda bajarildi, lekin ro\'yxatni yangilab bo\'lmadi.'**
  String get moderationListStale;

  /// Rad etish tasdiqlangan advokatni `citizen` ga qaytarganda SnackBar'ga qo'shiladi. Belgi SERVERDAN keladi (`verify_expert_application` javobidagi `role_reverted`), klient hisoblamaydi. RUNTIME'DA O'LCHANGAN (2026-08-29): javob `{"role_reverted": true, "previous_role": "verified_expert"}` va advokat ochiq katalogdan chiqdi (1 -> 0).
  ///
  /// In uz, this message translates to:
  /// **'Advokat maqomi ham bekor qilindi.'**
  String get moderationRoleReverted;

  /// No description provided for @errorNetwork.
  ///
  /// In uz, this message translates to:
  /// **'Internet aloqasi yo\'q. Tarmoqni tekshirib, qaytadan urinib ko\'ring.'**
  String get errorNetwork;

  /// No description provided for @errorTimeout.
  ///
  /// In uz, this message translates to:
  /// **'Server javob bermadi. Iltimos, qaytadan urinib ko\'ring.'**
  String get errorTimeout;

  /// No description provided for @errorServer.
  ///
  /// In uz, this message translates to:
  /// **'Serverda xatolik yuz berdi. Keyinroq qaytadan urinib ko\'ring.'**
  String get errorServer;

  /// No description provided for @errorUnauthorized.
  ///
  /// In uz, this message translates to:
  /// **'Sessiya tugagan. Iltimos, qaytadan kiring.'**
  String get errorUnauthorized;

  /// No description provided for @errorForbidden.
  ///
  /// In uz, this message translates to:
  /// **'Bu amalni bajarishga ruxsat yo\'q.'**
  String get errorForbidden;

  /// No description provided for @errorNotFound.
  ///
  /// In uz, this message translates to:
  /// **'So\'ralgan ma\'lumot topilmadi.'**
  String get errorNotFound;

  /// No description provided for @errorRateLimited.
  ///
  /// In uz, this message translates to:
  /// **'Juda ko\'p urinish. Bir necha daqiqadan keyin qaytadan urinib ko\'ring.'**
  String get errorRateLimited;

  /// UMUMIY sovutish matni — server TUZILGAN ma'lumot bermaganda (eski server versiyasi yoki `DETAIL` shakli mos kelmaganda) ishlatiladi. Aniq vaqt bo'lsa `errorApplicationCooldownUntil` afzal.
  ///
  /// In uz, this message translates to:
  /// **'Ariza rad etilgan. Qayta topshirish qaror qabul qilinganidan 24 soat o\'tgach mumkin.'**
  String get errorApplicationCooldown;

  /// Sovutish davri — SABAB YOZILMAGAN holat. Serverning `p_rejection_reason IS NULL` shoxiga mos keladi: sabab yo'q bo'lsa bo'sh "Sabab:" sarlavhasi KO'RSATILMAYDI (§20). {time} — `retry_at` xom serverdan (`DETAIL` JSON), klientda `dd.MM.yyyy, HH:mm` shaklida mahalliy vaqtga aylantiriladi.
  ///
  /// In uz, this message translates to:
  /// **'Ariza rad etilgan. Qayta topshirish {time} dan keyin mumkin.'**
  String errorApplicationCooldownUntil(String time);

  /// Sovutish davri — moderator SABAB yozgan holat. Sabab MATNI moderatordan keladi va tarjima QILINMAYDI (§16: tarjima qilinadigan narsa shablon, qiymat emas). {time} — `retry_at` mahalliy vaqtda.
  ///
  /// In uz, this message translates to:
  /// **'Ariza rad etilgan. Sabab: {reason}. Qayta topshirish {time} dan keyin mumkin.'**
  String errorApplicationCooldownUntilWithReason(String reason, String time);

  /// No description provided for @errorValidation.
  ///
  /// In uz, this message translates to:
  /// **'Kiritilgan ma\'lumotlar to\'g\'ri emas. Iltimos, tekshirib ko\'ring.'**
  String get errorValidation;

  /// No description provided for @errorCache.
  ///
  /// In uz, this message translates to:
  /// **'Qurilmada saqlangan ma\'lumotni o\'qib bo\'lmadi.'**
  String get errorCache;

  /// No description provided for @errorCancelled.
  ///
  /// In uz, this message translates to:
  /// **'So\'rov bekor qilindi.'**
  String get errorCancelled;

  /// No description provided for @errorUnexpected.
  ///
  /// In uz, this message translates to:
  /// **'Kutilmagan xatolik yuz berdi. Iltimos, qaytadan urinib ko\'ring.'**
  String get errorUnexpected;
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'uz'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppL10nEn();
    case 'uz':
      return AppL10nUz();
  }

  throw FlutterError(
      'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
