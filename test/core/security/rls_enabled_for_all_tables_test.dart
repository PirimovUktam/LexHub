// LEXHUB — REPO-MIQYOSIDA RLS QOPLAMASI (statik kontrakt).
//
// BU DEPLOYMENT ISBOTI EMAS. Bu test `supabase/migrations/*.sql` MATNINI
// o'qiydi, jonli bazaga ULANMAYDI. Ya'ni u "repo shu himoyani BUYURADI"
// deganini isbotlaydi, "production'da himoya BOR" deganini ISBOTLAMAYDI.
// Jonli isbot: `test/integration/private_tables_anon_isolation_live_test.dart`
// (anon kalit bilan har bir maxfiy jadvaldan NOL qator ko'rinishini o'lchaydi).
//
// NIMA UCHUN BU FAYL BOR: 2026-08-30 auditida MIGRATSIYALARDA TO'RT jadvalda
// RLS hech qachon yoqilmagani topildi (`bookmarks`, `question_categories`,
// `question_tags`, `question_tag_mappings`). Ular alohida-alohida testlarda
// ham, migration review'ida ham e'tibordan chetda qolgan edi, chunki hech kim
// "BARCHA jadval" bo'yicha savol bermagan. Supabase `public` sxemada `anon`/
// `authenticated` ga sukut bo'yicha to'liq huquq beradi — ya'ni RLS'siz
// jadval o'qishga VA yozishga ochiq. Tuzatish:
// `20260830100000_rls_never_enabled_tables.sql`.
//
// DIQQAT — QAMROV MIGRATSIYALAR BILAN CHEKLANGAN: `supabase/schema.sql`
// to'rttasida ham RLS ni yoqadi (`:822-833`), lekin `question_tags` va
// `question_tag_mappings` uchun POLICY bermaydi — ya'ni `schema.sql`
// qo'llangan bazada bu ikki jadval DENY-ALL bo'ladi (o'lchandi 2026-08-30).
// Shu sababli tuzatish migratsiyasi ikki xil bazada ikki xil ish qiladi:
// himoyani yoqadi YOKI buzilgan o'qishni tiklaydi. Jonli holat NOT VERIFIED.
//
// IKKI QISM:
//   A. INVARIANT — `CREATE TABLE public.X` bo'lgan HAR BIR jadvalda
//      `ENABLE ROW LEVEL SECURITY` VA kamida bitta `CREATE POLICY` bor.
//      Ikkinchi shart muhim: RLS yoqilib policy berilmasa jadval DENY-ALL
//      bo'ladi va himoya nomidan feature buziladi.
//   B. Tuzatish migration'ining o'z kontrakti (uni "soddalashtirib"
//      himoyani jimgina yo'q qilib qo'yishning oldini oladi).
//
// CARVE-OUT RO'YXATI ATAYLAB YO'Q: 2026-08-30 da o'lchangan holat — 21
// jadval, 21 tasida RLS va policy bor. Kelajakda istisno KERAK bo'lsa, u
// SABABI bilan yozilishi shart (masalan faqat `SECURITY DEFINER` funksiya
// tegadigan ichki jadval va `REVOKE ... FROM anon, authenticated`).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _createTable = RegExp(
    r'create\s+table\s+(?:if\s+not\s+exists\s+)?(?:public\.)?([a-z_0-9]+)',
    caseSensitive: false);

final _enableRls = RegExp(
    r'alter\s+table\s+(?:if\s+exists\s+)?(?:public\.)?([a-z_0-9]+)'
    r'\s+enable\s+row\s+level\s+security',
    caseSensitive: false);

final _createPolicy = RegExp(
    r'create\s+policy\s+"[^"]+"\s*on\s+(?:public\.)?([a-z_0-9]+)',
    caseSensitive: false);

/// `--` izoh qatorlarini TASHLAB kodni qaytaradi. Izohda ataylab "yo'q",
/// "noto'g'ri", "ilgari shunday edi" qiymatlari eslatiladi — tekshiruv
/// KODDA bo'lishi kerak, izohda emas.
String _codeOf(String sql) => sql
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('--'))
    .join('\n');

/// `CREATE POLICY ...;` gaplarini JADVAL bo'yicha guruhlaydi.
///
/// `;` bo'yicha bo'lish shu faylda xavfsiz: `CREATE POLICY` bironta `DO`
/// bloki ichida yo'q. Regexp bilan "boshidan oxiriga" izlash XATO bo'lardi —
/// non-greedy moslik bir jadvalning `CREATE POLICY` sidan BOSHQA jadvalning
/// `ON public.X` iga cho'zilib, tekshiruvni ma'nosiz qilardi.
Map<String, List<String>> _policiesByTable(String code) {
  final out = <String, List<String>>{};
  for (final stmt in code.split(';')) {
    final m = _createPolicy.firstMatch(stmt);
    if (m == null) continue;
    out.putIfAbsent(m.group(1)!.toLowerCase(), () => <String>[]).add(stmt);
  }
  return out;
}

void main() {
  const dirPath = 'supabase/migrations';
  const fixPath =
      '$dirPath/20260830100000_rls_never_enabled_tables.sql';

  /// jadval -> uni YARATGAN fayl.
  final created = <String, String>{};
  final rlsEnabled = <String>{};
  final policyCount = <String, int>{};
  late List<String> files;

  setUpAll(() {
    final dir = Directory(dirPath);
    expect(dir.existsSync(), isTrue,
        reason: '`$dirPath` topilmadi — test paket ildizidan ishga '
            'tushirilishi kerak.');
    files = dir
        .listSync()
        .whereType<File>()
        .map((f) => f.path.replaceAll('\\', '/'))
        .where((p) => p.endsWith('.sql'))
        .toList()
      ..sort();

    for (final path in files) {
      final code = _codeOf(File(path).readAsStringSync());
      for (final m in _createTable.allMatches(code)) {
        created.putIfAbsent(m.group(1)!.toLowerCase(), () => path);
      }
      for (final m in _enableRls.allMatches(code)) {
        rlsEnabled.add(m.group(1)!.toLowerCase());
      }
      for (final m in _createPolicy.allMatches(code)) {
        final t = m.group(1)!.toLowerCase();
        policyCount[t] = (policyCount[t] ?? 0) + 1;
      }
    }
  });

  group('A. INVARIANT — har bir jadvalda RLS va policy', () {
    test('skaner haqiqatan topdi (bo\'sh o\'tish IMKONSIZ)', () {
      // Eng xavfli yiqilish usuli: regexp buzilib HECH NARSA topmasligi va
      // testning JIM yashil bo'lishi. Shu sababli sonlar ham qulflangan.
      expect(files.length, greaterThanOrEqualTo(30),
          reason: 'o\'lchangan 2026-08-30: 30 migration fayli');
      expect(created.length, greaterThanOrEqualTo(21),
          reason: 'o\'lchangan 2026-08-30: 21 jadval. KAMAYSA — skaner '
              'buzildi yoki jadval o\'chirildi (ikkisi ham tekshirilsin).');
      expect(rlsEnabled.length, greaterThanOrEqualTo(21));
    });

    test('`ENABLE ROW LEVEL SECURITY` YO\'Q jadval qolmadi', () {
      final missing = created.entries
          .where((e) => !rlsEnabled.contains(e.key))
          .map((e) => '${e.key}  (${e.value})')
          .toList()
        ..sort();
      expect(missing, isEmpty,
          reason: 'Bu jadvallar RLS\'siz — Supabase sukut huquqlari bilan '
              'ular mehmon uchun O\'QISHGA VA YOZISHGA ochiq:\n'
              '${missing.join('\n')}');
    });

    test('RLS yoqilib POLICY berilmagan jadval YO\'Q (DENY-ALL tuzoqi)', () {
      final noPolicy = created.keys
          .where((t) => rlsEnabled.contains(t) && (policyCount[t] ?? 0) == 0)
          .toList()
        ..sort();
      expect(noPolicy, isEmpty,
          reason: 'RLS yoqilgan, lekin bironta policy yo\'q. PostgreSQL '
              'bunday jadvalni DENY-ALL qiladi: himoya nomidan feature '
              'buziladi (ochiq ma\'lumotnoma o\'qilmay qoladi):\n'
              '${noPolicy.join('\n')}');
    });

    test('policy YARATILGAN jadval haqiqatan MAVJUD', () {
      // Xato yozilgan jadval nomiga policy yozilsa migration yiqiladi, lekin
      // `IF EXISTS` shoxlarida JIM o'tib ketishi mumkin.
      final ghosts = policyCount.keys
          .where((t) => !created.containsKey(t))
          .toList()
        ..sort();
      expect(ghosts, isEmpty,
          reason: 'Bu nomlar uchun policy bor, `CREATE TABLE` esa yo\'q — '
              'nom xato yozilgan yoki jadval boshqa joyda yaratilgan:\n'
              '${ghosts.join('\n')}');
    });

    test('2026-08-30 da topilgan TO\'RT jadval qoplamaga KIRDI', () {
      for (final t in const [
        'bookmarks',
        'question_categories',
        'question_tags',
        'question_tag_mappings',
      ]) {
        expect(created.containsKey(t), isTrue, reason: t);
        expect(rlsEnabled.contains(t), isTrue,
            reason: '$t: RLS yana o\'chirib qo\'yildi.');
        expect(policyCount[t] ?? 0, greaterThan(0), reason: t);
      }
    });
  });

  group('B. tuzatish migration\'ining kontrakti', () {
    late String sql;
    late String code;
    late Map<String, List<String>> byTable;

    setUpAll(() {
      final file = File(fixPath);
      expect(file.existsSync(), isTrue, reason: 'topilmadi: $fixPath');
      sql = file.readAsStringSync();
      code = _codeOf(sql);
      byTable = _policiesByTable(code);
    });

    test('transaction-safe', () {
      expect(code, contains('BEGIN;'));
      expect(code, contains('COMMIT;'));
    });

    test('to\'rt jadvalda ham RLS YOQILADI', () {
      for (final t in const [
        'bookmarks',
        'question_categories',
        'question_tags',
        'question_tag_mappings',
      ]) {
        expect(code,
            contains('ALTER TABLE public.$t ENABLE ROW LEVEL SECURITY'),
            reason: t);
      }
    });

    test('`bookmarks` — cheklovsiz policy YO\'Q, faqat EGASI', () {
      final policies = byTable['bookmarks'] ?? const <String>[];
      expect(policies.length, 3,
          reason: 'SELECT/INSERT/DELETE kutilgan, o\'lchangan: '
              '${policies.length}');
      for (final p in policies) {
        expect(p.replaceAll(RegExp(r'\s+'), ' '),
            isNot(contains('USING (true)')),
            reason: 'Shaxsiy xatcho\'plarga cheklovsiz policy: $p');
        expect(p, contains('auth.uid() = user_id'));
      }
    });

    test('`bookmarks` UPDATE policy\'si ATAYLAB yo\'q (= DENY)', () {
      expect(code.replaceAll(RegExp(r'\s+'), ' '),
          isNot(contains('ON public.bookmarks FOR UPDATE')),
          reason: 'Xatcho\'p yaratiladi va o\'chiriladi, TAHRIRLANMAYDI.');
    });

    test('ochiq ma\'lumotnomalarda O\'QISH saqlanadi, YOZISH admin\'da', () {
      for (final t in const [
        'question_categories',
        'question_tags',
        'question_tag_mappings',
      ]) {
        final flat = (byTable[t] ?? const <String>[])
            .map((p) => p.replaceAll(RegExp(r'\s+'), ' '))
            .toList();
        expect(flat.length, 2, reason: '$t: SELECT + ALL kutilgan: $flat');
        expect(flat.any((p) => p.contains('FOR SELECT USING (true)')), isTrue,
            reason: '$t: cheklovsiz SELECT policy YO\'Q — RLS yoqilgani '
                'ochiq ma\'lumotnomani O\'QILMAS qiladi (feature buziladi).');
        expect(
            flat.any((p) =>
                p.contains('FOR ALL') &&
                p.contains('USING (public.is_admin_or_moderator())') &&
                p.contains('WITH CHECK (public.is_admin_or_moderator())')),
            isTrue,
            reason: '$t: yozish himoyasi YO\'Q. Mehmon kategoriyani '
                'o\'chirsa `ON DELETE SET NULL` haqiqiy savollarning '
                '`category_id` sini NULL qiladi.');
      }
      // Loyihada `public.is_admin(uuid)` YO'Q — adashib ishlatilmasin.
      expect(code, isNot(contains('is_admin(')));
    });

    test('OLDIN va KEYIN o\'lchov gate\'lari bor (jim o\'tish yo\'q)', () {
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
      expect(code, contains('relrowsecurity'));
      expect(code, contains('FROM pg_policies'));
      // D3/D4 nomga emas, PREDIKATGA tayanadi.
      expect(code, contains("btrim(lower(qual)) = 'true'"));
      expect(code, contains('to_regprocedure'));
    });

    test('idempotent: har bir `CREATE POLICY` uchun `DROP POLICY IF EXISTS`',
        () {
      final creates =
          RegExp('CREATE POLICY', caseSensitive: false).allMatches(code).length;
      final drops = RegExp('DROP POLICY IF EXISTS', caseSensitive: false)
          .allMatches(code)
          .length;
      expect(creates, 9,
          reason: 'bookmarks 3 + har bir ma\'lumotnomada 2 = 9. '
              'O\'lchangan: $creates');
      expect(drops, creates,
          reason: 'Migration ikkinchi marta qo\'llansa `42710` bilan '
              'yiqiladi (policy allaqachon bor).');
    });

    test('NOTICE ko\'rinmasligi hisobga olingan — COMMIT\'dan keyin SELECT',
        () {
      final commit = code.indexOf('COMMIT;');
      expect(commit, greaterThan(0));
      final after = code.substring(commit);
      expect(after, contains('SELECT'),
          reason: 'Supabase SQL Editor `RAISE NOTICE` ni ko\'rsatmaydi '
              '(219545f) — natija COMMIT\'dan keyin JADVAL bo\'lib '
              'qaytarilishi kerak.');
      expect(after, contains('relrowsecurity'));
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
      ]) {
        expect(upper, isNot(contains(banned)), reason: '$banned taqiqlangan');
      }
    });

    test('sir YO\'Q', () {
      expect(sql, isNot(contains('sb_secret_')));
      expect(sql, isNot(contains('service_role_key')));
      expect(sql, isNot(matches(RegExp(r'eyJ[A-Za-z0-9_-]{20,}'))));
    });

    test('live isbot yo\'li fayl ICHIDA ko\'rsatilgan', () {
      expect(sql, contains('private_tables_anon_isolation_live_test.dart'));
      expect(sql, contains('DEPLOYMENT ISBOTI EMAS'));
    });

    test('JONLI holat va "QO\'LLANMADI" qarori fayl ICHIDA yozilgan', () {
      // Bu tekshiruv ATAYLAB IZOHGA qaraydi (shu sababli `sql`, `code` emas).
      // 2026-08-30 da jonli holat o'lchandi: to'rt jadvalda RLS YOQILGAN va
      // policy YO'Q, ya'ni PostgreSQL ularni DENY-ALL qiladi. Demak bu fayl
      // jonli bazada himoyani YOQMAYDI — BO'SHASHTIRADI (uchta ma'lumotnomaga
      // `USING (true)` SELECT beradi). Shu sababli u production'ga ATAYLAB
      // qo'llanmadi.
      //
      // Agar bu qaror yozuvi "tozalash" paytida o'chirilsa, keyingi o'quvchi
      // migratsiyani "qo'llanishi kutilayotgan" deb tushunib jonli bazani
      // bo'shashtiradi — aynan shuni to'sish uchun qulflanadi.
      expect(sql, contains('PRODUCTION\'GA QO\'LLANMADI'),
          reason: 'Qaror yozuvi YO\'Q: faylni ko\'rgan odam uni jonli bazaga '
              'qo\'llash KERAK deb tushunadi.');
      expect(sql, contains('.runtime_evidence/before_rls_state.out.json'),
          reason: '§0: qaror ASOSI (o\'lchov fayli) ko\'rsatilishi shart, aks '
              'holda "qo\'llanmadi" DA\'VO bo\'lib qoladi.');
      expect(sql, isNot(contains('jonli holat NOT VERIFIED')),
          reason: 'Jonli holat O\'LCHANDI — eski NOT VERIFIED da\'vosi '
              'faylda qolib ketmasligi kerak.');
    });
  });
}
