import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lexhub/core/network/supabase_db.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// TUTILMAGAN XATOLARNI SERVERGA YOZADI (`public.client_error_logs`).
///
/// NIMA UCHUN KERAK (o'lchangan): `main.dart` dagi `FlutterError.onError` va
/// `PlatformDispatcher.instance.onError` faqat `debugPrint` qilardi. Release
/// build'da `debugPrint` HECH QAYERGA bormaydi — ya'ni foydalanuvchi
/// qurilmasidagi crash haqida bizda MUTLAQO ma'lumot yo'q edi. Loyihaga
/// `sentry` kabi yangi dependency qo'shilmadi: sink loyihaning o'z
/// Supabase'ida (migratsiya `20260830010000_client_error_logs.sql`).
///
/// SERVER SHARTNOMASI:
///   * `user_id` YUBORILMAYDI — server `DEFAULT auth.uid()` bilan qo'yadi va
///     RLS `WITH CHECK` boshqa qiymatni RAD ETADI (soxta muallif yo'q).
///   * Uzun matn serverda ham KESILADI, klientda ham — ikki tomonlama qulf.
///   * `created_at` serverda `now()` bilan QAYTA yoziladi.
class CrashReporter {
  CrashReporter._();

  /// Server CHECK'lari bilan bir xil chegaralar (tarmoqni behuda band
  /// qilmaslik uchun klientda ham kesiladi).
  static const int _maxMessageChars = 2000;
  static const int _maxStackChars = 8000;

  /// BIR SESSIYADA yuborish chegarasi. Server ham 20/min chegara qo'yadi;
  /// bu yerdagi chegara tarmoq trafigini himoya qiladi (masalan `build`
  /// ichidagi xato har kadrda qaytarilishi mumkin).
  static const int _maxPerSession = 20;

  /// AYNI xatoni takroran yubormaslik oynasi.
  static const Duration _dedupeWindow = Duration(minutes: 1);

  static SupabaseClient? _client;
  static bool _sending = false;
  static int _sentCount = 0;
  static String? _lastSignature;
  static DateTime? _lastSignatureAt;

  /// `Supabase.initialize` DAN KEYIN chaqiriladi.
  ///
  /// Bundan oldingi xatolar yuborilmaydi va BUFERGA HAM OLINMAYDI: Supabase
  /// hali yo'q, ya'ni yuborishning imkoni yo'q. Bu nuqtadan oldin faqat
  /// konfiguratsiya tekshiruvi ishlaydi va uning o'z diagnostik ekrani bor
  /// (`ConfigurationErrorApp`) — jim yo'qolish yo'q.
  static void attach(SupabaseClient client) {
    _client = client;
  }

  /// Xatoni yozib qo'yish (fire-and-forget: UI kutmaydi).
  static void report({
    required String kind,
    required Object error,
    StackTrace? stack,
    String? context,
  }) {
    unawaited(_send(kind: kind, error: error, stack: stack, context: context));
  }

  static Future<void> _send({
    required String kind,
    required Object error,
    StackTrace? stack,
    String? context,
  }) async {
    final client = _client;
    if (client == null) return;

    // REKURSIYA QULFI: yuborish paytida chiqqan xato yana `onError` ga
    // tushishi mumkin — bu cheksiz halqa hosil qilardi.
    if (_sending) return;
    if (_sentCount >= _maxPerSession) return;

    final message = _clip(error.toString(), _maxMessageChars);
    final signature = '$kind|${_clip(message, 120)}';
    final now = DateTime.now();
    if (_lastSignature == signature &&
        _lastSignatureAt != null &&
        now.difference(_lastSignatureAt!) < _dedupeWindow) {
      return;
    }

    _sending = true;
    try {
      // Timeout ALOHIDA qo'yilmaydi: barcha Supabase so'rovlari
      // `TimeoutHttpClient` qobig'idan o'tadi (CRUD uchun 20 s).
      // `db()` — `from()` EMAS: `from()` yo'lida postgrest 2.9.1 avtomatik
      // 4 urinish qiladi (`lib/core/network/supabase_db.dart` da o'lchangan),
      // ya'ni crash hisoboti tarmoq nosozligida 22 s davomida qayta-qayta
      // yuborilardi. Bu qoidani `postgrest_retry_disabled_test.dart` qulflaydi.
      await client.db('client_error_logs').insert({
        'kind': _clip(kind, 32),
        'message': message,
        'stack': stack == null ? null : _clip(stack.toString(), _maxStackChars),
        'context': context == null ? null : _clip(context, 200),
        'platform': defaultTargetPlatform.name,
        'build_mode': kReleaseMode
            ? 'release'
            : kProfileMode
                ? 'profile'
                : 'debug',
      });
      _sentCount++;
      _lastSignature = signature;
      _lastSignatureAt = now;
    } catch (e) {
      // JIM YUTISH EMAS: sabab log'ga chiqadi. Lekin bu xato QAYTA
      // report qilinmaydi — reporterning o'zi crash sabab bo'lib qolmasin.
      // Release'da `debugPrint` ko'rinmaydi; reporterning o'z nosozligini
      // yozadigan boshqa kanal YO'Q va bu ATAYLAB shunday (aks holda
      // xato → yuborish → xato halqasi).
      if (kDebugMode) {
        debugPrint('[crash_reporter] yuborilmadi: $e');
      }
    } finally {
      _sending = false;
    }
  }

  static String _clip(String value, int max) =>
      value.length <= max ? value : value.substring(0, max);

  /// TEST uchun: statik holatni tozalaydi (testlar bir-biriga ta'sir
  /// qilmasligi uchun).
  @visibleForTesting
  static void resetForTest() {
    _client = null;
    _sending = false;
    _sentCount = 0;
    _lastSignature = null;
    _lastSignatureAt = null;
  }

  /// TEST uchun: shu sessiyada nechta yozuv yuborilgani.
  @visibleForTesting
  static int get sentCountForTest => _sentCount;
}
