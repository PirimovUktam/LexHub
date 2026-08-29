-- ==============================================================================
-- MIGRATION: 20260822_citizen_services_freshness_and_seed.sql
-- LexHub Platform — Citizen Services & Government Guides Freshness Migration
-- Official Legal Sources (Lex.uz, My.gov.uz), BHM Fees, Deadlines & Seed Data
-- ==============================================================================

-- 1. RECONCILE COLUMNS ON citizen_services
CREATE TABLE IF NOT EXISTS public.citizen_services (
    id VARCHAR(64) PRIMARY KEY,
    category_id VARCHAR(64) REFERENCES public.question_categories(id) ON DELETE SET NULL,
    title VARCHAR(255) NOT NULL,
    department VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    cost_bhm_percent NUMERIC(5, 2) DEFAULT 0.00 NOT NULL CHECK (cost_bhm_percent >= 0.00),
    is_free BOOLEAN DEFAULT FALSE NOT NULL,
    processing_days INTEGER DEFAULT 1 NOT NULL CHECK (processing_days >= 0),
    required_documents TEXT[] DEFAULT '{}',
    online_url TEXT,
    deadline_law_reference TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE public.citizen_services ADD COLUMN IF NOT EXISTS category_id VARCHAR(64) REFERENCES public.question_categories(id) ON DELETE SET NULL;
ALTER TABLE public.citizen_services ADD COLUMN IF NOT EXISTS title VARCHAR(255);
ALTER TABLE public.citizen_services ADD COLUMN IF NOT EXISTS department VARCHAR(255);
ALTER TABLE public.citizen_services ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE public.citizen_services ADD COLUMN IF NOT EXISTS cost_bhm_percent NUMERIC(5, 2) DEFAULT 0.00 NOT NULL;
ALTER TABLE public.citizen_services ADD COLUMN IF NOT EXISTS is_free BOOLEAN DEFAULT FALSE NOT NULL;
ALTER TABLE public.citizen_services ADD COLUMN IF NOT EXISTS processing_days INTEGER DEFAULT 1 NOT NULL;
ALTER TABLE public.citizen_services ADD COLUMN IF NOT EXISTS required_documents TEXT[] DEFAULT '{}';
ALTER TABLE public.citizen_services ADD COLUMN IF NOT EXISTS online_url TEXT;
ALTER TABLE public.citizen_services ADD COLUMN IF NOT EXISTS deadline_law_reference TEXT;
ALTER TABLE public.citizen_services ADD COLUMN IF NOT EXISTS source_url TEXT;
ALTER TABLE public.citizen_services ADD COLUMN IF NOT EXISTS legal_basis TEXT;
ALTER TABLE public.citizen_services ADD COLUMN IF NOT EXISTS last_verified_at TIMESTAMPTZ DEFAULT now() NOT NULL;
ALTER TABLE public.citizen_services ADD COLUMN IF NOT EXISTS status VARCHAR(32) DEFAULT 'active' NOT NULL;
ALTER TABLE public.citizen_services ADD COLUMN IF NOT EXISTS is_popular BOOLEAN DEFAULT FALSE NOT NULL;
ALTER TABLE public.citizen_services ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now() NOT NULL;

-- 2. RECONCILE COLUMNS ON service_steps
CREATE TABLE IF NOT EXISTS public.service_steps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    service_id VARCHAR(64) NOT NULL REFERENCES public.citizen_services(id) ON DELETE CASCADE,
    step_number INTEGER NOT NULL CHECK (step_number > 0),
    title VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    warning_note TEXT,
    UNIQUE (service_id, step_number)
);

ALTER TABLE public.service_steps ADD COLUMN IF NOT EXISTS service_id VARCHAR(64) REFERENCES public.citizen_services(id) ON DELETE CASCADE;
ALTER TABLE public.service_steps ADD COLUMN IF NOT EXISTS step_number INTEGER NOT NULL;
ALTER TABLE public.service_steps ADD COLUMN IF NOT EXISTS title VARCHAR(255);
ALTER TABLE public.service_steps ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE public.service_steps ADD COLUMN IF NOT EXISTS warning_note TEXT;
ALTER TABLE public.service_steps ADD COLUMN IF NOT EXISTS action_url TEXT;
ALTER TABLE public.service_steps ADD COLUMN IF NOT EXISTS step_type VARCHAR(32) DEFAULT 'online' NOT NULL;

-- 3. INDICES
CREATE INDEX IF NOT EXISTS idx_citizen_services_category ON public.citizen_services(category_id);
CREATE INDEX IF NOT EXISTS idx_citizen_services_popular ON public.citizen_services(is_popular);
CREATE INDEX IF NOT EXISTS idx_citizen_services_status ON public.citizen_services(status);
CREATE INDEX IF NOT EXISTS idx_service_steps_service_id ON public.service_steps(service_id);

-- 4. HARDENED ROW LEVEL SECURITY
ALTER TABLE public.citizen_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_steps ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Services are readable by everyone" ON public.citizen_services;
CREATE POLICY "Services are readable by everyone" ON public.citizen_services 
FOR SELECT USING (true);

DROP POLICY IF EXISTS "Service steps are readable by everyone" ON public.service_steps;
CREATE POLICY "Service steps are readable by everyone" ON public.service_steps 
FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admins can manage services" ON public.citizen_services;
CREATE POLICY "Admins can manage services" ON public.citizen_services 
FOR ALL USING (
    EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE id = auth.uid() AND role::text IN ('admin', 'moderator')
    ) OR current_user = 'service_role'
);

DROP POLICY IF EXISTS "Admins can manage service steps" ON public.service_steps;
CREATE POLICY "Admins can manage service steps" ON public.service_steps 
FOR ALL USING (
    EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE id = auth.uid() AND role::text IN ('admin', 'moderator')
    ) OR current_user = 'service_role'
);

-- 4.5 SEED PARENT CATEGORIES (FK PREREQUISITE)
--
-- O'LCHANGAN NUQSON (2026-08-29, production): bu migratsiya HECH QACHON
-- qo'llanmagan, sababi aynan shu yerda:
--   ERROR: insert or update on table "citizen_services" violates foreign key
--   constraint "citizen_services_category_id_fkey" (SQLSTATE 23503)
--   Key (category_id)=(traffic) is not present in table "question_categories".
--   At statement: 39
--
-- `public.question_categories` `20260819_base_schema.sql:124` da YARATILADI,
-- lekin repodagi BIRORTA migratsiya unga qator QO'SHMAYDI (o'lchangan: jonli
-- bazada 0 qator). Quyidagi seed esa `category_id` sifatida 'traffic',
-- 'labor', 'family', 'civil', 'real_estate' ni ishlatadi — ya'ni ota-qatorlar
-- yo'q va FK darhol yiqiladi. Shu sababli `citizen_services` production'da
-- bo'sh (0 qator) va ilova bundle'dagi zaxira katalogga tushib ishlayapti.
--
-- NIMA UCHUN `category_id`ni NULL qilib qo'ymaymiz: bu qiymatlar BACKEND
-- KONTRAKTI — klient ularni filtr sifatida AYNAN shu ko'rinishda yuboradi
-- (`citizen_services_remote_datasource.dart:45-49`:
--  "Yo'l harakati"->traffic, "Mehnat huquqi"->labor, "Ijtimoiy himoya"->family,
--  "Iste'molchi huquqi"->civil, "Kadastr va Uy-joy"->real_estate). NULL
-- qilinsa server ma'lumotida kategoriya filtri ishlamay qoladi.
--
-- NIMA UCHUN FK O'CHIRILMAYDI: bu jadval redizayni bo'lardi; ota-qatorni
-- qo'shish — eng kichik va butunlikni saqlaydigan yechim.
--
-- `name_uz` qiymatlari YUQORIDAGI klient mapping'idan olindi (to'qilmadi).
-- `name_ru` — NOT NULL, repoda manbasi yo'q, shuning uchun o'sha yorliqning
-- ruscha muqobili yozildi. Klientda `question_categories`ni o'qiydigan joy
-- YO'Q (`question_category_resolver.dart:28` — u ataylab `categories`
-- jadvalidan foydalanadi), ya'ni bu ustun faqat FK/sxema butunligi uchun.
INSERT INTO public.question_categories (id, name_uz, name_ru, icon_name, sort_order)
VALUES
    ('traffic',     'Yo''l harakati',     'Дорожное движение',  'directions_car', 1),
    ('labor',       'Mehnat huquqi',      'Трудовое право',     'work_outline',   2),
    ('family',      'Ijtimoiy himoya',    'Социальная защита',  'family_restroom', 3),
    ('civil',       'Iste''molchi huquqi', 'Права потребителей', 'shopping_bag',  4),
    ('real_estate', 'Kadastr va Uy-joy',  'Кадастр и жильё',    'home_work',      5)
ON CONFLICT (id) DO NOTHING;

-- 5. SEED OFFICIAL GOVERNMENT SERVICES & VERIFIED GUIDES
INSERT INTO public.citizen_services (
    id, category_id, title, department, description, 
    cost_bhm_percent, is_free, processing_days, required_documents, 
    online_url, deadline_law_reference, source_url, legal_basis, 
    last_verified_at, status, is_popular
)
VALUES 
(
    'service_traffic_discount',
    'traffic',
    'YHQ jarimalariga 50% chegirma olish va shikoyat berish',
    'IIV Yo''l harakati xavfsizligi xizmati',
    'Radar yoki inspektor tomonidan yozilgan ma''muriy jarimani 15 kun ichida to''lab 50% chegirmadan foydalanish yoki 10 kun ichida tuman ma''muriy sudiga shikoyat qilish tartibi.',
    0.0,
    TRUE,
    10,
    ARRAY['Jarima to''g''risidagi qaror raqami', 'Haydovchilik guvohnomasi / Tex-pasport', 'Radar joylashuvi va fotosurat dalillari'],
    'https://my.gov.uz/uz/service/469',
    'MJtK 332-1-modda (50% chegirma 15 kunda) va 315-modda (shikoyat 10 kunda)',
    'https://lex.uz/docs/97661#1184234',
    'O''zbekiston Respublikasining Ma''muriy javobgarlik to''g''risidagi kodeksi 332-1-moddasi',
    now(),
    'active',
    TRUE
),
(
    'service_labor_complaint',
    'labor',
    'Noqonuniy ishdan bo''shatish yoki oylik ish haqi bo''yicha shikoyat',
    'Kambag''allikni qisqartirish va bandlik vazirligi (Davlat mehnat inspeksiyasi)',
    'Ish beruvchi tomonidan ish haqi to''lanmaganligi, noqonuniy bo''shatilganligi yoki majburiy mehnatga jalb etilganligi bo''yicha Davlat mehnat inspeksiyasiga shikoyat va sudga da''vo kiritish tartibi.',
    0.0,
    TRUE,
    15,
    ARRAY['Mehnat shartnomasi va buyruq nusxasi', 'Bank hisobvarag''idan ko''chirma', 'Ish beruvchiga berilgan yozma ariza nusxasi'],
    'https://my.gov.uz/uz/service/523',
    'Mehnat kodeksi 560-modda (Sudga da''vo muddati: 1 oy)',
    'https://lex.uz/docs/6257288#6273110',
    'O''zbekiston Respublikasining Mehnat kodeksi 560-moddasi',
    now(),
    'active',
    TRUE
),
(
    'service_child_subsidy',
    'family',
    'Bolalar nafaqasi va moddiy yordam tayinlash (Yagona reestr)',
    'Ijtimoiy himoya milliy agentligi',
    'Kam ta''minlangan oilalarga bolalar nafaqasi va moddiy yordam tayinlash bo''yicha ''Ijtimoiy himoya yagona reestri'' axborot tizimi orqali elektron ariza topshirish tartibi.',
    0.0,
    TRUE,
    7,
    ARRAY['Ariza beruvchi va oila a''zolarining JSHSHIR (PINFL) raqamlari', 'Bolalarning tug''ilganlik guvohnomalari', 'Daromadlar to''g''risidagi ma''lumotlar (avtomatik olinadi)'],
    'https://my.gov.uz/uz/service/670',
    'Vazirlar Mahkamasining 2021-yil 21-oktabrdagi 654-son qarori',
    'https://lex.uz/docs/5688536',
    'Vazirlar Mahkamasining 654-son qarori bilan tasdiqlangan Nizom',
    now(),
    'active',
    TRUE
),
(
    'service_consumer_refund',
    'civil',
    'Nuqsonli tovarni almashtirish va to''langan pulni qaytarish',
    'Raqobatni rivojlantirish va iste''molchilar huquqlarini himoya qilish qo''mitasi',
    'Xarid qilingan sifatsiz yoki talabga javob bermaydigan tovar uchun sotuvchidan pulni qaytarib olish, almashtirish yoki bepul ta''mirlash talabi bilan murojaat qilish.',
    0.0,
    TRUE,
    10,
    ARRAY['Tovar cheki, kvitansiya yoki elektron to''lov kodi', 'Kafolat taloni (mavjud bo''lsa)', 'Sotuvchiga yozilgan pretenziya nusxasi'],
    'https://consumer.gov.uz',
    'Iste''molchilar huquqlarini himoya qilish to''g''risidagi Qonun 18-modda (10 kun)',
    'https://lex.uz/docs/44265#44389',
    'O''zbekiston Respublikasining ''Iste''molchilarning huquqlarini himoya qilish to''g''risida''gi Qonuni 18-moddasi',
    now(),
    'active',
    FALSE
),
(
    'service_cadastre_extract',
    'real_estate',
    'Ko''chmas mulk kadastr pasportini rasmiylashtirish va ko''chirma olish',
    'Davlat kadastrlari palatasi',
    'Uy, turar joy, bino yoki yer uchastkasi uchun yangi namunadagi kadastr pasportini shakllantirish va mulk huquqini davlat ro''yxatidan o''tkazish.',
    1.25,
    FALSE,
    5,
    ARRAY['Mulkka egalik huquqini tasdiqlovchi hujjat (oldi-sotdi shartnomasi, order, meros)', 'Mulk egasining pasport yoki ID karta nusxasi'],
    'https://my.gov.uz/uz/service/101',
    'Vazirlar Mahkamasining 2020-yil 2-sentabrdagi 535-son qarori',
    'https://lex.uz/docs/4977467',
    'Vazirlar Mahkamasining 535-son qarori bilan tasdiqlangan Davlat xizmati reglamenti',
    now(),
    'active',
    FALSE
),
(
    'service_notary_power_of_attorney',
    'civil',
    'Elektron notarius orqali ishonchnoma (Doverennost) rasmiylashtirish',
    'Adliya vazirligi (E-Notarius)',
    'Avtotransport vositasini boshqarish yoki mulkni tasarruf etish bo''yicha videoaloqa orqali uydan chiqmasdan notarial tasdiqlangan elektron ishonchnoma berish.',
    0.50,
    FALSE,
    1,
    ARRAY['Mulk egasi va ishonchli shaxsning ID karta / Pasport ma''lumotlari', 'Tex-pasport yoki mulk hujjati', 'OneID biometrik tasdiq'],
    'https://e-notarius.uz',
    '''Notariat to''g''risida''gi Qonun va VMQ-741-son qarori',
    'https://lex.uz/docs/5110594',
    'Vazirlar Mahkamasining 2020-yil 18-noyabrdagi 741-son qarori',
    now(),
    'active',
    TRUE
)
ON CONFLICT (id) DO UPDATE SET
    title = EXCLUDED.title,
    department = EXCLUDED.department,
    description = EXCLUDED.description,
    cost_bhm_percent = EXCLUDED.cost_bhm_percent,
    is_free = EXCLUDED.is_free,
    processing_days = EXCLUDED.processing_days,
    required_documents = EXCLUDED.required_documents,
    online_url = EXCLUDED.online_url,
    deadline_law_reference = EXCLUDED.deadline_law_reference,
    source_url = EXCLUDED.source_url,
    legal_basis = EXCLUDED.legal_basis,
    last_verified_at = EXCLUDED.last_verified_at,
    status = EXCLUDED.status,
    is_popular = EXCLUDED.is_popular,
    updated_at = now();

-- 6. SEED SERVICE STEPS
DELETE FROM public.service_steps WHERE service_id IN (
    'service_traffic_discount', 'service_labor_complaint', 'service_child_subsidy',
    'service_consumer_refund', 'service_cadastre_extract', 'service_notary_power_of_attorney'
);

INSERT INTO public.service_steps (service_id, step_number, title, description, warning_note, action_url, step_type)
VALUES
-- Traffic discount steps
('service_traffic_discount', 1, 'Qaror bilan tanishish', 'my.gov.uz yoki YHXX rasmiy boti orqali qoidabuzarlik fotosurati va radar sertifikatini tekshiring.', NULL, 'https://my.gov.uz/uz/service/469', 'online'),
('service_traffic_discount', 2, '50% chegirma bilan to''lash', 'Qaror chiqarilgan kundan boshlab 15 kun ichida jarimaning 50% qismini to''lang (Payme, Click yoki bank orqali).', '15 kun o''tgach jarima to''liq 100% miqdorda undiriladi.', 'https://payme.uz', 'payment'),
('service_traffic_discount', 3, 'Norozilik bo''lsa shikoyat arizasi', 'Qaror nusxasi topshirilgan kundan boshlab 10 kun ichida tuman ma''muriy sudiga yoki yuqori organiga ariza bering.', '10 kunlik shikoyat muddati o''tkazib yuborilsa, uzrli sabablar bilan tiklanishi talab etiladi.', NULL, 'appeal'),

-- Labor complaint steps
('service_labor_complaint', 1, 'Ish beruvchiga yozma pretenziya berish', 'Ish beruvchiga 2 nusxada yozma ogohlantirish arizasi topshiring va 1 nusxasiga imzo/pechat qo''ydirib oling.', NULL, NULL, 'offline'),
('service_labor_complaint', 2, 'Davlat mehnat inspeksiyasiga murojaat', 'my.gov.uz portali orqali yoki 1176 ishonch telefoniga rasmiy tekshiruv talabi bilan shikoyat yuboring.', NULL, 'https://my.gov.uz/uz/service/523', 'online'),
('service_labor_complaint', 3, 'Sudga da''vo arizasi kiritish', 'Ishdan bo''shatish to''g''risidagi buyruq chiqqan kundan boshlab 1 oy ichida fuqarolik sudiga da''vo bering. Ishchi xodimlar sud bojidan ozod qilinadi!', '1 oylik da''vo muddati o''tkazib yuborilsa, sud arizani rad etishi mumkin.', NULL, 'appeal'),

-- Child subsidy steps
('service_child_subsidy', 1, 'Daromad mezonini baholash', 'Oilaning har bir a''zosiga to''g''ri keladigan oylik daromad minimal iste''mol xarajatlaridan (jon boshiga belgilangan miqdor) oshmasligi shart.', NULL, NULL, 'online'),
('service_child_subsidy', 2, 'my.gov.uz orqali ariza yuborish', 'OneID orqali tizimga kirib, oila a''zolarini ko''rsatgan holda elektron ariza yuboring. Barcha soliq, kadastr va mol-mulk ma''lumotlari avtomatik tekshiriladi.', NULL, 'https://my.gov.uz/uz/service/670', 'online'),

-- Consumer refund steps
('service_consumer_refund', 1, 'Sotuvchiga tovar va chek bilan murojaat', 'Xarid qilingan kundan boshlab 10 kun ichida tovar ko''rinishi saqlangan holda sotuvchiga murojaat qiling.', NULL, NULL, 'offline'),
('service_consumer_refund', 2, 'Raqobat qo''mitasiga 1159 orqali shikoyat', 'Agar sotuvchi qonuniy talabni bajarishdan bosh tortsa, 1159 ishonch telefoni yoki consumer.gov.uz orqali xabar qiling.', NULL, 'https://consumer.gov.uz', 'appeal'),

-- Cadastre steps
('service_cadastre_extract', 1, 'Arizani elektron topshirish', 'my.gov.uz orqali kadastr obyekti manzilini kiritib ariza yuboring va davlat bojini to''lang.', NULL, 'https://my.gov.uz/uz/service/101', 'online'),
('service_cadastre_extract', 2, 'Mutaxassis o''lchov o''tkazishi va pasport shakllanishi', 'Kadastr xodimi kelib obyektni o''lchaydi va elektron pasportni QR-kod bilan yaratadi.', NULL, NULL, 'offline'),

-- Notary steps
('service_notary_power_of_attorney', 1, 'E-Notarius portaliga kirish va ariza to''ldirish', 'e-notarius.uz portaliga OneID orqali kiring, ishonchnoma turini tanlang va ishonchli shaxs ma''lumotlarini kiriting.', NULL, 'https://e-notarius.uz', 'online'),
('service_notary_power_of_attorney', 2, 'Videoaloqa orqali notarius bilan tasdiqlash', 'Belgilangan vaqtda notarius bilan videoaloqaga chiqing, shaxsingizni tasdiqlang va elektron imzo bilan hujjatni imzolang.', 'Elektron ishonchnoma qog''oz nusxasi bilan bir xil yuridik kuchga ega (QR-kod orqali tekshiriladi).', 'https://e-notarius.uz', 'online');
