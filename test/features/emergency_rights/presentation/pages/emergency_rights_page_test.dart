// LexHub — SHOSHILINCH HUQUQLAR EKRANI: XULQ-ATVOR QULFI.
//
// NIMA UCHUN BU FAYL BOR: `emergency_rights_page.dart` — ilovadagi eng
// XAVFLI ekran. Foydalanuvchi unga hibsga olinganda, tintuv paytida yoki
// majburiy mehnatga jalb qilinganda qaraydi. Shu ekrandagi xato (yo'q
// bo'lgan ishonch telefoni, o'chib ketgan huquq, yoki asossiz absolut
// da'vo) real huquqiy zarar keltiradi. 2026-08-30 gacha bu 315 satrli
// sahifada BIRORTA test yo'q edi.
//
// TESTLAR NIMANI USHLAYDI (hammasi EKRAN darajasida, ya'ni "kodda bor"
// emas, "foydalanuvchiga YETIB BORADI"):
//   1. To'rtta ishonch telefoni AYNAN o'z raqami bilan chiqadi.
//   2. To'rtta protokolning HAMMASI chiqadi (biri jim yo'qolmaydi).
//   3. Qoidalar SONI qulflangan — huquq jim o'chirilmaydi.
//   4. Grounding: Konstitutsiya moddalari AYNAN keltirilgan (§3).
//   5. Ekranda ABSOLUT huquqiy da'vo YO'Q (§1).
//   6. `en` locale'da huquqiy matn INGLIZCHA yetib boradi (o'zbekcha
//      qolib ketmaydi) — 1-5 qulflarining hammasi `en` da ham o'lchanadi.
//
// 6-TEST NIMA UCHUN QO'SHILDI (2026-08-30): shu kunga qadar bu sahifadagi
// 21 ta huquqiy matn XOM o'zbekcha literal edi, ya'ni `en` foydalanuvchi
// HIBSGA OLINGANDA o'z huquqlarini TUSHUNMAYDIGAN tilda o'qirdi. Matn ARB'ga
// ko'chirildi; 6-test aynan shu regressni qulflaydi. O'zbekcha satrlar `uz`
// ARB'dan OLINADI (qattiq yozilmaydi), aks holda `uz` matni o'zgarganda
// "yo'q" da'vosi bo'shab qolardi va test o'z signalini yo'qotardi.
//
// 5-TEST HAQIQIY NUQSONNI QAYTA HOSIL QILDI (o'lchandi 2026-08-30): satr 40
// "... deyishga 100% qonuniy haqlisiz." deb yozardi. Bu ASOSSIZ absolut
// kafolat edi — amalda ko'rsatuv berishdan bosh tortish oqibatlari ish
// turiga bog'liq va "100% qonuniy" degan gap foydalanuvchini himoyasiz
// qoldiradi. Test AVVAL QIZIL bo'ldi, keyin matn defensible so'zlashga
// almashtirildi (`.claude/skills/lexhub-legal-answer-safety` §1).
//
// TELEFON QILISH XULQI TEST QILINMAYDI (halol cheklov): `_call()`
// `url_launcher` platform kanalini chaqiradi va uni faking qilish
// `UrlLauncherPlatform` ni almashtirishni talab qiladi. Pump paytida
// `_call()` ISHLAMAYDI (faqat `onTap` da), shuning uchun bu testlar
// plaginga tegmaydi. `emergencyCallFailed` SnackBar yo'li — NOT VERIFIED.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/features/emergency_rights/presentation/pages/emergency_rights_page.dart';
import 'package:lexhub/l10n/gen/app_localizations.dart';

import '../../../../support/l10n_test_app.dart';
import '../../../../support/legal_absolutes.dart';

/// Ekranda AYNAN ko'rinadigan barcha matn. `SingleChildScrollView` bolalarni
/// DARHOL quradi (lazy emas), shuning uchun skroll qilish shart emas —
/// pastdagi protokollar ham widget daraxtida bo'ladi.
List<String> _screenTexts(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .where((s) => s.trim().isNotEmpty)
    .toList();

/// To'rtta protokol sarlavhasi — ARB'DAN olinadi, testda qattiq YOZILMAYDI.
///
/// Ilgari bu ro'yxat `const` o'zbekcha literal edi. Matn ARB'ga ko'chgach
/// shunday ro'yxat IKKINCHI manbaga aylanardi: ARB'da so'z o'zgarsa test
/// qizil bo'lib, "protokol yo'qoldi" degan YOLG'ON signal berardi.
List<String> _protocolTitles(AppL10n l10n) => [
      l10n.emergencyProtocolArrestTitle,
      l10n.emergencyProtocolSearchTitle,
      l10n.emergencyProtocolTrafficTitle,
      l10n.emergencyProtocolForcedLaborTitle,
    ];

void main() {
  /// Sahifani pump qiladi va AYNAN pump qilingan locale'ning `AppL10n` ini
  /// qaytaradi (kutilgan matnni shu yerdan olish uchun).
  Future<AppL10n> pumpPage(
    WidgetTester tester, {
    Locale locale = const Locale('uz'),
  }) async {
    await tester.pumpWidget(
      l10nTestApp(const EmergencyRightsPage(), locale: locale),
    );
    await tester.pumpAndSettle();
    return AppL10n.of(tester.element(find.byType(EmergencyRightsPage)));
  }

  testWidgets('to\'rtta ishonch telefoni AYNAN o\'z raqami bilan chiqadi',
      (tester) async {
    await pumpPage(tester);

    // Raqamlar ATAYLAB qattiq yozilgan: ular davlat xizmatlari raqamlari va
    // tarjimaga bog'liq emas. Prokuratura / IIV / Ombudsman / Mehnat
    // inspeksiyasi.
    for (final phone in ['1002', '102', '1096', '1092']) {
      expect(find.text(phone), findsOneWidget,
          reason: 'Ishonch telefoni $phone ekranda YO\'Q. Bu shoshilinch '
              'holatda foydalanuvchini yordamsiz qoldiradi.');
    }
  });

  testWidgets('to\'rtta protokolning HAMMASI chiqadi', (tester) async {
    final l10n = await pumpPage(tester);

    for (final title in _protocolTitles(l10n)) {
      expect(find.text(title), findsOneWidget,
          reason: '"$title" protokoli ekranda YO\'Q.');
    }
  });

  testWidgets('qoidalar SONI qulflangan — huquq jim o\'chmaydi',
      (tester) async {
    await pumpPage(tester);

    // O'LCHANGAN 2026-08-30: 4 + 3 + 3 + 3 = 13 qoida. Har bir qoida oldida
    // AYNAN bitta `shield_outlined` ikonkasi bor va bu ikonka shu sahifada
    // BOSHQA joyda ishlatilmaydi, shuning uchun ikonka soni = qoida soni.
    expect(find.byIcon(Icons.shield_outlined), findsNWidgets(13),
        reason: 'Qoidalar soni o\'zgardi. KAMAYSA — huquq ekrandan '
            'YO\'QOLGAN (jim regress). OSHSA — yangi qoida qo\'shilgan: '
            'grounding (modda/kodeks) borligini tekshirib, bu sonni YANGI '
            'o\'lchov bilan yangila.');
  });

  testWidgets('grounding: Konstitutsiya moddalari AYNAN keltirilgan',
      (tester) async {
    await pumpPage(tester);
    final texts = _screenTexts(tester).join('\n');

    for (final citation in [
      'Konstitutsiya 28-moddasi',
      'Konstitutsiya 44-moddasi',
    ]) {
      expect(texts.contains(citation), isTrue,
          reason: '"$citation" ekranda YO\'Q. `lexhub-legal-answer-safety` '
              '§3: huquqiy da\'vo modda darajasida asoslanishi shart.');
    }
  });

  testWidgets('ekranda ABSOLUT huquqiy da\'vo YO\'Q', (tester) async {
    await pumpPage(tester);

    final offenders = _screenTexts(tester)
        .where(forbiddenLegalAbsolutes.hasMatch)
        .toList();

    expect(offenders, isEmpty,
        reason: 'ABSOLUT HUQUQIY DA\'VO EKRANDA (§1). Topildi:\n'
            '${offenders.join('\n')}\n\n'
            'Absolut kafolat foydalanuvchini himoyasiz qoldiradi: natija '
            'ish turiga, dalillarga va sud amaliyotiga bog\'liq. Defensible '
            'so\'zlash ishlat ("haqlisiz", "shart", "taqiqlanadi") yoki '
            'moddani AYNAN keltir.');
  });

  testWidgets('en locale: huquqiy matn INGLIZCHA yetib boradi',
      (tester) async {
    final en = await pumpPage(tester, locale: const Locale('en'));
    // `uz` matni ham ARB'DAN olinadi (ikkinchi manba yaratmaslik uchun):
    // sahifani qayta pump qilmasdan, delegat orqali.
    final uz = await AppL10n.delegate.load(const Locale('uz'));
    final texts = _screenTexts(tester);

    for (final title in _protocolTitles(en)) {
      expect(find.text(title), findsOneWidget,
          reason: '"$title" (en) ekranda YO\'Q — `en` foydalanuvchi shu '
              'protokolni KO\'RMAYDI.');
    }

    // AYNAN O'LCHANGAN REGRESS (2026-08-30): `en` locale'da o'zbekcha
    // sarlavha yoki qoida ekranga CHIQMASLIGI shart.
    final uzLeaks = [
      ..._protocolTitles(uz),
      uz.emergencyProtocolArrestRule1,
      uz.emergencyProtocolForcedLaborRule1,
    ];
    for (final leak in uzLeaks) {
      expect(texts.contains(leak), isFalse,
          reason: 'O\'ZBEKCHA MATN `en` EKRANDA: "$leak". Hibsga olingan '
              'foydalanuvchi o\'z huquqini TUSHUNMAYDIGAN tilda o\'qiydi.');
    }
    // ATAYLAB ISTISNO: `Rule2` inglizchada ham AYTILADIGAN o'zbekcha iborani
    // saqlaydi ("Advokatim kelmaguncha ko'rsatuv bermayman") — huquqiy vazni
    // aynan shu so'zlashuvda, tarjimasi yonida izoh sifatida beriladi.
    expect(en.emergencyProtocolArrestRule2.contains("ko'rsatuv bermayman"),
        isTrue,
        reason: 'Inglizcha matndan AYTILADIGAN o\'zbekcha ibora tushib '
            'qolgan: foydalanuvchi AYNAN nima deyishini bilmaydi.');

    // 3- va 4-qulf `en` da ham amal qiladi.
    expect(find.byIcon(Icons.shield_outlined), findsNWidgets(13),
        reason: 'Qoidalar soni `en` da `uz` dan FARQ qiladi — bitta '
            'locale\'da huquq tushib qolgan (jim regress).');
    for (final citation in [
      'Article 28 of the Constitution',
      'Article 44 of the Constitution',
    ]) {
      expect(texts.join('\n').contains(citation), isTrue,
          reason: '"$citation" `en` ekranda YO\'Q (§3: grounding modda '
              'darajasida bo\'lishi shart).');
    }

    // §1 `en` da ILK MARTA o'lchanadi: `forbiddenLegalAbsolutes` ga shu kuni
    // ingliz naqshlari qo'shildi, aks holda bu da'vo BO'SH bo'lardi.
    final offenders = texts.where(forbiddenLegalAbsolutes.hasMatch).toList();
    expect(offenders, isEmpty,
        reason: 'ABSOLUT HUQUQIY DA\'VO `en` EKRANDA (§1). Topildi:\n'
            '${offenders.join('\n')}');
  });
}
