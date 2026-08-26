// LexHub — `LegalBasisAccordion` BO'SH holati regressiya testi.
//
// O'LCHANGAN DEFEKT ZANJIRI (2026-08-26 audit, ikkita bog'liq nuqson):
//
//  1. `LegalKnowledgeRetriever.retrieveRelevantChunks` nol ball holatida
//     korpusning BIRINCHI 3 moddasini (Konstitutsiya) qaytarardi.
//  2. `legal_assistant_remote_datasource.dart` grounding filtri HAMMASINI rad
//     etganda filtrlanmagan xom chunk'larni `legalBasis`ga qayta tiklardi.
//
// Natijada korpusdan tashqaridagi savolga (soliq, litsenziya, bojxona)
// foydalanuvchi o'z holatiga ALOQASI YO'Q Konstitutsiya moddalarini
// "Qonuniy asoslar" sifatida ko'rardi.
//
// Ikkisi tuzatilgandan keyin `legalBasis` haqiqatan bo'sh bo'lishi mumkin.
// Bu widget ilgari bo'sh ro'yxatda `SizedBox.shrink()` qaytarardi — ya'ni
// JIMGINA yo'qolardi va foydalanuvchi javob qonuniy asosga ega emasligini
// bilmasdi. Shu test halol ogohlantirish KO'RSATILISHINI qulflaydi.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/features/legal_assistant/domain/entities/law_article.dart';
import 'package:lexhub/features/legal_assistant/presentation/widgets/legal_basis_accordion.dart';
import 'package:lexhub/l10n/gen/app_localizations.dart';

import '../../../../support/l10n_test_app.dart';

void main() {
  const article = LawArticle(
    lawName: "O'zbekiston Respublikasining Mehnat kodeksi",
    articleNumber: '161',
    articleTitle: 'Mehnat shartnomasini ish beruvchi tashabbusi bilan bekor '
        'qilish',
    articleText: 'Ish beruvchi mehnat shartnomasini faqat qonunda nazarda '
        'tutilgan asoslar bo\'yicha bekor qilishi mumkin.',
    lexUrl: 'https://lex.uz/docs/6257288',
  );

  Future<void> pumpAccordion(
    WidgetTester tester,
    List<LawArticle> articles, {
    Locale locale = const Locale('uz'),
  }) async {
    await tester.pumpWidget(
      l10nTestApp(
        Scaffold(
          body: SingleChildScrollView(
            child: LegalBasisAccordion(articles: articles),
          ),
        ),
        locale: locale,
      ),
    );
    await tester.pumpAndSettle();
  }

  group('LegalBasisAccordion — bo\'sh holat HALOL ogohlantirish beradi', () {
    testWidgets('uz: bo\'sh ro\'yxatda sabab matni ko\'rinadi', (tester) async {
      final l10n = await AppL10n.delegate.load(const Locale('uz'));

      await pumpAccordion(tester, const []);

      expect(find.text(l10n.aiLegalBasisNoneTitle), findsOneWidget,
          reason: 'Bo\'sh holatda sarlavha ko\'rinishi SHART — ilgari widget '
              'jimgina yo\'qolardi');
      expect(find.text(l10n.aiLegalBasisNoneBody), findsOneWidget,
          reason: 'Foydalanuvchi NIMA UCHUN asos yo\'qligini bilishi kerak');
    });

    testWidgets('en: bo\'sh holat ingliz tilida ham lokalizatsiyalangan',
        (tester) async {
      final l10n = await AppL10n.delegate.load(const Locale('en'));

      await pumpAccordion(tester, const [], locale: const Locale('en'));

      expect(find.text(l10n.aiLegalBasisNoneTitle), findsOneWidget);
      expect(find.text(l10n.aiLegalBasisNoneBody), findsOneWidget);
    });

    testWidgets('bo\'sh holatda "tasdiqlangan manba" da\'vosi QILINMAYDI',
        (tester) async {
      final l10n = await AppL10n.delegate.load(const Locale('uz'));

      await pumpAccordion(tester, const []);

      // HALOLLIK: ko'k "Qonuniy asoslar (Lex.uz)" sarlavhasi va Lex.uz manba
      // subtitle'i bo'sh holatda CHIQMASLIGI kerak — aks holda foydalanuvchi
      // tasdiqlangan asos bor deb o'ylaydi.
      expect(find.text(l10n.aiLegalBasisTitle), findsNothing);
      expect(find.text(l10n.aiLexUzBaseSubtitle), findsNothing);
    });

    testWidgets('modda BOR bo\'lsa ogohlantirish CHIQMAYDI (teskari tomon)',
        (tester) async {
      final l10n = await AppL10n.delegate.load(const Locale('uz'));

      await pumpAccordion(tester, const [article]);

      expect(find.text(l10n.aiLegalBasisNoneTitle), findsNothing,
          reason: 'Haqiqiy modda bo\'lganda ogohlantirish yolg\'on signal');
      expect(find.text(l10n.aiLegalBasisTitle), findsOneWidget,
          reason: 'Normal holatda odatdagi sarlavha ko\'rinishi kerak');
    });
  });
}
