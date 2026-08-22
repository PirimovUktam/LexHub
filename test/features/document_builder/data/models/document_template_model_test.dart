import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/features/document_builder/data/models/document_form_field_model.dart';
import 'package:lexhub/features/document_builder/data/models/document_template_model.dart';
import 'package:lexhub/features/document_builder/domain/entities/document_form_field.dart';

void main() {
  group('DocumentTemplateModel & DocumentFormFieldModel Tests', () {
    test('1. DocumentFormFieldModel JSON serialization', () {
      final json = {
        'id': 'applicant_name',
        'label': 'Foydalanuvchi F.I.Sh',
        'placeholder': 'Aliyev Ali',
        'is_required': true,
        'field_type': 'text',
      };

      final model = DocumentFormFieldModel.fromJson(json);
      expect(model.id, 'applicant_name');
      expect(model.isRequired, true);
      expect(model.fieldType, DocumentFieldType.text);

      final outJson = model.toJson();
      expect(outJson['id'], 'applicant_name');
      expect(outJson['field_type'], 'text');
    });

    test('2. DocumentTemplateModel JSON serialization and interpolation', () {
      final json = {
        'id': 'template_test_refund',
        'title': 'Test Refund Template',
        'category': "Iste'molchi huquqlari",
        'description': 'Test description',
        'legal_basis': 'Iste''molchi huquqlari to''g''risidagi qonun',
        'source_url': 'https://lex.uz/docs/44265',
        'last_verified_at': '2026-01-15T00:00:00.000Z',
        'status': 'active',
        'is_popular': true,
        'required_fields': [
          {
            'id': 'buyer_name',
            'label': 'Xaridor nomi',
            'placeholder': 'Ali',
            'is_required': true,
            'field_type': 'text',
          },
          {
            'id': 'item_name',
            'label': 'Tovar nomi',
            'placeholder': 'Telefon',
            'is_required': true,
            'field_type': 'text',
          }
        ],
        'body_template': 'Men, {{buyer_name}}, sotib olingan {{item_name}} uchun pulni qaytarishingizni so''rayman.',
      };

      final model = DocumentTemplateModel.fromJson(json);
      expect(model.id, 'template_test_refund');
      expect(model.category, "Iste'molchi huquqlari");
      expect(model.fields.length, 2);
      expect(model.isPopular, true);

      // Interpolation test
      final generated = model.buildDocument({
        'buyer_name': 'Jasur Karimov',
        'item_name': 'Kir yuvish mashinasi',
      });

      expect(generated.contains('Jasur Karimov'), true);
      expect(generated.contains('Kir yuvish mashinasi'), true);
      expect(generated.contains('{{buyer_name}}'), false);
    });
  });
}
