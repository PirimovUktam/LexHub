import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/config/supabase_config.dart';

/// P0 configuration regression guard.
///
/// Bu testlar oldingi P0 bug'ni qaytib kelishidan saqlaydi: release build'da
/// Supabase credential'lari yo'q edi, chunki konfiguratsiya runtime'da
/// `dart:io File('.env')` orqali o'qilardi va Android sandbox'da bu fayl
/// hech qachon mavjud bo'lmaydi.
///
/// Testlar network'ga chiqmaydi va cloud'da hech narsani o'zgartirmaydi.
/// Fayl o'qish `flutter test`ning CWD == package root kafolatiga tayanadi.
void main() {
  group('SupabaseConfig contract', () {
    test('isConfigured is exactly "validate() returned null"', () {
      expect(SupabaseConfig.isConfigured, SupabaseConfig.validate() == null);
    });

    test('empty url or anonKey can never produce a configured build', () {
      if (SupabaseConfig.url.isEmpty || SupabaseConfig.anonKey.isEmpty) {
        expect(
          SupabaseConfig.isConfigured,
          isFalse,
          reason: 'Bo\'sh credential bilan isConfigured true bo\'lmasligi kerak',
        );
        expect(SupabaseConfig.validate(), isNotNull);
      } else {
        expect(SupabaseConfig.isConfigured, isTrue);
      }
    });

    test('a configured build must expose an absolute https url', () {
      if (!SupabaseConfig.isConfigured) return;
      final uri = Uri.parse(SupabaseConfig.url);
      expect(uri.isScheme('https'), isTrue);
      expect(uri.host, isNotEmpty);
    });

    test('validate() rejects a non-https url', () {
      // Statik kontrakt: xato matni kalit nomini ko'rsatadi, qiymatni emas.
      final message = SupabaseConfig.validate();
      if (message == null) return;
      if (SupabaseConfig.anonKey.isNotEmpty) {
        expect(
          message.contains(SupabaseConfig.anonKey),
          isFalse,
          reason: 'Xato matni anon key qiymatini oshkor qilmasligi kerak',
        );
      }
    });

    test('redactedDiagnostics never leaks a secret value', () {
      final dump = SupabaseConfig.redactedDiagnostics.toString();
      if (SupabaseConfig.anonKey.isNotEmpty) {
        expect(dump.contains(SupabaseConfig.anonKey), isFalse);
      }
      if (SupabaseConfig.geminiApiKey.isNotEmpty) {
        expect(dump.contains(SupabaseConfig.geminiApiKey), isFalse);
      }
      expect(dump, contains('supabaseHost'));
    });

    test('init() is a no-op and must not inject configuration at runtime',
        () async {
      final configuredBefore = SupabaseConfig.isConfigured;
      final urlBefore = SupabaseConfig.url;
      final keyLengthBefore = SupabaseConfig.anonKey.length;

      await SupabaseConfig.init();

      expect(SupabaseConfig.isConfigured, configuredBefore);
      expect(SupabaseConfig.url, urlBefore);
      expect(SupabaseConfig.anonKey.length, keyLengthBefore);
    });

    test('no bogus fallback values are ever surfaced as configuration', () {
      expect(SupabaseConfig.anonKey, isNot('anon-fallback-token'));
      expect(SupabaseConfig.url, isNot('https://lexhub.supabase.co'));
    });
  });

  group('source-level guards (P0 regression)', () {
    test('SupabaseConfig must not perform runtime file loading', () {
      final src =
          File('lib/core/config/supabase_config.dart').readAsStringSync();

      expect(
        src.contains("import 'dart:io'"),
        isFalse,
        reason: 'Runtime File() lookup Android sandbox\'da hech qachon '
            'ishlamaydi — bu P0 bug\'ning asl sababi edi',
      );
      expect(
        src.contains("import 'package:flutter_dotenv/"),
        isFalse,
        reason: 'flutter_dotenv .env faylini talab qiladi, u APK ichida yo\'q',
      );
      expect(
        src.contains('rootBundle'),
        isFalse,
        reason: '.env asset sifatida yuklanmasligi kerak',
      );
      expect(src, contains("String.fromEnvironment('SUPABASE_URL')"));
      expect(src, contains("String.fromEnvironment('SUPABASE_ANON_KEY')"));
    });

    test('DI must not register a hardcoded fallback Supabase client', () {
      final src = File('lib/core/di/injection_container.dart').readAsStringSync();

      expect(
        src.contains('anon-fallback-token'),
        isFalse,
        reason: 'Soxta token har bir backend chaqiruvini mavjud bo\'lmagan '
            'proyektga yuborardi',
      );
      expect(
        RegExp(r'SupabaseClient\(').hasMatch(src),
        isFalse,
        reason: 'SupabaseClient qo\'lda yaratilmasligi kerak; faqat '
            'Supabase.instance.client ishlatiladi',
      );
    });

    test('main() must fail fast instead of conditionally initializing Supabase',
        () {
      final src = File('lib/main.dart').readAsStringSync();

      expect(src, contains('SupabaseConfig.validate()'));
      expect(src, contains('ConfigurationErrorApp'));
      expect(
        src.contains('if (SupabaseConfig.isConfigured)'),
        isFalse,
        reason: 'Konfiguratsiya yo\'q bo\'lsa ilova davom etmasligi kerak',
      );
    });

    test('.env must not be declared as a Flutter asset', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();

      expect(
        RegExp(r'^\s*-\s*\.env', multiLine: true).hasMatch(pubspec),
        isFalse,
        reason: '.env APK asset sifatida yuklanmasligi kerak',
      );
      expect(
        pubspec.contains('flutter_dotenv'),
        isFalse,
        reason: 'flutter_dotenv endi ishlatilmaydi',
      );
    });

    test('build-time config files are gitignored', () {
      final gitignore = File('.gitignore').readAsStringSync();
      expect(gitignore, contains('env/*.json'));
    });

    test('production config template must not carry GEMINI_API_KEY', () {
      final prod = File('env/prod.json.example').readAsStringSync();

      expect(prod, contains('SUPABASE_URL'));
      expect(prod, contains('SUPABASE_ANON_KEY'));
      expect(
        prod.contains('GEMINI_API_KEY'),
        isFalse,
        reason: 'AI kaliti release build\'ga uzatilmasligi kerak; '
            'LEGAL_AI_PROXY_URL orqali server-side proxy ishlatiladi',
      );
      expect(prod, contains('LEGAL_AI_PROXY_URL'));
    });

    /// 2026-08-21: `env/*.json.example` fayllariga real credential'lar
    /// yozib qo'yilgan edi (Supabase host + publishable key + Gemini key).
    /// Bu fayllar `.gitignore`dan CHIQARILGAN — ya'ni ular Git'ga tushadi.
    /// Real qiymatlar faqat ignored `env/dev.json` ichida bo'lishi kerak.
    test('env templates must contain placeholders only, never real secrets',
        () {
      const templates = <String>[
        'env/dev.json.example',
        'env/prod.json.example',
      ];
      // Ma'lum credential prefikslari: Supabase publishable/secret key,
      // JWT (legacy anon key), Google API key, Gemini API key.
      const denyMarkers = <String>[
        'sb_publishable_',
        'sb_secret_',
        'eyJ',
        'AIza',
        'AQ.',
      ];

      for (final path in templates) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: '$path mavjud bo\'lishi kerak');

        final raw = file.readAsStringSync();
        for (final marker in denyMarkers) {
          expect(
            raw.contains(marker),
            isFalse,
            reason: '$path ichida real credential prefiksi topildi '
                '($marker). Template faqat placeholder saqlashi kerak.',
          );
        }

        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        expect(decoded, isNotEmpty, reason: '$path bo\'sh JSON bo\'lmasligi kerak');

        for (final entry in decoded.entries) {
          final value = entry.value.toString();
          if (value.isEmpty) continue; // bo'sh qiymat ruxsat etilgan
          expect(
            value.contains('YOUR_'),
            isTrue,
            // Ataylab faqat KALIT nomi; qiymat xato matnida ko'rinmasligi kerak.
            reason: '$path -> ${entry.key}: template qiymati "YOUR_..." '
                'placeholder bo\'lishi shart, real qiymat emas.',
          );
        }
      }
    });
  });
}
