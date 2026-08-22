// LexHub — KONSULTATSIYA yorliqlari va DB qiymatlari chegarasi.
//
// QAT'IY QOIDA (§16): "Database values o'sha-o'sha qoladi."
// `consultations.status` / `payments.status` ustunlaridagi XOM qiymatlar
// (`awaiting_payment`, `in_progress`, `partially_refunded`, ...) va
// `p_meeting_type` qiymatlari (`online`, `phone`, `office`) BACKEND
// kontrakti — ular hech qachon tarjima QILINMAYDI va bu faylda
// O'ZGARTIRILMAYDI. Faqat EKRANDA ko'rinadigan yorliq tarjima qilinadi.
//
// Ilgari bu yorliqlar `ConsultationStatus.displayName` /
// `PaymentStatus.displayName` getter'larida — ya'ni DOMAIN qatlamida —
// o'zbek matni sifatida qotib qolgan edi (§16 buzilishi). Endi domain
// faqat `fromString` parser'ini saqlaydi, matn esa ARB'dan keladi.

import 'package:lexhub/features/consultations/domain/entities/consultation.dart';
import 'package:lexhub/l10n/gen/app_localizations.dart';

/// Konsultatsiya holati chip'ining yorlig'i.
String consultationStatusLabel(AppL10n l10n, ConsultationStatus status) {
  switch (status) {
    case ConsultationStatus.pending:
      return l10n.consultationStatusPending;
    case ConsultationStatus.awaitingPayment:
      return l10n.consultationStatusAwaitingPayment;
    case ConsultationStatus.confirmed:
      return l10n.consultationStatusConfirmed;
    case ConsultationStatus.inProgress:
      return l10n.consultationStatusInProgress;
    case ConsultationStatus.completed:
      return l10n.consultationStatusCompleted;
    case ConsultationStatus.cancelled:
      return l10n.consultationStatusCancelled;
    case ConsultationStatus.expired:
      return l10n.consultationStatusExpired;
    case ConsultationStatus.disputed:
      return l10n.consultationStatusDisputed;
  }
}

/// Uchrashuv turi chip'ining yorlig'i.
///
/// [rawType] — `book_consultation(p_meeting_type)` ga uzatiladigan XOM
/// qiymat. Tanilmagan qiymat xom holida ko'rsatiladi (to'qima yorliq YO'Q).
String consultationMeetingTypeLabel(AppL10n l10n, String rawType) {
  switch (rawType) {
    case 'online':
      return l10n.bookMeetingTypeOnline;
    case 'phone':
      return l10n.bookMeetingTypePhone;
    case 'office':
      return l10n.bookMeetingTypeOffice;
    default:
      return rawType;
  }
}

/// To'lov provayderining tavsifi.
///
/// [rawProvider] — `payments.provider` ga yoziladigan XOM qiymat
/// (`payme` / `click` / `uzum`). Provayder NOMI (Payme, Click Up, Uzum
/// Bank) — atoqli nom, u tarjima QILINMAYDI; faqat tavsif tarjima
/// qilinadi. Ilgari bu matnlar `_providers` ro'yxatida qotib qolgan va
/// `'Humo, Uzcard orqali to''lov'` — Dart'da qo'shni literal sifatida
/// "to" + "lov" ga yopishib, ekranda "to lov" ko'rinardi (bug).
String? paymentProviderSubtitle(AppL10n l10n, String rawProvider) {
  switch (rawProvider) {
    case 'payme':
      return l10n.paymentProviderPaymeSubtitle;
    case 'click':
      return l10n.paymentProviderClickSubtitle;
    case 'uzum':
      return l10n.paymentProviderUzumSubtitle;
    default:
      return null;
  }
}

/// Hafta kunining qisqa nomi (sana tanlash lentasi).
///
/// [weekday] — `DateTime.weekday` (1 = dushanba ... 7 = yakshanba).
String weekdayShortLabel(AppL10n l10n, int weekday) {
  switch (weekday) {
    case DateTime.monday:
      return l10n.weekdayShortMon;
    case DateTime.tuesday:
      return l10n.weekdayShortTue;
    case DateTime.wednesday:
      return l10n.weekdayShortWed;
    case DateTime.thursday:
      return l10n.weekdayShortThu;
    case DateTime.friday:
      return l10n.weekdayShortFri;
    case DateTime.saturday:
      return l10n.weekdayShortSat;
    case DateTime.sunday:
    default:
      return l10n.weekdayShortSun;
  }
}

/// Summa yorlig'i: `12345` -> "12345 so'm" / "12345 UZS".
///
/// Faqat BIRLIK tarjima qilinadi, RAQAM server qiymati (§6).
String consultationAmountLabel(AppL10n l10n, double amountUzs) =>
    l10n.consultationAmountUzs(amountUzs.toStringAsFixed(0));
