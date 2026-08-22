// LexHub — Community savol kategoriyalari uchun NOM -> ID rezolyutsiyasi.
//
// INVARIANT (buzilishi P0):
//   UI faqat kategoriya NOMINI ko'rsatishi mumkin, lekin
//   `public.questions.category_id` ustuniga FAQAT katalogdan
//   (`public.categories`) olingan real UUID yoziladi.
//   Display name hech qachon FK ustuniga yuborilmaydi.
//
// LIVE CLOUD EVIDENCE (2026-08-22, prod anon key, PostgREST):
//   GET /rest/v1/questions?select=id&category_id=eq.Mehnat%20huquqi
//     -> HTTP 400 {"code":"22P02",
//        "message":"invalid input syntax for type uuid: \"Mehnat huquqi\""}
//   GET /rest/v1/questions?category_id=eq.9e25aeac-...-02b06a714f42
//     -> HTTP 200
//   GET /rest/v1/categories?select=*
//     -> HTTP 200, 5 qator; ustunlar: id (uuid), name, slug, description,
//        icon, created_at
//   GET /rest/v1/question_categories?select=*
//     -> HTTP 200, [] (BO'SH JADVAL)
//   => Eski implementatsiya `from('question_categories')` o'qigani uchun
//      katalog HAR DOIM bo'sh bo'lgan va ID hech qachon topilmagan.
//
// Bu fayl ataylab Supabase'ga bog'liq EMAS (pure Dart) — shuning uchun
// invariantni mock backend'siz, real unit test bilan qo'riqlash mumkin.

/// Kategoriya katalogi joylashgan REAL jadval.
///
/// `question_categories` EMAS: live cloud'da u bo'sh, va
/// `questions.category_id` FK'si `public.categories(id)`ga qaraydi
/// (`questions_category_id_fkey`).
const String kCategoriesTable = 'categories';

/// "Barcha kategoriyalar" filtri uchun UI label (bu ID emas).
const String kAllCategoriesLabel = 'Barchasi';

/// Katalogda topilmagan kategoriya uchun UI label (xom uuid o'rniga).
const String kUnknownCategoryLabel = 'Umumiy';

/// Savol matni yoziladigan LIVE ustunlar.
///
/// LIVE EVIDENCE (2026-08-22, prod anon key, PostgREST):
///   GET /rest/v1/questions?select=body                -> HTTP 200 (BOR)
///   GET /rest/v1/questions?select=description         -> HTTP 200 (BOR)
///   GET /rest/v1/questions?select=content             -> HTTP 200 (BOR)
///   GET /rest/v1/questions?select=anonymized_question -> HTTP 200 (BOR)
///   GET /rest/v1/public_questions_view?select=body    -> HTTP 400 (view'da YO'Q)
///
/// REAL DEVICE EVIDENCE (2026-08-22, release APK):
///   null value in column "body" of relation "questions"
///   violates not-null constraint
///
/// `body` live cloud'da NOT NULL, lekin repo migration'larida UMUMAN yo'q
/// (`supabase/migrations/*.sql` faqat `answers.body`ni biladi) — ya'ni u
/// legacy ustun. `content` ham legacy bo'lishi mumkin va uning NOT NULL
/// holatini anon kalit bilan aniqlash IMKONSIZ: RLS (42501) NOT NULL (23502)
/// tekshiruvidan OLDIN ishlaydi. Shu sababli savol matni mavjud bo'lgan
/// BARCHA matn ustunlariga bir xil yoziladi — bitta insert bilan NOT NULL
/// muammosining butun sinfi yopiladi va view (`description`,
/// `anonymized_question`) ham to'g'ri to'ldiriladi.
const List<String> kQuestionTextColumns = <String>[
  'body',
  'description',
  'content',
  'anonymized_question',
];

/// `questions.title` uchun xavfsiz uzunlik (repo: VARCHAR(255)).
/// Uzunroq sarlavha 22001 (`value too long`) beradi.
const int kQuestionTitleMaxLength = 255;


/// UI'da tanlash mumkin bo'lgan kategoriyalar — `public.categories.name`
/// qiymatlari bilan bir xil.
///
/// MUHIM: bu ro'yxatga faqat katalogda REAL mavjud nom qo'shiladi. Katalogda
/// yo'q nomni ko'rsatish foydalanuvchini saqlanmaydigan tanlovga olib boradi
/// (eski holat: dropdown'da 8 ta nom bor edi, katalogda esa faqat 2 tasi).
/// Apostrof varianti farq qilmaydi — [QuestionCategoryCatalog.normalizeName]
/// `'` / `’` / `ʻ` / `ʼ` ni birlashtiradi (live qiymat: "Maʼmuriy huquqi").
const List<String> kCommunityCategoryNames = <String>[
  'Mehnat huquqi',
  'Oila huquqi',
  'Fuqarolik huquqi',
  'Jinoyat huquqi',
  "Ma'muriy huquqi",
];

/// Filtr paneli uchun ro'yxat: "Barchasi" + real katalog nomlari.
const List<String> kCommunityFilterCategories = <String>[
  kAllCategoriesLabel,
  ...kCommunityCategoryNames,
];

/// Kategoriya nomi katalogdan ID'ga aylantirilmaganda tashlanadi.
///
/// Bu ATAYLAB silent fallback emas: `category_id`ga nom yuborish 22P02
/// beradi, kalitni jimgina tashlab yuborish esa savolni kategoriyasiz
/// saqlab, muammoni yashiradi. Ikkalasi ham taqiqlangan.
class CategoryResolutionException implements Exception {
  const CategoryResolutionException(this.message, {this.category});

  final String message;

  /// Rezolyutsiya qilinmagan xom qiymat (forensics uchun).
  final String? category;

  @override
  String toString() => 'CategoryResolutionException: $message';
}

/// Savol matni (`questions.body`) yoki sarlavha bo'sh bo'lganda tashlanadi.
///
/// LIVE: `public.questions.body` NOT NULL (real device evidence). Bo'sh yoki
/// null matnni PostgREST'ga yuborish 23502 beradi:
///   `null value in column "body" ... violates not-null constraint`
/// Shu sababli tekshiruv client'da, insert'dan OLDIN bajariladi va silent
/// fallback qilinmaydi.
class QuestionContentException implements Exception {
  const QuestionContentException(this.message, {this.field});

  final String message;

  /// Qaysi ustun invarianti buzilgani (`body` / `title`).
  final String? field;

  @override
  String toString() => 'QuestionContentException($field): $message';
}

/// `public.profiles` ichida joriy `auth.uid()` uchun qator bo'lmaganda
/// tashlanadi — `questions.user_id` FK'si aynan shu jadvalga ishora qiladi.
///
/// LIVE EVIDENCE (2026-08-22, prod anon key, PostgREST embedding):
///   GET /rest/v1/questions?select=id,profiles!questions_user_id_fkey(id)
///     -> HTTP 200  => FK BOR va u `public.profiles`ga ishora qiladi
///   GET /rest/v1/questions?select=id,users(id)
///     -> HTTP 400 PGRST200 => `auth.users`ga TO'G'RIDAN-TO'G'RI FK yo'q
/// REPO: `questions.user_id UUID REFERENCES public.profiles(id)`
///   (supabase/migrations/20260819_base_schema.sql:144,161)
///
/// REAL DEVICE EVIDENCE (2026-08-22):
///   insert or update on table "questions" violates foreign key constraint
///   "questions_user_id_fkey"
///
/// Ya'ni `auth.users`da user BOR (sessiya ishlayapti), `public.profiles`da esa
/// qator YO'Q. Profil yaratish faqat `handle_new_user()` triggeriga bog'liq
/// (client hech qachon profil INSERT qilmaydi), trigger esa xatolikni
/// `EXCEPTION WHEN OTHERS` bilan jimgina yutadi.
///
/// INVARIANT (foydalanuvchi talabi §7): profil bo'lmasa savol yaratishni
/// DAVOM ETTIRMAYMIZ. Bu yerda profil YARATILMAYDI ham — `profiles`ga
/// client'dan INSERT qilish RBAC yuzasi (`role`) bo'lgani uchun bu qaror
/// DB tomonida hal qilinishi kerak.
class ProfileMissingException implements Exception {
  const ProfileMissingException(this.message, {this.userId});

  final String message;

  /// Profili topilmagan `auth.uid()` (forensics uchun; UI'da ko'rsatilmaydi).
  final String? userId;

  @override
  String toString() => 'ProfileMissingException: $message';
}

/// `questions.user_id` FK constraint nomi (live'da tasdiqlangan).
const String kQuestionsUserFkName = 'questions_user_id_fkey';

/// Foydalanuvchiga ko'rsatiladigan matn: profil yo'qligi sababli savol
/// saqlanmadi. Xom DB xatosi YUTILMAYDI — u `details`da saqlanadi.
const String kProfileMissingMessage =
    "Profilingiz bazada topilmadi, shuning uchun savol saqlanmadi "
    "(questions.user_id -> profiles.id). Iltimos, tizimdan chiqib qayta "
    "kiring; muammo saqlansa, ro'yxatdan o'tish jarayonida profil "
    "yaratilmaganini administratorga xabar qiling.";

/// PostgreSQL 23503 xatosi AYNAN `questions_user_id_fkey` bo'yicha kelganini
/// aniqlaydi.
///
/// Nima uchun kerak: `questions` jadvalida bir nechta FK bor (`user_id`,
/// `category_id`). Ularning hammasini bitta xabar bilan izohlash noto'g'ri
/// diagnostikaga olib keladi, shuning uchun constraint nomi bo'yicha ajratamiz.
bool isQuestionUserFkViolation({String? code, String? message}) {
  if (code != null && code.trim() != '23503') return false;
  final text = (message ?? '').toLowerCase();
  if (text.isEmpty) return false;
  return text.contains(kQuestionsUserFkName) ||
      (text.contains('foreign key') && text.contains('user_id'));
}

/// `public.categories` jadvalining runtime snapshot'i.
///
/// Ustun nomlari qattiq bog'lanmaydi: live cloud `name` + `slug` beradi,
/// repo'dagi `supabase/schema.sql` esa `name_uz` / `name_ru` bilan drift
/// qilgan. Shuning uchun mavjud bo'lgan barcha nom ustunlari indekslanadi.
/// repo'dagi `supabase/schema.sql` esa `name_uz` / `name_ru` bilan drift
/// qilgan. Shuning uchun mavjud bo'lgan barcha nom ustunlari indekslanadi.
class QuestionCategoryCatalog {
  const QuestionCategoryCatalog({
    required this.idByNormalizedName,
    required this.nameById,
  });

  const QuestionCategoryCatalog.empty()
      : idByNormalizedName = const <String, String>{},
        nameById = const <String, String>{};

  /// `normalizeName(nom)` -> category id
  final Map<String, String> idByNormalizedName;

  /// category id -> asosiy display nom
  final Map<String, String> nameById;

  bool get isEmpty => nameById.isEmpty && idByNormalizedName.isEmpty;

  /// Katalogda ID sifatida tanilgan qiymatlar.
  Iterable<String> get knownIds => nameById.keys;

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  // O'zbek nomlarida apostrof variantlari aralashadi: ' ’ ʻ ʼ ` ´
  static final RegExp _apostrophes = RegExp("[‘’ʻʼ`´']");
  static final RegExp _whitespace = RegExp(r'\s+');

  /// Nom ustunlari, ustuvorlik tartibida (live: `name`).
  static const List<String> nameColumns = <String>[
    'name_uz',
    'name_ru',
    'name_en',
    'name',
    'title',
    'label',
  ];

  static bool isUuid(String value) => _uuidPattern.hasMatch(value.trim());

  /// Filtr "hammasi"ni bildiradimi (ID rezolyutsiyasi kerak emas).
  static bool isAllCategories(String? raw) {
    final value = raw?.trim() ?? '';
    return value.isEmpty || value == kAllCategoriesLabel;
  }

  /// Nomlarni solishtirish uchun normalizatsiya: register, apostrof
  /// variantlari va ortiqcha bo'shliqlar farqi yo'qoladi.
  static String normalizeName(String value) => value
      .toLowerCase()
      .replaceAll(_apostrophes, "'")
      .replaceAll(_whitespace, ' ')
      .trim();

  factory QuestionCategoryCatalog.fromRows(List<dynamic> rows) {
    final idByName = <String, String>{};
    final nameById = <String, String>{};

    for (final row in rows) {
      if (row is! Map) continue;
      final id = row['id']?.toString().trim();
      if (id == null || id.isEmpty) continue;

      String? primaryName;
      for (final column in nameColumns) {
        final value = row[column];
        if (value is String && value.trim().isNotEmpty) {
          primaryName ??= value.trim();
          idByName[normalizeName(value)] = id;
        }
      }

      // `slug` bo'lsa, u ham nom sifatida qabul qilinadi (ID emas).
      final slug = row['slug'];
      if (slug is String && slug.trim().isNotEmpty) {
        idByName[normalizeName(slug)] = id;
      }

      nameById[id] = primaryName ?? id;
    }

    return QuestionCategoryCatalog(
      idByNormalizedName: idByName,
      nameById: nameById,
    );
  }

  /// UI'dan kelgan qiymatni real `category_id`ga aylantiradi.
  ///
  /// Qaytaradi:
  /// * `null` — filtr yo'q / bo'sh / katalogdan ID topilmadi.
  ///   Bu holda chaqiruvchi `category_id`ni MUTLAQO yubormasligi shart.
  /// * uuid — har qanday holatda o'zgarmasdan o'tadi.
  /// * katalogdagi ID — masalan `labor` kabi slug-ID (schema drift).
  /// * nom -> ID — `Mehnat huquqi` -> katalogdagi haqiqiy UUID.
  String? resolveId(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty || value == kAllCategoriesLabel) return null;
    if (isUuid(value)) return value;
    if (nameById.containsKey(value)) return value;
    return idByNormalizedName[normalizeName(value)];
  }

  /// [resolveId]ning QAT'IY varianti — yozish va filtrlash yo'llari uchun.
  ///
  /// Topilmasa [CategoryResolutionException] tashlaydi: nom `category_id`ga
  /// yuborilmaydi va jimjitlikda tashlab ham ketilmaydi.
  String requireId(String? raw) {
    final value = raw?.trim() ?? '';
    if (isAllCategories(value)) {
      throw CategoryResolutionException(
        'Kategoriya tanlanmagan. Iltimos, savol uchun kategoriya tanlang.',
        category: raw,
      );
    }
    final id = resolveId(value);
    if (id == null) {
      throw CategoryResolutionException(
        '"$value" kategoriyasi katalogda (public.$kCategoriesTable) topilmadi. '
        "Savol saqlanmadi — iltimos, ro'yxatdagi kategoriyani tanlang.",
        category: raw,
      );
    }
    return id;
  }

  /// `category_id` -> UI uchun display nom. Topilmasa `null`.
  String? displayNameFor(String? categoryId) {
    final value = categoryId?.trim() ?? '';
    if (value.isEmpty) return null;
    return nameById[value];
  }
}

/// Haqiqiy `category_id` shakli: uuid yoki slug-ID (`labor`, `labor-law`).
/// Display nom (`Mehnat huquqi`, `Fuqarolik`) bu shablonga TUSHMAYDI.
final RegExp _categoryIdShape = RegExp(r'^[a-z0-9][a-z0-9_-]*$');

/// `public.questions` INSERT payloadini quradi.
///
/// Bu funksiya IKKI invariantning yakuniy qo'riqchisi.
///
/// 1. [categoryId] majburiy va FAQAT haqiqiy ID shaklida bo'lishi kerak.
///    Display nom kelsa — jimjitlikda tashlab ketilmaydi, balki
///    [CategoryResolutionException] tashlanadi:
///      * nomni yuborish  -> PostgreSQL 22P02;
///      * kalitni tashlash -> savol kategoriyasiz saqlanib, bug yashiriladi.
///
/// 2. [description] (savol matni) null/bo'sh/faqat bo'shliq bo'lishi MUMKIN
///    EMAS. Live `questions.body` NOT NULL, shuning uchun bo'sh matn
///    [QuestionContentException] beradi va PostgREST'ga UMUMAN yuborilmaydi.
///    Matn [kQuestionTextColumns] dagi barcha ustunlarga yoziladi.
Map<String, dynamic> buildQuestionInsertPayload({
  required String userId,
  required String title,
  required String description,
  required String aiSummary,
  required bool isAnonymous,
  required String categoryId,
}) {
  final id = categoryId.trim();
  if (id.isEmpty) {
    throw const CategoryResolutionException(
      "category_id bo'sh — savol kategoriyasiz saqlanmaydi.",
    );
  }
  if (!QuestionCategoryCatalog.isUuid(id) && !_categoryIdShape.hasMatch(id)) {
    throw CategoryResolutionException(
      'category_id sifatida display nom yuborilmoqda: "$id". '
      'PostgreSQL bu qiymatni uuid sifatida qabul qilmaydi '
      '(22P02: invalid input syntax for type uuid).',
      category: id,
    );
  }

  // `questions.body` NOT NULL — bo'sh matn client'da to'xtatiladi.
  final body = description.trim();
  if (body.isEmpty) {
    throw const QuestionContentException(
      "Savol matni bo'sh. `questions.body` ustuni NOT NULL, shuning uchun "
      "savol saqlanmaydi — iltimos, savolingizni yozing.",
      field: 'body',
    );
  }

  // `questions.title` ham NOT NULL (repo: VARCHAR(255) NOT NULL).
  final safeTitle = title.trim();
  if (safeTitle.isEmpty) {
    throw const QuestionContentException(
      "Savol sarlavhasi bo'sh. `questions.title` ustuni NOT NULL, shuning "
      "uchun savol saqlanmaydi.",
      field: 'title',
    );
  }

  return <String, dynamic>{
    'user_id': userId,
    'category_id': id,
    'title': safeTitle.length > kQuestionTitleMaxLength
        ? safeTitle.substring(0, kQuestionTitleMaxLength)
        : safeTitle,
    // body / description / content / anonymized_question — hammasi bir xil
    // sanitizatsiya qilingan matn (izohni [kQuestionTextColumns] da o'qing).
    for (final column in kQuestionTextColumns) column: body,
    'is_anonymous': isAnonymous,
    'status': 'open',
    'ai_summary': aiSummary,
    'views_count': 1,
    'upvotes_count': 0,
    'answers_count': 0,
  };
}
