import 'package:lexhub/features/legal_experts/domain/entities/expert_application.dart';

/// `expert_profiles` BAZA jadvalidan (view'dan EMAS) o'qilgan ariza qatori.
///
/// §6 QULFI (`legal_expert_model.dart` bilan bir xil siyosat): bo'sh maydon
/// SOXTA qiymat bilan TO'LDIRILMAYDI. Ariza kartasida "Ko'rsatilmagan" deb
/// chiqishi — moderator ko'rishi KERAK bo'lgan nuqson. Uni "namuna" litsenziya
/// raqami yoki o'ylab topilgan ish joyi bilan yashirish moderatorni yolg'on
/// asosda tasdiqlashga olib boradi.
class ExpertApplicationModel extends ExpertApplication {
  const ExpertApplicationModel({
    required super.applicationId,
    required super.userId,
    required super.fullName,
    required super.licenseNumber,
    required super.specialization,
    required super.workplace,
    required super.education,
    required super.experienceYears,
    super.licenseDocumentUrl,
    super.createdAt,
  });

  factory ExpertApplicationModel.fromJson(Map<String, dynamic> json) {
    // PostgREST embedded resource: `select=...,profiles!inner(full_name)`.
    // FK `expert_profiles.user_id -> profiles.id` mavjud, shuning uchun
    // qo'shimcha so'rov (N+1) KERAK EMAS.
    final embedded = json['profiles'];
    final profile = embedded is Map<String, dynamic> ? embedded : null;

    return ExpertApplicationModel(
      applicationId: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      fullName: (profile?['full_name'] as String?)?.trim() ?? '',
      licenseNumber: (json['license_number'] as String?)?.trim() ?? '',
      specialization: (json['specialization'] as String?)?.trim() ?? '',
      workplace: (json['workplace'] as String?)?.trim() ?? '',
      education: (json['education'] as String?)?.trim() ?? '',
      // `experience_years` NOT NULL CHECK (>= 0), lekin klient bazaga
      // ISHONMAYDI: `num` kelishi mumkin (PostgREST NUMERIC'ni `double`
      // qilib beradi), shuning uchun `as int` CAST QILINMAYDI.
      experienceYears: (json['experience_years'] as num?)?.toInt() ?? 0,
      licenseDocumentUrl: json['license_document_url'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }
}
