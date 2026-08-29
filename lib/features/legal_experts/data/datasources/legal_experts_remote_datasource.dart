/// TIMEOUT YUTILMAYDI (bu fayldagi barcha generic `catch (e)` uchun).
///
/// Xato matni `"...: $e"` ko'rinishida quriladi, ya'ni `TimeoutException`
/// yutilsa foydalanuvchi ekranida XOM texnik matn chiqadi va `ErrorHandler`
/// `FailureCode.timeout` o'rniga `server` beradi. `TimeoutException`
/// `AppException` EMAS — mavjud shox uni ushlamaydi.
library;

import 'dart:async';

import 'package:lexhub/core/errors/exceptions.dart';
import 'package:lexhub/core/network/supabase_db.dart';
import 'package:lexhub/features/legal_experts/data/models/expert_application_model.dart';
import 'package:lexhub/features/legal_experts/data/models/legal_expert_model.dart';
import 'package:lexhub/features/legal_experts/domain/entities/expert_application.dart';
import 'package:lexhub/features/legal_experts/domain/entities/legal_expert.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class LegalExpertsRemoteDataSource {
  Future<List<LegalExpert>> getExperts({
    String? specialization,
    String? city,
    String? searchQuery,
  });

  Future<LegalExpert> getExpertById(String id);

  Future<Map<String, dynamic>> applyForVerification({
    required String specialization,
    required int experienceYears,
    required String licenseNumber,
    String? licenseDocumentUrl,
    String? workplace,
    String? education,
    double consultationFee = 0.0,
  });

  /// TASDIQLASH KUTAYOTGAN arizalar (`verified_at IS NULL`).
  ///
  /// XAVFSIZLIK: bu so'rov `expert_profiles` BAZA jadvaliga boradi va
  /// SERVER tomonda RLS bilan qulflangan (`auth.uid() = user_id OR
  /// public.is_admin_or_moderator()`). Admin bo'lmagan foydalanuvchi chaqirsa
  /// FAQAT o'z arizasini ko'radi — ya'ni klientdagi rol tekshiruvi UX
  /// qulayligi, ishonch chegarasi EMAS.
  Future<List<ExpertApplication>> getPendingApplications();

  /// Arizani TASDIQLASH yoki RAD ETISH.
  ///
  /// FAQAT `verify_expert_application` RPC orqali: u `profiles.role`,
  /// `profiles.is_verified` va `expert_profiles.verified_at` ni BIR
  /// TRANZAKSIYADA qo'yadi va `is_admin_or_moderator()` bilan himoyalangan.
  /// Klientdan to'g'ridan-to'g'ri UPDATE QILINMAYDI (anti-tampering trigger
  /// uni bloklaydi va tasdiqlash yarim holatda qolardi).
  Future<Map<String, dynamic>> verifyExpertApplication({
    required String userId,
    required bool approve,
  });
}

/// ADVOKATLAR MA'LUMOTI FAQAT REAL BAZADAN OLINADI.
///
/// Ilgari bu klass `LegalExpertsLocalDataSource` ichidagi TO'QILGAN 6 ta
/// "tasdiqlangan advokat"ga (soxta litsenziya raqami, soxta telefon,
/// `isVerified: true`) qaytardi: (a) view bo'sh bo'lsa, (b) `catch (_)`
/// bo'lsa, (c) noto'g'ri ID so'ralsa. Bu §6 mock-data siyosatini buzardi va
/// yuridik ishonch nuqtai nazaridan Phase-1 dagi `_fallbackPosts.first`
/// bug'idan og'irroq edi. Endi:
///   * bo'sh natija -> BO'SH ro'yxat (UI empty state ko'rsatadi);
///   * xato        -> `ServerException` (UI xato + "Qaytadan urinish");
///   * topilmadi   -> 404 `ServerException` (mos kelmagan advokat EMAS).
class LegalExpertsRemoteDataSourceImpl implements LegalExpertsRemoteDataSource {
  final SupabaseClient? supabaseClient;

  LegalExpertsRemoteDataSourceImpl({this.supabaseClient});

  SupabaseClient get _client {
    final client = supabaseClient;
    if (client == null) {
      throw const ServerException(
        message: "Ma'lumotlar bazasiga ulanish sozlanmagan.",
      );
    }
    return client;
  }

  @override
  Future<List<LegalExpert>> getExperts({
    String? specialization,
    String? city,
    String? searchQuery,
  }) async {
    // DIQQAT: `specialization` / `city` — UI YORLIG'I EMAS, xom filtr
    // qiymati. "Barchasi" / "Barcha viloyatlar" holati UI'da `null` ga
    // aylantiriladi, shuning uchun bu yerda o'zbek matni bilan
    // taqqoslash YO'Q (§16: yorliq tarjima qilinsa ham filtr ishlaydi).
    try {
      var query = _client.db('public_expert_profiles_view').select();

      if (specialization != null && specialization.isNotEmpty) {
        query = query.ilike('specialization', '%$specialization%');
      }

      if (city != null && city.isNotEmpty) {
        // HUDUD FILTRI `workplace` MATNIGA qarshi ishlaydi, chunki `city`
        // ustuni bazada YO'Q — `public_expert_profiles_view` faqat
        // `workplace` ni ochadi. Shu sababli kelayotgan qiymat hudud
        // O'ZAGI bo'lishi SHART ("Toshkent", emas "Toshkent sh.") —
        // `UzbekRegions.filterValues` shuni kafolatlaydi. O'zak bo'lmasa
        // `ilike` real ish joyi matnini topmaydi va ro'yxat asossiz
        // bo'sh qaytadi.
        query = query.ilike('workplace', '%$city%');
      }

      final response = await query;
      final rawList = response as List<dynamic>?;
      final experts = (rawList ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map((json) => LegalExpertModel.fromJson(json))
          .toList();

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final lower = searchQuery.trim().toLowerCase();
        return experts.where((e) {
          return e.fullName.toLowerCase().contains(lower) ||
              e.specialization.toLowerCase().contains(lower) ||
              e.bio.toLowerCase().contains(lower);
        }).toList();
      }
      return experts;
    } catch (e) {
      if (e is AppException) rethrow;
      // TIMEOUT != server xatosi (fayl boshidagi izohga qara).
      if (e is TimeoutException) rethrow;
      throw ServerException(
        message: "Advokatlar ro'yxatini yuklab bo'lmadi: $e",
        details: e,
      );
    }
  }

  @override
  Future<LegalExpert> getExpertById(String id) async {
    final Map<String, dynamic>? response;
    try {
      response = await _client
          .db('public_expert_profiles_view')
          .select()
          .eq('expert_id', id)
          .maybeSingle();
    } catch (e) {
      if (e is AppException) rethrow;
      // TIMEOUT != server xatosi (fayl boshidagi izohga qara).
      if (e is TimeoutException) rethrow;
      throw ServerException(
        message: "Advokat ma'lumotlarini yuklab bo'lmadi: $e",
        details: e,
      );
    }

    // TOPILMADI = 404. Ilgari bu yerda `_experts.first` (soxta 'adv_1')
    // qaytardi, ya'ni foydalanuvchi SO'RAMAGAN advokatni ko'rardi.
    if (response == null) {
      throw ServerException(
        message: "Advokat topilmadi yoki ro'yxatdan chiqarilgan.",
        statusCode: 404,
        details: id,
      );
    }

    return LegalExpertModel.fromJson(response);
  }

  @override
  Future<Map<String, dynamic>> applyForVerification({
    required String specialization,
    required int experienceYears,
    required String licenseNumber,
    String? licenseDocumentUrl,
    String? workplace,
    String? education,
    double consultationFee = 0.0,
  }) async {
    if (supabaseClient == null) {
      throw const ServerException(message: "Supabase client not initialized.");
    }

    final currentUser = supabaseClient!.auth.currentUser;
    if (currentUser == null) {
      throw const UnauthorizedException(message: "Ariza topshirish uchun avval tizimga kiring.");
    }

    try {
      final result = await supabaseClient!.rpc(
        'apply_for_expert_verification',
        params: {
          'p_specialization': specialization,
          'p_experience_years': experienceYears,
          'p_license_number': licenseNumber,
          'p_license_document_url': licenseDocumentUrl,
          'p_workplace': workplace,
          'p_education': education,
          'p_consultation_fee': consultationFee,
        },
      );

      if (result is Map<String, dynamic>) {
        return result;
      }
      return {'success': true, 'message': 'Ariza muvaffaqiyatli topshirildi.'};
    } catch (e) {
      if (e is AppException) rethrow;
      // TIMEOUT != server xatosi (fayl boshidagi izohga qara).
      if (e is TimeoutException) rethrow;
      // SOVUTISH DAVRI — MASHINA O'QIY OLADIGAN KOD BO'YICHA.
      //
      // `apply_for_expert_verification()` rad etilgandan keyingi 24 soat
      // ichida `SQLSTATE LX429` bilan yiqiladi
      // (`20260829130000_expert_moderation_guard_fix_and_apply_cooldown.sql`).
      // Bu KUTILGAN biznes holati, nosozlik EMAS — shuning uchun umumiy
      // "Arizani yuborishda xatolik" matni BERILMAYDI: `ErrorHandler` uni
      // `FailureCode.applicationCooldown` ga o'giradi va foydalanuvchi
      // QACHON qayta topshirishi mumkinligini ko'radi.
      //
      // Matn bo'yicha taxmin QILINMAYDI (server matni o'zgarsa buzilardi) —
      // faqat SQLSTATE tekshiriladi. 423 (Locked) tanlandi, 429 EMAS: 429
      // umumiy rate-limit matnini ("bir necha daqiqadan keyin") berardi.
      if (e is PostgrestException && e.code == 'LX429') {
        throw ServerException(
          message: e.message,
          statusCode: 423,
          details: e.toString(),
        );
      }
      throw ServerException(message: "Arizani yuborishda xatolik: $e");
    }
  }

  @override
  Future<List<ExpertApplication>> getPendingApplications() async {
    try {
      // `select` ro'yxati ANIQ yozilgan (`*` EMAS): ariza kartasi uchun
      // kerak bo'lgan maydonlar + `profiles` dan FAQAT `full_name`.
      // `rating`/`reviews_count`/`consultation_fee` moderatsiya qaroriga
      // ta'sir qilmaydi, shuning uchun so'ralmaydi.
      final response = await _client.db('expert_profiles').select(
            'id, user_id, license_number, license_document_url, '
            'specialization, experience_years, education, workplace, '
            'created_at, profiles!inner(full_name)',
          )
          // TASDIQLASH KUTAYOTGANLAR: tasdiqlangan advokat bu ro'yxatda
          // KO'RINMASLIGI kerak, aks holda moderator uni ikkinchi marta
          // "tasdiqlab" `verified_at` ni yangilab yuborardi.
          .isFilter('verified_at', null)
          // RAD ETILGANLAR HAM CHIQADI. `rejected_at` ustuni
          // `20260829010000_expert_rejection_and_revocation.sql` bilan qo'shildi va
          // JONLI bazada mavjudligi `information_schema.columns` orqali
          // tasdiqlandi — ya'ni bu filtr `42703` bermaydi. U bo'lmasa rad
          // etilgan ariza ro'yxatga qaytib tushardi va moderator ayni qarorni
          // qayta-qayta bosardi (§20 jim no-op).
          //
          // Serverdagi partial index AYNI shu ikki shartga qurilgan:
          // `idx_expert_profiles_pending ... WHERE verified_at IS NULL AND
          // rejected_at IS NULL`.
          .isFilter('rejected_at', null)
          .order('created_at', ascending: true);

      final rawList = response as List<dynamic>?;
      return (rawList ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map((json) => ExpertApplicationModel.fromJson(json))
          .toList();
    } catch (e) {
      if (e is AppException) rethrow;
      // TIMEOUT != server xatosi (fayl boshidagi izohga qara).
      if (e is TimeoutException) rethrow;
      throw ServerException(
        message: "Arizalar ro'yxatini yuklab bo'lmadi: $e",
        details: e,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> verifyExpertApplication({
    required String userId,
    required bool approve,
  }) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw const UnauthorizedException(
        message: "Tasdiqlash uchun avval tizimga kiring.",
        statusCode: 401,
      );
    }

    try {
      final result = await _client.rpc(
        'verify_expert_application',
        params: {
          // DIQQAT: RPC `user_id` ni kutadi, `expert_profiles.id` NI EMAS.
          'p_target_user_id': userId,
          'p_approve': approve,
        },
      );

      if (result is Map<String, dynamic>) {
        // JIM MUVAFFAQIYAT YO'Q: RPC `{'success': true, 'status': ...}`
        // qaytaradi. `success` boshqa qiymat bo'lsa — bu MUVAFFAQIYAT EMAS,
        // va shunday deb ko'rsatilsa moderator arizani tasdiqlangan deb
        // o'ylab ketardi (§20).
        if (result['success'] != true) {
          throw ServerException(
            message: "Tasdiqlash bajarilmadi.",
            details: result,
          );
        }
        return result;
      }
      // Kutilmagan javob shakli JIM MUVAFFAQIYAT deb qabul QILINMAYDI:
      // ro'yxat yangilanmasa moderator tasdiq bo'ldi deb o'ylab qolardi.
      throw ServerException(
        message: "Tasdiqlash javobi tushunilmadi.",
        details: result,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      if (e is TimeoutException) rethrow;
      // `verify_expert_application()` admin bo'lmasa
      // `RAISE EXCEPTION 'Access Denied: ...'` beradi — PostgREST buni
      // `PostgrestException(code: 'P0001')` qilib qaytaradi. Bu SERVER
      // qarori: xom SQL matni UI'ga chiqmasligi uchun 403 ga aylantiriladi.
      if (e is PostgrestException &&
          e.message.contains('Access Denied')) {
        throw UnauthorizedException(
          message: "Bu amal uchun ruxsat yo'q.",
          statusCode: 403,
          details: e.message,
        );
      }
      throw ServerException(
        message: "Tasdiqlashda xatolik: $e",
        details: e,
      );
    }
  }
}
