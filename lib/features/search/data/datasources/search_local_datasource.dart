import 'package:lexhub/features/citizen_services/data/datasources/citizen_services_local_datasource.dart';
import 'package:lexhub/features/document_builder/data/datasources/document_templates_local_datasource.dart';
import 'package:lexhub/features/search/data/models/search_result_model.dart';
import 'package:lexhub/features/search/domain/entities/search_result_item.dart';

abstract class SearchLocalDataSource {
  Future<List<String>> getRecentSearches();
  Future<void> saveRecentSearch(String query);
  Future<void> clearRecentSearches();
  Future<List<SearchResultModel>> searchOffline(String query, SearchResultType filterType);
}

/// OFFLINE QIDIRUV FAQAT ILOVA BILAN KELADIGAN KATALOG BO'YICHA ISHLAYDI:
/// hujjat shablonlari va davlat xizmatlari. Bu ma'lumot mahsulotning o'z
/// ma'lumotnomasi (`*_local_datasource` seed'lari repository'larda ham
/// birinchi manba sifatida ishlatiladi), shuning uchun soxta ma'lumot EMAS.
///
/// ADVOKATLAR (`SearchResultType.expert`) offline qidiruvdan OLIB TASHLANDI:
/// u `LegalExpertsLocalDataSource` ichidagi to'qilgan 6 ta "tasdiqlangan
/// advokat"ni (soxta litsenziya, soxta telefon) qaytarardi. Advokat
/// ma'lumoti faqat real bazadan olinadi (§6).
class SearchLocalDataSourceImpl implements SearchLocalDataSource {
  final DocumentTemplatesLocalDataSource? _templatesLocalDS;
  final CitizenServicesLocalDataSource? _servicesLocalDS;

  /// Qidiruv tarixi SESSIYA doirasida saqlanadi (diskka yozilmaydi).
  /// Ilgari bu yerda 4 ta TO'QILGAN "oldingi qidiruv" bor edi va yangi
  /// foydalanuvchi hech qachon qidirmagan so'rovlarni o'z tarixi sifatida
  /// ko'rardi (§6). Doimiy saqlash MVP qamrovidan tashqarida (§22).
  final List<String> _recentSearches = <String>[];

  SearchLocalDataSourceImpl({
    DocumentTemplatesLocalDataSource? templatesLocalDS,
    CitizenServicesLocalDataSource? servicesLocalDS,
  })  : _templatesLocalDS = templatesLocalDS,
        _servicesLocalDS = servicesLocalDS;

  @override
  Future<List<String>> getRecentSearches() async {
    return List<String>.unmodifiable(_recentSearches);
  }

  @override
  Future<void> saveRecentSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    _recentSearches.removeWhere((q) => q.toLowerCase() == trimmed.toLowerCase());
    _recentSearches.insert(0, trimmed);
    if (_recentSearches.length > 10) {
      _recentSearches.removeRange(10, _recentSearches.length);
    }
  }

  @override
  Future<void> clearRecentSearches() async {
    _recentSearches.clear();
  }

  @override
  Future<List<SearchResultModel>> searchOffline(String query, SearchResultType filterType) async {
    final results = <SearchResultModel>[];
    final q = query.toLowerCase().trim();

    // 1. Templates offline
    if (filterType == SearchResultType.all || filterType == SearchResultType.template) {
      final templatesDS = _templatesLocalDS ?? DocumentTemplatesLocalDataSourceImpl();
      final templates = await templatesDS.getTemplates();
      for (final t in templates) {
        if (t.title.toLowerCase().contains(q) ||
            t.description.toLowerCase().contains(q) ||
            t.legalBasisSummary.toLowerCase().contains(q)) {
          results.add(
            SearchResultModel(
              id: t.id,
              type: SearchResultType.template,
              title: t.title,
              subtitle: t.targetAuthority,
              snippet: t.description,
              category: t.category,
              metadata: {
                'legal_basis': t.legalBasisSummary,
                'source_url': t.sourceUrl,
                'is_popular': t.isPopular,
              },
              relevanceScore: t.title.toLowerCase().contains(q) ? 0.95 : 0.7,
            ),
          );
        }
      }
    }

    // 2. Services offline
    if (filterType == SearchResultType.all || filterType == SearchResultType.service) {
      final servicesDS = _servicesLocalDS ?? CitizenServicesLocalDataSourceImpl();
      final services = await servicesDS.getServices();
      for (final s in services) {
        if (s.title.toLowerCase().contains(q) ||
            s.description.toLowerCase().contains(q) ||
            s.department.toLowerCase().contains(q)) {
          results.add(
            SearchResultModel(
              id: s.id,
              type: SearchResultType.service,
              title: s.title,
              subtitle: s.department,
              snippet: s.description,
              category: s.category,
              metadata: {
                'cost_bhm_percent': s.costBhmPercent,
                'is_free': s.isFree,
                'processing_days': s.processingDays,
                'source_url': s.sourceUrl,
                'online_url': s.onlineUrl,
              },
              relevanceScore: s.title.toLowerCase().contains(q) ? 0.95 : 0.7,
            ),
          );
        }
      }
    }

    // 3. Advokatlar offline qidiruvi ATAYLAB YO'Q (yuqoridagi izohga qara):
    //    `SearchResultType.expert` uchun offline natija BO'SH bo'ladi.

    results.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
    return results;
  }
}
