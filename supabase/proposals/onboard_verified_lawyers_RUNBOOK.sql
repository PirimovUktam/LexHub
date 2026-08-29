-- =============================================================================
-- LEXHUB — TASDIQLANGAN ADVOKATLARNI RO'YXATGA KIRITISH: RUNBOOK
-- Sana: 2026-08-29
-- Ishga tushirish joyi: Supabase Studio -> SQL Editor (service_role huquqi)
-- Bu fayl `supabase/migrations/` ga QO'YILMAGAN — u AVTOMATIK ishga
-- tushmasligi kerak. Ma'lumot kiritish migratsiya EMAS.
-- =============================================================================
--
-- 1. O'LCHANGAN MUAMMO (2026-08-29, anon REST, `Prefer: count=exact`)
-- -----------------------------------------------------------------------------
--   GET /rest/v1/profiles?select=id                          -> content-range: 0-0/21
--   GET /rest/v1/profiles?role=in.(lawyer,verified_expert)    -> content-range: */0
--   GET /rest/v1/public_expert_profiles_view?select=expert_id -> content-range: */0
--
-- `profiles` SELECT policy `USING (true)` (20260826_bulletproof_auth_signup_
-- trigger.sql:69), ya'ni anon KO'RGAN 21 qator — BARCHA qator. Ularning
-- hech biri `lawyer`/`verified_expert` emas. `public_expert_profiles_view`
-- predikati (20260821_expert_verification_and_privacy.sql:118-140):
--     WHERE p.is_verified = TRUE
--       AND p.role::text IN ('verified_expert','lawyer')
-- Demak ro'yxatning BO'SHLIGI matematik jihatdan MAJBURIY. Bu RLS to'sig'i
-- EMAS — ma'lumot yo'q.
--
-- 2. ROOT CAUSE — NIMA UCHUN MA'LUMOT YO'Q
-- -----------------------------------------------------------------------------
-- Ariza berish yo'li ilovada BOR:
--   `apply_for_expert_verification()` <- `ApplyExpertDialog`
-- Tasdiqlash yo'li ilovada YO'Q:
--   `verify_expert_application()` — Dart kodida CHAQIRUVCHI YO'Q
--   (`grep -rn "verify_expert_application" lib/` -> nol moslik; faqat
--    `test/integration/real_supabase_expert_verification_flow_test.dart:182`
--    dagi XAVFSIZLIK testi chaqiradi).
--   Admin/moderator ekrani ham yo'q (`find lib -ipath "*admin*"` -> bo'sh).
--
-- Ya'ni advokat ariza bersa ham `verified_at` MANGU `NULL` qoladi, `profiles
-- .role` `citizen` bo'lib turadi va u view'ga TUSHMAYDI. Ro'yxatni "seed"
-- qilish bu bo'g'inni tuzatmaydi — u faqat bir martalik qo'l ishi bo'ladi.
--
-- 3. NIMA UCHUN BU FAYLDA SOXTA ADVOKAT YO'Q
-- -----------------------------------------------------------------------------
-- Ekranda yozilgan da'vo: "Rasmiy Litsenziyaga Ega Advokatlar — Barcha
-- mutaxassislar O'zbekiston Advokatlar palatasi ro'yxatidan tekshirilgan".
-- O'ylab topilgan ism/litsenziya/telefon bu da'voni YOLG'ONGA aylantiradi va
-- foydalanuvchi mavjud bo'lmagan advokatga qo'ng'iroq qiladi. Shuning uchun
-- quyidagi bloklar PLACEHOLDER bilan keladi va to'ldirilmasa SQL xatosi
-- beradi (jim o'tmaydi).
-- =============================================================================


-- =============================================================================
-- VARIANT A — TAVSIYA ETILADI: ARIZA BERGAN ADVOKATNI TASDIQLASH
-- Ma'lumotni advokatning O'ZI kiritadi, admin faqat litsenziyani tekshiradi.
-- =============================================================================

-- A.1. Kutayotgan arizalar (verified_at IS NULL). Bo'sh natija = hech kim
--      ariza bermagan; u holda VARIANT B ga o'ting.
--      DIQQAT: email `public.profiles` da YO'Q (`20260819_base_schema.sql`
--      dagi CREATE TABLE da bunday ustun yo'q) — u FAQAT `auth.users` da
--      turadi, shuning uchun bu so'rov service_role huquqini talab qiladi.
SELECT
    ep.user_id,
    p.full_name,
    u.email,
    ep.license_number,
    ep.specialization,
    ep.workplace,
    ep.experience_years,
    ep.license_document_url,
    ep.created_at
FROM public.expert_profiles ep
JOIN public.profiles p ON p.id = ep.user_id
JOIN auth.users u ON u.id = ep.user_id
WHERE ep.verified_at IS NULL
ORDER BY ep.created_at;

-- A.2. LITSENZIYANI TEKSHIRING (advokatlar palatasi ro'yxati bo'yicha).
--      Tekshirilmagan arizani TASDIQLAMANG.

-- A.3. Tasdiqlash. `<USER_ID>` ni A.1 natijasidan ko'chiring.
--      Funksiya `profiles.role = 'verified_expert'`, `is_verified = TRUE` va
--      `expert_profiles.verified_at = now()` ni BIR TRANZAKSIYADA qo'yadi.
-- SELECT public.verify_expert_application('<USER_ID>'::uuid, TRUE);

-- A.4. Rad etish (litsenziya tasdiqlanmasa):
-- SELECT public.verify_expert_application('<USER_ID>'::uuid, FALSE);


-- =============================================================================
-- VARIANT B — BOOTSTRAP: ADVOKATNI NOLDAN QO'SHISH
-- Faqat ro'yxat butunlay bo'sh bo'lgan boshlang'ich holat uchun. Har bir
-- advokatdan YOZMA ROZILIK va litsenziya nusxasi olinishi SHART (PII).
-- =============================================================================

-- B.1. HISOB YARATISH — SQL BILAN QILINMAYDI.
--      `profiles.id` -> `auth.users(id)` FK, va `auth.users` ga qo'lda INSERT
--      parol hash / `email_confirmed_at` / `aud` / `role` maydonlarini
--      buzadi. To'g'ri yo'l — IKKISIDAN BIRI:
--
--      (a) Studio -> Authentication -> Users -> "Add user"
--          (email + parol, "Auto Confirm User" yoqilgan holda), yoki
--      (b) Admin API:
--          curl -X POST "https://<PROJECT_REF>.supabase.co/auth/v1/admin/users" \
--            -H "apikey: <SERVICE_ROLE_KEY>" \
--            -H "Authorization: Bearer <SERVICE_ROLE_KEY>" \
--            -H "Content-Type: application/json" \
--            -d '{"email":"<EMAIL>","password":"<PAROL>",
--                 "email_confirm":true,
--                 "user_metadata":{"full_name":"<F.I.SH.>"}}'
--
--      `handle_new_user()` trigger'i `profiles` qatorini O'ZI yaratadi
--      (20260826_bulletproof_auth_signup_trigger.sql). Qo'lda INSERT
--      QILMANG — trigger bilan konflikt beradi.

-- B.2. Yaratilgan hisoblarni topish (B.1 dan keyin). Email `auth.users` da
--      (A.1 dagi izohga qara).
SELECT p.id, u.email, p.full_name, p.role, p.is_verified
FROM public.profiles p
JOIN auth.users u ON u.id = p.id
WHERE u.email = ANY (ARRAY[
    -- '<EMAIL_1>',
    -- '<EMAIL_2>'
]::text[])
ORDER BY p.created_at;

-- B.3. Advokat kartasini to'ldirish. HAR BIR QIYMAT HAQIQIY bo'lishi SHART.
--      `workplace` ichida HUDUD NOMI bo'lsin ("Toshkent shahar advokatlar
--      hay'ati") — hudud filtri `UzbekRegions.regionOf()` orqali AYNAN shu
--      matndan o'qiladi (`city` ustuni bazada YO'Q).
--      `specialization` qiymati `LawyerSpecializationMatcher` chiplariga mos
--      kelsin: Mehnat / Oila / Jinoyat / Yo'l harakati / Iste'molchi /
--      Soliq / Biznes — aks holda AI eskalatsiyasi bu advokatni topmaydi.
/*
INSERT INTO public.expert_profiles (
    user_id, license_number, specialization, experience_years,
    education, workplace, consultation_fee, is_available_for_booking
)
VALUES
    ('<USER_ID_1>'::uuid, '<LITSENZIYA_RAQAMI>', '<IXTISOSLIK>',
     <TAJRIBA_YIL>, '<TA_LIM>', '<ISH_JOYI_HUDUD_BILAN>',
     <NARX_UZS>, TRUE)
ON CONFLICT (user_id) DO UPDATE SET
    license_number   = EXCLUDED.license_number,
    specialization   = EXCLUDED.specialization,
    experience_years = EXCLUDED.experience_years,
    education        = EXCLUDED.education,
    workplace        = EXCLUDED.workplace,
    consultation_fee = EXCLUDED.consultation_fee,
    updated_at       = now();
*/

-- B.4. Tasdiqlash — VARIANT A.3 dagi AYNI funksiya:
-- SELECT public.verify_expert_application('<USER_ID_1>'::uuid, TRUE);


-- =============================================================================
-- TEKSHIRISH — ilovada ko'rinadigan AYNI manba
-- =============================================================================

-- DIQQAT — VIEW USTUNLARI va MIGRATSIYA TARTIBI: `license_number` ochiq
-- view'ga FAQAT `20260829_expert_license_visibility_and_lock.sql`
-- QO'LLANGANDAN keyin tushadi (T-1 tuzatishi). Undan OLDIN quyidagi C.1
-- `column "license_number" does not exist` xatosi beradi — u holda ustunni
-- so'rovdan olib tashlab, C.2 dagi `expert_profiles` JOIN'idan foydalaning.
-- `license_document_url` esa HAR QANDAY holatda view'da YO'Q (PII).

-- C.1. View qatorlari (ilova AYNAN shu view'ni o'qiydi):
SELECT expert_id, full_name, specialization, workplace,
       experience_years, rating, reviews_count, is_profile_verified,
       verified_at, license_number
FROM public.public_expert_profiles_view
ORDER BY full_name;

-- C.2. HALOLLIK NAZORATI: bo'sh yoki ishonchsiz maydonlar. Har bir qator
--      ilovada "ko'rsatilmagan" deb chiqadi — bu nuqson, tuzatilishi kerak.
--      `license_number` ATAYLAB `expert_profiles` dan o'qiladi: bu so'rov
--      T-1 migratsiyasi qo'llanmagan bazada HAM ishlaydi. Buning uchun
--      service_role huquqi kerak (base jadval RLS: owner yoki admin).
SELECT v.expert_id, v.full_name,
       (ep.license_number IS NULL OR btrim(ep.license_number) = '')
           AS litsenziya_bosh,
       (v.workplace IS NULL OR btrim(v.workplace) = '') AS ish_joyi_bosh,
       (v.specialization IS NULL OR btrim(v.specialization) = '')
           AS ixtisoslik_bosh
FROM public.public_expert_profiles_view v
JOIN public.expert_profiles ep ON ep.id = v.expert_id
WHERE ep.license_number IS NULL OR btrim(ep.license_number) = ''
   OR v.workplace IS NULL OR btrim(v.workplace) = ''
   OR v.specialization IS NULL OR btrim(v.specialization) = '';

-- C.3. HUDUD FILTRI ishlashini tekshirish (ilova AYNI `ilike` ni yuboradi):
SELECT full_name, workplace
FROM public.public_expert_profiles_view
WHERE workplace ILIKE '%Toshkent%';

-- C.4. Anon ko'rinish (RLS): quyidagi so'rov brauzerdan anon kalit bilan
--      ishlatilsa AYNI natijani berishi kerak. Farq bo'lsa — view yoki
--      GRANT buzilgan.
--      GET /rest/v1/public_expert_profiles_view?select=expert_id,full_name


-- =============================================================================
-- QAYTARISH (rollback)
-- =============================================================================
-- Advokatni ro'yxatdan CHIQARISH (hisob o'chirilmaydi):
-- SELECT public.verify_expert_application('<USER_ID>'::uuid, FALSE);
-- UPDATE public.profiles SET role = 'citizen', is_verified = FALSE
--  WHERE id = '<USER_ID>'::uuid;
--
-- DIQQAT: `expert_profiles` qatorini DELETE qilish arizani ham yo'q qiladi.
-- Vaqtinchalik yashirish uchun `is_available_for_booking = FALSE` yetarli.


-- =============================================================================
-- OCHIQ QOLGAN P0 — BU FAYL TUZATMAYDI
-- =============================================================================
-- Ilovada admin/moderator uchun TASDIQLASH EKRANI yo'q. Ya'ni bu runbook
-- har bir yangi advokat uchun QO'LDA SQL talab qiladi va mahsulot o'z-o'zidan
-- o'sa olmaydi. Kerakli minimal ish:
--   1. `LegalExpertsRemoteDataSource` ga `getPendingApplications()` +
--      `verifyExpertApplication(userId, approve)` (RPC `verify_expert_
--      application` allaqachon MAVJUD va `is_admin_or_moderator()` bilan
--      himoyalangan — server tomonda yangi hech narsa kerak emas).
--   2. `profiles.role IN ('admin','moderator')` bo'lganda ko'rinadigan
--      ekran + tasdiqlash/rad etish tugmasi.
--   3. Litsenziya hujjatini ochish (`license_document_url`).
-- Xavfsizlik chegarasi SERVER tomonda allaqachon qulflangan, ya'ni bu ish
-- FAQAT presentation + data qatlami.
--
--
-- QO'SHIMCHA TOPILMALAR (o'lchangan) — TUZATISH YOZILGAN, QO'LLANMAGAN
-- -----------------------------------------------------------------------------
-- T-1 va T-2 uchun tuzatish `supabase/migrations/20260829_expert_license_
-- visibility_and_lock.sql` da. DIQQAT: fayl mavjudligi "qo'llangan" DEGANI
-- EMAS — `supabase db push` bajarilmagan.
--
-- T-1 (SHOULD FIX → TUZATISH YOZILGAN). Litsenziya raqami ilovada
--   KO'RINMAYDI. `public_expert_profiles_view` SELECT ro'yxatida
--   `license_number` YO'Q edi (`20260821_...sql:118-140`), ya'ni
--   `LegalExpertModel.licenseNumber` DOIM `''`. Ekrandagi "Rasmiy
--   Litsenziyaga Ega Advokatlar … Advokatlar palatasi ro'yxatidan
--   tekshirilgan" da'vosini foydalanuvchi TEKSHIRA OLMAYDI.
--   Yaxshi tomoni: bo'sh qiymat UI'da soxta raqam bilan TO'LDIRILMAYDI
--   (`legal_expert_model.dart` §6 qulfi), ya'ni yolg'on ma'lumot yo'q —
--   faqat da'vo isbotsiz qoladi.
--   Tuzatish: view'ga `ep.license_number` OXIRGI ustun sifatida qo'shildi
--   (`CREATE OR REPLACE VIEW` faqat oxiriga qo'shishga ruxsat beradi);
--   `license_document_url` PII bo'lib QOLDI.
--
-- T-2 (SHOULD FIX → TUZATISH YOZILGAN, IKKI YO'L). Tasdiqlangandan KEYIN
--   litsenziya raqamini almashtirish mumkin edi:
--     Yo'l 1 (RPC): `apply_for_expert_verification()` ON CONFLICT bloki
--       `license_number = EXCLUDED.license_number` yozardi
--       (`20260821_...sql:216`) va `verified_at` SAQLANARDI.
--     Yo'l 2 (to'g'ridan-to'g'ri UPDATE): `"Experts can update their profile"`
--       policy'si `FOR UPDATE USING (auth.uid() = user_id)` (`:161-162`), va
--       `protect_expert_profile_sensitive_fields()` faqat `rating`,
--       `reviews_count`, `verified_at`, `user_id` ni qulflardi (`:86-104`).
--   MUHIM: Yo'l 1 ni trigger gvardi TUTMAYDI — funksiya SECURITY DEFINER,
--   uning ichida `current_user` = funksiya EGASI (`postgres`), ya'ni gvard
--   sharti bajarilmaydi. Shu sababli IKKI joyda tuzatildi: gvardga
--   `OLD.verified_at IS NOT NULL` shartli qulf + RPC ON CONFLICT da
--   `CASE WHEN expert_profiles.verified_at IS NULL`.
--   Tasdiqlanmagan ariza TAHRIRLANADIGAN bo'lib qoldi (xato raqamni tuzatish
--   uchun) — qulf faqat tasdiq momentidan keyin yopiladi.
--
-- T-2 qo'llanganini tekshirish runtime so'rovlari migratsiya faylining
-- §4.3-4.4 bo'limida. Ular BAJARILMAGUNCHA T-2 holati: NOT VERIFIED.

