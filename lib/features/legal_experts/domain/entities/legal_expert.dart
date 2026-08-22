import 'package:equatable/equatable.dart';

/// Maslahat turi. DIQQAT: `public_expert_profiles_view` da bu ustun YO'Q,
/// shuning uchun UI hech qanday maslahat turini TASDIQ sifatida ko'rsatmaydi
/// (ilgari `ConsultationTypeExtension.displayName` orqali "Barcha turlar"
/// deb ko'rsatilardi — bu ma'lumot bazada bo'lmagan da'vo edi, §6).
enum ConsultationType { online, office, phone, all }

/// Domain entity for Verified Legal Experts / Lawyers in Uzbekistan
class LegalExpert extends Equatable {
  final String id;
  final String? userId;
  final String fullName;
  final String? avatarUrl;
  final String specialization;
  final String licenseNumber;
  final double rating;
  final int reviewsCount;
  final int experienceYears;
  final String city;
  final String address;
  final String? workplace;
  final String? education;
  final double? consultationFee;
  final bool isVerified;
  final ConsultationType consultationType;
  final String phoneNumber;
  final String telegramUsername;
  final String bio;
  final int successfulCasesCount;
  final String priceInfo;
  final DateTime? verifiedAt;

  const LegalExpert({
    required this.id,
    this.userId,
    required this.fullName,
    this.avatarUrl,
    required this.specialization,
    required this.licenseNumber,
    required this.rating,
    this.reviewsCount = 0,
    required this.experienceYears,
    required this.city,
    required this.address,
    this.workplace,
    this.education,
    this.consultationFee,
    // FAIL-CLOSED (§6/§9): "tasdiqlangan" belgisi faqat bazadan kelgan
    // qiymat bilan yoqiladi. Ilgari default `true` edi — ustun bo'lmasa
    // ham advokat "verified" ko'rinardi.
    this.isVerified = false,
    required this.consultationType,
    required this.phoneNumber,
    required this.telegramUsername,
    required this.bio,
    this.successfulCasesCount = 0,
    // Narx MATNI o'ylab topilmaydi: bo'sh bo'lsa UI `expertPriceText()`
    // orqali `consultation_fee` yoki "kelishuv asosida" yorlig'ini beradi.
    this.priceInfo = '',
    this.verifiedAt,
  });

  @override
  List<Object?> get props => [
        id,
        userId,
        fullName,
        avatarUrl,
        specialization,
        licenseNumber,
        rating,
        reviewsCount,
        experienceYears,
        city,
        address,
        workplace,
        education,
        consultationFee,
        isVerified,
        consultationType,
        phoneNumber,
        telegramUsername,
        bio,
        successfulCasesCount,
        priceInfo,
        verifiedAt,
      ];
}
