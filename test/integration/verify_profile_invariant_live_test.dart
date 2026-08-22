import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/config/supabase_config.dart';
import 'package:lexhub/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:lexhub/features/community_forum/data/datasources/community_forum_remote_datasource.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/live_gate.dart';
/// AUTH PROFILE INVARIANT — REAL SUPABASE RUNTIME VERIFICATION
///
/// Bu `20260827_profile_invariant_final_fix.sql` migration'i SQL Editor'da
/// QO'LLANGANDAN KEYIN ishga tushiriladi. Ishga tushirish buyrug'i:
///
///   flutter test test/integration/verify_profile_invariant_live_test.dart \
///     --dart-define-from-file=env/prod.json \
///     --dart-define=LEXHUB_LIVE_WRITE_TESTS=true
///
/// DIQQAT: bu test REAL PRODUCTION'ga YOZADI (yangi auth user + 1 savol).
/// Shu sababli `LEXHUB_LIVE_WRITE_TESTS=true` bo'lmaguncha SKIP bo'ladi —
/// oddiy `flutter test` uni tasodifan ishga tushirmaydi.
///
/// NIMA UCHUN YANGI FAYL: mavjud
/// `test/integration/real_supabase_signup_cloud_verification_test.dart`
/// signup butunlay yiqilsa ham `on ServerException` bilan uni ushlab,
/// "ALL SIGNUP & PROFILE TRIGGER VERIFICATIONS PASSED" deb PASS beradi
/// (o'sha fayl 82-90 satrlar). Ya'ni u fix'ni TASDIQLAY OLMAYDI.
/// Bu testda hech qanday catch-all YO'Q: har qanday xato = FAIL.
void main() {
  // P2 test konfiguratsiyasi: bu fayl REAL Supabase Cloud'ga ulanadi.
  // `--dart-define=LEXHUB_LIVE_WRITE_TESTS=true` bo'lmasa OSHKORA skip.
  if (!liveSuiteEnabled('verify_profile_invariant_live')) return;

  const liveWrites =
      bool.fromEnvironment('LEXHUB_LIVE_WRITE_TESTS', defaultValue: false);

  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null; // real tarmoq

  setUpAll(() async {
    if (!liveWrites) return;
    SharedPreferences.setMockInitialValues({});
    await SupabaseConfig.init();
    // Konfiguratsiya yo'q bo'lsa test PASS bo'lmasligi kerak — BLOCKED emas,
    // FAIL: buyruqda `--dart-define-from-file` tushib qolgan.
    expect(SupabaseConfig.isConfigured, isTrue,
        reason: 'BLOCKED: --dart-define-from-file=env/prod.json berilmagan '
            '(${SupabaseConfig.validate()})');
    await Supabase.initialize(
      url: SupabaseConfig.url,
      // ignore: deprecated_member_use
      anonKey: SupabaseConfig.anonKey,
    );
  });

  /// UUID'ni redaktsiya qilib chiqarish (log'ga to'liq ID yozilmaydi).
  String redact(String id) =>
      id.length > 12 ? '${id.substring(0, 8)}…${id.substring(id.length - 4)}' : id;

  test(
    'LIVE: signup -> profiles invarianti -> phone NULL -> escalation bloki -> savol',
    () async {
      final client = Supabase.instance.client;
      final authDs = AuthRemoteDataSourceImpl(supabaseClient: client);
      final ts = DateTime.now().millisecondsSinceEpoch;
      final email = 'invariant_probe_$ts@lexhub.uz';
      const password = 'Password123!';
      const fullName = 'Invariant Probe';

      // ── 1. REAL SIGNUP ──────────────────────────────────────────────────
      // Xato bo'lsa u YUTILMAYDI: test yiqiladi va asl matn ko'rinadi.
      final user = await authDs.signUpWithEmail(
        email: email,
        password: password,
        fullName: fullName,
      );
      stdout.writeln('EVIDENCE 1 — auth.users: id=${redact(user.id)}');
      expect(user.id, isNotEmpty);

      // ── 2. INVARIANT: auth.users.id == profiles.id ───────────────────────
      final profile = await client
          .from('profiles')
          .select('id, full_name, phone, role, is_verified, reputation_points')
          .eq('id', user.id)
          .maybeSingle();
      stdout.writeln('EVIDENCE 2 — profiles qatori: ${profile == null ? 'YO\'Q' : 'BOR'}');
      expect(profile, isNotNull,
          reason: 'INVARIANT BUZILGAN: handle_new_user() profil yaratmadi. '
              'Migration qo\'llanmagan yoki yana bir 23502 bor.');
      expect(profile!['id'], user.id);

      // ── 3. ROOT CAUSE: phone NULL bilan INSERT o'tdi ─────────────────────
      stdout.writeln('EVIDENCE 3 — profiles.phone = ${profile['phone']}');
      expect(profile['phone'], isNull,
          reason: 'email signup telefon bermaydi — NULL kutilgan');
      expect(profile['full_name'], fullName);
      expect(profile['role'], 'citizen');
      expect(profile['is_verified'], isFalse);
      expect(profile['reputation_points'], 10);

      // ── 4. getUserProfile sun'iy profil emas, REAL qator qaytaradi ───────
      final model = await authDs.getUserProfile(user.id);
      expect(model.id, user.id);
      expect(model.fullName, fullName);
      stdout.writeln('EVIDENCE 4 — getUserProfile OK (sun\'iy profil emas)');

      // ── 5. P0 GUARD: o'ziga role='admin' bera olmaydi ────────────────────
      // Bu authorized negative security test — o'z loyihasida, o'z sessiyasida.
      Object? escalationError;
      try {
        await client
            .from('profiles')
            .update({'role': 'admin'})
            .eq('id', user.id);
      } catch (e) {
        escalationError = e;
      }
      final afterEscalation = await client
          .from('profiles')
          .select('role, is_verified, reputation_points')
          .eq('id', user.id)
          .maybeSingle();
      stdout.writeln('EVIDENCE 5 — escalation xatosi: '
          '${escalationError == null ? 'YO\'Q (guard ishlamadi!)' : escalationError.runtimeType}');
      stdout.writeln('EVIDENCE 5 — role escalation`dan keyin: '
          '${afterEscalation?['role']}');
      expect(afterEscalation?['role'], 'citizen',
          reason: 'P0: foydalanuvchi o\'ziga admin bera oldi');
      expect(escalationError, isNotNull,
          reason: 'P0: UPDATE guard EXCEPTION ko\'tarmadi (trigger '
              'SECURITY DEFINER bo\'lib qolgan bo\'lishi mumkin)');

      // ── 6. TASK 4: client'dan profil INSERT qilish YO'LI YOPIQ ───────────
      Object? insertError;
      try {
        await client.from('profiles').insert({
          'id': user.id,
          'full_name': 'Escalation',
          'role': 'admin',
        });
      } catch (e) {
        insertError = e;
      }
      stdout.writeln('EVIDENCE 6 — client INSERT bloklandi: '
          '${insertError != null}');
      expect(insertError, isNotNull,
          reason: 'TASK 4: client profiles INSERT qila oldi');

      // ── 7. 23503 YOPILDI: Community savol yaratish ────────────────────────
      final communityDs =
          CommunityForumDataSourceImpl(supabaseClient: client);
      final post = await communityDs.createQuestion(
        title: 'Invariant probe savoli $ts',
        rawQuestion:
            'Mehnat shartnomasi bekor qilinganda qanday huquqlarim bor?',
        category: 'Mehnat huquqi',
        isAnonymous: false,
        authorName: fullName,
      );
      stdout.writeln('EVIDENCE 7 — savol yaratildi: id=${redact(post.id)}');
      expect(post.id, isNotEmpty);

      final question = await client
          .from('questions')
          .select('id, user_id, category_id, body')
          .eq('id', post.id)
          .maybeSingle();
      expect(question, isNotNull, reason: 'savol DB`da yo\'q');
      expect(question!['user_id'], user.id,
          reason: 'questions.user_id = profiles.id bo\'lishi shart');
      expect(question['category_id'], isNotNull);
      expect(RegExp(r'^[0-9a-f]{8}-').hasMatch('${question['category_id']}'),
          isTrue,
          reason: 'category_id real UUID bo\'lishi shart (22P02 regressiyasi)');
      expect('${question['body']}'.trim(), isNotEmpty,
          reason: 'questions.body NOT NULL (23502 regressiyasi)');
      stdout.writeln('EVIDENCE 7 — user_id=${redact('${question['user_id']}')} '
          'category_id=UUID body=NOT NULL');

      stdout.writeln('--- BARCHA INVARIANTLAR REAL SUPABASE`DA TASDIQLANDI ---');
      stdout.writeln('Tozalash: bu probe user va savol PRODUCTION`da qoldi — '
          'SQL Editor`dan qo\'lda o\'chiring: '
          'delete from auth.users where email = \'$email\';');
    },
    skip: liveWrites
        ? false
        : 'SKIPPED (BLOCKED): real production yozuvi. Ishga tushirish: '
            '--dart-define-from-file=env/prod.json '
            '--dart-define=LEXHUB_LIVE_WRITE_TESTS=true',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
