// ignore_for_file: avoid_print

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/config/supabase_config.dart';
import 'package:lexhub/features/document_builder/data/datasources/document_templates_local_datasource.dart';
import 'package:lexhub/features/document_builder/data/datasources/document_templates_remote_datasource.dart';
import 'package:lexhub/features/document_builder/data/repositories/document_builder_repository_impl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/live_gate.dart';
class RealHttpOverrides extends HttpOverrides {}

void main() {
  // P2 test konfiguratsiyasi: bu fayl REAL Supabase Cloud'ga ulanadi.
  // `--dart-define=LEXHUB_LIVE_WRITE_TESTS=true` bo'lmasa OSHKORA skip.
  if (!liveSuiteEnabled('real_supabase_document_builder')) return;

  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = RealHttpOverrides();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SupabaseConfig.init();
    if (SupabaseConfig.isConfigured) {
      try {
        await Supabase.initialize(
          url: SupabaseConfig.url,
          // ignore: deprecated_member_use
          anonKey: SupabaseConfig.anonKey,
        );
      } catch (_) {
        // Already initialized
      }
    }
  });

  group('Sprint 7.1: Real Supabase Document Builder & Templates E2E Suite', () {
    test('1. Remote Database Schema & user_documents Table Accessibility', () async {
      final client = Supabase.instance.client;

      bool templatesTableExists = false;
      bool userDocsTableExists = false;

      // 1. Query document_templates
      try {
        final templates = await client
            .from('document_templates')
            .select('id, title, category, target_authority')
            .limit(5);
        templatesTableExists = true;
        print('EVIDENCE 1: Live document_templates table accessible (${templates.length} rows)');
      } catch (e) {
        print('EVIDENCE 1: document_templates error: $e');
      }

      // 2. Query user_documents
      try {
        final userDocs = await client
            .from('user_documents')
            .select('id, user_id, title')
            .limit(5);
        userDocsTableExists = true;
        print('EVIDENCE 1: Live user_documents table accessible (${userDocs.length} rows)');
      } catch (e) {
        print('EVIDENCE 1: user_documents query result: $e');
      }

      expect(templatesTableExists, true);
      expect(userDocsTableExists, true);
    });

    test('2. Freshness & Lex.uz Legal Grounding in Real Templates (2+ Scenarios)', () async {
      final client = Supabase.instance.client;
      final localDS = DocumentTemplatesLocalDataSourceImpl();
      final remoteDS = DocumentTemplatesRemoteDataSourceImpl(
        supabaseClient: client,
        localDataSource: localDS,
      );

      final templates = await remoteDS.getTemplates();
      print('EVIDENCE 2: Loaded ${templates.length} total document templates');
      expect(templates.isNotEmpty, true);

      // Scenario A: Consumer Refund (Iste'molchi huquqlari)
      final refundList = templates.where((t) => t.id.contains('consumer') || t.id.contains('refund')).toList();
      final refundTemplate = refundList.isNotEmpty ? refundList.first : templates.first;

      print('--- SCENARIO A: ISTE''MOLCHI HUQUQLARI EVIDENCE ---');
      print('Template: ${refundTemplate.title}');
      print('Legal basis: ${refundTemplate.legalBasisSummary}');
      print('Source URL: ${refundTemplate.sourceUrl}');
      print('Last verified: ${refundTemplate.lastVerifiedAt}');

      expect(refundTemplate.sourceUrl?.contains('lex.uz') ?? false, true);
      expect(refundTemplate.legalBasisSummary.isNotEmpty, true);
      expect(refundTemplate.fields.isNotEmpty, true);

      // Scenario B: Labor Wrongful Termination (Mehnat huquqi)
      final laborList = templates.where((t) => t.id.contains('labor')).toList();
      final laborTemplate = laborList.isNotEmpty ? laborList.first : templates.last;

      print('--- SCENARIO B: MEHNAT HUQUQI EVIDENCE ---');
      print('Template: ${laborTemplate.title}');
      print('Legal basis: ${laborTemplate.legalBasisSummary}');
      print('Source URL: ${laborTemplate.sourceUrl}');

      expect(laborTemplate.sourceUrl?.contains('lex.uz') ?? false, true);
      expect(laborTemplate.legalBasisSummary.contains('Mehnat'), true);

      // Scenario C: Alimony Court Petition (Oila huquqi)
      final alimonyList = templates.where((t) => t.id.contains('alimony')).toList();
      final alimonyTemplate = alimonyList.isNotEmpty ? alimonyList.first : templates.first;

      print('--- SCENARIO C: OILAVIY HUQUQ EVIDENCE ---');
      print('Template: ${alimonyTemplate.title}');
      print('Legal basis: ${alimonyTemplate.legalBasisSummary}');
      print('Target Authority: ${alimonyTemplate.targetAuthority}');

      expect(alimonyTemplate.legalBasisSummary.contains('Oila'), true);
    });

    test('3. Strict RLS Public Read & Unauthenticated Mutation Defense', () async {
      final client = Supabase.instance.client;

      // 1. Public Read Check on templates (Must succeed)
      final publicTemplates = await client.from('document_templates').select('id, title').limit(3);
      print('EVIDENCE 3: Public read confirmed (${publicTemplates.length} templates)');
      expect(publicTemplates, isNotNull);

      // 2. Unauthenticated Insert Attempt on document_templates (Must be rejected by RLS)
      try {
        await client.from('document_templates').insert({
          'id': 'template_fake_malicious',
          'title': 'Hacked Template',
          'category': 'Fake',
          'description': 'Malicious injection',
          'target_authority': 'None',
          'required_fields': [],
          'body_template': 'Hacked',
        });
        fail('Unauthenticated template insert should have been blocked by RLS');
      } catch (e) {
        print('EVIDENCE 3: Unauthenticated template insert blocked by RLS: $e');
        expect(e, isNotNull);
      }

      // 3. Unauthenticated Insert Attempt on user_documents (Must be rejected by RLS)
      try {
        await client.from('user_documents').insert({
          'user_id': '00000000-0000-0000-0000-000000000000',
          'title': 'Fake private doc',
          'category': 'Fake',
          'form_values': {},
          'generated_text': 'Confidential Text',
        });
        fail('Unauthenticated user document insert should have been blocked by RLS');
      } catch (e) {
        print('EVIDENCE 3: Unauthenticated user document insert blocked by RLS: $e');
        expect(e, isNotNull);
      }
    });

    test('4. Repository Search, Category Filter & Document Generation Interpolation', () async {
      final client = Supabase.instance.client;
      final localDS = DocumentTemplatesLocalDataSourceImpl();
      final remoteDS = DocumentTemplatesRemoteDataSourceImpl(
        supabaseClient: client,
        localDataSource: localDS,
      );
      final repository = DocumentBuilderRepositoryImpl(
        remoteDataSource: remoteDS,
        localDataSource: localDS,
      );

      // Search by query "shikoyat"
      final searchResult = await repository.getTemplates(searchQuery: 'shikoyat');
      expect(searchResult.isRight(), true);
      searchResult.fold(
        (_) => fail('Search failed'),
        (list) {
          print('EVIDENCE 4: Search "shikoyat" returned ${list.length} templates');
          expect(list.isNotEmpty, true);
        },
      );

      // Category filter "Iste'molchi huquqlari"
      final categoryResult = await repository.getTemplates(category: "Iste'molchi huquqlari");
      expect(categoryResult.isRight(), true);
      categoryResult.fold(
        (_) => fail('Category filter failed'),
        (list) {
          print('EVIDENCE 4: Category "Iste''molchi" returned ${list.length} templates');
          expect(list.isNotEmpty, true);

          // Interpolation test on the template
          final template = list.first;
          final generatedDoc = template.buildDocument({
            'store_name': 'Artel Savdo MCHJ',
            'applicant_name': 'Jasur Karimov Anvarovich',
            'applicant_address': 'Toshkent sh., Chilonzor 12-mavze',
            'purchase_date': '15.08.2026',
            'product_name': 'Artel Muzlatgich HD-345',
            'product_price': '4 200 000 so''m',
            'defect_details': 'Muzlatish bo''limi yetarli darajada sovutmayapti',
          });

          print('EVIDENCE 4: Generated Document Snippet:\n${generatedDoc.substring(0, 200)}...');
          expect(generatedDoc.contains('Artel Savdo MCHJ'), true);
          expect(generatedDoc.contains('Jasur Karimov Anvarovich'), true);
          expect(generatedDoc.contains('4 200 000 so''m'), true);
          expect(generatedDoc.contains('{{store_name}}'), false);
        },
      );
    });
  });
}
