/// XATOLAR JIM YUTILMAYDI.
///
/// Ikkala shox ham `catch (e)` da mahalliy katalogga tushardi va HECH QANDAY
/// log qoldirmasdi — ya'ni cloud jadvali butunlay ishlamay qolsa ham hech kim
/// sezmasligi mumkin edi (CLAUDE.md §3).
///
/// ZAXIRA XATTI-HARAKATI ATAYLAB SAQLANADI: `citizen_services` mahalliy
/// katalogi bundle'da TO'LIQ (`citizen_services_local_datasource.dart`) —
/// cloud jadvali faqat yangilanish manbasi. Shu sababli timeout'da xato ekrani
/// ko'rsatishdan ko'ra ishlaydigan katalogni berish to'g'ri. Bu Global
/// Search'dagi holatdan FARQ QILADI: u yerda mahalliy baza qamrovi qisman
/// (17 modda) bo'lgani uchun natijani "izlash tugadi" deb ko'rsatish qamrov
/// haqida yolg'on bo'lardi.
library;

import 'package:flutter/foundation.dart';
import 'package:lexhub/core/network/supabase_db.dart';
import 'package:lexhub/features/citizen_services/data/datasources/citizen_services_local_datasource.dart';
import 'package:lexhub/features/citizen_services/data/models/citizen_service_model.dart';
import 'package:lexhub/features/citizen_services/domain/entities/citizen_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class CitizenServicesRemoteDataSource {
  Future<List<CitizenService>> getServices({String? category, String? searchQuery});
  Future<CitizenService> getServiceById(String serviceId);
}

class CitizenServicesRemoteDataSourceImpl implements CitizenServicesRemoteDataSource {
  final SupabaseClient supabaseClient;
  final CitizenServicesLocalDataSource localDataSource;

  CitizenServicesRemoteDataSourceImpl({
    required this.supabaseClient,
    required this.localDataSource,
  });

  @override
  Future<List<CitizenService>> getServices({String? category, String? searchQuery}) async {
    try {
      var query = supabaseClient
          .db('citizen_services')
          .select('*, service_steps(*)');

      if (category != null && category != 'Barchasi') {
        String catFilter = category;
        if (category == "Yo'l harakati") catFilter = 'traffic';
        if (category == "Mehnat huquqi") catFilter = 'labor';
        if (category == "Ijtimoiy himoya") catFilter = 'family';
        if (category == "Iste'molchi huquqi") catFilter = 'civil';
        if (category == "Kadastr va Uy-joy") catFilter = 'real_estate';

        query = query.or('category_id.eq.$catFilter,category_id.eq.$category');
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query.or('title.ilike.%$q%,description.ilike.%$q%,department.ilike.%$q%,legal_basis.ilike.%$q%');
      }

      final response = await query
          .order('is_popular', ascending: false)
          .order('created_at', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      if (data.isEmpty) {
        return await localDataSource.getServices(category: category, searchQuery: searchQuery);
      }

      return data.map((json) => CitizenServiceModel.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[citizen-services] cloud katalog o\'qilmadi, bundle: $e');
      }
      return await localDataSource.getServices(category: category, searchQuery: searchQuery);
    }
  }

  @override
  Future<CitizenService> getServiceById(String serviceId) async {
    try {
      final response = await supabaseClient
          .db('citizen_services')
          .select('*, service_steps(*)')
          .eq('id', serviceId)
          .maybeSingle();

      if (response == null) {
        return await localDataSource.getServiceById(serviceId);
      }

      return CitizenServiceModel.fromJson(response);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[citizen-services] cloud xizmat o\'qilmadi, bundle: $e');
      }
      return await localDataSource.getServiceById(serviceId);
    }
  }
}
