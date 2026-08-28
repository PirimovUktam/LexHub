/// `LexBottomNav` — INDEKS XARITASI qulfi.
///
/// NIMA UCHUN BU TEST BOR: UI redesign'da pastki panelning KO'RSATISH tartibi
/// o'zgardi (markazda ko'tarilgan "Maslahat"), lekin `MainNavigationPage`
/// ichidagi `IndexedStack` tartibi ATAYLAB o'zgarmadi:
///
///   0 Bosh sahifa · 1 Maslahat · 2 Hamjamiyat · 3 Xizmatlar · 4 Kabinet
///
/// `HomePage(onAskAITap: () => _navigateToTab(1))` va ikki
/// `onSendQueryToAI: (q) { _navigateToTab(1); }` chaqiruvi SHU raqamlarga
/// bog'langan. Agar kimdir `_NavSlot.stackIndex` ni ko'rsatish tartibi bilan
/// "tartibga solsa", tugmalar boshqa ekranga olib boradi va bu JIMGINA
/// regressiya bo'ladi — analyze ham, mavjud testlar ham topmaydi.
///
/// Shuning uchun bu yerda HAR BIR slot bosiladi va `onSelect` HAQIQATDA
/// qaysi indeksni olganini tekshiriladi.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/features/main_navigation/presentation/widgets/lex_bottom_nav.dart';
import 'package:lexhub/l10n/gen/app_localizations.dart';

import '../../../../support/l10n_test_app.dart';

void main() {
  late AppL10n uz;

  setUpAll(() async {
    uz = await AppL10n.delegate.load(const Locale('uz'));
  });

  /// Panelni yakka o'zi pump qiladi — `MainNavigationPage` ning DI grafigi
  /// (get_it, Supabase) kerak emas, chunki tekshirilayotgan narsa faqat
  /// indeks xaritasi.
  Future<List<int>> tapAll(
    WidgetTester tester,
    List<String> labels, {
    int currentIndex = 0,
  }) async {
    final received = <int>[];
    await tester.pumpWidget(
      l10nTestApp(
        Scaffold(
          bottomNavigationBar: LexBottomNav(
            currentIndex: currentIndex,
            onSelect: received.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final label in labels) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }
    return received;
  }

  group('LexBottomNav — IndexedStack indekslari', () {
    testWidgets('beshta yorliq ham ko\'rinadi', (tester) async {
      await tapAll(tester, const []);

      for (final label in <String>[
        uz.navHome,
        uz.navCommunity,
        uz.navAI,
        uz.navServices,
        uz.navCabinet,
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('har bir slot O\'ZINING stack indeksini yuboradi',
        (tester) async {
      final received = await tapAll(tester, <String>[
        uz.navHome,
        uz.navCommunity,
        uz.navAI,
        uz.navServices,
        uz.navCabinet,
      ]);

      // Ko'rsatish tartibi: Bosh sahifa, Hamjamiyat, [Maslahat], Xizmatlar,
      // Kabinet. Kutilgan STACK indekslari esa quyidagicha — 1 va 2 O'RIN
      // ALMASHGAN, chunki markazdagi harakat `IndexedStack` da 1-o'rinda.
      expect(received, <int>[0, 2, 1, 3, 4],
          reason: 'Indeks xaritasi buzildi: `onAskAITap` endi boshqa ekranni '
              'ochadi (`MainNavigationPage` ichidagi tartib 0 Bosh sahifa, '
              '1 Maslahat, 2 Hamjamiyat, 3 Xizmatlar, 4 Kabinet)');
    });

    testWidgets('yorliq ekran o\'quvchiga IKKI MARTA o\'qilmaydi',
        (tester) async {
      // O'LCHANGAN NUQSON: tashqi `Semantics(label:)` qobig'i ostidagi
      // `Text` semantikasi bilan QO'SHILADI, natijada `SemanticsNode.label`
      // "Maslahat\nMaslahat" bo'lib qolardi va TalkBack yorliqni ikki marta
      // o'qirdi. Tashqi `label:` olib tashlangandan keyin yagona qoladi.
      await tapAll(tester, const [], currentIndex: 1);

      for (final label in <String>[
        uz.navHome,
        uz.navCommunity,
        uz.navAI,
        uz.navServices,
        uz.navCabinet,
      ]) {
        expect(tester.getSemantics(find.text(label)).label, label,
            reason: 'Semantics yorlig\'i takrorlangan: $label');
      }
    });
    testWidgets('en: yorliqlar ingliz tilida chiqadi', (tester) async {
      // §7 — "English tanlanganda HAMMASI tarjima bo'lsin". ZONE A skaneri
      // faqat literal YO'QLIGINI isbotlaydi; bu test yorliqlar HAQIQATDA
      // `en` ARB'dan o'qilishini ko'rsatadi.
      final en = await AppL10n.delegate.load(const Locale('en'));

      await tester.pumpWidget(
        l10nTestApp(
          Scaffold(
            bottomNavigationBar: LexBottomNav(
              currentIndex: 0,
              onSelect: (_) {},
            ),
          ),
          locale: const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();

      for (final label in <String>[
        en.navHome,
        en.navCommunity,
        en.navAI,
        en.navServices,
        en.navCabinet,
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      // O'zbekcha yorliq QOLMASIN (uz va en qiymatlari bir xil bo'lsa bu
      // tekshiruv ma'nosiz bo'lardi — shuning uchun farqli kalit tanlandi).
      expect(uz.navHome == en.navHome, isFalse,
          reason: 'navHome tarjimasi yo\'q — `arb_parity_test` ham ogohlantiradi');
      expect(find.text(uz.navHome), findsNothing);
    });
  });
}
