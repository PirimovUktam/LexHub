/// P2 — XATO XABARLARI LOKALIZATSIYASI: MASHINA O'QIY OLADIGAN KOD.
///
/// MUAMMO: `Failure.message` — o'zbekcha, datasource ichida qotib qolgan
/// matn (18 faylda 74 ta literal). Ingliz tilida ilova ishlaganda ham
/// foydalanuvchi o'zbekcha xato ko'radi; bundan tashqari ba'zi joylarda
/// server/DB matni to'g'ridan-to'g'ri UI'ga chiqib ketadi.
///
/// YECHIM (minimal, scalable): 74 ta literalni ARB'ga ko'chirish EMAS —
/// `Failure` ga TIL'DAN MUSTAQIL `code` qo'shiladi. Kod markaziy nuqtada
/// (`ErrorHandler`) belgilanadi, presentation qatlami `failureText(l10n, f)`
/// orqali tarjima qiladi. Original o'zbekcha texnik matn `Failure.message`
/// da QOLADI — log/debug uchun kerak.
enum FailureCode {
  /// Internet yo'q / DNS / socket xatosi.
  network,

  /// Server javob bermadi (connect/send/receive timeout).
  timeout,

  /// 5xx yoki noaniq server xatosi.
  server,

  /// 401 — sessiya tugagan yoki login kerak.
  unauthorized,

  /// 403 / RLS rad etdi — ruxsat yo'q.
  forbidden,

  /// 404 — resurs topilmadi.
  notFound,

  /// 429 — rate limit.
  rateLimited,

  /// Foydalanuvchi kiritgan ma'lumot noto'g'ri.
  validation,

  /// Lokal cache (Hive/SharedPreferences) o'qilmadi.
  cache,

  /// So'rov bekor qilindi.
  cancelled,

  /// Kod aniqlanmagan. UI umumiy xabar ko'rsatadi, texnik matn LOG'da qoladi.
  unknown,
}
