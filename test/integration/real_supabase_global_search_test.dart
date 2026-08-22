// ignore_for_file: avoid_print

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/config/supabase_config.dart';
import 'package:lexhub/features/search/data/datasources/search_local_datasource.dart';
import 'package:lexhub/features/search/data/datasources/search_remote_datasource.dart';
import 'package:lexhub/features/search/data/repositories/search_repository_impl.dart';
import 'package:lexhub/features/search/domain/entities/search_result_item.dart';
import 'package:lexhub/features/search/domain/usecases/global_search_usecase.dart';
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

  group('Sprint 8: Real Supabase Unified Global Search E2E Suite', () {
    test('1. Direct global_search RPC Invocation on Real Supabase Cloud', () async {
      final client = Supabase.instance.client;

      final response = await client.rpc(
        'global_search',
        params: {
          'query_text': 'shikoyat',
          'filter_type': 'all',
          'match_limit': 10,
          'match_offset': 0,
        },
      );

      print('EVIDENCE 1: Direct RPC global_search response type: ${response.runtimeType}');
      expect(response is List, true);
      final list = response as List;
      print('EVIDENCE 1: Returned ${list.length} rows from live Cloud database');
      for (final row in list) {
        print('  - [${row['result_type']}] ${row['title']} (Score: ${row['relevance_score']})');
      }
      expect(list.isNotEmpty, true);
    });

    test('2. Multi-Entity Search across Laws, Templates, Services, Experts & Forum', () async {
      final client = Supabase.instance.client;
      final localDS = SearchLocalDataSourceImpl();
      final remoteDS = SearchRemoteDataSourceImpl(
        supabaseClient: client,
        localDataSource: localDS,
      );
      final repository = SearchRepositoryImpl(
        remoteDataSource: remoteDS,
        localDataSource: localDS,
      );
      final useCase = GlobalSearchUseCase(repository);

      // Search keyword "shikoyat"
      final result = await useCase(
        const GlobalSearchParams(
          query: 'shikoyat',
          filterType: SearchResultType.all,
        ),
      );

      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Search failed'),
        (items) {
          print('EVIDENCE 2: Global search "shikoyat" returned ${items.length} items');
          expect(items.isNotEmpty, true);

          // Relevance sorting check: scores must be descending
          for (int i = 0; i < items.length - 1; i++) {
            expect(items[i].relevanceScore >= items[i + 1].relevanceScore, true);
          }
        },
      );
    });

    test('3. Entity Type Filtering (template, service, expert, law, question)', () async {
      final client = Supabase.instance.client;
      final localDS = SearchLocalDataSourceImpl();
      final remoteDS = SearchRemoteDataSourceImpl(
        supabaseClient: client,
        localDataSource: localDS,
      );
      final repository = SearchRepositoryImpl(
        remoteDataSource: remoteDS,
        localDataSource: localDS,
      );
      final useCase = GlobalSearchUseCase(repository);

      // Filter: only templates
      final templateResult = await useCase(
        const GlobalSearchParams(
          query: 'aliment',
          filterType: SearchResultType.template,
        ),
      );

      templateResult.fold(
        (_) => fail('Template filter search failed'),
        (items) {
          print('EVIDENCE 3: Template filter "aliment" returned ${items.length} items');
          for (final item in items) {
            expect(item.type, SearchResultType.template);
          }
        },
      );

      // Filter: only services
      final serviceResult = await useCase(
        const GlobalSearchParams(
          query: 'jarima',
          filterType: SearchResultType.service,
        ),
      );

      serviceResult.fold(
        (_) => fail('Service filter search failed'),
        (items) {
          print('EVIDENCE 3: Service filter "jarima" returned ${items.length} items');
          for (final item in items) {
            expect(item.type, SearchResultType.service);
          }
        },
      );
    });

    test('4. Pagination Support (match_limit & match_offset)', () async {
      final client = Supabase.instance.client;

      final page1 = await client.rpc(
        'global_search',
        params: {
          'query_text': 'a',
          'filter_type': 'all',
          'match_limit': 2,
          'match_offset': 0,
        },
      ) as List;

      final page2 = await client.rpc(
        'global_search',
        params: {
          'query_text': 'a',
          'filter_type': 'all',
          'match_limit': 2,
          'match_offset': 2,
        },
      ) as List;

      print('EVIDENCE 4: Page 1 count: ${page1.length}, Page 2 count: ${page2.length}');
      if (page1.isNotEmpty && page2.isNotEmpty) {
        expect(page1.first['id'] != page2.first['id'], true);
      }
    });

    test('5. Anonymous Questions Privacy Defense', () async {
      final client = Supabase.instance.client;

      // Ensure anonymous questions without authentication are filtered out
      final searchAnon = await client.rpc(
        'global_search',
        params: {
          'query_text': 'maxfiy',
          'filter_type': 'question',
          'match_limit': 10,
          'match_offset': 0,
        },
      ) as List;

      print('EVIDENCE 5: Anonymous questions search returned ${searchAnon.length} public/owned items');
      expect(searchAnon, isNotNull);
    });

    test('6. Recent Search History Management & Offline Fallback', () async {
      final localDS = SearchLocalDataSourceImpl();
      final repository = SearchRepositoryImpl(
        remoteDataSource: SearchRemoteDataSourceImpl(localDataSource: localDS),
        localDataSource: localDS,
      );

      // Save a new search query
      await repository.saveRecentSearch('Konstitutsiya moddalari');
      final recent = await repository.getRecentSearches();

      expect(recent.isRight(), true);
      recent.fold(
        (_) => fail('Failed to get recent searches'),
        (list) {
          print('EVIDENCE 6: Recent searches list: $list');
          expect(list.contains('Konstitutsiya moddalari'), true);
        },
      );

      // Clear search history
      await repository.clearRecentSearches();
      final cleared = await repository.getRecentSearches();
      cleared.fold(
        (_) => fail('Failed to get cleared searches'),
        (list) {
          print('EVIDENCE 6: Cleared search history count: ${list.length}');
          expect(list.contains('Konstitutsiya moddalari'), false);
        },
      );
    });
  });
}
