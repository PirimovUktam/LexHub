-- LEXHUB — `questions` SXEMA DRIFT'INI YOPISH (repo ↔ production pariteti)
--
-- O'LCHANGAN (2026-08-29, PRODUCTION, PostgREST OpenAPI + `service_role`):
-- jonli `public.questions` da 22 ustun bor, repo migratsiyalari esa faqat 19
-- tasini yaratadi. Quyidagi 3 ustun HECH QAYSI migratsiya faylida yo'q, ya'ni
-- ular bazaga qo'lda (Studio orqali) qo'shilgan:
--
--   body                       text              NOT NULL
--   ai_classified_category_id  uuid              nullable  -> categories.id
--   ai_confidence              double precision  nullable
--
-- Teskari yo'nalishda drift YO'Q: repoda bor, bazada yo'q ustun topilmadi.
--
-- NIMA UCHUN BU MUHIM: `supabase db reset` yoki yangi muhit FAQAT shu
-- migratsiyalardan qurilsa, `questions.body` UMUMAN bo'lmaydi. Ilova esa unga
-- YOZADI va u NOT NULL: `question_category_resolver.dart` ichida aynan shu
-- xato hujjatlashtirilgan — `null value in column "body" of relation
-- "questions"`. Ya'ni drift yopilmasa, yangi muhitda savol yaratish 42703
-- bilan darhol yiqiladi.
--
-- PRODUCTION UCHUN BU FAYL NO-OP: barcha operatsiyalar `IF NOT EXISTS` /
-- `information_schema` qo'riqchisi ostida. Uslub `20260819_base_schema.sql`
-- dagi `answers.body` moslashtirishidan ko'chirildi (o'sha yerda ham AYNI
-- muammo shu yo'l bilan yopilgan).
--
-- HOLATI: bu fayl JONLI BAZADA ISHGA TUSHIRILMAGAN (`db push` uchun DB paroli
-- kerak, u menda yo'q). Production allaqachon shu holatda — fayl yangi muhit
-- reproduktsiyasi uchun. `db reset` bilan tekshirilmaguncha NOT VERIFIED.

ALTER TABLE public.questions
    ADD COLUMN IF NOT EXISTS body TEXT;

ALTER TABLE public.questions
    ADD COLUMN IF NOT EXISTS ai_classified_category_id UUID
    REFERENCES public.categories(id) ON DELETE SET NULL;

ALTER TABLE public.questions
    ADD COLUMN IF NOT EXISTS ai_confidence DOUBLE PRECISION;

-- `body` NOT NULL bo'lishi SHART (jonli bazada shunday). Lekin bu migratsiya
-- ilgari `db reset` qilingan va allaqachon savol yozilgan muhitda ham ishlashi
-- kerak: avval bo'sh qiymatlar mavjud matn ustunlaridan to'ldiriladi, keyingina
-- cheklov qo'yiladi. `title` NOT NULL, shuning uchun COALESCE oxiri kafolatli.
DO $$ BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'questions'
          AND column_name = 'body' AND is_nullable = 'YES'
    ) THEN
        UPDATE public.questions
        SET body = COALESCE(NULLIF(body, ''), NULLIF(content, ''),
                            NULLIF(description, ''), title)
        WHERE body IS NULL OR body = '';

        ALTER TABLE public.questions ALTER COLUMN body SET NOT NULL;
    END IF;
END $$;
