import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/features/citizen_services/data/models/citizen_service_model.dart';
import 'package:lexhub/features/citizen_services/data/models/service_step_model.dart';

void main() {
  group('CitizenServiceModel & ServiceStepModel JSON Serialization', () {
    test('should correctly parse full Supabase record with relational steps', () {
      final json = {
        'id': 'service_traffic_discount',
        'category_id': 'traffic',
        'title': 'YHQ jarimalariga 50% chegirma',
        'department': 'IIV YHXX',
        'description': 'Radar jarimalarini 15 kunda 50% chegirma bilan to\'lash',
        'cost_bhm_percent': 0.0,
        'is_free': true,
        'processing_days': 10,
        'required_documents': ['Qaror raqami', 'Guvohnoma'],
        'online_url': 'https://my.gov.uz/uz/service/469',
        'deadline_law_reference': 'MJtK 332-1-modda',
        'source_url': 'https://lex.uz/docs/97661#1184234',
        'legal_basis': 'O\'zbekiston Respublikasi MJtK 332-1-moddasi',
        'last_verified_at': '2026-01-15T00:00:00Z',
        'status': 'active',
        'is_popular': true,
        'service_steps': [
          {
            'step_number': 1,
            'title': 'Qaror bilan tanishish',
            'description': 'my.gov.uz orqali tekshiring',
            'action_url': 'https://my.gov.uz/uz/service/469',
            'step_type': 'online',
          },
          {
            'step_number': 2,
            'title': '50% chegirma bilan to\'lash',
            'description': 'Payme orqali to\'lang',
            'warning_note': '15 kundan keyin 100% bo\'ladi',
            'action_url': 'https://payme.uz',
            'step_type': 'payment',
          },
        ],
      };

      final model = CitizenServiceModel.fromJson(json);

      expect(model.id, 'service_traffic_discount');
      expect(model.category, "Yo'l harakati");
      expect(model.title, 'YHQ jarimalariga 50% chegirma');
      expect(model.department, 'IIV YHXX');
      expect(model.isFree, true);
      expect(model.costBhmPercent, 0.0);
      expect(model.processingDays, 10);
      expect(model.requiredDocuments.length, 2);
      expect(model.onlineUrl, 'https://my.gov.uz/uz/service/469');
      expect(model.sourceUrl, 'https://lex.uz/docs/97661#1184234');
      expect(model.legalBasis, 'O\'zbekiston Respublikasi MJtK 332-1-moddasi');
      expect(model.lastVerifiedAt, isNotNull);
      expect(model.lastVerifiedAt!.year, 2026);
      expect(model.isPopular, true);
      expect(model.steps.length, 2);

      expect(model.steps[0].stepNumber, 1);
      expect(model.steps[0].title, 'Qaror bilan tanishish');
      expect(model.steps[0].stepType, 'online');
      expect(model.steps[0].actionUrl, 'https://my.gov.uz/uz/service/469');

      expect(model.steps[1].stepNumber, 2);
      expect(model.steps[1].warningNote, '15 kundan keyin 100% bo\'ladi');
      expect(model.steps[1].stepType, 'payment');
    });

    test('should convert to JSON and back faithfully', () {
      const step = ServiceStepModel(
        stepNumber: 1,
        title: 'Ariza berish',
        description: 'my.gov.uz orqali topshiring',
        actionUrl: 'https://my.gov.uz',
        stepType: 'online',
      );

      final service = CitizenServiceModel(
        id: 'test_1',
        title: 'Test Xizmat',
        category: 'Mehnat huquqi',
        department: 'Bandlik vazirligi',
        description: 'Test tavsif',
        isPopular: true,
        sourceUrl: 'https://lex.uz',
        steps: const [step],
      );

      final json = service.toJson();
      final reconstructed = CitizenServiceModel.fromJson(json);

      expect(reconstructed.id, 'test_1');
      expect(reconstructed.title, 'Test Xizmat');
      expect(reconstructed.isPopular, true);
      expect(reconstructed.steps.length, 1);
      expect(reconstructed.steps.first.title, 'Ariza berish');
    });
  });
}
