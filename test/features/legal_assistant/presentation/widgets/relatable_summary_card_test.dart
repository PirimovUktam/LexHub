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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/legal_response.dart';
import 'package:lexhub/features/legal_assistant/presentation/widgets/relatable_summary_card.dart';
import 'package:lexhub/l10n/gen/app_localizations.dart';

import '../../../../support/l10n_test_app.dart';

const _summary = 'Ish beruvchi ish haqini kechiktirsa, mehnat inspeksiyasiga '
    'murojaat qilish huquqingiz bor.';

Future<AppL10n> _pump(WidgetTester tester, String source,
    {Locale locale = const Locale('uz')}) async {
  late AppL10n l10n;
  await tester.pumpWidget(l10nTestApp(
    Scaffold(
      body: Builder(builder: (context) {
        l10n = AppL10n.of(context);
        return SingleChildScrollView(
          child: RelatableSummaryCard(summary: _summary, source: source),
        );
      }),
    ),
    locale: locale,
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
}
