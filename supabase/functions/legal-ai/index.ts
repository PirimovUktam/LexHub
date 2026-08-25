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
//   4. Grounding: model qaytargan `legal_basis` client yuborgan
//      `retrieved_chunks` bilan solishtiriladi; mos kelmagan modda
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
  asStringList,
  type Chunk,
  groundLegalBasis,
} from './grounding.ts';

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

const TIMEOUT_MS = Number(Deno.env.get('LEGAL_AI_TIMEOUT_MS') ?? '20000');
const MAX_PER_HOUR = Number(Deno.env.get('LEGAL_AI_MAX_PER_HOUR') ?? '10');

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
const RETRY_503_ATTEMPTS = Number(Deno.env.get('LEGAL_AI_RETRY_503') ?? '3');

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
const TOTAL_BUDGET_MS = Number(Deno.env.get('LEGAL_AI_TOTAL_BUDGET_MS') ?? '50000');

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
};

function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  });
}

/// Xato javoblari MASHINA O'QIY OLADIGAN `code` bilan qaytadi, chunki Dart
/// tomoni (`LegalAiProxyService`) `503 ai_not_configured` ni `429 rate_limited`
/// dan farqlab, foydalanuvchiga to'g'ri xabar ko'rsatishi kerak.
function errorResponse(status: number, code: string, message: string): Response {
  return jsonResponse(status, { error: { code, message } });
}

/// DIAGNOSTIKA REJIMI — `supabase secrets set LEGAL_AI_DEBUG_UPSTREAM=1`.
///
/// NIMA UCHUN KERAK: bu CLI versiyasida `supabase functions logs` YO'Q, ya'ni
/// production'da upstream nega 400/500 qaytarganini bilishning yagona yo'li —
/// dashboard'ni qo'lda ochish. Debug flag YOQILGANDA (faqat shunda) 502 javob
/// tanasiga upstream statusi va qisqartirilgan matni qo'shiladi.
///
/// XAVFSIZLIK: flag O'CHIQ bo'lganda (default) javob AVVALGIDEK — hech qanday
/// upstream tafsiloti chiqmaydi. Google'ning payload xatosi kalitni yoki
/// loyiha ma'lumotini o'z ichiga olmaydi, lekin baribir doimiy ravishda
/// oshkor qilinmaydi.
const DEBUG_UPSTREAM = (Deno.env.get('LEGAL_AI_DEBUG_UPSTREAM') ?? '') === '1';

function upstreamErrorResponse(
  code: string,
  message: string,
  status: number,
  variant: string,
  detail: unknown,
  model: string,
): Response {
  const error: Record<string, unknown> = { code, message };
  if (DEBUG_UPSTREAM) {
    // Model nomi ham qo'shiladi: `LEGAL_AI_MODEL` almashtirilganda javob
    // AYNAN qaysi model bilan olinganini bilmasak, 404/503 ni to'g'ri
    // modelga bog'lab bo'lmaydi (isolate eski `MODEL` bilan qolishi mumkin).
    error.upstream_model = model;
    error.upstream_status = status;
    error.upstream_variant = variant;
    error.upstream_detail = typeof detail === 'string'
      ? detail.slice(0, 300)
      : JSON.stringify(detail ?? null).slice(0, 300);
  }
  return jsonResponse(502, { error });
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

/// CHEKLOV — HALOL AYTILADI: bu hisoblagich ISOLATE xotirasida. Supabase Edge
/// Functions bir nechta isolate ko'tarishi va idle'dan keyin o'chirishi mumkin,
/// ya'ni bu limit QAT'IY kafolat emas — u faqat bitta isolate ichida bir
/// foydalanuvchining ketma-ket suiiste'molini to'xtatadi.
/// Qat'iy, taqsimlangan limit uchun Postgres jadval kerak (`legal_ai_usage`)
/// va u alohida migration + RLS talab qiladi — hozir DEPLOY QILINMAGAN,
/// shuning uchun bu yerda da'vo qilinmaydi.
const hits = new Map<string, number[]>();
const WINDOW_MS = 60 * 60 * 1000;

function rateLimitExceeded(userId: string): boolean {
  const now = Date.now();
  const previous = hits.get(userId) ?? [];
  const recent = previous.filter((t) => now - t < WINDOW_MS);
  if (recent.length >= MAX_PER_HOUR) {
    hits.set(userId, recent);
    return true;
  }
  recent.push(now);
  hits.set(userId, recent);
  // Xotira o'sib ketmasligi uchun: bo'sh yozuvlarni tozalash.
  if (hits.size > 5000) {
    for (const [key, stamps] of hits) {
      if (stamps.every((t) => now - t >= WINDOW_MS)) hits.delete(key);
    }
  }
  return false;
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
  });
  if (!response.ok) return { userId: null, isAnonymous: false };
  const user = await response.json().catch(() => null);
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
  if (typeof body !== 'object' || body === null) return { error: 'body JSON obyekt bo\'lishi kerak' };
  const raw = body as Record<string, unknown>;

  const queryText = asString(raw.query_text).trim();
  if (queryText.length === 0) return { error: '`query_text` bo\'sh' };
  if (queryText.length > MAX_QUERY_CHARS) {
    return { error: `\`query_text\` ${MAX_QUERY_CHARS} belgidan uzun` };
  }

  const rawChunks = Array.isArray(raw.retrieved_chunks) ? raw.retrieved_chunks : [];
  if (rawChunks.length > MAX_CHUNKS) return { error: `\`retrieved_chunks\` ${MAX_CHUNKS} tadan ko'p` };

  const chunks: Chunk[] = [];
  for (const item of rawChunks) {
    if (typeof item !== 'object' || item === null) continue;
    const c = item as Record<string, unknown>;
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
    ? '(Kontekst berilmagan — quyidagi qoidaga rioya qil: tasdiqlangan manba ' +
      'bo\'lmasa modda RAQAMINI to\'qib chiqarma, `legal_basis` ni bo\'sh qoldir.)'
    : request.chunks
        .map((c, i) =>
          `[${i + 1}] Hujjat: ${c.documentName}\n` +
          `    Modda: ${c.articleNumber}${c.articleTitle ? ` — ${c.articleTitle}` : ''}\n` +
          `    Matn: ${c.content}\n` +
          `    Havola: ${c.lexUrl}`)
        .join('\n\n');

  return `### TASDIQLANGAN HUQUQIY KONTEKST (RAG)
${context}

### FOYDALANUVCHI SAVOLI
Kategoriya: ${request.category}
Savol: ${request.queryText}

### JAVOB FORMATI — QAT'IY
Faqat JSON obyekt qaytar. Markdown bloki, izoh yoki matn QO'SHMA.
Barcha matn O'ZBEK TILIDA.

{
  "relatable_summary": "2-3 gap, jargonsiz (1-BLOK)",
  "actionable_steps": ["1. ...", "2. ...", "3. ..."],
  "legal_basis": [
    {
      "law_name": "hujjat nomi — FAQAT yuqoridagi kontekstdan",
      "article_number": "masalan 161-modda",
      "article_title": "modda sarlavhasi",
      "article_text": "moddadan qisqa aniq iqtibos",
      "lex_url": "kontekstdagi havola yoki bo'sh satr"
    }
  ],
  "risk_assessment": {
    "level": "low | medium | high | critical",
    "summary": "risklar va ogohlantirishlar (4-BLOK)",
    "limitations": ["ushbu maslahat qaysi holatda ish bermaydi"],
    "requires_lawyer": true,
    "deadline_days": 30
  }
}

MUHIM: \`legal_basis\` ichida FAQAT yuqoridagi kontekstda AYNAN ko'rsatilgan
hujjat va modda raqamlari bo'lishi mumkin. Kontekstda yo'q moddani yozsang,
server uni tashlab yuboradi va javob asossiz qoladi. Aniq modda bo'lmasa
\`legal_basis\`ni bo'sh massiv qilib qoldir va buni \`relatable_summary\`da ayt.
\`deadline_days\` — protsessual muddat kunlarda; noma'lum bo'lsa null.`;
}
// ---------------------------------------------------------------------------
// Gemini chaqiruvi
// ---------------------------------------------------------------------------

interface GeminiOutcome {
  text?: string;
  status: number;
  variant: string;
  detail?: string;
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
    });
    const bodyText = await response.text();
    if (response.ok) {
      const parsed = JSON.parse(bodyText) as unknown;
      return { text: extractText(parsed), status: 200, variant: variant.name, model };
    }
    // Xato matnida kalit bo'lishi mumkin emas, lekin baribir qisqartiramiz.
    const failed: GeminiOutcome = {
      status: response.status,
      variant: variant.name,
      detail: bodyText.slice(0, 300),
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
    const aborted = error instanceof DOMException && error.name === 'AbortError';
    logEvent('gemini_exception', { model, variant: variant.name, aborted });
    return {
      status: aborted ? 504 : 502,
      variant: variant.name,
      detail: aborted ? `timeout ${budget}ms` : String(error).slice(0, 200),
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

/// MODEL ZANJIRI: asosiy model o'tkinchi 503 yoki 404 bersa, zaxira modelga
/// o'tamiz.
///
/// NIMA UCHUN faqat 503/404: 401/403 (kalit), 429 (kvota) va 504 (timeout)
/// modelni almashtirish bilan TUZALMAYDI — zanjirni davom ettirish foydasiz
/// so'rov va kechikish qo'shadi. 400 esa `callModel` ichida payload
/// variantlari bilan allaqachon hal qilinadi.
async function callGemini(apiKey: string, userPrompt: string): Promise<GeminiOutcome> {
  const deadline = Date.now() + TOTAL_BUDGET_MS;
  let last: GeminiOutcome = { status: 0, variant: 'none' };
  for (const model of MODELS) {
    last = await callModel(model, apiKey, userPrompt, deadline);
    if (last.text !== undefined) return last;
    if (last.status !== 503 && last.status !== 404) return last;
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

const RISK_LEVELS = ['low', 'medium', 'high', 'critical'];

/// `RiskLevel` Dart tomonda enum; noto'g'ri satr kelsa `parseRisk` uni
/// `RiskLevel.low` ga tushiradi va foydalanuvchi HAQIQIY riskdan past
/// baho ko'radi. Shuning uchun normalizatsiya serverda: tanib bo'lmasa
/// `medium` (past emas) — xavfsizlik tomoniga xato qilamiz.
function normalizeRisk(raw: unknown, requiresLawyerDefault: boolean): Record<string, unknown> {
  const r = (typeof raw === 'object' && raw !== null ? raw : {}) as Record<string, unknown>;
  const level = asString(r.level).toLowerCase().trim();
  const summary = asString(r.summary).slice(0, 3000);
  const deadlineRaw = r.deadline_days ?? r.deadlineDays;
  const deadline = typeof deadlineRaw === 'number' && Number.isFinite(deadlineRaw)
    ? Math.max(0, Math.trunc(deadlineRaw))
    : null;
  return {
    level: RISK_LEVELS.includes(level) ? level : 'medium',
    summary: summary.length > 0
      ? summary
      : 'Risk tahlili to\'liq emas — huquqiy oqibatlarni advokat bilan tekshiring.',
    limitations: asStringList(r.limitations).slice(0, 12),
    requires_lawyer: typeof r.requires_lawyer === 'boolean'
      ? r.requires_lawyer
      : (typeof r.requiresLawyer === 'boolean' ? r.requiresLawyer : requiresLawyerDefault),
    deadline_days: deadline,
  };
}

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
): { body: Record<string, unknown>; droppedArticles: number } {
  const { kept, dropped } = groundLegalBasis(parsed.legal_basis ?? parsed.legalBasis, request.chunks);
  const steps = asStringList(parsed.actionable_steps ?? parsed.actionableSteps).slice(0, 20);
  return {
    droppedArticles: dropped,
    body: {
      query_id: request.queryId,
      category: request.category,
      relatable_summary: asString(parsed.relatable_summary ?? parsed.relatableSummary).slice(0, 4000),
      actionable_steps: steps,
      legal_basis: kept,
      risk_assessment: normalizeRisk(parsed.risk_assessment ?? parsed.riskAssessment, kept.length === 0),
      created_at: new Date().toISOString(),
      // Halollik metadatasi: UI "AI tahlili" deyishga HAQLI ekanini shu
      // maydon belgilaydi (`source: 'llm'`). Deterministik fallback client
      // tomonda `source: 'deterministic'` bo'ladi.
      source: 'llm',
      model: MODEL,
      dropped_articles: dropped,
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
    return errorResponse(405, 'method_not_allowed', 'Faqat POST qabul qilinadi');
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
  if (!authHeader.toLowerCase().startsWith('bearer ') || authHeader.length < 20) {
    return errorResponse(401, 'missing_authorization', 'Authorization: Bearer <token> talab qilinadi');
  }

  let auth: AuthResult;
  try {
    auth = await verifyUser(authHeader, supabaseUrl, anonKey);
  } catch (error) {
    logEvent('auth_check_failed', { error: String(error).slice(0, 120) });
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

  // 3) Rate limit.
  if (rateLimitExceeded(auth.userId)) {
    logEvent('rate_limited', { user: redactId(auth.userId), limit: MAX_PER_HOUR });
    return errorResponse(429, 'rate_limited', `Soatlik limit tugadi (${MAX_PER_HOUR})`);
  }
  // 4) Body validatsiyasi.
  let body: unknown;
  try {
    body = await req.json();
  } catch {
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
    // Upstream tafsiloti client'ga UZATILMAYDI — kalit/loyiha ma'lumoti
    // sizib chiqmasligi uchun. To'liq matn faqat funksiya log'ida.
    if (outcome.detail !== undefined) logEvent('ai_detail', { detail: JSON.stringify(outcome.detail) });
    return upstreamErrorResponse(
      code,
      'AI xizmatidan javob olinmadi',
      outcome.status,
      outcome.variant,
      outcome.detail,
      outcome.model ?? MODEL,
    );
  }

  const parsed = extractJsonObject(outcome.text);
  if (parsed === null) {
    logEvent('unparseable', { len: outcome.text.length, variant: outcome.variant });
    return errorResponse(502, 'ai_unparseable', 'AI javobi JSON emas');
  }

  const { body: shaped, droppedArticles } = shapeResponse(parsed, request, outcome.variant);
  if (asString(shaped.relatable_summary).length === 0) {
    logEvent('empty_summary', { variant: outcome.variant });
    return errorResponse(502, 'ai_empty', 'AI javobi bo\'sh');
  }

  logEvent('ok', {
    user: redactId(auth.userId),
    model: outcome.model ?? MODEL,
    articles: (shaped.legal_basis as unknown[]).length,
    dropped: droppedArticles,
    variant: outcome.variant,
  });
  return jsonResponse(200, shaped);
});
