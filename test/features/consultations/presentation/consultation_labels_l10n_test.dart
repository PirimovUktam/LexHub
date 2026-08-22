import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/localization/consultation_labels.dart';
import 'package:lexhub/features/consultations/domain/entities/consultation.dart';
import 'package:lexhub/l10n/gen/app_localizations.dart';

/// §16 REGRESSION GUARD — KONSULTATSIYA/TO'LOV YORLIQLARI.
///
/// Bu testlar ikki narsani birdan qo'riqlaydi:
///   1. LOKALIZATSIYA: har bir ekran yorlig'i `uz` va `en` da HAQIQATAN
///      boshqacha chiqadi. Ilgari yorliqlar `ConsultationStatus.displayName`
///      ichida — domain qatlamida — o'zbekcha qotib qolgan edi, ya'ni ingliz
///      tilida ham "Tasdiqlangan" ko'rinardi.
///   2. DB KONTRAKTI: "Database values o'sha-o'sha qoladi." `fromString`
///      xom qiymatlarni (`awaiting_payment`, `in_progress`, ...) o'zgarmagan
///      holda parse qilishi shart; `p_meeting_type` va `payments.provider`
///      ID'lari (`online`/`phone`/`office`, `payme`/`click`/`uzum`) TARJIMA
///      QILINMAYDI — ular faqat KALIT sifatida ishlatiladi.
void main() {
  late AppL10n uz;
  late AppL10n en;

  setUpAll(() async {
    uz = await AppL10n.delegate.load(const Locale('uz'));
    en = await AppL10n.delegate.load(const Locale('en'));
  });

  group('§16: consultationStatusLabel', () {
    test('barcha holatlar ikki tilda ham bo\'sh emas va takrorlanmaydi', () {
      final uzLabels = <String>[];
      final enLabels = <String>[];

      for (final status in ConsultationStatus.values) {
        final uzLabel = consultationStatusLabel(uz, status);
        final enLabel = consultationStatusLabel(en, status);
        expect(uzLabel.trim(), isNotEmpty, reason: 'uz: $status');
        expect(enLabel.trim(), isNotEmpty, reason: 'en: $status');
        uzLabels.add(uzLabel);
        enLabels.add(enLabel);
      }

      expect(uzLabels.toSet().length, ConsultationStatus.values.length,
          reason: 'Har bir holat FARQLI yorliqqa ega bo\'lishi kerak.');
      expect(enLabels.toSet().length, ConsultationStatus.values.length);
    });

    test('ingliz tilida o\'zbekcha yorliq QAYTMAYDI', () {
      expect(consultationStatusLabel(uz, ConsultationStatus.confirmed),
          'Tasdiqlangan');
      expect(consultationStatusLabel(en, ConsultationStatus.confirmed),
          'Confirmed');
      expect(consultationStatusLabel(en, ConsultationStatus.awaitingPayment),
          'Awaiting payment');
      // Eng muhimi: hech bir ingliz yorlig'i o'zbekcha bilan bir xil emas.
      for (final status in ConsultationStatus.values) {
        expect(consultationStatusLabel(en, status),
            isNot(consultationStatusLabel(uz, status)),
            reason: '$status ingliz tilida tarjima qilinmagan.');
      }
    });
  });

  group('§16: DB qiymatlari o\'zgarmaydi', () {
    test('ConsultationStatusExtension.fromString xom qiymatlarni saqlaydi', () {
      const cases = <String, ConsultationStatus>{
        'pending': ConsultationStatus.pending,
        'awaiting_payment': ConsultationStatus.awaitingPayment,
        'confirmed': ConsultationStatus.confirmed,
        'in_progress': ConsultationStatus.inProgress,
        'completed': ConsultationStatus.completed,
        'cancelled': ConsultationStatus.cancelled,
        'expired': ConsultationStatus.expired,
        'disputed': ConsultationStatus.disputed,
      };
      cases.forEach((raw, expected) {
        expect(ConsultationStatusExtension.fromString(raw), expected,
            reason: "DB qiymati '$raw' boshqa holatga tushdi.");
      });
      // Tanilmagan/`null` qiymat fail-closed: eng past huquqli holat.
      expect(ConsultationStatusExtension.fromString(null),
          ConsultationStatus.pending);
      expect(ConsultationStatusExtension.fromString('yangi_holat'),
          ConsultationStatus.pending);
    });

    test('PaymentStatusExtension.fromString xom qiymatlarni saqlaydi', () {
      const cases = <String, PaymentStatus>{
        'pending': PaymentStatus.pending,
        'processing': PaymentStatus.processing,
        'paid': PaymentStatus.paid,
        'failed': PaymentStatus.failed,
        'refunding': PaymentStatus.refunding,
        'refunded': PaymentStatus.refunded,
        'partially_refunded': PaymentStatus.partiallyRefunded,
      };
      cases.forEach((raw, expected) {
        expect(PaymentStatusExtension.fromString(raw), expected,
            reason: "DB qiymati '$raw' boshqa holatga tushdi.");
      });
      expect(PaymentStatusExtension.fromString(null), PaymentStatus.pending);
    });

    test('meeting type ID lari kalit bo\'lib qoladi, yorliq esa tarjimalanadi',
        () {
      expect(consultationMeetingTypeLabel(uz, 'online'), 'Onlayn Video');
      expect(consultationMeetingTypeLabel(en, 'online'), 'Online video');
      expect(consultationMeetingTypeLabel(en, 'phone'), 'Phone');
      expect(consultationMeetingTypeLabel(en, 'office'), 'At the office');
      // Tanilmagan XOM qiymat O'ZI ko'rsatiladi (to'qima yorliq YO'Q).
      expect(consultationMeetingTypeLabel(en, 'video_call'), 'video_call');
    });
  });

  group('§16: to\'lov provayderi tavsifi', () {
    test('barcha provayderlar ikki tilda tavsifga ega', () {
      for (final id in ['payme', 'click', 'uzum']) {
        expect(paymentProviderSubtitle(uz, id), isNotNull, reason: 'uz: $id');
        expect(paymentProviderSubtitle(en, id), isNotNull, reason: 'en: $id');
        expect(paymentProviderSubtitle(en, id),
            isNot(paymentProviderSubtitle(uz, id)));
      }
    });

    test("QO'SHNI LITERAL BUG: \"to lov\" QAYTMAYDI", () {
      // Ilgari `'Humo, Uzcard orqali to''lov'` Dart'da 'Humo, Uzcard orqali to'
      // + 'lov' bo'lib birlashgan va ekranda "to lov" ko'ringan.
      final payme = paymentProviderSubtitle(uz, 'payme')!;
      expect(payme, contains("to'lov"));
      expect(payme, isNot(contains('to lov')));
      expect(paymentProviderSubtitle(uz, 'click')!, contains("to'lov"));
    });

    test('tanilmagan provayder -> null (to\'qima tavsif YO\'Q)', () {
      expect(paymentProviderSubtitle(uz, 'stripe'), isNull);
    });
  });

  group('§16: hafta kunlari va summa', () {
    test('7 kun ikki tilda ham farqli', () {
      for (final l10n in [uz, en]) {
        final labels = [
          for (var weekday = 1; weekday <= 7; weekday++)
            weekdayShortLabel(l10n, weekday),
        ];
        expect(labels.toSet().length, 7);
        expect(labels.every((label) => label.trim().isNotEmpty), isTrue);
      }
      expect(weekdayShortLabel(uz, DateTime.monday), 'Dush');
      expect(weekdayShortLabel(en, DateTime.monday), 'Mon');
      expect(weekdayShortLabel(en, DateTime.sunday), 'Sun');
    });

    test('summa: RAQAM server qiymati, faqat BIRLIK tarjimalanadi', () {
      expect(consultationAmountLabel(uz, 150000), "150000 so'm");
      expect(consultationAmountLabel(en, 150000), '150000 UZS');
      // 0 ham haqiqiy server qiymati — "bepul" deb TO'QILMAYDI.
      expect(consultationAmountLabel(en, 0), '0 UZS');
    });
  });
}
