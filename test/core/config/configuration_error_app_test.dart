import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/config/configuration_error_app.dart';
import 'package:lexhub/core/localization/app_locales.dart';
import 'package:lexhub/core/localization/bootstrap_strings.dart';
// `show` ataylab: main.dart ham `main()` e'lon qiladi, kolliziyani oldini oladi.
// Bu import bootstrap zanjirini (main.dart -> DI -> barcha feature'lar)
// test compile'iga tortadi, ya'ni fail-fast o'zgarishi kompilyatsiya
// darajasida ham tekshiriladi.
import 'package:lexhub/main.dart' show LexHubApp;

/// P0 fail-fast bootstrap uchun regression testlar.
///
/// Maqsad: konfiguratsiya yetishmasa ilova JIM qolmasligi, balki aniq
/// diagnostik ekran ko'rsatishi. Bu test `ConfigurationErrorApp` widget'ini
/// haqiqiy render qiladi — ya'ni fayl kompilyatsiya bo'lgani va ekran
/// ishlagani isbotlanadi (statik grep emas).
void main() {
  group('ConfigurationErrorApp', () {
    const details =
        'Build konfiguratsiyasi yetishmayapti: SUPABASE_URL, SUPABASE_ANON_KEY.';

    tearDown(() => BootstrapStrings.debugLocaleOverride = null);

    testWidgets('renders the diagnostic screen with the validate() message',
        (WidgetTester tester) async {
      // §16: ekran DI'dan OLDIN chiziladi, ya'ni `AppL10n` yo'q. Til
      // `BootstrapStrings` orqali keladi — shuning uchun IKKALA tilni ham
      // haqiqatan tekshiramiz, "test hosti qaysi tilni tanlasa" degan
      // tasodifga tayanmaymiz.
      BootstrapStrings.debugLocaleOverride = AppLocales.uzbek;
      await tester.pumpWidget(const ConfigurationErrorApp(details: details));
      await tester.pump();

      expect(find.text('Ilova sozlanmagan'), findsOneWidget);
      expect(find.textContaining('env/dev.json.example'), findsOneWidget);

      // SelectableText.data orqali o'qiymiz — find.text semantikasiga
      // tayanmaslik uchun (SelectableText ichkarida EditableText yasaydi).
      final texts = tester
          .widgetList<SelectableText>(find.byType(SelectableText))
          .map((w) => w.data ?? '')
          .toList();

      expect(texts, contains(details));
      expect(
        texts.any((t) => t.contains('--dart-define-from-file')),
        isTrue,
        reason: 'Ekran to\'g\'ri build komandasini ko\'rsatishi kerak',
      );
    });

    testWidgets('ingliz tilida BUTUN ekran tarjima qilinadi (§16)',
        (WidgetTester tester) async {
      BootstrapStrings.debugLocaleOverride = AppLocales.english;
      await tester.pumpWidget(const ConfigurationErrorApp(details: details));
      await tester.pump();

      expect(find.text('The app is not configured'), findsOneWidget);
      expect(find.text('Ilova sozlanmagan'), findsNothing);

      final rendered = tester
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data ?? '')
          .join('\n');
      // `en` rejimida o'zbekcha matn QOLMASLIGI kerak. `details` va build
      // komandasi `SelectableText` — ular diagnostika, tarjimasiz.
      for (final uzMarker in const ["yo'q", 'ishlamaydi', 'Kerakli kalitlar']) {
        expect(rendered.contains(uzMarker), isFalse,
            reason: 'Ingliz rejimida o\'zbekcha matn qoldi: $uzMarker');
      }
      expect(rendered, contains('env/dev.json.example'));
    });

    testWidgets('renders nothing beyond the message it was given',
        (WidgetTester tester) async {
      // Anti-leak: widget faqat unga berilgan matnni chiqaradi. Agar kelajakda
      // kimdir bu ekranga `SupabaseConfig.anonKey` yoki boshqa credential
      // qo'shsa, bu test uni ushlaydi.
      await tester.pumpWidget(const ConfigurationErrorApp(details: details));
      await tester.pump();

      const forbidden = <String>[
        'sb_publishable_',
        'sb_secret_',
        'eyJ',
        'AIza',
        'AQ.',
        '.supabase.co',
      ];

      final rendered = <String>[
        ...tester.widgetList<Text>(find.byType(Text)).map((w) => w.data ?? ''),
        ...tester
            .widgetList<SelectableText>(find.byType(SelectableText))
            .map((w) => w.data ?? ''),
      ].join('\n');

      for (final marker in forbidden) {
        expect(
          rendered.contains(marker),
          isFalse,
          reason: 'Diagnostik ekran credential ko\'rinishidagi matn '
              'ko\'rsatmasligi kerak (marker: $marker)',
        );
      }
    });

    testWidgets('is dependency-free: no GetIt, no Supabase, no theme lookup',
        (WidgetTester tester) async {
      // DI initialize qilinmagan holatda ham ishlashi shart — chunki
      // main() bu ekranni `initDependencies()`dan OLDIN ko'rsatadi.
      await tester.pumpWidget(const ConfigurationErrorApp(details: details));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('main.dart bootstrap', () {
    test('LexHubApp is still a const-constructible StatelessWidget', () {
      // Bu test main.dart'ni compile zanjiriga qo'shish uchun ham kerak:
      // fail-fast o'zgarishidan keyin bootstrap fayli buzilmaganini
      // kompilyatsiya darajasida tasdiqlaydi.
      expect(const LexHubApp(), isA<StatelessWidget>());
    });
  });
}
