// LexHub — `legal-ai` Supabase Edge Function (server-side Legal AI proxy).
//
// NIMA UCHUN KERAK: ilgari Gemini chaqiruvi CLIENT tomonda edi
// (`lib/core/network/gemini_legal_service.dart`), ya'ni kalit APK ichiga
// tushishi kerak edi. Shuning uchun `SupabaseConfig.geminiApiKey` release'da
// ataylab bo'sh qaytarilardi va release build'da AI UMUMAN ishlamasdi.
// Bu funksiya kalitni serverda ushlab, "AI" da'vosini haqiqiy qiladi.
//
// XAVFSIZLIK SHARTLARI (`.claude/skills/lexhub-ai-proxy/SKILL.md`):
//   1. `GEMINI_API_KEY` faqat `supabase secrets set` orqali — repo'da, APK'da,
//      `env/*.json`da yoki `--dart-define`da YO'Q.
//   2. Anonim so'rov fail-closed: platformaning `verify_jwt`iga TAYANMAYMIZ,
//      chunki publishable/anon key ham valid token bo'lishi mumkin. Token
//      HAQIQIY foydalanuvchiga tegishli ekani `/auth/v1/user` bilan
//      tekshiriladi (§2).
//   3. PII: client `PiiAnonymizer.anonymize()`dan o'tgan matn yuboradi.
//      Bu funksiya so'rov MATNINI log qilmaydi — faqat uzunlik va user
//      prefiksi.
//   4. Grounding: client hints resolve to active canonical database passages;
//      model output is bounded by those server-loaded sources. Unmatched claims
//      TASHLANADI (server tomonda anti-hallucination filtri).
//   5. Rate limit + timeout majburiy.
//
// TASHQI KUTUBXONA YO'Q: `npm:`/`esm.sh` import'lari o'rniga faqat `fetch`
// ishlatiladi. Sabab — supply-chain yuzasini nolga tushirish va versiya
// taxmin qilmaslik.
import { MASTER_SYSTEM_PROMPT } from './master_prompt.ts';
import {
  asScalar,
  asString,
  type Chunk,
} from './grounding.ts';
import { shouldTryNextModel } from './model_chain.ts';
import { constrainNarrative } from './narrative_guard.ts';

// ---------------------------------------------------------------------------
// Konfiguratsiya
// ---------------------------------------------------------------------------

/// Gemini model IDsi. 2026-08 holatiga ko'ra `gemini-1.5-flash` (eski client
/// kodidagi qiymat) ALLAQACHON o'chirilgan; GA Flash modellari:
/// `gemini-3.7-flash`, `gemini-3.6-flash`, `gemini-3.5-flash`.
/// Model nomi env orqali almashtiriladi — kod qayta deploy qilinmasin.
const MODEL = Deno.env.get('LEGAL_AI_MODEL') ?? 'gemini-3.7-flash';

/// ZAXIRA MODELLAR — asosiy model `503 UNAVAILABLE` yoki `404` bersa.
///
/// O'LCHANGAN (2026-08-26, production probe, `tool/probe_legal_ai_model.py`):
///   * `gemini-3.7-flash` — MAVJUD, lekin yuklama tepasida 503 qaytaradi
///     (bir xil so'rov ba'zan 200, ba'zan 503).
///   * `gemini-3.6-flash` — MAVJUD va o'sha so'rovga 200 qaytardi.
///   * `gemini-2.5-flash` — 404: "This model is no longer available".
///     Shuning uchun zaxira ro'yxatiga KIRITILMAYDI.
///
/// Zaxira BO'LMASA, Google spike'i har safar foydalanuvchini deterministik
/// fallback'ga tushiradi — ya'ni "AI" da'vosi amalda bajarilmaydi.
const MODEL_FALLBACKS = (Deno.env.get('LEGAL_AI_MODEL_FALLBACK') ?? 'gemini-3.6-flash')
  .split(',')
  .map((m) => m.trim())
  .filter((m) => m.length > 0);

/// Sinash tartibi: asosiy model, keyin takrorlanmaydigan zaxiralar.
const MODELS = [MODEL, ...MODEL_FALLBACKS.filter((m) => m !== MODEL)];

/// 3.x liniyasida `temperature` / `top_p` / `top_k` OLIB TASHLANGAN —
/// ularni yuborish 400 beradi. Shuning uchun `generationConfig` minimal.
///
/// `LEGAL_AI_GEMINI_HOST` — FAQAT lokal kontrakt testi uchun (fake upstream).
/// Deploy'da o'rnatilmaydi, standart qiymat haqiqiy Google hosti.
const GEMINI_HOST = Deno.env.get('LEGAL_AI_GEMINI_HOST') ?? 'https://generativelanguage.googleapis.com';
const API_VERSION = 'v1beta';

function boundedSetting(name: string, fallback: number, maximum: number): number {
  const value = Number(Deno.env.get(name) ?? fallback);
  return Number.isInteger(value) && value > 0 ? Math.min(value, maximum) : fallback;
}
const TIMEOUT_MS = boundedSetting('LEGAL_AI_TIMEOUT_MS', 20000, 50000);

/// O'TKINCHI 503 UCHUN CHEKLANGAN QAYTA URINISH.
///
/// O'LCHANGAN (2026-08-26, production probe): `gemini-3.7-flash` real javob
/// o'rniga `503 UNAVAILABLE` + `"This model is currently experiencing high
/// demand. Spikes in demand are usually temporary."` qaytardi. Bu KONFIGURATSIYA
/// xatosi EMAS — kalit ham, model nomi ham to'g'ri. Bitta urinishda taslim
/// bo'lsak, Google band bo'lgan har lahzada foydalanuvchi deterministik
/// fallback oladi va "AI ishlamayapti" degan taassurot paydo bo'ladi.
///
/// FAQAT 503 uchun. 429 (kvota) qayta urinishdan FAQAT yomonlashadi;
/// 400/401/403/404 esa determinatsiyalangan xatolar — takrorlash befoyda.
const RETRY_503_ATTEMPTS = boundedSetting('LEGAL_AI_RETRY_503', 3, 3);

/// UMUMIY BYUDJET (ms) — retry + model zanjiri BIRGALIKDA shundan oshmaydi.
///
/// NIMA UCHUN KERAK (O'LCHANGAN, 2026-08-26): faqat "har bir urinishga
/// TIMEOUT_MS" qo'yish YETARLI EMAS. 3 urinish × 40s × 2 model = 240s, ya'ni
/// client (55s) va Edge Function wall-clock allaqachon uzilib ketadi va
/// foydalanuvchi `client_timeout` oladi — server aniq `error.code`ni
/// qaytarishga ulgurmaydi. Live testda AYNAN shu holat kuzatildi.
///
/// Client `receiveTimeout` (55s) bundan KATTA bo'lishi shart: kesishni
/// HAR DOIM server bajaradi, shunda javob mashina o'qiy oladigan kod bilan
/// keladi.
const TOTAL_BUDGET_MS = boundedSetting('LEGAL_AI_TOTAL_BUDGET_MS', 50000, 50000);

/// Byudjetda shundan kam qolganda yangi urinish BOSHLANMAYDI — yarim yo'lda
/// uzilgan so'rov Google kvotasini behuda sarflaydi.
const MIN_ATTEMPT_MS = 8000;

/// Urinishlar orasidagi kutish (ms). Uzunligi `RETRY_503_ATTEMPTS - 1` dan
/// kam bo'lsa oxirgi qiymat qayta ishlatiladi.
const RETRY_BACKOFF_MS = [700, 2100];

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

const MAX_QUERY_CHARS = 4000;
const MAX_CHUNKS = 8;
const MAX_CHUNK_CHARS = 6000;
const MAX_BODY_BYTES = 256 * 1024;
const MAX_UPSTREAM_BYTES = 256 * 1024;
const AUTH_TIMEOUT_MS = 5000;

// A server-side test override must never forward the provider key to an
// arbitrary host. Loopback doubles are allowed only with loopback Auth.
function isAllowedGeminiHost(supabaseUrl: string): boolean {
  if (GEMINI_HOST === 'https://generativelanguage.googleapis.com') return true;
  try {
    const upstream = new URL(GEMINI_HOST);
    const auth = new URL(supabaseUrl);
    const loopback = (url: URL) => ['localhost', '127.0.0.1', '[::1]'].includes(url.hostname);
    return loopback(upstream) && loopback(auth) && upstream.protocol === 'http:' &&
      !upstream.username && !upstream.password && !upstream.search && !upstream.hash &&
      upstream.pathname === '/';
  } catch {
    return false;
  }
}

class BodyTooLarge extends Error {}
class BodyReadTimeout extends Error {}

// Count actual streamed bytes: Content-Length can be omitted or forged.
async function readBoundedText(
  message: Request | Response, maximum: number, timeoutMs = AUTH_TIMEOUT_MS,
): Promise<string> {
  const declared = Number(message.headers.get('content-length') ?? 0);
  if (declared > maximum) {
    await message.body?.cancel();
    throw new BodyTooLarge();
  }
  if (!message.body) return '';
  const reader = message.body.getReader();
  let timer: ReturnType<typeof setTimeout> | undefined;
  const timeout = new Promise<never>((_, reject) => {
    timer = setTimeout(() => reject(new BodyReadTimeout()), Math.max(1, timeoutMs));
  });
  let size = 0;
  const decoder = new TextDecoder('utf-8', { fatal: true });
  let text = '';
  try {
    while (true) {
      const { done, value } = await Promise.race([reader.read(), timeout]);
      if (done) return text + decoder.decode();
      size += value.byteLength;
      if (size > maximum) throw new BodyTooLarge();
      text += decoder.decode(value, { stream: true });
    }
  } finally {
    clearTimeout(timer);
    // Cancellation must not let a stalled sender hold the handler open.
    void reader.cancel().catch(() => undefined);
  }
}
// ---------------------------------------------------------------------------
// Yordamchi funksiyalar
// ---------------------------------------------------------------------------

/// CORS: LexHub — mobil ilova, ya'ni brauzer `Origin` yubormaydi. Lekin
/// `flutter run -d chrome` va integration test brauzerda ishlashi mumkin,
/// shuning uchun preflight qo'shilgan. `*` faqat SO'ROV METODLARI uchun —
/// autorizatsiya baribir `Authorization` header'iga bog'liq.
const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Expose-Headers': 'Retry-After',
  'Cache-Control': 'no-store',
  'X-Content-Type-Options': 'nosniff',
};

function jsonResponse(status: number, body: unknown, headers: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json', ...headers },
  });
}

/// Xato javoblari MASHINA O'QIY OLADIGAN `code` bilan qaytadi, chunki Dart
/// tomoni (`LegalAiProxyService`) `503 ai_not_configured` ni `429 rate_limited`
/// dan farqlab, foydalanuvchiga to'g'ri xabar ko'rsatishi kerak.
function errorResponse(status: number, code: string, message: string, headers: Record<string, string> = {}): Response {
  return jsonResponse(status, { error: { code, message } }, headers);
}

// Upstream diagnostics may contain credentials, project IDs or user input.
// Neither a debug flag nor an exception may expose them in responses/logs.
function upstreamErrorResponse(code: string, message: string): Response {
  return errorResponse(502, code, message);
}

/// So'rov MATNI hech qachon log'ga tushmaydi (§3). Faqat metadata.
function logEvent(event: string, fields: Record<string, unknown>): void {
  const parts = Object.entries(fields).map(([k, v]) => `${k}=${v}`);
  console.log(`[legal-ai] ${event} ${parts.join(' ')}`);
}

/// UUIDni to'liq log qilmaymiz — audit uchun 8 belgi yetarli.
function redactId(id: string): string {
  return id.length <= 8 ? id : `${id.slice(0, 8)}…`;
}
// ---------------------------------------------------------------------------
// Rate limit
// ---------------------------------------------------------------------------

// This RPC derives auth.uid() from the verified JWT and atomically enforces
// a rolling 10 requests/hour in PostgreSQL. No isolate-local fallback is safe.
async function consumeQuota(authHeader: string, supabaseUrl: string, anonKey: string):
    Promise<{ allowed: boolean; retryAfter: number }> {
  const response = await fetch(`${supabaseUrl}/rest/v1/rpc/consume_legal_ai_quota`, {
    method: 'POST',
    headers: { Authorization: authHeader, apikey: anonKey, 'Content-Type': 'application/json' },
    body: '{}', redirect: 'error', signal: AbortSignal.timeout(AUTH_TIMEOUT_MS),
  });
  if (!response.ok) {
    await response.body?.cancel();
    throw new Error('quota_unavailable');
  }
  const result = JSON.parse(await readBoundedText(response, 4096));
  if (typeof result?.allowed !== 'boolean' || !Number.isInteger(result.retry_after_seconds) ||
      result.retry_after_seconds < 0 || result.retry_after_seconds > 3600 ||
      (!result.allowed && result.retry_after_seconds === 0)) throw new Error('invalid_quota_result');
  return { allowed: result.allowed, retryAfter: result.retry_after_seconds };
}

// ---------------------------------------------------------------------------
// Autentifikatsiya (§2 — fail-closed)
// ---------------------------------------------------------------------------

interface AuthResult {
  userId: string | null;
  isAnonymous: boolean;
}

/// Nima uchun `verify_jwt` yetarli emas: Supabase `anon`/`publishable` kaliti
/// ham imzolangan JWT. Platforma darajasidagi tekshiruv uni QABUL QILADI,
/// ya'ni ilova kalitini bilgan har kim AI kvotasini sarflay oladi.
/// `/auth/v1/user` esa faqat HAQIQIY user session'i uchun 200 qaytaradi.
async function verifyUser(authHeader: string, supabaseUrl: string, anonKey: string): Promise<AuthResult> {
  const response = await fetch(`${supabaseUrl}/auth/v1/user`, {
    headers: { Authorization: authHeader, apikey: anonKey },
    redirect: 'error', signal: AbortSignal.timeout(AUTH_TIMEOUT_MS),
  });
  if (!response.ok) {
    await response.body?.cancel();
    return { userId: null, isAnonymous: false };
  }
  const user = JSON.parse(await readBoundedText(response, 64 * 1024));
  const id = asString((user ?? {}).id);
  if (id.length === 0) return { userId: null, isAnonymous: false };
  // Supabase anonymous sign-in ham `id` beradi; `is_anonymous` bilan ajratamiz.
  return { userId: id, isAnonymous: (user ?? {}).is_anonymous === true };
}
// ---------------------------------------------------------------------------
// So'rov validatsiyasi
// ---------------------------------------------------------------------------

interface ValidRequest {
  queryId: string;
  queryText: string;
  category: string;
  chunks: Chunk[];
}

/// DIQQAT: client `system_instruction` YUBORSA HAM u O'QILMAYDI. System prompt
/// faqat serverdagi `MASTER_SYSTEM_PROMPT`dan olinadi — aks holda foydalanuvchi
/// "rolingni o'zgartir" deb yuborib prompt injection qilishi mumkin bo'lardi
/// (master prompt §1.2 aynan buni taqiqlaydi, lekin himoya SERVER tomonda
/// bo'lishi kerak, promptdagi iltimosda emas).
function validate(body: unknown): { request?: ValidRequest; error?: string } {
  if (typeof body !== 'object' || body === null || Array.isArray(body)) return { error: 'body JSON obyekt bo\'lishi kerak' };
  const raw = body as Record<string, unknown>;
  const invalidControl = /[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]/;

  const queryText = asString(raw.query_text).trim();
  if (queryText.length === 0) return { error: '`query_text` bo\'sh' };
  if (queryText.length > MAX_QUERY_CHARS) {
    return { error: `\`query_text\` ${MAX_QUERY_CHARS} belgidan uzun` };
  }
  if (invalidControl.test(queryText)) return { error: '`query_text` yaroqsiz belgi saqlaydi' };
  for (const key of ['query_id', 'category']) {
    if (raw[key] !== undefined && raw[key] !== null && (typeof raw[key] !== 'string' ||
        (raw[key] as string).length > 120 || invalidControl.test(raw[key] as string))) {
      return { error: `\`${key}\` yaroqsiz` };
    }
  }
  if (raw.retrieved_chunks !== undefined && !Array.isArray(raw.retrieved_chunks)) {
    return { error: '`retrieved_chunks` massiv bo\'lishi kerak' };
  }

  const rawChunks = Array.isArray(raw.retrieved_chunks) ? raw.retrieved_chunks : [];
  if (rawChunks.length > MAX_CHUNKS) return { error: `\`retrieved_chunks\` ${MAX_CHUNKS} tadan ko'p` };

  const chunks: Chunk[] = [];
  for (const item of rawChunks) {
    if (typeof item !== 'object' || item === null || Array.isArray(item)) {
      return { error: '`retrieved_chunks` elementi yaroqsiz' };
    }
    const c = item as Record<string, unknown>;
    for (const [key, maximum] of Object.entries({ document_name: 300, article_number: 80,
      article_title: 300, content: MAX_CHUNK_CHARS, lex_url: 500 })) {
      if (c[key] === undefined || c[key] === null) continue;
      if ((typeof c[key] !== 'string' && !(key === 'article_number' &&
          typeof c[key] === 'number' && Number.isFinite(c[key]))) ||
          asScalar(c[key]).length > maximum || invalidControl.test(asScalar(c[key]))) {
        return { error: '`retrieved_chunks` maydoni yaroqsiz' };
      }
    }
    if (asScalar(c.lex_url).length > 0) {
      try {
        const url = new URL(asScalar(c.lex_url));
        if (url.protocol !== 'https:' || url.username || url.password) {
          return { error: '`lex_url` xavfsiz HTTPS havola bo\'lishi kerak' };
        }
      } catch {
        return { error: '`lex_url` yaroqsiz' };
      }
    }
    chunks.push({
      documentName: asScalar(c.document_name).slice(0, 300),
      articleNumber: asScalar(c.article_number).slice(0, 80),
      articleTitle: asScalar(c.article_title).slice(0, 300),
      content: asScalar(c.content).slice(0, MAX_CHUNK_CHARS),
      lexUrl: asScalar(c.lex_url).slice(0, 500),
    });
  }

  return {
    request: {
      queryId: asString(raw.query_id).slice(0, 120),
      queryText,
      category: asString(raw.category, 'Umumiy huquq').slice(0, 120),
      chunks,
    },
  };
}
// Client passages are hints, never authority. Load active canonical text through
// the caller's JWT; do not forward client prose, titles or URLs to the model.
async function canonicalChunks(chunks: Chunk[], authHeader: string,
    supabaseUrl: string, anonKey: string): Promise<Chunk[]> {
  const numbers = [...new Set(chunks.map((c) => c.articleNumber)
    .filter((n) => /^[1-9][0-9]{0,8}(?:-modda)?$/.test(n))
    .map((n) => String(parseInt(n, 10))))];
  if (numbers.length === 0) return [];
  const url = new URL(`${supabaseUrl}/rest/v1/law_article_chunks`);
  url.searchParams.set('select', 'document_name,article_number,article_title,content,lex_url,status');
  url.searchParams.set('status', 'eq.active');
  url.searchParams.set('article_number', `in.(${numbers.join(',')})`);
  url.searchParams.set('limit', '65');
  const response = await fetch(url, {
    headers: { Authorization: authHeader, apikey: anonKey },
    redirect: 'error', signal: AbortSignal.timeout(AUTH_TIMEOUT_MS),
  });
  if (!response.ok) {
    await response.body?.cancel();
    throw new Error('evidence_unavailable');
  }
  const rows: unknown = JSON.parse(await readBoundedText(response, MAX_BODY_BYTES));
  if (!Array.isArray(rows) || rows.length > 64) throw new Error('invalid_evidence');
  const result: Chunk[] = [];
  for (const hint of chunks) {
    if (!/^[1-9][0-9]{0,8}(?:-modda)?$/.test(hint.articleNumber)) continue;
    const matches = rows.filter((row) => row?.status === 'active' &&
      row.document_name === hint.documentName &&
      row.article_number === parseInt(hint.articleNumber, 10));
    // Ambiguous editions must not be silently merged or selected by the client.
    if (matches.length !== 1) continue;
    const checked = validate({ query_text: 'canonical', retrieved_chunks: matches });
    const chunk = checked.request?.chunks[0];
    if (!chunk || !chunk.content || !chunk.lexUrl) throw new Error('invalid_evidence');
    if (!result.some((c) => c.documentName === chunk.documentName &&
        c.articleNumber === chunk.articleNumber)) result.push(chunk);
  }
  return result;
}
// ---------------------------------------------------------------------------
// Prompt qurish
// ---------------------------------------------------------------------------

/// `emergency_protocol` ATAYLAB so'ralmaydi. Client tomonda u DETERMINISTIK:
/// `LegalAssistantRemoteDataSourceImpl.detectEmergency()` (kalit so'zlar +
/// qo'lda yozilgan Konstitutsiya moddalari) va `getLegalAdvice` uni
/// `emergency ?? aiResponse.emergencyProtocol` bilan USTUN qo'yadi
/// (`legal_assistant_remote_datasource.dart:152`). Modeldan Konstitutsiya
/// moddasini so'rash = gallyutsinatsiya xavfini bekorga oshirish.
function buildUserPrompt(request: ValidRequest): string {
  const context = request.chunks.length === 0
    ? '(Kontekst berilmagan — evidence_refs bo‘sh bo‘lishi shart.)'
    : request.chunks
        .map((c, i) =>
          `[${i + 1}] Hujjat: ${c.documentName}\n` +
          `    Modda: ${c.articleNumber}${c.articleTitle ? ` — ${c.articleTitle}` : ''}\n` +
          `    Matn: ${c.content}\n` +
          `    Havola: ${c.lexUrl}`)
        .join('\n\n');

  return `### SO‘ROV BILAN BERILGAN HUQUQIY KONTEKST (RAG)
${context}

### FOYDALANUVCHI SAVOLI
Kategoriya: ${request.category}
Savol: ${request.queryText}

### JAVOB FORMATI — QAT'IY
Faqat JSON obyekt qaytar. Markdown bloki, izoh yoki matn QO'SHMA.
Barcha matn O'ZBEK TILIDA.

{
  "evidence_refs": [1],
  "risk_assessment": {
    "level": "medium | high | critical"
  }
}

\`evidence_refs\` — faqat ushbu kontekstdagi [1], [2], ... indekslardan
savolga aloqador bo‘lishi mumkin bo‘lgan ko‘pi bilan 3 tasi. Hujjat yoki
modda raqami indeks emas. Aloqador manba bo‘lmasa [] qaytar.
Manbaga moslik uning dolzarbligi yoki ushbu vaziyatga tatbiqini isbotlamaydi.
Erkin huquqiy xulosa, harakatlar rejasi, iqtibos yoki muddat yozma: server
faqat tanlangan manba matni va cheklangan tayyorgarlik qadamlarini chiqaradi.
Shu JSON formati umumiy javob formati ko‘rsatmalaridan ustun.`;
}
// ---------------------------------------------------------------------------
// Gemini chaqiruvi
// ---------------------------------------------------------------------------

interface GeminiOutcome {
  text?: string;
  status: number;
  variant: string;
  /// Javobni AYNAN qaysi model bergani (yoki qaysi model yiqilgani).
  model?: string;
}

/// Uch xil payload varianti KETMA-KET sinaladi. Sabab — 3.x liniyasi
/// `generationConfig` maydonlarining bir qismini OLIB TASHLADI
/// (`temperature`, `top_p`, `top_k`, `candidate_count`) va rasmiy hujjatda
/// `responseMimeType` / `systemInstruction` ning 3.x'da qo'llanishi
/// TASDIQLANMAGAN. Shu sababli kod bitta imzoga bog'lanmaydi: 400 kelsa
/// kamroq maydon bilan qayta uriniladi. Bu "taxmin qilib deploy qilish"
/// o'rniga muhitning haqiqiy javobiga moslashish.
function payloadVariants(userPrompt: string): Array<{ name: string; body: Record<string, unknown> }> {
  const parts = [{ text: userPrompt }];
  return [
    {
      name: 'system+json',
      body: {
        contents: [{ role: 'user', parts }],
        systemInstruction: { parts: [{ text: MASTER_SYSTEM_PROMPT }] },
        generationConfig: { responseMimeType: 'application/json' },
      },
    },
    {
      name: 'system',
      body: {
        contents: [{ role: 'user', parts }],
        systemInstruction: { parts: [{ text: MASTER_SYSTEM_PROMPT }] },
      },
    },
    {
      name: 'inline',
      body: {
        contents: [{
          role: 'user',
          parts: [{ text: `${MASTER_SYSTEM_PROMPT}\n\n${userPrompt}` }],
        }],
      },
    },
  ];
}

function extractText(payload: unknown): string {
  const candidates = ((payload ?? {}) as Record<string, unknown>).candidates;
  if (!Array.isArray(candidates) || candidates.length === 0) return '';
  const first = candidates[0] as Record<string, unknown> | null;
  const content = ((first ?? {}).content ?? {}) as Record<string, unknown>;
  const parts = content.parts;
  if (!Array.isArray(parts)) return '';
  return parts.map((p) => asString((p as Record<string, unknown>)?.text)).join('').trim();
}
/// BITTA urinish: bitta payload varianti, bitta HTTP so'rov.
///
/// Ajratilgan sabab — qayta urinish mantig'i (`callGemini`) so'rov yuborish
/// tafsilotlaridan mustaqil bo'lishi kerak, aks holda `try/finally` ichida
/// ikki xil sikl chalkashadi.
async function attemptGemini(
  model: string,
  apiKey: string,
  variant: { name: string; body: unknown },
  deadline: number,
): Promise<GeminiOutcome> {
  const url = `${GEMINI_HOST}/${API_VERSION}/models/${model}:generateContent`;
  // Urinish vaqti = TIMEOUT_MS, lekin UMUMIY byudjetdan oshmaydi.
  const budget = Math.min(TIMEOUT_MS, deadline - Date.now());
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), budget);
  try {
    const response = await fetch(url, {
      method: 'POST',
      // Kalit HEADER'da — `?key=` query'da emas. Sabab: query string
      // proxy/CDN log'lariga tushadi, header esa tushmaydi.
      headers: { 'Content-Type': 'application/json', 'x-goog-api-key': apiKey },
      body: JSON.stringify(variant.body),
      signal: controller.signal,
      redirect: 'error',
    });
    const bodyText = await readBoundedText(response, MAX_UPSTREAM_BYTES, budget);
    if (response.ok) {
      const parsed = JSON.parse(bodyText) as unknown;
      return { text: extractText(parsed), status: 200, variant: variant.name, model };
    }
    // Inspect provider errors only in memory; never retain their raw detail.
    const failed: GeminiOutcome = {
      status: response.status,
      variant: variant.name,
      model,
    };
    logEvent('gemini_error', { model, variant: variant.name, status: response.status });
    // O'LCHANGAN (2026-08-25, lokal probe): yaroqsiz kalit uchun Google
    // `400 INVALID_ARGUMENT` + `"reason": "API_KEY_INVALID"` qaytaradi —
    // 401 EMAS. Agar 400 ni "payload imzosi mos emas" deb hisoblab qayta
    // urinsak, kalit xato bo'lganda 3 marta behuda so'rov ketadi va client
    // `ai_unavailable` degan chalg'ituvchi kod oladi.
    if (bodyText.includes('API_KEY_INVALID') || bodyText.includes('API key not valid')) {
      return { ...failed, status: 401 };
    }
    return failed;
  } catch (error) {
    const aborted = (error instanceof DOMException && error.name === 'AbortError') ||
      error instanceof BodyReadTimeout;
    logEvent('gemini_exception', { model, variant: variant.name, aborted });
    return {
      status: aborted ? 504 : 502,
      variant: variant.name,
      model,
    };
  } finally {
    clearTimeout(timer);
  }
}

/// BITTA model uchun: payload variantlari × 503 qayta urinishlari.
async function callModel(
  model: string,
  apiKey: string,
  userPrompt: string,
  deadline: number,
): Promise<GeminiOutcome> {
  let last: GeminiOutcome = { status: 0, variant: 'none', model };

  for (const variant of payloadVariants(userPrompt)) {
    const maxAttempts = Math.max(1, RETRY_503_ATTEMPTS);
    for (let attempt = 0; attempt < maxAttempts; attempt++) {
      last = await attemptGemini(model, apiKey, variant, deadline);
      if (last.text !== undefined) return last;
      // FAQAT 503 = Google vaqtincha band → SHU variantni qayta sinaymiz.
      if (last.status !== 503) break;
      if (attempt === maxAttempts - 1) break;
      const wait = RETRY_BACKOFF_MS[Math.min(attempt, RETRY_BACKOFF_MS.length - 1)];
      // Kutib, keyin urinishga byudjet yetmasa — qayta urinmaymiz.
      if (deadline - Date.now() - wait < MIN_ATTEMPT_MS) break;
      logEvent('gemini_retry', {
        model,
        variant: variant.name,
        attempt: attempt + 1,
        wait_ms: wait,
      });
      await sleep(wait);
    }
    // 400 = payload imzosi mos emas → keyingi variantni sina.
    // 401/403 = kalit muammosi, 404 = model nomi yo'q, 429 = kvota,
    // 503 (urinishlar tugagach) / boshqa 5xx = server — chiqamiz.
    if (last.status !== 400) return last;
  }
  return last;
}

/// MODEL ZANJIRI: asosiy model o'tkinchi 503, 404 yoki TIMEOUT bersa, zaxira
/// modelga o'tamiz.
///
/// 504 NIMA UCHUN ZANJIRGA KIRITILDI (o'lchangan, 2026-08-26 production):
/// avvalgi izohda "504 modelni almashtirish bilan TUZALMAYDI" deb yozilgan
/// edi — bu XATO bo'lib chiqdi. `tool/probe_legal_ai_latency.py` o'lchovi:
/// `gemini-3.7-flash` 68 baytlik so'rovga ham, 1006 baytlik so'rovga ham
/// AYNAN `timeout 40000ms` berdi (variant `system+json`), ya'ni model sekin
/// generatsiya qilmayapti — umuman JAVOB BERMAYAPTI. AYNI daqiqada
/// `gemini-3.6-flash` ayni endpoint'ga 200 qaytardi. Demak timeout MODELGA
/// XOS bo'lishi mumkin va zaxiraga o'tish uni TUZATADI.
///
/// 401/403 (kalit) esa haqiqatan modelga bog'liq EMAS — zanjirni to'xtatadi.
/// 400 `callModel` ichida payload variantlari bilan hal qilinadi.
///
/// 429 TUZATILDI (2026-09-04): bu izohda avval "429 (kvota) ham modelga
/// bog'liq EMAS" deb yozilgandi — PRODUCTION O'LCHOVI buni RAD ETDI (kvota
/// har model uchun ALOHIDA). Dalil va narxi `model_chain.ts` da; qaror endi
/// SHU MODULDAN olinadi va `model_chain_test.ts` real runtime'da uni
/// qulflaydi (9/9), ya'ni izoh bilan kod bir-biridan ajralib ketmaydi.
///
/// CHEKLOV — HALOL AYTILADI: o'lchangan haqiqiy javob vaqti ~16–33 s, ya'ni
/// `TIMEOUT_MS` 40 s va `TOTAL_BUDGET_MS` 50 s bo'lganda birinchi urinish
/// abort bo'lgach zaxiraga ~10 s qoladi — bu ko'p hollarda YETMAYDI. Zanjir
/// haqiqatan foyda berishi uchun operator `LEGAL_AI_TIMEOUT_MS`ni
/// kichraytirishi kerak; bu kod uni O'ZI o'zgartirmaydi.
async function callGemini(apiKey: string, userPrompt: string): Promise<GeminiOutcome> {
  const deadline = Date.now() + TOTAL_BUDGET_MS;
  let last: GeminiOutcome = { status: 0, variant: 'none' };
  for (const model of MODELS) {
    last = await callModel(model, apiKey, userPrompt, deadline);
    if (last.text !== undefined) return last;
    if (!shouldTryNextModel(last.status)) {
      return last;
    }
    // Zaxira modelga o'tishga byudjet qolmasa — bor javobni qaytaramiz.
    if (deadline - Date.now() < MIN_ATTEMPT_MS) {
      logEvent('budget_exhausted', { after: model, status: last.status });
      return last;
    }
    logEvent('model_fallback', { failed: model, status: last.status });
  }
  return last;
}

/// Model `responseMimeType`ni qo'llamasa javob ```json ... ``` bloki ichida
/// keladi. Shuning uchun bevosita `JSON.parse` ga tayanmaymiz.
function extractJsonObject(text: string): Record<string, unknown> | null {
  const trimmed = text.trim();
  const withoutFence = trimmed
    .replace(/^```(?:json)?\s*/i, '')
    .replace(/\s*```$/, '')
    .trim();
  const start = withoutFence.indexOf('{');
  const end = withoutFence.lastIndexOf('}');
  if (start === -1 || end <= start) return null;
  try {
    const parsed = JSON.parse(withoutFence.slice(start, end + 1)) as unknown;
    return typeof parsed === 'object' && parsed !== null ? parsed as Record<string, unknown> : null;
  } catch {
    return null;
  }
}
// ---------------------------------------------------------------------------
// Grounding filtri `./grounding.ts` da (unit test uchun ajratilgan).
// ---------------------------------------------------------------------------
// Javobni shakllantirish
// ---------------------------------------------------------------------------

/// `user_query` ATAYLAB QAYTARILMAYDI. Sabab: `LegalResponse.fromJson`
/// (`legal_response.dart:72-76`) `user_query` bo'lmasa `relatable_summary`ga
/// tushadi — ya'ni UI'da foydalanuvchining savoli o'rniga AI xulosasi
/// ko'rinardi. Shuning uchun Dart client `user_query`ni O'ZI (sanitizatsiya
/// QILINMAGAN, foydalanuvchi yozgan asl matn bilan) qo'yadi; server esa
/// sanitizatsiyalangan matnni qaytarib UI'ga chiqarmaydi.
function shapeResponse(
  parsed: Record<string, unknown>,
  request: ValidRequest,
  variant: string,
): { body: Record<string, unknown>; droppedArticles: number; replacedQuotes: number } {
  const { fields, dropped, replacedQuotes } = constrainNarrative(parsed, request.chunks);
  return {
    droppedArticles: dropped,
    replacedQuotes,
    body: {
      query_id: request.queryId,
      category: request.category,
      ...fields,
      created_at: new Date().toISOString(),
      // `fields.source` is deterministic when no usable source was selected.
      model: MODEL,
      dropped_articles: dropped,
      // MODEL IQTIBOSI CHUNK ICHIDA TOPILMAGANI UCHUN RASMIY MATN BILAN
      // ALMASHTIRILGAN moddalar soni. Almashtirish JIM bo'lmaydi: bu son
      // nolga teng bo'lmasa, model kontekstdagi moddani noto'g'ri
      // iqtibos qilgan — kuzatish uchun log'da ham bor.
      replaced_quotes: replacedQuotes,
      payload_variant: variant,
    },
  };
}
// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS_HEADERS });
  if (req.method !== 'POST') {
    return errorResponse(405, 'method_not_allowed', 'Faqat POST qabul qilinadi', { Allow: 'POST, OPTIONS' });
  }

  // 1) Muhit. `SUPABASE_URL` va `SUPABASE_ANON_KEY` — platforma tomonidan
  //    avtomatik beriladi; `GEMINI_API_KEY` faqat `supabase secrets set`dan.
  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
  if (supabaseUrl.length === 0 || anonKey.length === 0) {
    logEvent('misconfigured', { has_url: supabaseUrl.length > 0, has_anon: anonKey.length > 0 });
    return errorResponse(500, 'misconfigured', 'Funksiya muhiti to\'liq emas');
  }

  // 2) Autorizatsiya — HAR QANDAY boshqa ishdan OLDIN (fail-closed).
  const authHeader = req.headers.get('Authorization') ?? '';
  if (!authHeader.toLowerCase().startsWith('bearer ') || authHeader.length < 20 || authHeader.length > 8192) {
    return errorResponse(401, 'missing_authorization', 'Authorization: Bearer <token> talab qilinadi');
  }

  let auth: AuthResult;
  try {
    auth = await verifyUser(authHeader, supabaseUrl, anonKey);
  } catch {
    logEvent('auth_check_failed', { unavailable: true });
    // Auth serveriga yetib bo'lmasa RUXSAT BERMAYMIZ (fail-closed, fail-open emas).
    return errorResponse(503, 'auth_unavailable', 'Autentifikatsiyani tekshirish imkonsiz');
  }

  if (auth.userId === null || auth.isAnonymous) {
    logEvent('rejected', { reason: auth.userId === null ? 'invalid_token' : 'anonymous_user' });
    return errorResponse(
      401,
      'invalid_or_anonymous_token',
      'Yaroqli foydalanuvchi sessiyasi talab qilinadi (anon/publishable key yetarli emas)',
    );
  }

  // 3) Bounded JSON read before quota/provider work.
  if ((req.headers.get('content-type') ?? '').split(';')[0].trim().toLowerCase() !== 'application/json') {
    return errorResponse(415, 'unsupported_media_type', 'Content-Type: application/json talab qilinadi');
  }
  let body: unknown;
  try {
    body = JSON.parse(await readBoundedText(req, MAX_BODY_BYTES));
  } catch (error) {
    if (error instanceof BodyTooLarge) return errorResponse(413, 'payload_too_large', 'Request exceeds the size limit');
    if (error instanceof BodyReadTimeout) return errorResponse(408, 'request_timeout', 'Request body timed out');
    return errorResponse(400, 'invalid_json', 'Body JSON emas');
  }
  const { request, error } = validate(body);
  if (request === undefined) {
    return errorResponse(400, 'invalid_request', error ?? 'Body noto\'g\'ri');
  }

  // 5) Kalit. Kalit YO'Q bo'lsa 503 — HECH QACHON to'qib chiqarilgan javob
  //    qaytarilmaydi. Client bu kodni ko'rib deterministik fallback'ga o'tadi
  //    va UI'da "AI" deb ATAMAYDI.
  const geminiKey = Deno.env.get('GEMINI_API_KEY') ?? '';
  if (geminiKey.length === 0) {
    logEvent('ai_not_configured', { user: redactId(auth.userId) });
    return errorResponse(503, 'ai_not_configured', 'AI kaliti serverda sozlanmagan');
  }

  if (!isAllowedGeminiHost(supabaseUrl) || MODELS.length > 3 ||
      MODELS.some((model) => !/^[a-zA-Z0-9._-]{1,120}$/.test(model))) {
    return errorResponse(503, 'ai_not_configured', 'AI server konfiguratsiyasi yaroqsiz');
  }
  // 4) Durable, per-user quota. A database outage must not open a billing hole.
  try {
    const quota = await consumeQuota(authHeader, supabaseUrl, anonKey);
    if (!quota.allowed) {
      return errorResponse(429, 'rate_limited', 'Soatlik limit tugadi (10)',
        { 'Retry-After': String(quota.retryAfter) });
    }
  } catch {
    logEvent('quota_unavailable', { unavailable: true });
    return errorResponse(503, 'rate_limit_unavailable', 'Request quota is temporarily unavailable');
  }

  try {
    request.chunks = await canonicalChunks(request.chunks, authHeader, supabaseUrl, anonKey);
  } catch {
    return errorResponse(503, 'evidence_unavailable', 'Legal sources are temporarily unavailable');
  }

  // So'rov MATNI log'ga TUSHMAYDI (§3) — faqat o'lchamlar.
  logEvent('request', {
    user: redactId(auth.userId),
    query_len: request.queryText.length,
    chunks: request.chunks.length,
    models: MODELS.join('>'),
  });

  // 6) Model chaqiruvi.
  const outcome = await callGemini(geminiKey, buildUserPrompt(request));
  if (outcome.text === undefined) {
    const code = outcome.status === 504
      ? 'ai_timeout'
      : outcome.status === 429
      ? 'ai_quota'
      : outcome.status === 401 || outcome.status === 403
      ? 'ai_key_rejected'
      : outcome.status === 404
      // `LEGAL_AI_MODEL` eskirgan model nomiga ishora qilsa aynan shu kod
      // keladi. Tuzatish: `supabase secrets set LEGAL_AI_MODEL=<GA model>` —
      // kodni qayta deploy qilish shart emas.
      ? 'ai_model_unavailable'
      // 503 = Google vaqtincha BAND (`UNAVAILABLE`). Bu konfiguratsiya xatosi
      // EMAS — kalit va model to'g'ri. Client uchun ALOHIDA kod: UI "keyinroq
      // urinib ko'ring" deyishi mumkin, "AI sozlanmagan" emas. Bu holat
      // production'da O'LCHANGAN (2026-08-26).
      : outcome.status === 503
      ? 'ai_overloaded'
      : 'ai_unavailable';
    logEvent('ai_failed', {
      code,
      status: outcome.status,
      variant: outcome.variant,
      model: outcome.model ?? MODEL,
    });
    return upstreamErrorResponse(code, 'AI xizmatidan javob olinmadi');
  }

  const parsed = extractJsonObject(outcome.text);
  if (parsed === null) {
    logEvent('unparseable', { len: outcome.text.length, variant: outcome.variant });
    return errorResponse(502, 'ai_unparseable', 'AI javobi JSON emas');
  }

  const { body: shaped, droppedArticles, replacedQuotes } =
      shapeResponse(parsed, request, outcome.variant);
  if (asString(shaped.relatable_summary).length === 0) {
    logEvent('empty_summary', { variant: outcome.variant });
    return errorResponse(502, 'ai_empty', 'AI javobi bo\'sh');
  }

  logEvent('ok', {
    user: redactId(auth.userId),
    model: outcome.model ?? MODEL,
    articles: (shaped.legal_basis as unknown[]).length,
    dropped: droppedArticles,
    replaced_quotes: replacedQuotes,
    variant: outcome.variant,
  });
  return jsonResponse(200, shaped);
});
