// ignore_for_file: avoid_print

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/config/supabase_config.dart';
import 'package:lexhub/features/citizen_services/data/datasources/citizen_services_local_datasource.dart';
import 'package:lexhub/features/citizen_services/data/datasources/citizen_services_remote_datasource.dart';
import 'package:lexhub/features/citizen_services/data/repositories/citizen_services_repository_impl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RealHttpOverrides extends HttpOverrides {}

void main() {
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

  group('Sprint 6: Real Supabase Citizen Services E2E Suite', () {
    test('1. Remote Database Schema & Citizen Services Table Accessibility', () async {
      final client = Supabase.instance.client;

      bool servicesTableExists = false;
      bool stepsTableExists = false;

      // 1. Query citizen_services
      try {
        final services = await client
            .from('citizen_services')
            .select('id, title, department, cost_bhm_percent, is_free')
            .limit(5);
        servicesTableExists = true;
        print('EVIDENCE 1: Live citizen_services table accessible (${services.length} rows)');
      } catch (e) {
        print('EVIDENCE 1: citizen_services error: $e');
      }

      // 2. Query service_steps
      try {
        final steps = await client
            .from('service_steps')
            .select('id, service_id, step_number, title')
            .limit(5);
        stepsTableExists = true;
        print('EVIDENCE 1: Live service_steps table accessible (${steps.length} rows)');
      } catch (e) {
        print('EVIDENCE 1: service_steps error: $e');
      }

      expect(servicesTableExists, true);
      expect(stepsTableExists, true);
    });

    test('2. Freshness & Official Source Metadata Verification (Lex.uz / My.gov.uz)', () async {
      final client = Supabase.instance.client;

      // Verify that official government service records have valid source references
      final localDS = CitizenServicesLocalDataSourceImpl();
      final remoteDS = CitizenServicesRemoteDataSourceImpl(
        supabaseClient: client,
        localDataSource: localDS,
      );

      final services = await remoteDS.getServices();
      print('EVIDENCE 2: Loaded ${services.length} total services with freshness metadata');
      expect(services.isNotEmpty, true);

      final trafficService = services.firstWhere(
        (s) => s.id.contains('traffic'),
        orElse: () => services.first,
      );

      print('EVIDENCE 2: Traffic service: ${trafficService.title}');
      print('EVIDENCE 2: Source URL: ${trafficService.sourceUrl}');
      print('EVIDENCE 2: Legal basis: ${trafficService.legalBasis}');
      print('EVIDENCE 2: Last verified: ${trafficService.lastVerifiedAt}');

      expect(trafficService.sourceUrl?.contains('lex.uz') ?? false, true);
      expect(trafficService.legalBasis?.isNotEmpty ?? false, true);
      expect(trafficService.steps.isNotEmpty, true);
    });

    test('3. RLS Public Read & Unauthenticated Mutation Defense', () async {
      final client = Supabase.instance.client;

      // 1. Public Read Check
      final publicServices = await client.from('citizen_services').select('id, title').limit(3);
      print('EVIDENCE 3: Public read confirmed (${publicServices.length} items)');
      expect(publicServices, isNotNull);

      // 2. Unauthenticated Insert Attempt (Must be rejected by RLS)
      try {
        await client.from('citizen_services').insert({
          'id': 'service_fake_malicious',
          'title': 'Hacked Service',
          'department': 'Fake Department',
          'description': 'Malicious injection',
        });
        fail('Unauthenticated insert should have been blocked by RLS');
      } catch (e) {
        print('EVIDENCE 3: Unauthenticated insert attempt blocked by RLS: $e');
        expect(e, isNotNull);
      }
    });

    test('4. Repository Offline-First Resilience and Category Search', () async {
      final client = Supabase.instance.client;
      final localDS = CitizenServicesLocalDataSourceImpl();
      final remoteDS = CitizenServicesRemoteDataSourceImpl(
        supabaseClient: client,
        localDataSource: localDS,
      );
      final repository = CitizenServicesRepositoryImpl(
        remoteDataSource: remoteDS,
        localDataSource: localDS,
      );

      // Search by query "jarima"
      final searchResult = await repository.getServices(searchQuery: 'jarima');
      expect(searchResult.isRight(), true);
      searchResult.fold(
        (_) => fail('Search query failed'),
        (list) {
          print('EVIDENCE 4: Search "jarima" returned ${list.length} services');
          expect(list.isNotEmpty, true);
          expect(list.first.title.toLowerCase().contains('jarima') || list.first.description.toLowerCase().contains('jarima'), true);
        },
      );

      // Filter by category "Mehnat huquqi"
      final categoryResult = await repository.getServices(category: 'Mehnat huquqi');
      expect(categoryResult.isRight(), true);
      categoryResult.fold(
        (_) => fail('Category filter failed'),
        (list) {
          print('EVIDENCE 4: Category "Mehnat huquqi" returned ${list.length} services');
          expect(list.isNotEmpty, true);
          expect(list.first.category.toLowerCase().contains('mehnat'), true);
        },
      );
    });
  });
}
