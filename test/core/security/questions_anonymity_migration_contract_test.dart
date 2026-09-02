// LEXHUB — `20260830080000_questions_anonymity_rls_enforcement.sql` KONTRAKT TESTI.
//
// BU DEPLOYMENT ISBOTI EMAS. Fayl mazmunini qulflaydi, xolos: kimdir
// migration'ni "soddalashtirib" himoyani jimgina yo'q qilib qo'ymasin.
// Deployment isboti — `test/integration/questions_anonymity_live_test.dart`
// (real production, anon kalit).
//
// NIMANI QULFLAYDI:
//   1. Fayl BOR va transaction ichida (`BEGIN;` / `COMMIT;`).
//   2. RLS YOQILADI.
//   3. Cheklovsiz (`USING (true)`) SELECT/ALL policy'lari NOMGA bog'lanmasdan,
//      predikat bo'yicha olib tashlanadi — production'dagi policy nomi
//      repo'dagidan farq qilishi mumkin.
//   4. To'g'ri predikat AYNAN `20260820_p0_security_remediation.sql` dagi
//      uchlik: `is_anonymous = false` OR `auth.uid() = user_id` OR
//      `is_admin_or_moderator()`. Yangi qoida O'YLAB TOPILMAYDI.
//   5. Post-deploy assertion BOR — "muvaffaqiyatli, lekin hech narsa
//      o'zgarmadi" holati IMKONSIZ (§20).
//   6. DESTRUKTIV operatsiya YO'Q: `DROP TABLE` / `DROP COLUMN` /
//      `DELETE FROM` / `TRUNCATE` yo'q.
//   7. Sir (JWT, `sb_secret_`, service_role kaliti) fayl ichida YO'Q.
//
// IZOHLAR AJRATILADI: izohda ataylab "ishlatilmagan"/"noto'g'ri" qiymatlar
// eslatiladi (masalan o'lchangan `user_id`), shuning uchun tekshiruv KODDA
// qilinadi, izohda emas.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // Versiya `20260830080000`: `...060000` ALLAQACHON
  // `expert_rating_no_fabrication.sql` tomonidan olingan, ikki xil migration
  // bir xil versiyada bo'lsa qo'llash TARTIBI aniqlanmaydi.
  const path = 'supabase/migrations/'
      '20260830080000_questions_anonymity_rls_enforcement.sql';

  late String sql;
  late String code;

  setUpAll(() {
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: 'Migration fayli topilmadi: $path');
    sql = file.readAsStringSync();
    code = sql
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('--'))
        .join('\n');
  });

  group('questions anonimlik migration — kontrakt', () {
    test('transaction-safe', () {
      expect(code, contains('BEGIN;'));
      expect(code, contains('COMMIT;'));
    });

    test('RLS yoqiladi', () {
      expect(code, contains('ALTER TABLE public.questions ENABLE ROW LEVEL SECURITY'));
    });

    test('cheklovsiz SELECT policy PREDIKAT bo\'yicha olib tashlanadi', () {
      // Nomga bog'lanmagan yechim: `pg_policies` bo'yicha aylanib DROP.
      expect(code, contains('FROM pg_policies'));
      expect(code, contains("cmd IN ('SELECT', 'ALL')"));
      expect(code, contains("btrim(lower(qual)) = 'true'"));
      expect(code, contains('DROP POLICY %I ON public.questions'));
    });

    test('to\'g\'ri predikat uchligi AYNAN saqlangan', () {
      expect(code, contains('is_anonymous = false'));
      expect(code, contains('auth.uid() = user_id'));
      expect(code, contains('public.is_admin_or_moderator()'));
      // Loyihada `public.is_admin(uuid)` YO'Q — adashib ishlatilmasin.
      expect(code, isNot(contains('is_admin(')));
    });

    test('post-deploy assertion bor (jim o\'tish yo\'q)', () {
      expect(code, contains('RAISE EXCEPTION'));
      expect(code, contains('relrowsecurity'));
      // Predikatni ANON nomidan hisoblab ko'radigan yakuniy o'lchov.
      expect(code, contains('is_anonymous = TRUE'));
    });

    test('destruktiv operatsiya YO\'Q', () {
      final upper = code.toUpperCase();
      for (final banned in [
        'DROP TABLE',
        'DROP COLUMN',
        'DELETE FROM',
        'TRUNCATE',
        'DROP VIEW',
      ]) {
        expect(upper, isNot(contains(banned)), reason: '$banned taqiqlangan');
      }
    });

    test('policy faqat SELECT/ALL ga tegadi (INSERT/UPDATE/DELETE tegilmaydi)',
        () {
      // `FOR SELECT` dan boshqa `CREATE POLICY ... FOR ...` bo'lmasin.
      final created = RegExp(r'CREATE POLICY[\s\S]*?FOR (\w+)')
          .allMatches(code)
          .map((m) => m.group(1))
          .toList();
      expect(created, isNotEmpty);
      expect(created.every((c) => c == 'SELECT'), isTrue,
          reason: 'Kutilmagan policy turi: $created');
    });

    test('sir YO\'Q', () {
      expect(sql, isNot(contains('sb_secret_')));
      expect(sql, isNot(contains('service_role_key')));
      expect(sql, isNot(matches(RegExp(r'eyJ[A-Za-z0-9_-]{20,}'))));
    });

    test('live isbot yo\'li fayl ichida ko\'rsatilgan', () {
      // Kelgusi o'quvchi "deployed?" savoliga javobni FAYLDA topsin.
      expect(sql, contains('questions_anonymity_live_test.dart'));
      expect(sql, contains('public_questions_view'));
    });

    test('yakuniy o\'lchov `anon` ROLI nomidan qilinadi', () {
      // Qo'lda qayta yozilgan predikat ISBOT EMAS: u repo matnini
      // tekshiradi, qo'llanadigan policy'ni emas. Bundan tashqari migration
      // `postgres` ostida ishlaydi va u RLS'ni CHETLAB O'TADI.
      expect(code, contains("SET LOCAL ROLE anon"),
          reason: 'Rol almashtirilmasa o\'lchov soxta: `postgres` RLS\'ni '
              'chetlab o\'tadi.');
      expect(code, contains('RESET ROLE'),
          reason: 'Rol tiklanmasa keyingi gaplar `anon` huquqida bajariladi.');
      expect(code, contains('WHEN insufficient_privilege'),
          reason: '`anon` ga huquq berilmagan holat — izolyatsiyadan '
              'KUCHLIROQ himoya, migration bundan yiqilmasligi kerak.');
      // Bo'sh to'plamda o'lchov "isbot" deb ko'rsatilmasin (§0).
      expect(code, contains('v_total_anon'));
    });

    test('NOTICE ko\'rinmasligi hisobga olingan — COMMIT\'dan keyin SELECT',
        () {
      final commit = code.indexOf('COMMIT;');
      expect(commit, greaterThan(0));
      final after = code.substring(commit + 'COMMIT;'.length);
      expect(after, contains('relrowsecurity'),
          reason: 'Supabase SQL Editor `RAISE NOTICE` ni ko\'rsatmaydi '
              '(219545f) — natija JADVAL bo\'lib qaytarilishi kerak.');
      expect(after, contains('anonim_savol_soni'),
          reason: 'Anonim savol soni KO\'RINSIN: 0 bo\'lsa yuqoridagi anon '
              'o\'lchovi bo\'sh to\'plamda bajarilgan va hech narsani '
              'isbotlamaydi.');
    });

    test('hujjat HALOLLIGI: tuzatilgan YOLG\'ON qaytib kelmadi', () {
      // Ikkisi ham 2026-08-30 da o'lchov bilan RAD ETILGAN da'volar.
      expect(sql, isNot(contains('sabab taxmin emas, o\'lchov bo\'lib qoladi')),
          reason: 'SQL Editor `NOTICE` ni ko\'rsatmaydi — 1-blok sababni '
              'HECH KIMGA ko\'rsatmagan.');
      expect(
          sql,
          isNot(contains(
              'INSERT/UPDATE/\n-- DELETE policy\'lari QO\'LGA TEGMAYDI')),
          reason: 'Filtr `cmd IN (\'SELECT\', \'ALL\')` — `ALL` policy '
              'INSERT/UPDATE/DELETE ni HAM boshqaradi.');
    });

  });
}
