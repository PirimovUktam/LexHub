import 'package:lexhub/core/errors/exceptions.dart';
import 'package:lexhub/features/consultations/domain/entities/consultation_slot.dart';

/// §6: PARSER TO'QIMA QIYMAT YARATMAYDI.
///
/// Ilgari bu yerda bo'sh ustunlar quyidagilar bilan to'ldirilardi:
///   * `slot_time` yo'q     -> `DateTime.now()` (O'YLAB TOPILGAN vaqt, ya'ni
///     foydalanuvchi mavjud bo'lmagan slotni bron qilishi mumkin edi);
///   * `is_available` yo'q  -> `true` (FAIL-OPEN: band slot ham bo'sh
///     ko'rinardi);
///   * `price_amount_uzs`   -> `150000.0` (server bermagan NARX).
/// Endi: vaqt yo'q -> `ServerException` (format xatosi), noaniq bandlik ->
/// `false` (FAIL-CLOSED), narx yo'q -> `0.0` va UI qaror qabul qiladi.
class ConsultationSlotModel extends ConsultationSlot {
  const ConsultationSlotModel({
    required super.slotTime,
    required super.isAvailable,
    super.durationMinutes,
    required super.priceAmountUzs,
  });

  factory ConsultationSlotModel.fromJson(Map<String, dynamic> json) {
    final rawSlotTime = json['slot_time'];
    final slotTime =
        rawSlotTime == null ? null : DateTime.tryParse(rawSlotTime.toString());
    if (slotTime == null) {
      throw ServerException(
        message: "Bo'sh vaqt javobida `slot_time` yo'q yoki noto'g'ri.",
        details: json,
      );
    }

    return ConsultationSlotModel(
      slotTime: slotTime,
      isAvailable: json['is_available'] as bool? ?? false,
      durationMinutes: json['duration_minutes'] as int? ?? 0,
      priceAmountUzs: (json['price_amount_uzs'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'slot_time': slotTime.toIso8601String(),
      'is_available': isAvailable,
      'duration_minutes': durationMinutes,
      'price_amount_uzs': priceAmountUzs,
    };
  }
}

/// §6: TO'LOV CHECKOUT JAVOBI — SOXTA "MUVAFFAQIYAT" YO'Q.
///
/// Ilgari bu parser:
///   * `success` ustuni yo'q bo'lsa `true` deb hisoblardi (FAIL-OPEN:
///     server xato javob qaytarsa ham UI "bron qilindi" deb ko'rsatardi);
///   * `commission_amount_uzs` yo'q bo'lsa `priceUzs * 0.10` ni CLIENTDA
///     hisoblardi (pul matematikasi serverda bo'lishi shart);
///   * `expert_name` yo'q bo'lsa "Advokat" deb yozardi;
///   * `scheduled_at` yo'q bo'lsa `DateTime.now()` ni qo'yardi.
/// Endi: majburiy maydonlar bo'lmasa -> `ServerException` (format xatosi),
/// `success` yo'q bo'lsa -> `false` (FAIL-CLOSED), komissiya faqat serverdan.
class PaymentCheckoutModel extends PaymentCheckoutResult {
  const PaymentCheckoutModel({
    required super.success,
    required super.consultationId,
    required super.paymentId,
    required super.idempotencyKey,
    required super.priceAmountUzs,
    required super.priceAmountTiyin,
    super.commissionAmountUzs,
    required super.expertName,
    required super.scheduledAt,
    required super.status,
    required super.provider,
    super.checkoutUrl,
  });

  factory PaymentCheckoutModel.fromJson(Map<String, dynamic> json) {
    final consultationId = json['consultation_id'] as String? ?? '';
    final paymentId = json['payment_id'] as String? ?? '';
    final rawScheduledAt = json['scheduled_at'];
    final scheduledAt = rawScheduledAt == null
        ? null
        : DateTime.tryParse(rawScheduledAt.toString());

    if (consultationId.isEmpty || paymentId.isEmpty || scheduledAt == null) {
      throw ServerException(
        message: "To'lov javobi to'liq emas (bron ma'lumotlari yetishmaydi).",
        details: json,
      );
    }

    final priceTiyin = json['price_amount_tiyin'] as int? ?? 0;
    // `price_amount_uzs` yo'q bo'lsa tiyin'dan KONVERTATSIYA qilinadi (bu
    // to'qima emas — aynan shu server qiymatining boshqa birligi).
    final priceUzs =
        (json['price_amount_uzs'] as num?)?.toDouble() ?? (priceTiyin / 100.0);

    return PaymentCheckoutModel(
      success: json['success'] as bool? ?? false,
      consultationId: consultationId,
      paymentId: paymentId,
      idempotencyKey: json['idempotency_key'] as String? ?? '',
      priceAmountUzs: priceUzs,
      priceAmountTiyin: priceTiyin,
      commissionAmountUzs:
          (json['commission_amount_uzs'] as num?)?.toDouble() ?? 0.0,
      expertName: json['expert_name'] as String? ?? '',
      scheduledAt: scheduledAt,
      status: json['status'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      checkoutUrl: json['checkout_url'] as String?,
    );
  }
}

