// LexHub — DIAGNOSTIKA JURNALI EKRANI: HALOLLIK QULFI.
//
// NIMA UCHUN BU FAYL BOR: `crash_log_page.dart` o'z kutubxona izohida TO'RTTA
// halollik majburiyatini E'LON QILADI (to'qima yozuv yo'q, PII
// minimizatsiyasi, xato yashirilmaydi, purge soni SERVERDAN keladi), lekin
// 2026-08-30 gacha birortasi test bilan qulflanmagan edi — ya'ni majburiyat
// IZOH edi, tekshiriladigan XOSSA emas.
//
// USUL: `SupabaseClient` `MockClient` bilan quriladi va `sl` (GetIt) ga
// qo'yiladi. Tarmoq CHIQMAYDI, jonli baza TALAB QILINMAYDI.
//
// CHEKLOV (CLAUDE.md §0, ochiq aytiladi): bu MOCK backend, ya'ni u
// PRODUCTION isboti EMAS. Bu yerda o'lchanadigan narsa server siyosati emas,
// EKRANNING server javobiga MUNOSABATI. `client_error_logs` ning haqiqiy
// SELECT policy'si (`is_admin_or_moderator()`) alohida o'lchanadi —
// `test/integration/private_tables_anon_isolation_live_test.dart`.
//
// `autoRefreshToken: false` ATAYLAB: standart `true` GoTrue'da davriy `Timer`
// ochadi va `pumpAndSettle` "timed out" bilan yiqiladi.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lexhub/core/di/injection_container.dart';
import 'package:lexhub/features/diagnostics/presentation/pages/crash_log_page.dart';
import 'package:lexhub/l10n/gen/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../support/l10n_test_app.dart';

void main() {
  /// Oxirgi so'rov URI'si — `select` ro'yxatini o'lchash uchun.
  Uri? lastUri;

  /// Serverni ALMASHTIRADI: `body` AYNAN shu javob sifatida qaytadi.
  void useFakeServer(String body, {int status = 200}) {
    lastUri = null;
    final client = SupabaseClient(
      'https://fake.supabase.co',
      'fake-anon-key',
      httpClient: MockClient((req) async {
        lastUri = req.url;
        // `request: req` MAJBURIY: `postgrest` javobni tahlil qilishda
        // `response.request!.method` ni o'qiydi (postgrest 2.9.1,
        // `postgrest_builder.dart:462`). Uni bermasak har bir so'rov
        // "Null check operator used on a null value" bilan yiqiladi va test
        // ekranning XATO yo'lini o'lchab, muvaffaqiyat yo'lini
        // TEKSHIRMAGAN bo'lardi (o'lchandi 2026-08-30).
        return http.Response(body, status,
            request: req,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    if (sl.isRegistered<SupabaseClient>()) {
      sl.unregister<SupabaseClient>();
    }
    sl.registerSingleton<SupabaseClient>(client);
  }

  tearDown(() async => sl.reset());

  Future<AppL10n> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(l10nTestApp(const CrashLogPage()));
    await tester.pumpAndSettle();
    return AppL10n.of(tester.element(find.byType(CrashLogPage)));
  }

  testWidgets('bo\'sh javob TO\'QIMA yozuvga aylanmaydi', (tester) async {
    useFakeServer('[]');
    final l10n = await pumpPage(tester);

    // `crashLogEmpty` — HALOL bo'shlik. Placeholder/namuna yozuv bo'lsa
    // diagnostika ekrani o'zi YOLG'ON dalil bo'lardi.
    expect(find.text(l10n.crashLogEmpty), findsOneWidget);
    expect(find.byType(ExpansionTile), findsNothing,
        reason: 'Server 0 qator qaytardi, lekin ekranda yozuv bor — '
            'TO\'QIMA MA\'LUMOT.');
  });

  testWidgets('PII MINIMIZATSIYASI: `user_id` so\'ralmaydi va chiqmaydi',
      (tester) async {
    // Server ATAYLAB `user_id` ni ham qaytaradi (yon ta'sir yoki policy
    // o'zgarishi natijasida bu real holat bo'lishi mumkin).
    useFakeServer(jsonEncode([
      {
        'created_at': '2026-08-30T10:11:12.000Z',
        'kind': 'FlutterError',
        'message': 'RenderFlex overflowed by 42 pixels',
        'stack': '#0 _AssertionError._throwNew',
        'context': 'community_page',
        'platform': 'android',
        'build_mode': 'release',
        'user_id': '11111111-2222-3333-4444-555555555555',
      }
    ]));
    await pumpPage(tester);

    expect(find.text('RenderFlex overflowed by 42 pixels'), findsOneWidget,
        reason: 'Yozuv ekranga chiqmadi — testning qolgani hech narsa '
            'isbotlamaydi.');

    // 1) SO'ROV darajasi: ustun UMUMAN so'ralmaydi.
    expect(lastUri, isNotNull);
    expect(lastUri!.query.contains('user_id'), isFalse,
        reason: 'So\'rov `user_id` ni SO\'RAYDI: $lastUri. Kerak '
            'bo\'lmagan PII tarmoqqa chiqmasligi kerak.');

    // 2) EKRAN darajasi. TILE OCHILADI: `ExpansionTile` yopiq holatda
    // bolalarini QURMAYDI, ya'ni yopiq holda tekshirish `context` va `stack`
    // ni — PII yashirinishi eng mumkin bo'lgan ikki joyni — O'LCHAMAY
    // qoldirardi (o'lchandi 2026-08-30).
    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();
    expect(find.text('#0 _AssertionError._throwNew'), findsOneWidget,
        reason: 'Tile ochilmadi — pastdagi tekshiruv bo\'sh matn ustida '
            'ishlab, VAKUUM assertion bo\'lardi.');

    // `stack` `SelectableText` da ko'rsatiladi — u `Text` EMAS, shuning uchun
    // ikkalasi ham yig'iladi.
    final screen = [
      ...tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? ''),
      ...tester
          .widgetList<SelectableText>(find.byType(SelectableText))
          .map((t) => t.data ?? ''),
    ].join('\n');
    expect(screen.contains('11111111-2222-3333-4444-555555555555'), isFalse,
        reason: 'XATO JURNALI foydalanuvchi identifikatorini EKRANDA '
            'ko\'rsatdi — bu diagnostika uchun kerak emas.');
  });

  testWidgets('XATO YASHIRILMAYDI: 42501 bo\'sh ro\'yxatga aylanmaydi',
      (tester) async {
    // Ruxsat yo'q: `client_error_logs` SELECT'i `is_admin_or_moderator()`.
    useFakeServer(
      jsonEncode({
        'code': '42501',
        'message': 'permission denied for table client_error_logs',
        'details': null,
        'hint': null,
      }),
      status: 403,
    );
    final l10n = await pumpPage(tester);

    expect(find.text(l10n.actionRetry), findsOneWidget,
        reason: 'Xato holati ko\'rsatilmadi.');
    expect(find.text(l10n.crashLogEmpty), findsNothing,
        reason: 'JIM YUTISH: ruxsat rad etilgani "jurnal bo\'sh" deb '
            'ko\'rsatildi. Foydalanuvchi hech qanday xato yo\'q deb o\'ylaydi.');
    expect(find.byType(ExpansionTile), findsNothing);
  });
}
