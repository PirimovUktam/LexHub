import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// AUTH PROFILE INVARIANT — MIGRATION SOURCE GUARD
///
/// MUHIM CHEKLOV (CLAIM != EVIDENCE): bu test FAQAT repo'dagi SQL matnini
/// tekshiradi. U migration live Supabase'ga DEPLOY qilinganini yoki real
/// signup ishlaganini ISBOTLAMAYDI. Bu regressiya qo'riqchisi:
/// `20260827_profile_invariant_final_fix.sql` dagi to'rt fix keyingi
/// commit'larda jimgina qaytarib olinmasligi uchun.
///
/// Root cause (live'da tasdiqlangan): `profiles.phone` TEXT NOT NULL,
/// DEFAULT yo'q; email signup'da `auth.users.phone` = NULL =>
/// `handle_new_user()` INSERT'i 23502 => `EXCEPTION WHEN OTHERS THEN NULL`
/// xatoni yutdi => profil YO'Q, signup "muvaffaqiyatli" => keyin
/// `questions.user_id` FK 23503.
void main() {
  const migrationsDir = 'supabase/migrations';
  const fixFile = '$migrationsDir/20260827_profile_invariant_final_fix.sql';

  /// SQL `--` izohlarini olib tashlaydi, string literal ichidagi `--` ni
  /// esa saqlaydi. Izohlarni tozalamasdan tekshirish yolg'on natija beradi:
  /// fayl sarlavhasi eski BUG'ni tasvirlash uchun aynan o'sha naqshlarni
  /// (`EXCEPTION WHEN OTHERS`, `DROP NOT NULL`) matn sifatida o'z ichiga oladi.
  String stripSqlComments(String sql) {
    final out = StringBuffer();
    var inString = false;
    var inComment = false;
    for (var i = 0; i < sql.length; i++) {
      final ch = sql[i];
      if (inComment) {
        if (ch == '\n') {
          inComment = false;
          out.write(ch);
        }
        continue;
      }
      if (inString) {
        out.write(ch);
        if (ch == "'") inString = false;
        continue;
      }
      if (ch == "'") {
        inString = true;
        out.write(ch);
        continue;
      }
      if (ch == '-' && i + 1 < sql.length && sql[i + 1] == '-') {
        inComment = true;
        i++;
        continue;
      }
      out.write(ch);
    }
    return out.toString();
  }

  String readCode(String path) {
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: 'fayl topilmadi: $path');
    return stripSqlComments(file.readAsStringSync());
  }

  late String code;

  setUpAll(() {
    code = readCode(fixFile);
  });

  group('izoh tozalagichning o\'zi (test infratuzilmasi)', () {
    test('`--` izoh olib tashlanadi, string ichidagi `--` qoladi', () {
      expect(stripSqlComments('SELECT 1; -- izoh\nSELECT 2;'),
          'SELECT 1; \nSELECT 2;');
      expect(stripSqlComments("SELECT 'a--b'; -- izoh"), "SELECT 'a--b'; ");
      expect(stripSqlComments("SELECT 'yo''q'; -- izoh"), "SELECT 'yo''q'; ");
    });

    test('sarlavha izohidagi eski bug naqshlari kodga o\'tmaydi', () {
      final raw = File(fixFile).readAsStringSync();
      // Xom matnda bug tavsifi BOR (dokumentatsiya), kodda esa YO'Q.
      expect(raw.contains('EXCEPTION WHEN OTHERS THEN NULL'), isTrue,
          reason: 'sarlavha root cause`ni tushuntirishi kerak');
      expect(code.contains('EXCEPTION WHEN OTHERS THEN NULL'), isFalse);
    });
  });

  group('TASK 1 — profiles.phone NULL qabul qiladi, DEFAULT qo\'shilmaydi', () {
    test('NOT NULL olib tashlanadi', () {
      expect(
          code.contains(
              'ALTER TABLE public.profiles ALTER COLUMN phone DROP NOT NULL'),
          isTrue,
          reason: 'root cause tuzatilmagan');
    });

    test('ustun yo\'q muhitda idempotent qo\'shiladi', () {
      expect(code.contains('ADD COLUMN IF NOT EXISTS phone TEXT'), isTrue,
          reason: 'toza `db reset`da handle_new_user 42703 beradi');
    });

    test('DEFAULT ATAYLAB qo\'shilmaydi (talab §1)', () {
      expect(code.contains('SET DEFAULT'), isFalse,
          reason: 'talab: DEFAULT qo\'shmasdan NULL qabul qilinsin');
    });

    test('mavjud data o\'zgartirilmaydi', () {
      for (final destructive in [
        'DROP TABLE',
        'TRUNCATE',
        'DELETE FROM',
        'DROP COLUMN',
        'DROP CONSTRAINT',
        'UPDATE public.profiles SET',
        'UPDATE profiles SET',
      ]) {
        expect(code.contains(destructive), isFalse,
            reason: 'destruktiv operatsiya: $destructive');
      }
      // Yagona data yozuvi: trigger funksiyasidagi INSERT + backfill.
      expect('INSERT INTO public.profiles'.allMatches(code).length, 2);
      expect(code.contains('ON CONFLICT (id) DO NOTHING'), isTrue);
      expect(code.contains('WHERE p.id IS NULL'), isTrue,
          reason: 'backfill faqat YETISHMAYDIGAN qatorlarni qo\'shishi kerak');
    });
  });

  group('TASK 2 — handle_new_user() xatoni YUTMAYDI', () {
    late String body;

    setUpAll(() {
      final start =
          code.indexOf('CREATE OR REPLACE FUNCTION public.handle_new_user()');
      expect(start, isNot(-1), reason: 'funksiya ta\'rifi topilmadi');
      final end = code.indexOf(r'$function$;', start);
      expect(end, isNot(-1));
      body = code.substring(start, end);
    });

    test('silent fallback YO\'Q — asl xato qayta ko\'tariladi', () {
      expect(body.contains('EXCEPTION WHEN OTHERS'), isTrue,
          reason: 'log uchun handler qoladi');
      expect(body.contains('RAISE WARNING'), isTrue,
          reason: 'Postgres log`ida forensic iz qolishi kerak');
      expect(body.contains('RAISE;'), isTrue,
          reason: 'bare RAISE asl SQLSTATE`ni saqlaydi');
      // Handler ichida `RETURN NEW` bo'lsa — signup yana yolg'on success beradi.
      final handler = body.substring(body.indexOf('EXCEPTION WHEN OTHERS'));
      expect(handler.contains('RETURN NEW'), isFalse,
          reason: 'xatodan keyin RETURN NEW = profilsiz "muvaffaqiyatli" signup');
      expect(handler.contains('INSERT INTO'), isFalse,
          reason: 'zaxira INSERT yana 23502 beradi — olib tashlangan bo\'lishi shart');
    });

    test('NEW.phone NULL holati VALID', () {
      expect(body.contains('NEW.phone'), isTrue);
      expect(body.contains("COALESCE(NEW.phone"), isFalse,
          reason: 'NULL`ni yashirish = talab §1 buzilishi');
    });

    test('ON CONFLICT (id) saqlangan, imtiyozlar yangilanmaydi', () {
      expect(body.contains('ON CONFLICT (id) DO UPDATE'), isTrue);
      final conflict = body.substring(body.indexOf('ON CONFLICT (id)'));
      for (final privileged in ['role', 'is_verified', 'reputation_points']) {
        expect(conflict.contains('$privileged  ='), isFalse,
            reason: '$privileged signup orqali qayta yozilmasligi kerak');
        expect(conflict.contains('$privileged ='), isFalse,
            reason: '$privileged signup orqali qayta yozilmasligi kerak');
      }
    });

    test('SECURITY DEFINER + search_path saqlangan', () {
      expect(body.contains('SECURITY DEFINER'), isTrue);
      expect(body.contains('SET search_path = public, pg_temp'), isTrue,
          reason: 'search_path pinlanmasa SECURITY DEFINER xavfli');
    });

    test('full_name normallashtiriladi (22001/23502 sinfi yopiladi)', () {
      expect(body.contains('left(COALESCE'), isTrue,
          reason: 'VARCHAR(128) uchun uzunlik cheklovi');
      expect(body.contains('btrim(COALESCE'), isTrue);
    });
  });

  group('TASK 3 — auth.users.id = profiles.id invarianti', () {
    test('FK profiles.id -> auth.users(id)', () {
      expect(code.contains('REFERENCES auth.users(id)'), isTrue);
      expect(code.contains('FOREIGN KEY (id)'), isTrue);
      expect(code.contains('pg_constraint'), isTrue,
          reason: 'idempotentlik uchun katalog tekshiruvi kerak');
    });

    test('backfill mavjud yetishmovchilikni to\'ldiradi', () {
      expect(code.contains('FROM auth.users u'), isTrue);
      expect(code.contains('LEFT JOIN public.profiles p ON p.id = u.id'), isTrue);
    });

    test('orphan qolsa migration YIQILADI (yolg\'on success yo\'q)', () {
      expect(code.contains('INVARIANT BUZILGAN'), isTrue);
      final tail = code.substring(code.indexOf('INVARIANT BUZILGAN') - 200);
      expect(tail.contains('RAISE EXCEPTION'), isTrue,
          reason: 'WARNING yetarli emas — tranzaksiya rollback bo\'lishi kerak');
    });

    test('trigger qayta ulanadi va dublikat yaratmaydi', () {
      expect(code.contains('DROP TRIGGER IF EXISTS on_auth_user_created'), isTrue);
      expect(code.contains('AFTER INSERT ON auth.users'), isTrue);
      expect('CREATE TRIGGER'.allMatches(code).length,
          'DROP TRIGGER IF EXISTS'.allMatches(code).length,
          reason: 'har bir CREATE TRIGGER oldidan DROP IF EXISTS bo\'lishi shart');
    });
  });

  group('TASK 4 — client role=admin bera OLMAYDI', () {
    test('yangi INSERT policy YARATILMAYDI', () {
      expect(code.contains('CREATE POLICY'), isFalse,
          reason: 'client`dan profil yaratish yo\'li ochilmasligi kerak');
      expect(code.contains('FOR INSERT WITH CHECK'), isFalse);
    });

    test('mavjud INSERT policy`lar nom bo\'yicha emas, katalog bo\'yicha o\'chadi',
        () {
      expect(code.contains("cmd = 'INSERT'"), isTrue,
          reason: 'live`da policy nomi boshqacha bo\'lishi mumkin');
      expect(code.contains('DROP POLICY %I ON public.profiles'), isTrue);
    });

    test('anon/authenticated rollaridan INSERT grant olinadi', () {
      expect(code.contains('REVOKE INSERT ON TABLE public.profiles FROM'), isTrue);
      expect(code.contains("'anon'"), isTrue);
      expect(code.contains("'authenticated'"), isTrue);
      expect(code.contains('FROM pg_roles WHERE rolname'), isTrue,
          reason: 'rol yo\'q muhitda REVOKE 42704 beradi');
    });

    test('role client metadata`sidan OLINMAYDI', () {
      expect(code.contains("raw_user_meta_data->>'role'"), isFalse,
          reason: 'signUp payload`i role`ni belgilay olmasligi kerak');
      expect("'citizen'::public.user_role".allMatches(code).length, 3,
          reason: 'trigger + backfill + INSERT guard — hammasida hardcoded');
    });

    test('guard funksiyalar SECURITY INVOKER (DEFINER = o\'lik kod)', () {
      // SECURITY DEFINER ichida `current_user` DOIM funksiya egasi bo'ladi,
      // shuning uchun chaqiruvchini ko'rishi kerak bo'lgan guard INVOKER
      // bo'lishi SHART (20260826 dagi P0 sababi shu edi).
      for (final fn in [
        'public.is_privileged_db_role()',
        'public.protect_profile_privileged_columns_on_insert()',
        'public.protect_profile_sensitive_fields()',
      ]) {
        final start = code.indexOf('CREATE OR REPLACE FUNCTION $fn');
        expect(start, isNot(-1), reason: '$fn ta\'rifi yo\'q');
        final head = code.substring(start, code.indexOf(r'AS $function$', start));
        expect(head.contains('SECURITY INVOKER'), isTrue, reason: fn);
        expect(head.contains('SECURITY DEFINER'), isFalse, reason: fn);
      }
      expect('SECURITY DEFINER'.allMatches(code).length, 1,
          reason: 'faqat handle_new_user() DEFINER bo\'lishi kerak');
    });

    test('INSERT guard OLD`ga tegmaydi (55000 oldini olish)', () {
      final start = code.indexOf(
          'CREATE OR REPLACE FUNCTION '
          'public.protect_profile_privileged_columns_on_insert()');
      final end = code.indexOf(r'$function$;', start);
      final body = code.substring(start, end);
      expect(body.contains('OLD.'), isFalse,
          reason: 'INSERT triggerida OLD tayinlanmagan');
      expect(body.contains('is_privileged_db_role()'), isTrue);
      expect(body.contains('Privilege Escalation Blocked'), isTrue);
    });

    test('UPDATE guard imtiyozli ustunlarni himoya qiladi', () {
      final start = code.indexOf(
          'CREATE OR REPLACE FUNCTION public.protect_profile_sensitive_fields()');
      final body = code.substring(start, code.indexOf(r'$function$;', start));
      expect(body.contains("TG_OP = 'UPDATE'"), isTrue);
      expect(body.contains('NEW.role IS DISTINCT FROM OLD.role'), isTrue);
      expect(body.contains('NEW.is_verified IS DISTINCT FROM OLD.is_verified'),
          isTrue);
      expect(
          body.contains(
              'NEW.reputation_points IS DISTINCT FROM OLD.reputation_points'),
          isTrue);
      // Qonuniy tahrirlash buzilmasligi kerak: toUpdatePayload() yuboradigan
      // ustunlar guard ro'yxatida BO'LMASLIGI shart.
      for (final allowed in ['full_name', 'avatar_url', 'phone', 'bio']) {
        expect(body.contains('NEW.$allowed IS DISTINCT FROM'), isFalse,
            reason: '$allowed profil tahrirlashda o\'zgarishi kerak');
      }
    });
  });

  group('TASK 7 — idempotentlik va migration TARTIBI', () {
    test('bitta tranzaksiyaga o\'ralgan', () {
      expect(code.trimLeft().startsWith('BEGIN;'), isTrue);
      expect(code.trimRight().endsWith('COMMIT;'), isTrue,
          reason: 'yarim qo\'llangan migration eng xavfli holat');
      expect(code.contains('ROLLBACK'), isFalse,
          reason: 'migration ichida ROLLBACK bo\'lmasligi kerak');
    });

    test('barcha DDL idempotent shaklda', () {
      // Shartsiz `ADD CONSTRAINT` / `ALTER COLUMN` ikkinchi run`da yiqiladi.
      expect(code.contains('ADD COLUMN IF NOT EXISTS'), isTrue);
      expect(code.contains('CREATE OR REPLACE FUNCTION'), isTrue);
      expect(code.contains('CREATE FUNCTION public.'), isFalse,
          reason: 'OR REPLACE bo\'lmasa 42723');
      expect(code.contains('pg_attribute'), isTrue,
          reason: 'DROP NOT NULL katalog bilan qo\'riqlanishi kerak');
    });

    test('fix fayli handle_new_user() ni ta\'riflovchi ENG OXIRGI fayl', () {
      // `supabase db push/reset` leksikografik tartibda ishlatadi: kichik
      // prefiks bilan nomlansa, eski (xatoni yutuvchi) ta'rif OXIRGI qo'llanadi
      // va fix jimgina bekor bo'ladi.
      final definers = Directory(migrationsDir)
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.sql'))
          .where((f) => stripSqlComments(f.readAsStringSync())
              .contains('FUNCTION public.handle_new_user'))
          .map((f) => f.uri.pathSegments.last)
          .toList()
        ..sort();
      expect(definers.length, greaterThan(1),
          reason: 'eski ta\'riflar hamon repo\'da — tartib muhim');
      expect(definers.last, '20260827_profile_invariant_final_fix.sql',
          reason: 'fix eng oxirgi qo\'llanishi SHART');
    });

    test('fix fayli anti-tampering guard`ni ta\'riflovchi ENG OXIRGI fayl', () {
      final definers = Directory(migrationsDir)
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.sql'))
          .where((f) => stripSqlComments(f.readAsStringSync())
              .contains('FUNCTION public.protect_profile_sensitive_fields'))
          .map((f) => f.uri.pathSegments.last)
          .toList()
        ..sort();
      expect(definers.last, '20260827_profile_invariant_final_fix.sql',
          reason: 'SECURITY DEFINER (o\'lik guard) versiyasi qaytib kelmasligi kerak');
    });

    test('oldingi migration fayllari QAYTA YOZILMAGAN', () {
      // Talab §7: "Avvalgi migrationlarni qayta yozma". Fix faqat
      // CREATE OR REPLACE bilan ustidan yozadi.
      for (final old in [
        '20260826000500_bulletproof_auth_signup_trigger.sql',
        // 2026-08-29 da qayta nomlandi (8 xonali prefiks to'qnashuvi —
        // `schema_migrations.version` PRIMARY KEY). Mazmuni o'zgarmagan.
        '20260826010000_fix_profile_anti_tampering_and_auth_trigger.sql',
      ]) {
        expect(File('$migrationsDir/$old').existsSync(), isTrue,
            reason: '$old o\'chirilgan');
      }
    });

    test('regressiya detektori kelgusi NOT NULL drift`ini ushlaydi', () {
      expect(code.contains('SCHEMA DRIFT'), isTrue);
      expect(code.contains('pg_attrdef'), isTrue,
          reason: 'DEFAULT`i yo\'q NOT NULL ustunlar aniqlanishi kerak');
      expect(code.contains('attgenerated'), isTrue,
          reason: 'generated ustunlar noto\'g\'ri ogohlantirish bermasligi kerak');
    });
  });

  group('TASK 4/5/6 — Dart tomoni (client yo\'llari)', () {
    String dartCode(String path) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: 'fayl topilmadi: $path');
      return file
          .readAsStringSync()
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
    }

    test('TASK 4 — lib/ ichida `profiles` INSERT/UPSERT YO\'Q', () {
      final offenders = <String>[];
      // `from` VA `db` — ilova `supabaseClient.db(...)` ga o'tdi
      // (`lib/core/network/supabase_db.dart`); ikkala shakl ham ushlanadi.
      // HAR BIR uchrash tekshiriladi: `indexOf` faqat birinchisini ko'rgani
      // uchun fayldagi keyingi INSERT jimgina o'tib ketishi mumkin edi.
      final tableRef = RegExp(r"\.(?:from|db)\('profiles'\)");
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        final src = dartCode(f.path);
        for (final match in tableRef.allMatches(src)) {
          // Chaining `db('profiles').insert(...)` / `.upsert(...)` shakli.
          final chain =
              src.substring(match.start, (match.start + 200).clamp(0, src.length));
          if (chain.contains('.insert(') || chain.contains('.upsert(')) {
            offenders.add(f.path);
          }
        }
      }
      expect(offenders, isEmpty,
          reason: 'profil FAQAT SECURITY DEFINER handle_new_user() orqali '
              'yaratilishi kerak');
    });

    test('TASK 4 — client role/is_verified yubormaydi', () {
      final model =
          dartCode('lib/features/auth/data/models/user_profile_model.dart');
      final start = model.indexOf('toUpdatePayload()');
      expect(start, isNot(-1));
      final payload = model.substring(start, model.indexOf('}', start));
      for (final privileged in [
        "'role'",
        "'is_verified'",
        "'reputation_points'",
      ]) {
        expect(payload.contains(privileged), isFalse,
            reason: '$privileged update payload`ida — DB guard uni bloklaydi');
      }
    });

    test('TASK 5 — getUserProfile sun\'iy profil QAYTARMAYDI', () {
      final ds = dartCode(
          'lib/features/auth/data/datasources/auth_remote_datasource.dart');
      // IMPLEMENTATSIYA (abstract deklaratsiya emas) — shuning uchun lastIndexOf.
      final start = ds.lastIndexOf('Future<UserProfileModel> getUserProfile(');
      final end = ds.lastIndexOf('Future<UserProfileModel> updateUserProfile');
      expect(start, isNot(-1));
      expect(end, greaterThan(start), reason: 'implementatsiya topilmadi');
      final body = ds.substring(start, end);
      expect(body.contains('throw ServerException'), isTrue,
          reason: 'profil yo\'q bo\'lsa aniq invariant xatosi qaytishi kerak');
      expect(body.contains('statusCode: 404'), isTrue);
      expect(body.contains('invarianti buzilgan'), isTrue);
      // Sun'iy profil qurish shakllari qaytmasin.
      expect(body.contains('UserProfileModel('), isFalse,
          reason: 'xotirada profil yasash 23503 ni oylab yashirgan');
    });

    test('TASK 6 — Community `_requireProfileExists` saqlangan', () {
      final ds = dartCode('lib/features/community_forum/data/datasources/'
          'community_forum_remote_datasource.dart');
      expect(ds.contains('_requireProfileExists'), isTrue);
      final start = ds.lastIndexOf('createQuestion(');
      final block = ds.substring(start);
      final guardAt = block.indexOf('_requireProfileExists(');
      final insertAt = block.indexOf("db('questions')");
      expect(guardAt, isNot(-1), reason: 'guard createQuestion ichida yo\'q');
      expect(insertAt, isNot(-1));
      expect(guardAt < insertAt, isTrue,
          reason: 'guard INSERT`dan OLDIN chaqirilishi shart');
      expect(ds.contains('ProfileMissingException'), isTrue);
    });
  });
}
