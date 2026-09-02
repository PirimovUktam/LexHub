// LEXHUB — `anon` UCHUN O'QISH/YOZISH QATIQLASHTIRISH (statik kontrakt).
//
// BU DEPLOYMENT ISBOTI EMAS. Test `supabase/migrations/*.sql` MATNINI o'qiydi,
// jonli bazaga ULANMAYDI. Ikki fayl 2026-09-02 (UTC) da JONLI production
// bazasiga QO'LLANDI — buning isboti SHU TESTDA EMAS, migratsiya fayllari
// ichidagi "QO'LLANDI" bo'limida va `.runtime_evidence/
// {before,after}_anon_hardening.out.json` nusxalarida. Qayta o'lchash yo'li:
//   python tool/anon_profile_row_visibility_probe.py
//   python tool/anon_write_privilege_zero_rows_probe.py
//   python tool/anon_privilege_probe_precise.py
// Bu testning VAZIFASI boshqa: matn kontraktini QULFLASH, ya'ni kelajakda
// kimdir bu fayllarni "soddalashtirib" himoyani yoki uning ISBOT manzilini
// o'chirib tashlashini to'sish.
//
// NIMA UCHUN BU FAYL BOR — IKKI O'LCHANGAN NUQSON (qo'llashdan OLDIN):
//   1. `profiles` da IKKI cheklovsiz SELECT policy bor edi — `USING (true)`
//      (`20260826010000:128`) va `((auth.uid() = id) OR true)` (nomi
//      "o'z profilini ko'ra oladi", jonli `pg_policies` o'lchovi). Ustun
//      darajali GRANT faqat USTUNni yopadi, QATORni emas. Jonli o'lchov
//      (2026-09-02, anon kalit): `select=id,role,full_name` -> 12 qator;
//      `role=eq.admin` -> 1 qator (YAGONA administrator ANIQLANDI);
//      `full_name=ilike.*a*` -> 7 qator (ism qidiruvi). Qo'llagandan keyin
//      uchtasi ham 0.
//   2. `anon` da `public` sxemadagi 25 obyektning HAMMASIDA table-level
//      UPDATE/DELETE/TRUNCATE huquqi BOR edi (katalog o'lchovi,
//      `has_table_privilege`), HTTP tomonidan ham tasdiqlangan (0-qatorli
//      probe -> 204; ijobiy nazorat `profiles?select=phone` -> `42501`,
//      ya'ni detektor ko'r emas). Qo'llagandan keyin uch huquq ham 0/25.
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

    test('IKKINCHI, YASHIRIN `true` policy ham AYNAN tashlanadi', () {
      // JONLI KATALOG O'LCHOVI (2026-09-02, `pg_policies`): `profiles` da
      // ikkinchi SELECT policy bor — nomi "o'z profilini ko'ra oladi", lekin
      // `qual` = `((auth.uid() = id) OR true)`, ya'ni AMALDA `true`.
      // PERMISSIVE policy'lar `OR` bilan qo'shiladi: bu qolsa yangi `anon`
      // policy'si HECH NIMANI cheklamaydi va migratsiya SOXTA tuzatish
      // bo'lardi. Shu qulf aynan shuni ushlaydi.
      expect(
          flat,
          contains('DROP POLICY IF EXISTS "Foydalanuvchilar o\'z profilini '
              'ko\'ra oladi" ON public.profiles'),
          reason: 'O\'lchangan `((auth.uid() = id) OR true)` policy '
              'tashlanmasa, enumeratsiya OCHIQ qoladi (OR birlashmasi).');
      expect(sql, contains('((auth.uid() = id) OR true)'),
          reason: 'Nima uchun tashlanayotgani (o\'lchangan `qual`) faylda '
              'yozilmagan — keyingi o\'quvchi buni "keraksiz" deb qaytaradi.');
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
      expect(sql, contains('public_questions_view'),
          reason: 'O\'LCHANGAN TUZATISH: mehmon tasmasi `profiles` join\'iga '
              'EMAS, shu view\'ga tayanadi (view `security_invoker` emas). '
              'Bu jumla yo\'qolsa fayl yana "8 join mehmon uchun ishlaydi" '
              'degan NOTO\'G\'RI da\'voga qaytadi.');
    });

    test('QO\'LLANGAN holat va HALOL QOLDIQ ikkisi ham faylda', () {
      // §0 — fayl endi QO'LLANGAN. Demak "NOT VERIFIED" yorlig'i o'rniga
      // O'LCHANGAN natija manzili turishi SHART; lekin sinalmagan tomon
      // (predikatning TRUE tarmog'i) ham AYTILISHI shart.
      expect(sql, contains('after_anon_hardening.out.json'),
          reason: 'QO\'LLANGANDAN keyingi katalog nusxasining manzili yo\'q — '
              '"qo\'llandi" da\'vosi ISBOTSIZ qolardi (§0).');
      expect(sql, contains('tool/anon_profile_row_visibility_probe.py'),
          reason: 'Enumeratsiya OLDIN/KEYIN qanday o\'lchangani manzilsiz.');
      expect(
          File('tool/anon_profile_row_visibility_probe.py').existsSync(), isTrue,
          reason: 'Ko\'rsatilgan probe MAVJUD EMAS — SOXTA ISBOT MANZILI (§0).');
      expect(sql, contains('NOT VERIFIED'),
          reason: 'Predikatning "TRUE" tarmog\'i jonli ma\'lumotda '
              'sinalmagani (production\'da 0 ommaviy savol) AYTILISHI shart — '
              'aks holda "0 qator" natijasi "predikat ishladi" deb '
              'NOTO\'G\'RI o\'qiladi.');
      expect(sql, contains('BLOCKED'),
          reason: '`authenticated` yo\'li HTTP orqali sinalmagani (test '
              'foydalanuvchi kaliti yo\'q) yorliq bilan aytilishi kerak.');
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

    test('`supabase_admin` sukut huquqi KODGA qo\'shilmaydi (o\'lchangan '
        'cheklov)', () {
      // JONLI O'LCHOV (2026-09-02): `pg_default_acl` da `public` jadvallari
      // uchun IKKI yozuv bor — `postgres` va `supabase_admin`, ikkisi ham
      // `anon=arwdDxtm`. Ikkinchisini shu ulanishdan tuzatib BO'LMAYDI:
      // `postgres` `supabase_admin` a'zosi emas va urinish jonli bazada
      // `ERROR: 42501: permission denied to change default privileges`
      // qaytardi (BEGIN...ROLLBACK ichida sinaldi). Agar kimdir bu
      // statement'ni "to'liqlik uchun" qo'shsa — BUTUN migratsiya yiqiladi
      // va hech qanday REVOKE qo'llanmaydi. Shu uchun KODDA taqiqlanadi,
      // izohda esa MAJBURIY tushuntiriladi.
      expect(code, isNot(contains('FOR ROLE supabase_admin')),
          reason: 'Bu statement `postgres` roli bilan 42501 beradi va '
              'tranzaksiyani yiqitadi — migratsiya butunlay qo\'llanmaydi.');
      expect(sql, contains('permission denied to change default privileges'),
          reason: 'Qoldiq xavf (supabase_admin yaratgan jadval) va uning '
              'o\'lchangan sababi faylda YOZILISHI shart.');
      expect(sql, contains('has_table_privilege'),
          reason: 'Katalog detektori — HTTP probe RLS bilan chalkashadigan '
              'joyda yagona ishonchli o\'lchov; uning matni faylda qolsin.');
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

    test('O\'LCHOV manzili va QO\'LLANGAN natija faylda', () {
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
      // §0 — fayl QO'LLANGAN. "Kutilgan natija" o'rniga O'LCHANGAN natija
      // va uning nusxasi turishi SHART.
      expect(sql, contains('after_anon_hardening.out.json'),
          reason: 'Qo\'llangandan keyingi katalog nusxasi manzilsiz — '
              '"qo\'llandi" da\'vosi ISBOTSIZ (§0).');
      expect(sql, contains('GRANT-RAD'),
          reason: 'HTTP probe\'ning KEYINGI natijasi (13/13 `42501`) '
              'yozilmagan — faqat OLDINGI 204 jadvali qolsa fayl eskiradi.');
      expect(sql, contains('0 / 25'),
          reason: 'Katalog OLDIN/KEYIN taqqoslashi (25 -> 0) yo\'q.');
      expect(sql, contains('arxtm'),
          reason: '`pg_default_acl` ning KEYINGI o\'lchangan holati yo\'q — '
              '`w`/`d`/`D` olinganini fayl KO\'RSATISHI kerak.');
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

