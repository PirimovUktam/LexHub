// LexHub — KATEGORIYA YORLIQLARI (UI label) va DB qiymatlari orasidagi chegara.
//
// QAT'IY QOIDA (§15): `public.categories.name` / `slug` / `id` — DB kontrakti.
// Savol yaratishda kategoriya nomi UUID'ga rezolyutsiya qilinadi
// (`QuestionCategoryCatalog`), shuning uchun UI'da ko'rsatiladigan matnni
// tarjima qilish MUMKIN, lekin uzatiladigan QIYMAT o'zgarmasligi kerak.
//
// Naqsh (butun ilovada bir xil):
//   value:  kategoriyaning DB nomi         <- rezolyutsiyaga ketadi
//   child:  categoryLabel(l10n, dbName)    <- faqat ekranda ko'rinadi
//
// Katalogda bo'lgan, lekin bu yerda tarjimasi yo'q nom uchun DB nomi
// o'zi qaytariladi — ya'ni yangi kategoriya qo'shilsa UI buzilmaydi
// (grafik bo'sh joy emas, real nom ko'rinadi).

import 'package:lexhub/features/community_forum/data/datasources/question_category_resolver.dart';
import 'package:lexhub/l10n/gen/app_localizations.dart';

/// Kategoriyaning DB nomini tanlangan tildagi yorliqqa aylantiradi.
String categoryLabel(AppL10n l10n, String dbName) {
  switch (QuestionCategoryCatalog.normalizeName(dbName)) {
    case 'barchasi':
      return l10n.categoryAll;
    case 'mehnat huquqi':
      return l10n.categoryLabor;
    case 'oila huquqi':
      return l10n.categoryFamily;
    case 'fuqarolik huquqi':
      return l10n.categoryCivil;
    case 'jinoyat huquqi':
      return l10n.categoryCriminal;
    case "ma'muriy huquqi":
    case "ma'muriy huquq":
      return l10n.categoryAdministrative;
    case 'umumiy':
      return l10n.categoryGeneral;
    default:
      return dbName;
  }
}

/// Home/FAQ seed kataloglaridagi 13 huquqiy kategoriya yorliqlari.
///
/// Kirish sifatida kategoriya SARLAVHASI (`LegalCategory.title` yoki
/// `SeedQuestionModel.categoryName`) keladi — bu lokal seed ma'lumot, DB
/// kontrakti emas, lekin filtr `cat.id` orqali ishlaydi, shuning uchun
/// yorliqni tarjima qilish xavfsiz.
///
/// Tanilmagan qiymat uchun [categoryLabel] ga o'tadi (u ham topolmasa xom
/// nomni qaytaradi) — ya'ni yangi kategoriya qo'shilganda UI buzilmaydi.
String homeCategoryLabel(AppL10n l10n, String title) {
  switch (QuestionCategoryCatalog.normalizeName(title)) {
    case "yo'l harakati":
      return l10n.homeCatTraffic;
    case "ma'muriy jarimalar":
      return l10n.homeCatAdminFines;
    case "iste'molchi huquqi":
    case "iste'molchi huquqlari":
      return l10n.homeCatConsumer;
    case 'uy-joy va kadastr':
    case 'kadastr va uy-joy':
      return l10n.homeCatHousing;
    case 'ijtimoiy himoya':
      return l10n.categorySocialProtection;
    case 'soliq masalalari':
      return l10n.homeCatTax;
    case 'bank va kredit':
      return l10n.homeCatBanking;
    case 'mulk va meros':
      return l10n.homeCatInheritance;
    case 'davlat xizmatlari':
      return l10n.homeCatGovServices;
    case 'sud masalalari':
      return l10n.homeCatCourt;
    case 'biznes va shartnomalar':
      return l10n.homeCatBusiness;
    default:
      return categoryLabel(l10n, title);
  }
}

/// Davlat xizmatlari va hujjat shablonlari filtr kategoriyalari yorlig'i.
///
/// `CitizenServicesPage.categories` va `DocumentTemplatesPage.categories`
/// ro'yxatlari xom (o'zbekcha) qiymatlarni saqlaydi, chunki ular
/// `FilterServicesByCategoryEvent(cat)` / `LoadTemplatesListEvent(category:)`
/// ga QIYMAT sifatida ketadi va data-layer'da `service.category` /
/// `template.category` bilan solishtiriladi. Shu sababli faqat ekranda
/// ko'rinadigan matn shu funksiya orqali tarjima qilinadi.
String catalogCategoryLabel(AppL10n l10n, String name) =>
    homeCategoryLabel(l10n, name);
