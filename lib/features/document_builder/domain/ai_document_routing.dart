/// AI JAVOBIDAN HUJJAT SHABLONIGA YO'NALTIRISH — sof (pure) qoidalar.
///
/// NIMA UCHUN ALOHIDA FAYL: bu jadvallar ilgari `legal_assistant_page.dart`
/// ichida, `_openRelatedDocumentBuilder` metodining tanasida edi va shu
/// sababli TEST QILINMAS edi. Auditda topilgan IKKI nuqson aynan shu
/// jadvallarning katalog bilan MOS EMASLIGI edi:
///
///   1. `template_debt_pretenziya` ga yo'naltirilardi, lekin bu id HECH QAYSI
///      ko'rib chiqiladigan katalogda yo'q edi (uchinchi, faqat AI yo'liga
///      xos katalogda bor edi).
///   2. Muammo tavsifi `violation_details` kalitiga yozilardi — bu kalit
///      FAQAT o'sha uchinchi katalogda bor. Haqiqiy katalogda (baza seed'i va
///      bundle) maydon nomi `violation_reason`. Ya'ni AI aniqlagan tavsif
///      hujjatga TUSHMASDI va hech qanday xato ko'rinmasdi (§20).
///
/// Endi jadvallar `document_template_catalog_consistency_test.dart` da
/// KATALOGNING O'ZIGA solishtiriladi: yo'naltirilgan har bir id katalogda
/// bo'lishi shart va to'ldirilgan har bir maydon shu shablonda mavjud
/// bo'lishi shart.
library;

class AiDocumentRouting {
  const AiDocumentRouting._();

  /// Kalit so'z -> shablon id. TARTIB MUHIM: birinchi mos kelgan shox
  /// tanlanadi (aniqroq mavzular yuqorida).
  ///
  /// `else` (catch-all) shoxi ATAYLAB YO'Q: mos kelmasa `null` qaytadi va
  /// UI foydalanuvchiga shablonni O'ZI tanlashni taklif qiladi. Ilgari
  /// catch-all noto'g'ri hujjatni "topilgan" qilib ko'rsatardi.
  static const List<(String, List<String>)> _rules = [
    (
      'template_alimony_petition',
      // ANIQROQ SHOX BIRINCHI: "aliment" savolida "farzand"/"bola" so'zlari
      // bilan birga "sud" ham uchraydi, lekin bu mehnat yoki qarz nizosi
      // EMAS. Ilgari aliment uchun shox BUTUNLAY yo'q edi: `legal_assistant_page`
      // da "Aliment undirish" tezkor tugmasi bor edi, hujjat esa
      // ochilmasdi (§9 uzilishi).
      ['aliment', 'nafaqa', 'farzand ta\'minot', 'bola ta\'minot'],
    ),
    (
      'template_labor_complaint',
      ['mehnat', 'ishdan', 'ish beruvchi'],
    ),
    (
      'template_traffic_fine_appeal',
      ['jarima', 'radar', 'ypx', 'yo\'l'],
    ),
    (
      'template_debt_pretenziya',
      ['qarz', 'tilxat', 'kredit'],
    ),
    (
      'template_consumer_refund',
      ['iste\'molchi', 'tovar', 'do\'kon', 'kafolat', 'sifatsiz'],
    ),
  ];

  /// Muammo tavsifi YOZILADIGAN maydon id'si (shablon bo'yicha).
  ///
  /// QO'LDA yozilgan, avtomatik "birinchi multiline maydonni topish" EMAS:
  /// aliment shablonining yagona erkin matn maydoni `children_info`
  /// ("bolalar F.I.Sh va tug'ilgan sanalari") — unga muammo tavsifini
  /// yozib qo'yish HUJJATNI BUZADI. Shu sababli aliment bu jadvalda
  /// ATAYLAB YO'Q: shablon ochiladi, lekin to'ldirilmaydi.
  static const Map<String, String> _summaryField = {
    'template_labor_complaint': 'violation_reason',
    'template_consumer_refund': 'defect_details',
    'template_traffic_fine_appeal': 'appeal_reason',
    'template_debt_pretenziya': 'debt_details',
  };

  /// Yo'naltirish mumkin bo'lgan BARCHA shablon id'lari (test uchun ham).
  static List<String> get routableTemplateIds =>
      _rules.map((r) => r.$1).toList(growable: false);

  /// Matnga qarab shablon id. Mos kelmasa `null`.
  static String? templateIdFor(String text) {
    final lower = text.toLowerCase();
    for (final (id, keywords) in _rules) {
      for (final k in keywords) {
        if (lower.contains(k)) return id;
      }
    }
    return null;
  }

  /// Shu shablonda muammo tavsifi yoziladigan maydon id. Yo'q bo'lsa `null`.
  static String? summaryFieldFor(String templateId) =>
      _summaryField[templateId];

  /// Test uchun: to'ldirish jadvalining o'zi.
  static Map<String, String> get summaryFieldMap => _summaryField;
}
