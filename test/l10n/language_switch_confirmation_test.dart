import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/localization/app_locales.dart';
import 'package:lexhub/core/localization/l10n.dart';

/// Til almashtirish tasdig'i YANGI tilda chiqishini qulflaydi.
///
/// REAL QURILMADAGI NUQSON (emulator-5554, release APK, 23-avgust):
/// Sozlamalar → Til → English tanlangandan keyin ekran to'liq inglizchaga
/// o'tdi ("Language", "The selected language applies to the whole app..."),
/// LEKIN pastdagi SnackBar O'ZBEKCHA chiqdi: "Til o'zgartirildi: English".
///
/// Sabab: `Localizations` delegate'i asinxron yuklanadi, shuning uchun
/// `cubit.select()`dan keyingi microtask'da `AppL10n.of(context)` hali eski
/// (uz) obyektni qaytaradi. `LanguageSettingsPage` endi `lookupAppL10n(locale)`
/// orqali TANLANGAN til uchun tarjimani to'g'ridan-to'g'ri oladi.
void main() {
  test('languageChangedTo har bir til uchun O\'Z tilida qaytadi', () {
    final uz = lookupAppL10n(AppLocales.uzbek);
    final en = lookupAppL10n(AppLocales.english);

    final uzMsg = uz.languageChangedTo(AppLocales.nativeName(AppLocales.uzbek));
    final enMsg = en.languageChangedTo(AppLocales.nativeName(AppLocales.english));

    expect(uzMsg, contains('Til'),
        reason: 'O\'zbekcha tanlanganda o\'zbekcha tasdiq');
    expect(enMsg, contains('Language'),
        reason: 'English tanlanganda INGLIZCHA tasdiq — regressiya qulfi');
    expect(enMsg, isNot(contains('o\'zgartirildi')),
        reason: 'English rejimida o\'zbekcha matn QOLMASLIGI kerak');
  });

  test('qo\'llab-quvvatlanadigan tillar: faqat uz va en (ru UI\'da yo\'q)', () {
    expect(AppLocales.supported.map((l) => l.languageCode).toList(),
        equals(['uz', 'en']));
    expect(AppLocales.fallback, equals(AppLocales.uzbek),
        reason: 'DEFAULT til — o\'zbekcha');
  });

  test('lookupAppL10n noma\'lum til uchun ham yiqilmaydi', () {
    // `ru` arxitektura darajasida tayyor, lekin ARB yo'q — shuning uchun
    // UI ro'yxatida ham yo'q. Bu test faqat `supported` ro'yxatidan
    // tashqarida tasodifan chaqiruv bo'lsa xatti-harakat aniq bo'lishi uchun.
    expect(() => lookupAppL10n(const Locale('ru')), throwsA(isA<Object>()));
  });
}
