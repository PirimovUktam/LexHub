/// TIMEOUT YUTILMAYDI (bu fayldagi barcha generic `catch (e)` uchun).
///
/// Bu faylning har bir shoxi `message: "...: $e"` ko'rinishida xato matnini
/// QURADI — ya'ni `TimeoutException` shu yerga tushsa foydalanuvchi ekranida
/// XOM `TimeoutException after 0:00:20.000000: rest/v1/consultations` matni
/// paydo bo'ladi va `ErrorHandler` `FailureCode.server` beradi (ingliz UI
/// to'g'ri ARB matnini tanlay olmaydi). `TimeoutException` `AppException`
/// EMAS, shuning uchun mavjud `if (e is AppException) rethrow;` uni
/// ushlamaydi — alohida shox kerak.
library;

import 'dart:async';

import 'package:lexhub/core/errors/exceptions.dart';
import 'package:lexhub/core/network/supabase_db.dart';
import 'package:lexhub/features/consultations/data/models/consultation_model.dart';
import 'package:lexhub/features/consultations/data/models/consultation_slot_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class ConsultationRemoteDataSource {
  Future<List<ConsultationSlotModel>> getAvailableSlots({
    required String expertId,
    required DateTime date,
  });

  Future<PaymentCheckoutModel> bookConsultation({
    required String expertId,
    required DateTime scheduledAt,
    String meetingType = 'online',
    String? notes,
    String? questionId,
    String provider = 'payme',
  });

  Future<Map<String, dynamic>> processPaymentWebhook({
    required String paymentId,
    required String provider,
    required String providerTransactionId,
    required int paidAmountTiyin,
    String status = 'paid',
    String? errorMessage,
  });

  Future<List<ConsultationModel>> getMyConsultations();

  /// [reason] — XOM DB QIYMATI: `cancel_consultation(p_reason)` ga uzatiladi
  /// va SQL funksiyasining default'i bilan bir xil. Bu UI matni EMAS (§16).
  Future<Map<String, dynamic>> cancelConsultation({
    required String consultationId,
    String reason = 'Foydalanuvchi tomonidan bekor qilindi',
  });
}

/// KONSULTATSIYA VA TO'LOV — FAQAT REAL BACKEND (§6).
///
/// Ilgari bu klass `ConsultationLocalDataSource` ichidagi TO'QILGAN
/// ma'lumotlarga qaytardi va bu PUL OQIMIDA soxta muvaffaqiyat yaratardi:
///   * `getAvailableSlots`: `catch (_)` yoki BO'SH natija -> kuniga 9 ta
///     O'YLAB TOPILGAN slot (200 000 so'm), advokat jadvalidan qat'i nazar;
///   * `bookConsultation`: tarmoq xatosida -> soxta `payment_id`, soxta
///     `checkout_url` (`https://checkout.paycom.uz/...`) va "Tasdiqlangan
///     Yurist" nomi bilan bazada MAVJUD BO'LMAGAN bron;
///   * `processPaymentWebhook`: client `null` bo'lsa -> `{'success': true,
///     'status': 'paid'}`, ya'ni TO'LOV QILINMAGAN HOLDA "To'lov
///     muvaffaqiyatli bajarildi!" ekrani;
///   * `getMyConsultations`: `catch (_)` -> `status: confirmed`,
///     `paymentStatus: paid` bo'lgan soxta konsultatsiya + soxta xona
///     havolasi (`https://meet.lexhub.uz/room/local_consultation_1`);
///   * `cancelConsultation`: client `null` bo'lsa -> `refund_percent: 100`,
///     `refund_amount_uzs: 200000` — bazada hech qanday yozuv bo'lmasa ham.
///
/// Endi: bo'sh natija -> BO'SH ro'yxat (UI empty state), xato ->
/// `ServerException` (UI xato + "Qaytadan urinish"), server `success: false`
/// qaytarsa -> XATO (soxta muvaffaqiyat EMAS).
class ConsultationRemoteDataSourceImpl implements ConsultationRemoteDataSource {
  final SupabaseClient? supabaseClient;

  ConsultationRemoteDataSourceImpl({this.supabaseClient});

  SupabaseClient get _client {
    final client = supabaseClient;
    if (client == null) {
      throw const ServerException(
        message: "Ma'lumotlar bazasiga ulanish sozlanmagan.",
      );
    }
    return client;
  }

  /// RPC javobi `jsonb_build_object('success', ...)` shartnomasiga mos
  /// bo'lishini talab qiladi. `success != true` -> XATO.
  Map<String, dynamic> _requireSuccessMap(dynamic response, String context) {
    if (response is! Map<String, dynamic>) {
      throw ServerException(
        message: "$context: server javobi noto'g'ri formatda.",
        details: response,
      );
    }
    if (response['success'] != true) {
      final serverMessage = response['error'] ?? response['message'];
      throw ServerException(
        message: serverMessage?.toString() ?? '$context: amal bajarilmadi.',
        details: response,
      );
    }
    return response;
  }

  String _requireUserId(String action) {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw UnauthorizedException(message: action, statusCode: 401);
    }
    return userId;
  }

  @override
  Future<List<ConsultationSlotModel>> getAvailableSlots({
    required String expertId,
    required DateTime date,
  }) async {
    final dateStr = "${date.year.toString().padLeft(4, '0')}-"
        "${date.month.toString().padLeft(2, '0')}-"
        "${date.day.toString().padLeft(2, '0')}";

    try {
      final response = await _client.rpc(
        'get_expert_available_slots',
        params: {'p_expert_id': expertId, 'p_date': dateStr},
      );

      if (response is! List) {
        throw ServerException(
          message: "Bo'sh vaqtlar javobi noto'g'ri formatda.",
          details: response,
        );
      }

      // BO'SH RO'YXAT AYNAN BO'SH QOLADI: advokatning shu kunga jadvali
      // bo'lmasa UI "bo'sh slot yo'q" deb ko'rsatadi (soxta slot YO'Q).
      return response
          .whereType<Map<String, dynamic>>()
          .map((json) => ConsultationSlotModel.fromJson(json))
          .toList();
    } catch (e) {
      if (e is AppException) rethrow;
      // TIMEOUT != server xatosi (fayl boshidagi izohga qara).
      if (e is TimeoutException) rethrow;
      throw ServerException(
        message: "Bo'sh vaqtlarni yuklab bo'lmadi: $e",
        details: e,
      );
    }
  }

  @override
  Future<PaymentCheckoutModel> bookConsultation({
    required String expertId,
    required DateTime scheduledAt,
    String meetingType = 'online',
    String? notes,
    String? questionId,
    String provider = 'payme',
  }) async {
    _requireUserId('Konsultatsiya bron qilish uchun avval tizimga kiring.');

    try {
      final response = await _client.rpc(
        'book_consultation',
        params: {
          'p_expert_id': expertId,
          'p_scheduled_at': scheduledAt.toIso8601String(),
          'p_meeting_type': meetingType,
          'p_notes': notes,
          'p_question_id': questionId,
          'p_provider': provider,
        },
      );

      return PaymentCheckoutModel.fromJson(
        _requireSuccessMap(response, 'Bron qilish'),
      );
    } catch (e) {
      if (e is AppException) rethrow;
      // TIMEOUT != server xatosi (fayl boshidagi izohga qara).
      if (e is TimeoutException) rethrow;
      throw ServerException(
        message: "Konsultatsiyani bron qilib bo'lmadi: $e",
        details: e,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> processPaymentWebhook({
    required String paymentId,
    required String provider,
    required String providerTransactionId,
    required int paidAmountTiyin,
    String status = 'paid',
    String? errorMessage,
  }) async {
    try {
      final response = await _client.rpc(
        'process_payment_webhook',
        params: {
          'p_payment_id': paymentId,
          'p_provider': provider,
          'p_provider_transaction_id': providerTransactionId,
          'p_paid_amount_tiyin': paidAmountTiyin,
          'p_status': status,
          'p_error_message': errorMessage,
        },
      );

      // `process_payment_webhook` to'lov muvaffaqiyatsiz bo'lganda
      // `{'success': false, 'status': 'failed', 'error': ...}` qaytaradi.
      // Ilgari bu javob ham `Right(...)` bo'lib UI'da "To'lov muvaffaqiyatli
      // bajarildi!" deb ko'rsatilardi (§3: "DB xatosi success sifatida").
      return _requireSuccessMap(response, "To'lovni tasdiqlash");
    } catch (e) {
      if (e is AppException) rethrow;
      // TIMEOUT != server xatosi (fayl boshidagi izohga qara).
      if (e is TimeoutException) rethrow;
      throw ServerException(
        message: "To'lovni tasdiqlab bo'lmadi: $e",
        details: e,
      );
    }
  }

  @override
  Future<List<ConsultationModel>> getMyConsultations() async {
    _requireUserId("Konsultatsiyalarni ko'rish uchun avval tizimga kiring.");

    try {
      // RLS: fuqaro faqat o'z konsultatsiyalarini, advokat esa faqat o'ziga
      // tegishlilarini ko'radi (server tomonda filtrlanadi).
      final response = await _client.db('consultations').select('''
                *,
                expert:expert_profiles(
                  id,
                  specialization,
                  user:profiles!expert_profiles_user_id_fkey(full_name)
                ),
                citizen:profiles!consultations_citizen_id_fkey(full_name)
              ''').order('scheduled_at', ascending: false);

      // `PostgrestFilterBuilder.select()` STATIK ravishda `PostgrestList`
      // (ya'ni `List<Map<String, dynamic>>`) qaytaradi, shuning uchun bu yerda
      // qo'shimcha `is! List` tekshiruvi kerak emas. Qator ichidagi noto'g'ri
      // turlar `whereType` bilan chiqarib tashlanadi, majburiy maydonlar esa
      // `ConsultationModel.fromJson` ichida tekshiriladi (§6).
      return response.whereType<Map<String, dynamic>>().map((json) {
        final expertObj = json['expert'] as Map<String, dynamic>?;
        final userObj = expertObj?['user'] as Map<String, dynamic>?;
        final citizenObj = json['citizen'] as Map<String, dynamic>?;

        final enriched = Map<String, dynamic>.from(json);
        enriched['expert_name'] = userObj?['full_name'];
        enriched['specialization'] = expertObj?['specialization'];
        enriched['citizen_name'] = citizenObj?['full_name'];

        return ConsultationModel.fromJson(enriched);
      }).toList();
    } catch (e) {
      if (e is AppException) rethrow;
      // TIMEOUT != server xatosi (fayl boshidagi izohga qara).
      if (e is TimeoutException) rethrow;
      throw ServerException(
        message: "Konsultatsiyalarni yuklab bo'lmadi: $e",
        details: e,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> cancelConsultation({
    required String consultationId,
    String reason = 'Foydalanuvchi tomonidan bekor qilindi',
  }) async {
    _requireUserId('Bekor qilish uchun avval tizimga kiring.');

    try {
      final response = await _client.rpc(
        'cancel_consultation',
        params: {
          'p_consultation_id': consultationId,
          'p_reason': reason,
        },
      );

      return _requireSuccessMap(response, 'Bekor qilish');
    } catch (e) {
      if (e is AppException) rethrow;
      // TIMEOUT != server xatosi (fayl boshidagi izohga qara).
      if (e is TimeoutException) rethrow;
      throw ServerException(
        message: "Konsultatsiyani bekor qilib bo'lmadi: $e",
        details: e,
      );
    }
  }
}

