import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/legal_safety/legal_grounding_validator.dart';
import 'package:lexhub/core/legal_safety/pii_anonymizer.dart';

void main() {
  group('P0-1: PII Sanitization & Zero Raw Leak Test', () {
    test('strictly masks phone, passport, PINFL, bank card, and email', () {
      const sensitiveInput =
          "Mening ismim Bobur, telefonim +998901234567, pasportim AA 7654321, JSHSHIR 31201991234567, karta 8600 1234 5678 9012, email bobur@gmail.com";

      final sanitized = PiiAnonymizer.anonymize(sensitiveInput);

      // Verify that NO raw sensitive strings remain in the output
      expect(sanitized, isNot(contains('+998901234567')));
      expect(sanitized, isNot(contains('901234567')));
      expect(sanitized, isNot(contains('AA 7654321')));
      expect(sanitized, isNot(contains('7654321')));
      expect(sanitized, isNot(contains('31201991234567')));
      expect(sanitized, isNot(contains('8600 1234 5678 9012')));
      expect(sanitized, isNot(contains('bobur@gmail.com')));

      // Verify masked placeholder tokens are inserted
      expect(sanitized, contains('[Telefon yashirildi]'));
      expect(sanitized, contains('[Pasport yashirildi]'));
      expect(sanitized, contains('[JSHSHIR yashirildi]'));
      expect(sanitized, contains('[Karta raqami yashirildi]'));
      expect(sanitized, contains('[Email yashirildi]'));
    });

    test('masks variations of phone numbers without international prefix', () {
      const localPhone = "Aloqaga chiqing: (90) 123-45-67 yoki 93 987 65 43";
      final sanitized = PiiAnonymizer.anonymize(localPhone);

      expect(sanitized, isNot(contains('90) 123-45-67')));
      expect(sanitized, isNot(contains('93 987 65 43')));
      expect(sanitized, contains('[Telefon yashirildi]'));
    });

    test('masks lowercase passport series properly', () {
      const passportInput = "Hujjat raqamim ab 1234567 yoki fa7654321";
      final sanitized = PiiAnonymizer.anonymize(passportInput);

      expect(sanitized, isNot(contains('ab 1234567')));
      expect(sanitized, isNot(contains('fa7654321')));
      expect(sanitized, contains('[Pasport yashirildi]'));
    });
  });

  group('P0-2 to P0-5: Database Schema & RLS Hardening Verification', () {
    late String schemaContent;

    setUpAll(() {
      final file = File('supabase/schema.sql');
      expect(file.existsSync(), isTrue, reason: 'supabase/schema.sql must exist');
      // MEASURED (2026-09-02): the privacy-shield assertion below matches a
      // multi-line expression (`... THEN NULL \n        ELSE q.user_id`). Git
      // for Windows installs `core.autocrlf=true` by default, so a FRESH clone
      // materialises `\r\n` in the working tree while the repo keeps `\n` —
      // this test was green only on an OLD working tree and turned RED right
      // after `git checkout`. Line endings are not part of the contract being
      // locked here (the SQL text is), so they are normalised on read.
      schemaContent = file.readAsStringSync().replaceAll('\r\n', '\n');
    });

    test('verifies profiles anti-escalation trigger is defined', () {
      expect(schemaContent, contains('CREATE OR REPLACE FUNCTION public.protect_profile_sensitive_fields()'));
      expect(schemaContent, contains('trg_protect_profile_sensitive_fields'));
      expect(schemaContent, contains('Privilege Escalation Blocked'));
    });

    test('verifies expert profiles anti-tampering trigger is defined', () {
      expect(schemaContent, contains('CREATE OR REPLACE FUNCTION public.protect_expert_profile_sensitive_fields()'));
      expect(schemaContent, contains('trg_protect_expert_profile_sensitive_fields'));
      expect(schemaContent, contains('Rating Tampering Blocked'));
    });

    test('verifies anonymous question privacy shield view is defined', () {
      expect(schemaContent, contains('CREATE OR REPLACE VIEW public.public_questions_view'));
      expect(schemaContent, contains('WHEN q.is_anonymous THEN NULL \n        ELSE q.user_id'));
      expect(schemaContent, contains("WHEN q.is_anonymous THEN 'Anonim fuqaro'"));
    });

    test('verifies reports table security is restricted to moderators/admins', () {
      expect(schemaContent, contains('CREATE OR REPLACE FUNCTION public.is_admin_or_moderator()'));
      expect(schemaContent, contains('Moderators and Admins can view reports'));
      expect(schemaContent, contains('Moderators and Admins can update reports'));
    });

    test('verifies rating range and counter integrity constraints exist', () {
      expect(schemaContent, contains('CHECK (rating >= 0.00 AND rating <= 5.00)'));
      expect(schemaContent, contains('CHECK (reviews_count >= 0)'));
      expect(schemaContent, contains('CHECK (experience_years >= 0)'));
      expect(schemaContent, contains('CHECK (views_count >= 0)'));
      expect(schemaContent, contains('CHECK (upvotes_count >= 0)'));
      expect(schemaContent, contains('CHECK (answers_count >= 0)'));
    });

    test('verifies base questions table RLS restricts anonymous question access', () {
      expect(schemaContent, contains('CREATE POLICY "Public questions are viewable by everyone" ON public.questions'));
      expect(schemaContent, contains('is_anonymous = false'));
      expect(schemaContent, contains('auth.uid() = user_id'));
    });

    test('verifies votes records are private to user', () {
      expect(schemaContent, contains('CREATE POLICY "Users can view own votes" ON public.votes'));
      expect(schemaContent, contains('FOR SELECT USING (auth.uid() = user_id)'));
    });

    test('verifies handle_new_user trigger auto-creates citizen profile on signup', () {
      expect(schemaContent, contains('CREATE OR REPLACE FUNCTION public.handle_new_user()'));
      expect(schemaContent, contains('INSERT INTO public.profiles'));
      expect(schemaContent, contains("'citizen'"));
      expect(schemaContent, contains('CREATE TRIGGER on_auth_user_created'));
    });
  });

  group('Anti-Hallucination Grounding Validator Security', () {
    test('blocks hallucinated article numbers beyond legal maximums', () {
      expect(LegalGroundingValidator.isValidArticleNumber("O'zbekiston Konstitutsiyasi", 155), isTrue);
      expect(LegalGroundingValidator.isValidArticleNumber("O'zbekiston Konstitutsiyasi", 156), isFalse);
      expect(LegalGroundingValidator.isValidArticleNumber("Mehnat kodeksi", 581), isTrue);
      expect(LegalGroundingValidator.isValidArticleNumber("Mehnat kodeksi", 582), isFalse);
      expect(LegalGroundingValidator.isValidArticleNumber("Oila kodeksi", 238), isTrue);
      expect(LegalGroundingValidator.isValidArticleNumber("Oila kodeksi", 239), isFalse);
    });
  });
}
