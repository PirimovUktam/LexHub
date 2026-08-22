// LexHub — XATO XABARLARINI TILGA MOSLASH (P2).
//
// MUAMMO: `Failure.message` — datasource ichida qotib qolgan O'ZBEKCHA matn
// (18 faylda 74 ta literal). `Settings -> Language -> English` tanlanganda
// UI inglizchaga o'tadi, LEKIN xato SnackBar'lari o'zbekcha qolardi.
//
// NEGA 74 LITERAL ARB'GA KO'CHIRILMADI: bu MVP freeze bosqichida katta
// refactor bo'lardi va har bir datasource'ning texnik matnini yo'qotardi.
// O'rniga `Failure.code` (`FailureCode`) qo'shildi — til'dan mustaqil,
// mashina o'qiy oladigan sinf. Original texnik matn `Failure.message` va
// `Failure.details` da QOLADI (log/debug uchun).
//
// TANLOV MANTIQI:
//   * O'ZBEK tilida  -> `failure.message` ishlatiladi. U aynan foydalanuvchi
//     uchun yozilgan va umumiy matndan ANIQROQ (masalan "Konsultatsiya vaqti
//     kelajakda bo'lishi shart"). `ErrorHandler` uni texnik detaldan
//     TOZALAB beradi, shuning uchun DB/server matni oshkor bo'lmaydi.
//   * BOSHQA tilda -> o'zbekcha matn ko'rsatish ma'nosiz. `code` bo'yicha
//     ARB'dagi tarjima ishlatiladi.
//
// CHEKLOV (halol qayd): ingliz tilida xabar UMUMIY (kod darajasida) bo'ladi,
// o'zbekchadagidek har bir holat uchun alohida matn EMAS. Bu ataylab
// qilingan murosa: tushunarli inglizcha umumiy matn — tushunarsiz o'zbekcha
// aniq matndan afzal.

import 'package:lexhub/core/errors/failure_code.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/l10n/gen/app_localizations.dart';

/// `Failure` ni foydalanuvchi ko'radigan matnga aylantiradi.
String failureText(AppL10n l10n, Failure failure) {
  final uzbek = l10n.localeName.startsWith('uz');
  final authored = failure.message.trim();

  if (uzbek && authored.isNotEmpty) return authored;

  return failureMessageFor(
    l10n,
    failure.code,
    technical: uzbek ? authored : null,
  );
}

/// Bloc `ErrorState`'lari uchun (ular `Failure` obyektini emas,
/// `message` + `code` juftligini tashiydi). `failureText` bilan AYNI mantiq.
String errorStateText(AppL10n l10n, String message, FailureCode code) {
  final uzbek = l10n.localeName.startsWith('uz');
  final authored = message.trim();

  if (uzbek && authored.isNotEmpty) return authored;

  return failureMessageFor(l10n, code, technical: uzbek ? authored : null);
}

/// Faqat `FailureCode` mavjud bo'lgan joylar uchun (bloc state'lari
/// `Failure` obyektini emas, `String message` ni tashiydi).
String failureMessageFor(
  AppL10n l10n,
  FailureCode code, {
  String? technical,
}) {
  switch (code) {
    case FailureCode.network:
      return l10n.errorNetwork;
    case FailureCode.timeout:
      return l10n.errorTimeout;
    case FailureCode.server:
      return l10n.errorServer;
    case FailureCode.unauthorized:
      return l10n.errorUnauthorized;
    case FailureCode.forbidden:
      return l10n.errorForbidden;
    case FailureCode.notFound:
      return l10n.errorNotFound;
    case FailureCode.rateLimited:
      return l10n.errorRateLimited;
    case FailureCode.validation:
      return l10n.errorValidation;
    case FailureCode.cache:
      return l10n.errorCache;
    case FailureCode.cancelled:
      return l10n.errorCancelled;
    case FailureCode.unknown:
      // O'zbek tilida texnik matn (tozalangan) mavjud bo'lsa — u aniqroq.
      final t = technical?.trim();
      if (t != null && t.isNotEmpty) return t;
      return l10n.errorUnexpected;
  }
}
