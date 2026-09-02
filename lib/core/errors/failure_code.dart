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

  /// Ekspert arizasi rad etilgan va sovutish davri hamon davom etadi
  /// (server SQLSTATE `LX429`, HTTP 423 ga moslanadi).
  ///
  /// `rateLimited` DAN ALOHIDA: `errorRateLimited` matni "bir necha
  /// daqiqadan keyin" deydi, sovutish davri esa 24 SOAT — ya'ni umumiy
  /// matn foydalanuvchini CHALG'ITARDI (§20).
  applicationCooldown,

  /// `signUp` hisob yaratdi, LEKIN sessiya bermadi — email tasdiqlash kerak
  /// (`EmailConfirmationRequiredException`).
  ///
  /// XATO EMAS: UI buni qizil xato sifatida EMAS, ko'rsatma sifatida
  /// ko'rsatadi (`EmailConfirmationRequired` holati).
  emailConfirmationRequired,

  /// Foydalanuvchi kiritgan ma'lumot noto'g'ri.
  validation,

  /// Lokal cache (Hive/SharedPreferences) o'qilmadi.
  cache,

  /// So'rov bekor qilindi.
  cancelled,

  /// Kod aniqlanmagan. UI umumiy xabar ko'rsatadi, texnik matn LOG'da qoladi.
  unknown,
}
