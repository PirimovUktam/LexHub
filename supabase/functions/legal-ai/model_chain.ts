// LexHub — `legal-ai` MODEL ZANJIRI QARORI (bitta sof funksiya).
//
// NIMA UCHUN ALOHIDA FAYL: `index.ts` yuklanishi bilan `Deno.serve` ni
// ishga tushiradi, ya'ni uni testdan import qilib bo'lmaydi. Qaror mantig'i
// shu yerda turgani uchun u REAL RUNTIME testda tekshiriladi
// (`model_chain_test.ts`), "kodda shunday yozilgan" degani bilan emas
// (CLAUDE.md §0).

/// Upstream shu `status` ni qaytarganda ZAXIRA modelga o'tamizmi?
///
/// `true` = bu nosozlik MODELGA XOS bo'lishi mumkin, zanjirni davom ettir.
/// `false` = model almashtirish YORDAM BERMAYDI, bor javobni qaytar.
///
/// O'LCHANGAN (2026-09-04, PRODUCTION, `tool/probe_legal_ai_latency.py` +
/// `LEGAL_AI_DEBUG_UPSTREAM=1`):
///   `upstream_status = 429`, `upstream_model = gemini-3.6-flash`,
///   upstream xabari "You exceeded your current quota".
///   75 sekund kutish YORDAM BERMADI (ya'ni daqiqalik burst emas, KUNLIK
///   kvota), lekin AYNI daqiqalarda `gemini-3.7-flash` 200 + `source=llm`
///   qaytardi.
///
/// XATO TAXMIN TUZATILDI: ilgari `index.ts` izohida "429 (kvota) modelga
/// bog'liq EMAS — zanjirni to'xtatadi" deb yozilgandi. Yuqoridagi o'lchov
/// buni RAD ETADI: Gemini bepul kvotasi HAR MODEL uchun ALOHIDA hisoblanadi.
/// Eski qoida bilan asosiy model kvotasi tugagach foydalanuvchi `ai_quota`
/// olardi, holbuki zaxira modelda kvota BOR edi — 0/3 muvaffaqiyat.
/// Model zanjiri secret orqali almashtirilgandan keyin 2/3 bo'ldi.
///
/// 429 NARXI — HALOL AYTILADI: kvota IKKI modelda ham tugagan bo'lsa,
/// foydalanuvchi bitta emas, IKKI rad javobini kutadi. O'lchangan 429 rad
/// vaqti 1.0–1.9 s, ya'ni qo'shimcha kechikish ~2 s dan oshmaydi va
/// `callGemini` dagi `MIN_ATTEMPT_MS` / `deadline` qulfi umumiy byudjetdan
/// chiqib ketishga YO'L QO'YMAYDI.
///
/// Ro'yxatga KIRMAGANLAR va sababi:
///   * `401` / `403` — kalit muammosi. Kalit BITTA, model almashtirish
///     befoyda (o'lchangan emas, mantiqiy: kalit modelga bog'liq emas).
///   * `400` — payload imzosi. `callModel` uni payload VARIANTLARI bilan
///     hal qiladi, model bilan emas.
///   * `500` / `502` — server yoki javobni ajratish xatosi. Bu yerda
///     to'xtaymiz: zanjirni davom ettirish o'lchangan foyda bermadi.
///   * `200` — muvaffaqiyat, zanjir kerak emas.
export function shouldTryNextModel(status: number): boolean {
  return status === 503 || status === 404 || status === 504 || status === 429;
}
