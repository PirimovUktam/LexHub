// LexHub — MODEL ZANJIRI QARORINING UNIT TESTI (real Deno runtime).
//
// Ishga tushirish:
//   deno test --allow-none supabase/functions/legal-ai/model_chain_test.ts
//
// NIMA UCHUN MUHIM: bu bitta shart foydalanuvchi AI javobini OLADIMI yoki
// "AI EMAS" deterministik matnni oladimi — shuni hal qiladi. 2026-09-04 da
// PRODUCTION'da aynan shu shart sabab 429 (kvota) kelganda zaxira modelga
// O'TILMADI va probe 0/3 muvaffaqiyat berdi, holbuki zaxira modelda kvota
// BOR edi (`upstream_model = gemini-3.6-flash` 429, `gemini-3.7-flash` 200).
//
// XATONI QAYTA HOSIL QILISH (CLAUDE.md §16 — bajarildi, 2026-09-04):
// `model_chain.ts` dagi shartdan `|| status === 429` OLIB TASHLANDI va
// `deno test` ishga tushirildi -> AYNAN 2 ta test yiqildi:
//   `429 (kvota) -> ZAXIRA MODELGA O'TILADI` va
//   `zanjirni davom ettiradigan status'lar RO'YXATI`.
// Keyin qaytarildi -> 9/9 o'tdi. Ya'ni bu testlar BO'SH EMAS.
import { assertEquals } from 'jsr:@std/assert@1';
import { shouldTryNextModel } from './model_chain.ts';

Deno.test("429 (kvota) -> ZAXIRA MODELGA O'TILADI", () => {
  // O'LCHANGAN (2026-09-04 production): kvota HAR MODEL uchun ALOHIDA.
  // `gemini-3.6-flash` 429 bergan daqiqada `gemini-3.7-flash` 200 qaytardi.
  assertEquals(shouldTryNextModel(429), true);
});

Deno.test("503 (Google band) -> ZAXIRA MODELGA O'TILADI", () => {
  assertEquals(shouldTryNextModel(503), true);
});

Deno.test("404 (model nomi yo'q) -> ZAXIRA MODELGA O'TILADI", () => {
  assertEquals(shouldTryNextModel(404), true);
});

Deno.test('504 (timeout) -> ZAXIRA MODELGA OTILADI', () => {
  // O'LCHANGAN (2026-08-26): `gemini-3.7-flash` 40000ms timeout bergan
  // daqiqada `gemini-3.6-flash` ayni endpoint'ga 200 qaytardi.
  assertEquals(shouldTryNextModel(504), true);
});

Deno.test('200 (muvaffaqiyat) -> zanjir DAVOM ETMAYDI', () => {
  assertEquals(shouldTryNextModel(200), false);
});

Deno.test('401 / 403 (kalit) -> zanjir DAVOM ETMAYDI', () => {
  // Kalit BITTA — boshqa modelda ham AYNI kalit ishlatiladi.
  assertEquals(shouldTryNextModel(401), false);
  assertEquals(shouldTryNextModel(403), false);
});

Deno.test('400 (payload) -> zanjir DAVOM ETMAYDI', () => {
  // Buni `callModel` payload VARIANTLARI bilan hal qiladi.
  assertEquals(shouldTryNextModel(400), false);
});

Deno.test('500 / 502 -> zanjir DAVOM ETMAYDI', () => {
  assertEquals(shouldTryNextModel(500), false);
  assertEquals(shouldTryNextModel(502), false);
});

// ANTI-VAKUUM: yuqoridagi testlar bittalab status'ni tekshiradi, ya'ni
// KENGAYTIRIB yuborilgan shartni (masalan "hamma 4xx da o't") ushlamaydi.
// Bu test ro'yxatni TO'LIQ qulflaydi: 100..599 oralig'ida `true` qaytaradigan
// status'lar AYNAN shu to'rtta bo'lishi kerak.
Deno.test("zanjirni davom ettiradigan status'lar RO'YXATI", () => {
  const yes: number[] = [];
  for (let s = 100; s <= 599; s++) {
    if (shouldTryNextModel(s)) yes.push(s);
  }
  assertEquals(yes, [404, 429, 503, 504]);
});
