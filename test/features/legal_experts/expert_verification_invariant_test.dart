/// ADVOKAT TASDIQLASH ISHONCH CHEGARASI — QULF.
///
/// Ekranda yozilgan DA'VO: "Rasmiy Litsenziyaga Ega Advokatlar — Barcha
/// mutaxassislar O'zbekiston Advokatlar palatasi ro'yxatidan tekshirilgan"
/// (`legal_experts_page.dart`). Bu da'vo faqat quyidagi shartlar
/// BUZILMAGANDA halol:
///
///   1. Advokat O'ZINI tasdiqlay OLMAYDI — `role`/`is_verified` faqat
///      privileged DB roli orqali o'zgaradi (INSERT va UPDATE ikkisida ham).
///   2. Tasdiqlash yagona yo'l bilan boradi: `verify_expert_application()`,
///      u `is_admin_or_moderator()` bilan himoyalangan.
///   3. Ariza berish tasdiqlash EMAS — `apply_for_expert_verification()`
///      `verified_at` ni NULL qoldiradi.
///   4. Ro'yxat manbasi `public_expert_profiles_view` predikati o'zgarmaydi.
///   5. Dart kodi `expert_profiles`/`profiles` ga tasdiqlash YOZMAYDI —
///      klient faqat RPC chaqiradi.
///   6. Ro'yxatni to'ldirish runbook'i TO'QIMA advokat bermaydi va
///      AVTOMATIK ishga tushmaydi.
///
/// DIQQAT — ISBOT DARAJASI (CLAIM != EVIDENCE): bu fayl SQL MATNINI va
/// Dart MANBASINI o'qiydi, ya'ni SERVER KONTRAKTI invariantini qulflaydi.
/// U real Cloud'da migratsiya QO'LLANGANINI isbotlamaydi — buning uchun
/// alohida runtime evidence kerak (`supabase/proposals/
/// onboard_verified_lawyers_RUNBOOK.sql` dagi C.1-C.4 so'rovlari).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Izohlarni tashlab, faqat BAJARILADIGAN SQL/Dart ni qaytaradi. Izohda
/// yozilgan matn qulf uchun isbot EMAS.
String _code(String path, {required bool sql}) {
  final lines = File(path).readAsLinesSync();
  final kept = <String>[];
  var inBlock = false;
  for (final line in lines) {
    var text = line;
    if (sql) {
      // SQL blok izohi: /* ... */
      if (inBlock) {
        final end = text.indexOf('*/');
        if (end < 0) continue;
        text = text.substring(end + 2);
        inBlock = false;
      }
      final open = text.indexOf('/*');
      if (open >= 0) {
        inBlock = !text.substring(open).contains('*/');
        text = text.substring(0, open);
      }
      final dash = text.indexOf('--');
      if (dash >= 0) text = text.substring(0, dash);
    } else {
      final slash = text.indexOf('//');
      if (slash >= 0) text = text.substring(0, slash);
    }
    if (text.trim().isNotEmpty) kept.add(text);
  }
  return kept.join('\n');
}

/// Bo'shliqlarni bir xillashtiradi — SQL formatlanishi qulfni buzmasligi
/// uchun.
String _flat(String source) => source.replaceAll(RegExp(r'\s+'), ' ');

/// `needle` ni O'Z ICHIGA OLGAN ENG OXIRGI migratsiyani (fayl nomi bo'yicha)
/// qaytaradi.
///
/// NIMA UCHUN: `CREATE OR REPLACE` obyektni QAYTA YOZADI. Qulf faqat eski
/// faylni o'qisa, keyingi migratsiya view predikatini yoki gvardni buzib
/// tashlagan bo'lsa ham test YASHIL qolardi — ya'ni qulf haqiqiy holatni
/// EMAS, tarixni tekshirardi.
///
/// `sliceToSemicolon` — `needle` dan boshlab birinchi `;` gacha kesib beradi.
/// View ta'rifi uchun SHART: aks holda AYNI FAYLDAGI boshqa operator (masalan
/// RPC ichidagi `license_document_url = COALESCE(...)`) view'ning ustuni deb
/// hisoblanib, PII qulfi YOLG'ON ishga tushardi.
String _latestMigrationWith(String needle, {bool sliceToSemicolon = false}) {
  final files = Directory('supabase/migrations')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.sql'))
      .toList()
    // Fayl tizimi tartibi kafolatlanmagan — sana prefiksi bo'yicha saralash
    // SHART, aks holda "eng oxirgi" tasodifiy tanlanardi.
    ..sort((a, b) => a.path.compareTo(b.path));
  String? found;
  for (final file in files) {
    final flat = _flat(_code(file.path, sql: true));
    if (flat.contains(needle)) found = flat;
  }
  if (found == null) {
    fail('Hech bir migratsiyada topilmadi (obyekt o\'chirilgan?): $needle');
  }
  if (!sliceToSemicolon) return found;
  final start = found.indexOf(needle);
  final end = found.indexOf(';', start);
  if (end < 0) fail('Operator `;` bilan yopilmagan: $needle');
  return found.substring(start, end);
}

const _invariantSql =
    'supabase/migrations/20260827_profile_invariant_final_fix.sql';
const _runbook = 'supabase/proposals/onboard_verified_lawyers_RUNBOOK.sql';

void main() {
  group('1. O\'ZINI TASDIQLASH BLOKLANGAN (server tomon)', () {
    late String sql;
    setUpAll(() => sql = _flat(_code(_invariantSql, sql: true)));

    test('UPDATE da `role` o\'zgarishi RAISE EXCEPTION beradi', () {
      expect(sql.contains('NEW.role IS DISTINCT FROM OLD.role'), isTrue,
          reason: 'role tampering gvardi olib tashlangan');
      expect(sql.contains('Privilege Escalation Blocked'), isTrue);
    });

    test('UPDATE da `is_verified` o\'zgarishi BLOKLANADI', () {
      expect(
          sql.contains('NEW.is_verified IS DISTINCT FROM OLD.is_verified'),
          isTrue,
          reason: 'foydalanuvchi o\'zini "tasdiqlangan" qilib qo\'yishi mumkin');
      expect(sql.contains('Verification Escalation Blocked'), isTrue);
    });

    test('INSERT da `role` faqat `citizen`, `is_verified` faqat FALSE', () {
      expect(
          sql.contains(
              "NEW.role IS DISTINCT FROM 'citizen'::public.user_role"),
          isTrue,
          reason: 'profili yo\'q user o\'ziga role=admin bilan INSERT qila '
              'oladi (P0 escalation yuzasi qaytgan)');
      expect(sql.contains('COALESCE(NEW.is_verified, FALSE)'), isTrue);
    });

    test('gvardni chetlab o\'tish FAQAT privileged DB roliga ochiq', () {
      expect(sql.contains('NOT public.is_privileged_db_role()'), isTrue);
      // `current_user != 'service_role'` YOLG'IZ o'zi YETARLI EMAS: PostgREST
      // `authenticated` roli ostida ishlaydi, ya'ni bu shart HAR DOIM rost
      // bo'lib gvardni ochib qo'yardi (migration izohi: FIX #5 root cause).
      expect(
          sql.contains(
              "current_user IN ('postgres', 'supabase_admin', "
              "'supabase_auth_admin', 'service_role')"),
          isTrue,
          reason: 'privileged rollar ro\'yxati o\'zgargan — sabab yozilishi '
              'kerak');
    });

    test('`handle_new_user()` rolni client metadata\'sidan OLMAYDI', () {
      expect(sql.contains("'citizen'::public.user_role"), isTrue);
      expect(sql.contains("raw_user_meta_data->>'role'"), isFalse,
          reason: 'signUp payload\'idagi `role` ga ishonilmoqda — '
              'privilege escalation');
    });
  });

  group('2. TASDIQLASH YO\'LI — YAGONA va ADMIN QULFLANGAN', () {
    // Har bir invariant O'Z obyektining ENG OXIRGI ta'rifidan o'qiladi.
    late String verifyFn;
    late String applyFn;
    late String guardFn;
    late String viewSql;
    setUpAll(() {
      verifyFn = _latestMigrationWith(
          'CREATE OR REPLACE FUNCTION public.verify_expert_application(');
      applyFn = _latestMigrationWith(
          'CREATE OR REPLACE FUNCTION public.apply_for_expert_verification(');
      guardFn = _latestMigrationWith('CREATE OR REPLACE FUNCTION '
          'public.protect_expert_profile_sensitive_fields()');
      viewSql = _latestMigrationWith(
          'CREATE OR REPLACE VIEW public.public_expert_profiles_view AS',
          sliceToSemicolon: true);
    });

    test('`verify_expert_application` admin/moderator gvardi bilan', () {
      expect(
          verifyFn.contains("IF NOT public.is_admin_or_moderator() THEN"),
          isTrue,
          reason: 'tasdiqlash gvardi o\'zgargan — har kim advokat bo\'la '
              'oladi');
      expect(verifyFn.contains('Access Denied'), isTrue);

      // INVARIANT KUCHAYTIRILDI (yumshatilmadi), 2026-08-29.
      //
      // ILGARIGI shart `... AND current_user != 'service_role'` edi va u
      // O'LIK: funksiya `SECURITY DEFINER`, ya'ni uning ichida `current_user`
      // = funksiya EGASI (`postgres`), `service_role` HECH QACHON emas.
      //
      // JONLI O'LCHOV (anon publishable kalit, tasodifiy UUID, 2026-08-29):
      // `p_approve` ikki qiymatida ham HTTP 400 + P0001 "Access Denied: ..."
      // — ya'ni shart hech kimni O'TKAZMAGAN, shunchaki o'lik edi.
      //
      // NIMA UCHUN QAYTISHI TAQIQLANADI: funksiya egasi kelajakda
      // `service_role` ga o'tkazilsa shart TESKARISIGA aylanadi — gvard
      // hech qachon ishlamaydi va har kim advokatni tasdiqlay oladi.
      expect(verifyFn.contains("current_user != 'service_role'"), isFalse,
          reason: 'o\'lik `current_user` sharti qaytgan — `SECURITY DEFINER` '
              'ichida u chaqiruvchini AJRATMAYDI '
              '(20260829130000_expert_moderation_guard_fix_and_apply_'
              'cooldown.sql, 2-bo\'lim)');
    });

    test('tasdiqlash `role` + `is_verified` + `verified_at` ni BIRGA qo\'yadi',
        () {
      // Uchtasidan biri tushib qolsa advokat view'ga TUSHMAYDI (yoki
      // teskarisi: tasdiq sanasi yo'q advokat "tasdiqlangan" bo'lib chiqadi).
      expect(verifyFn.contains("role = 'verified_expert', is_verified = TRUE"),
          isTrue);
      expect(verifyFn.contains('SET verified_at = now()'), isTrue);
    });

    test('ARIZA tasdiqlash EMAS — `verified_at` NULL qoladi', () {
      expect(applyFn.contains('SECURITY DEFINER'), isTrue);
      expect(applyFn.contains('v_user_id := auth.uid();'), isTrue,
          reason: 'ariza boshqa foydalanuvchi nomidan berilishi mumkin');
      // ON CONFLICT bloki `verified_at` ga TAYINLAMASLIGI SHART: aks holda
      // ariza qayta topshirilganda tasdiqlangan advokat tasdiqini yo'qotadi
      // (yoki teskarisi — o'ziga tasdiq qo'yib oladi). `verified_at` ni
      // O'QISH taqiqlanmaydi: T-2 qulfi aynan shu qiymatga qarab ishlaydi.
      final conflict = applyFn.substring(
        applyFn.indexOf('ON CONFLICT (user_id) DO UPDATE SET'),
        applyFn.indexOf('RETURNING id INTO v_expert_id'),
      );
      expect(RegExp(r'verified_at\s*=').hasMatch(conflict), isFalse,
          reason: 'ariza tasdiqni o\'zgartirmasligi kerak');
      expect(conflict.contains('role'), isFalse,
          reason: 'ariza `profiles.role` ga TEGMAYDI');
    });

    test('`expert_profiles` gvardi tasdiq sanasi va reytingni qulflaydi', () {
      expect(
          guardFn.contains('NEW.verified_at IS DISTINCT FROM OLD.verified_at'),
          isTrue,
          reason: 'advokat o\'ziga tasdiq sanasi qo\'yib, ro\'yxatga '
              'tushib oladi');
      expect(guardFn.contains('NEW.rating IS DISTINCT FROM OLD.rating'), isTrue,
          reason: 'reyting to\'qib chiqarilishi mumkin (§6)');
      expect(
          guardFn.contains('NEW.user_id IS DISTINCT FROM OLD.user_id'), isTrue);
    });

    test('RO\'YXAT MANBASI: view predikati o\'zgarmaydi', () {
      expect(
          viewSql.contains(
              "WHERE p.is_verified = TRUE AND p.role::text IN "
              "('verified_expert', 'lawyer')"),
          isTrue,
          reason: 'ro\'yxatga tasdiqlanmagan profil tushib qolishi mumkin');
      // Litsenziya HUJJATI ochiq view'da BERILMAYDI (PII) — hech bir
      // migratsiyada, hech qanday alias bilan.
      expect(viewSql.contains('license_document_url'), isFalse,
          reason: 'litsenziya hujjati URL\'i anon uchun ochilgan (PII)');
    });
  });

  group('3. KLIENT TOMON tasdiqlash YOZMAYDI', () {
    test('Dart kodi `expert_profiles` ga INSERT/UPDATE/UPSERT qilmaydi', () {
      final offenders = <String>[];
      for (final file in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final src = _flat(_code(file.path, sql: false));
        final touchesTable = src.contains("'expert_profiles'") ||
            src.contains('"expert_profiles"');
        if (!touchesTable) continue;
        if (RegExp(r'\.(insert|upsert|update|delete)\(').hasMatch(src)) {
          offenders.add(file.path);
        }
      }
      expect(offenders, isEmpty,
          reason: 'tasdiqlash FAQAT `verify_expert_application` RPC orqali '
              'bo\'lishi kerak; to\'g\'ridan-to\'g\'ri yozuv gvardni '
              'chetlab o\'tish yuzasini ochadi: $offenders');
    });

    test('ariza yo\'li `verified_at` / `role` YUBORMAYDI', () {
      final src = _code(
        'lib/features/legal_experts/data/datasources/'
        'legal_experts_remote_datasource.dart',
        sql: false,
      );
      expect(src.contains("'apply_for_expert_verification'"), isTrue);

      // INVARIANT AYNIQLASHTIRILDI (yumshatilmadi): taqiq — `verified_at` ni
      // klient YOZISHI. O'QISH filtri sifatida ishlatish (moderatsiya
      // ro'yxatidagi `.isFilter('verified_at', null)`) ZARUR va xavfsiz:
      // filtr `WHERE` ga tushadi, `SET` ga EMAS. Ilgari bu yerda
      // `src.contains('verified_at')` turgan, ya'ni o'qishni ham taqiqlagan —
      // u haqiqiy xavf (yozuv) o'rniga MATNNI qulflagan.
      //
      // YOZUV shakllari: payload map kaliti (`'verified_at': ...`) yoki RPC
      // parametri (`'p_verified_at'`). Ikkisi ham TAQIQ.
      expect(RegExp(r"'verified_at'\s*:").hasMatch(src), isFalse,
          reason: 'klient tasdiq sanasini payload\'ga qo\'yib yuborayapti');
      expect(src.contains("'p_verified_at'"), isFalse,
          reason: 'tasdiq sanasi RPC parametri sifatida klientdan kelmaydi');
      expect(src.contains("'p_role'"), isFalse);
      expect(RegExp(r"'role'\s*:").hasMatch(src), isFalse,
          reason: 'rolni klient o\'zi tayinlashga urinmoqda');
      // Asosiy qulf (to'g'ridan-to'g'ri yozuv YO'Q) yuqoridagi testda —
      // `.insert|.upsert|.update|.delete` bo'yicha — o'zgarishsiz qoladi.
    });
  });

  group('4. RUNBOOK — HALOL va AVTOMATIK EMAS', () {
    late String raw;
    setUpAll(() => raw = File(_runbook).readAsStringSync());

    test('`supabase/migrations/` da EMAS — o\'z-o\'zidan ishga tushmaydi', () {
      expect(File(_runbook).existsSync(), isTrue);
      final autoRun = Directory('supabase/migrations')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('onboard_verified_lawyers'));
      expect(autoRun, isEmpty,
          reason: 'ma\'lumot kiritish migratsiya EMAS — `db push` uni '
              'avtomatik bajarmasligi kerak');
    });

    test('TO\'QIMA advokat ma\'lumoti YO\'Q', () {
      // Soxta telefon / soxta litsenziya / o'ylab topilgan ism — P0-01
      // presedenti (`legal_expert_model.dart` sarlavhasiga qara).
      expect(RegExp(r'\+998\d{9}').hasMatch(raw), isFalse,
          reason: 'runbook\'da BOSIB QO\'NG\'IROQ QILINADIGAN soxta raqam');
      expect(raw.contains('ADV-VERIFIED'), isFalse);
      expect(RegExp(r"VALUES\s*\(\s*'[0-9a-f]{8}-").hasMatch(raw), isFalse,
          reason: 'to\'ldirilgan (placeholder emas) UUID bilan INSERT');
      // Bajariladigan SQL da faqat SELECT qolishi SHART: INSERT/UPDATE
      // bloklari izohda (placeholder to'ldirilmaguncha).
      final exec = _flat(_code(_runbook, sql: true));
      expect(RegExp(r'\b(INSERT|UPDATE|DELETE)\b').hasMatch(exec), isFalse,
          reason: 'runbook izohdan chiqib, JIM ishga tushadigan yozuv '
              'operatsiyasiga aylangan');
    });

    test('tasdiqlash uchun AYNI server funksiyasiga yo\'naltiradi', () {
      expect(raw.contains('public.verify_expert_application('), isTrue,
          reason: 'runbook o\'z yo\'lini o\'ylab topmasligi kerak');
      expect(raw.contains('auth.users'), isTrue);
      expect(raw.contains('handle_new_user()'), isTrue,
          reason: 'qo\'lda `profiles` INSERT ogohlantirishi yo\'q');
    });

    test('hudud filtri talabi yozilgan (`workplace` matniga bog\'liq)', () {
      expect(raw.contains('UzbekRegions.regionOf()'), isTrue,
          reason: 'hudud `workplace` dan olinishi tushuntirilmagan — '
              'ma\'lumot kiritilsa filtr yana bo\'sh qaytadi');
      expect(raw.contains('LawyerSpecializationMatcher'), isTrue);
    });

    test('MAVJUD BO\'LMAGAN ustunga murojaat YO\'Q (so\'rov Studio\'da '
        'yiqilmasligi kerak)', () {
      final exec = _flat(_code(_runbook, sql: true));
      // `public.profiles` da `email` ustuni YO'Q (`20260819_base_schema.sql`).
      // Email FAQAT `auth.users` da — runbook o'sha jadvalga JOIN qilishi SHART.
      expect(RegExp(r'\bp\.email\b').hasMatch(exec), isFalse,
          reason: '`profiles.email` ustuni mavjud emas — `auth.users` ga JOIN '
              'qilinishi kerak');
      expect(exec.contains('profiles.email'), isFalse);
      // OCHIQ view'dan PII so'ralmaydi. `expert_profiles` dan so'rash TO'G'RI
      // va ZARUR: admin arizani tekshirish uchun litsenziya hujjatini ochishi
      // SHART (A.1) — u service_role kontekstida ishlaydi, anon uchun emas.
      for (final statement in exec.split(';')) {
        if (!statement.contains('public_expert_profiles_view')) continue;
        expect(statement.contains('license_document_url'), isFalse,
            reason: 'ochiq view\'dan PII maydoni so\'ralgan — bu so\'rov '
                '`column ... does not exist` bilan yiqiladi');
      }
    });
  });

  group('5. LITSENZIYA — KO\'RINISH (T-1) va TASDIQDAN KEYIN QULF (T-2)', () {
    const viewNeedle =
        'CREATE OR REPLACE VIEW public.public_expert_profiles_view AS';
    late String viewBlock;
    late String viewFile;
    late String guardFn;
    late String applyFn;
    setUpAll(() {
      viewBlock = _latestMigrationWith(viewNeedle, sliceToSemicolon: true);
      viewFile = _latestMigrationWith(viewNeedle);
      guardFn = _latestMigrationWith('CREATE OR REPLACE FUNCTION '
          'public.protect_expert_profile_sensitive_fields()');
      applyFn = _latestMigrationWith(
          'CREATE OR REPLACE FUNCTION public.apply_for_expert_verification(');
    });

    test('T-1: view litsenziya RAQAMINI beradi (da\'vo tekshirilishi uchun)',
        () {
      // Ekrandagi "Advokatlar palatasi ro'yxatidan tekshirilgan" da'vosi
      // raqam ko'rinmasa ISBOTSIZ qoladi. Raqam ochiq ma'lumot, hujjat esa PII.
      expect(viewBlock.contains('ep.license_number'), isTrue,
          reason: 'view\'dan `license_number` olib tashlangan — '
              '`LegalExpertModel.licenseNumber` yana DOIM bo\'sh bo\'ladi');
    });

    test('view QAYTA YARATILMAYDI — `DROP VIEW` GRANT\'larni yo\'qotadi', () {
      expect(viewFile.contains('DROP VIEW'), isFalse,
          reason: '`DROP VIEW` + `CREATE` anon/authenticated GRANT\'ini va '
              'view egasi orqali RLS\'ni chetlab o\'tish xususiyatini '
              'yo\'qotadi — ro\'yxat BO\'SH qaytadi');
    });

    test('T-2 / yo\'l 2: to\'g\'ridan-to\'g\'ri UPDATE tasdiqlangan raqamni '
        'o\'zgartira olmaydi', () {
      // `"Experts can update their profile"` policy'si owner UPDATE'ga ruxsat
      // beradi, ya'ni qulf FAQAT trigger gvardida bo'lishi mumkin.
      expect(
          guardFn.contains('OLD.verified_at IS NOT NULL') &&
              guardFn.contains(
                  'NEW.license_number IS DISTINCT FROM OLD.license_number'),
          isTrue,
          reason: 'tasdiqlangan advokat REST orqali litsenziya raqamini '
              'almashtira oladi (T-2 qaytdi)');
      expect(guardFn.contains('License Number Locked'), isTrue);
    });

    test('T-2 / yo\'l 1: SECURITY DEFINER RPC ham raqamni SAQLAYDI', () {
      // MUHIM: RPC ichida `current_user` = funksiya EGASI, ya'ni trigger
      // gvardi shartidan O'TIB KETADI. Shu sababli qulf RPC ning O'ZIDA
      // bo'lishi SHART — aks holda yo'l 1 ochiq qoladi.
      expect(
          applyFn.contains(
              'license_number = CASE WHEN expert_profiles.verified_at IS NULL '
              'THEN EXCLUDED.license_number ELSE '
              'expert_profiles.license_number END'),
          isTrue,
          reason: 'arizani qayta yuborish tekshirilgan litsenziya raqamini '
              'almashtiradi (T-2 qaytdi)');
    });

    test('TASDIQLANMAGAN ariza TAHRIRLANADIGAN bo\'lib qoladi', () {
      // Qulf tasdiq momentidan KEYIN yopiladi. Aks holda advokat xato yozgan
      // raqamni tuzata olmay qolardi va ariza berish yo'li buzilardi.
      expect(applyFn.contains('expert_profiles.verified_at IS NULL'), isTrue,
          reason: 'qulf shartsiz qo\'yilgan — tasdiqlanmagan ariza ham '
              'muzlatilgan');
      expect(applyFn.contains('specialization = EXCLUDED.specialization'),
          isTrue,
          reason: 'ariza yangilash yo\'li buzilgan');
    });
  });
}
