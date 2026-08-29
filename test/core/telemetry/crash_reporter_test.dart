/// CRASH SINK QULFI (§20: jim yo'qolgan xato YO'Q).
///
/// ISBOT DARAJASI (CLAIM != EVIDENCE): bu fayl KLIENT tomonini va migratsiya
/// MANBASINI qulflaydi. Serverdagi RLS'ning haqiqiy xulqi bu testlar bilan
/// ISBOTLANMAYDI — u anon kalit bilan REST probe orqali alohida o'lchangan
/// (natijalar migratsiya faylining "HOLAT QAYDI" bo'limida).
library;

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
}
