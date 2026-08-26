// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'LexHub';

  @override
  String get appTagline => 'A legal ecosystem for the citizens of Uzbekistan';

  @override
  String get appLegalPlatform => 'Uzbekistan Legal Platform';

  @override
  String get legalDisclaimer =>
      'Please note: LexHub does not replace a court ruling or a licensed attorney. The platform helps you understand your situation and identify the lawful path forward.';

  @override
  String get legalSourceLlm => 'Analysis by the server AI model';

  @override
  String get legalSourceDeterministic =>
      'NOT AI: based on the verified law database on this device';

  @override
  String get actionRetry => 'Try again';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionClose => 'Close';

  @override
  String get actionSend => 'Send';

  @override
  String get actionSave => 'Save';

  @override
  String get actionCopy => 'Copy';

  @override
  String get actionCopied => 'Copied';

  @override
  String get actionContinue => 'Continue';

  @override
  String get actionOk => 'Got it';

  @override
  String get actionSearch => 'Search';

  @override
  String get actionShare => 'Share';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionOpen => 'Open';

  @override
  String get actionSeeAll => 'See all';

  @override
  String get loadingLabel => 'Loading...';

  @override
  String get navHome => 'Home';

  @override
  String get navAI => 'Advice';

  @override
  String get navCommunity => 'Community';

  @override
  String get navServices => 'Services';

  @override
  String get navExperts => 'Lawyers';

  @override
  String get navCabinet => 'My cabinet';

  @override
  String get authLoginTitle => 'Sign in';

  @override
  String get authRegisterTitle => 'Create account';

  @override
  String get authRegisterSubtitle =>
      'Get full access to legal services and the public forum through LexHub';

  @override
  String get authFieldFullName => 'Full name';

  @override
  String get authHintFullName => 'Bobur Mirzayev';

  @override
  String get authFieldEmail => 'Email address';

  @override
  String get authHintEmail => 'example@domain.uz';

  @override
  String get authFieldPassword => 'Password';

  @override
  String get authFieldCreatePassword => 'Create a password';

  @override
  String get authHintPassword => 'Enter your password';

  @override
  String get authHintMinSixChars => 'At least 6 characters';

  @override
  String get authFieldConfirmPassword => 'Confirm password';

  @override
  String get authHintConfirmPassword => 'Re-enter your password';

  @override
  String get authHaveAccount => 'Already have an account? ';

  @override
  String get authNoAccount => 'Don\'t have an account? ';

  @override
  String get authGoToLogin => 'Sign in';

  @override
  String get authGoToRegister => 'Sign up';

  @override
  String get authContinueAsGuest => 'Continue as a guest';

  @override
  String get authSignOut => 'Sign out';

  @override
  String get authLoginOrRegister => 'Sign in / Create account';

  @override
  String get authSignedOutTitle => 'Sign in to your account';

  @override
  String get authSignedOutSubtitle =>
      'Sign in to ask questions, rate answers and consult with lawyers';

  @override
  String get authDefaultUserName => 'User';

  @override
  String get validationNameRequired => 'Please enter your full name';

  @override
  String get validationNameTooShort => 'That name is too short';

  @override
  String get validationEmailRequired => 'Please enter your email address';

  @override
  String get validationEmailInvalid => 'Please enter a valid email address';

  @override
  String get validationPasswordRequired => 'Please enter your password';

  @override
  String get validationPasswordTooShort =>
      'The password must be at least 6 characters long';

  @override
  String get validationConfirmPasswordRequired =>
      'Please confirm your password';

  @override
  String get validationPasswordsMismatch =>
      'The passwords you entered do not match';

  @override
  String get profileSecurityTitle => 'Security & RLS protection';

  @override
  String get profileSecuritySubtitle =>
      'PostgreSQL Row Level Security is active';

  @override
  String profileReputationPoints(int points) {
    return '$points pts';
  }

  @override
  String get roleCitizen => 'Citizen';

  @override
  String get roleLawyer => 'Lawyer / Attorney';

  @override
  String get roleVerifiedExpert => 'Verified expert';

  @override
  String get roleModerator => 'Moderator';

  @override
  String get roleAdmin => 'Administrator';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguageTile => 'App language';

  @override
  String get settingsLanguageSubtitle => 'Choose the interface language';

  @override
  String get languagePageTitle => 'Language';

  @override
  String get languagePageSubtitle =>
      'The selected language applies to the whole app and is kept the next time you open it.';

  @override
  String get languageSaveFailed =>
      'The language could not be saved. Please try again.';

  @override
  String languageChangedTo(String language) {
    return 'Language changed to $language';
  }

  @override
  String get categoryAll => 'All';

  @override
  String get categoryLabor => 'Labour law';

  @override
  String get categoryFamily => 'Family law';

  @override
  String get categoryCivil => 'Civil law';

  @override
  String get categoryCriminal => 'Criminal law';

  @override
  String get categoryAdministrative => 'Administrative law';

  @override
  String get categoryGeneral => 'General';

  @override
  String get communityTitle => 'Citizens & Lawyers forum';

  @override
  String get communityAskTooltip => 'Ask the community';

  @override
  String get communityAskCta => 'Ask a question';

  @override
  String get communityEmptyInCategory => 'No questions found in this category';

  @override
  String communityAnswersCount(int count) {
    return '$count answers';
  }

  @override
  String get communityAiAnalysis => 'Legal analysis';

  @override
  String get communityAiSummaryLabel => 'Automatic category note:';

  @override
  String get communityExpertAnswerBadge => 'Has a lawyer\'s answer';

  @override
  String get communityAnonymousBadge => 'Private (anonymous)';

  @override
  String get communityAnonymousShort => 'Anonymous';

  @override
  String get communityAnonymousAuthor => 'Anonymous citizen';

  @override
  String get communityPiiNotice =>
      'Personal data (phone, passport, card numbers) is hidden automatically';

  @override
  String get askDialogTitle => 'Ask the community';

  @override
  String get askDialogPrivacyGuard =>
      'Privacy Guard: phone, passport and card numbers are hidden automatically';

  @override
  String get askDialogCategoryField => 'Category';

  @override
  String get askDialogTitleField => 'Question title (short)';

  @override
  String get askDialogTitleHint => 'For example: Forced work on a day off...';

  @override
  String get askDialogBodyField => 'Details';

  @override
  String get askDialogBodyHint =>
      'Describe your legal problem in your own words...';

  @override
  String get askDialogAnonymousToggle => 'Publish anonymously';

  @override
  String get askDialogAnonymousSubtitle =>
      '\'Anonymous citizen\' will be shown instead of your name';

  @override
  String get askDialogPiiDetected => 'Sensitive data detected and hidden:';

  @override
  String get askDialogPublishAnonymously => 'Publish anonymously';

  @override
  String get askDialogPublish => 'Publish question';

  @override
  String get askDialogEmptyBody => 'Please enter your question';

  @override
  String get authRequiredTitle => 'Sign-in required';

  @override
  String authRequiredMessage(String action) {
    return 'Please sign in or create an account to continue: $action.';
  }

  @override
  String get authActionAskQuestion => 'ask a question';

  @override
  String get authActionWriteAnswer => 'write an answer';

  @override
  String get authActionVote => 'vote';

  @override
  String get authActionAcceptAnswer => 'accept an answer';

  @override
  String get questionDetailTitle => 'Question details';

  @override
  String get questionDetailAiSummary => 'Automatic category note';

  @override
  String questionDetailAnswersSection(int count) {
    return 'Answers and advice ($count)';
  }

  @override
  String get questionDetailEmptyAnswers =>
      'Nobody has answered yet.\nBe the first to share your experience or legal opinion!';

  @override
  String get answerAsLawyerChip => 'Answer as a lawyer';

  @override
  String get answerInputHint => 'Write an opinion or legal advice...';

  @override
  String get answerSubmitSuccess => 'Your answer has been saved and published!';

  @override
  String get answerSubmitDemoted =>
      'The answer was saved, but as a REGULAR answer: your profile is not verified for expert answers.';

  @override
  String get answerAcceptSuccess =>
      'The answer was marked as helpful (resolved)!';

  @override
  String get answerAcceptedBadge => 'Accepted as helpful';

  @override
  String get answerAcceptAction => 'Accept';

  @override
  String get answerRoleCommunityMember => 'Community member';

  @override
  String get answerRoleLicensedLawyer => 'Licensed attorney';

  @override
  String get homeGreeting => 'Hello';

  @override
  String get homePlatformTitle => 'LexHub Platform';

  @override
  String get homeQueryHint => 'Describe your problem in plain language...';

  @override
  String get homeAiAnalyzeButton => 'Search';

  @override
  String get homeServicesBannerTitle => 'Government services & procedures';

  @override
  String get homeServicesBannerSubtitle =>
      'my.gov.uz guides, fees and official deadlines';

  @override
  String get homeTopicMatters => 'Related legal matters';

  @override
  String get homeCommunityQuestions => 'Community questions';

  @override
  String get homePrivacyGuardBadge =>
      'You can post a question without showing your name';

  @override
  String get homeAskBannerTitle => 'Do you have a legal question too?';

  @override
  String get homeAskBannerSubtitle =>
      'Post your question with your personal data hidden';

  @override
  String homeCategoriesTitle(int count) {
    return 'Legal categories ($count)';
  }

  @override
  String get emergencyQuickTitle => 'Emergency legal protection';

  @override
  String get emergencyQuickSubtitle =>
      'Detention, search, questioning and the 102/1002 hotlines';

  @override
  String get faqBannerTitle => 'Frequently asked questions';

  @override
  String get faqBannerBadge => 'TOP 20+';

  @override
  String get faqBannerSubtitle =>
      'The most popular legal cases and ready-made solutions';

  @override
  String get cabinetTitle => 'My cabinet';

  @override
  String get cabinetTabProfile => 'Profile';

  @override
  String get cabinetTabConsultations => 'Consultations';

  @override
  String get cabinetTabBuilder => 'Builder';

  @override
  String get cabinetTabOfflineCases => 'Offline cases';

  @override
  String get recentCasesTitle => 'My recent requests';

  @override
  String recentCasesSeeAll(int count) {
    return 'All ($count)';
  }

  @override
  String legalBasisCount(int count) {
    return '$count Lex.uz article(s)';
  }

  @override
  String get actionRead => 'Read';

  @override
  String get recentCaseDetailTitle => 'Request analysis';

  @override
  String get trendingTitle => 'Frequently asked legal questions';

  @override
  String get trendingEmptyInCategory => 'No questions found in this category';

  @override
  String casesCount(int count) {
    return '$count case(s)';
  }

  @override
  String get actionReadAnalysis => 'Read the analysis';

  @override
  String get faqAskAiAction => 'Get a legal analysis on this matter';

  @override
  String get faqSearchHint => 'Search questions (e.g. alimony, fine)...';

  @override
  String faqLegalCasesCount(int count) {
    return '$count legal case(s)';
  }

  @override
  String get faqWithLexUz => 'With Lex.uz articles';

  @override
  String get faqNoMatches => 'No matching questions found';

  @override
  String get faqNoMatchesHint => 'Try another keyword or category';

  @override
  String get emergencyRightsTitle => 'Emergency rights';

  @override
  String emergencyCallFailed(String phone) {
    return 'The call could not be placed: $phone';
  }

  @override
  String get emergencyHotlinesTitle => 'Emergency hotlines';

  @override
  String get emergencyProtocolsTitle => 'Emergency legal protection protocols';

  @override
  String get hotlineProsecutor => 'Prosecutor General\'s Office';

  @override
  String get hotlineInterior => 'Internal Affairs (MIA)';

  @override
  String get hotlineOmbudsman => 'Ombudsman';

  @override
  String get hotlineLaborInspection => 'Labour Inspectorate';

  @override
  String get savedCasesTitle => 'Saved cases';

  @override
  String get savedCasesEmptyTitle => 'No saved cases yet';

  @override
  String get savedCasesEmptyBody =>
      'By saving legal advice you can review it again at any time, even without an internet connection.';

  @override
  String savedCaseQuestionQuoted(String query) {
    return 'Question: \"$query\"';
  }

  @override
  String get actionViewDetails => 'View details';

  @override
  String get savedCaseDetailTitle => 'Saved legal case';

  @override
  String get homeCatTraffic => 'Road traffic';

  @override
  String get homeCatAdminFines => 'Administrative fines';

  @override
  String get homeCatConsumer => 'Consumer rights';

  @override
  String get homeCatHousing => 'Housing & cadastre';

  @override
  String get homeCatTax => 'Tax matters';

  @override
  String get homeCatBanking => 'Banking & credit';

  @override
  String get homeCatInheritance => 'Property & inheritance';

  @override
  String get homeCatGovServices => 'Government services';

  @override
  String get homeCatCourt => 'Court matters';

  @override
  String get homeCatBusiness => 'Business & contracts';

  @override
  String get aiAnalystSubtitle => 'Uzbekistan legal analyst';

  @override
  String get aiWriteSituationTitle => 'Describe your legal situation';

  @override
  String get aiQueryHint =>
      'Describe your situation in detail (for example: \'I received a speed-camera fine and two days later another one was issued...\')...';

  @override
  String get aiGetAdviceButton => 'Get legal analysis';

  @override
  String get aiAnalyzingLexUz => 'Analysing Lex.uz articles...';

  @override
  String get aiCommonSituations => 'Frequent legal situations';

  @override
  String get aiFullAnalysisCopied => 'The full legal analysis has been copied.';

  @override
  String get aiBuildDocumentAction => 'Draft a document';

  @override
  String get aiQueryEmptyError =>
      'Please describe your legal question or situation.';

  @override
  String get actionCopyAnalysis => 'Copy analysis';

  @override
  String get aiChipUnfairDismissal => 'Unfair dismissal';

  @override
  String get aiChipConsumerReturn => 'Consumer rights (returning goods)';

  @override
  String get aiChipAlimony => 'Claiming child support';

  @override
  String get aiChipTrafficFine => 'Traffic fine';

  @override
  String get aiChipDebtReceipt => 'Debt and promissory note';

  @override
  String get aiSummaryTitle => 'Plain-language explanation (summary)';

  @override
  String get aiStepsTitle => 'Step-by-step actions';

  @override
  String get aiLegalBasisTitle => 'Legal grounds (Lex.uz)';

  @override
  String get aiRiskTitle => 'Risk and deadline analysis';

  @override
  String get aiEmergencyAlertTitle => 'WARNING: urgent legal risk';

  @override
  String get aiClarificationTitle =>
      'Additional questions for more precise advice';

  @override
  String get aiClarificationBody =>
      'To give you even more precise and accurate legal advice, we recommend providing the following details:';

  @override
  String get aiSummarySubtitle => 'A simple explanation without legal jargon';

  @override
  String get aiAudioStarted => 'Audio playback started (voice analysis)...';

  @override
  String get aiAudioStopped => 'Audio stopped';

  @override
  String get aiSummaryCopied => 'The summary text has been copied.';

  @override
  String get actionListenAudio => 'Listen to audio';

  @override
  String aiStepsProgress(int done, int total) {
    return '$done of $total completed';
  }

  @override
  String get aiLexUzBaseSubtitle => 'Lex.uz official legislation database';

  @override
  String get aiOfficialDocsSubtitle => 'Official legislative documents';

  @override
  String get aiLexUzOpenFailed => 'The Lex.uz link could not be opened';

  @override
  String aiArticleCopied(String article) {
    return 'The text of $article has been copied.';
  }

  @override
  String get statusInForce => 'In force';

  @override
  String get actionOpenLexUz => 'Read in full on Lex.uz';

  @override
  String get aiRiskSubtitle => 'Impartial legal analysis & limitations';

  @override
  String get aiRiskGaugeLabel => 'Risk level indicator';

  @override
  String get riskScaleLow => 'Low risk';

  @override
  String get riskScaleMedium => 'Medium';

  @override
  String get riskScaleHigh => 'High';

  @override
  String get riskScaleCritical => 'Critical';

  @override
  String aiDeadlineRemaining(int days) {
    return 'Estimated time left to file your claim: $days days';
  }

  @override
  String get aiLimitationsTitle => 'Important limitations and warnings:';

  @override
  String get aiLawyerRequiredWarning =>
      'Handling this case on your own increases the risk of losing it. We recommend engaging a qualified attorney.';

  @override
  String get aiLawyerRecommendedWarning =>
      'Acting on your own in this situation is risky. We recommend consulting a qualified attorney.';

  @override
  String get riskLevelLow => 'Low risk';

  @override
  String get riskLevelMedium => 'Medium risk';

  @override
  String get riskLevelHigh => 'High risk';

  @override
  String get riskLevelCritical => 'Critical risk (emergency)';

  @override
  String get emergencyRedFlagsTitle => 'Red flags:';

  @override
  String get emergencyConstitutionalRightsTitle =>
      'Your constitutional rights:';

  @override
  String get emergencyImmediateActionsTitle => 'What to do immediately:';

  @override
  String get emergencyMirandaTitle => 'Miranda rule';

  @override
  String get emergencyMirandaArticleLabel =>
      'Article 28 of the Constitution of the Republic of Uzbekistan:';

  @override
  String get emergencyMirandaScriptLabel =>
      'The formal wording to state to the investigator or officer:';

  @override
  String get emergencyMirandaLawQuote =>
      '\"During detention, the person must have their rights and the grounds for the detention explained to them in language they understand.\"';

  @override
  String get emergencyMirandaScriptText =>
      '\"Men O\'zbekiston Konstitutsiyasining 28 va 29-moddalariga asosan, advokatim yetib kelmaguncha har qanday ko\'rsatma berishdan bosh tortaman va sukut saqlash huquqimdan foydalanaman.\"\n\nSay it in Uzbek — this is the wording that carries legal weight. It means: \"Under Articles 28 and 29 of the Constitution of Uzbekistan, I refuse to give any statement until my lawyer arrives, and I invoke my right to remain silent.\"';

  @override
  String emergencyCallAction(String phone) {
    return 'Call ($phone)';
  }

  @override
  String get actionCallHotline => 'Call the hotline';

  @override
  String get searchHint => 'Law, lawyer, service or template...';

  @override
  String get searchError => 'Something went wrong while searching';

  @override
  String get searchRecentTitle => 'Recent searches';

  @override
  String get actionClear => 'Clear';

  @override
  String get searchPopularTitle => 'Popular legal topics';

  @override
  String get searchFilterLaws => 'Laws';

  @override
  String get searchFilterTemplates => 'Templates';

  @override
  String get searchTopicAlimonyTitle => 'How to claim child support';

  @override
  String get searchTopicAlimonySubtitle =>
      'Article 96 of the Family Code and the court-order application';

  @override
  String get searchTopicDismissalTitle => 'Unlawful dismissal';

  @override
  String get searchTopicDismissalSubtitle =>
      'Labour Code guarantees and a reinstatement claim';

  @override
  String get searchTopicRefundTitle => 'Refund for defective goods';

  @override
  String get searchTopicRefundSubtitle => 'The Consumer Rights Protection Act';

  @override
  String get searchTopicFineTitle => 'Appealing a traffic fine';

  @override
  String get searchTopicFineSubtitle => 'Challenging traffic police decisions';

  @override
  String get searchBadgeLaw => 'Legislative act';

  @override
  String get searchBadgeService => 'Government service';

  @override
  String get searchBadgeTemplate => 'Document template';

  @override
  String get searchBadgeQuestion => 'Community forum';

  @override
  String get searchLexUzBadge => 'Lex.uz ↗';

  @override
  String get searchBuilderBadge => 'Builder ⚡';

  @override
  String get searchOfficialLawyer => 'Licensed lawyer';

  @override
  String get statusFree => 'Free';

  @override
  String searchCostBhmPercent(String percent) {
    return '$percent% of BCA';
  }

  @override
  String searchTemplateAuthority(String authority) {
    return 'Authority: $authority';
  }

  @override
  String get searchEmptyTitle => 'No results found';

  @override
  String get searchEmptyBody =>
      'Try another keyword or pick a different category filter.';

  @override
  String get actionReload => 'Reload';

  @override
  String get actionSaved => 'Saved';

  @override
  String get actionViewOnLexUz => 'View on Lex.uz';

  @override
  String get badgePopular => 'Popular';

  @override
  String get errorCannotOpenLink => 'The link could not be opened';

  @override
  String get categorySocialProtection => 'Social protection';

  @override
  String get servicesTitle => 'Government services & guides';

  @override
  String get servicesSearchHint => 'Search government services or guides...';

  @override
  String get servicesEmptyTitle => 'No services found';

  @override
  String serviceDaysShort(int days) {
    return '$days days';
  }

  @override
  String get serviceGuideTitle => 'Service guide';

  @override
  String get serviceFreeBadge => 'Free service';

  @override
  String serviceCostBhm(String amount) {
    return '$amount BCA';
  }

  @override
  String get serviceVerifiedByLaw =>
      'Verified against the legislation of Uzbekistan';

  @override
  String serviceLastVerified(int year, int month) {
    return 'Last verified: $month/$year';
  }

  @override
  String get serviceLawUpdateActive => 'Legislation tracking: active';

  @override
  String get serviceProcessingTime => 'Processing time';

  @override
  String serviceWorkDays(int days) {
    return '$days working days';
  }

  @override
  String get serviceFeeLabel => 'State duty / payment';

  @override
  String get serviceNoFee => 'No fee';

  @override
  String get serviceDescriptionTitle => 'Description & purpose';

  @override
  String get serviceLegalBasisTitle => 'Official legal basis';

  @override
  String get serviceRequiredDocsTitle => 'Required documents';

  @override
  String get serviceStepsTitle => 'Step-by-step actions';

  @override
  String get serviceStepOnline => 'Online';

  @override
  String get serviceStepPayment => 'Payment';

  @override
  String get serviceStepAppeal => 'Appeal';

  @override
  String get serviceStepOpenPortal => 'Complete this step on the portal';

  @override
  String get serviceOpenMyGov => 'Apply through my.gov.uz';

  @override
  String get documentBuilderTitle => 'Document builder';

  @override
  String get templatesSearchHint =>
      'Search by template name, article or area...';

  @override
  String get templatesEmptyTitle => 'No templates found';

  @override
  String templateFieldsCount(int count) {
    return '$count fields';
  }

  @override
  String get documentLegalBasisLabel => 'Official legal basis:';

  @override
  String get documentFillFieldsTitle => 'Fill in the fields:';

  @override
  String get documentGenerateAction => 'Generate and preview the document';

  @override
  String get documentPreviewTitle => 'Final document preview';

  @override
  String get documentSaveTooltip => 'Add to saved items';

  @override
  String get documentCopiedSnack =>
      'The document text has been copied to the clipboard.';

  @override
  String get documentSavedSnack => 'The document has been saved successfully.';

  @override
  String documentLegalBasisWith(String basis) {
    return 'Legal basis: $basis';
  }

  @override
  String get documentReadyToPrint =>
      'Generated according to official requirements. Ready to print.';

  @override
  String get expertsTitle => 'Verified Lawyers';

  @override
  String get expertsApplyTooltip => 'Join as a lawyer';

  @override
  String get expertsHeaderTitle => 'Officially Licensed Lawyers';

  @override
  String get expertsHeaderSubtitle =>
      'Every specialist is checked against the register of the Chamber of Lawyers of Uzbekistan.';

  @override
  String get expertsSearchHint => 'Search by lawyer name or practice area...';

  @override
  String get expertsRegionLabel => 'By region:';

  @override
  String get expertsAllRegions => 'All regions';

  @override
  String get expertsEmptyFiltered =>
      'No lawyers found for the selected filters';

  @override
  String get expertVerifiedBadge => 'Verified';

  @override
  String get expertNameUnknown => 'Name not provided';

  @override
  String get expertSpecializationUnknown => 'Practice area not provided';

  @override
  String get expertContact => 'Contact';

  @override
  String expertExperienceYears(int count) {
    return '$count yrs experience';
  }

  @override
  String expertWonCases(int count) {
    return '$count+ cases won';
  }

  @override
  String expertFeeAmount(String amount) {
    return '$amount UZS';
  }

  @override
  String get expertFeeNegotiable => 'By agreement';

  @override
  String expertLicenseLine(String number) {
    return 'Licence: $number';
  }

  @override
  String get expertMetricRating => 'Rating';

  @override
  String expertMetricReviews(int count) {
    return '$count ratings';
  }

  @override
  String get expertNoRating => 'No ratings';

  @override
  String get expertMetricExperience => 'Experience';

  @override
  String expertMetricYears(int count) {
    return '$count yrs';
  }

  @override
  String get expertMetricPractice => 'Practice';

  @override
  String get expertMetricWins => 'Wins';

  @override
  String get expertMetricWonCases => 'Cases won';

  @override
  String get expertAboutTitle => 'About the lawyer';

  @override
  String get expertBookConsultation => 'Book a Consultation';

  @override
  String get expertCall => 'Call';

  @override
  String get expertTelegram => 'Telegram';

  @override
  String get expertContactMissing => 'No contact details provided';

  @override
  String expertCallFailed(String phone) {
    return 'Could not start the call: $phone';
  }

  @override
  String expertTelegramFailed(String username) {
    return 'Could not open the Telegram profile: @$username';
  }

  @override
  String get expertApplyTitle => 'Application for Lawyer Membership';

  @override
  String get expertApplyIntro =>
      'Enter your Chamber of Lawyers of Uzbekistan licence details. You will be added to the list of verified specialists.';

  @override
  String get expertApplySpecializationLabel => 'Practice area *';

  @override
  String get expertApplySpecializationError => 'Select a practice area';

  @override
  String get expertApplyLicenseLabel => 'Licence number (ADV-XXXXX) *';

  @override
  String get expertApplyLicenseError => 'Enter the licence number';

  @override
  String get expertApplyExperienceLabel => 'Legal experience (years) *';

  @override
  String get expertApplyExperienceError => 'Enter your experience';

  @override
  String get expertApplyWorkplaceLabel => 'Workplace / law firm';

  @override
  String get expertApplyFeeLabel => 'Consultation fee (UZS, optional)';

  @override
  String get expertApplySubmit => 'Submit application';

  @override
  String get expertSpecLabor => 'Labour law';

  @override
  String get expertSpecFamilyProperty => 'Family and property law';

  @override
  String get expertSpecCriminalDefense => 'Criminal defence and investigations';

  @override
  String get expertSpecTrafficAdmin => 'Traffic and administrative fines';

  @override
  String get expertSpecConsumerContracts => 'Consumer rights and contracts';

  @override
  String get expertSpecBusinessCorporate => 'Business and corporate law';

  @override
  String get expertSpecTaxCustoms => 'Tax and customs law';

  @override
  String get consultationStatusPending => 'Pending';

  @override
  String get consultationStatusAwaitingPayment => 'Awaiting payment';

  @override
  String get consultationStatusConfirmed => 'Confirmed';

  @override
  String get consultationStatusInProgress => 'In progress';

  @override
  String get consultationStatusCompleted => 'Completed';

  @override
  String get consultationStatusCancelled => 'Cancelled';

  @override
  String get consultationStatusExpired => 'Expired';

  @override
  String get consultationStatusDisputed => 'Disputed';

  @override
  String consultationAmountUzs(String amount) {
    return '$amount UZS';
  }

  @override
  String get bookTitle => 'Book a Consultation';

  @override
  String get bookSelectSlotWarning => 'Please select a consultation time';

  @override
  String bookPriceLine(String amount) {
    return 'Price: $amount UZS';
  }

  @override
  String bookPriceWithDuration(String amount, int minutes) {
    return 'Price: $amount UZS / $minutes min';
  }

  @override
  String get bookSelectDate => 'Select a date';

  @override
  String get bookAvailableSlots => 'Available time slots';

  @override
  String get bookSlotsLoading => 'Loading time slots...';

  @override
  String get bookNoSlots => 'There are no free slots on this day.';

  @override
  String get bookMeetingTypeTitle => 'Consultation type';

  @override
  String get bookMeetingTypeOnline => 'Online video';

  @override
  String get bookMeetingTypePhone => 'Phone';

  @override
  String get bookMeetingTypeOffice => 'At the office';

  @override
  String get bookNotesTitle => 'Brief description of the matter (optional)';

  @override
  String get bookNotesHint =>
      'For example: labour dispute, unlawful dismissal...';

  @override
  String bookProceedToPaymentAmount(String amount) {
    return '$amount UZS — Proceed to payment';
  }

  @override
  String get bookProceedToPayment => 'Proceed to payment';

  @override
  String get bookSelectTime => 'Select a time';

  @override
  String get weekdayShortMon => 'Mon';

  @override
  String get weekdayShortTue => 'Tue';

  @override
  String get weekdayShortWed => 'Wed';

  @override
  String get weekdayShortThu => 'Thu';

  @override
  String get weekdayShortFri => 'Fri';

  @override
  String get weekdayShortSat => 'Sat';

  @override
  String get weekdayShortSun => 'Sun';

  @override
  String get myConsultationsTitle => 'My Consultations';

  @override
  String get myConsultationsTabUpcoming => 'Upcoming';

  @override
  String get myConsultationsTabCompleted => 'Completed';

  @override
  String get myConsultationsTabCancelled => 'Cancelled';

  @override
  String get myConsultationsEmpty => 'No consultations found';

  @override
  String get consultationCancelTitle => 'Cancel the consultation';

  @override
  String consultationCancelHoursLeft(int hours) {
    return 'Time left until the consultation: $hours h';
  }

  @override
  String consultationCancelRefundLine(String percent, String amount) {
    return 'Refundable amount: $percent% ($amount UZS)';
  }

  @override
  String get consultationCancelReasonLabel => 'Reason for cancellation';

  @override
  String get consultationCancelReasonHint => 'Describe the reason...';

  @override
  String get consultationCancelConfirm => 'Cancel booking';

  @override
  String consultationCancelledSnack(String amount) {
    return 'Consultation cancelled. Refunded: $amount UZS';
  }

  @override
  String consultationMeetingLinkSnack(String link) {
    return 'Meeting room link: $link';
  }

  @override
  String get consultationJoinRoom => 'Join the room';

  @override
  String get paymentTitle => 'Confirm Payment';

  @override
  String get paymentProcessing => 'Verifying the payment transaction...';

  @override
  String get paymentServiceLine => 'Legal consultation';

  @override
  String get paymentScheduledDateLabel => 'Scheduled date:';

  @override
  String get paymentTotalLabel => 'Total payment:';

  @override
  String get paymentGatewayUnavailableTitle =>
      'Online payment is not connected yet';

  @override
  String get paymentGatewayUnavailableBody =>
      'This build has no live Payme, Click or Uzum integration. Your booking is saved as \"awaiting payment\" — the lawyer will contact you to arrange payment. The app will not show a fake payment confirmation.';

  @override
  String get paymentGatewayUnavailableAction => 'Payment not available yet';

  @override
  String get paymentMethodTitle => 'Choose a Payment Method';

  @override
  String get paymentProviderPaymeSubtitle => 'Pay with Humo or Uzcard';

  @override
  String get paymentProviderClickSubtitle => 'ClickPass and QR payment';

  @override
  String get paymentProviderUzumSubtitle => 'Uzum cards and instalments';

  @override
  String paymentPayAmount(String amount) {
    return 'Pay $amount UZS';
  }

  @override
  String get paymentSuccessTitle => 'Payment completed successfully!';

  @override
  String get paymentSuccessWithLink =>
      'Your consultation with the lawyer is confirmed. At the scheduled time you can join through the room below.';

  @override
  String get paymentSuccessNoLink =>
      'Your consultation with the lawyer is confirmed. Once the meeting link is ready, it will appear in the \"My Consultations\" section.';

  @override
  String get paymentGoToMyConsultations => 'Go to My Consultations';

  @override
  String get errorNetwork =>
      'No internet connection. Check your network and try again.';

  @override
  String get errorTimeout => 'The server did not respond. Please try again.';

  @override
  String get errorServer => 'A server error occurred. Please try again later.';

  @override
  String get errorUnauthorized =>
      'Your session has expired. Please sign in again.';

  @override
  String get errorForbidden =>
      'You do not have permission to perform this action.';

  @override
  String get errorNotFound => 'The requested data was not found.';

  @override
  String get errorRateLimited =>
      'Too many attempts. Please try again in a few minutes.';

  @override
  String get errorValidation =>
      'The information you entered is not valid. Please check it.';

  @override
  String get errorCache => 'The data stored on this device could not be read.';

  @override
  String get errorCancelled => 'The request was cancelled.';

  @override
  String get errorUnexpected =>
      'An unexpected error occurred. Please try again.';
}
