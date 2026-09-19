# 1-bosqich: database tuzatishlari va qayta tiklash

> 2026-09-20 qayta tekshiruv: [davomiy natija](STAGE1_CONTINUATION.md).
> Production migration gate **BLOCKED**: PITR o'chiq, restore dalili yo'q.

**Holat: repository tayyor; production'ga qo'llanmagan.**
2026-09-19 kuni faqat Supabase MCP `SELECT` va `list_migrations` ishlatildi.
Production'da hech qanday yozish, migratsiya yoki sinov foydalanuvchisi yaratilmadi.

## Jonli holatdan olingan dalillar

- `answers` UPDATE policy savol egasiga ham butun javobni yangilash ruxsatini
  beradi; acceptance trigger faqat `is_accepted`ni tekshiradi. Qo'shimcha legacy
  INSERT policy faqat authenticated rolini tekshiradi, muallifni tekshirmaydi.
- `expert_profiles` INSERT policy faqat `auth.uid() = user_id`; sensitive guard
  faqat UPDATE'ga ulangan. Birinchi yozuvdagi tasdiq va reyting himoyasiz.
- `book_consultation` faqat `expert_profiles.verified_at`ga ishonadi;
  `consultations.fee` NOT NULL/defaultsiz, RPC INSERT esa `fee` yubormaydi.
- Jonli `categories` UUID katalogi, `profiles.specialization/license_number`,
  `official_sources` va ayrim `answers` ustunlari migratsiya boshlang'ich
  sxemasida yo'q. `questions.category_id` jonli bazada UUID/NOT NULL.
- Migration history'da 27 yozuv, oldingi repository'da 34 migration bor.
  `20260830080000`, `20260830090000`, `20260830100000`, `20260830110000`,
  `20260830120000`, `20260903000000`, `20260903001000` history'da yo'q.
  Ulardan ayrimlarining obyektlari production'da mavjud. History'ni ko'r-ko'rona
  qayta ijro etish yoki `db push --include-all` ishlatish mumkin emas.
- `labor_art_560` va `service_labor_complaint` hanuz 1 oy deb yozilgan;
  xizmatning 3-qadami muddatni buyruq chiqqan kundan boshlaydi.
  `const_art_28` esa 27/28-moddalarni aralashtirgan. To'rtta chunk havolasi eski.

## Repository'da tayyorlangan tuzatishlar

`20260919001000_stage1_authorization_and_booking.sql`:

- Savol egasi faqat qabul qilish holatini o'zgartiradi. Javob muallifi matni va
  manbalarini tahrirlaydi; identitet va hisoblagichlar himoyalangan.
- Joriy `PATCH {is_accepted: true}` API saqlanadi. Muallif, moderator tahriri,
  qabul qilingan javobni almashtirish va ovoz hisoblagichi lokal sinalgan.
- Restrictive RLS eski permissive policylarni ham cheklaydi. Trigger INVOKER
  bo'lib, haqiqiy DB rolini tekshiradi.
- Ekspert INSERT pending/unrated bo'lishi shart; tekshiruv/rejection/reytingni
  mijoz bera olmaydi. Ariza va moderatsiya RPC'lari o'zgarmagan.
- Bron profilning tasdiqlangan roli va verification holatini ham tekshiradi;
  haqiqiy narx `fee` hamda tiyin snapshotiga yoziladi. Narx to'qilmaydi.

`20260919002000_reviewed_legal_excerpts_and_deadlines.sql`:

- Konstitutsiya 27/28/29 va Mehnat kodeksi 560-modda parchalari, URL'lari va
  mehnat xizmatidagi muddat/3-qadam tuzatiladi. Mehnat shikoyati shablonidagi
  aloqasiz 437-modda o'rniga 561-modda havolasi qo'yiladi; formalar saqlanadi.
- Asoslar: <https://lex.uz/docs/6445145#6445434>,
  <https://lex.uz/docs/6445145#6445509>,
  <https://lex.uz/docs/6445145#6445518>,
  <https://lex.uz/docs/6257288#6269139>,
  <https://lex.uz/docs/6257288#6269151>. Matnlar 2026-09-19 kuni rasmiy
  sahifalar bilan tekshirilib, client korpusidagi nusxaga tenglashtirilgan.
- Mavjud matn o'lchangan eski yoki tasdiqlangan yangi nusxaga mos kelmasa,
  butun transaction bekor bo'ladi. Noma'lum tahrirlar ustiga yozilmaydi.
- Toza bazada faqat shu to'rtta tekshirilgan parcha seed qilinadi. Bu butun
  huquqiy korpus tiklanganini anglatmaydi.
- Matn o'zgarsa eski embedding NULL qilinadi; uni serverda qayta hisoblash
  alohida ish. `last_verified_at` sun'iy yangilanmaydi: xizmatning boshqa
  tafsilotlari bu bosqichda to'liq qayta tekshirilmagan.

## Toza mahalliy bazani takror yaratish

`supabase/bootstrap/rebuild.sql` — yagona **bo'sh mahalliy** psql kirish nuqtasi.
U loopback/mahalliy ulanishni va ilova jadvallari hali yo'qligini tekshiradi,
tarixiy migratsiyalarni tartib bilan o'qiydi; base'dan keyin
`replay_prerequisites.sql` jonli sxemada o'lchangan yetishmayotgan qismlarni yaratadi.
Besh ochiq kategoriya haqiqiy katalog nomlari/sluglari bilan seed qilinadi.
Foydalanuvchi, ekspert, savol va konsultatsiya ma'lumotlari ko'chirilmaydi.

Tarixiy `20260830100000` faylda bitta assertion tuzatildi: INSERT policy uchun
`qual` tabiatan NULL bo'ladi; endi uning `with_check` qiymati tekshiriladi.
Oldingi shart to'g'ri owner INSERT'ni ochiq policy deb, clean replay'ni yiqitardi.
Ruxsatlar o'zgartirilmadi. Boshqa tarixiy fayllar qayta yozilmadi.

Oldindan mavjud **bo'sh lokal Supabase** Postgres'da, tegishli auth obyektlari,
rollar, default grantlar va `vector`, `uuid-ossp`, `pg_trgm`, `btree_gist`
extensionlari mavjud bo'lsa, psql orqali `rebuild.sql`ni ishga tushirish mumkin.
`supabase/schema.sql` tarixiy ma'lumotnoma; deployment kirish nuqtasi emas.
Oddiy `supabase db reset`ning o'zi bootstrap ko'prigini bajarmaydi.

Docker talab qilmaydigan mahalliy sinov:

```powershell
npm install --prefix build/stage1_db --no-save --ignore-scripts @electric-sql/pglite@0.5.8 @electric-sql/pglite-pgvector@0.0.9
node tool/database/verify_stage1_db.mjs
python tool/validate_sql_syntax.py
flutter test test/core/security/stage1_database_contract_test.dart
```

Paketlar faqat ignored `build/` ichidagi sinov asboblari; Flutter dependencylari
o'zgarmaydi. Runner **in-memory PostgreSQL** yaratadi, connection string olmaydi
va remote bazaga ulana olmaydi. Auth interfeysi/grantlari lokal fixture bilan
taqlid qilinadi; GoTrue, PostgREST va Supabase xizmatlari taqlid qilinmaydi.

## Tekshiruv dalili va chegarasi

- 36 migration toza lokal PostgreSQL'da tartib bilan o'tdi; 23 public jadval,
  5 kategoriya tekshirildi. Ikkala yangi migration qayta ijro etilganda o'tdi.
- 22 runtime regression guruhi: mualliflik, accept/switch, RLS, real mavjud
  qatorni tahrirlash, INSERT spoofing, apply/approve, booking fee, anon RPC,
  eski/yangi huquqiy parcha, noma'lum/NULL drift, transaction rollback va
  shablonning havola/forma yaxlitligi, tasdiqlangan litsenziya qulfi va
  rad etish holati orqali cooldown'ni chetlab o'tishga qarshi sinovlar.
- `current_user=authenticated`, `session_user=authenticator` alohida assertion
  bilan tekshiriladi. Superuser sifatida o'tgan test RLS isboti deb olinmaydi.
- Muallif guardi, expert INSERT guardi, `fee`, NULL drift guardi, shablon
  havolasi, litsenziya qulfi, rejection guardi va caller allowlist ataylab
  buzilgan sakkizta holatda test QIZIL bo'ldi; fayl har safar
  asl baytlariga tiklanib SHA-256 solishtirildi.
- Bu **lokal SQL runtime isboti**. Production RLS natijasi, to'liq Supabase
  restore, production load/concurrency va PostgREST integratsiyasi hali
  `NOT VERIFIED`. To'liq backup/PITR restore sinovi bajarilmadi.

## Production'da alohida bajariladigan ishlar

1. DBA migration history va haqiqiy DDL/grantlarni solishtirsin; backup va
   tiklash imkonini tekshirsin. Bootstrap fayllarini yoki eski cleanup/test
   migrationlarini mavjud production bazaga yubormasin.
2. Avval staging'da tekshirib, alohida yozish ruxsati olingach faqat ikkita
   yangi `20260919001000` va `20260919002000` candidate'ni tartib bilan qo'llasin.
   Ular hozir **qo'llanmagan**. History reconciliation alohida, tekshirilgan amal.
3. Ikki oddiy hisob va moderator orqali ruxsatli/taqiqlangan amallarni
   staging'da qayta tekshirsin; production'da avval metadata SELECT bilan guard,
   ACL va matnlarni tasdiqlasin. Mavjud ekspertlarning noto'g'ri oldingi
   verification/rating qiymatlari alohida ko'rib chiqilsin — migration ularni
   taxmin bilan tozalamaydi. O'zgargan parchalarning embeddinglari qayta hisoblansin.

**Production database tuzatilmadi.** Tayyor fayl, lokal test va parser natijasi
remote qo'llanish isboti emas. Qo'shimcha P2 bron/refund muammolari bu bosqichga
qo'shilmadi va saqlanib turibdi.

## 2026-09-20: production migration gate va tayyor amallar

**REQUIRES EXPLICIT APPROVAL. Hozir production'ga qo'llash mumkin emas.**
MCP project identity lokal production konfiguratsiyasiga mos; DB roli
`supabase_read_only_user`, `transaction_read_only=on`, PostgreSQL 17.6.
Management API: `pitr_enabled=false`, `walg_enabled=true`, `backups=null`,
`physical_backup_data={}`. WALG yoqilganligi restore bajarilishi yoki recovery
window mavjudligini isbotlamaydi. Backupning mavjudligi/tiklanishi NOT VERIFIED.
Mavjud staging loyiha/branch aniqlanmadi: project list'da faqat LexHub,
branch list'da 0 ta, lokal staging konfiguratsiyasi yo'q.

### Qo'llashdan oldin

1. DBA yangi backup/recovery dalilini olsin: muvaffaqiyatli backup vaqti,
   retention/recovery window, himoyalangan saqlash joyi va kirish imkoniyati.
   Uni alohida staging muhitiga tiklab, schema/ma'lumot yaxlitligi, Auth va
   Storage chegaralarini tekshirsin. Database backup Storage fayllarini to'liq
   tiklaydi deb taxmin qilinmasin. Dalil bo'lmaguncha gate yopiq.
2. Joriy DDL, trigger/function definitionlari va owner/GRANT/RLS holati hamda
   o'zgaradigan huquqiy katalog qatorlarining oldingi nusxasi himoyalangan joyga
   saqlansin. Ularni ommaviy repository yoki logga qo'ymang.
3. `supabase/verification/stage1_preflight.sql`ni faqat SELECT sifatida bajaring.
   10 ta `passed=true` kutiladi. Bu maqsadli metadata tekshiruvi, barcha schema
   tafsilotlari yoki backup tayyorligi bo'yicha to'liq kafolat emas.
4. `SELECT version, name FROM supabase_migrations.schema_migrations ORDER BY version;`
   bilan history'ni qayta solishtiring. 2026-09-20: production 27 ta,
   repository 36 ta; 7 ta eski gap va 2 ta yangi candidate bor. Oddiy bulk push,
   `--include-all`, bootstrap yoki eski cleanup migrationlarini ishlatmang.
5. Staging'da mavjud 36 migration bootstrap'i va 24 lokal regression guruhidan
   tashqari ikki oddiy hisob/moderator bilan PostgREST/Auth oqimini tekshiring.
   Backup/restore va staging dalilidan keyin production amali uchun alohida
   aniq ruxsat olinadi. Ushbu hujjat ruxsat hisoblanmaydi.

### Faqat tasdiqdan keyingi tartib

1. `20260919001000_stage1_authorization_and_booking.sql`.
2. `20260919002000_reviewed_legal_excerpts_and_deadlines.sql`.

Har bir fayl alohida transaction. Ikkinchi fayl xato bersa birinchi faylning
oldin COMMIT qilingan himoyalari avtomatik qaytmaydi. Yangi history yozuvlarini
tasdiqlangan migration operatori boshqarsin; bu agent history'ni o'zgartirmadi.

### Kutilgan holat va tekshiruv

`supabase/verification/stage1_postflight.sql` — faqat SELECT, 8 ta
`passed=true` kutiladi. U INSERT+UPDATE triggerlari, INVOKER, restrictive
policylar, ACL, booking signature va tasdiqlangan huquqiy matn hash/havolalarini
tekshiradi. Matn hash'i mualliflik/haqiqiylik imzosi emas, tenglik tekshiruvi.

Runtime'da: begona muallif matnini almashtirish va soxta expert INSERT rad
etiladi; savol egasi accept/switch qila oladi; muallif/moderator tahriri saqlanadi;
anon booking RPC'ni chaqira olmaydi; haqiqiy tasdiqlangan ekspert uchun bron
`fee` va tiyin snapshotini to'g'ri yozadi. O'zgargan huquqiy matnning eski
embeddingi NULL bo'ladi; keyin alohida tasdiqlangan server jarayonida yangilanadi.

2026-09-20 production natijasi: preflight 10/10 mos; postflight 2/8 mos.
6 ta qolgan holat — yangi tuzatishlar production'ga qo'llanmaganining dalili.
Lokal bazada ikki SQL ham READ ONLY transaction ichida o'tdi; ustun, RLS,
trigger va huquqiy matn ataylab buzilganda tegishli tekshiruvlar rad etdi.

### Rollback/recovery

- COMMITgacha xato bo'lsa shu migration transaction'i ROLLBACK bo'ladi.
  Lokal test noma'lum/NULL huquqiy drift oldingi yangilanishlarni qaytarishini
  tekshiradi. Xatoni e'tiborsiz qoldirib keyingi faylga o'tmang.
- Birinchi migration muvaffaqiyatli, ikkinchisi muvaffaqiyatsiz bo'lsa
  avtorizatsiya himoyalarini saqlang; driftni tekshirib forward fix tayyorlang.
  Eski zaif policylarni avtomatik qaytarish xavfsiz rollback emas.
- COMMITdan keyingi jiddiy buzilish uchun faqat oldindan sinovdan o'tgan
  recovery tartibi, tegishli backup/recovery nuqtasi va alohida ruxsat ishlatiladi.
  Hozir bu tartibning restore mashqi NOT VERIFIED; shu sabab production gate yopiq.
- Flutter/Vercel yoki Edge Function rollback'i DB transaction'ini qaytarmaydi.
  Ushbu qatlamlar alohida versiyalanadi va alohida tekshiriladi.
