import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lexhub/core/legal_safety/pii_anonymizer.dart';
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
///
/// MAZMUN TOZALASH FAQAT KLIENTDA (o'lchandi migratsiya manbasidan,
/// `20260830010000_client_error_logs.sql:78-84`): serverdagi
/// `client_error_logs_sanitize()` trigger'i matnni FAQAT KESADI (`left(...)`)
/// — PII yoki sirni O'CHIRMAYDI. Migratsiyaning o'zi bu xavfni tan oladi:
/// "stack trace boshqa foydalanuvchining ma'lumotini oshkor qilishi mumkin"
/// (shu sababli SELECT faqat xodimga). Ya'ni mazmunni tozalash uchun YAGONA
/// joy — shu klass; jadvalga tushgan matnni keyin o'zgartirish MUMKIN EMAS
/// (UPDATE policy ATAYLAB yo'q, audit izi).
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

    final message = _scrub(error.toString(), _maxMessageChars);
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
        'stack': stack == null ? null : _scrub(stack.toString(), _maxStackChars),
        'context': context == null ? null : _scrub(context, 200),
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

  // ── MAZMUN TOZALASH ──────────────────────────────────────────────────────
  //
  // O'LCHANGAN LEAK ZANJIRI (2026-09-02, manba tahlili):
  //   `legal_assistant_local_datasource.dart:38` -> `jsonDecode(raw)` — `raw`
  //   FOYDALANUVCHINING huquqiy savoli va AI javobi saqlangan kesh. Buzuq
  //   keshda `FormatException.toString()` MANBA MATNINING bir bo'lagini
  //   (Dart SDK: offset atrofidagi ~78 belgi + karet satri) xato matniga
  //   QO'SHADI. Shu satr :46 da `CacheException(message: "...: $e")` ichiga
  //   o'raladi va tutilmagan holatda `client_error_logs.message` ga tushardi.
  //   AYNI shakl `saved_user_document_model.dart:29` da ham bor — u yerda
  //   manba HUJJAT MAYDONLARI (ism, manzil, pasport).
  //
  // Shuning uchun matn KETMA-KET uch qatlamdan o'tadi. TARTIB MUHIM.
  static const String _sourceMask = '[manba yashirildi]';
  static const String _secretMask = '[sir yashirildi]';

  /// 1-QATLAM: `FormatException` ning MANBA DERAZASI.
  ///
  /// SDK shakli: `... (at character N)\n<manba satri>\n   ^\n` (ko'p satrli
  /// manbada `(at line L, character C)`). Karet satriga ANCHOR qilinadi, ya'ni
  /// naqsh faqat SHU shaklni oladi — oddiy ko'p satrli diagnostika (masalan
  /// Flutter assert matni) TEGILMAYDI. O'ralgan (`$e` bilan interpolatsiya
  /// qilingan) holat ham SHU yerda ushlanadi.
  ///
  /// HALOL CHEKLOV: `offset` NULL bo'lsa SDK `(at ...)` yorlig'ini ham, karet
  /// satrini ham QO'YMAYDI (`"$report\n$source"`), ya'ni bu naqsh uni
  /// ushlamaydi. `jsonDecode` HAR DOIM offset beradi — o'lchangan zanjir shu
  /// shaklda; qo'lda `FormatException(msg, source)` (offset'siz) yozilsa
  /// manba 2-3 qatlamga (sir/PII) qoladi.
  static final RegExp _formatSourceWindow = RegExp(
    r'\(at (?:character \d+|line \d+, character \d+)\)\n.*\n[ ]*\^\n?',
  );

  /// 2-QATLAM: SIRLAR. PII maskasi ularni QAMRAMAYDI, lekin xato matni URL
  /// yoki `Authorization` sarlavhasini qaytarishi mumkin — sessiya token'i
  /// log'ga tushsa u HISOBNI EGALLASH uchun yetarli bo'lardi.
  ///
  /// TARTIB MUHIM: `nom=qiymat` shakli BIRINCHI turadi, aks holda ichkaridagi
  /// JWT alohida maskalanib, `nom=[mask]` qoldig'i ustiga IKKINCHI moslik
  /// tushardi (o'lchandi: `[sir yashirildi] yashirildi]`).
  static final List<RegExp> _secretPatterns = <RegExp>[
    RegExp(r'(?:access_token|refresh_token|api[_-]?key|apikey|token)='
        r'''[^&\s"']+''', caseSensitive: false),
    RegExp(r'[Bb]earer\s+[A-Za-z0-9._\-]{10,}'),
    RegExp(r'eyJ[A-Za-z0-9_\-]{8,}\.[A-Za-z0-9_\-]{8,}(?:\.[A-Za-z0-9_\-]+)?'),
    RegExp(r'sb_(?:publishable|secret)_[A-Za-z0-9_\-]{6,}'),
    RegExp(r'AIza[A-Za-z0-9_\-]{20,}'),
  ];

  static String _clip(String value, int max) =>
      value.length <= max ? value : value.substring(0, max);

  /// Regex INPUT chegarasi. Kesish TOZALASHDAN OLDIN qo'yilsa, kesim
  /// `FormatException` derazasining karet satrini yeb, MANBA satrini
  /// tozalanmagan holda qoldirishi mumkin edi — shu sababli avval keng
  /// shift (32 KB) bilan tozalanadi, server chegarasiga esa KEYIN kesiladi.
  static const int _scrubCeiling = 32000;

  /// Xato matnini serverga yuborishdan OLDIN tozalaydi.
  ///
  /// Oxirgi `_clip` MAJBURIY: maska matnni UZAYTIRISHI mumkin (13 belgili
  /// telefon -> 20 belgili `[Telefon yashirildi]`), server chegarasi esa
  /// qat'iy.
  ///
  /// BU BEST-EFFORT, KAFOLAT EMAS (§0): naqsh bilan aniqlanmaydigan ERKIN
  /// matn — masalan foydalanuvchi yozgan huquqiy savolning o'zi — biror xato
  /// matniga QO'LDA interpolatsiya qilinsa, u shu yerdan O'TIB KETADI.
  /// Yagona to'liq himoya — xato matniga foydalanuvchi mazmunini
  /// QO'SHMASLIK.
  static String _scrub(String value, int max) {
    var out = _clip(value, _scrubCeiling);
    out = out.replaceAll(_formatSourceWindow, '(at ...) $_sourceMask');
    for (final pattern in _secretPatterns) {
      out = out.replaceAll(pattern, _secretMask);
    }
    // 3-QATLAM: PII. Loyihaning MAVJUD anonimlashtiruvchisi ishlatiladi
    // (telefon/pasport/karta/JSHSHIR/email/ism) — ikkinchi, parallel PII
    // qoidalar to'plami YARATILMAYDI, aks holda ikkisi vaqt o'tishi bilan
    // bir-biridan uzoqlashardi.
    return _clip(PiiAnonymizer.anonymize(out), max);
  }

  /// TEST uchun: tozalash qatlamlarini payload'siz o'lchash imkoni.
  @visibleForTesting
  static String scrubForTest(String value, {int max = _maxStackChars}) =>
      _scrub(value, max);

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
