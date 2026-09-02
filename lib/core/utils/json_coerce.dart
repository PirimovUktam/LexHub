/// JSON qiymatlarini TUR XAVFSIZ o'qish yordamchilari.
///
/// NIMA UCHUN KERAK: entity'lardagi `json['x'] as String?` shakli MODEL yoki
/// cache noto'g'ri tur qaytarganda `type 'int' is not a subtype of type
/// 'String?'` bilan YIQILADI va butun huquqiy javob `ServerException`ga
/// aylanadi. Bu real xavf, chunki:
///   * Gemini `"article_number": 161` (RAQAM) qaytarishi mumkin —
///     `law_article.dart` esa String kutadi;
///   * `"deadline_days": "30"` (SATR) — `risk_assessment.dart` int kutadi;
///   * Hive cache'dan kelgan ichki obyektlar `Map<dynamic, dynamic>` bo'ladi,
///     `Map<String, dynamic>` EMAS — `whereType<Map<String, dynamic>>()`
///     ularni JIMGINA tashlab yuboradi va `legal_basis` bo'sh qoladi.
///
/// PRINSIP: bu funksiyalar HECH QACHON exception tashlamaydi. Tur mos
/// kelmasa `null` qaytaradi va chaqiruvchi standart qiymatga tushadi
/// (fail-closed), ya'ni bitta buzuq maydon butun javobni yo'q qilmaydi.
library;

/// Matn maydoni. `String` — o'zi; `num` — `toString()` (model modda raqamini
/// raqam sifatida yuborishi ODATIY hol). `bool`/`Map`/`List` — `null`, chunki
/// `"true"` yoki `"{...}"` matn sifatida MA'NOSIZ bo'ladi.
String? jsonText(dynamic raw) {
  if (raw is String) return raw;
  if (raw is num) return raw.toString();
  return null;
}

/// Mantiqiy maydon. `bool` — o'zi; `'true'/'false'` (registr farqsiz) va
/// `1/0` — o'girib olinadi; qolgani `null`.
bool? jsonFlag(dynamic raw) {
  if (raw is bool) return raw;
  if (raw is num) {
    if (raw == 1) return true;
    if (raw == 0) return false;
    return null;
  }
  if (raw is String) {
    final lower = raw.trim().toLowerCase();
    if (lower == 'true') return true;
    if (lower == 'false') return false;
  }
  return null;
}

/// Butun son. `int` — o'zi; chekli `double` — yaqin butun songa; `String` —
/// `int.tryParse`, keyin `double.tryParse`; qolgani `null`.
int? jsonInt(dynamic raw) {
  if (raw is int) return raw;
  if (raw is double) return raw.isFinite ? raw.round() : null;
  if (raw is String) {
    final asInt = int.tryParse(raw.trim());
    if (asInt != null) return asInt;
    final asDouble = double.tryParse(raw.trim());
    if (asDouble != null && asDouble.isFinite) return asDouble.round();
  }
  return null;
}

/// Ichki obyekt. ISTALGAN `Map` qabul qilinadi va kalitlari `String`ga
/// keltiriladi — Hive cache'dan kelgan `Map<dynamic, dynamic>` ham
/// ishlaydi.
Map<String, dynamic>? jsonMap(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) {
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }
  return null;
}
