import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/errors/exceptions.dart';
import 'package:lexhub/features/consultations/data/models/consultation_model.dart';
import 'package:lexhub/features/consultations/data/models/consultation_slot_model.dart';

/// §6 REGRESSION GUARD — KONSULTATSIYA/TO'LOV PARSERLARI.
///
/// Bu testlar quyidagi TO'QIMA QIYMATLAR qaytib kelmasligini qo'riqlaydi:
///   * slot vaqti yo'q -> `DateTime.now()` (mavjud bo'lmagan slot bron
///     qilinishi mumkin edi);
///   * `is_available` yo'q -> `true` (band slot bo'sh ko'rinardi, FAIL-OPEN);
///   * narx yo'q -> `150000.0` (server bermagan narx);
///   * `success` yo'q -> `true` (server xatosi "muvaffaqiyat" bo'lib ko'rinardi);
///   * komissiya yo'q -> `priceUzs * 0.10` (pul matematikasi CLIENTDA);
///   * `expert_name` yo'q -> `'Advokat'` / `'Tasdiqlangan Yurist'`;
///   * `scheduled_at` / `created_at` yo'q -> `DateTime.now()` (NOTO'G'RI
///     uchrashuv vaqti ko'rsatilardi).
void main() {
  group('§6: ConsultationSlotModel', () {
    test("`slot_time` yo'q -> ServerException (o'ylab topilgan vaqt yo'q)", () {
      expect(
        () => ConsultationSlotModel.fromJson(const {'is_available': true}),
        throwsA(isA<ServerException>()),
      );
    });

    test("`slot_time` noto'g'ri formatda -> ServerException", () {
      expect(
        () => ConsultationSlotModel.fromJson(const {'slot_time': 'ertaga'}),
        throwsA(isA<ServerException>()),
      );
    });

    test('FAIL-CLOSED: noaniq bandlik -> false, narx -> 0.0', () {
      final slot = ConsultationSlotModel.fromJson(const {
        'slot_time': '2026-08-25T10:00:00Z',
      });

      expect(slot.isAvailable, false, reason: 'FAIL-OPEN qaytmasligi kerak.');
      expect(slot.priceAmountUzs, 0.0, reason: '150000.0 to\'qima narx yo\'q.');
      expect(slot.durationMinutes, 0);
      expect(slot.slotTime.toUtc(), DateTime.utc(2026, 8, 25, 10));
    });
  });

  group('§6: PaymentCheckoutModel', () {
    const validCheckout = {
      'consultation_id': 'c1',
      'payment_id': 'p1',
      'scheduled_at': '2026-08-25T10:00:00Z',
    };

    test("majburiy maydonlar yo'q -> ServerException", () {
      expect(
        () => PaymentCheckoutModel.fromJson(const {'success': true}),
        throwsA(isA<ServerException>()),
      );
      expect(
        () => PaymentCheckoutModel.fromJson(const {
          'consultation_id': 'c1',
          'payment_id': 'p1',
        }),
        throwsA(isA<ServerException>()),
        reason: "`scheduled_at` yo'q -> DateTime.now() QO'YILMAYDI.",
      );
    });

    test('FAIL-CLOSED: `success` yo\'q -> false', () {
      final checkout = PaymentCheckoutModel.fromJson(validCheckout);
      expect(checkout.success, false,
          reason: "Server 'success' bermasa, bu MUVAFFAQIYAT emas.");
    });

    test('komissiya va ism CLIENTDA to\'qilmaydi', () {
      final checkout = PaymentCheckoutModel.fromJson({
        ...validCheckout,
        'success': true,
        'price_amount_tiyin': 20000000,
      });

      expect(checkout.priceAmountTiyin, 20000000);
      // tiyin -> UZS konvertatsiyasi (bir xil qiymatning boshqa birligi).
      expect(checkout.priceAmountUzs, 200000.0);
      expect(checkout.commissionAmountUzs, 0.0,
          reason: 'priceUzs * 0.10 clientda hisoblanmaydi.');
      expect(checkout.expertName, '',
          reason: "'Advokat' / 'Tasdiqlangan Yurist' to'qilmaydi.");
      expect(checkout.status, '');
      expect(checkout.provider, '');
      expect(checkout.idempotencyKey, '');
      expect(checkout.checkoutUrl, isNull,
          reason: 'book_consultation RPC checkout_url QAYTARMAYDI.');
    });
  });

  group('§6: ConsultationModel', () {
    const validRow = {
      'id': 'c1',
      'scheduled_at': '2026-08-25T10:00:00Z',
      'created_at': '2026-08-21T09:00:00Z',
    };

    test("`id` / `scheduled_at` / `created_at` yo'q -> ServerException", () {
      for (final broken in [
        const {'scheduled_at': '2026-08-25T10:00:00Z', 'created_at': '2026-08-21T09:00:00Z'},
        const {'id': 'c1', 'created_at': '2026-08-21T09:00:00Z'},
        const {'id': 'c1', 'scheduled_at': '2026-08-25T10:00:00Z'},
      ]) {
        expect(
          () => ConsultationModel.fromJson(broken),
          throwsA(isA<ServerException>()),
          reason: "Yetishmayotgan maydon uchun DateTime.now() QO'YILMAYDI.",
        );
      }
    });

    test('narx tiyin\'dan konvertatsiya qilinadi, qolgani bo\'sh qoladi', () {
      final consultation = ConsultationModel.fromJson({
        ...validRow,
        'price_amount_tiyin': 20000000,
      });

      expect(consultation.priceAmountUzs, 200000.0);
      expect(consultation.commissionAmountUzs, 0.0);
      expect(consultation.expertPayoutAmountUzs, 0.0);
      expect(consultation.refundAmountUzs, 0.0);
      expect(consultation.durationMinutes, 0,
          reason: "45 daqiqa to'qilmaydi — server qiymati ishlatiladi.");
      expect(consultation.meetingType, '');
      expect(consultation.meetingLink, isNull);
      expect(consultation.expertName, isNull);
      expect(consultation.scheduledAt.toUtc(), DateTime.utc(2026, 8, 25, 10));
      expect(consultation.createdAt.toUtc(), DateTime.utc(2026, 8, 21, 9));
    });
  });
}
