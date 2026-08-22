// LexHub — ROL YORLIQLARI (UI label) va DB qiymatlari orasidagi chegara.
//
// QAT'IY QOIDA (§15): DB qiymatlari HECH QACHON tarjima qilinmaydi.
//   `profiles.role` -> 'citizen' | 'lawyer' | 'verified_expert' |
//                      'moderator' | 'admin'
// Bu funksiya faqat EKRANDA ko'rinadigan matnni beradi. So'rovlar, RBAC
// tekshiruvlari va `canAnswerAsExpert()` hamon xom DB qiymati bilan ishlaydi.

import 'package:lexhub/l10n/gen/app_localizations.dart';

/// Xom `profiles.role` qiymatini tanlangan tildagi yorliqqa aylantiradi.
///
/// Noma'lum / bo'sh rol uchun eng past imtiyozli yorliq (`citizen`)
/// qaytariladi — fail-closed: hech qachon "ekspert" deb ko'rsatilmaydi.
String roleLabelFromDbValue(AppL10n l10n, String? dbRole) {
  switch (dbRole?.trim().toLowerCase()) {
    case 'lawyer':
      return l10n.roleLawyer;
    case 'verified_expert':
      return l10n.roleVerifiedExpert;
    case 'moderator':
      return l10n.roleModerator;
    case 'admin':
      return l10n.roleAdmin;
    case 'citizen':
    default:
      return l10n.roleCitizen;
  }
}

/// `answers.author_role` (yoki join qilingan `profiles.role`) qiymatini
/// yorliqqa aylantiradi.
///
/// [roleLabelFromDbValue] dan FARQI: bu maydon erkin matn bo'lishi mumkin.
/// Live'da `answers` jadvalida `author_role` ustuni YO'Q, shuning uchun
/// `QuestionAnswerModel.fromJson` join'dagi `profiles.role`ni oladi — ya'ni
/// UI'da xom `lawyer` / `citizen` ko'rinib qolgan edi. Endi tanilgan DB
/// qiymatlari tarjima qilinadi, tanilmagan (masalan eski o'zbekcha erkin
/// matn) esa O'ZGARISHSIZ ko'rsatiladi — fail-open faqat KO'RINISHDA,
/// hech qanday imtiyoz bermaydi.
String answerAuthorRoleLabel(AppL10n l10n, String? rawRole) {
  final value = rawRole?.trim() ?? '';
  if (value.isEmpty) return l10n.answerRoleCommunityMember;
  switch (value.toLowerCase()) {
    case 'citizen':
      return l10n.answerRoleCommunityMember;
    case 'lawyer':
      return l10n.roleLawyer;
    case 'verified_expert':
      return l10n.roleVerifiedExpert;
    case 'moderator':
      return l10n.roleModerator;
    case 'admin':
      return l10n.roleAdmin;
    default:
      return value;
  }
}
