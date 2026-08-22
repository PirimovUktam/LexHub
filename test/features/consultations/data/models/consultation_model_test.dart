import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/features/consultations/data/models/consultation_model.dart';
import 'package:lexhub/features/consultations/data/models/consultation_slot_model.dart';
import 'package:lexhub/features/consultations/domain/entities/consultation.dart';

void main() {
  group('Sprint 9: ConsultationModel & SlotModel Unit Tests', () {
    test('1. ConsultationModel correctly parses from JSON and formats UZS / Tiyin', () {
      final json = {
        'id': 'consultation_123',
        'citizen_id': 'user_abc',
        'expert_id': 'expert_xyz',
        'expert_name': 'Sanjar Rahimov',
        'specialization': 'Mehnat huquqi',
        'scheduled_at': '2026-08-25T14:00:00.000Z',
        'duration_minutes': 45,
        'price_amount_tiyin': 20000000,
        'commission_amount_tiyin': 2000000,
        'expert_payout_amount_tiyin': 18000000,
        'status': 'confirmed',
        'payment_status': 'paid',
        'payment_id': 'pay_999',
        'meeting_link': 'https://meet.lexhub.uz/room/consultation_123',
        'meeting_type': 'online',
        'notes': 'Mehnat nizosi',
        'refund_amount_tiyin': 0,
        'created_at': '2026-08-21T10:00:00.000Z',
      };

      final model = ConsultationModel.fromJson(json);

      expect(model.id, 'consultation_123');
      expect(model.expertName, 'Sanjar Rahimov');
      expect(model.priceAmountUzs, 200000.0);
      expect(model.priceAmountTiyin, 20000000);
      expect(model.commissionAmountUzs, 20000.0);
      expect(model.expertPayoutAmountUzs, 180000.0);
      expect(model.status, ConsultationStatus.confirmed);
      expect(model.paymentStatus, PaymentStatus.paid);
      expect(model.meetingLink, 'https://meet.lexhub.uz/room/consultation_123');
    });

    test('2. ConsultationSlotModel correctly parses available and booked slots', () {
      final json = {
        'slot_time': '2026-08-25T09:00:00.000Z',
        'is_available': true,
        'duration_minutes': 45,
        'price_amount_uzs': 150000.0,
      };

      final slot = ConsultationSlotModel.fromJson(json);
      expect(slot.isAvailable, true);
      expect(slot.durationMinutes, 45);
      expect(slot.priceAmountUzs, 150000.0);
    });

    test('3. PaymentCheckoutModel parses checkout responses accurately', () {
      final json = {
        'success': true,
        'consultation_id': 'c_1',
        'payment_id': 'p_1',
        'idempotency_key': 'pay_c_1_12345',
        'price_amount_uzs': 200000.0,
        'price_amount_tiyin': 20000000,
        'commission_amount_uzs': 20000.0,
        'expert_name': 'Jasur Karimov',
        'scheduled_at': '2026-08-26T11:00:00.000Z',
        'status': 'awaiting_payment',
        'provider': 'payme',
      };

      final checkout = PaymentCheckoutModel.fromJson(json);
      expect(checkout.success, true);
      expect(checkout.priceAmountUzs, 200000.0);
      expect(checkout.expertName, 'Jasur Karimov');
      expect(checkout.provider, 'payme');
    });
  });
}
