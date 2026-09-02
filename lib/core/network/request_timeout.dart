/// TARMOQ SO'ROVLARI UCHUN MAJBURIY TIMEOUT.
///
/// MUAMMO (runtime kuzatuv, 2026-08-27, emulator): Global Search shimmer
/// holatida 4 daqiqadan ortiq qotib qoldi — natija ham, `empty` ham, `error`
/// ham kelmadi; `adb logcat` da BIRORTA flutter satri yo'q, ya'ni exception
/// ham tashlanmagan. Sabab: `lib/` ichida BIRORTA `.timeout(...)` chaqirig'i
/// yo'q edi (`grep -r "\.timeout("` -> 0 natija). PostgREST/`http` client
/// standart holatda cheksiz kutadi: socket yarim-ochiq qolsa (mobil tarmoq
/// almashishi, qurilma uyquga ketishi) `Future` HECH QACHON yopilmaydi va
/// BLoC `loading` holatidan chiqmaydi.
///
/// QOIDA: foydalanuvchi kutib turadigan har bir tarmoq so'rovi CHEKLANGAN
/// vaqt ichida tugashi SHART. Timeout tugagach `TimeoutException` tashlanadi
/// va `ErrorHandler` uni `FailureCode.timeout` ga aylantiradi — UI "server
/// javob bermadi" xabarini ko'rsatadi. Cheksiz spinner — YOLG'ON signal:
/// foydalanuvchi so'rov hali ham bajarilayotganiga ishonadi.
library;

import 'dart:async';

/// Oddiy CRUD / RPC so'rovi (PostgREST, Storage metadata).
const Duration kDbRequestTimeout = Duration(seconds: 20);

/// Auth so'rovi (`signUp`, `signInWithPassword`, `signOut`).
///
/// Nega CRUD'dan kattaroq: `signUp` faqat `auth.users` INSERT emas — u bir
/// tranzaksiyada `handle_new_user()` trigger'ini bajaradi va (email
/// tasdiqlash yoqilgan bo'lsa) SMTP provayderiga murojaat qiladi. Bu ikki
/// bosqich sekin tarmoqda 20 s dan oshishi mumkin, ya'ni 20 s chegara
/// muvaffaqiyatli ro'yxatdan o'tishni SUN'IY ravishda "timeout" qilib
/// ko'rsatgan bo'lardi — foydalanuvchi hisobi yaratilgan, lekin UI xato
/// beradi (eng yomon holat: takroriy urinishda "email allaqachon band").
const Duration kAuthRequestTimeout = Duration(seconds: 30);

/// AI/Edge Function so'rovi — model javobi sekin, chegara kattaroq.
/// Legal assistant oqimida real o'lchov 20–33 s bo'lgani uchun 20 s kam.
const Duration kAiRequestTimeout = Duration(seconds: 75);

/// Fayl yuklash/tushirish.
const Duration kFileTransferTimeout = Duration(minutes: 2);

/// ZANJIR UZUVCHI (circuit breaker) oynasi — bitta so'rov timeout bo'lgach
/// AYNI SINFDAGI keyingi so'rovlar shu oyna ichida TEZ yiqiladi.
///
/// NEGA KERAK (runtime o'lchov, 2026-08-27, black-hole server + emulator):
/// per-so'rov chegarasi ekran darajasidagi kutishni CHEKLAMAYDI. Bitta ekran
/// yuklashi so'rovlarni ZANJIR qiladi (kategoriyalar -> `public_questions_view`
/// -> `questions` -> `answers`) va oldingi bo'g'in nosozligi ataylab yutiladi,
/// ya'ni har bo'g'in o'z 20 s chegarasini oladi: `retryEnabled: false` dan
/// keyin ham shimmer 110 s dan oshdi (`.runtime_evidence/fix_110s.png`).
///
/// NEGA 5 s: zanjir bo'g'inlari bir-biridan millisekundlar farqi bilan ketadi,
/// shuning uchun ularni bitta chegaraga yig'ish uchun qisqa oyna yetarli.
/// Ayni paytda oyna foydalanuvchi "Qaytadan urinish" tugmasini bosgan
/// vaqtdan (>1 s reaksiya + bosish) qisqa bo'lishi SHART — aks holda qo'lda
/// qayta urinish REAL so'rov yubormasdan darhol xato berardi va bu YOLG'ON
/// signal bo'lardi.
const Duration kTimeoutBreakerWindow = Duration(seconds: 5);

extension LexHubRequestTimeout<T> on Future<T> {
  /// So'rovga qat'iy vaqt chegarasi qo'yadi.
  ///
  /// [label] — QAYSI so'rov qotib qolgani (`Failure.details` / log uchun;
  /// foydalanuvchi ARB matnini ko'radi). `TimeoutException.toString()` o'zi
  /// "TimeoutException after 0:00:20.000000: <label>" ko'rinishida chiqadi,
  /// shuning uchun bu yerda qo'shimcha matn shakllantirilmaydi — aks holda
  /// lokalizatsiya qilinmagan yangi UI matni paydo bo'lardi.
  Future<T> withTimeout(
    Duration limit, {
    required String label,
  }) {
    return timeout(
      limit,
      onTimeout: () => throw TimeoutException(label, limit),
    );
  }
}
