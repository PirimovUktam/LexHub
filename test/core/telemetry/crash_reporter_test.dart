/// CRASH SINK QULFI (§20: jim yo'qolgan xato YO'Q).
///
/// ISBOT DARAJASI (CLAIM != EVIDENCE): bu fayl KLIENT tomonini va migratsiya
/// MANBASINI qulflaydi. Serverdagi RLS'ning haqiqiy xulqi bu testlar bilan
/// ISBOTLANMAYDI — u anon kalit bilan REST probe orqali alohida o'lchangan
/// (natijalar migratsiya faylining "HOLAT QAYDI" bo'limida).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/telemetry/crash_reporter.dart';

String _squash(String path) =>
    File(path).readAsStringSync().replaceAll(RegExp(r'\s+'), ' ');

void main() {
  setUp(CrashReporter.resetForTest);

  group('1. Supabase ULANMAGAN holat', () {
    test('`report` xato TASHLAMAYDI va hech narsa yuborilmaydi', () async {
      // `attach` chaqirilmagan: `main.dart` da handler'lar
      // `Supabase.initialize` DAN OLDIN o'rnatiladi, ya'ni bu holat real.
      CrashReporter.report(
        kind: 'flutter_error',
        error: StateError('probe'),
        stack: StackTrace.current,
      );
      // fire-and-forget: mikrotask navbati bo'shashini kutamiz.
      await Future<void>.delayed(Duration.zero);
      expect(CrashReporter.sentCountForTest, 0);
    });
  });

  group('2. KLIENT SHARTNOMASI — `user_id` yuborilmaydi', () {
    test('insert payload\'ida `user_id` kaliti YO\'Q', () {
      final src = _squash('lib/core/telemetry/crash_reporter.dart');
      // `db()` — loyiha konvensiyasi (`from()` retry tsikliga tushadi),
      // `postgrest_retry_disabled_test.dart` bilan qulflangan.
      expect(src.contains("client.db('client_error_logs').insert("), isTrue);
      // Server `DEFAULT auth.uid()` qo'yadi. Klient bu ustunni yuborsa RLS
      // `WITH CHECK` uni rad etardi (soxta muallif himoyasi).
      expect(src.contains("'user_id':"), isFalse,
          reason: 'muallifni server aniqlaydi, klient EMAS');
      expect(src.contains("'created_at':"), isFalse,
          reason: 'vaqtni server `now()` bilan qo\'yadi');
    });

    test('rekursiya va chegara qulflari joyida', () {
      final src = _squash('lib/core/telemetry/crash_reporter.dart');
      expect(src.contains('if (_sending) return;'), isTrue);
      expect(src.contains('if (_sentCount >= _maxPerSession) return;'), isTrue);
      expect(src.contains('_dedupeWindow'), isTrue);
    });
  });

  group('3. `main.dart` — ikki handler ham serverga yozadi', () {
    test('`FlutterError.onError` va `PlatformDispatcher` ulangan', () {
      final src = _squash('lib/main.dart');
      expect(src.contains("kind: 'flutter_error'"), isTrue);
      expect(src.contains("kind: 'platform_error'"), isTrue);
      expect(src.contains('CrashReporter.attach(Supabase.instance.client)'),
          isTrue);
      // `attach` `initialize` DAN KEYIN bo'lishi shart, aks holda klient
      // hali yo'q va birinchi xatolar yo'qolardi.
      expect(src.indexOf('CrashReporter.attach'),
          greaterThan(src.indexOf('await Supabase.initialize(')));
    });
  });

  group('4. MIGRATSIYA MANBASI — xavfsizlik modeli qulfi', () {
    const path = 'supabase/migrations/20260830010000_client_error_logs.sql';

    test('INSERT `auth.uid()` ga bog\'langan, SELECT faqat xodimga', () {
      final src = _squash(path);
      expect(
          src.contains('WITH CHECK (user_id IS NOT DISTINCT FROM auth.uid())'),
          isTrue);
      expect(src.contains('USING (public.is_admin_or_moderator())'), isTrue);
      expect(src.contains('user_id UUID DEFAULT auth.uid()'), isTrue);
    });

    test('UPDATE/DELETE policy YO\'Q (audit izi o\'zgarmaydi)', () {
      final src = _squash(path);
      expect(src.contains('FOR UPDATE'), isFalse);
      expect(src.contains('FOR DELETE'), isFalse);
      // Qo'llash paytida ishlaydigan o'z-o'zini tekshiruv shu qoidani
      // bazada ham qulflaydi.
      expect(src.contains("cmd IN ('UPDATE', 'DELETE', 'ALL')"), isTrue);
    });

    test('tezlik chegarasi `SECURITY DEFINER` (aks holda JIM ishlamaydi)', () {
      final src = _squash(path);
      expect(
          src.contains(
              'CREATE OR REPLACE FUNCTION public.client_error_logs_sanitize() '
              'RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER'),
          isTrue);
      expect(src.contains("USING ERRCODE = 'LX429'"), isTrue);
      expect(src.contains('GRANT INSERT ON public.client_error_logs TO anon, '
          'authenticated;'), isTrue);
      // Klientga SELECT huquqi berilmaydi.
      expect(src.contains('GRANT SELECT ON public.client_error_logs TO anon'),
          isFalse);
    });
  });

  group('5. MAZMUN TOZALASH — PII/sir serverga TUSHMAYDI', () {
    // O'LCHANGAN ZANJIR (manba tahlili, 2026-09-02):
    //   `legal_assistant_local_datasource.dart:38` buzuq keshni
    //   `jsonDecode(raw)` bilan o'qiydi — `raw` FOYDALANUVCHINING huquqiy
    //   savoli. Dart SDK `FormatException.toString()` ichiga MANBA MATNINING
    //   offset atrofidagi bo'lagini + karet satrini QO'SHADI, :46 esa uni
    //   `CacheException(message: "...: $e")` bilan o'raydi. Tutilmagan holatda
    //   bu matn `client_error_logs.message` ga tushardi va UNI KEYIN
    //   O'CHIRISH MUMKIN EMAS (UPDATE policy ataylab yo'q).
    const userQuestion = "Ish beruvchi ish haqimni to'lamadi, sudga beraman";
    const corruptCache = '{"savol": "$userQuestion" X}';

    String wrappedCacheError() {
      try {
        jsonDecode(corruptCache);
      } on FormatException catch (e) {
        // `legal_assistant_local_datasource.dart:46` AYNAN shunday o'raydi.
        return 'CacheException: Saqlangan keyslarni yuklashda xatolik: $e';
      }
      fail('`corruptCache` HAQIQATAN buzuq JSON bo\'lishi kerak');
    }

    test('XOM matn foydalanuvchi savolini HAQIQATAN olib keladi (leak isboti)',
        () {
      final raw = wrappedCacheError();
      // Bu tekshiruv NUQSONNI qayd etadi: agar Dart SDK bir kun manba
      // derazasini qo'shmay qo'ysa, quyidagi tozalash testi VAKUUM bo'lib
      // qolardi — shuning uchun leak MAVJUDLIGI ham qulflanadi.
      expect(raw.contains(userQuestion), isTrue,
          reason: 'SDK shakli o\'zgardi — tozalash naqshi qayta o\'lchansin');
      expect(raw.contains('^'), isTrue, reason: 'karet satri kutilgan');
    });

    test('tozalangan matnda foydalanuvchi savoli QOLMAYDI', () {
      final scrubbed = CrashReporter.scrubForTest(wrappedCacheError());

      expect(scrubbed.contains(userQuestion), isFalse,
          reason: 'huquqiy savol `client_error_logs` ga tushmasligi kerak');
      expect(scrubbed.contains('sudga beraman'), isFalse);
      expect(scrubbed, contains('[manba yashirildi]'));
      // DIAGNOSTIKA YO'QOLMAYDI: sabab va tur saqlanadi.
      expect(scrubbed, contains('FormatException'));
      expect(scrubbed, contains('CacheException'));
    });

    test('STACK TRACE TEGILMAYDI — diagnostika qiymati yo\'qolmaydi', () {
      // Dart stack trace'ida QIYMAT yo'q (faqat simvol/fayl/satr), ya'ni
      // maskalanadigan narsa ham yo'q. Bu POL tekshiruvi: haddan tashqari
      // tozalash crash sink'ining butun ma'nosini yo'qotardi.
      const stack =
          '#0      _CustomZone.handleUncaughtError (dart:async/zone.dart:1381:19)\n'
          '#1      Future._propagateToListeners (dart:async/future_impl.dart:809:32)\n'
          '#2      CommunityForumRemoteDataSourceImpl.voteAnswer '
          '(package:lexhub/features/community_forum/data/datasources/'
          'community_forum_remote_datasource.dart:512:7)\n';
      expect(CrashReporter.scrubForTest(stack), stack);
    });

    test('sirlar (token param / Bearer / JWT / kalit) MASKALANADI', () {
      const jwt = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
          'eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0TH';
      final scrubbed = CrashReporter.scrubForTest(
        'AuthApiException: 401 https://x.supabase.co/auth/v1/user'
        '?access_token=$jwt apikey=sb_publishable_AbCdEf12345 '
        'Authorization: Bearer $jwt AIzaSyA1234567890abcdefghijklmnopqrst',
      );

      expect(scrubbed.contains(jwt), isFalse, reason: 'sessiya token\'i');
      expect(scrubbed.contains('sb_publishable_'), isFalse);
      expect(scrubbed.contains('AIzaSy'), isFalse);
      expect(scrubbed, contains('[sir yashirildi]'));
      // Xatoning O'ZI saqlanadi — nima yiqilgani ko'rinadi.
      expect(scrubbed, contains('AuthApiException'));
    });

    test('PII (email / telefon / ism) MASKALANADI', () {
      // `PostgrestException` `details` maydonida Postgres BUZILGAN QIYMATNI
      // qaytaradi (`Key (email)=(...)`) — ya'ni PII xato matni ichida keladi.
      final scrubbed = CrashReporter.scrubForTest(
        'PostgrestException(message: duplicate key value violates unique '
        'constraint, details: Key (email)=(aziz.karimov@mail.uz) already '
        'exists; foydalanuvchi Aziz Karimov, tel +998901234567)',
      );

      expect(scrubbed.contains('aziz.karimov@mail.uz'), isFalse);
      expect(scrubbed.contains('998901234567'), isFalse);
      expect(scrubbed.contains('Aziz Karimov'), isFalse);
      expect(scrubbed, contains('PostgrestException'));
    });

    test('maska matnni UZAYTIRSA ham server chegarasi buzilmaydi', () {
      // `+998901234567` (13) -> `[Telefon yashirildi]` (20): tozalash matnni
      // O'STIRADI, server CHECK'i esa qat'iy — shu sababli kesish tozalashdan
      // KEYIN ham qo'yiladi.
      final long = List.filled(40, '+998901234567').join(' ');
      final scrubbed = CrashReporter.scrubForTest(long, max: 200);
      expect(scrubbed.length, lessThanOrEqualTo(200));
      expect(scrubbed.contains('998901234567'), isFalse);
    });

    test('uch matn maydoni HAM `_scrub` dan o\'tadi (payload qulfi)', () {
      final src = _squash('lib/core/telemetry/crash_reporter.dart');
      expect(src,
          contains('final message = _scrub(error.toString(), _maxMessageChars);'));
      expect(
          src,
          contains("'stack': stack == null ? null : "
              '_scrub(stack.toString(), _maxStackChars),'));
      expect(src, contains("'context': context == null ? null : _scrub(context, 200),"));
      // XOM matn payload'ga to'g'ridan-to'g'ri TUSHMASLIGI kerak.
      expect(src.contains("'message': error.toString()"), isFalse);
      expect(src.contains('_clip(error.toString()'), isFalse);
      expect(src.contains('_clip(stack.toString()'), isFalse);
    });
  });
}
