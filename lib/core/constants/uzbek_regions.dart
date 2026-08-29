// LexHub — O'ZBEKISTON HUDUDLARI: filtr qiymatlari va matndan ajratish.
//
// NIMA UCHUN BU FAYL BOR (o'lchangan nuqson, 2026-08-29):
// advokatlar sahifasidagi "Hudud" dropdown'i `FilterCityEvent` yuboradi va u
// `legal_experts_remote_datasource.dart:81` da `.ilike('workplace', '%$city%')`
// ga aylanadi. Ya'ni filtr HUDUD ustuniga emas, ISH JOYI matniga qarshi
// ishlaydi. Sabab: `city` ustuni bazada UMUMAN YO'Q —
// `supabase/migrations/*.sql` va `supabase/schema.sql` bo'ylab `city` uchun
// nol moslik; `expert_profiles` da faqat `workplace VARCHAR(255)` bor
// (`20260819_base_schema.sql:100`, `20260821010000_expert_verification_and_privacy
// .sql:46`), `public_expert_profiles_view` ham faqat `workplace` ni ochadi.
//
// Natijada ikki aniq zarar bor edi:
//   1. Dropdown qiymatlari "Toshkent sh.", "Samarqand sh." ko'rinishida edi.
//      `ilike` da `.` va `sh.` — ODDIY BELGILAR, regex emas. Ya'ni
//      `%Toshkent sh.%` real ish joyi matnini ("Toshkent shahar advokatlar
//      hay'ati", "Toshkent viloyati advokatura boshqarmasi") TOPMAYDI. Filtr
//      texnik jihatdan ishlagan, lekin amalda deyarli har doim bo'sh ro'yxat
//      qaytargan — foydalanuvchi uchun bu "advokat yo'q" degan YOLG'ON signal.
//   2. `legal_expert_model.dart` `json['city']` ni o'qiydi, u esa view'da
//      yo'q -> `city` DOIM `''`. Shu sababli `expertLocationText()` kartada
//      hududni hech qachon ko'rsatmagan.
//
// SHU FAYL NIMA QILADI: hudud nomini `workplace` MATNIDAN deterministik
// ajratadi va filtrga `ilike` uchun ishonchli O'ZAK beradi. Baza sxemasi
// O'ZGARMAYDI (§12: yangi database redesign qilinmaydi) — bu mavjud
// ma'lumot ustidagi to'g'ri o'qish.
//
// HALOLLIK CHEGARASI (§6, §20): hudud topilmasa `null` qaytadi va UI hududni
// UMUMAN ko'rsatmaydi. Taxmin qilingan yoki to'qima hudud YOZILMAYDI.

/// O'zbekiston Respublikasi hududlari — filtr va matndan ajratish uchun.
class UzbekRegions {
  UzbekRegions._();

  /// Dropdown'dagi "hammasi" sentinel'i. XOM qiymat: `expertCityLabel()`
  /// uni `l10n.expertsAllRegions` ga aylantiradi.
  static const String allSentinel = 'Barcha viloyatlar';

  /// FILTR QIYMATLARI — `ilike '%qiymat%'` ga XOM holida ketadi, shuning
  /// uchun tarjima QILINMAYDI (§16).
  ///
  /// Qiymatlar ataylab O'ZAK holida: "Toshkent" (emas "Toshkent sh.") —
  /// `workplace` matnida "Toshkent shahar", "Toshkent viloyati", "Toshkentdagi"
  /// variantlari uchraydi va o'zak ularning HAMMASINI topadi. Shahar/viloyat
  /// farqini bu daraja DA'VO QILMAYDI — buning uchun bazada alohida ustun
  /// kerak, u esa hozir YO'Q.
  static const List<String> filterValues = [
    allSentinel,
    'Toshkent',
    'Andijon',
    'Buxoro',
    "Farg'ona",
    'Jizzax',
    'Namangan',
    'Navoiy',
    'Qashqadaryo',
    "Qoraqalpog'iston",
    'Samarqand',
    'Sirdaryo',
    'Surxondaryo',
    'Xorazm',
  ];

  /// Hududlar (sentinel'siz) — `regionOf()` shu ro'yxat bo'yicha izlaydi.
  static List<String> get regions => filterValues.sublist(1);

  /// Apostrof va harf registrini bir xillashtiradi: `Farg‘ona`, `Farg'ona`,
  /// `FARGONA` — hammasi bir xil solishtiriladi. Bazadagi matn qo'lda
  /// kiritilgani uchun bu normalizatsiya SHART.
  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll('‘', "'")
      .replaceAll('’', "'")
      .replaceAll('`', "'")
      .replaceAll("g'", 'g')
      .replaceAll("o'", 'o');

  /// Ish joyi matnidan hududni ajratadi. Topilmasa `null` — chaqiruvchi UI
  /// bu holatda hududni KO'RSATMASLIGI kerak (to'qima qiymat yo'q).
  ///
  /// Bir nechta hudud nomi uchrasa BIRINCHISI olinadi (`regions` tartibi
  /// bo'yicha) — natija deterministik.
  static String? regionOf(String? workplace) {
    if (workplace == null) return null;
    final haystack = _normalize(workplace);
    if (haystack.trim().isEmpty) return null;
    for (final region in regions) {
      if (haystack.contains(_normalize(region))) return region;
    }
    return null;
  }
}
