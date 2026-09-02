// LEXHUB — MIGRATSIYALARDAGI YOZISH POLICY QOPLAMASI (statik kontrakt).
//
// BU DEPLOYMENT ISBOTI EMAS. Bu test `supabase/migrations/*.sql` va
// `supabase/schema.sql` MATNINI o'qiydi, jonli bazaga ULANMAYDI. Jonli isbot —
// SESSIYALI yozish testi:
// `test/integration/community_write_session_rls_live_test.dart` (gated).
// DIQQAT: `real_supabase_community_e2e_test.dart` bu yerda ISBOT sifatida
// ko'rsatilMAYDI — o'lchandi (2026-08-30): u `signIn*` CHAQIRMAYDI, ya'ni
// faqat MEHMON rad etilishini tekshiradi va yozish policy'sini O'LCHAMAYDI.
//
// JONLI HOLAT (o'lchangan 2026-08-30T17:31:33Z,
// `.runtime_evidence/write_policies_parity_facts.out.json`): jonli bazada
// `questions` INSERT/DELETE, `reports` UPDATE/DELETE va `votes` ALL policy'lari
// BOR; `questions` UPDATE va `reports` INSERT esa YO'Q. Ya'ni pastda aytilgan
// "savol yaratish 42501 bilan rad etiladi" oqibati PRODUCTION'da RO'Y BERMAGAN
// — bu test REPO parity'sini qulflaydi, jonli holatni EMAS.
//
// NIMA UCHUN BU FAYL BOR: 2026-08-30 da o'lchandi — `supabase/schema.sql` da
// bor YOZISH policy'lari `supabase/migrations/` da YO'Q edi:
//   questions -> INSERT, UPDATE;   reports -> INSERT;   votes -> ALL.
// Oqibati: FAQAT migratsiyalardan qurilgan bazada `questions` da RLS YOQILGAN
// (`20260828_mvp_blockers_p0_07_p1_05_p1_06.sql:256`), INSERT policy esa yo'q —
// PostgreSQL savol yaratishni `42501` bilan RAD ETADI. Bu §4 dagi "community
// savol yaratish" regressiya taqiqiga tegadi. Tuzatish:
// `20260830110000_missing_write_policies_parity.sql`.
//
// `rls_enabled_for_all_tables_test.dart` bu sinfni TUTMAYDI: u har bir
// jadvalda KAMIDA BITTA policy borligini talab qiladi, qaysi BUYRUQ
// qoplanganini emas — SELECT policy bilan ham yashil qolardi.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _createPolicy = RegExp(
    r'create\s+policy\s+"([^"]+)"\s*on\s+(?:public\.)?([a-z_0-9]+)',
    caseSensitive: false);

final _forCmd =
    RegExp(r'\bfor\s+(select|insert|update|delete|all)\b', caseSensitive: false);

/// `--` izoh qatorlari TASHLANADI: izohda ataylab "ilgari yo'q edi" kabi
/// qiymatlar eslatiladi, tekshiruv esa KODDA bo'lishi kerak.
String _codeOf(String sql) =>
    sql.split('\n').where((l) => !l.trimLeft().startsWith('--')).join('\n');

class _Scan {
  final Map<String, Set<String>> byTable = <String, Set<String>>{};
  final List<String> implicitCmd = <String>[];
}

/// `CREATE POLICY` dan KEYINGI 250 belgidan `FOR <cmd>` izlanadi.
///
/// `;` bo'yicha bo'lish bu yerda XATO bo'lardi: yangi migratsiyada
/// `CREATE POLICY` matnlari dollar-quoted satr ichida va BITTA `DO` bloki
/// tarkibida — `;` bo'yicha bo'lish ularni bir-biridan ajratmaydi.
_Scan _scan(String code) {
  final scan = _Scan();
  for (final m in _createPolicy.allMatches(code)) {
    final table = m.group(2)!.toLowerCase();
    final stop = m.end + 250 > code.length ? code.length : m.end + 250;
    final cmd = _forCmd.firstMatch(code.substring(m.end, stop));
    if (cmd == null) {
      scan.implicitCmd.add('"${m.group(1)}" ON $table');
      continue;
    }
    scan.byTable
        .putIfAbsent(table, () => <String>{})
        .add(cmd.group(1)!.toUpperCase());
  }
  return scan;
}

/// ATAYLAB torroq: `20260830100000_rls_never_enabled_tables.sql` `bookmarks`
/// ga egaga-xos SELECT/INSERT/DELETE beradi, `schema.sql` dagi keng `FOR ALL`
/// ni esa QAYTARMAYDI (`UPDATE` policy'siz = DENY). Bu KAMCHILIK EMAS,
/// shuning uchun yagona ruxsat etilgan istisno — SABABI bilan.
const _deliberatelyNarrower = <String, List<String>>{
  'bookmarks': ['ALL'],
};

void main() {
  const migDir = 'supabase/migrations';
  const fixPath = '$migDir/20260830110000_missing_write_policies_parity.sql';

  late _Scan mig;
  late _Scan sch;
  late int migFileCount;

  setUpAll(() {
    final dir = Directory(migDir);
    expect(dir.existsSync(), isTrue,
        reason: '`$migDir` topilmadi — test paket ildizidan ishga '
            'tushirilishi kerak.');
    final files = dir
        .listSync()
        .whereType<File>()
        .map((f) => f.path.replaceAll('\\', '/'))
        .where((p) => p.endsWith('.sql'))
        .toList()
      ..sort();
    migFileCount = files.length;
    mig = _scan(files.map((p) => _codeOf(File(p).readAsStringSync())).join('\n'));

    final schemaFile = File('supabase/schema.sql');
    expect(schemaFile.existsSync(), isTrue);
    sch = _scan(_codeOf(schemaFile.readAsStringSync()));
  });

  group('A. migrations `schema.sql` dagi YOZISH policy\'larini qoplaydi', () {
    test('skaner haqiqatan topdi (bo\'sh o\'tish IMKONSIZ)', () {
      // Eng xavfli yiqilish — regexp buzilib HECH NARSA topmasligi va testning
      // JIM yashil bo'lishi. Shu sababli sonlar ham qulflangan.
      expect(migFileCount, greaterThanOrEqualTo(31),
          reason: 'o\'lchangan 2026-08-30: 31 migratsiya fayli');
      expect(mig.byTable.length, greaterThanOrEqualTo(21),
          reason: 'o\'lchangan 2026-08-30: policy 21 jadvalga beriladi');
      expect(sch.byTable.length, greaterThanOrEqualTo(15));
    });

    test('har bir `CREATE POLICY` da OSHKORA `FOR <cmd>` bor', () {
      // `FOR` yozilmasa PostgreSQL `ALL` deb oladi — ya'ni jim keng huquq.
      // Skanerning o'zi ham shu holatda buyruqni XATO aniqlaydi.
      expect(mig.implicitCmd, isEmpty, reason: 'migrations: ${mig.implicitCmd}');
      expect(sch.implicitCmd, isEmpty, reason: 'schema.sql: ${sch.implicitCmd}');
    });

    test('YOZISH buyrug\'i qoplanmagan jadval YO\'Q', () {
      final gaps = <String, List<String>>{};
      for (final entry in sch.byTable.entries) {
        final have = mig.byTable[entry.key] ?? const <String>{};
        final missing = entry.value
            .where((c) => c != 'SELECT')
            .where((c) => !have.contains(c))
            .toList()
          ..sort();
        if (missing.isNotEmpty) gaps[entry.key] = missing;
      }
      expect(gaps, _deliberatelyNarrower,
          reason: 'FAQAT `$migDir` dan qurilgan bazada bu buyruqlar policy\'siz '
              'qoladi — RLS yoqilgan jadvalda bu DENY, ya\'ni oqim `42501` '
              'bilan yiqiladi. Har bir yangi istisno SABABI bilan '
              '`_deliberatelyNarrower` ga yozilishi shart.\nO\'lchangan: $gaps');
    });

    test('savol/ovoz/shikoyat yozish yo\'li AYNAN qoplangan', () {
      // 2026-08-30 da topilgan uchta teshik nomma-nom qulflanadi.
      expect(mig.byTable['questions'], containsAll(<String>['INSERT', 'UPDATE']));
      expect(mig.byTable['reports'], contains('INSERT'));
      final votes = mig.byTable['votes'] ?? const <String>{};
      expect(votes.contains('ALL') || votes.containsAll(['INSERT', 'DELETE']),
          isTrue,
          reason: 'ovoz berish/qaytarish uchun INSERT va DELETE kerak: $votes');
    });
  });

  group('B. tuzatish migratsiyasining kontrakti', () {
    late String sql;
    late String code;

    setUpAll(() {
      final file = File(fixPath);
      expect(file.existsSync(), isTrue, reason: 'topilmadi: $fixPath');
      sql = file.readAsStringSync();
      code = _codeOf(sql);
    });

    test('transaction-safe', () {
      expect(code, contains('BEGIN;'));
      expect(code, contains('COMMIT;'));
    });

    test('FAQAT TO\'LDIRADI — bironta `DROP POLICY` YO\'Q', () {
      // Bu faylning ASOSIY xossasi. Jonli policy predikati repo'dagidan
      // QATTIQROQ bo'lishi mumkin (`schema.sql` production'dan farq qilishi
      // hujjatlashtirilgan) — uni almashtirish ZAIFLASHTIRISH bo'lardi.
      expect(code.toUpperCase(), isNot(contains('DROP POLICY')),
          reason: 'Mavjud policy TEGILMASLIGI kerak.');
      expect(code, contains('cmd = ANY (v_row.blockers)'),
          reason: 'Shu buyruq allaqachon qoplanganini tekshiradigan shart '
              'YO\'Q — u bo\'lmasa fayl ikkinchi marta `42710` bilan '
              'yiqiladi va mavjud policy ustidan yozilardi.');
      expect(code, contains("permissive = 'PERMISSIVE'"));
      // `ALL` policy INSERT/UPDATE/DELETE ni HAM boshqaradi — to'suvchi
      // ro'yxatida bo'lishi shart, aks holda ikkinchi RUXSAT policy'si
      // qo'shilib huquq KENGAYARDI.
      expect(code, contains("ARRAY['INSERT', 'ALL']"));
    });

    test('predikatlar `schema.sql` dan AYNAN ko\'chirilgan', () {
      expect(code, contains("auth.role() = 'authenticated'"));
      expect(code, contains('auth.uid() = user_id'));
      expect(code, contains('auth.uid() = reporter_id'));
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
      ]) {
        expect(code, contains(gate), reason: gate);
      }
      expect(code, contains('P3 O\'\'LCHOV'),
          reason: 'O\'zgartirishdan OLDINGI holat o\'lchanmasa, "hech narsa '
              'o\'zgarmadi" holati KO\'RINMAYDI.');
      expect(code, contains('FROM pg_policies'));
    });

    test('NOTICE ko\'rinmasligi hisobga olingan — COMMIT\'dan keyin SELECT',
        () {
      final commit = code.indexOf('COMMIT;');
      expect(commit, greaterThan(0));
      final after = code.substring(commit + 'COMMIT;'.length);
      expect(after, contains('FROM pg_policies'),
          reason: 'Supabase SQL Editor `RAISE NOTICE` ni ko\'rsatmaydi '
              '(219545f) — natija JADVAL bo\'lib qaytarilishi kerak.');
      expect(after, contains('CHEKLOVSIZ'),
          reason: 'Cheklovsiz yozish policy\'si KO\'RINSIN.');
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
        'ALTER TABLE',
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
      expect(sql, contains('DEPLOYMENT ISBOTI EMAS'));
      expect(sql, contains('real_supabase_community_e2e_test.dart'));
    });
  });
}

