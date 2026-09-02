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
-- Bularning HAMMASI mehmon (anon) uchun ishlaydi. Qatorni 0 ga tushirish
-- forum tasmasida muallif ismini BO'SH qoldiradi va `!inner` joinlarda
-- BUTUN qatorni yo'q qiladi. Shuning uchun bu migratsiya qatorni
-- "OMMAVIY tarzda ALLAQACHON ko'rinadigan" to'plamga QISQARTIRADI.
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
-- BU FAYL JONLI BAZAGA QO'LLANMAGAN (§0: NOT VERIFIED). Yuqoridagi natijalar
-- KUTILGAN natija, o'lchangan EMAS.
--
-- =============================================================================
-- QAYTARISH (ROLLBACK) — bir bloknoma, ma'lumot YO'QOLMAYDI
-- =============================================================================
-- BEGIN;
--   DROP POLICY IF EXISTS "Anon can view only publicly referenced profiles"
--       ON public.profiles;
--   DROP POLICY IF EXISTS "Authenticated users can view profiles"
--       ON public.profiles;
--   CREATE POLICY "Public profiles are viewable by everyone"
--       ON public.profiles FOR SELECT USING (true);
--   DROP FUNCTION IF EXISTS public.is_publicly_visible_profile(UUID);
-- COMMIT;
--
-- UNUTMANG: `answers.user_id` da INDEKS yo'q (o'lchandi — repo'da faqat
-- `idx_questions_user_id` bor). Foydalanuvchi soni o'sganda funksiya har
-- profil qatori uchun ishlaydi; o'sha paytda
-- `CREATE INDEX idx_answers_user_id ON public.answers(user_id);` kerak
-- bo'ladi. HOZIR (12 profil) o'lchanadigan ta'sir yo'q.
