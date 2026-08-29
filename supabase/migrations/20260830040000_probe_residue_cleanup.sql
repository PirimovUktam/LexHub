-- LEXHUB — GVARD PROBE'INING QOLDIQ MA'LUMOTINI TOZALASH
--
-- NIMA UCHUN BU FAYL BOR (CLAUDE.md §0 + foydalanuvchi talabi "ilovaga soxta
-- advokat qo'shib tashlama"):
-- `20260830020000` va `20260830030000` migratsiyalari gvard trigger'ining
-- KLIENT `UPDATE` ini rad etishini TEKSHIRA OLMADI — migratsiya sessiyasida
-- `session_user = postgres`, ya'ni `is_privileged_db_role()` TRUE va gvard
-- ATAYLAB o'tkazib yuboradi; `SET SESSION AUTHORIZATION` esa 42501 beradi.
-- Shuning uchun o'lchov HAQIQIY JWT bilan, HAQIQIY PostgREST `PATCH` orqali
-- bajarildi (`tool/probe_expert_guard.py`). Probe:
--   signUp -> `apply_for_expert_verification` -> 6 ta buzish urinishi ->
--   nazorat `PATCH` -> `withdraw_expert_application` -> qator YO'Q.
-- Natija shu faylning oxirida (VERBATIM chiqish).
--
-- Probe `expert_profiles` qatorini O'ZI o'chirdi (`withdraw` RPC). LEKIN
-- `auth.users` va `profiles` qatorlari QOLDI: klient uchun o'z akkauntini
-- o'chirish yo'li YO'Q va `anon`/`authenticated` `auth.users` ga tegolmaydi.
-- Ularni faqat migratsiya kanali (`postgres`) o'chira oladi — shu fayl.
--
-- DOIRA QAT'IY CHEGARALANGAN: faqat `guardprobe-%@lexhub.invalid` va
-- `assert-%@lexhub.invalid` naqshlari. `.invalid` — RFC 2606 bo'yicha HECH
-- QACHON haqiqiy bo'lmaydigan TLD, ya'ni bu naqsh HAQIQIY foydalanuvchini
-- ushlab qolishi MUMKIN EMAS.
--
-- IDEMPOTENT: qayta ijro etilganda hech narsa topmaydi va yiqilmaydi.

BEGIN;

DO $cleanup$
DECLARE
    v_users    INTEGER;
    v_profiles INTEGER;
    v_experts  INTEGER;
BEGIN
    -- `auth.users` -> `profiles` (`ON DELETE CASCADE`,
    -- `20260819_base_schema.sql:69`) -> `expert_profiles`
    -- (`ON DELETE CASCADE`, `20260819_base_schema.sql:94`).
    -- Ya'ni bitta DELETE butun zanjirni tozalaydi.
    DELETE FROM auth.users
     WHERE email LIKE 'guardprobe-%@lexhub.invalid'
        OR email LIKE 'assert-%@lexhub.invalid';
    GET DIAGNOSTICS v_users = ROW_COUNT;
    RAISE NOTICE 'LEXHUB_CLEANUP: auth.users dan % qator o''chirildi', v_users;

    -- Litsenziya naqshi bo'yicha YETIM qator qolmaganini ham tekshiramiz
    -- (agar CASCADE biror sababdan ishlamasa, shu yerda ushlanadi).
    SELECT count(*) INTO v_experts FROM public.expert_profiles
     WHERE license_number LIKE 'LX-PROBE-%'
        OR license_number LIKE 'LX-ASSERT-%'
        OR specialization LIKE 'PROBE %'
        OR specialization LIKE 'ASSERT %';
    IF v_experts > 0 THEN
        RAISE EXCEPTION
            'CLEANUP FAILED: % ta probe `expert_profiles` qatori QOLDI '
            '(CASCADE ishlamadi?)', v_experts;
    END IF;

    SELECT count(*) INTO v_profiles FROM public.profiles
     WHERE full_name LIKE 'PROBE %' OR full_name LIKE 'ASSERT %';
    IF v_profiles > 0 THEN
        RAISE EXCEPTION
            'CLEANUP FAILED: % ta probe `profiles` qatori QOLDI', v_profiles;
    END IF;

    SELECT count(*) INTO v_users FROM auth.users
     WHERE email LIKE 'guardprobe-%@lexhub.invalid'
        OR email LIKE 'assert-%@lexhub.invalid';
    IF v_users > 0 THEN
        RAISE EXCEPTION
            'CLEANUP FAILED: % ta probe `auth.users` qatori QOLDI', v_users;
    END IF;

    RAISE NOTICE 'LEXHUB_CLEANUP: QOLDIQ YO''Q (users=0 profiles=0 experts=0)';
END
$cleanup$;

COMMIT;

-- =============================================================================
-- HOLAT QAYDI — GVARD TRIGGER XULQI ENDI **VERIFIED** (2026-08-30)
-- =============================================================================
-- `python tool/probe_expert_guard.py` CHIQISHI (verbatim, HAQIQIY JWT bilan,
-- `SUPABASE_ANON_KEY` + `POST /auth/v1/signup` -> `access_token`):
--
--   [PASS] 1. signUp: uid=bd665520-b3ac-41c3-a7ae-9afd2bbf2bc4 jwt_len=1031
--   [PASS] 2. apply (real JWT): status=pending_verification
--          expert_id=48c56650-a4fa-4a5c-9b55-dd8f4b174d10
--   [PASS] 3.rating PATCH rad etildi: HTTP 400 | Rating Tampering Blocked:
--          Ratings are computed automatically from verified reviews.
--   [PASS] 3.reviews_count PATCH rad etildi: HTTP 400 | Reviews Count
--          Tampering Blocked.
--   [PASS] 3.verified_at PATCH rad etildi: HTTP 400 | Expert verification
--          date is managed by administrators.
--   [PASS] 3.user_id PATCH rad etildi: HTTP 400 | Expert user_id is immutable.
--   [PASS] 3.rejected_at PATCH rad etildi: HTTP 400 | Rejection state is
--          managed by administrators.
--   [PASS] 3.rejection_reason PATCH rad etildi: HTTP 400 | Rejection reason
--          is managed by administrators.
--   [PASS] 4. NAZORAT: `workplace` O'TDI (gvard hammani bloklamaydi): HTTP 200
--   [PASS] 5. withdraw_expert_application: HTTP 200 |
--          {'status': 'withdrawn', 'success': True, 'expert_id': '48c56650-...'}
--   [PASS] 6. ariza qatori YO'Q: HTTP 200 | []
--   jami=11 pass=11 fail=0
--
-- YA'NI `20260829130000_...sql` §6 va `20260830020000_...sql` §(3) da
-- "NOT VERIFIED" deb yozilgan invariant ENDI O'LCHANGAN: gvard trigger
-- KLIENT `PATCH` ini HAQIQATAN rad etadi (6/6), lekin ruxsat etilgan
-- maydonni (`workplace`) bloklamaydi — ya'ni gvard TANLAB ishlaydi.
--
-- PROBE'NING BIRINCHI IJROSIDA IKKI YOLG'ON "FAIL" BO'LDI (yashirilmaydi,
-- chunki bu probe metodikasining chegarasini ko'rsatadi):
--   `rating: 5.0`  -> HTTP 200. Sabab: `rating` ustunining DEFAULT qiymati
--       AYNAN 5.00 (`20260819_base_schema.sql:101`), ya'ni
--       `NEW.rating IS DISTINCT FROM OLD.rating` FALSE — gvard TO'G'RI
--       ishladi, probe noto'g'ri qiymat tanlagan edi (endi 4.25).
--   `rejected_at: null` -> HTTP 200. Sabab: OLD qiymati ham NULL edi
--       (endi haqiqiy timestamp yuboriladi).
-- IKKISI HAM gvard nuqsoni EMAS. Lekin birinchisi ALOHIDA nuqsonni ochdi:
-- yangi ekspert profili `rating = 5.00`, `reviews_count = 0` bilan tug'iladi,
-- ya'ni HECH QANDAY sharh bo'lmasa ham UI'da "5.0" ko'rinadi. Bu foydalanuvchi
-- talab qilgan "soxta ma'lumot qo'shma" qoidasiga to'g'ridan-to'g'ri ziddir va
-- ALOHIDA hal qilinadi (bu fayl doirasida EMAS, §26 — scope creep yo'q).
