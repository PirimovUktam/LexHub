import 'package:lexhub/core/errors/exceptions.dart';
import 'package:lexhub/features/search/data/datasources/search_local_datasource.dart';
import 'package:lexhub/features/search/data/models/search_result_model.dart';
import 'package:lexhub/features/search/domain/entities/search_result_item.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class SearchRemoteDataSource {
  Future<List<SearchResultModel>> search({
    required String query,
    SearchResultType filterType = SearchResultType.all,
    int limit = 20,
    int offset = 0,
  });
}

/// Global qidiruv `global_search` RPC orqali ishlaydi.
///
/// XATO SIYOSATI (§6): ilgari BARCHA xatolar `catch (_)` bilan yutilib,
/// offline natijalar MUVAFFAQIYAT sifatida qaytarilardi — ya'ni `global_search`
/// RPC'i yo'q bo'lsa yoki SQL xatosi bo'lsa ham foydalanuvchi "hammasi joyida"
/// deb o'ylardi. Endi:
///   * tarmoq/ulanish xatosi  -> offline katalog (shablon + xizmat) qaytariladi,
///     chunki bu ma'lumot ilova bilan BIRGA KELADIGAN haqiqiy ma'lumotnoma
///     (soxta emas) va offline rejim MVP oqimi hisoblanadi;
///   * server/RPC/DB xatosi   -> `ServerException` (UI xato + "Qaytadan urinish").
class SearchRemoteDataSourceImpl implements SearchRemoteDataSource {
  final SupabaseClient? _supabaseClient;
  final SearchLocalDataSource _localDataSource;

  SearchRemoteDataSourceImpl({
    SupabaseClient? supabaseClient,
    required SearchLocalDataSource localDataSource,
  })  : _supabaseClient = supabaseClient,
        _localDataSource = localDataSource;

  @override
  Future<List<SearchResultModel>> search({
    required String query,
    SearchResultType filterType = SearchResultType.all,
    int limit = 20,
    int offset = 0,
  }) async {
    final client = _supabaseClient ?? Supabase.instance.client;
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    try {
      final response = await client.rpc(
        'global_search',
        params: {
          'query_text': cleanQuery,
          'filter_type': filterType.name,
          'match_limit': limit,
          'match_offset': offset,
        },
      );

      if (response is List) {
        final remoteResults = response
            .whereType<Map<String, dynamic>>()
            .map(SearchResultModel.fromJson)
            .toList();
        if (remoteResults.isNotEmpty) return remoteResults;

        // RPC muvaffaqiyatli, lekin natija bo'sh: ilova bilan keladigan
        // shablon/xizmat katalogidan to'ldiramiz (soxta ma'lumot emas).
        return _localDataSource.searchOffline(cleanQuery, filterType);
      }

      throw ServerException(
        message: "Qidiruv natijasi noto'g'ri formatda keldi.",
        details: response,
      );
    } catch (e) {
      if (e is AppException) rethrow;
      // Faqat ULANISH uzilganda offline katalogga tushamiz.
      if (_isConnectivityError(e)) {
        return _localDataSource.searchOffline(cleanQuery, filterType);
      }
      throw ServerException(
        message: "Qidiruvni bajarib bo'lmadi: $e",
        details: e,
      );
    }
  }

  /// `dart:io` (web'da mavjud emas) importidan qochish uchun xato turi
  /// matn ko'rinishida aniqlanadi. Bu YAGONA joyda saqlanadi.
  static bool _isConnectivityError(Object error) {
    if (error is NetworkException) return true;
    final text = error.toString().toLowerCase();
    return text.contains('socketexception') ||
        text.contains('clientexception') ||
        text.contains('failed host lookup') ||
        text.contains('connection refused') ||
        text.contains('connection closed') ||
        text.contains('connection reset') ||
        text.contains('network is unreachable') ||
        text.contains('timeoutexception');
  }
}
