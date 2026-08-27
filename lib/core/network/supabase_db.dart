/// RETRY'SIZ DB KIRISHI — `supabaseClient.from()` O'RNIGA `supabaseClient.db()`.
///
/// NIMA UCHUN BU FAYL BOR (paket defekti, supabase 2.16.1):
/// `Supabase.initialize(postgrestOptions: PostgrestClientOptions(
/// retryEnabled: false))` sozlamasi `supabase.rest` va `supabase.rpc()` uchun
/// ishlaydi, LEKIN `supabase.from(table)` uchun ISHLAMAYDI:
///
///   supabase_client.dart:209-221  `from()` -> `SupabaseQueryBuilder(...)`
///     — `retryEnabled`, `retryCount`, `retryableStatusCodes`,
///       `requestTimeout` UZATILMAYDI;
///   supabase_query_builder.dart:9-24  konstruktor bu parametrlarni
///     UMUMAN QABUL QILMAYDI;
///   postgrest_query_builder.dart:22-23  standart qiymatlar
///     `retryEnabled = true`, `retryCount = 3` KUCHGA KIRADI.
///
/// Natijada har bir `from(...).select()` `postgrest_builder.dart:425-445`
/// dagi qayta urinish tsikliga tushadi: 4 urinish + `1+2+4 = 7 s` backoff.
///
/// RUNTIME ISBOT (real socket, `screen_wait_bound_test.dart` diagnostikasi,
/// per-so'rov chegarasi 300 ms ga siqilgan):
///   +195ms   GET /rest/v1/categories
///   +7513ms  GET /rest/v1/categories [X-Retry-Count: 3]
///   +14848ms GET /rest/v1/categories [X-Retry-Count: 3]
///   +22191ms GET /rest/v1/categories [X-Retry-Count: 3]
/// `X-Retry-Count` sarlavhasini FAQAT o'sha tsikl qo'yadi — ya'ni
/// `retryEnabled: false` sozlamasi bu yo'lda O'LIK KONFIGURATSIYA edi.
/// Qurilmadagi ta'siri: javob bermaydigan serverda Hamjamiyat ekrani
/// 88.66 s shimmer ko'rsatdi (`.runtime_evidence/err_89s.png`), holbuki
/// bitta so'rov chegarasi 20 s.
///
/// `rest` esa AYNI SHU sozlama bilan quriladi (supabase_client.dart:330-341),
/// shuning uchun `rest.from(table)` retry'siz ishlaydi. Auth jihatidan farq
/// YO'Q: ikkala yo'l ham bir xil `_authHttpClient` va bir xil sarlavhalarni
/// oladi (`auth_http_client.dart` `putIfAbsent` bilan token qo'yadi).
///
/// `.stream()` (realtime) bu loyihada ISHLATILMAYDI (0 chaqiruv), ya'ni
/// `SupabaseQueryBuilder`ning yagona qo'shimcha imkoniyati yo'qotilmaydi.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

extension LexhubDbAccess on SupabaseClient {
  /// Jadval/ko'rinishga so'rov — AVTOMATIK QAYTA URINISHSIZ.
  ///
  /// `from()` ni TO'G'RIDAN-TO'G'RI ishlatish taqiqlangan; buni
  /// `test/core/network/postgrest_retry_disabled_test.dart` qulflaydi.
  PostgrestQueryBuilder<void> db(String table) => rest.from(table);
}
