/// HUDUD FILTRI — QULF.
///
/// NUQSON (o'lchangan): `city` ustuni bazada UMUMAN YO'Q, filtr esa
/// `.ilike('workplace', '%$city%')` ga ketadi. Dropdown qiymatlari
/// "Toshkent sh." / "Samarqand sh." ko'rinishida edi — `ilike` da `sh.`
/// ODDIY BELGILAR, ya'ni real ish joyi matni ("Toshkent shahar advokatlar
/// hay'ati") HECH QACHON topilmasdi. Filtr texnik jihatdan ishlagan, natijasi
/// esa doim bo'sh — foydalanuvchi buni "bu hududda advokat yo'q" deb o'qiydi.
///
/// Bu fayl uchta narsani qulflaydi:
///   1. FILTR QIYMATI — hudud O'ZAGI, `sh.`/`viloyati` qo'shimchasi YO'Q,
///      ya'ni `ilike` real matnni topadi.
///   2. AJRATISH — `workplace` matnidan hudud deterministik olinadi va
///      topilmasa `null` qaytadi (to'qima qiymat yo'q).
///   3. ULANISH — sahifa va model manbasi AYNI ro'yxatdan foydalanadi.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/constants/uzbek_regions.dart';
import 'package:lexhub/core/localization/expert_labels.dart';
import 'package:lexhub/features/legal_experts/data/models/legal_expert_model.dart';

void main() {
  group('FILTR QIYMATI — `ilike` real matnni TOPADI', () {
    test('qiymatlarda `sh.` / `viloyati` qo\'shimchasi YO\'Q', () {
      for (final raw in UzbekRegions.regions) {
        expect(raw.contains('sh.'), isFalse,
            reason: '"$raw" — `ilike` da `sh.` literal belgi, moslik buziladi');
        expect(raw.toLowerCase().contains('viloyat'), isFalse,
            reason: '"$raw" — o\'zak emas, ish joyi matniga mos kelmaydi');
      }
    });

    test('sentinel BIRINCHI va hududlar ro\'yxatiga TUSHMAYDI', () {
      expect(UzbekRegions.filterValues.first, UzbekRegions.allSentinel);
      expect(UzbekRegions.regions.contains(UzbekRegions.allSentinel), isFalse);
      expect(UzbekRegions.regions.length, 13,
          reason: 'O\'zbekiston hududlari soni o\'zgargan — sabab yozilishi '
              'kerak');
    });

    test('sentinel `expertCityLabel` da tarjima qilinadi, hudud nomi YO\'Q',
        () {
      // Atoqli nom tarjima qilinmaydi; sentinel esa ARB dan keladi.
      // `expert_labels.dart` sentinel'ni AYNAN shu satr bilan taqqoslaydi.
      final src =
          File('lib/core/localization/expert_labels.dart').readAsStringSync();
      expect(src.contains("raw == 'Barcha viloyatlar'"), isTrue,
          reason: 'sentinel matni o\'zgargan — dropdown yorlig\'i buziladi');
      expect(UzbekRegions.allSentinel, 'Barcha viloyatlar');
    });
  });

  group('AJRATISH — `workplace` matnidan hudud', () {
    test('real ish joyi matnlari to\'g\'ri hududga tushadi', () {
      const cases = <String, String>{
        'Toshkent shahar advokatlar hay\'ati': 'Toshkent',
        'Toshkent viloyati advokatura boshqarmasi': 'Toshkent',
        '"Adolat" advokatlik byurosi, Samarqand': 'Samarqand',
        'Andijon shahridagi yuridik markaz': 'Andijon',
        'Buxoro viloyat sudi': 'Buxoro',
        'Xorazm advokatlar palatasi': 'Xorazm',
      };
      cases.forEach((workplace, expected) {
        expect(UzbekRegions.regionOf(workplace), expected,
            reason: '"$workplace" -> $expected kutilgan');
      });
    });

    test('apostrof va registr variantlari BIR XIL natija beradi', () {
      // Bazadagi matn qo'lda kiritiladi: `Farg'ona`, `Farg‘ona`, `FARGONA`.
      for (final variant in <String>[
        "Farg'ona advokatlik byurosi",
        'Farg‘ona advokatlik byurosi',
        'FARGONA ADVOKATLIK BYUROSI',
        'fargona advokatlik byurosi',
      ]) {
        expect(UzbekRegions.regionOf(variant), "Farg'ona",
            reason: 'normalizatsiya ishlamadi: "$variant"');
      }
      expect(UzbekRegions.regionOf('Qoraqalpogiston respublika sudi'),
          "Qoraqalpog'iston");
    });

    test('HALOL null — taxmin QILINMAYDI', () {
      for (final workplace in <String?>[
        null,
        '',
        '   ',
        'Advokatlik byurosi',
        'Yuridik xizmatlar markazi',
      ]) {
        expect(UzbekRegions.regionOf(workplace), isNull,
            reason: 'hudud TAXMIN qilindi: "$workplace"');
      }
    });

    test('natija DETERMINISTIK', () {
      const w = 'Samarqand va Buxoro filiallari';
      expect(UzbekRegions.regionOf(w), UzbekRegions.regionOf(w));
      // `regions` tartibi bo'yicha birinchisi — `Buxoro` `Samarqand` dan
      // oldin keladi.
      expect(UzbekRegions.regionOf(w), 'Buxoro');
    });
  });

  group('ULANISH — manba qulfi', () {
    String code(String path) => File(path)
        .readAsStringSync()
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');

    test('sahifa `UzbekRegions.filterValues` dan foydalanadi', () {
      final src = code(
        'lib/features/legal_experts/presentation/pages/legal_experts_page.dart',
      );
      expect(src.contains('_cities = UzbekRegions.filterValues'), isTrue,
          reason: 'dropdown yana qattiq kodlangan ro\'yxatga qaytgan');
      expect(src.contains('"Toshkent sh."'), isFalse,
          reason: '`sh.` qo\'shimchali qiymat qaytgan — filtr yana bo\'sh '
              'natija beradi');
      expect(src.contains('UzbekRegions.allSentinel'), isTrue);
    });

    test('model hududni `workplace` dan ajratadi', () {
      final src = code(
        'lib/features/legal_experts/data/models/legal_expert_model.dart',
      );
      expect(src.contains('UzbekRegions.regionOf(workplace)'), isTrue,
          reason: '`city` yana doimiy bo\'sh string bo\'lib qolgan');
    });

    test('datasource `workplace` ustuniga filtrlaydi', () {
      final src = code(
        'lib/features/legal_experts/data/datasources/'
        'legal_experts_remote_datasource.dart',
      );
      // `city` ustuni YO'Q — unga filtrlash `PGRST` xatosi beradi.
      expect(src.contains("ilike('workplace', '%\$city%')"), isTrue);
      expect(src.contains("ilike('city'"), isFalse,
          reason: 'mavjud bo\'lmagan `city` ustuniga filtr qaytgan');
    });
  });

  test('MODEL — `city` maydoni `workplace` dan to\'ldiriladi', () {
    // View AYNI shu ustunlarni qaytaradi: `city` YO'Q, `workplace` BOR.
    final m = LegalExpertModel.fromJson(<String, dynamic>{
      'expert_id': '11111111-1111-1111-1111-111111111111',
      'full_name': 'Test Advokat',
      'specialization': 'Mehnat',
      'workplace': 'Toshkent shahar advokatlar hay\'ati',
    });
    expect(m.city, 'Toshkent',
        reason: 'kartada hudud yana ko\'rinmaydi');
    expect(expertLocationText(m).startsWith('Toshkent'), isTrue);

    // Hudud nomi yo'q ish joyi — hudud satri UMUMAN chiqmaydi.
    final unknown = LegalExpertModel.fromJson(<String, dynamic>{
      'expert_id': '22222222-2222-2222-2222-222222222222',
      'full_name': 'Test Advokat',
      'workplace': 'Advokatlik byurosi',
    });
    expect(unknown.city, '');
    expect(expertLocationText(unknown), 'Advokatlik byurosi',
        reason: 'to\'qima hudud qo\'shildi');
  });
}
