-- NUQSON — KATALOG IKKIGA BO'LINGAN: ILOVADA BOR, BAZADA YO'Q SHABLONLAR.
--
-- O'LCHANGAN HOLAT (fayllardan, jonli bazadan EMAS):
--   * `20260823_legal_document_templates_and_user_docs.sql:99-243` FAQAT 3
--     shablon seed qiladi: consumer_refund, labor_complaint,
--     alimony_petition.
--   * Ilova bundle'ida (`document_templates_local_datasource.dart`) 5 shablon
--     bor: yuqoridagi 3 + traffic_fine_appeal + debt_pretenziya.
--   * `DocumentTemplatesRemoteDataSourceImpl.getTemplates` bundle'ga FAQAT
--     baza BO'SH ro'yxat qaytarganda tushadi (`:70-72`). Baza 3 qator
--     qaytarganligi uchun production'da qolgan 2 shablon HECH QACHON
--     ko'rinmaydi — ular bundle'da bo'lsa ham.
--   * `user_documents.template_id` -> `document_templates(id)` FK'si bor
--     (`20260823...sql:36`). Ya'ni AI foydalanuvchini bazada YO'Q shablonga
--     yo'naltirganda saqlash `23503 foreign_key_violation` bilan yiqiladi.
--
-- SHU MIGRATSIYA NIMA QILADI:
--   1. Yetishmayotgan 2 shablonni seed qiladi (bundle bilan AYNAN bir xil
--      matn va maydonlar). Endi FK uchun ota qatori BOR.
--   2. `Sana:` qatorini tuzatadi. `buildDocument` faqat `required_fields`
--      ichida id'si bor `{{...}}` ni almashtiradi
--      (`document_template.dart:42`), shuning uchun bazadagi
--      `Sana: {{created_at}}` (`20260823...sql:241`) RASMIY SUD ARIZASIGA
--      literal `{{created_at}}` bo'lib chiqardi. Iste'molchi va mehnat
--      shablonlarida esa imzo sanasi o'rnida xarid / buyruq sanasi turardi.
--   3. `last_verified_at` ustunidan NOT NULL va `DEFAULT now()` olib
--      tashlanadi. Sababi `expert_profiles.rating DEFAULT 5.00` bilan AYNAN
--      bir xil (`20260830060000_expert_rating_no_fabrication.sql`): sukut
--      qiymat sifatidagi `now()` HAR BIR yangi qator uchun "bu norma
--      bugun TEKSHIRILDI" degan TO'QIMA da'vo yozadi. Tekshiruv hodisasi
--      esa sodir bo'lmagan. Endi tekshirilmagan shablon `NULL` bo'ladi.
--
-- MA'LUMOT YO'QOTISH XAVFI: `last_verified_at` 5 seed qatorida QAYTA
-- yoziladi. Bu qiymat isbotlangan ma'nosiz: `20260823...sql` uni `now()`
-- bilan yozadi (113, 160, 206-qatorlar), ya'ni u MIGRATSIYA QO'LLANGAN
-- vaqtni bildiradi, huquqiy tekshiruv sanasini emas. Boshqa hech qanday
-- qator TEGILMAYDI (`WHERE id IN (...)`), hech narsa o'chirilmaydi.
--
-- QO'LLASH PAYTIDA ISBOTLANADI:
--   P1  FK haqiqatan bor (aks holda butun asos yo'q);
--   P2  o'zgartirishdan oldingi holat o'lchanadi (qaysi id bor, qaysi yo'q);
--   D1  bundle'dagi 5 id BARCHASI bazada bor;
--   D2  hech bir `body_template` ichida O'Z `required_fields` ida BO'LMAGAN
--       `{{...}}` qolmadi (ya'ni hujjatga xom joy egasi chiqmaydi);
--   D3  har bir maydon body ichida HAQIQATAN ishlatiladi (foydalanuvchi
--       to'ldirgan maydon jim yo'qolmaydi);
--   D4  `last_verified_at` sukut qiymati endi SANA QAYTARMAYDI.
--
-- Birorta shart bajarilmasa `RAISE` ishlaydi va BUTUN migratsiya rollback
-- bo'ladi.

BEGIN;

-- 1. NUQSONNI O'LCHASH (o'zgartirishdan OLDIN)
DO $pre$
DECLARE
    v_fk BOOLEAN;
    v_present TEXT;
    v_missing TEXT;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM pg_constraint c
         WHERE c.conrelid = 'public.user_documents'::regclass
           AND c.contype = 'f'
           AND c.confrelid = 'public.document_templates'::regclass
    ) INTO v_fk;

    -- FK bo'lmasa "bazada ota qatori yo'q -> 23503" degan da'vo YOLG'ON
    -- bo'ladi. Bunday holatda migratsiyaning asosi qayta o'rganilishi kerak.
    IF NOT v_fk THEN
        RAISE EXCEPTION 'P1 FAILED: `user_documents` -> `document_templates` '
            'FK''si YO''Q — bu migratsiyaning asosi noto''g''ri, holatni '
            'qayta o''rgan.';
    END IF;

    SELECT string_agg(id, ', ' ORDER BY id) INTO v_present
      FROM public.document_templates
     WHERE id IN ('template_consumer_refund', 'template_labor_complaint',
                  'template_alimony_petition', 'template_traffic_fine_appeal',
                  'template_debt_pretenziya');

    SELECT string_agg(x, ', ' ORDER BY x) INTO v_missing
      FROM unnest(ARRAY['template_consumer_refund', 'template_labor_complaint',
                        'template_alimony_petition',
                        'template_traffic_fine_appeal',
                        'template_debt_pretenziya']) AS x
     WHERE NOT EXISTS (SELECT 1 FROM public.document_templates t WHERE t.id = x);

    RAISE NOTICE 'P2 O''LCHOV: bazada BOR = [%], YO''Q = [%]',
        coalesce(v_present, '-'), coalesce(v_missing, '-');
END
$pre$;

-- 2. TEKSHIRUV SANASI MAJBURIY BO'LMAYDI (to'qima "tekshirildi" yozuvi yo'q)
ALTER TABLE public.document_templates
    ALTER COLUMN last_verified_at DROP NOT NULL,
    ALTER COLUMN last_verified_at SET DEFAULT NULL;

-- 3. YETISHMAYOTGAN 2 SHABLON — matn va maydonlar bundle'dan AYNAN olingan
--    (`document_templates_local_datasource.dart`).
--
--    ATAYLAB TEGILMAGAN TAFOVUT: mavjud 3 qatorning `legal_basis` matni
--    bundle'dagidan uzunroq yozilgan ("O'zbekiston Respublikasining ... gi
--    Qonuni 13, 18-moddalari" / "Iste'molchilar huquqlarini himoya qilish
--    to'g'risidagi Qonun 13, 18-moddalari"). Moddalar AYNI, ya'ni huquqiy
--    ma'no bir xil — faqat uslub farqi. Uni tekislash 3 qatorni qayta
--    yozishni talab qiladi va hech qanday nuqsonni yopmaydi, shuning uchun
--    QILINMADI.
INSERT INTO public.document_templates (
    id, title, category, description, target_authority,
    legal_basis, source_url, last_verified_at, status, is_popular,
    required_fields, body_template
)
VALUES
(
    'template_traffic_fine_appeal',
    'YHQ jarima qarori ustidan shikoyat arizasi',
    'Yo''l harakati',
    'Asossiz yoki xato yozilgan yo''l harakati qoidabuzarligi jarimasi ustidan YHXX yoki Sudga beriladigan shikoyat.',
    'Toshkent shahar IIBB YHXX boshlig''iga / Sudga',
    'MJtK 315, 316, 332-1-moddalari',
    'https://lex.uz/docs/97661#1184234',
    '2026-01-15'::timestamptz,
    'active',
    FALSE,
    '[
        {"id": "authority_name", "label": "Shikoyat berilayotgan YHXX bo''limi", "placeholder": "Masalan: Toshkent shahar IIBB YHXX boshlig''iga", "field_type": "text", "is_required": true},
        {"id": "driver_name", "label": "Haydovchi (Ariza beruvchi) F.I.Sh", "placeholder": "Masalan: Rustamov Jasur Anvarovich", "field_type": "text", "is_required": true},
        {"id": "driver_phone", "label": "Telefon raqami va manzili", "placeholder": "Masalan: +998901234567, Toshkent sh.", "field_type": "text", "is_required": true},
        {"id": "fine_number", "label": "Jarima qarori raqami va sanasi", "placeholder": "Masalan: AB 12345678, 10.08.2026", "field_type": "text", "is_required": true},
        {"id": "car_number", "label": "Avtotransport davlat raqami", "placeholder": "Masalan: 01 A 777 AA", "field_type": "text", "is_required": true},
        {"id": "appeal_reason", "label": "Jarima noto''g''ri qo''llanilgani sababi", "placeholder": "Masalan: Radar ko''rsatgan vaqtda transport vositasini boshqa shaxs ishonchnoma bilan boshqarayotgan edi / Yo''l belgisi ko''rinmas holatda edi...", "field_type": "multiline", "is_required": true}
    ]'::jsonb,
    'KIMGA: {{authority_name}}
KIMDAN: {{driver_name}}
MANZIL VA TEL: {{driver_phone}}

SHIKOYAT ARIZASI
(Ma''muriy jarima qarorini bekor qilish to''g''risida)

Men, {{driver_name}}, o''zimga tegishli {{car_number}} davlat raqamli avtomashina yuzasidan chiqarilgan {{fine_number}} sonli ma''muriy jarima qaroriga e''tiroz bildiraman.

Mazkur qaror quyidagi sabablarga ko''ra asossiz va noto''g''ri deb hisoblayman:
{{appeal_reason}}

O''zbekiston Respublikasining Ma''muriy javobgarlik to''g''risidagi kodeksining 315 va 316-moddalariga muvofiq, ma''muriy jazo qo''llash to''g''risidagi qaror ustidan yuqori turuvchi organga yoki sudga 10 kunlik muddatda shikoyat berishga haqlidirman.

Yuqoridagilardan kelib chiqib, SIZDAN:
1. {{fine_number}} sonli ma''muriy huquqbuzarlik to''g''risidagi qarorni qayta ko''rib chiqishingizni;
2. Mazkur qarorni asossiz deb topib, ma''muriy ishni harakatdan tugatishingizni so''rayman.

Ilova:
1. Haydovchilik guvohnomasi va texnik pasport nusxasi.
2. Jarima qarori nusxasi.
3. Daliliy fotosuratlar / videoyozuvlar.

Sana: ____________
Imzo: ______________ ({{driver_name}})'
),
-- `source_url` va `last_verified_at` ATAYLAB NULL: bu shablon uchun lex.uz
-- chuqur havolasi TEKSHIRILMAGAN. Havolani o'ylab topish yoki
-- `last_verified_at = now()` yozish "tekshirildi" degan TO'QIMA da'vo bo'lardi
-- (§0). Bundle'da ham AYNI shunday (`lastVerifiedAt` va `sourceUrl` berilmagan).
(
    'template_debt_pretenziya',
    'Qarzni qaytarish to''g''risida talabnoma (Pretenziya)',
    'Qarz va shartnomalar',
    'Qarzni muddatida qaytarmagan shaxsga sudgacha yuboriladigan qat''iy yozma talabnoma.',
    'Qarzdor shaxsning o''ziga (sudgacha talabnoma)',
    'Fuqarolik kodeksi 732, 735-moddalari',
    NULL,
    NULL,
    'active',
    FALSE,
    '[
        {"id": "debtor_name", "label": "Qarzdor shaxs F.I.Sh", "placeholder": "Masalan: Qodirov Otabek Shuhratovich", "field_type": "text", "is_required": true},
        {"id": "creditor_name", "label": "Qarz beruvchi (Sizning) F.I.Sh", "placeholder": "Masalan: Rahimov Jamshid Komilovich", "field_type": "text", "is_required": true},
        {"id": "debt_date", "label": "Qarz berilgan sana", "placeholder": "Masalan: 15.01.2026", "field_type": "date", "is_required": true},
        {"id": "debt_amount", "label": "Qarz summasi (so''mda)", "placeholder": "Masalan: 15 000 000 so''m", "field_type": "number", "is_required": true},
        {"id": "due_date", "label": "Qaytarilishi kerak bo''lgan muddat", "placeholder": "Masalan: 01.06.2026", "field_type": "date", "is_required": true},
        {"id": "debt_details", "label": "Qarz holati tafsilotlari (tilxat, guvohlar, yozishmalar)", "placeholder": "Masalan: Pul naqd holda tilxat asosida berilgan, ikki guvoh imzosi bor...", "field_type": "multiline", "is_required": true}
    ]'::jsonb,
    'KIMGA: {{debtor_name}}
KIMDAN: {{creditor_name}}

TALABNOMA (PRETENZIYA)
(Qarz summasini qaytarish to''g''risida)

{{debt_date}} sanasida tuzilgan qarz shartnomasi (tilxat)ga muvofiq, men Sizga {{debt_amount}} miqdorida pul mablag''ini qarzga bergan edim.

Qarz holati tafsilotlari:
{{debt_details}}

Shartnomaga ko''ra, Siz qarz mablag''ini {{due_date}} sanasiga qadar to''liq qaytarishingiz lozim edi. Biroq, bugungi kunga qadar ushbu majburiyat bajarilmadi.

O''zbekiston Respublikasi Fuqarolik kodeksining 735-moddasiga ko''ra, qarz oluvchi olingan qarz summasini shartnomada nazarda tutilgan muddatda va tartibda qaytarishi shart.

Ushbu talabnoma olingan kundan boshlab 7 (yetti) kunlik muddatda {{debt_amount}} miqdoridagi qarzni to''liq qaytarishingizni TALAB QILAMAN.

Aks holda, Fuqarolik ishlari bo''yicha tumanlararo sudiga da''vo arizasi kiritilib, qarz summasi bilan birga har bir kechiktirilgan kun uchun foizlar, davlat boji va advokat xizmati xarajatlari Sizdan majburiy tartibda undirilishini ma''lum qilaman.

Sana: ____________
Imzo: ______________ ({{creditor_name}})'
)
ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    category = EXCLUDED.category,
    description = EXCLUDED.description,
    target_authority = EXCLUDED.target_authority,
    required_fields = EXCLUDED.required_fields,
    body_template = EXCLUDED.body_template,
    legal_basis = EXCLUDED.legal_basis,
    source_url = EXCLUDED.source_url,
    last_verified_at = EXCLUDED.last_verified_at,
    status = EXCLUDED.status,
    is_popular = EXCLUDED.is_popular,
    updated_at = now();

-- 4. "Sana:" QATORINI TUZATISH (mavjud 3 qator)
--
-- `replace()` FAQAT "Sana: " prefiksi bilan birga qidiradi, shuning uchun
-- ayni joy egasining boshqa o'rinlaridagi (masalan "{{purchase_date}}
-- sanasida") ishlatilishi TEGILMAYDI. `position(...) > 0` sharti tufayli
-- migratsiya qayta qo'llansa hech narsa o'zgarmaydi (idempotent).
UPDATE public.document_templates
   SET body_template = replace(body_template,
           'Sana: {{purchase_date}}', 'Sana: ____________'),
       updated_at = now()
 WHERE id = 'template_consumer_refund'
   AND position('Sana: {{purchase_date}}' in body_template) > 0;

UPDATE public.document_templates
   SET body_template = replace(body_template,
           'Sana: {{dismissal_date}}', 'Sana: ____________'),
       updated_at = now()
 WHERE id = 'template_labor_complaint'
   AND position('Sana: {{dismissal_date}}' in body_template) > 0;

-- `{{created_at}}` MAYDON EMAS — hech qanday `required_fields` yozuvi bunday
-- id bilan yo'q, ya'ni u hujjatda XOM matn bo'lib chiqardi.
UPDATE public.document_templates
   SET body_template = replace(body_template,
           'Sana: {{created_at}}', 'Sana: ____________'),
       updated_at = now()
 WHERE id = 'template_alimony_petition'
   AND position('Sana: {{created_at}}' in body_template) > 0;

-- 5. TEKSHIRUV SANASINI BUNDLE'DAGI DA'VO BILAN TENGLASH
--
-- HALOL CHEGARA: `2026-01-15` sanasi BUNDLE'dan olingan (`lastVerifiedAt:
-- DateTime(2026, 1, 15)`) — ya'ni bu ilova ALLAQACHON aytib turgan da'vo,
-- yangi da'vo EMAS. Men bu lex.uz havolalarini BUGUN qayta tekshirmadim.
-- Bazadagi joriy qiymat esa `now()` bilan yozilgan
-- (`20260823...sql:113,160,206`), ya'ni u MIGRATSIYA QO'LLANGAN vaqtni
-- ko'rsatadi va huquqiy tekshiruvga hech qanday aloqasi yo'q.
UPDATE public.document_templates
   SET last_verified_at = '2026-01-15'::timestamptz,
       updated_at = now()
 WHERE id IN ('template_consumer_refund', 'template_labor_complaint',
              'template_alimony_petition')
   AND (last_verified_at IS NULL
        OR last_verified_at <> '2026-01-15'::timestamptz);

-- 6. TUZATISHDAN KEYINGI ISBOT
--
-- D2/D3 ATAYLAB faqat shu 5 id bo'yicha o'lchanadi: bu migratsiya AYNI
-- shu qatorlar uchun javob beradi. Admin tomonidan qo'lda kiritilgan boshqa
-- qator nuqsonli bo'lsa, migratsiyani BLOKLAB butun deploy'ni to'xtatishi
-- to'g'ri bo'lmaydi.
DO $post$
DECLARE
    v_ids TEXT[] := ARRAY['template_consumer_refund', 'template_labor_complaint',
                          'template_alimony_petition',
                          'template_traffic_fine_appeal',
                          'template_debt_pretenziya'];
    v_missing TEXT;
    v_orphan TEXT;
    v_unused TEXT;
    v_default TEXT;
    v_value TIMESTAMPTZ;
BEGIN
    SELECT string_agg(x, ', ' ORDER BY x) INTO v_missing
      FROM unnest(v_ids) AS x
     WHERE NOT EXISTS (SELECT 1 FROM public.document_templates t WHERE t.id = x);
    IF v_missing IS NOT NULL THEN
        RAISE EXCEPTION 'D1 FAILED: bundle''da bor, bazada YO''Q shablonlar: % '
            '— ular production''da ko''rinmaydi va FK ota qatori yo''q', v_missing;
    END IF;

    -- D2: body ichida joy egasi bor, lekin unga MOS MAYDON yo'q. Bunday
    -- `{{...}}` almashtirilmaydi va RASMIY hujjatga xom holda chiqadi.
    SELECT string_agg(format('%s:{{%s}}', z.id, z.token), ', ')
      INTO v_orphan
      FROM (
        SELECT DISTINCT t.id, m[1] AS token
          FROM public.document_templates t,
               LATERAL regexp_matches(
                   t.body_template, '\{\{([a-zA-Z0-9_]+)\}\}', 'g') AS m
         WHERE t.id = ANY(v_ids)
           AND NOT EXISTS (
               SELECT 1 FROM jsonb_array_elements(t.required_fields) f
                WHERE f->>'id' = m[1])
      ) z;
    IF v_orphan IS NOT NULL THEN
        RAISE EXCEPTION 'D2 FAILED: maydoni yo''q joy egalari hujjatga xom '
            'holda chiqadi: %', v_orphan;
    END IF;

    -- D3: maydon bor, lekin body ichida ISHLATILMAGAN. Foydalanuvchi uni
    -- to'ldiradi, natijaga esa hech narsa tushmaydi (jim ma'lumot yo'qotish).
    SELECT string_agg(format('%s:%s', z.id, z.fid), ', ')
      INTO v_unused
      FROM (
        SELECT DISTINCT t.id, f->>'id' AS fid
          FROM public.document_templates t,
               LATERAL jsonb_array_elements(t.required_fields) f
         WHERE t.id = ANY(v_ids)
           AND position('{{' || (f->>'id') || '}}' in t.body_template) = 0
      ) z;
    IF v_unused IS NOT NULL THEN
        RAISE EXCEPTION 'D3 FAILED: hujjatda ishlatilmaydigan maydonlar: % — '
            'foydalanuvchi to''ldiradi, natijada YO''Q', v_unused;
    END IF;

    -- D4: sukut qiymat SANA QAYTARMASLIGI kerak. `SET DEFAULT NULL` katalogda
    -- ifoda bo'lib qoladi, shuning uchun mavjudligi emas, NATIJASI o'lchanadi.
    SELECT pg_get_expr(d.adbin, d.adrelid) INTO v_default
      FROM pg_attribute a
      LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
     WHERE a.attrelid = 'public.document_templates'::regclass
       AND a.attname = 'last_verified_at';
    IF v_default IS NOT NULL THEN
        EXECUTE format('SELECT (%s)::timestamptz', v_default) INTO v_value;
        IF v_value IS NOT NULL THEN
            RAISE EXCEPTION 'D4 FAILED: sukut qiymat hamon SANA beradi: % (= %) '
                '— har bir yangi shablon "tekshirilgan" bo''lib tug''iladi',
                v_default, v_value;
        END IF;
    END IF;

    RAISE NOTICE 'D1-D4 OK: 5 shablon bazada, xom joy egasi yo''q, '
        'ishlatilmaydigan maydon yo''q, tekshiruv sanasi to''qilmaydi';
END
$post$;

COMMENT ON COLUMN public.document_templates.last_verified_at IS
    'Shablonning huquqiy asosi (source_url) OXIRGI MARTA qo''lda tekshirilgan '
    'sana. NULL = TEKSHIRILMAGAN. Sukut qiymat ATAYLAB NULL: `now()` bo''lganda '
    'har bir yangi qator o''zi haqida "bugun tekshirildi" degan to''qima da''vo '
    'yozardi (qiyos: 20260830060000_expert_rating_no_fabrication.sql).';

COMMIT;

-- 7. KO'RINADIGAN DIAGNOSTIKA
--
-- Supabase SQL Editor `RAISE NOTICE` ni KO'RSATMAYDI — yuqoridagi NOTICE'lar
-- faqat `supabase db push` / `psql` log'ida ko'rinadi. Shu sababli natija
-- JADVAL bo'lib ham qaytariladi. SELECT tranzaksiyadan TASHQARIDA, ya'ni
-- migratsiyaning o'ziga ta'sir qilmaydi.
SELECT
    t.id,
    t.status,
    t.is_popular,
    (t.source_url IS NOT NULL) AS has_source_url,
    t.last_verified_at,
    jsonb_array_length(t.required_fields) AS field_count,
    (SELECT count(DISTINCT m[1])
       FROM regexp_matches(t.body_template,
                '\{\{([a-zA-Z0-9_]+)\}\}', 'g') AS m) AS placeholder_count,
    (position('Sana: {{' in t.body_template) = 0) AS date_line_fixed
  FROM public.document_templates t
 WHERE t.id IN ('template_consumer_refund', 'template_labor_complaint',
                'template_alimony_petition', 'template_traffic_fine_appeal',
                'template_debt_pretenziya')
 ORDER BY t.id;
