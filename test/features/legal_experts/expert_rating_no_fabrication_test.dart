/// §20 QULFI — BAZA ADVOKATGA BAHO TO'QIB BERMAYDI.
///
/// NUQSON (2026-08-30 da tuzatildi): `expert_profiles.rating NUMERIC(3,2)
/// DEFAULT 5.00 NOT NULL` — har bir yangi advokat profili hech kim baho
/// qo'ymagan holda 5 yulduzli tug'ilardi. Bahoni HISOBLAYDIGAN manba yo'q
/// (`reviews` / `expert_reviews` jadvali loyihada mavjud emas, `rating` ni
/// YOZADIGAN kod ham yo'q), ya'ni 5.00 hech qachon haqiqiy bo'lmagan.
///
/// Ekranda ko'rinmasligi UI qulfi tufayli edi (`ExpertRatingStars`
/// `reviewsCount <= 0` bo'lsa chizilmaydi), lekin qiymat `unified_global_search`
/// RPC va `expert_directory` orqali TASHQARIGA chiqadi — ya'ni qulf MANBADA
/// bo'lishi kerak (§14).
///
/// Bu fayl SXEMA MATNINI qulflaydi. Live bazadagi HOLAT esa migratsiya
/// ichidagi server tomonidagi assertionlar bilan o'lchandi
/// (`20260830060000` D1-D4, `20260830061000` A1-A3 — temp jadvalda
/// deploy qilingan ifoda (5.00, 0) ni RAD ETADI). Bu test o'sha o'lchovni
/// TAKRORLAMAYDI — u faqat manba fayl orqaga qaytmasligini qo'riqlaydi.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

/// `--` izohlari olib tashlangan SQL. Izohda nuqson TARIXI yozilgan
/// ("ilgari `DEFAULT 5.00 NOT NULL` edi") — u qulfga ILINMASLIGI kerak,
/// aks holda test o'z hujjatini nuqson deb ko'rsatadi.
String _codeOnly(String sql) => sql
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('--'))
    .join('\n');

void main() {
  final schema = _codeOnly(_read('supabase/schema.sql'));
  final fix =
      _read('supabase/migrations/20260830060000_expert_rating_no_fabrication.sql');
  final proof = _read(
      'supabase/migrations/20260830061000_expert_rating_constraint_runtime_proof.sql');

  group('schema.sql — to\'qima sukut baho QAYTMAYDI', () {
    test('`rating` ustunida `DEFAULT 5.00` YO\'Q', () {
      expect(schema.contains('DEFAULT 5.00'), isFalse,
          reason: 'to\'qima 5 yulduz sukut qiymati qaytdi');
    });

    test('`rating` ustuni NOT NULL EMAS — baho BO\'SH bo\'lishi mumkin', () {
      expect(schema.contains('rating NUMERIC(3, 2) CHECK'), isTrue,
          reason: 'ustun ta\'rifi o\'zgargan — baho yana MAJBURIY bo\'lib '
              'qolmaganini tekshir');
      expect(schema.contains('rating NUMERIC(3, 2) DEFAULT'), isFalse);
      expect(schema.contains('rating NUMERIC(3, 2) NOT NULL'), isFalse);
    });

    test('invariant cheklovi sxemada hujjatlangan', () {
      expect(
          schema.contains('CONSTRAINT expert_profiles_rating_requires_reviews'),
          isTrue);
      expect(schema.contains('CHECK ((rating IS NULL) = (reviews_count = 0))'),
          isTrue);
    });

    test('diapazon cheklovi SAQLANDI (regressiya yo\'q)', () {
      expect(schema.contains('CHECK (rating >= 0.00 AND rating <= 5.00)'),
          isTrue);
    });
  });

  group('tuzatish migratsiyasi — mazmuni', () {
    test('ustun NULL qabul qiladigan holga o\'tkaziladi', () {
      expect(fix.contains('ALTER COLUMN rating DROP NOT NULL'), isTrue);
      expect(fix.contains('ALTER COLUMN rating SET DEFAULT NULL'), isTrue);
    });

    test('faqat MANBASIZ baho NULL ga o\'tadi — haqiqiy baho tegilmaydi', () {
      expect(
          fix.contains('SET rating = NULL\n WHERE reviews_count = 0 '
              'AND rating IS NOT NULL'),
          isTrue,
          reason: 'shartsiz `SET rating = NULL` haqiqiy bahoni ham o\'chiradi');
    });

    test('invariant cheklovi qo\'shiladi', () {
      expect(
          fix.contains('ADD CONSTRAINT expert_profiles_rating_requires_reviews'),
          isTrue);
    });

    test('nuqson mavjudligi QO\'LLASHDAN OLDIN isbotlanadi', () {
      expect(fix.contains('P1 FAILED'), isTrue);
      expect(fix.contains('P2 FAILED'), isTrue,
          reason: 'baho jadvali paydo bo\'lsa "to\'qima" da\'vosi yolg\'on '
              'bo\'ladi — migratsiya to\'xtashi kerak');
      expect(fix.contains('D1 FAILED'), isTrue);
      expect(fix.contains('D2 FAILED'), isTrue);
      expect(fix.contains('D3 FAILED'), isTrue);
      expect(fix.contains('D4 FAILED'), isTrue);
    });

    test('soxta advokat qatori YARATILMAYDI', () {
      expect(fix.contains('INSERT INTO public.expert_profiles'), isFalse,
          reason: 'test uchun ham soxta advokat yozish TAQIQLANGAN');
    });
  });

  group('runtime isbot migratsiyasi — D5 bo\'shlig\'i', () {
    test('cheklov ifodasi KATALOGDAN o\'qib sinaladi', () {
      expect(proof.contains('pg_get_constraintdef'), isTrue);
      expect(proof.contains('CREATE TEMP TABLE lx_rating_probe'), isTrue);
      expect(proof.contains('ON COMMIT DROP'), isTrue,
          reason: 'sinov jadvali bazada QOLMASLIGI kerak');
    });

    test('to\'rt holat sinaladi — rad etish VA qabul qilish', () {
      for (final c in <String>["('5.00, 0', FALSE)", "('NULL, 0', TRUE)",
        "('4.50, 3', TRUE)", "('NULL, 3', FALSE)"]) {
        expect(proof.contains(c), isTrue, reason: '$c holati yo\'q');
      }
    });

    test('o\'lchanmagan narsa HALOL yozilgan', () {
      expect(proof.contains('NOT VERIFIED'), isTrue,
          reason: 'haqiqiy advokat qatorida o\'lchanmaganligi yozilishi kerak');
      expect(proof.contains('INSERT INTO public.expert_profiles'), isFalse);
    });
  });

  group('kelajak migratsiyalari to\'qimani QAYTARMAYDI', () {
    test('20260830060000 dan KEYINGI birorta migratsiya `rating` ga son sukut '
        'qiymat bermaydi', () {
      final files = Directory('supabase/migrations')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.sql'))
          .where((f) => f.path.split(Platform.pathSeparator).last.compareTo(
                  '20260830060000_expert_rating_no_fabrication.sql') >
              0)
          .toList();
      final offenders = <String>[];
      for (final f in files) {
        final code = f
            .readAsStringSync()
            .split('\n')
            .where((l) => !l.trimLeft().startsWith('--'))
            .join('\n');
        if (RegExp(r'rating\s+NUMERIC[^,\n]*DEFAULT\s+[0-9]').hasMatch(code) ||
            RegExp(r'ALTER\s+COLUMN\s+rating\s+SET\s+DEFAULT\s+[0-9]')
                .hasMatch(code)) {
          offenders.add(f.path.split(Platform.pathSeparator).last);
        }
      }
      expect(offenders, isEmpty,
          reason: 'to\'qima baho sukut qiymati qayta kiritilgan');
    });
  });
}
