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
  const number = firstInteger(articleNumber);
  if (number === 0) return false;
  const wanted = docTokens(lawName);
  // Farqlovchi token qolmasa (masalan lawName = "Kodeks") hujjatni
  // TASDIQLAB bo'lmaydi → rad etamiz. Prompt modeldan hujjat nomini
  // kontekstdan AYNAN ko'chirishni talab qiladi.
  if (wanted.length === 0) return false;
  for (const chunk of chunks) {
    if (firstInteger(chunk.articleNumber) !== number) continue;
    const have = docTokens(chunk.documentName);
    if (wanted.some((t) => have.includes(t))) return true;
  }
  return false;
}

export function groundLegalBasis(raw: unknown, chunks: Chunk[]): {
  kept: Array<Record<string, string>>;
  dropped: number;
} {
  const kept: Array<Record<string, string>> = [];
  let dropped = 0;
  const items = Array.isArray(raw) ? raw : [];
  for (const item of items) {
    if (typeof item !== 'object' || item === null) { dropped++; continue; }
    const a = item as Record<string, unknown>;
    const lawName = asScalar(a.law_name ?? a.lawName).slice(0, 300);
    const articleNumber = asScalar(a.article_number ?? a.articleNumber).slice(0, 80);
    if (!isGrounded(lawName, articleNumber, chunks)) { dropped++; continue; }
    kept.push({
      law_name: lawName,
      article_number: articleNumber,
      article_title: asScalar(a.article_title ?? a.articleTitle).slice(0, 300),
      article_text: asScalar(a.article_text ?? a.articleText).slice(0, 4000),
      lex_url: asScalar(a.lex_url ?? a.lexUrl).slice(0, 500),
    });
  }
  return { kept, dropped };
}
