import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/legal_safety/pii_anonymizer.dart';

void main() {
  group('PiiAnonymizer Tests', () {
    test('anonymizes Uzbekistan phone numbers in various formats', () {
      const input1 = "Mening raqamim +998901234567, qo'ng'iroq qiling.";
      const input2 = "Aloqa uchun: 998 93 111-22-33 yoki (97) 555 44 33.";

      expect(
        PiiAnonymizer.anonymize(input1),
        contains("[Telefon yashirildi]"),
      );
      expect(
        PiiAnonymizer.anonymize(input1),
        isNot(contains("+998901234567")),
      );

      final result2 = PiiAnonymizer.anonymize(input2);
      expect(result2, contains("[Telefon yashirildi]"));
      expect(result2, isNot(contains("998 93 111-22-33")));
    });

    test('anonymizes Passport and ID numbers (AA 1234567)', () {
      const input = "Pasportim seriyasi AA 1234567, Toshkentda berilgan.";
      final sanitized = PiiAnonymizer.anonymize(input);

      expect(sanitized, contains("[Pasport yashirildi]"));
      expect(sanitized, isNot(contains("AA 1234567")));
    });

    test('anonymizes 16-digit Bank Card numbers', () {
      const input = "Plastik kartam raqami 8600 1234 5678 9012, pul yuboring.";
      final sanitized = PiiAnonymizer.anonymize(input);

      expect(sanitized, contains("[Karta raqami yashirildi]"));
      expect(sanitized, isNot(contains("8600 1234 5678 9012")));
    });

    test('anonymizes 14-digit PINFL / JSHSHIR numbers', () {
      const input = "JSHSHIR raqamim: 31205940123456.";
      final sanitized = PiiAnonymizer.anonymize(input);

      expect(sanitized, contains("[JSHSHIR yashirildi]"));
      expect(sanitized, isNot(contains("31205940123456")));
    });

    test('anonymizes email addresses', () {
      const input = "Menga info@example.uz manziliga yozing.";
      final sanitized = PiiAnonymizer.anonymize(input);

      expect(sanitized, contains("[Email yashirildi]"));
      expect(sanitized, isNot(contains("info@example.uz")));
    });

    test('containsPii returns true when PII is detected, false otherwise', () {
      expect(PiiAnonymizer.containsPii("Oddiy matn, hech qanday raqamsiz"), isFalse);
      expect(PiiAnonymizer.containsPii("Tel: +998901234567"), isTrue);
      expect(PiiAnonymizer.containsPii("Pasport: AB7654321"), isTrue);
    });
  });
}
