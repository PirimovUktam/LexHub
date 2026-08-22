// LEXHUB — MVP BLOCKER MIGRATION KONTRAKT TESTI (P0-07 / P1-05 / P1-06)
//
// DIQQAT — BU TEST NIMA EMAS:
//   Bu test migration'ning PRODUCTION'GA QO'LLANGANINI ISBOTLAMAYDI.
//   U faqat `.sql` faylning MAZMUNI to'g'ri ekanini qulflaydi (regressiya
//   qo'riqchisi). Deployment isboti FAQAT shu yerda:
//     test/integration/verify_mvp_blockers_live_test.dart
//   (`--dart-define=LEXHUB_LIVE_WRITE_TESTS=true` bilan).
//
// NIMA UCHUN KERAK: migration hali qo'llanmagan bo'lsa ham, keyingi
// refactor faylni buzib qo'ymasligi kerak — masalan 150000 fallback
// qaytib kelishi yoki `TO authenticated` tushib qolishi.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const path =
      'supabase/migrations/20260828_mvp_blockers_p0_07_p1_05_p1_06.sql';
  late String sql;

  /// Faqat BAJARILADIGAN SQL — `--` izoh qatorlari olib tashlangan.
  ///
  /// Izohlarda ataylab `150000` va `public.is_admin(uuid)` eslatiladi
  /// (nima uchun ishlatilmagani yozilgan), shuning uchun regressiya
  /// tekshiruvi izohlarda emas, KODDA qilinishi kerak.
  late String code;

  setUpAll(() {
    final f = File(path);
    expect(f.existsSync(), isTrue, reason: '$path topilmadi.');
    sql = f.readAsStringSync();
    code = sql
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('--'))
        .join('\n');
  });

  group('MVP blocker migration — kontrakt', () {
    test('transaction-safe: BEGIN va COMMIT bor', () {
      expect(sql, contains('BEGIN;'));
      expect(sql, contains('COMMIT;'));
    });

    test('P0-07: PUBLIC/anon/authenticated dan REVOKE, service_role ga GRANT',
        () {
      expect(sql, contains('REVOKE ALL ON FUNCTION'));
      expect(sql, contains('FROM PUBLIC'));
      expect(sql, contains('anon'));
      expect(sql, contains('authenticated'));
      expect(sql, contains('GRANT EXECUTE ON FUNCTION'));
      expect(sql, contains('service_role'));
      // Funksiya topilmasa migration JIMGINA o'tib ketmasligi kerak.
      expect(sql, contains('RAISE EXCEPTION'));
      // Signature'ga bog'liq bo'lmagan usul (har bir overload uchun).
      expect(sql, contains('regprocedure'));
    });

    test('P0-07: service_role KALITI faylga yozilmagan', () {
      // Rol NOMI bo'lishi shart, lekin JWT/secret QIYMATI bo'lmasligi kerak.
      expect(sql.contains('eyJ'), isFalse,
          reason: 'Migration ichida JWT ko\'rinishidagi qiymat bor.');
      expect(sql.contains('sb_secret'), isFalse);
      expect(sql.contains('service_role_key'), isFalse);
    });

    test('P1-05: 150000 to\'qima narx YO\'Q, expert_profiles dan olinadi', () {
      expect(code.contains('150000'), isFalse,
          reason: 'P1-05 REGRESSIYA: 150000 to\'qima narx qaytib kelgan.');
      expect(sql, contains('CREATE OR REPLACE FUNCTION '
          'public.get_expert_available_slots'));
      expect(sql, contains('FROM public.expert_profiles'));
      expect(sql, contains('verified_at IS NOT NULL'));
      // Qator topilmasa slot QAYTARILMAYDI (soxta bandlik ko'rsatilmaydi).
      expect(sql, contains('IF NOT FOUND THEN'));
    });

    test('P1-06: DELETE policy faqat egasi uchun va TO authenticated', () {
      expect(sql, contains('ENABLE ROW LEVEL SECURITY'));
      expect(sql, contains('DROP POLICY IF EXISTS'),
          reason: 'Idempotent bo\'lishi kerak.');
      expect(sql, contains('owner_can_delete_own_question'));
      expect(sql, contains('owner_can_delete_own_answer'));
      expect(sql, contains('FOR DELETE'));
      // `TO authenticated` — anon'ning fail-closed bo'lishini ta'minlaydi.
      expect(sql, contains('TO authenticated'));
      expect(sql, contains('auth.uid() = user_id'));
      // Admin/moderator xatti-harakati buzilmasligi kerak.
      expect(sql, contains('public.is_admin_or_moderator()'));
      // Mavjud bo'lmagan helper ishlatilmasin.
      expect(code.contains('is_admin('), isFalse,
          reason: 'public.is_admin(uuid) bazada YO\'Q.');
    });

    test('post-deploy verification SQL izoh sifatida berilgan', () {
      expect(sql, contains('has_function_privilege'));
      expect(sql, contains('pg_policies'));
    });
  });
}
