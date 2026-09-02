/// QAYTA TOPSHIRISH SOVUTISH DAVRI + MODERATSIYA GVARDI KONTEKSTI — QULF.
///
/// Asos: `supabase/migrations/20260829130000_expert_moderation_guard_fix_and_
/// apply_cooldown.sql`.
///
/// UCH INVARIANT QULFLANADI:
///   A. `protect_expert_profile_sensitive_fields()` `SECURITY INVOKER` bo'lib
///      qoladi va chaqiruvchini `is_privileged_db_role()` bilan ajratadi.
///      `SECURITY DEFINER` ga qaytsa `current_user` DOIM funksiya egasi
///      bo'ladi va gvard chaqiruvchini AJRATMAY qoladi — bu holda yoki
///      moderatsiya buziladi, yoki klient himoyasi o'chadi.
///   B. Gvard `rejected_at` o'zgarishini bloklaydi. Bu qator bo'lmasa rad
///      etilgan foydalanuvchi `PATCH /rest/v1/expert_profiles` bilan
///      `rejected_at = null` yozib sovutish davrini CHETLAB O'TADI
///      (`"Experts can update their profile"` policy'si owner UPDATE'ga
///      ruxsat beradi).
///   C. `apply_for_expert_verification()` sovutish davrini `rejected_at`
///      bo'yicha tekshiradi va `LX429` SQLSTATE bilan yiqiladi; klient shu
///      kodni HTTP 423 ga o'giradi.
///
/// ISBOT DARAJASI (CLAIM != EVIDENCE): bu fayl SQL va Dart MANBASINI
/// o'qiydi — SERVER KONTRAKTI invarianti. Migratsiya real Cloud'da
/// QO'LLANGANINI va gvard runtime'da ishlashini U ISBOTLAMAYDI; buning
/// uchun migratsiya faylining 5-bo'limidagi tekshiruvlar kerak.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/errors/error_handler.dart';
import 'package:lexhub/core/errors/exceptions.dart';
import 'package:lexhub/core/errors/failure_code.dart';

String _sqlCode(String path) {
  final kept = <String>[];
  for (final line in File(path).readAsLinesSync()) {
    var text = line;
    final dash = text.indexOf('--');
    if (dash >= 0) text = text.substring(0, dash);
    if (text.trim().isNotEmpty) kept.add(text);
  }
  return kept.join('\n');
}

String _flat(String source) => source.replaceAll(RegExp(r'\s+'), ' ');

/// `needle` ni o'z ichiga olgan ENG OXIRGI migratsiya (fayl nomi bo'yicha).
/// `CREATE OR REPLACE` obyektni qayta yozadi — eski faylni o'qish tarixni
/// tekshirardi, hozirgi holatni EMAS.
String _latestMigrationWith(String needle) {
  final files = Directory('supabase/migrations')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.sql'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  String? found;
  for (final file in files) {
    final flat = _flat(_sqlCode(file.path));
    if (flat.contains(needle)) found = flat;
  }
  if (found == null) fail('Hech bir migratsiyada topilmadi: $needle');
  return found;
}

void main() {
  late String guardFn;
  late String applyFn;

  setUpAll(() {
    guardFn = _latestMigrationWith('CREATE OR REPLACE FUNCTION '
        'public.protect_expert_profile_sensitive_fields()');
    applyFn = _latestMigrationWith(
        'CREATE OR REPLACE FUNCTION public.apply_for_expert_verification(');
  });

  group('A. gvard chaqiruvchini AJRATADI', () {
    test('gvard `SECURITY INVOKER`', () {
      final start = guardFn.indexOf('CREATE OR REPLACE FUNCTION '
          'public.protect_expert_profile_sensitive_fields()');
      final head = guardFn.substring(start, start + 400);
      expect(head.contains('SECURITY INVOKER'), isTrue,
          reason: 'INVOKER bo\'lmasa `current_user` = funksiya EGASI va gvard '
              'klient bilan RPC ni ajratmaydi');
      expect(head.contains('SECURITY DEFINER'), isFalse);
    });

    test('chaqiruvchi `is_privileged_db_role()` bilan aniqlanadi', () {
      expect(guardFn.contains('NOT public.is_privileged_db_role()'), isTrue);
      // O'LIK PREDIKAT QAYTMASIN: `SECURITY INVOKER` da ham, DEFINER da ham
      // bu shart chaqiruvchini ajratmaydi (`profiles` gvardida 2026-08-27 da
      // ayni sabab bilan olib tashlangan).
      expect(guardFn.contains("current_user != 'service_role'"), isFalse);
    });
  });

  group('B. `rejected_at` FAQAT moderatsiya yo\'lidan yoziladi', () {
    test('gvard `rejected_at` o\'zgarishini bloklaydi', () {
      expect(
          guardFn.contains('NEW.rejected_at IS DISTINCT FROM OLD.rejected_at'),
          isTrue,
          reason: 'rad etilgan foydalanuvchi `PATCH` bilan o\'zini yana '
              'kutayotganlar ro\'yxatiga qo\'shib oladi');
      expect(guardFn.contains('Rejection state is managed by administrators'),
          isTrue);
    });

    test('mavjud besh gvard SAQLANGAN (regressiya)', () {
      for (final needle in <String>[
        'NEW.rating IS DISTINCT FROM OLD.rating',
        'NEW.reviews_count IS DISTINCT FROM OLD.reviews_count',
        'NEW.verified_at IS DISTINCT FROM OLD.verified_at',
        'NEW.user_id IS DISTINCT FROM OLD.user_id',
        'NEW.license_number IS DISTINCT FROM OLD.license_number',
      ]) {
        expect(guardFn.contains(needle), isTrue, reason: 'gvard tushdi: $needle');
      }
    });
  });

  group('C. SOVUTISH DAVRI', () {
    test('`rejected_at` bo\'yicha tekshiriladi va INSERT dan OLDIN turadi', () {
      expect(applyFn.contains('v_cooldown CONSTANT INTERVAL'), isTrue);
      expect(
          applyFn.contains(
              'IF v_rejected_at IS NOT NULL AND v_rejected_at > now() - v_cooldown THEN'),
          isTrue,
          reason: 'sovutish sharti o\'zgargan — cheksiz qayta topshirish '
              'qaytdi');
      final guardIdx = applyFn.indexOf('v_rejected_at > now() - v_cooldown');
      final insertIdx = applyFn.indexOf('INSERT INTO public.expert_profiles');
      expect(guardIdx, lessThan(insertIdx),
          reason: 'tekshiruv INSERT dan KEYIN bo\'lsa ariza baribir yoziladi');
    });

    test('mashina o\'qiy oladigan `LX429` kodi beriladi', () {
      expect(applyFn.contains("USING ERRCODE = 'LX429'"), isTrue,
          reason: 'klient xato MATNI bo\'yicha taxmin qilishga majbur bo\'ladi');
    });

    test('klient `LX429` ni 423 ga o\'giradi (matn bo\'yicha EMAS)', () {
      final src = _sqlCode('lib/features/legal_experts/data/datasources/'
          'legal_experts_remote_datasource.dart');
      final flat = _flat(src);
      expect(flat.contains("e.code == 'LX429'"), isTrue);
      expect(flat.contains('statusCode: 423'), isTrue);
    });

    test('423 -> `FailureCode.applicationCooldown`', () {
      // `rateLimited` EMAS: `errorRateLimited` matni "bir necha daqiqadan
      // keyin" deydi, sovutish davri esa 24 soat.
      final failure = ErrorHandler.handle(
        const ServerException(message: 'Ariza rad etilgan.', statusCode: 423),
      );
      expect(failure.code, FailureCode.applicationCooldown);
      expect(failure.message, 'Ariza rad etilgan.');
    });
  });
}
