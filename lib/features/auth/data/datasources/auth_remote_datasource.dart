import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:lexhub/core/errors/exceptions.dart';
import 'package:lexhub/core/network/request_timeout.dart';
import 'package:lexhub/core/network/supabase_db.dart';
import 'package:lexhub/features/auth/data/models/user_model.dart';
import 'package:lexhub/features/auth/data/models/user_profile_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  });

  Future<UserModel> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
  });

  Future<void> signOut();

  Future<UserModel?> getCurrentUser();

  Future<UserProfileModel> getUserProfile(String userId);

  Future<UserProfileModel> updateUserProfile(UserProfileModel profile);

  Stream<UserModel?> get authStateChanges;
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final SupabaseClient supabaseClient;

  AuthRemoteDataSourceImpl({required this.supabaseClient});

  @override
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await supabaseClient.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      ).withTimeout(kAuthRequestTimeout, label: 'auth_sign_in');

      final user = response.user;
      if (user == null) {
        throw ServerException(message: 'Foydalanuvchi ma\'lumotlari olinmadi.');
      }

      return UserModel.fromSupabaseUser(user);
    } on AuthException catch (e) {
      throw ServerException(message: _mapAuthErrorMessage(e.message));
    } catch (e) {
      if (e is ServerException) rethrow;
      // TIMEOUT tashqariga uzatiladi: `ErrorHandler` uni
      // `FailureCode.timeout` ga aylantiradi. Aks holda u shu yerda
      // `ServerException` ichiga o'ralib, UI'ga lokalizatsiya qilinmagan
      // "TimeoutException after 0:00:30.000000: auth_sign_in" matni chiqardi.
      if (e is TimeoutException) rethrow;
      throw ServerException(message: 'Tizimga kirishda xatolik yuz berdi: ${e.toString()}');
    }
  }

  @override
  Future<UserModel> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final response = await supabaseClient.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'full_name': fullName.trim(),
          'role': 'citizen',
        },
      ).withTimeout(kAuthRequestTimeout, label: 'auth_sign_up');

      final user = response.user;
      if (user == null) {
        throw ServerException(message: 'Ro\'yxatdan o\'tishda xatolik yuz berdi.');
      }

      // SESSIYA YO'Q = TIZIMGA KIRILMAGAN (§20: jim yolg'on muvaffaqiyat YO'Q).
      //
      // Supabase'da "Confirm email" YOQILGAN bo'lsa `signUp` javobi
      // `user != null`, `session == null` beradi. Ilgari bu shox YO'Q edi:
      // `AuthBloc` darhol `Authenticated` chiqarardi, keyin profil so'rovi
      // ANON huquqi bilan ketib RLS bo'yicha bo'sh qaytardi va foydalanuvchi
      // sababini BILMAGAN holda "hisobim bor, lekin hech narsa ishlamaydi"
      // holatida qolardi.
      //
      // O'LCHOV (2026-08-29, `GET /auth/v1/settings`): loyihada
      // `mailer_autoconfirm: true` — ya'ni HOZIR bu shox ISHGA TUSHMAYDI.
      // U server sozlamasi o'zgarganda (yoki SMTP ulanganda) ilovaning
      // to'g'ri xulq qilishi uchun qo'yilgan; server sozlamasi bu yerdan
      // O'ZGARTIRILMAYDI.
      if (response.session == null) {
        throw EmailConfirmationRequiredException(
          details: 'signUp: user=${user.id}, session=null',
        );
      }

      return UserModel.fromSupabaseUser(user);
    } on AuthApiException catch (e) {
      final statusCode = e.statusCode != null ? int.tryParse(e.statusCode!) : null;
      throw ServerException(message: _mapAuthErrorMessage(e.message, code: e.code, statusCode: statusCode));
    } on AuthException catch (e) {
      final statusCode = e.statusCode != null ? int.tryParse(e.statusCode!) : null;
      throw ServerException(message: _mapAuthErrorMessage(e.message, statusCode: statusCode));
    } catch (e) {
      // `AppException` (`ServerException` VA
      // `EmailConfirmationRequiredException`) o'ralmaydi: aks holda email
      // tasdiqlash signali `ServerException` ichida yo'qolib, UI qizil
      // "Ro'yxatdan o'tishda xatolik" ko'rsatardi.
      if (e is AppException) rethrow;
      // TIMEOUT != server xatosi. MUHIM: 30 s dan keyin timeout bo'lsa ham
      // hisob SERVERDA yaratilgan bo'lishi mumkin — shu sababli xabar
      // "qayta urinib ko'ring" emas, `FailureCode.timeout` bo'lishi kerak.
      if (e is TimeoutException) rethrow;
      throw ServerException(message: 'Ro\'yxatdan o\'tishda xatolik: ${e.toString()}');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await supabaseClient.auth
          .signOut()
          .withTimeout(kAuthRequestTimeout, label: 'auth_sign_out');
    } on AuthException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
      if (e is TimeoutException) rethrow;
      throw ServerException(message: 'Chiqishda xatolik: ${e.toString()}');
    }
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    try {
      final user = supabaseClient.auth.currentUser;
      if (user == null) return null;
      return UserModel.fromSupabaseUser(user);
    } catch (e) {
      // TARMOQ SO'ROVI YO'Q: `currentUser` — SDK ichidagi xotiradagi
      // sessiyani sinxron o'qish, shuning uchun bu shoxda `TimeoutException`
      // paydo bo'lishi mumkin emas. Lekin `null` qaytarish "tizimga
      // kirilmagan" degan ma'noni beradi — model parse xatosi shu YOLG'ONga
      // aylanmasligi uchun sabab log'da qoladi.
      if (kDebugMode) {
        debugPrint('[auth] currentUser modelga aylanmadi: $e');
      }
      return null;
    }
  }

  @override
  Future<UserProfileModel> getUserProfile(String userId) async {
    try {
      final response = await supabaseClient
          .db('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle()
          .withTimeout(kDbRequestTimeout, label: 'profiles_select');

      if (response == null) {
        // INVARIANT: auth.users.id == profiles.id. Qator yo'q bo'lsa bu
        // HAQIQIY buzilish — `handle_new_user()` trigger profil yaratmagan.
        //
        // Ilgari bu yerda xotirada sun'iy profil ("Foydalanuvchi") qaytarilardi.
        // U "trigger kechikishi" bilan izohlangan edi, lekin bunday kechikish
        // yo'q: `on_auth_user_created` — AFTER INSERT trigger va `auth.users`
        // insert'i bilan BIR tranzaksiyada bajariladi. Sun'iy profil esa
        // mavjud bo'lmagan DB qatorini borday ko'rsatib, `questions.user_id`
        // FK buzilishini (23503) oylar davomida yashirib turgan.
        throw ServerException(
          message: "Profil bazada topilmadi (public.profiles.id = "
              "auth.users.id invarianti buzilgan). Ro'yxatdan o'tishda profil "
              "yaratilmagan.",
          statusCode: 404,
        );
      }

      return UserProfileModel.fromJson(response);
    } catch (e) {
      if (e is ServerException) rethrow;
      if (e is TimeoutException) rethrow;
      throw ServerException(message: 'Profil ma\'lumotlarini yuklashda xatolik: ${e.toString()}');
    }
  }

  @override
  Future<UserProfileModel> updateUserProfile(UserProfileModel profile) async {
    try {
      final response = await supabaseClient
          .db('profiles')
          .update(profile.toUpdatePayload())
          .eq('id', profile.id)
          .select()
          .single()
          .withTimeout(kDbRequestTimeout, label: 'profiles_update');

      return UserProfileModel.fromJson(response);
    } catch (e) {
      if (e is TimeoutException) rethrow;
      throw ServerException(message: 'Profilni yangilashda xatolik: ${e.toString()}');
    }
  }

  @override
  Stream<UserModel?> get authStateChanges {
    return supabaseClient.auth.onAuthStateChange.map((data) {
      final user = data.session?.user ?? supabaseClient.auth.currentUser;
      if (user == null) return null;
      return UserModel.fromSupabaseUser(user);
    });
  }

  String _mapAuthErrorMessage(String rawMessage, {String? code, int? statusCode}) {
    final lower = rawMessage.toLowerCase();
    final codeLower = (code ?? '').toLowerCase();

    if (statusCode == 429 ||
        codeLower.contains('rate_limit') ||
        codeLower.contains('over_email_send_rate_limit') ||
        lower.contains('email rate limit') ||
        lower.contains('rate limit') ||
        lower.contains('over_email_send_rate_limit')) {
      return 'Juda ko\'p urinish amalga oshirildi. Iltimos, bir necha daqiqadan so\'ng qayta urinib ko\'ring.';
    }
    if (lower.contains('invalid login credentials') || lower.contains('invalid credentials')) {
      return 'Email yoki parol noto\'g\'ri kiritildi.';
    }
    if (lower.contains('user already registered') || lower.contains('email already exists')) {
      return 'Ushbu email bilan allaqachon ro\'yxatdan o\'tilgan.';
    }
    if (lower.contains('password should be at least')) {
      return 'Parol kamida 6 ta belgidan iborat bo\'lishi kerak.';
    }
    if (lower.contains('database error saving new user') ||
        lower.contains('unexpected_failure') ||
        lower.contains('error saving new user')) {
      return 'Ro\'yxatdan o\'tishda server xatosi yuz berdi. Iltimos, qayta urinib ko\'ring.';
    }
    return rawMessage;
  }
}
