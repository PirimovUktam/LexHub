/// §20 QULFI — BUZILGAN JSON JIM YUTILMAYDI.
///
/// Bu test 2026-08-30 da o'zgartirilgan TO'RTTA joyning yangi xatti-harakatini
/// qulflaydi. Ilgari to'rttasi ham `catch (_) {}` ishlatardi, ya'ni buzilgan
/// ma'lumot foydalanuvchiga BO'SH ko'rinardi:
///
///   * `DocumentTemplateModel.fromJson` — `required_fields` matn shaklida
///     kelib, JSON'i buzilgan bo'lsa shablon MAYDONSIZ ochilardi (to'ldirish
///     mumkin bo'lmagan hujjat, xato belgisi YO'Q);
///   * `SavedUserDocumentModel.fromJson` — `form_values` buzilgan bo'lsa
///     foydalanuvchining O'ZI yozgan qiymatlari BO'SH ko'rinardi ("siz hech
///     narsa kiritmagansiz" degan jim yolg'on);
///   * `UserModel` / `UserProfileModel` — ulardagi `catch` esa O'LIK edi
///     (`DateTime.tryParse` exception TASHLAMAYDI, `null` qaytaradi). Ular
///     uchun bu test XATTI-HARAKAT SAQLANGANINI isbotlaydi: `catch` olib
///     tashlangani bilan hech narsa buzilmadi.
///
/// Ya'ni bu fayl ikki xil da'voni qulflaydi: qayerda ENDI otiladi va qayerda
/// ATAYLAB otilmaydi.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/features/auth/data/models/user_model.dart';
import 'package:lexhub/features/auth/data/models/user_profile_model.dart';
import 'package:lexhub/features/document_builder/data/models/document_template_model.dart';
import 'package:lexhub/features/document_builder/data/models/saved_user_document_model.dart';

/// `required_fields` dan tashqari hamma narsa haqiqiy shablon kabi.
Map<String, dynamic> _templateJson(Object? requiredFields) => {
      'id': 'tpl_parse_test',
      'title': 'Parse test',
      'category': "Iste'molchi huquqlari",
      'description': 'Tavsif',
      'legal_basis': 'Qonun',
      'body_template': 'Matn {{buyer_name}}',
      'required_fields': requiredFields,
    };

void main() {
  group('DocumentTemplateModel — `required_fields` matn shaklida', () {
    test('TO\'G\'RI JSON matni avvalgidek o\'qiladi (regressiya yo\'q)', () {
      final model = DocumentTemplateModel.fromJson(_templateJson(
        '[{"id":"buyer_name","label":"Xaridor","placeholder":"Ali",'
            '"is_required":true,"field_type":"text"}]',
      ));
      expect(model.fields.length, 1);
      expect(model.fields.first.id, 'buyer_name');
    });

    test('BUZILGAN JSON — ENDI OTILADI (ilgari 0 maydonli shablon berardi)',
        () {
      expect(
        () => DocumentTemplateModel.fromJson(_templateJson('[{"id":"buyer')),
        throwsA(isA<FormatException>()),
        reason: 'jim yutilsa foydalanuvchi to\'ldira olmaydigan shablonni '
            'ko\'radi va sabab HECH QAYERDA ko\'rinmaydi',
      );
    });

    test('JSON ro\'yxat EMAS (obyekt) — ANIQ xato', () {
      expect(
        () => DocumentTemplateModel.fromJson(_templateJson('{"id":"x"}')),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('DocumentTemplateModel — RO\'YXAT elementi matn shaklida', () {
    // 2026-08-30: bu yerdagi `catch (_)` BUZILGAN JSON MATNINI maydon
    // YORLIG'I qilib qo'yardi. Endi mo'ljal bo'yicha ajratiladi.
    test('MAYDON NOMI ro\'yxati avvalgidek ishlaydi (regressiya yo\'q)', () {
      final model = DocumentTemplateModel.fromJson(
          _templateJson(<dynamic>['buyer_name', 'seller_name']));
      expect(model.fields.map((f) => f.id), ['buyer_name', 'seller_name']);
      expect(model.fields.first.label, 'buyer_name');
    });

    test('element ichidagi TO\'G\'RI JSON obyekt o\'qiladi', () {
      final model = DocumentTemplateModel.fromJson(_templateJson(<dynamic>[
        '{"id":"buyer_name","label":"Xaridor","placeholder":"Ali"}',
      ]));
      expect(model.fields.single.label, 'Xaridor');
    });

    test('BUZILGAN JSON element — OTILADI (ilgari yorliq `{"id":"buyer` edi)',
        () {
      expect(
        () => DocumentTemplateModel.fromJson(
            _templateJson(<dynamic>['{"id":"buyer'])),
        throwsA(isA<FormatException>()),
        reason: 'buzilgan JSON matni foydalanuvchiga MAYDON NOMI bo\'lib '
            'ko\'rinardi',
      );
    });

    test('JSON obyekt EMAS (ro\'yxat) element — ANIQ xato', () {
      expect(
        () => DocumentTemplateModel.fromJson(
            _templateJson(<dynamic>['["buyer_name"]'])),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('SavedUserDocumentModel — `form_values` matn shaklida', () {
    Map<String, dynamic> docJson(Object? formValues) => {
          'id': 'doc_1',
          'user_id': 'user_1',
          'title': 'Ariza',
          'category': 'Umumiy',
          'generated_text': 'Matn',
          'form_values': formValues,
          'created_at': '2026-08-30T10:00:00.000Z',
          'updated_at': '2026-08-30T10:00:00.000Z',
        };

    test('TO\'G\'RI JSON matni o\'qiladi', () {
      final model =
          SavedUserDocumentModel.fromJson(docJson('{"buyer_name":"Ali"}'));
      expect(model.formValues['buyer_name'], 'Ali');
    });

    test('BUZILGAN JSON — OTILADI (foydalanuvchi ma\'lumoti, zaxira YO\'Q)',
        () {
      expect(
        () => SavedUserDocumentModel.fromJson(docJson('{"buyer_name":')),
        throwsA(isA<FormatException>()),
        reason: 'bo\'sh `formValues` — "hech narsa kiritmagansiz" degan jim '
            'yolg\'on',
      );
    });

    test('JSON obyekt EMAS (ro\'yxat) — ANIQ xato', () {
      expect(
        () => SavedUserDocumentModel.fromJson(docJson('["a","b"]')),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('O\'LIK `catch` olib tashlandi — XATTI-HARAKAT O\'ZGARMADI', () {
    test('UserModel: buzilgan `created_at` OTMAYDI, `createdAt` null bo\'ladi',
        () {
      final model = UserModel.fromJson({
        'id': 'u1',
        'email': 'a@b.uz',
        'created_at': 'bu sana emas',
      });
      expect(model.id, 'u1');
      expect(model.createdAt, isNull,
          reason: '`DateTime.tryParse` exception emas, null qaytaradi');
    });

    test('UserModel: `created_at` YO\'Q bo\'lsa ham otmaydi', () {
      final model = UserModel.fromJson({'id': 'u1', 'email': 'a@b.uz'});
      expect(model.createdAt, isNull);
    });

    test('UserProfileModel: buzilgan sanalar OTMAYDI', () {
      final model = UserProfileModel.fromJson({
        'id': 'p1',
        'full_name': 'Ali Valiyev',
        'created_at': 'xato',
        'updated_at': 'xato',
      });
      expect(model.fullName, 'Ali Valiyev');
      // `createdAt`/`updatedAt` entity'da NULLABLE EMAS, shuning uchun
      // avvalgidek `DateTime.now()` ga tushadi — bu xatti-harakat ATAYLAB
      // SAQLANDI (o'zgartirish faqat o'lik `catch` ni olib tashlash edi).
      expect(model.createdAt, isA<DateTime>());
      expect(model.updatedAt, isA<DateTime>());
    });

    test('UserProfileModel: to\'g\'ri sana o\'qiladi', () {
      final model = UserProfileModel.fromJson({
        'id': 'p1',
        'full_name': 'Ali',
        'created_at': '2026-08-30T10:00:00.000Z',
        'updated_at': '2026-08-30T11:00:00.000Z',
      });
      expect(model.createdAt.toUtc().hour, 10);
      expect(model.updatedAt.toUtc().hour, 11);
    });
  });
}
