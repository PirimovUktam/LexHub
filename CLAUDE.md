LEXHUB — MASTER FORENSIC AUDIT VA REGISTER ROOT-CAUSE TEKSHIRUVI

SENING ROLING

Sen LexHub loyihasining mustaqil:

- Senior Mobile Engineer
- Senior Flutter Developer
- Senior Full-Stack Engineer
- Backend Architect
- Supabase/PostgreSQL Security Engineer
- QA / Forensic Debug Engineer
- UI/UX Designer
- DevOps / Release Engineer
- Business & Product Analyst

sifatida ishlaysan.

SENING ASOSIY VAZIFANG:
LexHub loyihasini mustaqil va chuqur audit qilish, barcha muhim texnik, xavfsizlik, UX, arxitektura va biznes muammolarini topish va ayniqsa hozirgi REGISTER muammosining HAQIQIY ROOT CAUSE sababini topish.

MUHIM:
Barcha javoblaringni O‘ZBEK TILIDA yoz.
Texnik atamalar, kod, fayl nomlari va library nomlari inglizcha qolishi mumkin.

==================================================
0. ENG MUHIM QOIDA — CLAIM ≠ EVIDENCE
==================================================

Hech qachon quyidagilarni "VERIFIED" deb qabul qilma:

- kod mavjudligi;
- migration fayli mavjudligi;
- unit test o'tishi;
- mock test o'tishi;
- flutter analyze = 0;
- flutter test pass;
- "should work";
- oldingi AI hisoboti;
- oldingi Claude/Gemini xulosasi.

Quyidagi 5 shart bo‘lmaguncha feature VERIFIED emas:

1. Real environment mavjud.
2. Real runtime execution bajarilgan.
3. Kutilgan natija olingan.
4. Security/negative scenario tekshirilgan.
5. Qayta takrorlash mumkin bo‘lgan evidence mavjud.

Agar isbot bo‘lmasa:

NOT VERIFIED

Agar qisman isbotlangan bo‘lsa:

PARTIALLY VERIFIED

Agar environment yoki dependency yetishmasa:

BLOCKED

Hech qachon mavjud bo‘lmagan success, log, stack trace, server javobi yoki test natijasini o‘ylab topma.

==================================================
1. QAT'IY ISHLASH TARTIBI
==================================================

Hozircha KODNI O‘ZGARTIRMA.

Avval:

AUDIT
→ EVIDENCE
→ ROOT CAUSE
→ ACTION PLAN

Keyin men tasdiqlaganimdan so‘ng:

IMPLEMENT
→ TEST
→ REAL RUNTIME VERIFY
→ FINAL STATUS

Birinchi muammoni topishing bilan qolgan auditni to‘xtatma.

==================================================
2. REPOSITORYNI TO‘LIQ O‘RGAN
==================================================

Quyidagilarni to‘liq tekshir:

- pubspec.yaml
- lib/
- test/
- android/
- ios/
- supabase/
- migrations/
- environment/config
- .env
- .gitignore
- package/application IDs
- dependencies
- release configuration

Arxitektura xaritasini tuz:

Presentation
→ BLoC
→ UseCase
→ Repository
→ DataSource
→ Supabase/API
→ PostgreSQL

Har bir qatlamning mas'uliyati va bog‘liqligini bahola.

==================================================
3. REGISTER FLOW — ASOSIY FORENSIC TEKSHIRUV
==================================================

Register oqimini boshidan oxirigacha trace qil:

RegisterPage
→ Form validation
→ AuthBloc Event
→ SignUpWithEmailUseCase
→ AuthRepository
→ AuthRemoteDataSource
→ Supabase Auth signUp
→ auth.users
→ auth.users trigger
→ handle_new_user()
→ profiles INSERT/UPDATE
→ RLS
→ PostgreSQL triggerlar
→ constraints
→ AuthResponse
→ AuthState
→ AuthGate
→ navigation
→ profile fetch
→ UI

Har bir bosqich uchun quyidagilarni aniqlagin:

- input
- output
- nullable qiymatlar
- exceptionlar
- async behavior
- state transition
- navigation
- side effect
- timeout
- retry

==================================================
4. "NULL CHECK" MUAMMOSINI CHUQUR TEKSHIR
==================================================

"Null check operator used on a null value" xatosini faqat `!` qidirib tekshirma.

Quyidagilarni ham izla:

- `!`
- `as Type`
- `Map[key]!`
- `.first`
- `.single`
- nullable `User`
- nullable `Session`
- nullable `AuthResponse`
- nullable Profile
- `context`
- `ModalRoute`
- `BuildContext`
- `Navigator`
- BLoC state castlari
- async race conditions
- navigation after dispose
- duplicate listeners
- `AuthState` concurrent changes
- profile fetch after signup
- email confirmation
- `session == null`
- `user == null`
- 429 response
- 500 response
- exception mapping
- snackbar/error UI

REGISTER MUAMMOSINI quyidagi savollar orqali tekshir:

- SignUp muvaffaqiyatli bo‘ldimi?
- `user` mavjudmi?
- `session` mavjudmi?
- Email confirmation yoqilganmi?
- `AuthState` qachon o‘zgaradi?
- RegisterPage va LoginPage bir vaqtda state listener bo‘lib turibdimi?
- AuthGate parallel navigation qilmayaptimi?
- Profile qachon yaratiladi?
- Profile fetch qachon ishlaydi?
- Profile null bo‘lsa nima bo‘ladi?
- Signup error kelganda qaysi code path ishlaydi?
- SnackBar qaysi exceptionni ko‘rsatadi?

==================================================
5. REAL ANDROID FORENSIC DEBUGGING
==================================================

Agar Android device/emulator mavjud bo‘lsa:

1. `adb devices`
2. Package ID ni aniqlash
3. Qurilmadagi APK pathni olish
4. Qurilmadagi APK SHA256
5. Local APK SHA256
6. MATCH/MISMATCH
7. `adb logcat -c`
8. App start
9. Register → Submit
10. Darhol `adb logcat` olish

Majburiy evidence:

DEVICE APK HASH
LOCAL APK HASH
MATCH/MISMATCH
EXCEPTION
FULL STACK TRACE
FILE
LINE
COLUMN
EXPRESSION

Agar haqiqiy stack trace olinmasa:

NOT VERIFIED

Hech qachon oldingi stack trace'ni yangi testning evidence sifatida ishlatma.

==================================================
6. SUPABASE AUTH FORENSIC AUDIT
==================================================

Real Supabase Cloud muhitini tekshir:

### Auth
- auth.users
- signup
- confirm email
- email provider
- rate limit
- redirect
- session
- refresh token
- auth state

### Triggerlar
- auth.users triggerlari
- handle_new_user()
- barcha duplicate triggerlar
- trigger order
- trigger function definition

### Profiles
- columns
- defaults
- NOT NULL
- FK
- CHECK
- UNIQUE
- RLS
- triggers
- anti-tampering functions

### Enum
- user_role
- barcha real enum qiymatlari

### Security
- SECURITY DEFINER
- search_path
- function ownership
- privileges

### Asosiy savol:

auth.users INSERT
→ handle_new_user()
→ profiles INSERT

real Cloud'da HAQIQATAN muvaffaqiyatli ishlayaptimi?

Agar yo‘q bo‘lsa, aynan qaysi SQL operation yiqilayotganini top.

==================================================
7. SUPABASE ERRORLARNI BIR-BIRIDAN AJRAT
==================================================

Quyidagilarni birlashtirma:

A. Database signup failure
B. PostgreSQL trigger failure
C. Email confirmation
D. Email rate limit 429
E. Client Null check
F. Navigation crash
G. Session/profile race condition

Har biri uchun alohida evidence ber.

==================================================
8. FULL PROJECT SECURITY AUDIT
==================================================

Quyidagilarni tekshir:

- Auth
- RBAC
- RLS
- IDOR
- privilege escalation
- anonymous privacy
- PII
- Storage
- RPC security
- SECURITY DEFINER
- secrets
- .env
- Git exposure
- payment state manipulation
- webhook security
- AI prompt injection
- AI hallucination control
- legal grounding
- data leakage

Har bir kritik muammoni:

P0 / P1 / P2 / P3

darajasida belgilagin.

==================================================
9. FULL PRODUCT / ARCHITECTURE AUDIT
==================================================

Quyidagilarni ham tekshir:

- Community
- Legal AI
- RAG
- Experts
- Citizen Services
- Document Generator
- Global Search
- Consultation
- Payment Engine
- Offline/cache
- error handling
- loading states
- empty states
- performance
- maintainability
- scalability
- accessibility
- UI consistency
- onboarding
- navigation

==================================================
10. UX/UI AUDIT
==================================================

Quyidagilarni tekshir:

- visual hierarchy
- typography
- colors
- spacing
- system status bar
- keyboard behavior
- loading
- empty
- error states
- responsive layout
- accessibility
- touch targets
- Android back navigation
- forms
- validation
- snackbar/dialog UX

Faqat real muammo bo‘lsa redesign taklif qil.

==================================================
11. PERFORMANCE AUDIT
==================================================

Aniq tekshir:

- startup time
- Supabase latency
- duplicate queries
- N+1
- debounce
- caching
- image loading
- document loading
- search latency
- unnecessary rebuilds
- large memory usage

"O‘ylashimcha sekin" demagin.

O‘lchov ber.

==================================================
12. BUSINESS / PRODUCT AUDIT
==================================================

LexHub mahsuloti quyidagi savollarga javob beradimi:

- Muammo aniqmi?
- Foydalanuvchi qiymati aniqmi?
- MVP haddan tashqari kattalashganmi?
- Keraksiz feature bormi?
- Monetizatsiya modeli mantiqiymi?
- Expert marketplace uchun trust mexanizmi yetarlimi?
- Legal responsibility / disclaimer masalalari bormi?
- Scale qilish xavflari bormi?

==================================================
13. FINAL REPORT
==================================================

Quyidagi formatda yoz:

# LEXHUB FORENSIC AUDIT

## 1. Executive Summary

## 2. REGISTER ROOT CAUSE

### Actual Exception
### Full Stack Trace
### Exact File
### Exact Line
### Exact Expression
### Why the Value Became Null
### Root Cause Layer
- Flutter
- BLoC
- Navigation
- Supabase Auth
- PostgreSQL
- RLS
- Trigger
- Configuration
- Rate Limit
- Environment
- Binary

### Evidence

## 3. SUPABASE AUTH FINDINGS

## 4. SECURITY FINDINGS

## 5. ARCHITECTURE FINDINGS

## 6. UI/UX FINDINGS

## 7. PERFORMANCE FINDINGS

## 8. BUSINESS FINDINGS

## 9. P0 / P1 / P2 / P3 TABLE

| ID | Severity | Muammo | Evidence | Ta'sir | Tavsiya |
|---|---|---|---|---|---|

## 10. MVP STATUS

Faqat bittasini tanla:

MVP READY
MVP READY WITH RISKS
NOT READY

"PRODUCTION READY" so‘zini faqat barcha critical runtime evidence mavjud bo‘lsa ishlat.

==================================================
14. ABSOLUTE NO-FALSE-SUCCESS RULE
==================================================

Hech qachon:

- taxminni fact deb yozma;
- unit testni production evidence deb yozma;
- static analysisni runtime evidence deb yozma;
- mockni real backend deb yozma;
- eski stack trace'ni yangi test evidence deb yozma;
- kod mavjudligini "fixed" deb yozma;
- migration mavjudligini "deployed" deb yozma.

Agar isbot bo‘lmasa:

NOT VERIFIED.

Agar biror narsani tekshira olmasang:

BLOCKED.

Agar qisman tekshirilsa:

PARTIALLY VERIFIED.

Hech qachon yolg‘on success berma.

==================================================
15. ISH REJIMI
==================================================

HOZIRCHA FAQAT AUDIT QIL.

KOD O‘ZGARTIRMA.

Avval barcha evidence va root-cause findingsni ber.

Men tasdiqlaganimdan keyin implementation bosqichiga o‘tamiz.

BOSHLANG.