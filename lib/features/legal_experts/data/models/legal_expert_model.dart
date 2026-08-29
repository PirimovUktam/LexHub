import 'package:lexhub/core/constants/uzbek_regions.dart';
import 'package:lexhub/features/legal_experts/domain/entities/legal_expert.dart';

/// ADVOKAT YOZUVINI PARSE QILISH — TO'QIMA QIYMAT YO'Q (§6).
///
/// Ilgari bu `fromJson` bo'sh ustunlarni O'YLAB TOPILGAN qiymatlar bilan
/// to'ldirardi va natijada foydalanuvchi mavjud bo'lmagan ma'lumotni
/// haqiqiy deb ko'rardi:
///   * `rating` -> `5.0`            (bahosi yo'q advokat 5 yulduz ko'rinardi)
///   * `license_number` -> `ADV-VERIFIED`  (soxta litsenziya)
///   * `phone` -> `+998901234567`   (SOXTA, lekin BOSIB QO'NG'IROQ QILINADIGAN raqam)
///   * `is_verified` -> `true`      (fail-OPEN "tasdiqlangan" belgisi)
///   * `city`/`address` -> `Toshkent sh.` / `Advokatlik byurosi`
///   * `bio` -> "Malakali yuridik yordam ko'rsatuvchi advokat."
///   * `experience_years` 0 bo'lsa -> `1`
///
/// Endi bo'sh ustun BO'SH qoladi (`''` / `0` / `false`), UI esa
/// `lib/core/localization/expert_labels.dart` orqali "ko'rsatilmagan" deb
/// yozadi yoki tegishli satrni umuman chiqarmaydi.
class LegalExpertModel extends LegalExpert {
  const LegalExpertModel({
    required super.id,
    super.userId,
    required super.fullName,
    super.avatarUrl,
    required super.specialization,
    required super.licenseNumber,
    required super.rating,
    super.reviewsCount = 0,
    required super.experienceYears,
    required super.city,
    required super.address,
    super.workplace,
    super.education,
    super.consultationFee,
    super.isVerified = false,
    required super.consultationType,
    required super.phoneNumber,
    required super.telegramUsername,
    required super.bio,
    super.successfulCasesCount = 0,
    super.priceInfo = '',
    super.verifiedAt,
  });

  factory LegalExpertModel.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    int parseInt(dynamic val) {
      if (val is int) return val;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 0;
      return 0;
    }

    final id = json['expert_id'] as String? ?? json['id'] as String? ?? '';
    final userId = json['user_id'] as String?;
    final fullName = json['full_name'] as String? ?? '';
    final avatarUrl = json['avatar_url'] as String?;
    final specialization = json['specialization'] as String? ?? '';
    final licenseNumber = json['license_number'] as String? ?? '';
    final rating = parseDouble(json['rating']);
    final reviewsCount = parseInt(json['reviews_count']);
    final experienceYears = parseInt(json['experience_years']);
    final workplace = json['workplace'] as String?;
    // HUDUD: `city` ustuni bazada YO'Q (`supabase/migrations/*.sql` bo'ylab
    // nol moslik), ya'ni `json['city']` DOIM `null` keladi va bu qator ilgari
    // har doim `''` bergan — kartada hudud hech qachon ko'rinmagan.
    // `UzbekRegions.regionOf()` uni `workplace` matnidan deterministik
    // ajratadi; topilmasa `''` qoladi va `expertLocationText()` hududni
    // umuman chiqarmaydi (to'qima qiymat YOZILMAYDI).
    final city =
        json['city'] as String? ?? UzbekRegions.regionOf(workplace) ?? '';
    final address = json['address'] as String? ?? json['workplace'] as String? ?? '';
    final education = json['education'] as String?;
    final consultationFee = json['consultation_fee'] != null ? parseDouble(json['consultation_fee']) : null;
    final isVerified = json['is_profile_verified'] as bool? ?? json['is_verified'] as bool? ?? false;
    final phoneNumber = json['phone'] as String? ?? json['phone_number'] as String? ?? '';
    final telegramUsername = json['telegram_username'] as String? ?? '';
    final bio = json['bio'] as String? ?? json['education'] as String? ?? '';
    final successfulCasesCount = parseInt(json['successful_cases_count']);
    // `price_info` FAQAT bazadan keladi. Miqdorni matnga aylantirish
    // (valyuta so'zi bilan) PRESENTATION vazifasi -> `expertPriceText()`.
    final priceInfo = json['price_info'] as String? ?? '';
    final verifiedAt = json['verified_at'] != null ? DateTime.tryParse(json['verified_at'].toString()) : null;

    return LegalExpertModel(
      id: id,
      userId: userId,
      fullName: fullName,
      avatarUrl: avatarUrl,
      specialization: specialization,
      licenseNumber: licenseNumber,
      rating: rating,
      reviewsCount: reviewsCount,
      experienceYears: experienceYears,
      city: city,
      address: address,
      workplace: workplace,
      education: education,
      consultationFee: consultationFee,
      isVerified: isVerified,
      // Bazada (`public_expert_profiles_view`) maslahat turi ustuni YO'Q.
      // Bu qiymat UI'da DA'VO sifatida KO'RSATILMAYDI — `ExpertProfileModal`
      // dagi "Maslahat turi: …" satri shu sababli olib tashlandi (§6).
      consultationType: ConsultationType.all,
      phoneNumber: phoneNumber,
      telegramUsername: telegramUsername,
      bio: bio,
      successfulCasesCount: successfulCasesCount,
      priceInfo: priceInfo,
      verifiedAt: verifiedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'expert_id': id,
      'user_id': userId,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'specialization': specialization,
      'license_number': licenseNumber,
      'rating': rating,
      'reviews_count': reviewsCount,
      'experience_years': experienceYears,
      'city': city,
      'address': address,
      'workplace': workplace,
      'education': education,
      'consultation_fee': consultationFee,
      'is_verified': isVerified,
      'phone': phoneNumber,
      'telegram_username': telegramUsername,
      'bio': bio,
      'successful_cases_count': successfulCasesCount,
      'price_info': priceInfo,
      'verified_at': verifiedAt?.toIso8601String(),
    };
  }
}
