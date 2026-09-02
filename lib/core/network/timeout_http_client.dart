/// SUPABASE'NING BARCHA HTTP SO'ROVLARI UCHUN YAGONA TIMEOUT NUQTASI.
///
/// MUAMMO: `withTimeout(...)` ni har bir so'rovga qo'lda qo'yish — 50 dan
/// ortiq chaqiruv joyi (`grep -rE "\.(rpc|from|invoke|signUp|...)\(" lib/`
/// -> ~55 joy, 8 datasource). Bitta joy yodda qolib ketsa, o'sha ekran yana
/// CHEKSIZ spinner beradi: aynan shu nuqson Global Search'da 4 daqiqadan
/// ortiq kuzatilgan (`lib/core/network/request_timeout.dart` izohiga qara).
/// Qo'lda qo'yish kelajakdagi yangi so'rovlarni ham himoya qilmaydi.
///
/// YECHIM: `Supabase.initialize(httpClient: ...)` ga o'ralgan mijoz beriladi.
/// PostgREST, Auth (`signUp`, `signInWithPassword`, `signOut`) va Functions
/// — hammasi shu `send()` orqali o'tadi, ya'ni himoya BITTA joyda va yangi
/// so'rovlar avtomatik qamrab olinadi.
///
/// CHEGARA YO'L BO'YICHA TANLANADI ([limitFor]). Ilgari bu qobiq BARCHA
/// so'rovga bitta 30 s chegara qo'ygan edi va bu AI oqimini SINDIRARDI:
/// `functions/v1` javobi real o'lchovda 20–33 s (shu sababli
/// `kAiRequestTimeout` = 75 s), ya'ni 30 s da uzilgan so'rov foydalanuvchiga
/// "server javob bermadi" deb YOLG'ON aytardi — model hali javob yozayotgan
/// edi. Teskari tomoni ham bor: oddiy CRUD so'rovi uchun 30 s kutish
/// `kDbRequestTimeout` (20 s) siyosatidan yumshoqroq bo'lib qolardi.
///
/// CHEGARA (halol qayd): timeout `send()` ga — ya'ni javob SARLAVHALARI
/// kelishiga qo'yiladi. Sarlavhalar kelib, tana oqimi yarim yo'lda to'xtasa
/// bu qobiq ushlamaydi. Kuzatilgan nuqson (server TCP'ni qabul qiladi,
/// lekin HECH QANDAY javob qaytarmaydi) aynan `send()` bosqichida qotadi,
/// shuning uchun bu qamrov yetarli.
///
/// MUHIM (runtime kuzatuv, 2026-08-27, black-hole server + emulator): bu
/// qobiq BITTA URINISHni chegaralaydi. postgrest 2.9.1 esa standart holatda
/// GET/HEAD so'rovini HAR QANDAY `Exception` uchun 3 marta QAYTA yuboradi
/// (`retryEnabled: true`, `retryCount: 3`, backoff 1+2+4 s) — bizning
/// `TimeoutException` ham "qayta urinish" deb qabul qilingan. `getPosts`
/// ketma-ket 3 ta GET qilgani uchun Hamjamiyat ekrani javob bermaydigan
/// serverda 341–391 s shimmer ko'rsatdi (`.runtime_evidence/r6_end_391s.png`).
/// Shu sababli `main.dart` da `PostgrestClientOptions(retryEnabled: false)`
/// beriladi: qayta urinish qarorini foydalanuvchi "Qaytadan urinish" tugmasi
/// orqali o'zi qabul qiladi.
///
/// IKKINCHI KUZATUV (o'sha rig, retry o'chirilgandan keyin): shimmer yana
/// 110 s dan oshdi. Sabab per-so'rov chegarasi EMAS, KETMA-KETLIK: bitta
/// ekran yuklashi bir nechta so'rovni zanjir qilib bajaradi (kategoriyalar ->
/// `public_questions_view` -> `questions` -> `answers`) va oldingi
/// bo'g'inlarning nosozligi ATAYLAB yutiladi (katalog o'qilmasa feed
/// yiqilmaydi). Har bo'g'in o'z 20 s chegarasini oladi, ya'ni jami kutish
/// bo'g'inlar soniga KO'PAYADI.
///
/// YECHIM — ZANJIRNI UZUVCHI (circuit breaker): so'rov timeout bo'lsa, AYNI
/// SINFDAGI (`/rest/v1`, `/auth/v1`, ...) keyingi so'rovlar
/// [breakerWindow] ichida TEZ yiqiladi. Zanjir bo'g'inlari bir-biridan
/// millisekundlar farqi bilan ketgani uchun bu ularni bitta chegaraga
/// yig'adi; oyna ATAYLAB qisqa (5 s) — foydalanuvchi "Qaytadan urinish"ni
/// bosganda (>1 s) breaker yopilgan bo'ladi va REAL zond so'rovi ketadi.
/// Sinf bo'yicha ajratilgani muhim: DB timeout'i 75 s lik AI so'rovini
/// o'ldirmasligi kerak.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:lexhub/core/network/request_timeout.dart';

class TimeoutHttpClient extends http.BaseClient {
  TimeoutHttpClient(
    this._inner, {
    this.limit,
    this.breakerWindow = kTimeoutBreakerWindow,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final http.Client _inner;

  /// BARCHA so'rovga majburlanadigan bitta chegara. Faqat testlar uchun:
  /// `null` bo'lsa (ishlab chiqarish yo'li) chegara [limitFor] orqali
  /// so'rov yo'lidan tanlanadi.
  final Duration? limit;

  /// Timeout'dan keyin AYNI sinfdagi so'rovlar tez yiqiladigan oyna.
  final Duration breakerWindow;

  /// Test uchun soatni almashtirish mumkin — real vaqt kutilmaydi.
  final DateTime Function() _clock;

  /// So'rov sinfi -> oxirgi timeout vaqti (breaker holati).
  final Map<String, DateTime> _lastTimeoutAt = {};

  /// Timeout'dan keyin tez yiqitish uchun so'rovlarni sinflarga ajratadi.
  @visibleForTesting
  static String classOf(Uri url) {
    final path = url.path;
    for (final prefix in const ['/auth/v1', '/functions/v1', '/storage/v1']) {
      if (path.startsWith(prefix)) return prefix;
    }
    return '/rest/v1';
  }

  /// Supabase yo'li -> chegara.
  ///
  /// `startsWith` ishlatiladi, chunki yo'lning davomi bor:
  /// `/rest/v1/rpc/search_law_articles`, `/functions/v1/legal-analysis`.
  @visibleForTesting
  static Duration limitFor(Uri url) {
    switch (classOf(url)) {
      // `signUp` bir tranzaksiyada trigger + SMTP bajaradi — eng sekin auth.
      case '/auth/v1':
        return kAuthRequestTimeout;
      // AI/Edge Function: model javobi sekin (real o'lchov 20–33 s).
      case '/functions/v1':
        return kAiRequestTimeout;
      case '/storage/v1':
        return kFileTransferTimeout;
      // `/rest/v1` (PostgREST) va qolgan hammasi — oddiy CRUD/RPC.
      default:
        return kDbRequestTimeout;
    }
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final cls = classOf(request.url);
    final effective = limit ?? limitFor(request.url);

    final lastTimeout = _lastTimeoutAt[cls];
    if (lastTimeout != null) {
      if (_clock().difference(lastTimeout) < breakerWindow) {
        // ZANJIR UZILADI: bu so'rov ham 20 s kutsa, foydalanuvchi ekranda
        // bo'g'inlar soniga ko'paytirilgan vaqt kutardi.
        return Future.error(
          TimeoutException(
            '${request.method} ${request.url.path} (breaker)',
            effective,
          ),
          StackTrace.current,
        );
      }
      // Oyna tugadi — breaker yarim ochiq: bitta REAL zond so'rovi o'tadi.
      _lastTimeoutAt.remove(cls);
    }

    return _inner
        .send(request)
        .timeout(
          effective,
          // `label` — QAYSI endpoint qotib qolgani. To'liq URL YOZILMAYDI:
          // unda query parametrlari (email, foydalanuvchi ID) bo'lishi
          // mumkin va `TimeoutException.message` `Failure.details` orqali
          // log'ga tushadi. Faqat metod + yo'l qoldiriladi.
          onTimeout: () {
            _lastTimeoutAt[cls] = _clock();
            throw TimeoutException(
              '${request.method} ${request.url.path}',
              effective,
            );
          },
        )
        .then((response) {
          // Server javob berdi — breaker yopiladi (holat eskirmaydi).
          _lastTimeoutAt.remove(cls);
          return response;
        });
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
