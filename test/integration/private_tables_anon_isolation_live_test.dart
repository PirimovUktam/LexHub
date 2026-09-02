// LEXHUB — MAXFIY JADVALLARNING ANON IZOLYATSIYASI: LIVE (PRODUCTION) SVIP.
//
// NIMA UCHUN BU FAYL BOR: har bir feature testi o'z jadvalini alohida
// tekshirardi va TIZIMLI qoplama yo'q edi. Natijada
// `real_supabase_document_builder_test.dart` da XAVFSIZLIK JIHATIDAN KO'R
// assertion paydo bo'ldi: `expect(userDocsTableExists, true)` — ya'ni anon
// so'rov MUVAFFAQIYATLI bo'lishini talab qilardi. RLS butunlay o'chirilib
// boshqa fuqarolarning hujjatlari qaytsa ham u test YASHIL qolardi.
//
// Bu fayl BITTA xossani BARCHA maxfiy jadvalda o'lchaydi:
//
//   Tizimga KIRMAGAN klient (anon kalit, sessiyasiz) maxfiy jadvaldan
//   NOL qator ko'radi — yoki so'rov 42501 bilan rad etiladi.
//
// USUL: PostgREST `Prefer: count=exact` + `limit=0`. Ya'ni QATORLAR
// YUKLANMAYDI, faqat SON o'qiladi. Sababi ataylab: agar izolyatsiya
// buzilgan bo'lsa, testning o'zi PII va huquqiy kontentni CI log'iga
// ko'chirib, teshikni KATTALASHTIRARDI.
//
// Ishga tushirish (FAQAT O'QIYDI, hech narsa yozmaydi):
//
//   flutter test test/integration/private_tables_anon_isolation_live_test.dart \
//     --dart-define-from-file=env/prod.json \
//     --dart-define=LEXHUB_LIVE_WRITE_TESTS=true --reporter expanded
//
// POSTGREST STATUS SEMANTIKASI — O'LCHANDI 2026-08-30 (jonli bazada, taxmin
// EMAS). Bu fayl avval `expect(status, 200)` talab qilardi va SOG'LOM holatda
// QIZIL bo'lardi:
//   `?limit=5`                    Prefer YO'Q     -> 200, range `0-4/*`
//   `?limit=5`   + count=exact                    -> 206, range `0-4/17`
//   `?limit=0`   + count=exact, jadval TO'LA       -> 206, range `*/17`
//   `?limit=0`   + count=exact, jadval BO'SH       -> 200, range `*/0`
// Ya'ni bu faylning usulida (count=exact + limit=0) **206 = jadvalda qator
// BOR va anon uni O'QIYDI**, **200 = ko'rinadigan qator NOL**. Shuning uchun
// 206 ni "kutilmagan status" deb rad etish teshikni MAXFIYLIK xatosi emas,
// STATUS xatosi qilib ko'rsatardi va ochiq ma'lumotnoma testini teskari
// aylantirardi (o'lchangan: 4 ochiq jadval 206 tufayli QIZIL edi).
//
// COUNT=0 NING CHEKLOVI (§0): BO'SH jadval ham `count=0` qaytaradi. 2026-08-30
// da jonli bazada `bookmarks`, `question_categories`, `question_tags`,
// `question_tag_mappings`, `questions` — HAMMASI 0 qator. Ya'ni bu jadvallar
// uchun `count=0` "RLS himoya qilyapti" degani EMAS, "o'g'irlanadigan qator
// yo'q" degani. Himoya isboti faqat migratsiyaning O'ZI qo'llanganda
// (`relrowsecurity` + `pg_policies` ni o'lchaydigan D1-D4 gate'lari) olinadi.
//
// BIRINCHI JONLI ISHGA TUSHIRISH — O'LCHANDI 2026-08-30
// (host `lypejrvzzqarkiqpdimy.supabase.co`, migratsiyalar qo'llanishidan
// OLDIN): 10 ta maxfiy jadvalning HAMMASIDA `anon count=0`.
//   * `bookmarks` -> `count=0`. LEKIN BU HIMOYA ISBOTI EMAS: shu kuni
//     `bookmarks`, `question_categories`, `question_tags`,
//     `question_tag_mappings`, `questions` — beshtasi ham 0 qator, ya'ni
//     jadval BO'SH. Bo'sh jadval RLS bor-yo'qligidan qat'i nazar `count=0`
//     qaytaradi, shuning uchun ilgari bu yerda yozilgan xulosa
//     ("count = 0 -> `schema.sql` policy'si bazada bor") NOTO'G'RI edi —
//     SELECT zondi bu ikki shoxni AJRATA OLMAYDI (§0).
//   * AJRATADIGAN yagona jonli o'lchov — migratsiyaning O'ZINI qo'llash:
//     `20260830100000_rls_never_enabled_tables.sql` ning P3/D1-D4 bloklari
//     `pg_class.relrowsecurity` va `pg_policies` ni BEVOSITA o'qiydi va
//     mos kelmasa `RAISE EXCEPTION` bilan COMMIT'ni bekor qiladi.
//   * YONDOSH JONLI ISBOT: `profiles` -> `401 / 42501` va PostgREST hint'i
//     "GRANT SELECT ON public.profiles TO anon" deydi, ya'ni
//     `20260829120000` dagi `REVOKE ... FROM anon` JONLI BAZADA BOR. Bu —
//     hech bo'lmasa bitta 2026-08-29 xavfsizlik migratsiyasi qo'llangani
//     haqidagi to'g'ridan-to'g'ri dalil.
//   * Statik (jonli muhit talab qilmaydigan) isbot:
//     `test/core/security/rls_enabled_for_all_tables_test.dart`.
//
//   * Qolgan jadvallarda `auth.uid()` ga tayangan SELECT policy bor, ya'ni
//     ular YASHIL bo'lishi kutiladi (o'lchandi: hammasi yashil).
//
// `questions` ATAYLAB bu ro'yxatda yo'q: u OCHIQ jadval (anonim savol
// EGASI esa yopiq) va o'z fayli bor —
// `test/integration/questions_anonymity_live_test.dart`.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/config/supabase_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/live_gate.dart';

/// Maxfiy jadval: (nom, NIMA UCHUN maxfiy — policy manbasi bilan).
const _privateTables = <(String, String)>[
  (
    'user_documents',
    'RLS `USING (auth.uid() = user_id)` '
        '(20260823_legal_document_templates_and_user_docs.sql). Qatorlarda '
        'F.I.Sh, manzil, telefon va nizo tafsiloti bor.',
  ),
  (
    'votes',
    'RLS `USING (auth.uid() = user_id)` '
        '(20260820_p0_security_remediation.sql:241). Kim nimaga ovoz '
        'bergani — siyosiy/huquqiy qarash izi.',
  ),
  (
    'bookmarks',
    'MIGRATSIYALARDA RLS YO\'Q edi (20260819_base_schema.sql:317), '
        '`schema.sql:833,1042` esa RLS + egaga-xos policy beradi — natija '
        'qaysi manba jonli bazaga qo\'llanganini AJRATADI. Saqlangan element '
        'sarlavhalari odamning qaysi huquqiy muammosi borligini oshkor qiladi.',
  ),
  (
    'consultations',
    'RLS `auth.uid() = citizen_id OR expert_id IN (...)` '
        '(20260825010000_step2_payments_tables_and_logic.sql).',
  ),
  (
    'payments',
    'RLS `auth.uid() = citizen_id OR expert_id IN (...)`. To\'lov summasi '
        'va tomonlar.',
  ),
  (
    'payment_audit_logs',
    'RLS FAQAT admin (`profiles.role = admin`).',
  ),
  (
    'user_notifications',
    'RLS `USING (auth.uid() = user_id)`.',
  ),
  (
    'reports',
    'RLS `USING (public.is_admin_or_moderator())` — shikoyat BERUVCHI '
        'shaxsni oshkor qiladi.',
  ),
  (
    'expert_profiles',
    'RLS `auth.uid() = user_id OR is_admin_or_moderator()`; ochiq katalog '
        'ATAYLAB `public_expert_profiles_view` orqali beriladi '
        '(20260829000500_expert_license_visibility_and_lock.sql:85). Xom '
        'jadvalda litsenziya raqami bor.',
  ),
  (
    'client_error_logs',
    'SELECT FAQAT `authenticated` ga berilgan '
        '(20260830010000_client_error_logs.sql:141).',
  ),
];

/// Anon uchun OCHIQ bo'lishi KERAK bo'lgan resurslar (teskari tomon:
/// qulflash ilovaning o'z ishini buzmasligi shart), va 2026-08-30 da JONLI
/// bazada O'LCHANGAN ko'rinadigan qator MINIMUMI.
///
/// MINIMUM NIMA UCHUN BOR: faqat status tekshirilsa, test BO'SH jadvalda ham
/// yashil qoladi (bo'sh jadval `200` + `count=0` qaytaradi). Ya'ni sonsiz
/// assertion "ochiq va ishlayapti" bilan "ma'lumot yo'qoldi / qulflanib
/// qoldi" ni AJRATMAYDI. `answers` va `public_expert_profiles_view` —
/// foydalanuvchi yaratadigan kontent, jonli bazada bugun 0 qator (o'lchandi),
/// shuning uchun ularda minimum 0 va tekshiruv faqat status darajasida.
const _publicReadable = <(String, int)>[
  ('document_templates', 3),
  ('citizen_services', 6),
  ('service_steps', 14),
  ('law_article_chunks', 17),
  ('answers', 0),
  ('public_expert_profiles_view', 0),
];

void main() {
  if (!liveSuiteEnabled('private_tables_anon_isolation')) return;

  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null; // real tarmoq

  late String baseUrl;
  late String anonKey;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SupabaseConfig.init();
    expect(SupabaseConfig.isConfigured, isTrue,
        reason: 'BLOCKED: --dart-define-from-file=env/prod.json berilmagan '
            '(${SupabaseConfig.validate()})');
    baseUrl = SupabaseConfig.url;
    anonKey = SupabaseConfig.anonKey;
    stdout.writeln('LIVE host=${Uri.parse(baseUrl).host}');
  });

  /// SESSIYASIZ `count=exact` so'rovi. `limit=0` — hech qanday qator
  /// YUKLANMAYDI, faqat `content-range` sarlavhasidagi SON o'qiladi.
  ///
  /// `SupabaseClient` ATAYLAB ishlatilmaydi: u sessiya/keshga bog'lanadi,
  /// bu yerda esa AYNAN mehmon huquqi o'lchanadi.
  Future<(int status, int? count, String body)> countAsAnon(String rel) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    try {
      final req = await client
          .getUrl(Uri.parse('$baseUrl/rest/v1/$rel?select=*&limit=0'));
      req.headers.set('apikey', anonKey);
      req.headers.set('Authorization', 'Bearer $anonKey');
      req.headers.set('Prefer', 'count=exact');
      final res = await req.close().timeout(const Duration(seconds: 30));
      final body = await res.transform(utf8.decoder).join();
      final range = res.headers.value('content-range');
      final total = range == null ? null : int.tryParse(range.split('/').last);
      return (res.statusCode, total, body);
    } finally {
      client.close(force: true);
    }
  }
  group('ANON maxfiy jadvallardan NOL qator ko\'radi', () {
    for (final (table, why) in _privateTables) {
      test(table, () async {
        final (status, count, body) = await countAsAnon(table);

        // 401/403 — jadval yoki ustun huquqi qulflangan. Bu izolyatsiyadan
        // KUCHLIROQ himoya, shuning uchun QABUL QILINADI. Lekin sabab aniq
        // bo'lishi kerak: `42P01` (jadval YO'Q) himoya emas, SXEMA NUQSONI.
        if (status == 401 || status == 403) {
          final json = jsonDecode(body) as Map<String, dynamic>;
          expect(json['code'], '42501',
              reason: '$table: kutilmagan rad etish sababi: $body');
          stdout.writeln('$table: 42501 (huquq qulflangan) — OK');
          return;
        }

        // `count=exact` + `limit=0` da 206 = jadvalda qator BOR va anon uni
        // KO'RYAPTI (o'lchandi 2026-08-30). Uni status xatosi deb rad etish
        // maxfiylik teshigini boshqa nom bilan yashirardi — shuning uchun 206
        // ham qabul qilinadi va SO'NGGI so'zni pastdagi son assertion'i aytadi.
        expect(status, anyOf(200, 206),
            reason: '$table: kutilmagan status $status. Javob: $body');
        expect(count, isNotNull,
            reason: '$table: `content-range` sarlavhasi yo\'q — son '
                'o\'lchanmadi, ya\'ni bu test HECH NARSA isbotlamaydi.');
        // DIQQAT: qatorlar CHOP ETILMAYDI — faqat SON. Aks holda test o'zi
        // PII/huquqiy kontentni log'ga ko'chirib teshikni kattalashtirardi.
        expect(count, 0,
            reason: 'MAXFIYLIK TESHIGI (P0): tizimga KIRMAGAN so\'rov '
                '`$table` dan $count qator KO\'RADI.\nSABAB (kutilgan '
                'siyosat): $why');
        stdout.writeln('$table: anon count=0 — OK');
      });
    }
  });

  group('OCHIQ resurslar HADDAN TASHQARI qulflanmagan', () {
    for (final (rel, minRows) in _publicReadable) {
      test(rel, () async {
        final (status, count, body) = await countAsAnon(rel);
        expect(status, anyOf(200, 206),
            reason: '$rel anon uchun ochiq bo\'lishi kerak, lekin $status '
                'qaytdi. Ilova mehmon rejimida shu resursni o\'qiydi. '
                'Javob: $body');
        expect(count, isNotNull,
            reason: '$rel: `content-range` sarlavhasi yo\'q — son '
                'o\'lchanmadi, ya\'ni bu test HECH NARSA isbotlamaydi.');
        expect(count, greaterThanOrEqualTo(minRows),
            reason: '$rel: anon $count qator ko\'radi, kutilgan KAMIDA '
                '$minRows (jonli bazada o\'lchangan 2026-08-30). Son '
                'kamaysa — yo RLS qulflab qo\'ydi, yo ma\'lumot yo\'qoldi; '
                'ikkalasi ham mehmon rejimini buzadi.');
        stdout.writeln('$rel: anon o\'qidi (count=$count, minimum=$minRows)');
      });
    }
  });
}
