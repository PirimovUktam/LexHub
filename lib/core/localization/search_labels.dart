// LexHub — GLOBAL QIDIRUV yorliqlari (UI label) chegarasi.
//
// QAT'IY QOIDA (§16): bu yerda FAQAT ekranda ko'rinadigan matn tarjima
// qilinadi. `SearchResultType.fromString()` qabul qiladigan xom qiymatlar
// (`law`, `expert`, `service`, `template`, `question`) — backend kontrakti,
// ular O'ZGARMAYDI. Shuningdek qidiruv so'rovi sifatida uzatiladigan
// qiymatlar (`query: "Aliment"` va h.k.) ham tarjima qilinmaydi.

import 'package:lexhub/features/search/domain/entities/search_result_item.dart';
import 'package:lexhub/l10n/gen/app_localizations.dart';

/// Qidiruv filtri turi yorlig'i (ilgari `SearchResultType.label` bo'lgan).
String searchResultTypeLabel(AppL10n l10n, SearchResultType type) {
  switch (type) {
    case SearchResultType.all:
      return l10n.categoryAll;
    case SearchResultType.law:
      return l10n.searchFilterLaws;
    case SearchResultType.expert:
      return l10n.navExperts;
    case SearchResultType.service:
      return l10n.homeCatGovServices;
    case SearchResultType.template:
      return l10n.searchFilterTemplates;
    case SearchResultType.question:
      return l10n.navCommunity;
  }
}
