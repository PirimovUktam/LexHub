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
import 'package:lexhub/features/legal_experts/data/models/legal_expert_model.dart';
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
      throw ServerException(message: "Arizani yuborishda xatolik: $e");
    }
  }
}
