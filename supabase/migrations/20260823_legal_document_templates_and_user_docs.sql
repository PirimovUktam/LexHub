-- ==============================================================================
-- MIGRATION: 20260823_legal_document_templates_and_user_docs.sql
-- LexHub Platform — Smart Legal Document Templates & User Saved Documents Migration
-- Fully Self-Healing, Lex.uz Legal Grounding & Strict Owner RLS
-- ==============================================================================

-- 1. RECONCILE COLUMNS ON document_templates
CREATE TABLE IF NOT EXISTS public.document_templates (
    id VARCHAR(64) PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    category VARCHAR(128) NOT NULL,
    description TEXT NOT NULL,
    target_authority VARCHAR(255) NOT NULL,
    required_fields JSONB NOT NULL,
    body_template TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE public.document_templates ADD COLUMN IF NOT EXISTS title VARCHAR(255);
ALTER TABLE public.document_templates ADD COLUMN IF NOT EXISTS category VARCHAR(128);
ALTER TABLE public.document_templates ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE public.document_templates ADD COLUMN IF NOT EXISTS target_authority VARCHAR(255);
ALTER TABLE public.document_templates ADD COLUMN IF NOT EXISTS required_fields JSONB;
ALTER TABLE public.document_templates ADD COLUMN IF NOT EXISTS body_template TEXT;
ALTER TABLE public.document_templates ADD COLUMN IF NOT EXISTS legal_basis TEXT;
ALTER TABLE public.document_templates ADD COLUMN IF NOT EXISTS source_url TEXT;
ALTER TABLE public.document_templates ADD COLUMN IF NOT EXISTS last_verified_at TIMESTAMPTZ DEFAULT now() NOT NULL;
ALTER TABLE public.document_templates ADD COLUMN IF NOT EXISTS status VARCHAR(32) DEFAULT 'active' NOT NULL;
ALTER TABLE public.document_templates ADD COLUMN IF NOT EXISTS is_popular BOOLEAN DEFAULT FALSE NOT NULL;
ALTER TABLE public.document_templates ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now() NOT NULL;

-- 2. CREATE TABLE: user_documents (SAVED USER DOCUMENTS WITH STRICT PRIVACY)
CREATE TABLE IF NOT EXISTS public.user_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    template_id VARCHAR(64) REFERENCES public.document_templates(id) ON DELETE SET NULL,
    title VARCHAR(255) NOT NULL,
    category VARCHAR(128) NOT NULL,
    form_values JSONB NOT NULL DEFAULT '{}'::jsonb,
    generated_text TEXT NOT NULL,
    legal_basis TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE public.user_documents ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE public.user_documents ADD COLUMN IF NOT EXISTS template_id VARCHAR(64) REFERENCES public.document_templates(id) ON DELETE SET NULL;
ALTER TABLE public.user_documents ADD COLUMN IF NOT EXISTS title VARCHAR(255);
ALTER TABLE public.user_documents ADD COLUMN IF NOT EXISTS category VARCHAR(128);
ALTER TABLE public.user_documents ADD COLUMN IF NOT EXISTS form_values JSONB DEFAULT '{}'::jsonb;
ALTER TABLE public.user_documents ADD COLUMN IF NOT EXISTS generated_text TEXT;
ALTER TABLE public.user_documents ADD COLUMN IF NOT EXISTS legal_basis TEXT;
ALTER TABLE public.user_documents ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now() NOT NULL;
ALTER TABLE public.user_documents ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now() NOT NULL;

-- 3. INDICES
CREATE INDEX IF NOT EXISTS idx_document_templates_category ON public.document_templates(category);
CREATE INDEX IF NOT EXISTS idx_document_templates_popular ON public.document_templates(is_popular);
CREATE INDEX IF NOT EXISTS idx_user_documents_user_id ON public.user_documents(user_id);
CREATE INDEX IF NOT EXISTS idx_user_documents_template_id ON public.user_documents(template_id);

-- 4. ROW LEVEL SECURITY
ALTER TABLE public.document_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_documents ENABLE ROW LEVEL SECURITY;

-- Document templates are readable by everyone
DROP POLICY IF EXISTS "Templates are readable by everyone" ON public.document_templates;
CREATE POLICY "Templates are readable by everyone" ON public.document_templates 
FOR SELECT USING (true);

-- Only Admins can modify templates
DROP POLICY IF EXISTS "Admins can manage templates" ON public.document_templates;
CREATE POLICY "Admins can manage templates" ON public.document_templates 
FOR ALL USING (
    EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE id = auth.uid() AND role::text IN ('admin', 'moderator')
    ) OR current_user = 'service_role'
);

-- Strict User Document Isolation: Only Document Owner can SELECT, INSERT, UPDATE, DELETE
DROP POLICY IF EXISTS "Users can view own documents" ON public.user_documents;
CREATE POLICY "Users can view own documents" ON public.user_documents 
FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can create own documents" ON public.user_documents;
CREATE POLICY "Users can create own documents" ON public.user_documents 
FOR INSERT WITH CHECK (auth.role() = 'authenticated' AND auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own documents" ON public.user_documents;
CREATE POLICY "Users can update own documents" ON public.user_documents 
FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own documents" ON public.user_documents;
CREATE POLICY "Users can delete own documents" ON public.user_documents 
FOR DELETE USING (auth.uid() = user_id);

-- 5. SEED OFFICIAL LEGAL TEMPLATES GROUNDED IN LEX.UZ
INSERT INTO public.document_templates (
    id, title, category, description, target_authority, 
    legal_basis, source_url, last_verified_at, status, is_popular,
    required_fields, body_template
)
VALUES
(
    'template_consumer_refund',
    'Sifatsiz tovar uchun pulni qaytarish talabnomasi',
    'Iste''molchi huquqlari',
    'Nuqsonli yoki sifatsiz tovar sotib olganda sotuvchiga pulni to''liq qaytarishni talab qiluvchi rasmiy da''vo arizasi.',
    'Savdo do''koni yoki sotuvchi ma''muriyatiga',
    'O''zbekiston Respublikasining ''Iste''molchilarning huquqlarini himoya qilish to''g''risida''gi Qonuni 13, 18-moddalari',
    'https://lex.uz/docs/44265#44389',
    now(),
    'active',
    TRUE,
    '[
        {"id": "store_name", "label": "Do''kon yoki sotuvchi nomi (MCHJ/YATT)", "placeholder": "Masalan: ''MediaPark'' do''koni ma''muriyatiga", "field_type": "text", "is_required": true},
        {"id": "applicant_name", "label": "Foydalanuvchi (Ariza beruvchi) F.I.Sh", "placeholder": "Masalan: Karimov Anvar Jasurovich", "field_type": "text", "is_required": true},
        {"id": "applicant_address", "label": "Yashash manzili va telefon raqami", "placeholder": "Masalan: Toshkent sh., Chilonzor t., 12-uy, +998901234567", "field_type": "text", "is_required": true},
        {"id": "purchase_date", "label": "Tovar xarid qilingan sana", "placeholder": "Masalan: 12.08.2026", "field_type": "date", "is_required": true},
        {"id": "product_name", "label": "Tovar nomi va modeli", "placeholder": "Masalan: ''Artel'' kir yuvish mashinasi", "field_type": "text", "is_required": true},
        {"id": "product_price", "label": "To''langan pul miqdori (so''mda)", "placeholder": "Masalan: 4 500 000 so''m", "field_type": "number", "is_required": true},
        {"id": "defect_details", "label": "Aniqlangan nuqson va kamchiliklar tavsifi", "placeholder": "Masalan: Ishlatish jarayonida suv isitish tizimi ishlamay qoldi...", "field_type": "multiline", "is_required": true}
    ]'::jsonb,
    'KIMGA: {{store_name}}
KIMDAN: {{applicant_name}}
MANZIL: {{applicant_address}}

TALABNOMA (PRETENZIYA)
(Sifatsiz tovar uchun to''langan pul mablag''ini qaytarish to''g''risida)

Men, {{applicant_name}}, {{purchase_date}} sanasida Sizning savdo do''koningizdan {{product_price}} evaziga {{product_name}} tovarini xarid qilgan edim.

Biroq, tovarni foydalanish jarayonida quyidagi jiddiy nuqsonlar aniqlandi:
{{defect_details}}

O''zbekiston Respublikasining "Iste''molchilarning huquqlarini himoya qilish to''g''risida"gi Qonunining 13 va 18-moddalariga muvofiq, iste''molchi nuqsonli tovar sotilganda shartnomani bekor qilish va to''langan pul summasini to''liq qaytarib olishni talab qilishga haqlidir.

Yuqoridagilardan kelib chiqib, SIZDAN:
1. {{product_name}} tovari uchun to''langan {{product_price}} miqdoridagi pul mablag''ini 10 kunlik muddatda menga to''liq qaytarishingizni;
2. Mazkur talabnoma yuzasidan qonunda belgilangan muddatda yozma javob berishingizni talab qilaman.

Aks holda, ushbu masala yuzasidan Iste''molchilar huquqlarini himoya qilish agentligiga hamda Fuqarolik ishlari bo''yicha sudga da''vo arizasi kiritilishini va barcha sud xarajatlari hamda ma''naviy zarar Sizdan undirilishini ma''lum qilaman.

Ilova: 
1. Xarid cheki / kvitansiya nusxasi.
2. Kafolat taloni nusxasi.

Sana: {{purchase_date}}
Imzo: ______________ ({{applicant_name}})'
),
(
    'template_labor_complaint',
    'Noqonuniy ishdan bo''shatish ustidan shikoyat',
    'Mehnat huquqi',
    'Ish beruvchining asossiz bo''shatish buyrug''i ustidan Mehnat inspeksiyasi yoki Sudga kiritiladigan rasmiy shikoyat arizasi.',
    'Davlat mehnat inspeksiyasi boshlig''iga / Fuqarolik sudiga',
    'O''zbekiston Respublikasining Mehnat kodeksi 161, 437, 560-moddalari',
    'https://lex.uz/docs/6257288#6273110',
    now(),
    'active',
    TRUE,
    '[
        {"id": "authority_name", "label": "Shikoyat yuborilayotgan organ", "placeholder": "Masalan: Davlat mehnat inspeksiyasiga / Toshkent sh. Fuqarolik sudiga", "field_type": "text", "is_required": true},
        {"id": "applicant_name", "label": "Ariza beruvchi xodim F.I.Sh", "placeholder": "Masalan: Aliyev Botir Salimovich", "field_type": "text", "is_required": true},
        {"id": "applicant_phone", "label": "Telefon raqami va manzili", "placeholder": "Masalan: +998901112233, Toshkent sh., Yunusobod t.", "field_type": "text", "is_required": true},
        {"id": "company_name", "label": "Ish beruvchi tashkilot nomi", "placeholder": "Masalan: ''Grand Logistics'' MCHJ", "field_type": "text", "is_required": true},
        {"id": "job_title", "label": "Egallab turgan lavozimingiz", "placeholder": "Masalan: Bosh hisobchi", "field_type": "text", "is_required": true},
        {"id": "dismissal_date", "label": "Bo''shatish to''g''risida buyruq sanasi", "placeholder": "Masalan: 01.08.2026", "field_type": "date", "is_required": true},
        {"id": "violation_reason", "label": "Qonunbuzarlik holatlari tavsifi", "placeholder": "Masalan: Ish beruvchi ogohlantirish bermasdan va kasaba uyushmasi roziligisiz noqonuniy bo''shatdi...", "field_type": "multiline", "is_required": true}
    ]'::jsonb,
    'KIMGA: {{authority_name}}
KIMDAN: {{applicant_name}}
MANZIL VA TEL: {{applicant_phone}}

SHIKOYAT ARIZASI
(Noqonuniy ishdan bo''shatish buyrug''ini bekor qilish va ishga tiklash to''g''risida)

Men, {{applicant_name}}, {{company_name}} tashkilotida {{job_title}} lavozimida ishlab kelganman.

Biroq, {{dismissal_date}} sanasida ish beruvchi tomonidan mehnat qonunchiligi talablariga zid ravishda mehnat shartnomasi bekor qilindi.
Qonunbuzarlik tafsilotlari:
{{violation_reason}}

O''zbekiston Respublikasining Mehnat kodeksining 161, 437 va 560-moddalariga muvofiq, ish beruvchi tashabbusi bilan shartnomani bekor qilishda qonuniy asoslar va kafolatlar ta''minlanishi shart. Noqonuniy bo''shatilgan xodim avvalgi ishiga tiklanishi hamda majburiy progul vaqti uchun o''rtacha oylik ish haqi undirilishi lozim.

Yuqoridagilarga asosan, SIZDAN:
1. Mazkur qonunbuzarlik holatini joyiga chiqqan holda o''rganib chiqishingizni;
2. {{company_name}} ma''muriyatining {{dismissal_date}} dagi noqonuniy buyrug''ini bekor qilish va meni {{job_title}} lavozimiga qayta tiklash to''g''risida ko''rsatma berishingizni (sudga da''vo kiritishingizni) so''rayman.

Ilova: 
1. Pasport nusxasi.
2. Mehnat shartnomasi va buyruq nusxasi.

Sana: {{dismissal_date}}
Imzo: ______________ ({{applicant_name}})'
),
(
    'template_alimony_petition',
    'Aliment undirish to''g''risida sud buyrug''i arizasi',
    'Oila huquqi',
    'Voyaga yetmagan farzandlar ta''minoti uchun ota/onadan qonunda belgilangan miqdorda aliment undirish to''g''risida fuqarolik sudiga ariza.',
    'Fuqarolik ishlari bo''yicha tumanlararo sudiga',
    'O''zbekiston Respublikasi Oila kodeksi 96, 99, 136-moddalari',
    'https://lex.uz/docs/104720#107382',
    now(),
    'active',
    TRUE,
    '[
        {"id": "court_name", "label": "Sud nomi", "placeholder": "Masalan: Fuqarolik ishlari bo''yicha Mirzo Ulug''bek tumanlararo sudiga", "field_type": "text", "is_required": true},
        {"id": "applicant_name", "label": "Undiruvchi (Ariza beruvchi) F.I.Sh", "placeholder": "Masalan: Karimova Dilnoza Anvarovna", "field_type": "text", "is_required": true},
        {"id": "applicant_address", "label": "Undiruvchi manzili va tel", "placeholder": "Masalan: Toshkent sh., Buyuk Ipak Yo''li 45, +998901234567", "field_type": "text", "is_required": true},
        {"id": "debtor_name", "label": "Qarzdor (Javobgar) F.I.Sh", "placeholder": "Masalan: Karimov Rustam Botirovich", "field_type": "text", "is_required": true},
        {"id": "debtor_address", "label": "Qarzdorning yashash yoki ish joyi", "placeholder": "Masalan: Toshkent sh., Chilonzor 5-mavze 12-uy", "field_type": "text", "is_required": true},
        {"id": "children_info", "label": "Voyaga yetmagan bolalar F.I.Sh va tug''ilgan sanalari", "placeholder": "Masalan: Karimov Jasur (2018-yil) va Karimova Madina (2021-yil)", "field_type": "multiline", "is_required": true}
    ]'::jsonb,
    'KIMGA: {{court_name}}
UNDIRUVCHI: {{applicant_name}}
MANZIL: {{applicant_address}}
QARZDOR: {{debtor_name}}
QARZDOR MANZILI: {{debtor_address}}

SUD BUYRUG''I CHIQARISH TO''G''RISIDA ARIZA
(Voyaga yetmagan bolalar ta''minoti uchun aliment undirish haqida)

Men va javobgar {{debtor_name}} qonuniy nikohdan o''tganmiz (yoki birgalikda yashab kelganmiz). O''rtamizdagi nikohdan quyidagi voyaga yetmagan farzandlarimiz bor:
{{children_info}}

Hozirgi kunda bolalar to''liq mening qaramog''imda bo''lib, qarzdor {{debtor_name}} farzandlarining moddiy ta''minotida ishtirok etmayapti va ixtiyoriy ravishda yordam berishdan bosh tortmoqda.

O''zbekiston Respublikasi Oila kodeksining 96-moddasiga binoan, ota-ona voyaga yetmagan bolalariga ta''minot berishi shart. Kodeksning 99-moddasiga ko''ra, voyaga yetmagan bolalar uchun aliment ota-onaning har oylik ish haqi va boshqa daromadining tegishli qismi miqdorida undiriladi.

Yuqoridagilarga asosan, O''zbekiston Respublikasi Fuqarolik protsessual kodeksining 170-172-moddalariga muvofiq, SIZDAN:
Qarzdor {{debtor_name}}dan mening foydamga voyaga yetmagan farzandlarimiz ta''minoti uchun har oylik daromadining qonunda belgilangan qismi miqdorida bolalar voyaga yetguniga qadar aliment undirish to''g''risida SUD BUYRUG''I chiqarishingizni so''rayman.

Ilova:
1. Nikoh to''g''risidagi guvohnoma (yoki ajrim) nusxasi.
2. Bolalarning tug''ilganlik to''g''risidagi guvohnomalari nusxalari.
3. Mahalla yoki yashash joyidan bolalar mening qaramog''imdaligi haqida ma''lumotnoma.

Sana: {{created_at}}
Imzo: ______________ ({{applicant_name}})'
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
