-- =============================================================================
-- LEXHUB — `profiles` UCHUN ANON QATOR KO'RINISHINI CHEKLASH
-- Sana: 2026-09-03
-- Ishga tushirish: Supabase Dashboard -> SQL Editor -> BUTUN faylni RUN
-- =============================================================================
-- O'LCHANGAN NUQSON (2026-09-02, JONLI production bazada, vositalar:
-- `tool/anon_privilege_probe_precise.py`). Release artefaktidan chiqarib
-- olinadigan `anon` kalit bilan (u web bundle'da OCHIQ matn — o'lchandi):
--
--   so'rov                                          natija
--   /rest/v1/profiles?select=id,role,full_name       12 qator (HAMMASI)
--   /rest/v1/profiles?select=role                    {citizen: 11, admin: 1}
--   /rest/v1/profiles?role=eq.admin&select=id        1 qator -> ADMIN ANIQLANDI
--   /rest/v1/profiles?full_name=ilike.*a*            7 qator -> ISM QIDIRUVI
--
-- Ya'ni ustun-darajali GRANT (`20260829120000`) `phone`/`bio`/`license_number`
-- ni to'g'ri yopgan, lekin QATOR filtri YO'Q edi: SELECT policy
-- `USING (true)` (`20260826010000:128`). Oqibat: (a) butun foydalanuvchi
-- ro'yxati, (b) YAGONA administratorni bitta so'rov bilan ajratish —
-- maqsadli hujum uchun tayyor nishon. Huquqiy yordam ilovasida "kim
-- foydalanadi" ning o'zi maxfiy ma'lumot.
--
-- NIMA UCHUN "faqat O'Z QATORI" YECHIMI EMAS (O'LCHANGAN CHEKLOV):
-- `anon` da `auth.uid()` YO'Q, ya'ni "o'z qatori" = 0 qator. PostgREST
-- embedded resource (`profiles(...)`) BAZA jadvaliga tayanadi va uni VIEW'ga
-- yo'naltirib bo'lmaydi. Repo'da shunday 8 joy bor (o'lchandi):
--   community_forum_remote_datasource.dart:227,250,358,380,575,678
--     -> `select('*, profiles(full_name, role, is_verified, avatar_url)')`
--   consultation_remote_datasource.dart:244,246 -> `profiles!...(full_name)`
--   legal_experts_remote_datasource.dart:280    -> `profiles!inner(full_name)`
-- Qatorni 0 ga tushirish forum tasmasida muallif ismini BO'SH qoldiradi va
-- `!inner` joinlarda BUTUN qatorni yo'q qiladi. Shuning uchun bu migratsiya
-- qatorni "OMMAVIY tarzda ALLAQACHON ko'rinadigan" to'plamga QISQARTIRADI.
--
-- TUZATISH — OLDINGI DA'VO NOTO'G'RI EDI (o'lchandi 2026-09-03,
-- `tool/anon_profile_row_visibility_probe.py`, anon kalit): bu 8 join
-- HOZIR mehmon uchun ISHLAMAYDI, chunki OTA jadvallar `anon` ga YOPIQ:
--
--   so'rov (anon)                                    natija
--   /rest/v1/questions?select=id                     0 qator
--   /rest/v1/answers?select=id                       0 qator
--   /rest/v1/expert_profiles?select=id               0 qator
--   questions + profiles(...) embedded join          0 qator
--   /rest/v1/public_questions_view?select=id         1 qator  <- MEHMON YO'LI
--
-- KATALOG (rol `postgres`) 0 ning MA'NOSINI ajratdi: `questions` da JAMI 1
-- qator bor va u ANONIM (`is_anonymous=false` -> 0), ya'ni anon ko'rgan 0 —
-- RLS FILTRI. `answers` va `expert_profiles` da esa JAMI 0 qator — ya'ni
-- BO'SHLIK. Mehmon tasmasi `public_questions_view` orqali ishlaydi: u
-- `security_invoker` EMAS (`pg_class.reloptions = (none)`, egasi `postgres`),
-- shuning uchun baza RLS'ini AYLANIB O'TADI va ismni `author_name` ustunida
-- O'ZI beradi — `profiles` join'iga TAYANMAYDI.
--
-- DEMAK: (a) `anon` uchun bu migratsiya BUGUN regressiya kiritishi MUMKIN
-- EMAS — u 0 qatorni 0 qatorga aylantiradi; (b) 8 join REGRESSIYA xavfi
-- FAQAT `authenticated` uchun real, shuning uchun pastda o'sha rol uchun
-- `USING (true)` ATAYLAB saqlanadi; (c) predikatli policy "hech qanday
-- policy yo'q" variantidan afzal, chunki kelajakda `questions` mehmonga
-- ochilsa join JIMGINA bo'sh qolmaydi.
--
-- HALOL QOLDIQ (§0): predikatning "TRUE" tarmog'i JONLI ma'lumotda
-- SINALMAGAN — bugun production'da birorta ommaviy (non-anonim) savol,
-- javob yoki tasdiqlangan mutaxassis YO'Q (o'lchandi: 0/0/0). Ya'ni
-- qo'llagandan keyin `anon` KO'RADIGAN profil soni 0 bo'lishi kutiladi va
-- "haqiqiy ommaviy profil ko'rinishda qoladi" degan tomon NOT VERIFIED
-- bo'lib qoladi. Birinchi ommaviy savol paydo bo'lganda probe QAYTA
-- yurgiziladi.
--
-- JONLI POLICY HOLATI — QO'LLASHDAN OLDIN O'LCHANDI (2026-09-02T19:34:09Z,
-- `pg_policies`, rol `postgres`; nusxa: `.runtime_evidence/
-- before_anon_hardening.out.json`). `profiles` da TO'RT policy topildi:
--
--   cmd     roles     nomi                                       qual
--   SELECT  {public}  Foydalanuvchilar o'z profilini ko'ra oladi  ((auth.uid() = id) OR true)
--   SELECT  {public}  Public profiles are viewable by everyone    true
--   UPDATE  {public}  Foydalanuvchilar o'z profilini o'zgartira oladi  (auth.uid() = id)
--   UPDATE  {public}  Users can update own profile               (auth.uid() = id)
--
-- IKKINCHI SELECT POLICY — ENG MUHIM TOPILMA. `((auth.uid() = id) OR true)`
-- nomi "o'z profilini ko'ra oladi" deb tursa ham, `OR true` sababli HAR
-- QANDAY qator uchun TRUE. PostgreSQL'da PERMISSIVE policy'lar `OR` bilan
-- birlashadi, ya'ni bu policy JOYIDA QOLSA yangi `anon` policy'si HECH
-- NARSANI cheklamaydi — migratsiya SOXTA tuzatishga aylanadi. Shuning uchun
-- pastda IKKALASI ham tashlanadi.
--
-- IKKI UPDATE policy'siga TEGILMAYDI: ikkisi ham `auth.uid() = id`, ya'ni
-- o'z qatori. `anon` da `auth.uid()` NULL -> shart FALSE. Takroriy, lekin
-- ZARARSIZ va bu migratsiya doirasidan TASHQARIDA (§16).
--
-- SXEMA BO'YICHA TEKSHIRILDI: `OR true` naqshi butun `public` sxemada FAQAT
-- `profiles` da (o'lchandi — qolgan `qual=true` policy'lar `answers`,
-- `categories`, `citizen_services`, `document_templates`,
-- `law_article_chunks`, `official_sources`, `service_steps` da, ular ATAYLAB
-- ommaviy kontent). `answers` da esa ikki TAKRORIY `true` SELECT policy bor —
-- xabar qilinadi, TEGILMAYDI (§16).
--
-- `{public}` ROLDAN ROL-BO'YICHA AJRATISH REGRESSIYA BERMAYDI — O'LCHANDI
-- (`pg_roles`): `service_role` `bypassrls=true`, `postgres` `bypassrls=true`,
-- `supabase_admin` `bypassrls=true`, `profiles` egasi `postgres` va
-- `force_rls=false`. Ya'ni server tomoni RLS'ga BO'YSUNMAYDI va policy
-- yo'qolishi unga ta'sir qilmaydi. `supabase_auth_admin` da `bypassrls=false`,
-- lekin u `profiles` ga FAQAT `handle_new_user()` orqali tegadi — u
-- `SECURITY DEFINER`, egasi `postgres`, `search_path` qotirilgan (o'lchandi:
-- `pg_proc.prosecdef=true`), demak RLS'ni aylanib o'tadi. Repo'da
-- `custom_access_token` auth hook'i YO'Q (grep).
--
-- `authenticated` uchun xulq O'ZGARMAYDI (`USING (true)`) — bu migratsiya
-- REGRESSIYA kiritmaydi. Autentifikatsiyalangan foydalanuvchi boshqalarning
-- `phone`/`bio`/`license_number` ini o'qiy olishi AYRIM masala bo'lib
-- QOLADI (`20260829120000` da yozilgan ochiq muammo) — u ustun-darajali
-- GRANT yoki view bilan alohida yopiladi, chunki bu yerda tuzatish
-- yuqoridagi 8 joyni birdan buzardi.
--
-- QAYTARISH (rollback) fayl oxirida.
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1) YORDAMCHI FUNKSIYA — profil OMMAVIY tarzda ko'rinadimi?
-- -----------------------------------------------------------------------------
-- `SECURITY DEFINER` ATAYLAB: funksiya ichidagi `questions`/`answers`/
-- `expert_profiles` o'qishlari RLS'ni AYLANIB O'TADI. Sabab — RLS policy
-- ichidan boshqa RLS'li jadvalni o'qish (a) rekursiya xavfi tug'diradi,
-- (b) natijani chaqiruvchi roliga bog'lab NOANIQ qiladi. Funksiya FAQAT
-- `boolean` qaytaradi — hech qanday qator mazmuni chiqmaydi.
--
-- `search_path` QOTIRILGAN (loyiha talabi): aks holda `SECURITY DEFINER`
-- funksiyani sxema o'g'irlash (search_path hijacking) bilan aldash mumkin.
CREATE OR REPLACE FUNCTION public.is_publicly_visible_profile(p_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT EXISTS (
        -- ANONIM BO'LMAGAN savol muallifi: ismi tasmada allaqachon ko'rinadi.
        SELECT 1 FROM public.questions q
        WHERE q.user_id = p_id AND q.is_anonymous = FALSE
    ) OR EXISTS (
        -- Javob muallifi: javob OMMAVIY kontent (savol anonim bo'lsa ham
        -- yashiriladigan tomon SO'RAGAN odam, javob bergan emas).
        SELECT 1 FROM public.answers a WHERE a.user_id = p_id
    ) OR EXISTS (
        -- TASDIQLANGAN mutaxassis: `expert_profiles` ning o'zi ham mehmonga
        -- faqat tasdiqlanganini ko'rsatadi (`20260821010000`).
        SELECT 1 FROM public.expert_profiles ep
        WHERE ep.user_id = p_id AND ep.verified_at IS NOT NULL
    );
$$;

COMMENT ON FUNCTION public.is_publicly_visible_profile(UUID) IS
    'Profil ommaviy kontent orqali allaqachon ko''rinadimi. `profiles` '
    'SELECT policy''sida `anon` uchun ishlatiladi. FAQAT boolean qaytaradi.';

-- Policy ifodasi CHAQIRUVCHI roli huquqi bilan bajariladi — shuning uchun
-- `anon` da EXECUTE bo'lishi SHART, aks holda mehmon so'rovi `42501` beradi.
GRANT EXECUTE ON FUNCTION public.is_publicly_visible_profile(UUID)
    TO anon, authenticated;

-- -----------------------------------------------------------------------------
-- 2) SELECT POLICY'NI ROL BO'YICHA AJRATISH
-- -----------------------------------------------------------------------------
-- Eski policy `USING (true)` — HAR QANDAY rolga HAMMA qatorni berardi.
DROP POLICY IF EXISTS "Public profiles are viewable by everyone"
    ON public.profiles;

-- IKKINCHI CHEKLOVSIZ POLICY — nomi aldamchi, `qual` esa
-- `((auth.uid() = id) OR true)`, ya'ni AMALDA `true` (yuqoridagi o'lchov
-- jadvaliga qara). PERMISSIVE policy'lar `OR` bilan qo'shilgani uchun bu
-- QOLSA pastdagi `anon` cheklovi KUCHGA KIRMAYDI.
DROP POLICY IF EXISTS "Foydalanuvchilar o'z profilini ko'ra oladi"
    ON public.profiles;

-- `authenticated`: XULQ O'ZGARMADI (regressiya yo'q).
DROP POLICY IF EXISTS "Authenticated users can view profiles"
    ON public.profiles;
CREATE POLICY "Authenticated users can view profiles"
    ON public.profiles FOR SELECT TO authenticated
    USING (true);

-- `anon`: FAQAT ommaviy kontent orqali allaqachon ko'rinadigan profillar.
-- Administrator/moderator ommaviy savol yoki javob yozmagan bo'lsa —
-- mehmon uchun MUTLAQO KO'RINMAS bo'ladi, ya'ni `role=eq.admin` 0 qator.
DROP POLICY IF EXISTS "Anon can view only publicly referenced profiles"
    ON public.profiles;
CREATE POLICY "Anon can view only publicly referenced profiles"
    ON public.profiles FOR SELECT TO anon
    USING (public.is_publicly_visible_profile(id));

COMMIT;

-- =============================================================================
-- QO'LLAGANDAN KEYIN TEKSHIRISH (anon kalit bilan, `tool/` dagi probe)
-- =============================================================================
--   python tool/anon_privilege_probe_precise.py   # regressiya bo'lmasin
--
--   # Enumeratsiya YOPILGANIGA ishonch (hammasi 0 bo'lishi kutiladi, agar
--   # admin ommaviy post yozmagan bo'lsa):
--   curl -s "$URL/rest/v1/profiles?role=eq.admin&select=id" -H "apikey: $ANON"
--   curl -s "$URL/rest/v1/profiles?full_name=ilike.*a*&select=id" -H ...
--
--   # REGRESSIYA sinovi — mehmon tasmasi muallif ismini KO'RISHI kerak:
--   curl -s "$URL/rest/v1/questions?is_anonymous=eq.false\
-- &select=id,profiles(full_name,role,is_verified,avatar_url)" -H "apikey: $ANON"
--
-- =============================================================================
-- QO'LLANDI — JONLI PRODUCTION BAZASIDA O'LCHANGAN NATIJA
-- =============================================================================
-- QO'LLASH: `supabase db query --linked -f <shu fayl>`, rol `postgres`
-- (o'lchandi: `current_user`). Aniq vaqt IKKI katalog o'lchovi ORASIDA:
--   OLDIN — `.runtime_evidence/before_anon_hardening.out.json` (19:34:09Z)
--   KEYIN — `.runtime_evidence/after_anon_hardening.out.json`  (19:54:04Z)
-- Sana: 2026-09-02 (UTC).
--
-- 1) KATALOG (rol `postgres`, `pg_policies`) — `profiles` policy'lari KEYIN:
--      SELECT {anon}          Anon can view only publicly referenced profiles
--                             qual = is_publicly_visible_profile(id)
--      SELECT {authenticated} Authenticated users can view profiles
--                             qual = true
--      UPDATE {public}        (ikkitasi, TEGILMADI) qual = (auth.uid() = id)
--    Ikki CHEKLOVSIZ SELECT policy YO'Q — `helper_fn_count` 0 -> 1.
--
-- 2) ANON KALIT BILAN (vosita: `tool/anon_profile_row_visibility_probe.py`,
--    nusxalar: `.runtime_evidence/anon_profile_visibility_BEFORE.txt` va
--    `.runtime_evidence/anon_profile_visibility_AFTER_mig1.txt`)
--    — ENUMERATSIYA YOPILDI:
--
--      so'rov                                   OLDIN   KEYIN
--      profiles?select=id                       12      0
--      profiles?role=eq.admin&select=id          1      0   <- ADMIN YASHIRINDI
--      profiles?role=eq.moderator&select=id      0      0
--      profiles?full_name=ilike.*a*&select=id    7      0   <- ISM QIDIRUVI O'LDI
--
--    REGRESSIYA YO'Q (o'sha yurishda, o'zgarmagan qiymatlar):
--      public_questions_view?select=id           1      1   <- MEHMON TASMASI
--      questions?select=id                       0      0
--      question_categories?select=id             0      0
--      questions + profiles(...) embedded join   0      0
--      IJOBIY NAZORAT profiles?select=phone   42501  42501
--
-- 3) `tool/anon_privilege_probe_precise.py` QAYTA yurgizildi (nusxa:
--    `.runtime_evidence/anon_precise_AFTER.txt`) — anonim savol himoyasi
--    O'ZGARMADI: `user_id NOT NULL` 0, `author_name != 'Anonim fuqaro'` 0,
--    `is_admin_or_moderator` -> false, `global_search` -> 5 qator.
--
-- HALOL QOLDIQLAR (§0) — BU FAYL HAMMA NARSANI ISBOTLAMAYDI:
--   * `authenticated` YO'LI HTTP orqali SINALMAGAN (BLOCKED): repo'da test
--     foydalanuvchi paroli/JWT YO'Q. Isbot faqat KATALOG darajasida —
--     policy `{authenticated}` uchun `USING (true)` (yuqorida ko'rinadi),
--     ya'ni ilgarigi xulq AYNAN saqlangan.
--   * Predikatning "TRUE" tarmog'i JONLI ma'lumotda SINALMAGAN
--     (NOT VERIFIED): production'da non-anonim savol 0, javob 0,
--     tasdiqlangan mutaxassis 0 (o'lchandi, rol `postgres`). Shuning uchun
--     "KEYIN = 0" natijasi predikat TO'G'RI ishlaganini ham, "hech nima
--     mos kelmadi" ni ham bildiradi — ikkisi HOZIR ajratilmaydi. Birinchi
--     ommaviy savol paydo bo'lganda probe QAYTA yurgiziladi.
--
-- =============================================================================
-- QAYTARISH (ROLLBACK) — bir bloknoma, ma'lumot YO'QOLMAYDI
-- =============================================================================
-- BEGIN;
--   DROP POLICY IF EXISTS "Anon can view only publicly referenced profiles"
--       ON public.profiles;
--   DROP POLICY IF EXISTS "Authenticated users can view profiles"
--       ON public.profiles;
--   -- AYNAN o'lchangan asl holat (`.runtime_evidence/
--   -- before_anon_hardening.out.json`): IKKI policy, ikkisi ham `{public}`.
--   CREATE POLICY "Public profiles are viewable by everyone"
--       ON public.profiles FOR SELECT USING (true);
--   CREATE POLICY "Foydalanuvchilar o'z profilini ko'ra oladi"
--       ON public.profiles FOR SELECT USING ((auth.uid() = id) OR true);
--   DROP FUNCTION IF EXISTS public.is_publicly_visible_profile(UUID);
-- COMMIT;
--
-- UNUTMANG: `answers.user_id` da INDEKS yo'q (o'lchandi — repo'da faqat
-- `idx_questions_user_id` bor). Foydalanuvchi soni o'sganda funksiya har
-- profil qatori uchun ishlaydi; o'sha paytda
-- `CREATE INDEX idx_answers_user_id ON public.answers(user_id);` kerak
-- bo'ladi. HOZIR (12 profil) o'lchanadigan ta'sir yo'q.
