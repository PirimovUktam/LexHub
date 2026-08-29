// LexHub — `legal-ai` funksiyasining GROUNDING (anti-hallucination) yadrosi.
//
// NIMA UCHUN ALOHIDA FAYL: `index.ts` import qilinishi bilan `Deno.serve`
// ishga tushadi, ya'ni uni test faylidan import qilish server ko'taradi.
// Xavfsizlik uchun eng muhim mantiq — modelning to'qib chiqargan moddasini
// tashlab yuborish — UNIT TEST bilan isbotlanishi kerak
// (`grounding_test.ts`). Shuning uchun sof funksiyalar shu yerda.

export interface Chunk {
  documentName: string;
  articleNumber: string;
  articleTitle: string;
  content: string;
  lexUrl: string;
}

export function asString(value: unknown, fallback = ''): string {
  return typeof value === 'string' ? value : fallback;
}

/// `LawArticleChunk.articleNumber` Dart tomonda `int` (`toJson` → raqam),
/// `LawArticle.articleNumber` esa `String` ("161-modda"). Ikkalasi ham shu
/// funksiyadan o'tadi, aks holda raqam kelganda `asString` bo'sh satr qaytarib
/// grounding filtri HAMMASINI tashlab yuborardi.
export function asScalar(value: unknown): string {
  if (typeof value === 'string') return value;
  if (typeof value === 'number' && Number.isFinite(value)) return String(value);
  return '';
}

export function asStringList(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value.map((e) => asString(e)).filter((e) => e.trim().length > 0);
}

export function firstInteger(value: string): number {
  const match = value.match(/\d+/);
  return match ? Number(match[0]) : 0;
}

/// O'ZBEK HUQUQIY HUJJAT NOMLARIDA UMUMIY bo'lgan tokenlar. Bularni
/// solishtirishdan CHIQARIB tashlash SHART: "Mehnat kodeksi" va "Jinoyat
/// kodeksi" `kodeksi` tokenida mos keladi, ya'ni ular bo'lmasa filtr
/// "Jinoyat kodeksi 161-modda" ni Mehnat kodeksi chunk'i bilan tasdiqlab
/// qo'yardi (bu aynan `grounding_test.ts` topgan teshik).
const STOP_TOKENS = new Set([
  'kodeks', 'kodeksi', 'kodeksining', 'qonun', 'qonuni', 'qonunining',
  'respublikasi', 'respublikasining', 'zbekiston', 'ozbekiston',
  'modda', 'moddasi', 'qism', 'qismi', 'band', 'bandi',
  'tahrir', 'tahriri', 'sonli', 'qarori', 'farmoni', 'toris', 'sidagi',
]);

function docTokens(name: string): string[] {
  return name
    .toLowerCase()
    .split(/[^\p{L}\p{N}]+/u)
    .filter((t) => t.length > 3 && !STOP_TOKENS.has(t));
}

/// FAIL-CLOSED: mos chunk topilmasa `false`.
///
/// KLIENT NUSXASI: `LegalGroundingValidator.isGrounded`
/// (`lib/core/legal_safety/legal_grounding_validator.dart`) — endi u ham
/// FAIL-CLOSED. Ilgari klientda `firstWhere(..., orElse: () =>
/// LawArticleChunk(status: 'active'))` bor edi, ya'ni mos chunk topilmasa
/// SUN'IY "active" chunk yasab moddani QOLDIRARDI (audit topilmasi P1,
/// tuzatildi). Regressiya:
/// `test/core/security/legal_grounding_parity_test.dart`.
///
/// ATAYLAB FARQ: klient qo'shimcha ravishda `chunk.isActive`ni ham tekshiradi
/// (unda chunk'ning `status` maydoni bor). Bu yerdagi `Chunk` interfeysida
/// `status` yo'q — serverga keladigan chunk'lar allaqachon
/// `.eq('status','active')` bilan tanlangan.
///
/// `STOP_TOKENS` ikki tomonda BIR XIL bo'lishi shart — yuqoridagi test buni
/// qulflaydi.
export function isGrounded(lawName: string, articleNumber: string, chunks: Chunk[]): boolean {
  return findGroundingChunk(lawName, articleNumber, chunks) !== null;
}

/// `isGrounded` ning ASOSI: mos chunk'ning O'ZINI qaytaradi.
///
/// NIMA UCHUN KERAK: `groundLegalBasis` faqat "asoslanganmi?" degan savolga
/// javob bilan cheklanmaydi — u modda MATNI va HAVOLASINI ham chunk'dan
/// oladi. Boolean bilan buni qilib bo'lmaydi.
export function findGroundingChunk(
  lawName: string,
  articleNumber: string,
  chunks: Chunk[],
): Chunk | null {
  const number = firstInteger(articleNumber);
  if (number === 0) return null;
  const wanted = docTokens(lawName);
  // Farqlovchi token qolmasa (masalan lawName = "Kodeks") hujjatni
  // TASDIQLAB bo'lmaydi → rad etamiz. Prompt modeldan hujjat nomini
  // kontekstdan AYNAN ko'chirishni talab qiladi.
  if (wanted.length === 0) return null;
  for (const chunk of chunks) {
    if (firstInteger(chunk.articleNumber) !== number) continue;
    const have = docTokens(chunk.documentName);
    if (wanted.some((t) => have.includes(t))) return chunk;
  }
  return null;
}

/// IQTIBOSNI SOLISHTIRISH uchun normallashtirish: registr va bo'shliq
/// FARQI iqtibosni yolg'on qilmaydi, shuning uchun ular o'chiriladi.
/// Tinish belgilari ATAYLAB SAQLANADI — "18 yoshgacha" va "18 yoshgacha,"
/// farqi ma'noni o'zgartirmaydi, lekin so'z tushib qolishi o'zgartiradi va
/// tinish belgisini tashlash "not" / "emas" kabi inkorlarni yashirishga yo'l
/// ochib berardi.
function normalizeQuote(text: string): string {
  return text.toLowerCase().replace(/\s+/gu, ' ').trim();
}

/// IQTIBOS ENG KAM UZUNLIGI. Qisqa bo'lak manba ichida TASODIFAN topiladi:
/// `"A"` harfi deyarli har qanday o'zbek matnida bor, ya'ni bir harfli
/// "iqtibos" tekshiruvni bekorga o'tkazib yuborardi (bu chegara AYNAN
/// `grounding_test.ts` topgan teshik uchun qo'yildi). Shundan qisqa matn
/// DALIL emas, shuning uchun tekshirilmagan deb hisoblanadi va rasmiy matn
/// bilan almashtiriladi.
///
/// KLIENT NUSXASI: `LegalGroundingValidator.minQuoteChars`. Ikki tomonda BIR
/// XIL bo'lishi shart — `legal_grounding_parity_test.dart` shu faylni o'qib
/// sonni solishtiradi.
const MIN_QUOTE_CHARS = 12;

/// RUNTIME'DA O'LCHANGAN (2026-08-29, PRODUCTION Edge Function):
/// `verify_legal_ai_proxy_live_test.dart` deploy'dan keyin ishga tushirildi —
/// haqiqiy foydalanuvchi sessiyasi, haqiqiy Gemini chaqiruvi, HTTP 200,
/// `source=llm`, 3 modda (161/333/560). EVIDENCE 6: qaytgan HAR BIR
/// moddaning `article_text`, `lex_url`, `article_title` va `law_name`
/// qiymati BIZ YUBORGAN chunk bilan mos keldi. Negative stsenariylar ham
/// o'sha yugurishda: GET -> 405, Bearer'siz -> 401, anon kalit -> 401
/// `invalid_or_anonymous_token`.
///
/// Ilgari bu maydonlar MODELNING JSON'idan o'tib ketardi: modda RAQAMI
/// tasdiqlanib, ostida TO'QILGAN iqtibos va BOSHQA moddaga olib boradigan
/// lex.uz havolasi turishi mumkin edi. Bu ochiq soxta moddadan XAVFLIROQ —
/// u tekshirilgan ko'rinadi.

export function groundLegalBasis(raw: unknown, chunks: Chunk[]): {
  kept: Array<Record<string, string>>;
  dropped: number;
  replacedQuotes: number;
} {
  const kept: Array<Record<string, string>> = [];
  let dropped = 0;
  let replacedQuotes = 0;
  const items = Array.isArray(raw) ? raw : [];
  for (const item of items) {
    if (typeof item !== 'object' || item === null) { dropped++; continue; }
    const a = item as Record<string, unknown>;
    const lawName = asScalar(a.law_name ?? a.lawName).slice(0, 300);
    const articleNumber = asScalar(a.article_number ?? a.articleNumber).slice(0, 80);
    const chunk = findGroundingChunk(lawName, articleNumber, chunks);
    if (chunk === null) { dropped++; continue; }

    // IQTIBOS TEKSHIRILADI. Modda RAQAMI asoslangani modelning o'sha modda
    // haqida TO'G'RI yozganini bildirmaydi: raqam mos kelib, matn to'qilgan
    // bo'lishi mumkin. Model iqtibosi chunk ichida AYNAN topilmasa, u
    // ISHONCHLI EMAS va chunk'ning o'z matni bilan almashtiriladi.
    //
    // Bu YO'NALISH ataylab: tekshirilmagan iqtibosni ko'rsatgandan ko'ra
    // rasmiy matnni ko'rsatish xavfsizroq. Almashtirish soni javobda
    // `replaced_quotes` bo'lib qaytadi — jim tuzatish YO'Q (§20).
    const modelText = asScalar(a.article_text ?? a.articleText).slice(0, 4000);
    const normalizedQuote = normalizeQuote(modelText);
    const quoteVerified = normalizedQuote.length >= MIN_QUOTE_CHARS &&
      normalizeQuote(chunk.content).includes(normalizedQuote);
    if (modelText.length > 0 && !quoteVerified) replacedQuotes++;

    kept.push({
      // HUJJAT NOMI, SARLAVHA va HAVOLA — CHUNK'DAN. Model qiymati faqat
      // TOKEN MOSLIGI bo'yicha tekshirilgan, ya'ni "Mehnat kodeksi" chunk'i
      // "Mehnat kodeksining 2019 tahriri" deb yozilishi mumkin edi. Havola
      // esa umuman tekshirilmagan: noto'g'ri lex.uz havolasi foydalanuvchini
      // BOSHQA moddaga olib borardi va bu tasdiqlangan iqtibos ko'rinishida
      // bo'lardi. Chunk bo'sh qiymat bersa — BO'SH qoladi (fail-closed):
      // noto'g'ri havoladan ko'ra havolasizlik yaxshi.
      law_name: chunk.documentName.slice(0, 300),
      article_number: articleNumber,
      article_title: chunk.articleTitle.slice(0, 300),
      article_text: quoteVerified ? modelText : chunk.content.slice(0, 4000),
      lex_url: chunk.lexUrl.slice(0, 500),
    });
  }
  return { kept, dropped, replacedQuotes };
}
