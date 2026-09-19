// LexHub — SIRQIB CHIQQAN TEST PAROLI QAYTIB KELMASIN (§8 xavfsizlik qulfi).
//
// MUAMMO (O'LCHANDI 2026-09-04): repo OMMAVIY — anonim
// `GET api.github.com/repos/PirimovUktam/LexHub` -> `visibility = public`,
// `private = false`. 12 ta live test faylida esa bitta zaif parol OCHIQ
// yozilgandi va o'sha testlar shu parol bilan REAL `auth.signUp` qilardi.
// Hisob `email_confirmed_at IS NOT NULL` bilan bazada QOLADI (`service_role`
// kaliti mahalliy muhitda YO'Q -> o'chirib bo'lmaydi), ya'ni har yugurtirish
// repo ko'rgan HAR KIMGA hamjamiyat feed'iga YOZISH huquqli hisob qoldirardi.
//
// NIMA UCHUN BU TEST KERAK: parol `test/support/live_test_password.dart` ga
// ko'chirildi va faqat `--dart-define` bilan beriladi. Lekin bu KELAJAKDA
// qaytib kelishi mumkin — kimdir "test tez ishlasin" deb qattiq yozib
// qo'yishi oson. Qulf bo'lmasa regressiya JIMGINA o'tib ketardi.
//
// DIQQAT — ATAYLAB BO'LINGAN LITERAL: qidiruv naqshi `'Password' '123!'`
// ko'rinishida yozilgan (Dart yonma-yon literal'larni birlashtiradi). Uni
// BIRLASHTIRIB YOZMANG — aks holda sir shu faylning O'ZIDA repoga qaytadi va
// test o'zini topib doim yiqiladi.
//
// CHEKLOV (halol qayd): bu STATIK manba tekshiruvi — runtime isbot EMAS. U
// faqat "sir manbada yo'q" ni ko'rsatadi. `auth.users` dagi haqiqiy holat
// alohida o'lchangan (read-only SQL, `.runtime_evidence/`).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../support/live_test_password.dart';

/// Sirqib chiqqan qiymat. IKKI QISM — yuqoridagi izohga qarang.
const String _leaked = 'Password' '123!';

/// Skanerlanadigan kataloglar. `.claude/worktrees/` ATAYLAB YO'Q: u
/// `.gitignore:33` bilan qulflangan, ya'ni GitHub'ga TUSHMAYDI, va ichida
/// eski (detached HEAD) nusxa turadi — uni tekshirish soxta yiqilish berardi.
const List<String> _scanDirs = ['lib', 'test', 'tool', 'supabase', 'docs'];

const List<String> _scanExtensions = [
  '.dart', '.py', '.ts', '.sql', '.md', '.json', '.yaml', '.sh', '.ps1',
];

/// `liveTestPassword()` ga O'TKAZILGAN fayllar. Ro'yxat QASDDAN qo'lda —
/// yangi live fayl qo'shilsa uni ham shu yerga yozish kerak.
const List<String> _mustUseHelper = [
  'test/integration/cleanup_live_test_data_test.dart',
  'test/integration/community_write_session_rls_live_test.dart',
  'test/integration/debug_signup_repro_test.dart',
  'test/integration/forensic_auth_split_diagnosis_test.dart',
  'test/integration/forensic_db_triggers_and_schema_test.dart',
  'test/integration/real_db_error_diagnostic_test.dart',
  'test/integration/real_supabase_signup_cloud_verification_test.dart',
  'test/integration/verify_community_answer_live_test.dart',
  'test/integration/verify_legal_ai_proxy_live_test.dart',
  'test/integration/verify_mvp_blockers_live_test.dart',
  'test/integration/verify_profile_invariant_live_test.dart',
  'test/integration/verify_rate_limit_error_mapping_test.dart',
];

/// Windows'da `\`, Linux'da `/` — xabar bir xil ko'rinishi uchun.
String _norm(String p) => p.split(Platform.pathSeparator).join('/');

List<File> _sourceFiles() {
  final out = <File>[];
  for (final dir in _scanDirs) {
    final d = Directory(dir);
    if (!d.existsSync()) continue;
    for (final e in d.listSync(recursive: true, followLinks: false)) {
      if (e is! File) continue;
      if (_scanExtensions.any(e.path.endsWith)) out.add(e);
    }
  }
  return out;
}

void main() {
  test('sirqib chiqqan parol MANBADA yo`q', () {
    final files = _sourceFiles();

    // ANTI-VAKUUM 1: skaner haqiqatan fayl ko'rdimi. Yo'l yoki kengaytma
    // ro'yxati buzilsa ro'yxat bo'sh bo'lib test SOXTA yashil bergan bo'lardi.
    // O'LCHANDI (2026-09-04): 449 fayl.
    expect(files.length, greaterThan(400),
        reason: 'Skaner juda kam fayl ko`rdi — yo`l/kengaytma ro`yxati buzilgan');

    // ANTI-VAKUUM 2: naqshning O'ZI ishlaydimi.
    expect('xx${_leaked}yy'.contains(_leaked), isTrue,
        reason: 'Naqsh buzilgan — qulf hech narsa tekshirmaydi');

    final hits = <String>[];
    for (final f in files) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains(_leaked)) {
          hits.add('${_norm(f.path)}:${i + 1}');
        }
      }
    }

    expect(hits, isEmpty,
        reason: 'Repo OMMAVIY. Sirqib chiqqan parol manbaga QAYTGAN: '
            '${hits.join(", ")}. Uning o`rniga `liveTestPassword()` '
            'ishlatilsin (test/support/live_test_password.dart).');
  });

  test('live testlar parolni HELPER dan oladi', () {
    for (final path in _mustUseHelper) {
      final src = File(path).readAsStringSync();
      expect(src.contains('liveTestPassword()'), isTrue,
          reason: '$path parolni `liveTestPassword()` dan olishi kerak');
      expect(src.contains("import '../support/live_test_password.dart';"),
          isTrue,
          reason: '$path da helper import`i yo`q');
    }
  });

  test('helper FAIL-CLOSED — define berilmasa ishlamaydi', () {
    // Bu STATIK tekshiruv EMAS: funksiyaning O'ZI chaqiriladi.
    if (kLiveTestPasswordRaw.isEmpty) {
      expect(liveTestPassword, throwsStateError,
          reason: 'Define yo`q — sukutdagi parol bilan JIM ishlamasligi kerak');
    } else {
      // Live yugurtirishda (`--dart-define=LEXHUB_TEST_PASSWORD=...`) qiymat
      // qaytadi va uzunlik sharti BAJARILGAN bo'lishi kerak.
      expect(liveTestPassword().length, greaterThanOrEqualTo(16));
    }
  });
}
