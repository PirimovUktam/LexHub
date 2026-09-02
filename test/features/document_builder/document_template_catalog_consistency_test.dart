/// SHABLON KATALOGI — AI YO'NALTIRISHI VA HUJJAT MATNI BILAN MOSLIGI.
///
/// Bu fayl 2026-08-30 auditida topilgan BESH nuqsonni qulflaydi. Har biri
/// JIM edi: hech qanday exception, hech qanday xato ekrani yo'q.
///
///   1. KATALOG UCHTA edi — bundle, baza seed'i va faqat AI yo'liga xos
///      `document_templates_datasource.dart`. AI foydalanuvchini
///      `template_debt_pretenziya` ga yo'naltirardi, bu id esa ko'rib
///      chiqiladigan hech qaysi katalogda YO'Q edi. Uchinchi katalog
///      O'CHIRILDI, shablon bundle'ga ko'chirildi.
///   2. To'ldiriladigan maydon nomi KATALOGGA MOS EMAS edi: AI tavsifni
///      `violation_details` ga yozardi, haqiqiy maydon esa
///      `violation_reason`. Matn hujjatga TUSHMASDI.
///   3. `template_alimony_petition` uchun yo'naltirish shoxi UMUMAN yo'q edi,
///      "Aliment undirish" tezkor tugmasi esa bor edi.
///   4. `Sana:` qatorlariga NOTO'G'RI joy egasi qo'yilgan edi
///      (`Sana: {{fine_number}}`, `Sana: {{applicant_address}}`), bazada esa
///      MAYDON BO'LMAGAN `{{created_at}}` — u hujjatga XOM holda chiqardi.
///   5. Bundle matnida `to''g'risidagi` — Dart `"""` ichida `''` IKKI
///      apostrof bo'lib chiqadi (SQL escape'i bilan aralashtirilgan).
///
/// Qulf MEXANIZMI: jadvalning o'zi emas, KATALOG haqiqat manbasi. Yangi
/// shablon qo'shilsa yoki maydon nomi o'zgarsa test DARHOL yiqiladi.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/features/document_builder/data/datasources/document_templates_local_datasource.dart';
import 'package:lexhub/features/document_builder/domain/ai_document_routing.dart';
import 'package:lexhub/features/document_builder/domain/entities/document_form_field.dart';
import 'package:lexhub/features/document_builder/domain/entities/document_template.dart';

/// `{{field_id}}` joy egalari. `DocumentTemplate.buildDocument` AYNI shu
/// shaklni almashtiradi (`document_template.dart:47`).
final _placeholder = RegExp(r'\{\{([a-zA-Z0-9_]+)\}\}');

late List<DocumentTemplate> catalog;

DocumentTemplate _byId(String id) =>
    catalog.firstWhere((t) => t.id == id, orElse: () => throw StateError(id));

void main() {
  final source = DocumentTemplatesLocalDataSourceImpl();

  setUpAll(() async {
    catalog = await source.getTemplates();
  });

  group('KATALOG — BITTA HAQIQAT MANBASI', () {
    test('katalogda AYNAN kutilgan 5 shablon bor', () {
      expect(
        catalog.map((t) => t.id).toList()..sort(),
        <String>[
          'template_alimony_petition',
          'template_consumer_refund',
          'template_debt_pretenziya',
          'template_labor_complaint',
          'template_traffic_fine_appeal',
        ],
        reason: 'Yangi shablon qo\'shilganda u BAZA seed\'iga ham qo\'shilishi '
            'SHART (`20260830090000_document_templates_catalog_parity.sql`): '
            '`user_documents.template_id` -> `document_templates(id)` FK\'si '
            'bor, ota qatori yo\'q shablon saqlanganda PostgreSQL `23503` '
            'beradi. Bu testni yangilash — o\'sha migratsiyani yozish '
            'kerakligining ESLATMASI.',
      );
    });

    test('id takrorlanmaydi', () {
      final ids = catalog.map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('noma\'lum id XATO otadi — "birinchi shablon" QAYTMAYDI', () async {
      await expectLater(
        source.getTemplateById('template_mavjud_emas'),
        throwsA(isA<StateError>()),
        reason: 'Ilgari `orElse: () => _templates.first` edi: foydalanuvchi '
            'so\'ragan hujjat o\'rniga BUTUNLAY boshqa hujjat forma bo\'lib '
            'ochilardi, hech qanday xato ko\'rinmasdi.',
      );
    });
  });
  group('AI YO\'NALTIRISHI — KATALOG BILAN MOS', () {
    test('yo\'naltirilgan har bir id katalogda BOR', () {
      final ids = catalog.map((t) => t.id).toSet();
      for (final routed in AiDocumentRouting.routableTemplateIds) {
        expect(ids, contains(routed),
            reason: 'AI foydalanuvchini `$routed` ga yo\'naltiradi, bu id esa '
                'katalogda YO\'Q — hujjat ochilmaydi yoki FK 23503 beradi.');
      }
    });

    test('to\'ldiriladigan maydon shablonda BOR va MULTILINE', () {
      AiDocumentRouting.summaryFieldMap.forEach((templateId, fieldId) {
        final template = _byId(templateId);
        final field = template.fields.firstWhere(
          (f) => f.id == fieldId,
          orElse: () => throw StateError(
              'AI tavsifni `$templateId` -> `$fieldId` ga yozadi, bunday '
              'maydon YO\'Q. Aynan shu nuqson bor edi: `violation_details` '
              'yozilardi, haqiqiy maydon esa `violation_reason`.'),
        );
        expect(field.fieldType, DocumentFieldType.multiline,
            reason: 'Muammo tavsifi bir necha qatorli matn. `$fieldId` '
                'maydoni `${field.fieldType.name}` — bir qatorli maydonga '
                'yozilgan uzun tavsif formada KESILIB ko\'rinadi.');
      });
    });

    test('aliment shabloni ATAYLAB to\'ldirilmaydi', () {
      expect(
        AiDocumentRouting.summaryFieldFor('template_alimony_petition'),
        isNull,
        reason: 'Aliment shablonining yagona erkin matn maydoni '
            '`children_info` ("bolalar F.I.Sh va tug\'ilgan sanalari"). Unga '
            'muammo tavsifini yozib qo\'yish RASMIY SUD ARIZASINI buzadi.',
      );
      // Qoida O'ZI esa bor: aliment savoli shablonni OCHISHI kerak.
      expect(AiDocumentRouting.routableTemplateIds,
          contains('template_alimony_petition'));
    });
  });
  group('AI YO\'NALTIRISHI — KALIT SO\'Z QOIDALARI', () {
    // Har bir shox uchun REAL savol shakli. Tartib muhim: aliment savolida
    // "sud" ham uchraydi, lekin bu mehnat yoki qarz nizosi EMAS.
    const cases = <String, String>{
      'Er farzandiga aliment to\'lamayapti, sudga qanday murojaat qilaman?':
          'template_alimony_petition',
      'Ish beruvchi meni asossiz ishdan bo\'shatdi':
          'template_labor_complaint',
      'Radar ko\'rsatgan tezlik uchun jarima keldi, lekin men haydamaganman':
          'template_traffic_fine_appeal',
      'Tilxat asosida qarz berdim, muddat o\'tdi va qaytarmayapti':
          'template_debt_pretenziya',
      'Do\'kondan sifatsiz muzlatgich sotib oldim, pulni qaytarmayapti':
          'template_consumer_refund',
    };

    cases.forEach((text, expectedId) {
      test('"${text.substring(0, 28)}..." -> $expectedId', () {
        expect(AiDocumentRouting.templateIdFor(text), expectedId);
      });
    });

    test('BOSH HARF ahamiyatsiz', () {
      expect(AiDocumentRouting.templateIdFor('ALIMENT masalasi'),
          'template_alimony_petition');
    });

    test('mos kelmasa null — catch-all shoxi YO\'Q', () {
      expect(
        AiDocumentRouting
            .templateIdFor('Kvartirani ro\'yxatdan o\'tkazish tartibi qanday?'),
        isNull,
        reason: 'Ilgari catch-all bor edi va u BUTUNLAY aloqasiz hujjatni '
            '"sizga mos hujjat topildi" deb ko\'rsatardi.',
      );
      expect(AiDocumentRouting.templateIdFor(''), isNull);
    });
  });
  group('HUJJAT MATNI — XOM JOY EGASI CHIQMAYDI', () {
    // `buildDocument` FAQAT `fields` ichida id'si bor `{{...}}` ni
    // almashtiradi (`document_template.dart:47`). Ya'ni maydoni yo'q joy
    // egasi RASMIY hujjatga LITERAL matn bo'lib chiqadi.
    //
    // AYNI shu ikki shart SQL tomonida ham qulflangan (D2/D3,
    // `20260830090000_document_templates_catalog_parity.sql`). Ikki joyda
    // tekshiriladi, chunki matn IKKI manbadan keladi: bundle va baza.
    test('har bir joy egasi uchun MAYDON bor (D2)', () {
      final orphans = <String>[];
      for (final t in catalog) {
        for (final m in _placeholder.allMatches(t.templateText)) {
          final token = m.group(1)!;
          if (!t.fields.any((f) => f.id == token)) {
            orphans.add('${t.id}:{{$token}}');
          }
        }
      }
      expect(orphans, isEmpty,
          reason: 'Bu joy egalari almashtirilmaydi va hujjatga XOM holda '
              'chiqadi (bazada `Sana: {{created_at}}` shunday edi).');
    });

    test('har bir maydon matnda ISHLATILADI (D3)', () {
      final unused = <String>[];
      for (final t in catalog) {
        for (final f in t.fields) {
          if (!t.templateText.contains('{{${f.id}}}')) {
            unused.add('${t.id}:${f.id}');
          }
        }
      }
      expect(unused, isEmpty,
          reason: 'Foydalanuvchi bu maydonlarni to\'ldiradi, natijada esa '
              'hech narsa tushmaydi — JIM ma\'lumot yo\'qotish.');
    });

    test('to\'liq to\'ldirilgan hujjatda `{{` QOLMAYDI', () {
      for (final t in catalog) {
        final values = {
          for (final f in t.fields) f.id: 'QIYMAT_${f.id}',
        };
        final output = t.buildDocument(values);
        expect(output, isNot(contains('{{')), reason: t.id);
        for (final f in t.fields) {
          expect(output, contains('QIYMAT_${f.id}'), reason: '${t.id}/${f.id}');
        }
      }
    });
  });
  group('MATN SIFATI', () {
    test('"Sana:" qatoriga joy egasi QO\'YILMAGAN', () {
      for (final t in catalog) {
        expect(t.templateText, isNot(contains('Sana: {{')),
            reason: '${t.id}: imzo sanasi o\'rniga xarid sanasi, manzil yoki '
                'jarima raqami chiqardi. To\'g\'ri shakl: `Sana: ____________` '
                '— foydalanuvchi hujjatni topshirgan kuni QO\'LDA yozadi.');
      }
    });

    test('IKKI apostrof yo\'q (SQL escape\'i Dart matniga tushmagan)', () {
      // SQL'da bitta apostrof `''` bo'lib yoziladi — o'sha shakl Dart matniga
      // ko'chirilganda IKKI apostrof bo'lib qoladi. Hujjat matni bevosita
      // foydalanuvchiga ko'rinadi, ya'ni imlo xatosi RASMIY arizada chiqadi.
      final bad = <String>[];
      for (final t in catalog) {
        final texts = <String, String>{
          'templateText': t.templateText,
          'title': t.title,
          'description': t.description,
          'legalBasisSummary': t.legalBasisSummary,
          'targetAuthority': t.targetAuthority ?? '',
          for (final f in t.fields) 'field:${f.id}': '${f.label} ${f.placeholder}',
        };
        texts.forEach((where, text) {
          if (text.contains("''")) bad.add('${t.id}/$where');
        });
      }
      expect(bad, isEmpty);
    });

    test('TEKSHIRUV SANASI havolasiz DA\'VO QILINMAYDI (§0)', () {
      for (final t in catalog) {
        if (t.lastVerifiedAt != null) {
          expect(t.sourceUrl, isNotNull,
              reason: '${t.id}: "tekshirilgan" sanasi bor, tekshirilgan '
                  'MANBA havolasi esa yo\'q — bu isbotlanmaydigan da\'vo.');
        }
      }
    });

    test('majburiy maydonlarda yorliq va namuna BO\'SH emas', () {
      for (final t in catalog) {
        expect(t.fields, isNotEmpty, reason: t.id);
        for (final f in t.fields) {
          expect(f.label.trim(), isNotEmpty, reason: '${t.id}/${f.id}');
          expect(f.placeholder.trim(), isNotEmpty, reason: '${t.id}/${f.id}');
        }
      }
    });
  });
}
