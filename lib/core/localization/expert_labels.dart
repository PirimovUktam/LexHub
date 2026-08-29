// LexHub — ADVOKATLAR (legal experts) yorliqlari va DB qiymatlari chegarasi.
//
// QAT'IY QOIDA (§16): bu yerda FAQAT ekranda ko'rinadigan matn tarjima
// qilinadi. Filtr va ariza qiymatlari (`specialization`, `city`) BACKEND
// kontrakti — ular xom holida uzatiladi:
//   * `FilterSpecializationEvent(raw)` -> `.ilike('specialization', '%raw%')`
//   * `FilterCityEvent(raw)`           -> `.ilike('workplace', '%raw%')`
//     DIQQAT: `city` USTUNI BAZADA YO'Q. Filtr ish joyi MATNIGA qarshi
//     ishlaydi, shuning uchun qiymatlar hudud O'ZAKLARI holida beriladi
//     (`UzbekRegions.filterValues`) — sabab shu faylda yozilgan.
//   * `SubmitExpertApplicationEvent(specialization: raw)` ->
//     `apply_for_expert_verification(p_specialization)`
//
// QO'SHIMCHA QOIDA (§6): bu fayldagi "…Text" funksiyalari HECH QACHON
// to'qima ma'lumot qaytarmaydi. Maydon bo'sh bo'lsa — "ko'rsatilmagan"
// deb yozadi yoki umuman chiqmaydi; soxta ism/telefon/litsenziya/reyting
// O'YLAB TOPILMAYDI (P0-01 precedent).

import 'package:lexhub/features/legal_experts/domain/entities/legal_expert.dart';
import 'package:lexhub/l10n/gen/app_localizations.dart';

/// Advokatlar sahifasidagi mutaxassislik filtri chip'i yorlig'i.
///
/// Kirish — `LegalExpertsPage` dagi XOM qiymat (masalan `Mehnat`), u
/// `ilike` filtriga ketadi. Tanilmagan qiymat xom holida ko'rsatiladi.
String expertSpecializationChipLabel(AppL10n l10n, String raw) {
  switch (raw) {
    case 'Barchasi':
      return l10n.categoryAll;
    case 'Mehnat':
      return l10n.categoryLabor;
    case 'Oila':
      return l10n.categoryFamily;
    case 'Jinoyat':
      return l10n.categoryCriminal;
    case "Yo'l harakati":
      return l10n.homeCatTraffic;
    case "Iste'molchi":
      return l10n.homeCatConsumer;
    case 'Soliq':
      return l10n.homeCatTax;
    case 'Biznes':
      return l10n.homeCatBusiness;
    default:
      return raw;
  }
}

/// Ariza dialogidagi mutaxassislik ro'yxati yorlig'i.
///
/// Bu qiymatlar RPC ga uzatiladi va `expert_profiles.specialization` ga
/// yoziladi, shuning uchun ro'yxatdagi xom matn o'zgarmaydi.
String expertApplySpecializationLabel(AppL10n l10n, String raw) {
  switch (raw) {
    case 'Mehnat huquqi':
      return l10n.expertSpecLabor;
    case 'Oila va Mulk huquqi':
      return l10n.expertSpecFamilyProperty;
    case 'Jinoyat va Tergov himoyasi':
      return l10n.expertSpecCriminalDefense;
    case "Yo'l harakati va Ma'muriy jarimalar":
      return l10n.expertSpecTrafficAdmin;
    case "Iste'molchi huquqlari va Shartnomalar":
      return l10n.expertSpecConsumerContracts;
    case 'Biznes va Korporativ huquq':
      return l10n.expertSpecBusinessCorporate;
    case 'Soliq va Bojxona huquqi':
      return l10n.expertSpecTaxCustoms;
    default:
      return raw;
  }
}

/// Hudud dropdown'i yorlig'i: faqat "hammasi" sentinel'i tarjima qilinadi.
/// Shahar nomlari — atoqli nom, ular tarjima QILINMAYDI.
String expertCityLabel(AppL10n l10n, String raw) =>
    raw == 'Barcha viloyatlar' ? l10n.expertsAllRegions : raw;

/// Advokat ismi. Bo'sh kelsa TO'QIMA ism qo'yilmaydi.
String expertDisplayName(AppL10n l10n, LegalExpert expert) =>
    expert.fullName.trim().isEmpty ? l10n.expertNameUnknown : expert.fullName;

/// Avatar harfi. Bo'sh ism `substring(0, 1)` da RangeError bermasligi kerak.
String expertAvatarInitial(LegalExpert expert) {
  final name = expert.fullName.trim();
  return name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
}

/// Mutaxassislik matni. DB dan kelgan qiymat KONTENT sifatida o'zi
/// ko'rsatiladi (erkin matn, mashina tarjimasi qilinmaydi).
String expertSpecializationText(AppL10n l10n, LegalExpert expert) =>
    expert.specialization.trim().isEmpty
        ? l10n.expertSpecializationUnknown
        : expert.specialization;

/// "Shahar, manzil" satri. Bo'sh maydonlar TASHLAB KETILADI — natija bo'sh
/// bo'lsa, chaqiruvchi UI butun satrni ko'rsatmasligi kerak.
String expertLocationText(LegalExpert expert) => [expert.city, expert.address]
    .map((part) => part.trim())
    .where((part) => part.isNotEmpty)
    .join(', ');

/// Narx matni: DB `price_info` bo'lsa — o'zi; bo'lmasa `consultation_fee`;
/// ikkisi ham bo'lmasa — "kelishuv asosida".
String expertPriceText(AppL10n l10n, LegalExpert expert) {
  final info = expert.priceInfo.trim();
  if (info.isNotEmpty) return info;
  final fee = expert.consultationFee;
  if (fee != null && fee > 0) {
    return l10n.expertFeeAmount(fee.toInt().toString());
  }
  return l10n.expertFeeNegotiable;
}
