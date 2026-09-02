import 'package:equatable/equatable.dart';

/// TASDIQLASH KUTAYOTGAN ADVOKAT ARIZASI (`expert_profiles.verified_at IS NULL`).
///
/// Bu entity OCHIQ ro'yxatdagi [LegalExpert] EMAS: u `public_expert_profiles_view`
/// dan emas, `expert_profiles` BAZA jadvalidan o'qiladi va faqat
/// admin/moderator uchun ko'rinadi (RLS: `auth.uid() = user_id OR
/// public.is_admin_or_moderator()`).
///
/// [licenseDocumentUrl] — PII (skanerlangan hujjatda F.I.SH., manzil, imzo
/// bo'ladi). U ATAYLAB ochiq view'ga qo'shilmagan va faqat shu moderatsiya
/// oqimida ishlatiladi.
///
/// EMAIL BU YERDA YO'Q: `public.profiles` da `email` ustuni mavjud emas
/// (`20260819_base_schema.sql`), email faqat `auth.users` da turadi va u
/// klientga ochiq emas. Shu sababli arizani [fullName] + [licenseNumber]
/// bo'yicha tekshirish kerak.
class ExpertApplication extends Equatable {
  /// `expert_profiles.id` — RPC uchun EMAS, faqat ro'yxat kaliti.
  final String applicationId;

  /// `expert_profiles.user_id` — `verify_expert_application()` AYNAN shuni
  /// kutadi (`p_target_user_id`). [applicationId] bilan almashtirilsa RPC
  /// "profil topilmadi" beradi.
  final String userId;

  final String fullName;
  final String licenseNumber;
  final String specialization;
  final String workplace;
  final String education;
  final int experienceYears;
  final String? licenseDocumentUrl;
  final DateTime? createdAt;

  const ExpertApplication({
    required this.applicationId,
    required this.userId,
    required this.fullName,
    required this.licenseNumber,
    required this.specialization,
    required this.workplace,
    required this.education,
    required this.experienceYears,
    this.licenseDocumentUrl,
    this.createdAt,
  });

  /// Hujjat biriktirilganmi. Bo'sh matn `null` bilan bir xil qaraladi —
  /// `''` ni `Uri.parse` qilib ochishga urinish jim muvaffaqiyatsizlik beradi.
  bool get hasLicenseDocument =>
      licenseDocumentUrl != null && licenseDocumentUrl!.trim().isNotEmpty;

  @override
  List<Object?> get props => [
        applicationId,
        userId,
        fullName,
        licenseNumber,
        specialization,
        workplace,
        education,
        experienceYears,
        licenseDocumentUrl,
        createdAt,
      ];
}
