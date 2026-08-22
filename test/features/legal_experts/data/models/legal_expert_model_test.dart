import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/features/legal_experts/data/models/legal_expert_model.dart';
import 'package:lexhub/features/legal_experts/domain/entities/legal_expert.dart';

/// §6 REGRESSION: `LegalExpertModel.fromJson` hech qanday qiymatni O'YLAB
/// TOPMASLIGI kerak. Ilgari bo'sh ustunlar quyidagilar bilan to'ldirilardi:
///   * `rating` -> `5.0`
///   * `license_number` -> `ADV-VERIFIED`
///   * `phone` -> `+998901234567` (BOSIB QO'NG'IROQ QILINADIGAN SOXTA raqam)
///   * `is_verified` -> `true` (fail-OPEN "tasdiqlangan" belgisi)
///   * `city`/`address` -> "Toshkent sh." / "Advokatlik byurosi"
///   * `bio` -> reklama matni
///   * `experience_years` 0 -> 1
/// Bu test ularning QAYTIB KELISHINI bloklaydi.
void main() {
  group("LegalExpertModel.fromJson — to'qima qiymat yo'q (§6)", () {
    test("1. bo'sh JSON hech qanday ma'lumotni o'ylab topmaydi", () {
      final model = LegalExpertModel.fromJson(const <String, dynamic>{});

      expect(model.rating, 0.0,
          reason: "baholanmagan advokat 5.0 ko'rinmasligi kerak");
      expect(model.reviewsCount, 0);
      expect(model.experienceYears, 0,
          reason: '0 yil tajriba 1 yilga aylantirilmaydi');
      expect(model.successfulCasesCount, 0);
      expect(model.licenseNumber, '',
          reason: "soxta ADV-VERIFIED litsenziya yo'q");
      expect(model.phoneNumber, '', reason: "soxta +998901234567 raqam yo'q");
      expect(model.telegramUsername, '');
      expect(model.city, '');
      expect(model.address, '');
      expect(model.bio, '');
      expect(model.priceInfo, '');
      expect(model.consultationFee, isNull);
      expect(model.fullName, '');
      expect(model.specialization, '');
      expect(model.isVerified, isFalse,
          reason: 'FAIL-CLOSED: tasdiq faqat bazadan keladi');
      expect(model.consultationType, ConsultationType.all);
    });

    test("2. real ustunlar to'g'ri o'qiladi (view nomlari bilan)", () {
      final model = LegalExpertModel.fromJson(const <String, dynamic>{
        'expert_id': 'e1',
        'user_id': 'u1',
        'full_name': 'Kamola Yusupova',
        'specialization': 'Mehnat huquqi',
        'license_number': 'ADV-10293',
        'rating': 4.5,
        'reviews_count': 12,
        'experience_years': 7,
        'city': 'Samarqand sh.',
        'address': "Registon ko'chasi 4",
        'workplace': 'Yusupova & Partners',
        'education': 'TDYU',
        'consultation_fee': 250000,
        'is_profile_verified': true,
        'phone': '+998901112233',
        'telegram_username': 'kamola_adv',
        'bio': "Mehnat nizolari bo'yicha amaliyot.",
        'successful_cases_count': 34,
        'price_info': "250 000 so'mdan",
        'verified_at': '2026-01-15T10:00:00Z',
      });

      expect(model.id, 'e1');
      expect(model.userId, 'u1');
      expect(model.fullName, 'Kamola Yusupova');
      expect(model.specialization, 'Mehnat huquqi');
      expect(model.licenseNumber, 'ADV-10293');
      expect(model.rating, 4.5);
      expect(model.reviewsCount, 12);
      expect(model.experienceYears, 7);
      expect(model.city, 'Samarqand sh.');
      expect(model.address, "Registon ko'chasi 4");
      expect(model.consultationFee, 250000.0);
      expect(model.isVerified, isTrue);
      expect(model.phoneNumber, '+998901112233');
      expect(model.telegramUsername, 'kamola_adv');
      expect(model.successfulCasesCount, 34);
      expect(model.priceInfo, "250 000 so'mdan");
      expect(model.verifiedAt, DateTime.parse('2026-01-15T10:00:00Z'));
    });

    test("3. `is_verified` fallback ishlaydi, ustun yo'q bo'lsa FAIL-CLOSED",
        () {
      final legacy = LegalExpertModel.fromJson(
        const <String, dynamic>{'id': 'e2', 'is_verified': true},
      );
      expect(legacy.id, 'e2');
      expect(legacy.isVerified, isTrue);

      final noColumn =
          LegalExpertModel.fromJson(const <String, dynamic>{'id': 'e3'});
      expect(noColumn.isVerified, isFalse,
          reason: "ustun bo'lmasa 'tasdiqlangan' belgisi YOQILMAYDI");
    });

    test("4. `rating` matn bo'lsa ham to'qima 5.0 ga aylanmaydi", () {
      expect(
        LegalExpertModel.fromJson(
          const <String, dynamic>{'rating': 'not-a-number'},
        ).rating,
        0.0,
      );
      expect(
        LegalExpertModel.fromJson(const <String, dynamic>{'rating': '3.5'})
            .rating,
        3.5,
      );
    });

    test("5. `address` bo'sh bo'lsa `workplace` dan olinadi, aks holda bo'sh",
        () {
      final fromWorkplace = LegalExpertModel.fromJson(
        const <String, dynamic>{'workplace': 'Adliya Konsalting'},
      );
      expect(fromWorkplace.address, 'Adliya Konsalting');
      expect(fromWorkplace.city, '',
          reason: "shahar TO'QIB yozilmaydi ('Toshkent sh.' yo'q)");
    });
  });
}
