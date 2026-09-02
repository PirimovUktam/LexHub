// LEXHUB — `anon` UCHUN O'QISH/YOZISH QATIQLASHTIRISH (statik kontrakt).
//
// BU DEPLOYMENT ISBOTI EMAS. Test `supabase/migrations/*.sql` MATNINI o'qiydi,
// jonli bazaga ULANMAYDI. Ikki fayl ham 2026-09-03 holatiga ko'ra JONLI
// BAZAGA QO'LLANMAGAN (§0: NOT VERIFIED). Qo'llanganini isbotlash yo'li —
// `tool/anon_privilege_probe_precise.py` va
// `tool/anon_write_privilege_zero_rows_probe.py` ni QAYTA yurgizish.
//
// NIMA UCHUN BU FAYL BOR — IKKI O'LCHANGAN NUQSON:
//   1. `profiles` SELECT policy'si `USING (true)` edi (`20260826010000:128`),
//      ustun-darajali GRANT esa faqat USTUNni yopadi, QATORni emas. Jonli
//      o'lchov (2026-09-02, anon kalit): `select=id,role,full_name` -> 12
//      qator; `role=eq.admin` -> 1 qator (YAGONA administrator ANIQLANDI);
//      `full_name=ilike.*a*` -> 7 qator (ism qidiruvi).
//   2. `anon` da barcha sinalgan 13 jadvalda TABLE-LEVEL UPDATE/DELETE
//      huquqi BOR (jonli o'lchov 2026-09-03, 0-qatorli probe -> HTTP 204;
//      ijobiy nazorat `profiles?select=phone` -> `42501`, ya'ni detektor
//      ko'r emas). Yaxlitlik BUTUNLAY RLS matniga tayanadi.
//
// ENG MUHIM QULF — REGRESSIYA TOMONI. Bu ikki faylni "kuchaytirish" oson va
// aynan shu ilovani BUZADI:
//   * `authenticated` uchun `USING (true)` OLIB TASHLANSA — 8 ta PostgREST
//     embedded join (`profiles(...)`, `profiles!inner(...)`) muallif ismini
//     BO'SH qoldiradi va `!inner` da BUTUN qatorni yo'q qiladi.
//   * `REVOKE SELECT`/`REVOKE INSERT` QO'SHILSA — mehmon tasmasi o'lardi va
//     `client_error_logs` ga mijoz xato hisoboti YOZILMAY qolardi.
//   * `FROM authenticated` yozilsa — ilovaning BARCHA yozish yo'li o'lardi.
// Shu uchun quyida IJOBIY talablar bilan birga INKORLAR ham qulflangan.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// CRLF -> LF. Toza clone'da (`core.autocrlf=true`) ishchi daraxt CRLF bo'ladi
/// va ko'p satrli naqsh moslashmaydi — meta-qulf:
/// `test/support/source_lock_portability_test.dart`.
String _read(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: 'topilmadi: $path');
  return file.readAsStringSync().replaceAll('\r\n', '\n');
}

/// `--` izoh qatorlarini TASHLAYDI: izohlarda nuqson tavsifi sifatida
/// ataylab `USING (true)`, `GRANT`, `TRUNCATE` kabi matnlar keltirilgan.
/// Tekshiruv KODDA bo'lishi kerak, izohda emas.
String _codeOf(String sql) =>
    sql.split('\n').where((l) => !l.trimLeft().startsWith('--')).join('\n');

/// Bo'sh joylarni bitta probelga siqadi (DDL ko'p qatorga bo'lingan).
String _flat(String s) => s.replaceAll(RegExp(r'\s+'), ' ');

const _migDir = 'supabase/migrations';
const _rowVisPath = '$_migDir/20260903000000_profiles_anon_row_visibility.sql';
const _revokePath = '$_migDir/20260903001000_revoke_anon_write_grants.sql';

void main() {
  group('20260903000000 — `profiles` QATOR ko\'rinishi', () {
    late String sql;
    late String code;
    late String flat;

    setUpAll(() {
      sql = _read(_rowVisPath);
      code = _codeOf(sql);
      flat = _flat(code);
    });

    test('transaction-safe', () {
      expect(code, contains('BEGIN;'));
      expect(code, contains('COMMIT;'));
    });

    test('CHEKLOVSIZ eski policy AYNAN tashlanadi', () {
      expect(flat,
          contains('DROP POLICY IF EXISTS "Public profiles are viewable '
              'by everyone" ON public.profiles'),
          reason: '`USING (true)` policy jonli bazada QOLSA, yangi anon '
              'policy\'si bilan OR qilinadi va enumeratsiya OCHIQ qoladi.');
    });

    test('AYNAN ikki policy yaratiladi — ko\'p ham, kam ham emas', () {
      final creates =
          RegExp('CREATE POLICY', caseSensitive: false).allMatches(code).length;
      expect(creates, 2,
          reason: 'anon + authenticated kutilgan. O\'lchangan: $creates — '
              'fayl o\'lchangan doiradan CHIQIB ketgan.');
    });

    test('`anon` policy\'si predikatga BOG\'LANGAN, `USING (true)` EMAS', () {
      // `GRANT EXECUTE ... TO anon, authenticated` ham `TO anon` ni o'z
      // ichiga oladi — shuning uchun `CREATE POLICY` sharti MAJBURIY.
      final anonBlock = code
          .split(';')
          .map(_flat)
          .firstWhere(
              (s) =>
                  s.contains('TO anon') &&
                  s.toUpperCase().contains('CREATE POLICY'),
              orElse: () => throw StateError('`TO anon` policy YO\'Q'));
      expect(anonBlock, contains('ON public.profiles FOR SELECT TO anon'));
      expect(anonBlock,
          contains('USING (public.is_publicly_visible_profile(id))'),
          reason: 'Qator filtri YO\'Q — 12 qatorlik dump va `role=eq.admin` '
              'bilan administratorni ajratish YANA ochiladi.');
      expect(anonBlock, isNot(contains('USING (true)')), reason: anonBlock);
    });

    test('`authenticated` uchun `USING (true)` SAQLANADI (regressiya qulfi)',
        () {
      // BU ATAYLAB. Toraytirilsa 8 ta embedded join buziladi — quyidagi
      // izoh talabi shu sababni faylda MAJBURIY qoldiradi.
      final authBlock = code
          .split(';')
          .map(_flat)
          .firstWhere((s) => s.contains('TO authenticated') &&
              s.toUpperCase().contains('CREATE POLICY'),
              orElse: () =>
                  throw StateError('`TO authenticated` policy YO\'Q'));
      expect(authBlock,
          contains('ON public.profiles FOR SELECT TO authenticated'));
      expect(authBlock, contains('USING (true)'),
          reason: 'Autentifikatsiyalangan foydalanuvchi uchun xulq '
              'O\'ZGARMASLIGI kerak edi — aks holda forum tasmasida muallif '
              'ismi BO\'SH bo\'ladi va `!inner` join BUTUN qatorni yo\'qotadi.');
    });

    test('yordamchi funksiya QOTIRILGAN `search_path` bilan', () {
      final fn = flat.substring(
          flat.indexOf('CREATE OR REPLACE FUNCTION '
              'public.is_publicly_visible_profile'));
      expect(fn, contains('RETURNS BOOLEAN'),
          reason: 'Faqat `boolean` qaytishi SHART — qator mazmuni chiqmasin.');
      expect(fn, contains('STABLE'));
      expect(fn, contains('SECURITY DEFINER'));
      expect(fn, contains('SET search_path = public, pg_temp'),
          reason: '`SECURITY DEFINER` + qotirilmagan `search_path` = sxema '
              'o\'g\'irlash (search_path hijacking) yuzasi.');
    });

    test('`anon` ga EXECUTE berilgan — aks holda mehmon `42501` oladi', () {
      expect(flat,
          contains('GRANT EXECUTE ON FUNCTION '
              'public.is_publicly_visible_profile(UUID) TO anon, '
              'authenticated'),
          reason: 'Policy ifodasi CHAQIRUVCHI huquqi bilan bajariladi. '
              'EXECUTE bo\'lmasa HAR BIR mehmon so\'rovi xato beradi — ya\'ni '
              'bu "himoya" emas, TO\'LIQ ISHDAN CHIQISH bo\'lardi.');
    });

    test('RAD ETILGAN "faqat o\'z qatori" varianti sababi faylda QOLADI', () {
      // Bu ATAYLAB izohga qaraydi: sabab yozilmasa keyingi o'quvchi
      // "nega oddiy `auth.uid() = id` emas?" deb "soddalashtiradi" va
      // mehmon tasmasini buzadi.
      expect(sql, contains('community_forum_remote_datasource.dart'),
          reason: 'Buziladigan 8 joyning MANZILI yo\'q.');
      expect(sql, contains('!inner'),
          reason: '`!inner` join BUTUN qatorni yo\'qotishi aytilmagan.');
      expect(sql, contains('NOT VERIFIED'),
          reason: '§0 — fayl jonli bazaga qo\'llanmaganini AYTISHI shart.');
    });

    test('destruktiv operatsiya YO\'Q', () {
      final upper = code.toUpperCase();
      for (final banned in const [
        'DROP TABLE',
        'DROP COLUMN',
        'DELETE FROM',
        'TRUNCATE',
        'ALTER TABLE',
        'DISABLE ROW LEVEL SECURITY',
      ]) {
        expect(upper, isNot(contains(banned)), reason: '$banned taqiqlangan');
      }
    });
  });

  group('20260903001000 — `anon` dan YOZISH huquqini olib tashlash', () {
    late String sql;
    late String code;
    late String flat;

    setUpAll(() {
      sql = _read(_revokePath);
      code = _codeOf(sql);
      flat = _flat(code);
    });

    test('transaction-safe', () {
      expect(code, contains('BEGIN;'));
      expect(code, contains('COMMIT;'));
    });

    test('UPDATE/DELETE/TRUNCATE `anon` dan olinadi', () {
      expect(flat,
          contains('REVOKE UPDATE, DELETE ON ALL TABLES IN SCHEMA public '
              'FROM anon'));
      expect(flat,
          contains('REVOKE TRUNCATE ON ALL TABLES IN SCHEMA public FROM anon'),
          reason: '`TRUNCATE` RLS\'ga BO\'YSUNMAYDI — bu yozish huquqining '
              'yagona turi bo\'lib, uning uchun RLS backstop\'i YO\'Q.');
    });

    test('KELAJAKDAGI jadvallar uchun sukut huquqi ham kamaytiriladi', () {
      expect(flat,
          contains('ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA '
              'public REVOKE UPDATE, DELETE, TRUNCATE ON TABLES FROM anon'),
          reason: 'Supabase sukuti `GRANT ALL ON TABLES TO anon` — u '
              'tuzatilmasa har YANGI jadval mehmon uchun yozilaveradi.');
    });

    test('SELECT va INSERT ga TEGILMAYDI (mehmon oqimi tirik qoladi)', () {
      final upper = flat.toUpperCase();
      expect(upper, isNot(contains('REVOKE SELECT')),
          reason: 'Mehmon tasmasi, kategoriya ro\'yxati va mutaxassis '
              'profillari O\'QILISHDA QOLISHI kerak.');
      expect(upper, isNot(contains('REVOKE INSERT')),
          reason: '`client_error_logs` ga anon INSERT LOYIHA DIZAYNI '
              '(`20260830010000:140`) — olib tashlansa mehmon qurilmasidagi '
              'xato hisoboti YO\'QOLADI.');
      expect(upper, isNot(contains('REVOKE ALL')),
          reason: '`REVOKE ALL` SELECT/INSERT ni ham yutadi.');
    });

    test('`authenticated` roliga TEGILMAYDI', () {
      expect(flat, isNot(contains('FROM authenticated')),
          reason: 'Ilovaning BARCHA yozish yo\'li `authenticated` roli bilan '
              'ketadi (5 joy, hammasi sessiya talab qiladi) — bu roldan '
              'huquq olinsa ilova BUTUNLAY yozmay qoladi.');
      expect(flat, isNot(contains('FROM service_role')),
          reason: 'Server tomoni (Edge Function) `service_role` bilan '
              'ishlaydi.');
    });

    test('bu fayl FAQAT huquq oladi — hech nima BERMAYDI', () {
      expect(RegExp(r'\bGRANT\b').hasMatch(code), isFalse,
          reason: 'Kodda `GRANT` bo\'lmasligi kerak (rollback izohda). '
              'Aks holda fayl "qatiqlashtirish" nomi ostida huquq '
              'KENGAYTIRISHI mumkin.');
    });

    test('O\'LCHOV manzili va §0 yorlig\'i faylda', () {
      expect(sql, contains('tool/anon_write_privilege_zero_rows_probe.py'),
          reason: 'Qo\'llashdan OLDINGI holat qanday o\'lchanganining manzili '
              'yo\'q — natija QAYTA topilmaydi.');
      expect(File('tool/anon_write_privilege_zero_rows_probe.py').existsSync(),
          isTrue,
          reason: 'Ko\'rsatilgan probe fayli MAVJUD EMAS — bu SOXTA ISBOT '
              'MANZILI bo\'lardi (§0).');
      expect(sql, contains('?id=is.null'),
          reason: 'Probe\'ning ma\'lumotga xavfsizligi (0 qator) qanday '
              'kafolatlanganini fayl AYTISHI kerak.');
      expect(sql, contains('42501'),
          reason: 'Ijobiy nazorat (detektor ko\'r emasligi) kodi yo\'q.');
      expect(sql, contains('NOT VERIFIED'),
          reason: '§0 — fayl jonli bazaga qo\'llanmaganini AYTISHI shart.');
    });

    test('ma\'lumotga tegadigan operatsiya YO\'Q — faqat ACL', () {
      final upper = code.toUpperCase();
      for (final banned in const [
        'DROP TABLE',
        'DROP POLICY',
        'DROP FUNCTION',
        'DELETE FROM',
        'TRUNCATE TABLE',
        'TRUNCATE PUBLIC.',
        'ALTER TABLE',
        'UPDATE PUBLIC.',
      ]) {
        expect(upper, isNot(contains(banned)),
            reason: '$banned taqiqlangan — bu fayl FAQAT huquq (`ACL`) '
                'o\'zgartiradi, ma\'lumot yo\'qolmasligi shu bilan '
                'kafolatlanadi.');
      }
    });
  });

  test('IKKI faylda ham sir YO\'Q', () {
    for (final path in const [_rowVisPath, _revokePath]) {
      final raw = _read(path);
      expect(raw, isNot(contains('sb_secret_')), reason: path);
      expect(raw, isNot(contains('service_role_key')), reason: path);
      expect(raw, isNot(matches(RegExp(r'eyJ[A-Za-z0-9_-]{20,}'))),
          reason: '$path — JWT (anon yoki service_role kaliti) SQL faylga '
              'tushib qolgan.');
    }
  });
}

