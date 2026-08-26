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

  // ISM/FAMILIYA — O'LCHANGAN KAMCHILIK ustidan yozilgan testlar.
  // Sabab: live testda `Mening ismim Aziz Karimov, telefonim +998901234567`
  // matnidan faqat telefon yashirinardi, ism-familiya Google'ga OCHIQ ketardi.
  group('PiiAnonymizer — ism/familiya', () {
    const mask = '[Ism yashirildi]';

    test('yorliq + ism-familiya (live testdagi AYNAN matn)', () {
      const input = 'Mening ismim Aziz Karimov, telefonim +998901234567. '
          "Ish beruvchi meni asossiz ishdan bo'shatdi.";
      final sanitized = PiiAnonymizer.anonymize(input);

      expect(sanitized, contains(mask));
      expect(sanitized, isNot(contains('Karimov')));
      expect(sanitized, isNot(contains('Aziz')));
      expect(sanitized, contains('[Telefon yashirildi]'));
      // Huquqiy kontekst SAQLANADI — aks holda RAG modda topa olmaydi.
      expect(sanitized, contains("ishdan bo'shatdi"));
    });

    test("otasining ismi va `o'g'li/qizi` shakllari", () {
      expect(PiiAnonymizer.anonymize('Rustamovich bilan gaplashdim'),
          isNot(contains('Rustamovich')));
      expect(PiiAnonymizer.anonymize('Guvoh — Karim oʻgʻli'),
          isNot(contains('Karim')));
      expect(PiiAnonymizer.anonymize('Arizani Aziza qizi topshirdi'),
          isNot(contains('Aziza')));
    });

    test('juftlik ikki tomonlama tartibda va gap ORTASIDAGI yolgiz familiya',
        () {
      expect(PiiAnonymizer.anonymize('Karimov Aziz shartnoma tuzdi'),
          isNot(contains('Karimov')));
      expect(PiiAnonymizer.anonymize("Ish beruvchim Toʻlqinov haq bermadi"),
          isNot(contains('Toʻlqinov')));
      // LAVOZIM saqlanadi, ism maskalanadi — "kim bilan nizo" ma'nosi
      // huquqiy javob uchun kerak.
      expect(PiiAnonymizer.anonymize('Sudya Salimova qaror chiqardi'),
          'Sudya [Ism yashirildi] qaror chiqardi');
      expect(PiiAnonymizer.anonymize('Advokat Karimov Aziz yordam berdi'),
          'Advokat [Ism yashirildi] yordam berdi');
      expect(PiiAnonymizer.anonymize('Advokat Aziz Karimov yordam berdi'),
          'Advokat [Ism yashirildi] yordam berdi');
      // LAVOZIM + JOY NOMI: familiya suffiksi yo'q, shuning uchun
      // "Toshkent" TEGILMAYDI (over-redaction'dan himoya).
      expect(PiiAnonymizer.anonymize('Fuqaro Toshkent shahar sudiga murojaat qildi'),
          'Fuqaro Toshkent shahar sudiga murojaat qildi');
    });

    test('HUQUQIY ATAMALAR O\'CHIRILMAYDI (over-redaction regressiyasi)', () {
      const legal = [
        "Mehnat kodeksining 161-moddasiga asoslanaman",
        "O'zbekiston Respublikasi Konstitutsiyasi 43-moddasi",
        'Sinov muddati 3 oy edi, tanlov e\'lon qilinmagan',
        "So'rov Vazirlar Mahkamasiga yuborilgan",
        'Toshkent shahar sudiga ariza berdim',
        'Kuyov va qaynona bilan nizo bor',
      ];
      for (final text in legal) {
        expect(PiiAnonymizer.anonymize(text), text,
            reason: 'Huquqiy matn o\'zgardi: "$text"');
      }
    });

    test('containsPii ismni ham PII deb hisoblaydi', () {
      expect(PiiAnonymizer.containsPii('Mening ismim Aziz Karimov'), isTrue);
      expect(PiiAnonymizer.containsPii('Sinov muddati tugadi'), isFalse);
      expect(PiiAnonymizer.containsPii('Mehnat kodeksi 161-modda'), isFalse);
    });
  });
}
