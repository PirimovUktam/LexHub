// LexHub — grounding (anti-hallucination) filtrining unit testi.
//
// Ishga tushirish:
//   deno test --allow-none supabase/functions/legal-ai/grounding_test.ts
//
// NIMA UCHUN MUHIM: `legal_basis` — foydalanuvchi sudda yoki arizada
// keltiradigan modda raqami. Model to'qib chiqargan raqam UI'ga chiqsa,
// bu shunchaki "AI xatosi" emas — foydalanuvchi mavjud bo'lmagan moddaga
// tayanib huquqini yo'qotishi mumkin. Shuning uchun filtr FAIL-CLOSED
// bo'lishi ISBOTLANISHI kerak, "shunday yozilgan" degani yetarli emas.
import { assertEquals } from 'jsr:@std/assert@1';
import {
  type Chunk,
  findGroundingChunk,
  firstInteger,
  groundLegalBasis,
  isGrounded,
} from './grounding.ts';

const MK: Chunk = {
  documentName: "O'zbekiston Respublikasi Mehnat kodeksi",
  articleNumber: '161',
  articleTitle: 'Ishga tiklash',
  content: "Noqonuniy bo'shatilgan xodim ishga tiklanadi.",
  lexUrl: 'https://lex.uz/docs/1',
};

Deno.test('firstInteger — "161-modda" dan raqam ajratiladi', () => {
  assertEquals(firstInteger('161-modda'), 161);
  assertEquals(firstInteger('161-modda, 2-qism'), 161);
  assertEquals(firstInteger('161'), 161);
  assertEquals(firstInteger('modda yo\'q'), 0);
  assertEquals(firstInteger(''), 0);
});

Deno.test('isGrounded — kontekstdagi modda QABUL qilinadi', () => {
  assertEquals(isGrounded('Mehnat kodeksi', '161-modda', [MK]), true);
  // Hujjat nomi boshqacha yozilgan, lekin "mehnat" tokeni mos keladi.
  assertEquals(isGrounded("O'zR Mehnat Kodeksi", '161', [MK]), true);
});

Deno.test('isGrounded — kontekstda YO\'Q modda RAD etiladi (fail-closed)', () => {
  // To'g'ri hujjat, lekin modda raqami boshqa → gallyutsinatsiya.
  assertEquals(isGrounded('Mehnat kodeksi', '999-modda', [MK]), false);
  // To'g'ri modda raqami, lekin BOSHQA hujjat → aralashtirib yuborilgan.
  assertEquals(isGrounded('Jinoyat kodeksi', '161-modda', [MK]), false);
  // Modda raqami umuman yo'q.
  assertEquals(isGrounded('Mehnat kodeksi', 'nomalum', [MK]), false);
  // Kontekst bo'sh — HECH NARSA tasdiqlanmagan.
  assertEquals(isGrounded('Mehnat kodeksi', '161-modda', []), false);
});

Deno.test('groundLegalBasis — aralash ro\'yxatdan faqat asoslangani qoladi', () => {
  const result = groundLegalBasis([
    { law_name: 'Mehnat kodeksi', article_number: '161-modda', article_text: 'A' },
    { law_name: 'Mehnat kodeksi', article_number: '999-modda', article_text: 'B' },
    { law_name: 'Fuqarolik kodeksi', article_number: '161-modda', article_text: 'C' },
    'satr emas obyekt',
    null,
  ], [MK]);
  assertEquals(result.kept.length, 1);
  assertEquals(result.kept[0].article_number, '161-modda');
  // MODEL MATNI ('A') chunk ichida YO'Q, ya'ni u tekshirilmagan iqtibos.
  // Ilgari bu test uni O'TKAZIB YUBORARDI (`article_text` modeldan olinardi)
  // — bu modda RAQAMI to'g'ri, MATNI esa to'qilgan javob demakdir. Endi
  // rasmiy chunk matni bilan almashtiriladi va bu SANOQDA ko'rinadi.
  assertEquals(result.kept[0].article_text, MK.content);
  assertEquals(result.replacedQuotes, 1);
  assertEquals(result.dropped, 4);
});

Deno.test('groundLegalBasis — RAQAM ko\'rinishidagi article_number ham ishlaydi', () => {
  // `LawArticleChunk.toJson` Dart tomonda `article_number` ni INT qaytaradi.
  // Agar `asScalar` bo'lmasa, bu holat butun ro'yxatni tashlab yuborardi.
  const numeric: Chunk = { ...MK, articleNumber: '161' };
  const result = groundLegalBasis(
    [{ law_name: 'Mehnat kodeksi', article_number: 161 }],
    [numeric],
  );
  assertEquals(result.kept.length, 1);
  assertEquals(result.dropped, 0);
});

Deno.test('groundLegalBasis — massiv bo\'lmagan kirish bo\'sh natija beradi', () => {
  assertEquals(groundLegalBasis(null, [MK]).kept.length, 0);
  assertEquals(groundLegalBasis('legal_basis', [MK]).kept.length, 0);
  assertEquals(groundLegalBasis({ law_name: 'x' }, [MK]).kept.length, 0);
});

Deno.test('groundLegalBasis — camelCase kalitlar ham qabul qilinadi', () => {
  const result = groundLegalBasis(
    [{ lawName: 'Mehnat kodeksi', articleNumber: '161-modda', lexUrl: 'https://lex.uz/x' }],
    [MK],
  );
  assertEquals(result.kept.length, 1);
  // HAVOLA MODELDAN OLINMAYDI. Model yuborgan `https://lex.uz/x` tashlanadi va
  // chunk'ning havolasi qo'yiladi. Ilgari bu test modelning havolasini
  // KUTARDI: modda raqami tasdiqlangan bo'lsa ham, havola BOSHQA moddaga
  // olib borishi mumkin edi va foydalanuvchi buni tekshirilgan iqtibos deb
  // qabul qilardi.
  assertEquals(result.kept[0].lex_url, MK.lexUrl);
});

Deno.test('findGroundingChunk — mos chunk O\'ZI qaytadi', () => {
  assertEquals(findGroundingChunk('Mehnat kodeksi', '161-modda', [MK]), MK);
  assertEquals(findGroundingChunk('Jinoyat kodeksi', '161-modda', [MK]), null);
});

Deno.test('groundLegalBasis — AYNAN mos iqtibos SAQLANADI', () => {
  // Modelning iqtibosi chunk ichida bor: bu TEKSHIRILGAN iqtibos, uni
  // almashtirish ma'nosiz bo'lardi (model qisqa, o'rinli bo'lak tanlagan).
  const result = groundLegalBasis([{
    law_name: 'Mehnat kodeksi',
    article_number: '161-modda',
    article_text: 'xodim ishga tiklanadi',
  }], [MK]);
  assertEquals(result.kept.length, 1);
  assertEquals(result.kept[0].article_text, 'xodim ishga tiklanadi');
  assertEquals(result.replacedQuotes, 0);
});

Deno.test('groundLegalBasis — REGISTR va BO\'SHLIQ farqi iqtibosni buzmaydi', () => {
  const result = groundLegalBasis([{
    law_name: 'Mehnat kodeksi',
    article_number: '161',
    article_text: '  Xodim   ISHGA tiklanadi ',
  }], [MK]);
  assertEquals(result.kept.length, 1);
  assertEquals(result.replacedQuotes, 0);
});

Deno.test('groundLegalBasis — SARLAVHA va HUJJAT NOMI ham chunk\'dan olinadi', () => {
  // Model hujjat nomini "Mehnat kodeksi" deb qisqartirdi va sarlavhani
  // TO'QIDI. Ikkisi ham token mosligi bo'yicha o'tib ketardi.
  const result = groundLegalBasis([{
    law_name: 'Mehnat kodeksi',
    article_number: '161-modda',
    article_title: "To'qilgan sarlavha",
  }], [MK]);
  assertEquals(result.kept.length, 1);
  assertEquals(result.kept[0].article_title, MK.articleTitle);
  assertEquals(result.kept[0].law_name, MK.documentName);
});

Deno.test('groundLegalBasis — iqtibos BO\'SH bo\'lsa almashtirish SANALMAYDI', () => {
  // Model matn bermadi — bu YOLG'ON emas, kamchilik. Rasmiy matn qo'yiladi,
  // lekin `replacedQuotes` oshmaydi: u AYNAN noto'g'ri iqtibos hisoblagichi.
  const result = groundLegalBasis(
    [{ law_name: 'Mehnat kodeksi', article_number: '161-modda' }],
    [MK],
  );
  assertEquals(result.kept.length, 1);
  assertEquals(result.kept[0].article_text, MK.content);
  assertEquals(result.replacedQuotes, 0);
});

Deno.test('groundLegalBasis — chunk havolasi BO\'SH bo\'lsa BO\'SH qoladi', () => {
  // FAIL-CLOSED: modelning havolasi bilan to'ldirish noto'g'ri moddaga
  // olib borish xavfini tiklardi.
  const noUrl: Chunk = { ...MK, lexUrl: '' };
  const result = groundLegalBasis(
    [{ law_name: 'Mehnat kodeksi', article_number: '161', lex_url: 'https://lex.uz/soxta' }],
    [noUrl],
  );
  assertEquals(result.kept.length, 1);
  assertEquals(result.kept[0].lex_url, '');
});
