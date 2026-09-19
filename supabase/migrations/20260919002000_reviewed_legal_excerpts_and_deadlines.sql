-- P1-01: reviewed excerpts/anchors and the labour complaint deadline.
-- Reference text checked against Lex.uz on 2026-09-19; see docs/STAGE1_DATABASE.md.
-- Prepared after READ-ONLY MCP inspection; NOT APPLIED TO PRODUCTION.
-- Existing rows must match the measured old text or the reviewed replacement.
-- Unknown edits abort the transaction. Missing four canonical excerpts are seeded
-- for empty local bootstrap; no user data is read/modified by this migration.
BEGIN;
DO $patch$
DECLARE
    p RECORD;
    v_current public.law_article_chunks%ROWTYPE;
BEGIN
    FOR p IN SELECT * FROM (VALUES
        ('const_art_27',
         'O''zbekiston Respublikasining Konstitutsiyasi',
         'lex_const_2023',
         '27',
         'Shaxsiy daxlsizlik va erkinlik huquqi',
         'Har kim erkinlik va shaxsiy daxlsizlik huquqiga ega. Hech kim qonunga asoslanmagan holda hibsga olinishi, ushlab turilishi, qamoqqa olinishi, qamoqda saqlanishi yoki uning ozodligi boshqacha tarzda cheklanishi mumkin emas. Shaxsni ushlash chog''ida unga tushunarli tilda uning huquqlari va ushlab turilishi asoslari tushuntirilishi shart.',
         'Konstitutsiyaviy huquq',
         '2023-05-01',
         'https://lex.uz/docs/6445145#6445434',
         'Har kim erkinlik va shaxsiy daxlsizlik huquqiga ega. Hech kim qonunga asoslanmagan holda hibsga olinishi, ushlab turilishi, qamoqqa olinishi yoki boshqacha tarzda ozodlikdan mahrum etilishi mumkin emas.',
         'https://lex.uz/docs/6445145#6445371'),
        ('const_art_28',
         'O''zbekiston Respublikasining Konstitutsiyasi',
         'lex_const_2023',
         '28',
         'Aybsizlik prezumpsiyasi va sukut saqlash huquqi',
         'Gumon qilinuvchi, ayblanuvchi yoki sudlanuvchi o''zining aybsizligini isbotlashi shart emas va istalgan vaqtda sukut saqlash huquqidan foydalanishi mumkin. Hech kim o''ziga va yaqin qarindoshlariga qarshi guvohlik berishga majbur emas.',
         'Konstitutsiyaviy huquq',
         '2023-05-01',
         'https://lex.uz/docs/6445145#6445509',
         'Shaxsni ushlash chog''ida unga tushunarli tilda uning huquqlari va ushlab turilishi asoslari tushuntirilishi shart. Ushlab turilgan shaxs sukut saqlash huquqiga ega va uning so''zlaridan unga qarshi sudda foydalanilishi mumkin.',
         'https://lex.uz/docs/6445145#6445375'),
        ('const_art_29',
         'O''zbekiston Respublikasining Konstitutsiyasi',
         'lex_const_2023',
         '29',
         'Malakali yuridik yordam olish va advokat huquqi',
         'Har kimga malakali yuridik yordam olish huquqi kafolatlanadi. Qonunda nazarda tutilgan hollarda yuridik yordam davlat hisobidan ko''rsatiladi. Har bir shaxs jinoyat protsessining har qanday bosqichida, shaxs ushlanganida esa uning harakatlanish erkinligi huquqi amalda cheklangan paytdan e''tiboran o''z tanloviga ko''ra advokat yordamidan foydalanish huquqiga ega.',
         'Konstitutsiyaviy huquq',
         '2023-05-01',
         'https://lex.uz/docs/6445145#6445518',
         'Har kimga malakali yuridik yordam olish huquqi kafolatlanadi. Qonunda nazarda tutilgan hollarda yuridik yordam davlat hisobidan ko''rsatiladi. Shaxs ushlangan paytdan boshlab advokat xizmatidan foydalanish huquqiga ega.',
         'https://lex.uz/docs/6445145#6445380'),
        ('labor_art_560',
         'O''zbekiston Respublikasining Mehnat kodeksi',
         'lex_labor_2023',
         '560',
         'Yakka mehnat nizolarini ko''rib chiqish uchun sudga murojaat qilish muddatlari',
         'Ishga tiklash to''g''risidagi nizolar bo''yicha sudga murojaat qilish muddati xodimga u bilan mehnat shartnomasi bekor qilinganligi haqidagi ish beruvchi buyrug''ining ko''chirma nusxasi topshirilgan kundan e''tiboran uch oy. Xodim tomonidan ish beruvchiga yetkazilgan moddiy zararning o''rnini qoplash to''g''risidagi nizolar bo''yicha — ish beruvchi zarar yetkazilganligini aniqlagan kundan e''tiboran bir yil. Boshqa mehnat nizolari bo''yicha — xodim o''zining huquqi buzilganligi to''g''risida bilgan yoki bilishi kerak bo''lgan kundan e''tiboran olti oy. Xodimning hayoti va sog''lig''iga yetkazilgan ziyon hamda ma''naviy ziyonni kompensatsiya qilish haqidagi nizolarda sudga murojaat etish muddati belgilanmaydi. Muddatning o''tishi nizoni mediatsiya tartibida ko''rib chiqish davrida to''xtatib turiladi.',
         'Mehnat huquqi',
         '2023-04-30',
         'https://lex.uz/docs/6257288#6269139',
         'Ishga tiklash to''g''risidagi nizolar bo''yicha sudga murojaat qilish muddati xodimga u bilan mehnat shartnomasi bekor qilinganligi haqidagi buyruq nusxasi topshirilgan kundan e''tiboran 1 oyni tashkil etadi.',
         'https://lex.uz/docs/6257288#6270500')
    ) AS patches(chunk_id, document_name, document_id, article_number, article_title,
                 content, jurisdiction, last_updated, lex_url, old_content, old_url)
    LOOP
        SELECT * INTO v_current FROM public.law_article_chunks
            WHERE chunk_id = p.chunk_id FOR UPDATE;
        IF FOUND THEN
            IF v_current.document_id IS DISTINCT FROM p.document_id
               OR v_current.article_number IS DISTINCT FROM p.article_number::integer
               OR v_current.status IS DISTINCT FROM 'active'
               OR NOT ((v_current.content = p.old_content AND v_current.lex_url = p.old_url)
                    OR (v_current.content = p.content AND v_current.lex_url = p.lex_url)) THEN
                RAISE EXCEPTION 'Unexpected legal excerpt drift: %; review before applying', p.chunk_id;
            END IF;
            UPDATE public.law_article_chunks SET
                article_title = p.article_title,
                content = p.content,
                lex_url = p.lex_url,
                embedding = CASE WHEN content IS DISTINCT FROM p.content THEN NULL ELSE embedding END,
                updated_at = now()
            WHERE chunk_id = p.chunk_id;
        ELSE
            INSERT INTO public.law_article_chunks
                (chunk_id, document_name, document_id, article_number, article_title,
                 content, jurisdiction, last_updated, lex_url, status)
            VALUES (p.chunk_id, p.document_name, p.document_id, p.article_number::integer,
                    p.article_title, p.content, p.jurisdiction, p.last_updated::date,
                    p.lex_url, 'active');
        END IF;
    END LOOP;
END;
$patch$;

DO $service$
DECLARE
    v_service public.citizen_services%ROWTYPE;
    v_step public.service_steps%ROWTYPE;
BEGIN
    SELECT * INTO STRICT v_service FROM public.citizen_services
        WHERE id = 'service_labor_complaint' FOR UPDATE;
    IF NOT coalesce(((v_service.deadline_law_reference = 'Mehnat kodeksi 560-modda (Sudga da''vo muddati: 1 oy)'
             AND v_service.source_url = 'https://lex.uz/docs/6257288#6273110')
         OR (v_service.deadline_law_reference = 'Mehnat kodeksi 560-modda (Ishga tiklash nizosi: uch oy; boshqa mehnat nizolari: olti oy; qonundagi istisnolar hisobga olinadi)'
             AND v_service.source_url = 'https://lex.uz/docs/6257288#6269139')), false) THEN
        RAISE EXCEPTION 'Unexpected labour service drift; review before applying';
    END IF;
    SELECT * INTO STRICT v_step FROM public.service_steps
        WHERE service_id = 'service_labor_complaint' AND step_number = 3 FOR UPDATE;
    IF NOT coalesce(((v_step.description = 'Ishdan bo''shatish to''g''risidagi buyruq chiqqan kundan boshlab 1 oy ichida fuqarolik sudiga da''vo bering. Ishchi xodimlar sud bojidan ozod qilinadi!'
             AND v_step.warning_note = '1 oylik da''vo muddati o''tkazib yuborilsa, sud arizani rad etishi mumkin.')
         OR (v_step.description = 'Ishga tiklash to''g''risidagi nizoda sudga murojaat qilish muddati ish beruvchining mehnat shartnomasini bekor qilish haqidagi buyrug''i ko''chirma nusxasi xodimga topshirilgan kundan e''tiboran uch oy (Mehnat kodeksi 560-modda).'
             AND v_step.warning_note = 'Muddat nizoning turiga va qonunda nazarda tutilgan holatlarga bog''liq. Boshlanish sanasi, istisnolar va mediatsiya davrini yurist bilan tekshiring; bu qolgan vaqt hisob-kitobi emas.')), false) THEN
        RAISE EXCEPTION 'Unexpected labour service step drift; review before applying';
    END IF;
    UPDATE public.citizen_services SET
        deadline_law_reference = 'Mehnat kodeksi 560-modda (Ishga tiklash nizosi: uch oy; boshqa mehnat nizolari: olti oy; qonundagi istisnolar hisobga olinadi)',
        source_url = 'https://lex.uz/docs/6257288#6269139'
        WHERE id = 'service_labor_complaint';
    UPDATE public.service_steps SET
        description = 'Ishga tiklash to''g''risidagi nizoda sudga murojaat qilish muddati ish beruvchining mehnat shartnomasini bekor qilish haqidagi buyrug''i ko''chirma nusxasi xodimga topshirilgan kundan e''tiboran uch oy (Mehnat kodeksi 560-modda).',
        warning_note = 'Muddat nizoning turiga va qonunda nazarda tutilgan holatlarga bog''liq. Boshlanish sanasi, istisnolar va mediatsiya davrini yurist bilan tekshiring; bu qolgan vaqt hisob-kitobi emas.'
        WHERE service_id = 'service_labor_complaint' AND step_number = 3;
    -- last_verified_at deliberately unchanged: unrelated service details were
    -- not fully reviewed in this stage. Legislative last_updated is unchanged.
END;
$service$;

-- The same incorrect labour reference was present in the public template.
-- 437 covers secondary employment; reinstatement is covered by 561.
-- Source: https://lex.uz/docs/6257288#6269151 (checked 2026-09-19).
DO $template$
DECLARE
    v_template public.document_templates%ROWTYPE;
    v_old TEXT := '161, 437 va 560-moddalariga';
    v_new TEXT := '161, 560 va 561-moddalariga';
BEGIN
    SELECT * INTO STRICT v_template FROM public.document_templates
        WHERE id = 'template_labor_complaint' FOR UPDATE;
    IF NOT coalesce((
        (v_template.legal_basis = 'O''zbekiston Respublikasining Mehnat kodeksi 161, 437, 560-moddalari'
         AND v_template.source_url = 'https://lex.uz/docs/6257288#6273110'
         AND (length(v_template.body_template)
              - length(replace(v_template.body_template, v_old, ''))) = length(v_old))
        OR
        (v_template.legal_basis = 'O''zbekiston Respublikasining Mehnat kodeksi 161, 560, 561-moddalari'
         AND v_template.source_url = 'https://lex.uz/docs/6257288#6269151'
         AND (length(v_template.body_template)
              - length(replace(v_template.body_template, v_new, ''))) = length(v_new))
    ), false) THEN
        RAISE EXCEPTION 'Unexpected labour template drift; review before applying';
    END IF;
    UPDATE public.document_templates SET
        legal_basis = 'O''zbekiston Respublikasining Mehnat kodeksi 161, 560, 561-moddalari',
        source_url = 'https://lex.uz/docs/6257288#6269151',
        body_template = replace(body_template, v_old, v_new)
        WHERE id = 'template_labor_complaint';
END;
$template$;
COMMIT;

-- Read-only post-apply check (not proof of production deployment):
-- SELECT chunk_id, article_number, content, lex_url FROM public.law_article_chunks
-- WHERE chunk_id IN ('const_art_27','const_art_28','const_art_29','labor_art_560');
-- SELECT deadline_law_reference, source_url FROM public.citizen_services
-- WHERE id = 'service_labor_complaint';
