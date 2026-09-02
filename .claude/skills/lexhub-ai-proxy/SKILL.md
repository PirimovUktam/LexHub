---
name: lexhub-ai-proxy
description: LexHub'ning "AI" da'vosini HAQIQIY qilish uchun server-side Legal AI proxy (Supabase Edge Function `legal-ai`) yozish, deploy qilish va live tekshirish. Gemini/LLM kalitini client'ga QO'YMASDAN. Quyidagi hollarda ishlatiladi: AI javob bermayapti; release build'da AI o'chiq; `LEGAL_AI_PROXY_URL` 404 qaytaradi; demo/hakamlar uchun AI ishlashi kerak; `GeminiLegalService` null qaytaradi.
---

# LexHub — Legal AI proxy (server-side)

## Hozirgi holat (o'zgarmagan bo'lsa avval QAYTA TEKSHIR)

Release APK'da AI **umuman chaqirilmaydi**:

- `lib/core/config/supabase_config.dart:65` → `geminiApiKey => kReleaseMode ? '' : ...`
- `lib/core/network/gemini_legal_service.dart:21-24` → kalit bo'sh bo'lsa darhol `null`
- `legal_assistant_remote_datasource.dart` Step 5c → deterministik `_generateGroundedUzbekLegalResponse`
- `SupabaseConfig.legalAiProxyUrl` HECH QAYERDA iste'mol qilinmaydi (faqat config + test'da)
- `supabase/functions/` katalogi repo'da YO'Q

Tekshiruv buyrug'i (proxy deploy qilinganmi):

```bash
python -c "import json,urllib.request,urllib.error;u=json.load(open('env/prod.json'))['LEGAL_AI_PROXY_URL'];r=urllib.request.Request(u,data=b'{}',method='POST',headers={'Content-Type':'application/json'});
try: print(urllib.request.urlopen(r,timeout=20).status)
except urllib.error.HTTPError as e: print(e.code, e.read()[:200])"
```

`404 NOT_FOUND` → funksiya deploy qilinmagan. `401` → deploy qilingan, JWT talab qiladi (kutilgan).

## Qat'iy qoidalar

1. `GEMINI_API_KEY` **hech qachon** `env/*.json`, `--dart-define`, `lib/`, git yoki APK ichiga tushmaydi.
   Faqat `supabase secrets set` orqali serverda.
2. Client faqat o'z **JWT**'si bilan proxy'ga murojaat qiladi. `verify_jwt` YOQILGAN qoladi —
   anonim so'rov 401 bo'lishi kerak (fail-closed).
3. PII: client `PiiAnonymizer.anonymize()` dan O'TGAN matnni yuboradi. Proxy xom matnni
   log qilmaydi.
4. Grounding: proxy javobi `LegalGroundingValidator` va `RiskMatrixEvaluator` orqali
   post-process qilinadi — hallucination qilingan modda UI'ga chiqmasligi kerak.
   `MasterSystemPrompt.prompt` system instruction sifatida serverga ko'chiriladi.
5. Rate limit + timeout majburiy: bir user uchun soatlik limit, `AbortSignal` bilan
   ~20s timeout. Limitsiz proxy = ochiq hisob-kitob teshigi.
6. AI o'chiq/nosoz bo'lsa mavjud deterministik fallback SAQLANADI, lekin UI'da
   javob manbasi ROSTGO'YLIK bilan ko'rsatiladi (pastga qara).

## Bosqichlar

1. `supabase/functions/legal-ai/index.ts` yoz: JWT tekshir → body validatsiya
   (`query_text`, `category`, `retrieved_chunks`) → rate limit → Gemini `generateContent`
   (`responseMimeType: application/json`, `temperature: 0.2`) → javob sxemasini validatsiya →
   `LegalResponse.fromJson` kutgan snake_case JSON qaytar.
2. Kalitni sozla: `supabase secrets set GEMINI_API_KEY=<kalit>` (terminalda, repo'ga emas).
3. Deploy: `supabase functions deploy legal-ai`.
4. Client wiring: `LegalAssistantRemoteDataSourceImpl` ichida Step 5'ni
   `SupabaseConfig.hasLegalAiProxy` bo'lganda proxy'ga POST qiladigan yangi
   `LegalAiProxyService` bilan almashtir. `GeminiLegalService`ni release yo'lidan olib tashla
   (debug-only qoladi yoki butunlay o'chiriladi).
5. UI rostgo'yligi: javob AI'dan kelganini yoki deterministik bilim bazasidan kelganini
   ajratib ko'rsat (`LegalResponse`ga `source` maydoni + ARB kalitlari, `uz` va `en`).
6. Test: `test/integration/verify_legal_ai_proxy_live_test.dart` yoz —
   `test/support/live_gate.dart` gate'i ostida:
   - anon (JWT'siz) → **401** (fail-closed),
   - authenticated → 200 + `legal_basis` bo'sh emas + har bir modda `retrieved_chunks`
     ichida mavjud (hallucination yo'q),
   - PII bo'lgan so'rov → javobda ism/telefon/PINFL QAYTMASLIGI.
7. `lexhub-verify` skill'i bilan yakuniy verifikatsiya + APK secret scan
   (`GEMINI_API_KEY` hiti **0** bo'lishi SHART).

## Vaqt yetmasa (demo yaqin) — BAJARILDI

Proxy'ni deploy qilmasdan "AI" deb ko'rsatishdan ko'ra, UI'dagi nomlanishni
haqiqatga moslashtirish TEZROQ va XAVFSIZROQ. Bu qadam BAJARILGAN: `navAI`,
`homeAiAnalyzeButton`, `communityAiAnalysis`, `communityAiSummaryLabel`,
`questionDetailAiSummary`, `faqAskAiAction`, `legalDisclaimer` kalitlari
haqiqiy harakatni nomlaydigan matnga o'zgartirildi (uz + en pariteti bilan).

Regressiya qulfi: `test/l10n/ai_claim_honesty_test.dart` — ARB qiymatlarida
"AI" so'zi FAQAT `legalSourceLlm` va `legalSourceDeterministic` badge
kalitlarida qolishi mumkin, boshqa joyda test yiqiladi. Yangi yorliq
qo'shganda AI da'vosini `LegalResponse.source` bilan bog'la, matnga yozib
qo'yma.

QOLGAN NUQSON (P2, hali TUZATILMAGAN): manba badge'i FAQAT
`legal_assistant_page.dart:411-424` da ko'rsatiladi. `saved_cases_page.dart`,
`recent_cases_feed.dart` va `faq_questions_page.dart` AYNI javob matnini
manba ko'rsatmasdan chiqaradi.
