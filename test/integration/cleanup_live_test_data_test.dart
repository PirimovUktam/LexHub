import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/config/supabase_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/live_gate.dart';
/// §18 TEST DATA CLEANUP — live write testlardan keyin production'ni tozalash.
///
/// Live testlar production'da haqiqiy qatorlar yaratadi. Ularni qoldirib
/// ketish ikki sababdan xato: (1) hamjamiyat feed'ida begona "probe" savollari
/// ko'rinadi, (2) keyingi auditda bu qatorlar haqiqiy foydalanuvchi ma'lumoti
/// bilan aralashib ketadi.
///
/// USUL: har bir probe user o'z hisobiga KIRADI va O'Z qatorlarini o'chiradi.
/// Ya'ni bu tozalash RLS'ni chetlab o'tmaydi — aksincha, "owner o'z ma'lumotini
/// o'chira oladi" qoidasini ham TEKSHIRADI.
///
/// CHEKLOV (halol qayd): `auth.users` qatorini o'chirish uchun `service_role`
/// kaliti kerak. `env/prod.json` ichida u YO'Q (va bo'lmasligi ham kerak).
/// Shuning uchun probe user'larning O'ZI production'da qoladi — bu BLOCKED
/// holat, quyida ro'yxati chiqariladi.
///
/// Ishga tushirish:
///   flutter test test/integration/cleanup_live_test_data_test.dart \
///     --dart-define-from-file=env/prod.json \
///     --dart-define=LEXHUB_LIVE_WRITE_TESTS=true
const bool _enabled =
    bool.fromEnvironment('LEXHUB_LIVE_WRITE_TESTS', defaultValue: false);

/// Live testlar yaratgan probe hisoblar. Parol testlardagi bilan bir xil.
const List<String> _probeEmails = [
  'invariant_probe_1787428875317@lexhub.uz',
  'answer_probe_1787428900824@lexhub.uz',
  'answer_probe_1787389699140@lexhub.uz',
];
const String _probePassword = 'Password123!';

void main() {
  // P2 test konfiguratsiyasi: bu fayl REAL Supabase Cloud'ga ulanadi.
  // `--dart-define=LEXHUB_LIVE_WRITE_TESTS=true` bo'lmasa OSHKORA skip.
  if (!liveSuiteEnabled('cleanup_live_test_data')) return;

  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null; // real tarmoq

  setUpAll(() async {
    if (!_enabled) return;
    SharedPreferences.setMockInitialValues({});
    await SupabaseConfig.init();
    expect(SupabaseConfig.isConfigured, isTrue,
        reason: 'BLOCKED: --dart-define-from-file=env/prod.json berilmagan');
    await Supabase.initialize(
      url: SupabaseConfig.url,
      // ignore: deprecated_member_use
      anonKey: SupabaseConfig.anonKey,
    );
  });

  test('§18: live write test data production`dan o`chiriladi', () async {
    if (!_enabled) {
      stdout.writeln(
          'O`TKAZIB YUBORILDI: --dart-define=LEXHUB_LIVE_WRITE_TESTS=true kerak');
      return;
    }

    final client = Supabase.instance.client;
    var deletedAnswers = 0;
    var deletedQuestions = 0;
    final orphanUsers = <String>[];
    final failed = <String>[];
    final rlsDeleteBlocked = <String>[];

    for (final email in _probeEmails) {
      try {
        await client.auth.signOut();
        final res = await client.auth.signInWithPassword(
          email: email,
          password: _probePassword,
        );
        final uid = res.user?.id;
        if (uid == null) {
          failed.add('$email — kirish muvaffaqiyatsiz (user null)');
          continue;
        }

        // 1) O'z javoblari
        final ans = await client
            .from('answers')
            .delete()
            .eq('user_id', uid)
            .select('id');
        deletedAnswers += (ans as List).length;

        // 2) O'z savollariga kelgan javoblar (boshqa probe yozgan bo'lishi mumkin)
        final myQ = await client.from('questions').select('id').eq('user_id', uid);
        for (final q in (myQ as List)) {
          final qid = (q as Map)['id'] as String;
          final childAns = await client
              .from('answers')
              .delete()
              .eq('question_id', qid)
              .select('id');
          deletedAnswers += (childAns as List).length;
        }

        // 3) O'z savollari
        final qs = await client
            .from('questions')
            .delete()
            .eq('user_id', uid)
            .select('id');
        deletedQuestions += (qs as List).length;

        // ISBOT: qatorlar KO'RINADI, lekin O'CHMAYDI.
        // DELETE 0 qator qaytarishining ikki sababi bo'lishi mumkin:
        //   (a) qator yo'q, (b) RLS DELETE policy yo'q (PostgREST xato
        //       QAYTARMAYDI — shunchaki 0 qator ta'sir qiladi).
        // Farqni ajratish uchun DELETE'dan KEYIN SELECT qilamiz: agar qator
        // hali ham ko'rinsa — bu (b), ya'ni egasi o'z ma'lumotini o'chira
        // OLMAYDI. Bu §8 "data subject rights" bo'yicha alohida topilma.
        final stillThere =
            await client.from('questions').select('id').eq('user_id', uid);
        final visibleAfterDelete = (stillThere as List).length;
        if (visibleAfterDelete > 0) {
          rlsDeleteBlocked.add(
              '${email.split("@").first}: DELETE 0 qator, lekin SELECT $visibleAfterDelete qator ko`radi');
        }

        // 4) auth.users — service_role kerak, shuning uchun qoladi
        orphanUsers.add('${uid.substring(0, 8)}…${uid.substring(uid.length - 4)}');
      } catch (e) {
        failed.add('$email — $e');
      }
    }
    await client.auth.signOut();

    stdout.writeln('TOZALASH — o`chirilgan javoblar: $deletedAnswers');
    stdout.writeln('TOZALASH — o`chirilgan savollar: $deletedQuestions');
    stdout.writeln(
        'BLOCKED — auth.users qatorlari qoldi (service_role yo`q): ${orphanUsers.join(", ")}');
    if (failed.isNotEmpty) {
      stdout.writeln('DIQQAT — tozalanmagan hisoblar:');
      for (final f in failed) {
        stdout.writeln('  * $f');
      }
    }

    // Tekshiruv: feed'da "probe" savollari qolmadimi.
    final feed = await client
        .from('questions')
        .select('id,title')
        .ilike('title', '%probe%')
        .limit(20);
    final leftovers = (feed as List)
        .map((e) => (e as Map)['title'] as String? ?? '')
        .toList();
    stdout.writeln(
        'TEKSHIRUV — sarlavhasida "probe" bor savollar: ${leftovers.length}');
    for (final t in leftovers) {
      stdout.writeln('  ! qoldi: $t');
    }

    expect(failed, isEmpty, reason: 'Har bir probe hisob tozalanishi kerak');

    if (rlsDeleteBlocked.isNotEmpty) {
      stdout.writeln(
          'TOPILMA (P1) — egasi O`Z savolini o`chira OLMAYDI (RLS DELETE policy yo`q):');
      for (final r in rlsDeleteBlocked) {
        stdout.writeln('  * $r');
      }
      stdout.writeln(
          'NATIJA: §18 test data cleanup client tomondan BAJARILMAYDI. '
          'Tozalash faqat Supabase SQL Editor (service_role) orqali mumkin:');
      stdout.writeln(
          "  delete from public.answers where question_id in (select id from public.questions where title ilike '%probe%');");
      stdout.writeln(
          "  delete from public.questions where title ilike '%probe%';");
      stdout.writeln(
          "  delete from auth.users where email like '%_probe_%@lexhub.uz';");
    }

    // Bu yerda `expect(leftovers, isEmpty)` QO'YILMAYDI: yuqoridagi isbotga
    // ko'ra o'chirish client huquqidan tashqarida. Yolg'on FAIL emas, aniq
    // BLOCKED holat qayd etiladi (CLAIM ≠ EVIDENCE).
    expect(leftovers.isEmpty || rlsDeleteBlocked.isNotEmpty, isTrue,
        reason: 'Yoki tozalandi, yoki RLS sababi ISBOTLANGAN bo`lishi kerak');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
