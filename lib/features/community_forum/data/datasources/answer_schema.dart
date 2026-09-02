// LexHub — Community `public.answers` jadvali uchun SCHEMA KONTRAKTI.
//
// INVARIANT (buzilishi P0):
//   Javob matni FAQAT live cloud'da REAL mavjud bo'lgan ustunga yoziladi.
//   Mavjud bo'lmagan ustun nomi payload'ga tushsa PostgREST butun INSERT'ni
//   rad etadi (PGRST204) va foydalanuvchi javob yozа olmaydi.
//
// LIVE CLOUD EVIDENCE (2026-08-22, prod publishable key, read-only GET):
//   GET /rest/v1/answers?select=content     -> HTTP 400 {"code":"42703",
//        "message":"column answers.content does not exist"}
//   GET /rest/v1/answers?select=body        -> HTTP 200  (BOR)
//   GET /rest/v1/answers?select=answer      -> HTTP 400  42703
//   GET /rest/v1/answers?select=text        -> HTTP 400  42703
//   GET /rest/v1/answers?select=answer_text -> HTTP 400  42703
//   Mavjud: id, question_id, user_id, is_expert_answer, is_accepted,
//           upvotes_count, legal_references, created_at, updated_at
//   Content-Range: */0  (jadval BO'SH — bitta ham javob saqlanmagan)
//
// REAL DEVICE EVIDENCE (2026-08-22, release APK, Savol tafsilotlari sahifasi):
//   "Could not find the 'content' column of 'answers' in the schema cache"
//   (PostgREST PGRST204 — INSERT payload kaliti schema cache'da yo'q)
//
// MUHIM ASIMMETRIYA: live `public.questions` da `content` BOR
// (`kQuestionTextColumns` shuni ishlatadi), `public.answers` da esa YO'Q.
// Eski kod savollar uchun to'g'ri bo'lgan taxminni javoblarga ko'chirgan.
//
// Bu fayl ATAYLAB Supabase'ga bog'liq emas (pure Dart) — invariantni mock
// backend'siz, real unit test bilan qo'riqlash mumkin.

import 'package:lexhub/features/community_forum/data/datasources/question_category_resolver.dart'
    show kProfileMissingMessage;

/// Javoblar jadvali.
const String kAnswersTable = 'answers';

/// Javob matni YOZILADIGAN yagona live ustun.
///
/// `content` EMAS: live'da u mavjud emas (42703). Repo'dagi
/// `20260819_base_schema.sql:206` esa `content TEXT NOT NULL DEFAULT ''`
/// deb yaratadi va `:216` da `body` ni ham qo'shadi — ya'ni repo'dan toza
/// qurilgan bazada IKKALASI ham bo'ladi va `content` DEFAULT `''` oladi.
/// Shu sababli faqat `body` yozish ikki muhitda ham to'g'ri ishlaydi.
const String kAnswerTextColumn = 'body';

/// Javob matni O'QILADIGAN ustunlar — birinchi bo'sh bo'lmagani olinadi.
///
/// Yozuv faqat [kAnswerTextColumn] ga boradi, lekin o'qish kengroq: repo'dan
/// qurilgan bazada eski qatorlar `content` da bo'lishi mumkin.
const List<String> kAnswerTextReadColumns = <String>[
  'body',
  'content',
  'answer',
  'text',
];

/// `is_expert_answer = true` yuborishga haqli REAL `profiles.role` qiymatlari.
///
/// Manba: `public.enforce_expert_answer()` triggeri
/// (`supabase/migrations/20260821010000_expert_verification_and_privacy.sql:295`)
/// — u `role IN ('verified_expert','lawyer') AND is_verified IS TRUE`
/// shartini talab qiladi. Client shu shartni AYNAN takrorlaydi.
const Set<String> kExpertAnswerRoles = <String>{'lawyer', 'verified_expert'};

/// Profil yo'q bo'lganda ishlatiladigan matn (savollar yo'li bilan bir xil).
const String kAnswerProfileMissingMessage = kProfileMissingMessage;

/// Javob matni bo'sh bo'lganda tashlanadi.
///
/// Bo'sh matnni PostgREST'ga yuborish ma'nosiz qator yaratadi (yoki live'da
/// `body` NOT NULL bo'lsa 23502 beradi). Tekshiruv INSERT'dan OLDIN,
/// client'da bajariladi va silent fallback QILINMAYDI.
class AnswerContentException implements Exception {
  const AnswerContentException(this.message, {this.field});

  final String message;

  /// Muammoli ustun (forensics uchun).
  final String? field;

  @override
  String toString() => 'AnswerContentException: $message';
}

/// Ekspert javobiga haqli bo'lmagan foydalanuvchi `is_expert_answer = true`
/// yuborishga urinsa tashlanadi.
///
/// NIMA UCHUN CLIENT'DA HAM: DB triggeri (`enforce_expert_answer`) qiymatni
/// JIMGINA `FALSE` ga o'zgartiradi — ya'ni foydalanuvchi "Advokat sifatida"
/// yuborib, "muvaffaqiyatli" xabarini oladi, javob esa oddiy javob bo'lib
/// saqlanadi. Bu yolg'on success. Client aniq xato bilan to'xtatadi.
/// DB triggeri esa buzib bo'lmaydigan ASOSIY himoya bo'lib qoladi.
class ExpertAnswerNotAuthorizedException implements Exception {
  const ExpertAnswerNotAuthorizedException(this.message, {this.role});

  final String message;

  /// Foydalanuvchining REAL `profiles.role` qiymati.
  final String? role;

  @override
  String toString() => 'ExpertAnswerNotAuthorizedException: $message';
}

/// UI va data qatlami uchun YAGONA ekspert-huquqi qoidasi.
///
/// [role] — REAL `public.profiles.role` (client state EMAS).
/// [isVerified] — REAL `public.profiles.is_verified`.
///
/// `enforce_expert_answer()` triggeri bilan aynan bir xil shart.
bool canAnswerAsExpert({String? role, bool isVerified = false}) {
  final normalized = role?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) return false;
  return kExpertAnswerRoles.contains(normalized) && isVerified;
}

/// PostgREST qatoridan javob matnini o'qiydi.
///
/// [kAnswerTextReadColumns] tartibida birinchi bo'sh BO'LMAGAN qiymat
/// qaytariladi. Hech biri bo'lmasa `null` — chaqiruvchi buni ko'rinadigan
/// bo'sh matn bilan almashtirmasligi kerak (eski bug: `json['content'] ?? ''`
/// live'da HAR DOIM `''` bergan, ya'ni javob matni UI'da ko'rinmagan).
String? readAnswerText(Map<String, dynamic> json) {
  for (final column in kAnswerTextReadColumns) {
    final value = json[column];
    if (value is String && value.trim().isNotEmpty) return value;
  }
  return null;
}

/// `public.answers` uchun INSERT payload'ini quradi.
///
/// [text] — allaqachon PII-anonimlashtirilgan javob matni.
/// [isExpert] — SO'RALGAN qiymat; [canPostAsExpert] esa REAL profil huquqi.
///
/// Payload'da `content` kaliti YO'Q — live'da bu ustun mavjud emas va uning
/// borligi PGRST204 bilan butun INSERT'ni yiqitadi.
Map<String, dynamic> buildAnswerInsertPayload({
  required String questionId,
  required String userId,
  required String text,
  required bool isExpert,
  required bool canPostAsExpert,
}) {
  final body = text.trim();
  if (body.isEmpty) {
    throw const AnswerContentException(
      "Javob matni bo'sh. Iltimos, javobingizni yozing.",
      field: kAnswerTextColumn,
    );
  }
  if (isExpert && !canPostAsExpert) {
    throw const ExpertAnswerNotAuthorizedException(
      "Advokat sifatida javob berish uchun profilingiz tasdiqlangan "
      "yurist (`lawyer` yoki `verified_expert`) bo'lishi kerak. "
      "Javobni oddiy fuqaro javobi sifatida yuborishingiz mumkin.",
    );
  }

  return <String, dynamic>{
    'question_id': questionId,
    'user_id': userId,
    kAnswerTextColumn: body,
    'is_expert_answer': isExpert,
    'is_accepted': false,
    'upvotes_count': 0,
    // BO'SH ro'yxat — client hech qachon havola O'YLAB TOPMAYDI.
    // Eski kod ekspert javobiga `["Lex.uz rasmiy qonunchilik normasi"]`
    // degan SOXTA iqtibosni qo'shib qo'yardi (huquqiy ilovada bu jiddiy).
    'legal_references': const <String>[],
  };
}
