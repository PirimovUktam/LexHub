// LEXHUB — BO'SH YOZISH POLICY'LARINI TORAYTIRISH (statik kontrakt).
//
// BU DEPLOYMENT ISBOTI EMAS. Bu test `supabase/migrations/*.sql` MATNINI
// o'qiydi, jonli bazaga ULANMAYDI. Jonli isbot — sessiyali (authenticated)
// yozish testi: `test/integration/real_supabase_community_e2e_test.dart`
// (gated) va qo'llash chiqishi: `.runtime_evidence/mig_120000_apply.out.json`.
//
// NIMA UCHUN BU FAYL BOR: 2026-08-30 da JONLI bazadan o'lchandi
// (`.runtime_evidence/before_tighten_write_policies.out.json`) — ikki yozish
// policy'si EGA tekshiruvisiz edi:
//   questions/INSERT  WITH CHECK (auth.role() = 'authenticated')
//   votes/ALL         USING (auth.role() = 'authenticated'), with_check NULL
// Ya'ni autentifikatsiya qilgan har kim BOSHQANING `user_id` si bilan savol
// kiritardi va ovoz qo'shardi/o'chirardi; `FOR ALL` SELECT ni ham qoplagani
// uchun HAMMANING ovozi o'qilardi.
//
// `write_policy_parity_test.dart` bu sinfni TUTMAYDI: u qaysi BUYRUQ
// qoplanganini tekshiradi, PREDIKAT qanchalik torligini emas — bo'sh
// `auth.role()` policy'si bilan ham yashil qolardi.
//
// ENG MUHIM QULF — NOM BIRLIGI: yangi policy nomlari `20260830110000` dagi
// nomlar bilan AYNAN bir xil bo'lishi shart. Boshqa nom tanlansa, faqat
// migratsiyalardan qurilgan bazada IKKI ta PERMISSIVE policy yonma-yon
// qolardi (ular OR qilinadi = huquq KENGAYARDI).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `--` izoh qatorlari TASHLANADI: izohda ataylab BO'SH predikatlar
/// (`auth.role() = 'authenticated'`) nuqson tavsifi sifatida keltirilgan.
/// Tekshiruv KODDA bo'lishi kerak, izohda emas.
String _codeOf(String sql) =>
    sql.split('\n').where((l) => !l.trimLeft().startsWith('--')).join('\n');

/// Bo'sh joylarni bitta probelga keltiradi (DDL ko'p qatorga bo'lingan).
String _flat(String s) => s.replaceAll(RegExp(r'\s+'), ' ');

const _loosePolicyNames = <String>[
  'Autentifikatsiya qilganlar savol yaratadi',
  'Ovozlar autentifikatsiya qilganlar uchun',
];

const _canonicalPolicyNames = <String>[
  'Authenticated users can create questions',
  'Users can manage their own votes',
];

void main() {
  const migDir = 'supabase/migrations';
  const fixPath = '$migDir/20260830120000_tighten_loose_write_policies.sql';
  const fillPath = '$migDir/20260830110000_missing_write_policies_parity.sql';

  late String sql;
  late String code;
  late String flat;

  setUpAll(() {
    final file = File(fixPath);
    expect(file.existsSync(), isTrue, reason: 'topilmadi: $fixPath');
    sql = file.readAsStringSync();
    code = _codeOf(sql);
    flat = _flat(code);
  });

  test('transaction-safe', () {
    expect(code, contains('BEGIN;'));
    expect(code, contains('COMMIT;'));
  });

  test('AYNAN ikki policy almashtiriladi — ko\'p ham, kam ham emas', () {
    final creates =
        RegExp('CREATE POLICY', caseSensitive: false).allMatches(code).length;
    final drops = RegExp('DROP POLICY IF EXISTS', caseSensitive: false)
        .allMatches(code)
        .length;
    expect(creates, 2,
        reason: 'questions/INSERT + votes/ALL kutilgan. O\'lchangan: $creates. '
            'Ko\'paysa — bu fayl o\'lchangan doiradan CHIQIB ketgan.');
    expect(drops, 4,
        reason: 'Har bir policy uchun IKKI nom tashlanadi: jonli BO\'SH nom + '
            'kanonik nom (idempotentlik va nom to\'qnashuvi uchun). '
            'O\'lchangan: $drops');
  });

  test('jonli BO\'SH policy nomlari AYNAN tashlanadi', () {
    for (final name in _loosePolicyNames) {
      expect(flat, contains('DROP POLICY IF EXISTS "$name"'),
          reason: '"$name" tashlanmaydi — BO\'SH policy jonli bazada QOLADI '
              'va yangi policy bilan OR qilinadi (huquq kengayadi).');
    }
  });

  test('yangi policy EGAGA-XOS: `auth.uid() = user_id` VA `TO authenticated`',
      () {
    // `CREATE POLICY` dan keyingi matn `;` gacha — predikat shu ichida.
    final blocks = code
        .split(';')
        .where((s) => s.toUpperCase().contains('CREATE POLICY'))
        .map(_flat)
        .toList();
    expect(blocks.length, 2, reason: 'o\'lchangan: ${blocks.length}');
    for (final b in blocks) {
      expect(b, contains('auth.uid() = user_id'),
          reason: 'EGA tekshiruvi YO\'Q — toraytirish MA\'NOSIZ: $b');
      expect(b, contains('TO authenticated'),
          reason: 'Rol cheklovi YO\'Q: $b');
      expect(b, isNot(contains('USING (true)')), reason: b);
      expect(b, isNot(contains('WITH CHECK (true)')), reason: b);
    }
    expect(flat, contains('ON public.questions FOR INSERT'));
    expect(flat, contains('ON public.votes FOR ALL'));
  });

  test('NOM BIRLIGI: `20260830110000` bilan AYNAN bir xil nomlar', () {
    // Ikki muhit (jonli baza / faqat migratsiyalardan qurilgan baza) OXIRIDA
    // BITTA nom va BITTA ta'rifga kelishi shart.
    final fill = File(fillPath);
    expect(fill.existsSync(), isTrue, reason: 'topilmadi: $fillPath');
    final fillCode = _codeOf(fill.readAsStringSync());
    for (final name in _canonicalPolicyNames) {
      expect(flat, contains('"$name"'), reason: '$fixPath: "$name" YO\'Q');
      expect(fillCode, contains('"$name"'),
          reason: '$fillPath: "$name" YO\'Q — nomlar AJRALIB ketdi, ya\'ni '
              'faqat migratsiyalardan qurilgan bazada IKKI ta PERMISSIVE '
              'policy qoladi va huquq KENGAYADI.');
    }
  });

  test('P/D gate\'lari bor (jim o\'tish yo\'q)', () {
    for (final gate in const [
      'P1 FAILED',
      'P2 FAILED',
      'D1 FAILED',
      'D2 FAILED',
      'D3 FAILED',
      'D4 FAILED',
    ]) {
      expect(code, contains(gate), reason: gate);
    }
    expect(code, contains('P3 O\'\'LCHOV'),
        reason: 'OLDINGI predikat o\'lchanmasa, "hech narsa o\'zgarmadi" '
            'holati KO\'RINMAYDI.');
    expect(code, contains("btrim(lower(coalesce(qual, ''))) = 'true'"));
    expect(code, contains('FROM pg_policies'));
  });

  test('EGASIZ qator gate\'i bor (P2 haqiqiy o\'lchov)', () {
    // `user_id IS NULL` qator bo'lsa `auth.uid() = user_id` uni EGASIZ
    // qiladi — egasi ham ko'rmaydi, o'chirmaydi. Gate shu holatda TO'XTATADI.
    expect(code, contains('user_id IS NULL'),
        reason: 'P2 gate EGASIZ qatorni tekshirmaydi — toraytirish jim '
            'ravishda ma\'lumotni ko\'rinmas qilib qo\'yishi mumkin.');
  });

  test('NOTICE ko\'rinmasligi hisobga olingan — COMMIT\'dan keyin SELECT', () {
    final commit = code.indexOf('COMMIT;');
    expect(commit, greaterThan(0));
    final after = code.substring(commit + 'COMMIT;'.length);
    expect(after, contains('FROM pg_policies'),
        reason: 'Supabase SQL Editor `RAISE NOTICE` ni ko\'rsatmaydi '
            '(219545f) — natija JADVAL bo\'lib qaytarilishi kerak.');
    expect(after, contains('CHEKLOVSIZ'),
        reason: 'Cheklovsiz yozish policy\'si KO\'RINSIN.');
    expect(after, contains("'reports'"),
        reason: '`20260830110000` ning D3 gate\'i UCHALASINI tekshiradi — '
            'diagnostika `reports` ni ham ko\'rsatishi kerak, aks holda '
            '"to\'siq yo\'qoldi" degan xulosa O\'LCHANMAY qoladi.');
  });

  test('XULQ o\'lchovi manzili fayl ICHIDA — soxta isbot manzili YO\'Q', () {
    // Bu ATAYLAB izohga qaraydi. Fayl ilgari jonli isbot sifatida
    // `real_supabase_community_e2e_test.dart` ni ko'rsatgan edi — o'lchandi:
    // u test sessiya OCHMAYDI (`signIn*` yo'q), faqat MEHMON rad etilishini
    // tekshiradi. Ya'ni u ko'rsatma SOXTA ISBOT MANZILI edi (§0).
    expect(sql, contains('.runtime_evidence/rls_behavior_probe'),
        reason: 'HAQIQIY xulq o\'lchovining manzili YO\'Q — fayl faqat '
            'katalog (pg_policies) o\'lchoviga tayanib qoladi.');
    expect(sql, contains('42501'),
        reason: 'Impersonatsiya urinishi RAD ETILGANINING o\'lchangan '
            'SQLSTATE kodi ko\'rsatilmagan.');
    // BU SHART ALMASHTIRILDI, YUMSHATILMADI (2026-08-30).
    //
    // ILGARI: `expect(sql, contains('PARTIALLY VERIFIED'))` — sabab: Flutter
    // mijoz zanjiri uchun SESSIYALI test YO'Q edi va bu cheklov ochiq
    // aytilishi shart edi.
    //
    // ENDI cheklov YOPILDI: `community_write_session_rls_live_test.dart`
    // ikkita HAQIQIY sessiya bilan jonli production'da o'lchandi (7/7 o'tdi,
    // EVIDENCE 1-7). Ya'ni "PARTIALLY VERIFIED" talab qilish endi ESKIRGAN
    // holatni MAJBURAN saqlab turardi. O'rniga QATTIQROQ shart: yopilish
    // isboti AYNAN nomi bilan ko'rsatilishi kerak, aks holda fayl yana
    // katalog o'lchoviga tayanib qolgan deb o'qilardi.
    expect(sql, contains('community_write_session_rls_live_test.dart'),
        reason: 'ILOVA zanjirini yopgan sessiyali testning MANZILI YO\'Q — '
            'PostgREST + supabase_flutter qatlami isbotsiz qoladi.');
    expect(sql, contains('EVIDENCE 2'),
        reason: 'Impersonatsiya ILOVA zanjirida rad etilganining o\'lchov '
            'yorlig\'i ko\'rsatilmagan — natija qayta topilmaydi.');
    expect(sql, contains('sessiya OCHMAYDI'),
        reason: '`real_supabase_community_e2e_test.dart` ning CHEKLOVI '
            'aytilmasa, u yana butun oqim isboti deb o\'qilardi.');
  });

  test('QAYTARISH yozuvi fayl ICHIDA ko\'rsatilgan', () {
    // Bu ATAYLAB izohga qaraydi: `DROP POLICY` avtomatik qaytmaydi, shuning
    // uchun qaytarish manzili faylning O'ZIDA turishi shart.
    expect(sql, contains('.runtime_evidence/before_tighten_write_policies'),
        reason: 'Qaytarish yozuvining yo\'li YO\'Q — `DROP POLICY` dan keyin '
            'oldingi ta\'rifni tiklash IMKONSIZ bo\'lib qoladi.');
    expect(sql, contains('DEPLOYMENT ISBOTI EMAS'));
  });

  test('destruktiv operatsiya YO\'Q', () {
    final upper = code.toUpperCase();
    for (final banned in const [
      'DROP TABLE',
      'DROP COLUMN',
      'DELETE FROM',
      'TRUNCATE',
      'DROP VIEW',
      'ALTER COLUMN',
      'ALTER TABLE',
      'DISABLE ROW LEVEL SECURITY',
    ]) {
      expect(upper, isNot(contains(banned)), reason: '$banned taqiqlangan');
    }
  });

  test('sir YO\'Q', () {
    expect(sql, isNot(contains('sb_secret_')));
    expect(sql, isNot(contains('service_role_key')));
    expect(sql, isNot(matches(RegExp(r'eyJ[A-Za-z0-9_-]{20,}'))));
  });
}
