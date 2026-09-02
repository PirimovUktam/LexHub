# LEXHUB FINAL TRANSFORMATION REPORT

> **Sana:** 2026-08-30 · **Filial:** `chore/claude-skills` · **Oxirgi commit:** `219545f`
> **Til:** hisobot o'zbek tilida (CLAUDE.md), texnik atamalar inglizcha.
>
> **BU HISOBOTDAGI HAR BIR DA'VO YORLIQLANGAN:**
> `O'LCHANDI` = shu sessiyada buyruq ishga tushirilgan va chiqishi ko'rilgan ·
> `REPO'DA ISBOT` = repo matnidan o'qilgan (jonli tizim EMAS) ·
> `NOT VERIFIED` = isbot YO'Q · `BLOCKED` = muhit/dependency yetishmaydi.
>
> **Bu sessiyada ishga tushirilgan tekshiruvlar (O'LCHANDI):**
> `flutter analyze` → `No issues found! (ran in 6.4s)` ·
> `flutter test` → `+798 ~26`, chiqish kodi 0 (26 skip = 26 ta live gate) ·
> `python tool/validate_sql_syntax.py` → `Jami: 31 fayl, xatolik: 0`.

---

## 1. EXECUTIVE SUMMARY

LexHub bugun **ishlaydigan, testlar bilan qattiq qulflangan Flutter + Supabase
mahsuloti**, lekin briefda so'ralgan ma'noda **hali "Legal Reasoning Engine"
emas**: u `Legal Problem → Legal Answer` bosqichida turadi, `Legal Action`
qatlami esa (hujjat, eskalatsiya) qisman va bir-biriga to'liq ulanmagan.

Uchta eng muhim xulosa:

1. **Kod sifati va regressiya himoyasi — kuchli tomon.** 798 test o'tadi,
   `flutter analyze` toza, xavfsizlik testlari 81+, migratsiyalarning O'ZI ham
   statik kontrakt testlari bilan qulflangan (O'LCHANDI).
2. **Moat — hali yupqa.** Huquqiy korpus 17 moddadan iborat (REPO'DA ISBOT:
   `lib/core/legal_safety/uzbek_legal_knowledge_base.dart:257`), temporal
   validity (`effective_from`/`effective_to`) **umuman yo'q** (O'LCHANDI: `lib`
   va `supabase` bo'ylab 0 marta uchraydi), `CaseOutcome` / `LegalProblem` /
   `Feedback` modellari yo'q (O'LCHANDI: 0 marta). Ya'ni briefda "himoyalanadigan
   qatlam" deb aytilgan narsalarning aksariyati hali YO'Q.
3. **Yagona to'siq — DEPLOYMENT ISBOTI YO'Qligi.** Bugun repo'da ikkita
   xavfsizlik migratsiyasi yozildi (`20260830100000`, `20260830110000`), lekin
   ular jonli bazaga qo'llanganini isbotlash imkoni bo'lmadi: `psql` ham,
   Docker ham yo'q (BLOCKED). Shu sababli "shaxsiy xatcho'plar mehmon uchun
   ochiq" degan P0 ehtimoli **yopildi deb aytilmaydi** — repo'da yopildi,
   production'da NOT VERIFIED.

**FINAL STATUS: BLOCKED** — sabab va uni yechish tartibi §18 da.

## 2. BU TRANSFORMATSIYADA NIMA QILINDI

| # | Ish | Isbot darajasi |
|---|---|---|
| 1 | Anonim savol EGASINI fosh qilish teshigi yopildi (P0, maxfiylik) | jonli o'lchandi (commit `8ba78c1`) |
| 2 | Migratsiyalarda RLS **hech qachon yoqilmagan** 4 jadval topildi va yopildi (`bookmarks`, `question_categories`, `question_tags`, `question_tag_mappings`) | REPO'DA ISBOT; jonli NOT VERIFIED |
| 3 | `supabase/schema.sql` da bor, `migrations/` da YO'Q yozish policy'lari to'ldirildi (`questions` INSERT/UPDATE, `reports` INSERT, `votes` ALL) | REPO'DA ISBOT; jonli NOT VERIFIED |
| 4 | Ekspert rad etish sababi va qayta topshirish vaqti UI'da ko'rsatildi | commit `83dbd06` |
| 5 | To'qima (fabricated) 5 yulduzli reyting olib tashlandi | commit `50c98d9` |
| 6 | `tool/validate_sql_syntax.py` **soxta xato** berayotgani topildi va tuzatildi | O'LCHANDI (§13) |
| 7 | `BootstrapStrings` kalit pariteti testi qo'shildi (§20 null-xavfsizlik) | O'LCHANDI: 9 test, mutatsiya bilan QIZIL bo'lishi isbotlandi |

**Diqqat:** 2, 3 va 6-qatorlar *repo integritetini* tuzatadi. Ular
production'ni tuzatgani **isbotlanmagan** — migratsiya faylining mavjudligi
deployment ISBOTI EMAS (§0).

---

## 3. POZITSIYALASH: `Legal Problem → Legal Reasoning → Legal Action`

| Bosqich | Bugungi holat | Baho |
|---|---|---|
| Problem Intake | erkin matn + kategoriya chipi bor | **B** |
| Legal Classification | kategoriya bor, lekin **rasmiy taksonomiya YO'Q** (`LegalProblem` modeli 0 marta uchraydi) | **D** |
| Fact Extraction | kalit so'z stub'i (REPO'DA ISBOT) | **D** |
| Legal Retrieval | `search_law_articles` RPC + ILIKE, 12 moslik, ball darvozasi bor | **B** |
| Source Verification | `legal_grounding_validator.dart` bor; **amal qilish sanasi YO'Q** | **C** |
| Reasoning | real LLM (proxy orqali), 10 qismli javob shakli bor | **B** |
| Risk Assessment | emergency protokol bor, umumiy risk skoringi yo'q | **C** |
| Action Plan | qadamlar matn ichida, alohida struktura sifatida YO'Q | **C** |
| Document Generation | ishlaydi, lekin AI oqimidan **alohida** turadi (§9 talabi bajarilmagan) | **C** |
| Lawyer Escalation | `lawyer_escalation_card` + ekspert katalogi bor, avtomatik marshrutlash yo'q | **C** |
| Outcome / Feedback | **YO'Q** (`CaseOutcome`, `Feedback` modellari 0 marta) | **F** |

Ya'ni zanjirning **boshi kuchli, oxiri uzilgan**. Mahsulot "javob beradi",
lekin "natijani o'lchamaydi" — va aynan oxirgi bo'g'in moat yaratadi (§4).

## 4. MOAT: NIMA HIMOYALANADI, NIMA YO'Q

Model — kommodite. Quyidagi jadval briefdagi himoya qatlamlarini bugungi
O'LCHANGAN holat bilan solishtiradi.

| Himoya qatlami | Bugun | O'lchov |
|---|---|---|
| O'zbek huquqiy korpusi | **17 modda** | `uzbek_legal_knowledge_base.dart:257` |
| Modda darajasida mapping | bor (`article_number`, `document_name`) | `20260821020000_legal_rag_chunks_and_rpc.sql` |
| Manba yangiligi / temporal validity | **YO'Q** | `effective_from`/`effective_to` → 0 marta |
| Muammo taksonomiyasi | **YO'Q** | `LegalProblem` → 0 marta |
| Hujjat shablonlari | 2 migratsiyada seed | `20260823...`, `20260830090000` |
| Anonim workflow feedback | **YO'Q** | `Feedback` → 0 marta |
| Tasdiqlangan yurist tarmog'i | bor (moderatsiya + litsenziya qulfi) | `20260829000500_expert_license_visibility_and_lock.sql` |
| AI → inson eskalatsiyasi | qisman (karta bor, marshrut yo'q) | `lawyer_escalation_card.dart` |
| Natija (CaseOutcome) | **YO'Q** | 0 marta |

**Halol xulosa:** bugungi holatda LexHub'ning texnik qismini boshqa jamoa
bir necha haftada takrorlashi mumkin — chunki qiyin qism (verifikatsiyalangan
korpus, taksonomiya, natija ma'lumoti) hali yaratilmagan. "Clone qilib
bo'lmaydi" degan da'vo **asossiz bo'lardi**. Real moat 17 moddadan yuzlab
moddaga o'tishda va natija ma'lumotini yig'ishda paydo bo'ladi, kodda emas.

---

## 5. ARXITEKTURA

Qatlamlar **toza**: `presentation → bloc → usecase → repository → datasource →
Supabase`. God class YO'Q (eng katta modul `legal_experts` — 25 fayl / 4130
satr, O'LCHANDI). DI markazlashgan (`lib/core/di/injection_container.dart`).

**Kuchli tomon:** har bir pipeline bosqichi uchun alohida datasource/service
mavjud, ya'ni briefdagi "service boundary" talabi asosan bajarilgan.

**Zaif tomon:** pipeline bosqichlari **kod ichida ketma-ket chaqiriladi**,
lekin ular orasidagi shartnoma (contract) tiplangan emas — masalan "Fact
Extraction" natijasi alohida model emas, matn ichida qoladi. Yangi bosqich
qo'shish uchun mavjud faylni ochish kerak bo'ladi (extension point yo'q).

**Modullar hajmi (O'LCHANDI):**

```
core 54 fayl / 7195 satr   legal_experts 25/4130   legal_assistant 24/4296
community_forum 23/4580    auth 22/2633            document_builder 18/2556
consultations 17/2994      home 17/3401            citizen_services 14/1917
search 11/1694             saved_cases 3/505       main_navigation 2/448
settings 2/265             diagnostics 1/319       emergency_rights 1/314
```

## 6. MODUL BAHOLARI (§3)

Baho **o'lchangan test qoplamasi + ma'lum nuqsonlar** asosida, taassurot
asosida emas. "test" ustuni — shu modul fayllariga murojaat qiladigan test
fayllari soni (O'LCHANDI).

| Modul | Test | Baho | Sabab |
|---|---|---|---|
| `auth` | 19 fayl / ~189 test | **A−** | register/login/session/profile oqimi jonli tekshirilgan; null-crash regressiya testlari bor |
| `community_forum` | 19 / ~194 | **A−** | kategoriya UUID, anonimlik, javob mapping'i qulflangan; anonim EGA teshigi yopilgan |
| `legal_assistant` | 20 / ~162 | **B+** | real LLM proxy orqali, grounding validator bor; confidence modeli va temporal validity YO'Q |
| `legal_experts` | 13 / ~127 | **B+** | litsenziya ko'rinishi, moderatsiya gvardi, sovutish davri qulflangan; to'qima reyting olib tashlangan |
| `home` | 7 / ~91 | **B** | jim `catch (_) {}` lar olib tashlangan, xato ko'rinadi |
| `document_builder` | 10 / ~72 | **B−** | katalog pariteti migratsiyasi NOT VERIFIED; AI oqimiga ulanmagan |
| `consultations` | 7 / ~40 | **B−** | to'lov/konsultatsiya RLS bor; webhook oqimi qisman |
| `search` | 7 / ~26 | **B−** | unified RPC bor; overflow/bo'sh holat testlari yangi |
| `citizen_services` | 7 / ~21 | **C+** | 1917 satrga 21 test — nisbat past; freshness seed 2026-08-22 dan yangilanmagan |
| `saved_cases` | 2 / ~23 | **C+** | mahalliy Hive oqimi, server sinxronizatsiyasi yo'q |
| `main_navigation` | 2 / ~7 | **C** | asosiy skeleton, deep-link testi yo'q |
| `settings` | 1 fayl (l10n) | **C−** | faqat til almashtirish qulflangan |
| `diagnostics` | **0** | **D** | `crash_log_page.dart` (319 satr) — xulq testi YO'Q (O'LCHANDI) |
| `emergency_rights` | **0** | **D** | 314 satr — xulq testi YO'Q; huquqiy jihatdan eng nozik ekran |
| `core` | 30 fayl / 81+ xavfsizlik testi | **A−** | l10n, tema, telemetriya, xavfsizlik qulflangan |

**Eng jiddiy nomutanosiblik:** `emergency_rights` — foydalanuvchi eng
og'ir vaziyatda (hibsga olish, tintuv) ko'radigan ekran, va u **umuman
testlanmagan**. Bu texnik xato emas, **huquqiy risk**.

---

## 7. AI QATLAMI (§6, §8)

**Halol yorliqlash — bajarilgan.** `test/l10n/ai_claim_honesty_test.dart`
"AI" so'zining eski matnlarda qolib ketishini taqiqlaydi (O'LCHANDI: o'tadi).

**Secret joylashuvi — to'g'ri (O'LCHANDI):** repo bo'ylab `AIza…` shaklidagi
kalit **topilmadi**; `SupabaseConfig.geminiApiKey` `kReleaseMode`da bo'sh
string qaytaradi (`supabase_config.dart:65-66`); production yo'li —
`lib/core/network/legal_ai_proxy_service.dart` (kalit `supabase secrets`
ichida); `env/*.json` `.gitignore:21` bilan chiqarilgan.

**Grounding — qisman.** Retrieval ILIKE asosida (semantik embedding emas),
`legal_grounding_validator.dart` javobdagi modda raqamlarini korpus bilan
solishtiradi. **Lekin:** eskirgan va amaldagi norma bir-biridan ajratilmaydi,
chunki sana maydonlari yo'q. Ya'ni §8 talabi **bajarilmagan**.

## 8. REASONING UX VA CONFIDENCE MODELI (§7)

| Talab | Holat |
|---|---|
| 10 qismli javob shakli | BOR |
| "100% to'g'ri" demaslik | BAJARILGAN (`ai_claim_honesty_test.dart` qulflaydi) |
| Yuqori / O'rta / Qo'shimcha tekshiruv kerak | **YO'Q** — `confidence` `lib` ichida 1 marta uchraydi (O'LCHANDI), UI'da ishonch darajasi ko'rsatilmaydi |
| Ishonch darajasi SABABI | **YO'Q** |

Bu §7 ning eng katta bajarilmagan qismi. Foydalanuvchi javobning qanchalik
ishonchli ekanini bilmaydi — huquqiy mahsulotda bu **eng xavfli bo'shliq**,
chunki noto'g'ri javob ham to'g'ri javob kabi ishonchli ko'rinadi.

---

## 9. DOCUMENT BUILDER (§9)

Ishlaydi: shablon katalogi, maydon to'ldirish, ko'rish, saqlash
(`user_documents`, RLS `auth.uid() = user_id`). Jonli anon izolyatsiya testi
ro'yxatida (`private_tables_anon_isolation_live_test.dart`).

**Bajarilmagan:** AI oqimi bilan integratsiya. Bugun foydalanuvchi javob oladi,
keyin **alohida** hujjat quruvchiga boradi va faktlarni QAYTA kiritadi.
Briefda so'ralgani — bir oqim. `lib/features/document_builder/domain/
ai_document_routing.dart` (yangi, hali commit qilinmagan) shu ko'prikning
boshlanishi.

---

## 10. YURIST ESKALATSIYASI (§10)

Tasdiqlangan tarmoq **bor va qulflangan**: litsenziya raqami xom jadvalda,
ochiq katalog `public_expert_profiles_view` orqali; tasdiqlangandan keyin
litsenziya raqami qotib qoladi; rad etish holatini faqat moderatsiya
o'zgartiradi (trigger gvardi, `20260829130000`).

**Bajarilmagan:** avtomatik marshrutlash (muammo turi → mos ixtisoslik →
mavjud ekspert). Bugun foydalanuvchi o'zi qidiradi. To'liq marketplace
ATAYLAB qilinmagan — bu brief talabiga mos.

---

## 11. COMMUNITY (§11)

Savol/javob oqimi, kategoriya UUID rezolyutsiyasi, anonimlik, ega tomonidan
o'chirish, RBAC — barchasi test bilan qulflangan (~194 test). Anonim savolning
EGASI fosh bo'lish teshigi bugun yopildi (`8ba78c1`, jonli o'lchandi).

**Bajarilmagan:** community ma'lumotini *huquqiy intellekt* sifatida
ishlatish — ya'ni "qaysi muammo qanchalik ko'p uchraydi" signalini yig'ish.
Bu §11 va §23 (metrika extension point) bilan bir xil bo'shliq.

## 12. XAVFSIZLIK HOLATI

**Bugun topilgan va repo'da yopilgan (REPO'DA ISBOT, jonli NOT VERIFIED):**

1. **`bookmarks` — shaxsiy ma'lumot, migratsiyalarda RLS umuman yo'q edi.**
   Supabase `public` sxemada `anon`/`authenticated` ga sukut bo'yicha to'liq
   huquq beradi, ya'ni RLS'siz jadval **o'qishga VA yozishga ochiq**. Xatcho'p
   sarlavhasi odamning qanday huquqiy muammosi borligini oshkor qiladi.
   Yechim: egasiga-xos SELECT/INSERT/DELETE (`20260830100000`).
2. **Ochiq ma'lumotnomalarga YOZISH ochiq edi** (`question_categories`,
   `question_tags`, `question_tag_mappings`). Mehmon kategoriyani o'chirsa,
   `ON DELETE SET NULL` tufayli **haqiqiy savollarning** `category_id` si NULL
   bo'lardi. Yechim: o'qish ochiq (`USING (true)`), yozish admin/moderator.
3. **`migrations/` da yozish policy'lari yo'q edi** (`questions` INSERT/UPDATE,
   `reports` INSERT, `votes` ALL). Faqat migratsiyalardan qurilgan bazada
   savol yaratish `42501` bilan RAD ETILADI — ya'ni §4 dagi "community savol
   yaratish" regressiya taqiqiga tegadi. Yechim: **FILL-ONLY** migratsiya
   (`20260830110000`) — bironta `DROP POLICY` yo'q, chunki jonli policy
   repo'dagidan QATTIQROQ bo'lishi mumkin va uni almashtirish "security policy
   weakening" bo'lardi.
4. **`supabase/schema.sql` ning O'ZIDA nuqson:** u `question_tags` va
   `question_tag_mappings` ga RLS yoqadi, lekin policy bermaydi → **DENY-ALL**,
   ya'ni ochiq ma'lumotnoma o'qilmaydi. Yangi migratsiya bu shoxda buzilgan
   O'QISHNI TIKLAYDI (REPO'DA ISBOT: `schema.sql:822-833`).

**Ilgari yopilgan va hamon qulflangan:** anonim savol egasi, litsenziya
ko'rinishi, reyting o'zgartirish gvardi, `is_admin_or_moderator()` asosidagi
RBAC, webhook execute huquqi, PII log'ga yozilmasligi, service_role kalitining
repo'da yo'qligi (O'LCHANDI: `sb_secret_`/`eyJ…` naqshlari migratsiyalarda
topilmadi — har bir yangi migratsiya testida "sir YO'Q" gate'i bor).

**Statik qoplama (O'LCHANDI):** `test/core/security/rls_enabled_for_all_tables_test.dart`
— migratsiyalarda `CREATE TABLE` bo'lgan **21 jadvalning 21 tasida** RLS va
kamida bitta policy bor; carve-out ro'yxati ATAYLAB bo'sh.

**Eng muhim ogohlantirish:** bularning hammasi **repo matni**. Jonli bazada
ushbu policy'lar bor-yo'qligi shu sessiyada o'lchanmadi (`psql`/Docker yo'q →
BLOCKED). Anon kalit bilan zondlash ham javob bermaydi: policy YO'Qligi ham,
"sessiya kerak" holati ham bir xil `42501` beradi.

---

## 13. MA'LUMOTLAR BAZASI VA MIGRATSIYA INTEGRITETI

**31 migratsiya fayli, sintaksis xatosi 0** (O'LCHANDI:
`python tool/validate_sql_syntax.py` → `Jami: 31 fayl, xatolik: 0`).

Bunga yetishish uchun bugun **validatorning O'ZIDAGI nuqson** tuzatildi:

* `FUNC_RE` xom matnga qo'llanardi, shuning uchun **izoh ichidagi**
  `CREATE OR REPLACE FUNCTION` so'zi ham moslikni boshlab yuborardi va
  non-greedy `.*?` keyingi haqiqiy `$tag$ … $tag$;` gacha cho'zilardi.
* O'LCHANGAN natija (`20260829130000_expert_moderation_guard_fix_and_apply_cooldown.sql`):
  moslik #1 chegarasi **satr 13 → 123** (izohdan boshlanib haqiqiy funksiyani
  yutgan) va #2 **125 → 241**. Parser esa "syntax error at or near CREATE" va
  "syntax error at or near `` ` ``" deb qaytarardi — **soxta xato**, va shu
  bilan birga ikkita HAQIQIY funksiya tanasi **umuman tekshirilmay** qolardi.
* Tuzatish: `_blank_comments()` — `--` izohlarni bo'sh joy bilan almashtiradi
  (indeks va satr raqami o'zgarmaydi), satr literali va dollar-quoted tanani
  hisobga oladi. Tuzatishdan keyin chegaralar: **87→123, 164→241, 271→361**.

**Mutatsiya bilan isbot (O'LCHANDI) — validator "jim yashil" emas:**

| Mutatsiya | Kutilgan | Natija |
|---|---|---|
| funksiya tanasidan `END IF;` olib tashlandi | QIZIL | `[XATO] plpgsql funksiya #1 (satr ~87)` |
| xato FAQAT izohda | YASHIL | `[OK]` |
| `DO` bloki ichida `END IF;` → `END;` | QIZIL | `[XATO] DO bloki #2 (satr ~112)` |

**Halol cheklov (O'LCHANDI va hujjatlashtirildi):** plpgsql parseri gap
TUZILISHINI tekshiradi, gap ichidagi SQL IFODANI esa yo'q —
`NEW.updated_at := ;` mutatsiyasi `[OK]` bergan. Ya'ni `[OK]` = "tuzilish
buzilmagan", "ifoda to'g'ri" degani EMAS.

`tool/sql_quote_check.py` **saqlanadi** (qaror, §27 avtonomiyasi): u pglast
tuta olmaydigan sinfni tutadi — satr literali ichidagi `;` gap sonini
o'zgartirgani bugun ikki marta shu skript bilan topildi. Uning evristik
ekani va cheklovlari fayl boshiga yozildi.

## 14. ISHONCHLILIK, XATOLIK OQIMI, OBSERVABILITY (§20, §22)

**Jim yutish — YO'Q (O'LCHANDI).** `lib/` bo'ylab **0 ta** haqiqiy
`catch (_) {}` qoldi; topilgan 10 ta moslik — hammasi *olib tashlanganini
hujjatlashtiruvchi izoh*. Ya'ni "fake success / silent fallback" taqiqi
bajarilgan.

**Null-assertion auditi (O'LCHANDI — buyruq bilan qayta o'lchanadi):**

```bash
grep -rnoE '[]A-Za-z0-9_)]!' --include=*.dart lib | grep -v 'lib/l10n/gen' | wc -l
```

→ **119 moslik / 43 fayl**. Bu son YUQORI CHEGARA: mexanik sanoq satr literali
ichidagi undovni ham qo'shadi (masalan
`legal_assistant_remote_datasource.dart:85` — o'zbekcha ogohlantirish matni).
Indekslangan `...]!` shakli — 9 satr — to'liq qo'lda ko'rildi:
`Colors.grey[800]!` (Material palitrada kalit const), `match[0]!` /`m[2]!`
(RegExp guruhlari majburiy), `event.initialValues![field.id]!`
(`!= null && containsKey` gvardi ichida) — hammasi xavfsiz. Eng xavfli
ko'ringan shakllar alohida ko'rildi:


| Joy | Xulosa |
|---|---|
| `legal_assistant_bloc.dart:53,62` — `result.fold(...)!` | XAVFSIZ: `if (result.isLeft())` gvardi ichida |
| `legal_assistant_remote_datasource.dart:357` — `supabaseClient!` | XAVFSIZ: `if (supabaseClient != null && …)` gvardi |
| `legal_experts_bloc.dart:127` — `applyExpertVerificationUseCase!` | XAVFSIZ: yuqorida `== null → return` |
| `bootstrap_strings.dart:70-71` — `_values[fallback]![key]!` | **XAVF BOR EDI**: bugun yiqilmaydi, lekin kelajakda faqat `en` ga qo'shilgan kalit `ErrorWidget.builder` ICHIDA null-crash berardi |

Oxirgi qator bo'yicha **yangi test yozildi**:
`test/core/localization/bootstrap_strings_key_parity_test.dart` (9 test,
O'LCHANDI: o'tadi). Mutatsiya bilan isbotlandi — `en` dan `configKeysHint`
olib tashlanganda **3 test QIZIL** bo'ldi, manba baytma-bayt tiklandi.

**Observability bo'shligi:** `correlation_id` / `requestId` **0 marta**
uchraydi (O'LCHANDI). Ya'ni §22 dagi "request context + correlation id"
talabi bajarilmagan. Structured error code va sanitized log bor
(`crash_reporter.dart`, `client_error_logs` jadvali `authenticated` uchun
qulflangan).

---

## 15. TEST STRATEGIYASI (§21)

**O'LCHANDI:** `flutter test` → `+798 ~26`, chiqish kodi 0.

* 26 ta skip — **hammasi** `LIVE GATE (production)` markeri, har bir
  `test/integration/` fayliga bittadan (26 fayl). Yashirilgan skip YO'Q,
  yumshatilgan assertion YO'Q (`--reporter=json` bilan `testDone.skipped`
  tekshirilgan).
* Statik migratsiya kontrakt testlari: migratsiyani "soddalashtirib" himoyani
  jimgina yo'q qilishning oldini oladi (`rls_enabled_for_all_tables_test.dart`,
  `write_policy_parity_test.dart`, `questions_anonymity_migration_contract_test.dart`).
* Har bir yangi test **mutatsiya bilan** tekshirildi (tuzatishni olib tashlab
  QIZIL bo'lishini ko'rish) — "bo'sh o'tish" (vacuous pass) imkonsiz.

**Bo'shliq:** `diagnostics` va `emergency_rights` modullarida xulq testi
**yo'q** (O'LCHANDI: 0 fayl).

---

## 16. LOCALIZATION (§18)

uz + en, default uz. ARB pariteti, hardcoded matn taqiqi va til almashtirish
persistensiyasi test bilan qulflangan (O'LCHANDI: `test/l10n/` — 5 fayl,
hammasi o'tadi). Backend rol qiymatlari (`citizen`, `lawyer`,
`verified_expert`, `admin`, `moderator`) **o'zgarmagan** — lokalizatsiya faqat
prezentatsiya qatlamida. Bugun qo'shilgan bootstrap paritet testi shu
himoyaning **birinchi lokalizatsiyadan oldingi** qatlamini ham yopdi.

## 17. TRIAGE (§26)

### MUST FIX NOW

| ID | Muammo | Isbot | Nima qilinadi |
|---|---|---|---|
| M1 | Ikkita xavfsizlik migratsiyasi jonli bazaga qo'llangani ISBOTLANMAGAN | NOT VERIFIED (`psql`/Docker yo'q) | §18 dagi 3 qadam |
| M2 | `bookmarks` jonli bazada ochiq bo'lishi MUMKIN (shaxsiy ma'lumot) | ikki shoxli, NOT VERIFIED | M1 dan keyin `private_tables_anon_isolation_live_test.dart` |
| M3 | `emergency_rights` (314 satr) xulq testi YO'Q — huquqiy risk | O'LCHANDI: 0 test | ekran matnini va emergency protokolni qulflaydigan widget testi |

### SHOULD FIX

| ID | Muammo | Isbot |
|---|---|---|
| S1 | Confidence modeli (§7) UI'da YO'Q | `confidence` → 1 marta |
| S2 | `effective_from`/`effective_to` YO'Q — eskirgan norma ajratilmaydi (§8) | 0 marta |
| S3 | `correlation_id` YO'Q (§22) | 0 marta |
| S4 | Document Builder AI oqimidan alohida (§9) | REPO'DA ISBOT |
| S5 | `diagnostics` testsiz | 0 test |
| S6 | `citizen_services` freshness seed 2026-08-22 dan yangilanmagan | migratsiya sanasi |
| S7 | `20260830090000_document_templates_catalog_parity.sql` bajarilishi NOT VERIFIED | — |

### FUTURE

| ID | Ish |
|---|---|
| F1 | Korpusni 17 moddadan yuzlab moddaga kengaytirish (asosiy moat) |
| F2 | `LegalProblem` taksonomiyasi + `CaseOutcome` + anonim `Feedback` |
| F3 | Muammo → ixtisoslik → ekspert avtomatik marshrutlash |
| F4 | Semantik retrieval (embedding) ILIKE o'rniga |
| F5 | Metrika extension pointlari (§23) |
| F6 | `nullable`ni gvard bilan emas, tip bilan yopish (65 ta `!` ni kamaytirish) |

---

## 18. O'Z-O'ZINI TANQID (§28) VA FINAL STATUS (§31)

**PRODUCT:** mahsulot "javob beruvchi" bo'lib qoldi, "harakatga olib boruvchi"
emas. Foydalanuvchi javob oladi, keyin nima qilishni o'zi hal qiladi.

**AI:** halol yorliqlangan va real LLM ishlaydi, lekin ishonch darajasi
ko'rsatilmaydi. Huquqiy mahsulotda bu eng katta xavf: noto'g'ri javob
to'g'ri javob kabi ishonchli ko'rinadi.

**SECURITY:** repo integritetida sezilarli yaxshilanish bor, lekin men
**bugun production haqida hech narsani isbotlay olmadim**. "Yopildi" degan
so'z faqat repo uchun to'g'ri.

**DATA:** eng zaif joy. 17 modda, sana maydonlari yo'q, natija ma'lumoti yo'q.
Moat ma'lumotda bo'ladi, kodda emas — bugun ma'lumot yo'q.

**UX:** ikki modul (`emergency_rights`, `diagnostics`) testsiz; ishonch
indikatori yo'q; qolgan oqimlar overflow/bo'sh/xato holatlari bilan qulflangan.

**COMPETITION:** "boshqa dasturchi bir haftada takrorlay oladimi?" — **texnik
qismini, ha**. Takrorlanmaydigan qism (verifikatsiyalangan korpus, taksonomiya,
natija ma'lumoti) hali qurilmagan. Buni yashirish emas, aytish kerak.

**ENGINEERING:** kuchli tomon — regressiya himoyasi va mutatsiya bilan
tekshirilgan testlar. Zaif tomon — bugun **validatorning o'zi** soxta xato
berayotgani aniqlandi, ya'ni "yashil quvur" ham shubha ostiga olinishi kerak.
Bu sessiyaning eng muhim saboqi: **tekshirgichni ham tekshirish shart**.

### FINAL STATUS: **BLOCKED**

**Sabab (aynan bitta):** §31 qoidasiga ko'ra qolgan P0 xavfsizlik ehtimoli
BLOCKED beradi. Bugun repo'da yopilgan `bookmarks` teshigi **jonli bazada
yopilgani isbotlanmagan**, va uni anon zondlash bilan farqlash mumkin emas.
Ma'lumot yo'qotish xavfi YO'Q (migratsiyalar birorta qatorni o'chirmaydi,
`DROP POLICY` ishlatilmaydi), lekin maxfiylik ehtimoli ochiq.

**BLOCKED holatini yechish — 3 qadam (boshqa hech narsa kerak emas):**

1. Supabase SQL Editor'da **shu tartibda** ishga tushirish:
   `20260830100000_rls_never_enabled_tables.sql`, so'ng
   `20260830110000_missing_write_policies_parity.sql`.
   Har biri COMMIT'dan keyin **jadval** qaytaradi (NOTICE ko'rinmaydi):
   kutilgan — 4 jadvalda `rls_yoqilgan = true`, `bookmarks` → 3 policy,
   ma'lumotnomalar → 2 policy; ikkinchisida cheklovsiz yozish policy'si YO'Q.
2. Jonli isbot:
   ```
   flutter test test/integration/private_tables_anon_isolation_live_test.dart \
     --dart-define-from-file=env/prod.json \
     --dart-define=LEXHUB_LIVE_WRITE_TESTS=true --reporter expanded
   ```
   Kutilgan: `bookmarks: anon count=0`, ochiq resurslar esa 200.
3. Community regressiyasi (§4) buzilmaganini ko'rish:
   `flutter test test/integration/real_supabase_community_e2e_test.dart` (gated).

Shu uchtasi yashil bo'lsa status **MVP READY WITH KNOWN NON-BLOCKING RISKS**
ga o'tadi (qolgan risklar: §17 SHOULD FIX / FUTURE ro'yxati). Ulardan
oldin **"PRODUCTION READY" so'zi ishlatilmaydi**.







