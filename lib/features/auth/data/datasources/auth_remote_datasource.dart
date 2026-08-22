import 'dart:async';
import 'package:lexhub/core/errors/exceptions.dart';
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
      );

      final user = response.user;
      if (user == null) {
        throw ServerException(message: 'Foydalanuvchi ma\'lumotlari olinmadi.');
      }

      return UserModel.fromSupabaseUser(user);
    } on AuthException catch (e) {
      throw ServerException(message: _mapAuthErrorMessage(e.message));
    } catch (e) {
      if (e is ServerException) rethrow;
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
      );

      final user = response.user;
      if (user == null) {
        throw ServerException(message: 'Ro\'yxatdan o\'tishda xatolik yuz berdi.');
      }

      return UserModel.fromSupabaseUser(user);
    } on AuthApiException catch (e) {
      final statusCode = e.statusCode != null ? int.tryParse(e.statusCode!) : null;
      throw ServerException(message: _mapAuthErrorMessage(e.message, code: e.code, statusCode: statusCode));
    } on AuthException catch (e) {
      final statusCode = e.statusCode != null ? int.tryParse(e.statusCode!) : null;
      throw ServerException(message: _mapAuthErrorMessage(e.message, statusCode: statusCode));
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(message: 'Ro\'yxatdan o\'tishda xatolik: ${e.toString()}');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await supabaseClient.auth.signOut();
    } on AuthException catch (e) {
      throw ServerException(message: e.message);
    } catch (e) {
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
      return null;
    }
  }

  @override
  Future<UserProfileModel> getUserProfile(String userId) async {
    try {
      final response = await supabaseClient
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

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
      throw ServerException(message: 'Profil ma\'lumotlarini yuklashda xatolik: ${e.toString()}');
    }
  }

  @override
  Future<UserProfileModel> updateUserProfile(UserProfileModel profile) async {
    try {
      final response = await supabaseClient
          .from('profiles')
          .update(profile.toUpdatePayload())
          .eq('id', profile.id)
          .select()
          .single();

      return UserProfileModel.fromJson(response);
    } catch (e) {
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
