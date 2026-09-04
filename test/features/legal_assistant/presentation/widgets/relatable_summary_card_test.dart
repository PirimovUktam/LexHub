// LexHub — MANBA OSHKORLIGI qulfi (CLAUDE.md §0).
//
// MUAMMO (o'lchangan, 2026-08-26 production live test): `legal-ai` proxy
// `ai_timeout` qaytardi (`gemini-3.7-flash` 40s byudjetga sig'madi), shuning
// uchun `LegalAssistant` HAR BIR so'rovga `_generateGroundedUzbekLegalResponse`
// bilan javob berdi — ya'ni foydalanuvchi 100% hollarda DETERMINISTIK javob
// oldi. Manba badge'i esa faqat `legal_assistant_page.dart` da bo'lgani uchun
// `saved_cases_page`, `recent_cases_feed` va `faq_questions_page` AYNI matnni
// hech qanday oshkorlikSIZ chiqarardi.
//
// BU TEST NIMANI QULFLAYDI: `RelatableSummaryCard` matnni manbani AYTMASDAN
// chizmaydi. `source` parametri majburiy bo'lgani uchun kompilyator yangi
// chaqiruv joyini ushlaydi; bu test esa badge'ning haqiqatan CHIZILISHINI va
// to'g'ri matn tanlanishini ushlaydi (kelajakdagi refactor `Row`ni olib
// tashlasa, kompilyator sezmaydi — test sezadi).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/theme/app_theme.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_response.dart';
import 'package:lexhub/features/legal_assistant/presentation/widgets/relatable_summary_card.dart';
import 'package:lexhub/l10n/gen/app_localizations.dart';

import '../../../../support/l10n_test_app.dart';
import '../../../../support/source_scan.dart';

const _summary = 'Ish beruvchi ish haqini kechiktirsa, mehnat inspeksiyasiga '
    'murojaat qilish huquqingiz bor.';

/// ENG TOR haqiqiy telefon kengligi (Galaxy S8/A-seriya — 360x640 dp).
const _kNarrowPhone = Size(360, 640);

Future<AppL10n> _pump(
  WidgetTester tester,
  String source, {
  Locale locale = const Locale('uz'),
  VoidCallback? onSignInForAi,
  ThemeData? theme,
  Size? surface,
}) async {
  if (surface != null) {
    tester.view
      ..devicePixelRatio = 1.0
      ..physicalSize = surface;
    addTearDown(tester.view.reset);
  }

  late AppL10n l10n;
  await tester.pumpWidget(l10nTestApp(
    Scaffold(
      body: Builder(builder: (context) {
        l10n = AppL10n.of(context);
        return SingleChildScrollView(
          child: RelatableSummaryCard(
            summary: _summary,
            source: source,
            onSignInForAi: onSignInForAi,
          ),
        );
      }),
    ),
    locale: locale,
    theme: theme,
  ));
  await tester.pumpAndSettle();
  return l10n;
}

void main() {
  group('RelatableSummaryCard manbani OSHKOR qiladi', () {
    testWidgets('deterministik javob "AI EMAS" deb belgilanadi', (t) async {
      final l10n = await _pump(t, LegalResponse.sourceDeterministic);

      expect(find.text(_summary), findsOneWidget);
      expect(find.text(l10n.legalSourceDeterministic), findsOneWidget,
          reason: 'Deterministik matn manbani oshkor qilmasdan chizildi.');
      expect(find.text(l10n.legalSourceLlm), findsNothing);

      // Uchqun piktogrammasi deterministik matn ustida "buni AI yozdi" degan
      // yolg'on signal beradi — bo'lmasligi SHART.
      expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing,
          reason: 'Deterministik javob ustida uchqun piktogrammasi qoldi.');
      expect(find.byIcon(Icons.rule_rounded), findsOneWidget);
    });

    testWidgets('model javobi "server AI modeli" deb belgilanadi', (t) async {
      final l10n = await _pump(t, LegalResponse.sourceLlm);

      expect(find.text(l10n.legalSourceLlm), findsOneWidget);
      expect(find.text(l10n.legalSourceDeterministic), findsNothing);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget,
          reason: 'Haqiqiy model javobi uchun uchqun piktogrammasi TO\'G\'RI.');
    });

    // FAIL-CLOSED: `legal_response.dart:103` faqat aynan `'llm'` satrini model
    // javobi deb qabul qiladi. Kutilmagan qiymat kelsa karta ham AI DA'VOSI
    // QILMASLIGI kerak — aks holda buzilgan/eski ma'lumot "AI tahlili" bo'lib
    // ko'rinardi.
    testWidgets('notanish `source` qiymati AI da\'vosi QILMAYDI', (t) async {
      final l10n = await _pump(t, 'gemini-3.7-flash');

      expect(find.text(l10n.legalSourceDeterministic), findsOneWidget);
      expect(find.text(l10n.legalSourceLlm), findsNothing);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing);
    });

    testWidgets('ingliz UI\'da ham badge tarjima qilingan', (t) async {
      final l10n = await _pump(t, LegalResponse.sourceDeterministic,
          locale: const Locale('en'));

      expect(l10n.legalSourceDeterministic, contains('NOT AI'),
          reason: 'en ARB qiymati o\'zbekcha qolgan (gen-l10n / parity).');
      expect(find.text(l10n.legalSourceDeterministic), findsOneWidget);
    });
  });

  // ── MEHMON YO'LI (2026-09-04) ──
  //
  // O'LCHANDI (jonli production): server AI yo'li ISHLAYAPTI —
  // `tool/probe_legal_ai_latency.py` 3/3 `source=llm` qaytardi (24.8 / 14.6 /
  // 32.1 s). Lekin MEHMON rejimida (`login_page.dart:295`) Supabase sessiyasi
  // YO'Q va kodda `signInAnonymously` HAM yo'q, shuning uchun
  // `legal_ai_proxy_service.dart:62-64` proxy'ni UMUMAN chaqirmaydi
  // (`lastErrorCode='unauthenticated'`) va javob 100% deterministik bo'ladi.
  // Sabab faqat `debugPrint`ga chiqardi
  // (`legal_assistant_remote_datasource.dart:127`) — foydalanuvchi "AI EMAS"
  // ni ko'rardi, lekin NEGA va NIMA QILISHNI bilmasdi.
  //
  // BU GURUH NIMANI QULFLAYDI: taklif AYNAN kerakli holatda chiqadi
  // (deterministik + chaqiruvchi yo'l bergan) va boshqa hech qanday holatda
  // chiqmaydi. Karta 4 joyda ishlatiladi; uchtasi SAQLANGAN javoblarni
  // ko'rsatadi va u yerda "tizimga kiring" MA'NOSIZ.
  group('mehmonga kirish taklifi', () {
    // O'LCHANGAN TUZATISH (2026-09-04): bu yerda avval "mavzu `TextButton` ga
    // `minWidth = INFINITY` beradi" deb yozilgandi va test SHU DA'VONI RAD
    // ETDI — `textButtonTheme` (`app_theme.dart:168`, qorong'i twin `:502`)
    // faqat rang va shrift beradi. `Size.fromHeight(50)` esa QO'SHNI
    // `outlinedButtonTheme` da (`:179` / `:517`).
    //
    // Ya'ni taklif tugmasi uchun idish cheklovi MAJBURIY EMAS. Bu qulf
    // shuning uchun turadi: kimdir tugmani `OutlinedButton`/`ElevatedButton`
    // ga almashtirsa yoki `textButtonTheme` ga `Size.fromHeight` qo'shsa,
    // `themed_button_unbounded_width_test.dart` dagi cheksiz kenglik xatari
    // SHU KARTAGA ham qaytadi.
    testWidgets('MEXANIZM MANBASI: `textButtonTheme` kenglik MAJBURLAMAYDI',
        (t) async {
      late ThemeData theme;
      await t.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(builder: (context) {
          theme = Theme.of(context);
          return const SizedBox.shrink();
        }),
      ));

      expect(
        theme.textButtonTheme.style?.minimumSize,
        isNull,
        reason: '`textButtonTheme` ga `minimumSize` qo\'shilgan: `Size'
            '.fromHeight(...)` = `minWidth: INFINITY`, ya\'ni taklif tugmasi '
            'kenglikni CHEKLAMAYDIGAN otada yiqiladi. Kartadagi joylashuvni '
            'va `themed_button_unbounded_width_test.dart` ni qayta ko\'r.',
      );

      // QO'SHNI mavzu HAQIQATAN cheksiz beradi — yuqoridagi da'vo "mavzuni
      // umuman o'qimaganlik" emas, AYNAN o'lchov ekanini ko'rsatadi.
      final outlined =
          theme.outlinedButtonTheme.style?.minimumSize?.resolve(const <WidgetState>{});
      expect(outlined?.width, double.infinity);
    });

    testWidgets('deterministik javob + yo\'l berilgan => taklif CHIQADI va '
        'bosilganda ISHLAYDI', (t) async {
      var tapCount = 0;
      final l10n = await _pump(t, LegalResponse.sourceDeterministic,
          onSignInForAi: () => tapCount++);

      expect(find.text(l10n.legalAiSignInHint), findsOneWidget,
          reason: 'Mehmon "AI EMAS" ni ko\'rdi, lekin YECHIM ko\'rsatilmadi.');

      await t.tap(find.text(l10n.legalAiSignInHint));
      await t.pumpAndSettle();
      expect(tapCount, 1,
          reason: 'Tugma chizildi, lekin bosish HECH NARSA qilmadi.');
    });

    // ENG MUHIM NEGATIV: `saved_cases_page`, `recent_cases_feed` va
    // `faq_questions_page` `onSignInForAi` BERMAYDI.
    testWidgets('yo\'l berilmagan (saqlangan javoblar) => taklif YO\'Q',
        (t) async {
      final l10n = await _pump(t, LegalResponse.sourceDeterministic);

      expect(find.text(l10n.legalAiSignInHint), findsNothing,
          reason: 'Saqlangan javob ustida "tizimga kiring" MA\'NOSIZ.');
      expect(find.byIcon(Icons.login_rounded), findsNothing);
      // Manba badge'i esa SHU YERDA HAM qolishi kerak.
      expect(find.text(l10n.legalSourceDeterministic), findsOneWidget);
    });

    testWidgets('haqiqiy AI javobi => taklif YO\'Q', (t) async {
      final l10n = await _pump(t, LegalResponse.sourceLlm,
          onSignInForAi: () => fail('AI javobida taklif chiqmasligi KERAK'));

      expect(find.text(l10n.legalAiSignInHint), findsNothing);
      expect(find.byIcon(Icons.login_rounded), findsNothing);
      expect(find.text(l10n.legalSourceLlm), findsOneWidget);
    });

    // FAIL-CLOSED: notanish `source` deterministik hisoblanadi
    // (`legal_response.dart:103`), ya'ni taklif CHIQADI — mehmon uchun bu
    // to'g'ri, chunki matn AI tahlili EMAS.
    testWidgets('notanish `source` => taklif CHIQADI', (t) async {
      final l10n = await _pump(t, 'gemini-3.7-flash', onSignInForAi: () {});

      expect(find.text(l10n.legalAiSignInHint), findsOneWidget);
    });

    testWidgets('ingliz UI\'da taklif matni TARJIMA qilingan', (t) async {
      final l10n = await _pump(t, LegalResponse.sourceDeterministic,
          locale: const Locale('en'), onSignInForAi: () {});

      expect(l10n.legalAiSignInHint, contains('Sign in'),
          reason: 'en ARB qiymati o\'zbekcha qolgan (gen-l10n / parity).');
      expect(find.text(l10n.legalAiSignInHint), findsOneWidget);
    });

    // LAYOUT QULFI — 360 px + HAQIQIY mavzu.
    //
    // `FlutterError.onError` VAQTINCHA egallanadi: layout yiqilganda bitta
    // freymda bir necha xato chiqadi va `takeException()` ularni "Multiple
    // exceptions" xabariga ALMASHTIRADI, ya'ni haqiqiy sabab YO'QOLADI
    // (`themed_button_unbounded_width_test.dart:79-83` dagi ayni sabab).
    for (final locale in const ['uz', 'en']) {
      testWidgets('$locale: 360 px telefonda layout TOZA va tugma qisqargan',
          (t) async {
        final errors = <String>[];
        final previous = FlutterError.onError;
        FlutterError.onError = (d) => errors.add(d.exception.toString());
        late AppL10n l10n;
        try {
          l10n = await _pump(
            t,
            LegalResponse.sourceDeterministic,
            locale: Locale(locale),
            onSignInForAi: () {},
            theme: AppTheme.lightTheme,
            surface: _kNarrowPhone,
          );
        } finally {
          FlutterError.onError = previous;
        }

        expect(errors, isEmpty, reason: '360 px: ${errors.join(" | ")}');

        // `ButtonStyleButton` — `TextButton.icon` ichki sinfini NOMLAMASDAN
        // topish yo'li (freymvork versiyasiga bog'liq emas). Matn orqali
        // scope qilinadi, chunki kartadagi `IconButton`lar ham M3 da
        // `ButtonStyleButton` bo'ladi.
        final button = find.ancestor(
          of: find.text(l10n.legalAiSignInHint),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        );
        expect(button, findsOneWidget, reason: 'taklif tugmasi topilmadi');

        // Cheksiz minWidth `Column` cheklovi bilan QISQARGANI: kenglik ekranga
        // sig'adi. `Row` uyasida bu qiymat `Infinity` bo'lib assert bergan
        // bo'lardi.
        final width = t.getSize(button).width;
        expect(width, lessThanOrEqualTo(_kNarrowPhone.width),
            reason: 'tugma ekrandan CHIQDI (kenglik $width)');
        expect(width, greaterThan(0));

        // Uzun matn ikki qatorda QIRQILADI — balandlik o'sadi, chetdan
        // chiqmaydi (`maxLines: 2` + `ellipsis` qulfi).
        final para = t.renderObject<RenderParagraph>(
            find.text(l10n.legalAiSignInHint));
        expect(para.maxLines, 2);
        expect(para.overflow, TextOverflow.ellipsis);
      });
    }
  });

  // Karta o'zi to'g'ri ishlasa ham, CHAQIRUVCHI sahifa `onSignInForAi` ni
  // bermasa mehmon YANA sababsiz "AI EMAS" ni ko'radi — parametr OPSIONAL,
  // ya'ni kompilyator bu regressiyani USHLAMAYDI. Naqshlar BIR SATRLI
  // (`source_lock_portability_test.dart` meta-qulfi), izohlar olib tashlanadi.
  group('REGRESSIYA — savol beradigan sahifa yo\'lni BERMAY qo\'ymasin', () {
    test('legal_assistant_page.dart taklifni uzatadi', () {
      final file = File('lib/features/legal_assistant/presentation/pages/'
          'legal_assistant_page.dart');
      expect(file.existsSync(), isTrue, reason: 'sahifa topilmadi');
      final code = stripLineComments(file.readAsStringSync());

      expect(code.contains('onSignInForAi:'), isTrue,
          reason: 'Yagona JONLI so\'rov sahifasi taklifni uzatmaydi — mehmon '
              'uchun "AI EMAS" yana SABABSIZ qoladi.');
      expect(
        code.contains('context.watch<AuthBloc>().state is Authenticated'),
        isTrue,
        reason: 'Sessiya tekshiruvi yo\'q: taklif TIZIMGA KIRGAN '
            'foydalanuvchiga ham chiqib, uni allaqachon kirgan joyga '
            'yuborardi.',
      );
    });

    for (final locale in const ['uz', 'en']) {
      test('$locale ARB da `legalAiSignInHint` bor', () {
        final arb = File('lib/l10n/arb/app_$locale.arb').readAsStringSync();
        expect(arb.contains('"legalAiSignInHint"'), isTrue,
            reason: '$locale tarjimasi yo\'q — `gen-l10n` yiqiladi yoki '
                'foydalanuvchi boshqa tildagi matnni ko\'radi.');
      });
    }
  });
}
