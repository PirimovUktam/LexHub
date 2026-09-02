/// GLOBAL TIMEOUT QOBIG'I — `TimeoutHttpClient`.
///
/// NIMA UCHUN KERAK: `withTimeout` ni har bir so'rovga qo'lda qo'yish
/// ~55 chaqiruv joyini talab qiladi va yangi so'rovlarni himoya qilmaydi.
/// `Supabase.initialize(httpClient: ...)` ga o'ralgan mijoz berilsa,
/// PostgREST + Auth trafigi BITTA joyda chegaralanadi.
///
/// Bu test qulflaydi:
///   1. javob bermaydigan transport chegaradan keyin `TimeoutException`
///      beradi (qotib qolgan socket modeli);
///   2. vaqtida kelgan javob TEGILMAYDI;
///   3. xato matnida MAXFIY ma'lumot yo'q — faqat metod + yo'l, query
///      parametrlari (email, ID) tushmaydi;
///   4. zanjir oxiri: `ErrorHandler` uni `FailureCode.timeout` ga
///      aylantiradi, ya'ni UI cheksiz spinner emas, aniq xabar beradi.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lexhub/core/errors/failure_code.dart';
import 'package:lexhub/core/errors/error_handler.dart';
import 'package:lexhub/core/network/request_timeout.dart';
import 'package:lexhub/core/network/timeout_http_client.dart';

/// TCP'ni "qabul qiladi", lekin javob QAYTARMAYDI — black-hole server
/// modeli (`.runtime_evidence/s21_blackhole_shimmer.png` holati).
class _BlackHoleClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      Completer<http.StreamedResponse>().future;
}

class _InstantClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream.value(utf8.encode('[]')),
      200,
      request: request,
    );
  }
}

/// Black-hole, lekin urinishlarni SANAYDI: breaker ochiq bo'lganda so'rov
/// transportga BORMASLIGI kerak — buni faqat sanoq isbotlaydi.
class _CountingBlackHoleClient extends http.BaseClient {
  _CountingBlackHoleClient(this._onSend);

  final void Function() _onSend;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    _onSend();
    return Completer<http.StreamedResponse>().future;
  }
}

/// Birinchi so'rovda qotadi, keyin tiklanadi — breaker holati muvaffaqiyatli
/// javobdan keyin TOZALANISHINI tekshirish uchun.
class _FlakyClient extends http.BaseClient {
  var _calls = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (_calls++ == 0) return Completer<http.StreamedResponse>().future;
    return Future.value(http.StreamedResponse(
      Stream.value(utf8.encode('[]')),
      200,
      request: request,
    ));
  }
}

http.Request _request() => http.Request(
      'GET',
      // Query parametrlari ATAYLAB maxfiy ko'rinishda: xato matniga
      // tushmasligi tekshiriladi.
      Uri.parse('https://example.supabase.co/rest/v1/profiles'
          '?id=eq.11111111-2222-3333-4444-555555555555'),
    );

void main() {
  test('javob bermaydigan transport -> TimeoutException', () async {
    final client = TimeoutHttpClient(
      _BlackHoleClient(),
      limit: const Duration(milliseconds: 40),
    );

    await expectLater(
      client.send(_request()),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('vaqtida kelgan javob o\'zgarmaydi', () async {
    final client = TimeoutHttpClient(
      _InstantClient(),
      limit: const Duration(seconds: 5),
    );

    final response = await client.send(_request());
    expect(response.statusCode, 200);
    expect(await response.stream.bytesToString(), '[]');
  });

  test('xato matnida query parametrlari YO\'Q (maxfiylik)', () async {
    final client = TimeoutHttpClient(
      _BlackHoleClient(),
      limit: const Duration(milliseconds: 20),
    );

    try {
      await client.send(_request());
      fail('TimeoutException kutilgandi');
    } on TimeoutException catch (e) {
      expect(e.message, 'GET /rest/v1/profiles');
      // UUID va `?id=eq...` qismi log'ga ham tushmasligi kerak.
      expect(e.message, isNot(contains('11111111')));
      expect(e.message, isNot(contains('?')));
    }
  });

  test('zanjir oxiri: ErrorHandler -> FailureCode.timeout', () async {
    final client = TimeoutHttpClient(
      _BlackHoleClient(),
      limit: const Duration(milliseconds: 20),
    );

    try {
      await client.send(_request());
      fail('TimeoutException kutilgandi');
    } catch (e) {
      final failure = ErrorHandler.handle(e);
      expect(failure.code, FailureCode.timeout);
      expect(failure.message, isNot(contains('TimeoutException')));
    }
  });

  // ---------------------------------------------------------------------------
  // CHEGARA YO'L BO'YICHA TANLANADI.
  //
  // Ilgari qobiq HAMMASIGA bitta 30 s qo'ygan edi. Bu AI oqimini sindirardi:
  // `functions/v1` javobi real o'lchovda 20–33 s va `kAiRequestTimeout` = 75 s
  // ataylab kattaroq qilingan — 30 s da uzilgan so'rov foydalanuvchiga
  // "server javob bermadi" deb YOLG'ON aytardi.
  // ---------------------------------------------------------------------------
  group('limitFor — chegara so\'rov yo\'lidan tanlanadi', () {
    Uri u(String path) => Uri.parse('https://example.supabase.co$path');

    test('auth -> kAuthRequestTimeout', () {
      expect(TimeoutHttpClient.limitFor(u('/auth/v1/signup')),
          kAuthRequestTimeout);
    });

    test('AI/Edge Function -> kAiRequestTimeout (30 s da UZILMAYDI)', () {
      expect(TimeoutHttpClient.limitFor(u('/functions/v1/legal-analysis')),
          kAiRequestTimeout);
      expect(kAiRequestTimeout, greaterThan(kAuthRequestTimeout));
    });

    test('storage -> kFileTransferTimeout', () {
      expect(TimeoutHttpClient.limitFor(u('/storage/v1/object/docs/a.pdf')),
          kFileTransferTimeout);
    });

    test('PostgREST (jumladan rpc) -> kDbRequestTimeout', () {
      expect(TimeoutHttpClient.limitFor(u('/rest/v1/questions')),
          kDbRequestTimeout);
      expect(TimeoutHttpClient.limitFor(u('/rest/v1/rpc/search_law_articles')),
          kDbRequestTimeout);
    });

    test('noma\'lum yo\'l -> eng QAT\'IY chegara (fail-safe)', () {
      expect(TimeoutHttpClient.limitFor(u('/kelajakdagi/yangi/yol')),
          kDbRequestTimeout);
    });
  });

  // ---------------------------------------------------------------------------
  // postgrest QAYTA URINISHI O'CHIRILGAN BO'LISHI SHART.
  //
  // RUNTIME O'LCHOV (black-hole server, emulator, 2026-08-27): standart
  // `retryEnabled: true` + `retryCount: 3` postgrest'ga GET/HEAD so'rovini
  // HAR QANDAY `Exception` uchun (bizning `TimeoutException` ham) 4 marta
  // yuborishga ruxsat beradi. `getPosts` ketma-ket 3 ta GET qilgani uchun
  // Hamjamiyat ekrani 341–391 s shimmer ko'rsatdi
  // (`.runtime_evidence/r6_end_391s.png`) — ya'ni "20 s chegara" da'vosi
  // foydalanuvchi darajasida YOLG'ON edi.
  //
  // DIQQAT — BU SOZLAMA O'ZI YETARLI EMAS: `supabase 2.16.1` da u
  // `supabase.from()` yo'lida TASHLAB YUBORILADI va faqat `rest`/`rpc`
  // uchun kuchga kiradi. Xatti-harakat isboti va yechim:
  // `test/core/network/postgrest_retry_disabled_test.dart` +
  // `lib/core/network/supabase_db.dart`.
  //
  // Bu statik tekshiruv: `main.dart` ni real ishga tushirmaydi, faqat
  // sozlama TASODIFAN qaytarilmasligini qulflaydi.
  // ---------------------------------------------------------------------------
  test('main.dart postgrest avtomatik qayta urinishini o\'chiradi', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(
      source.contains('PostgrestClientOptions(retryEnabled: false)'),
      isTrue,
      reason: 'Supabase.initialize da `postgrestOptions: const '
          'PostgrestClientOptions(retryEnabled: false)` bo\'lishi SHART: aks '
          'holda har bir GET 4 marta yuboriladi va timeout chegarasi '
          'foydalanuvchi uchun 4 barobar cho\'ziladi.',
    );
  });

  // ---------------------------------------------------------------------------
  // ZANJIR UZUVCHI (circuit breaker).
  //
  // RUNTIME O'LCHOV (black-hole server, emulator, 2026-08-27): `retryEnabled:
  // false` dan keyin ham Hamjamiyat ekrani 110 s dan ortiq shimmer ko'rsatdi
  // (`.runtime_evidence/fix_110s.png`). Sabab per-so'rov chegarasi emas —
  // KETMA-KETLIK: bitta ekran yuklashi bir nechta so'rovni zanjir qiladi va
  // oldingi bo'g'in nosozligi ATAYLAB yutiladi, ya'ni har bo'g'in o'z 20 s
  // chegarasini oladi. Breaker shu zanjirni bitta chegaraga yig'adi.
  // ---------------------------------------------------------------------------
  group('breaker — timeout\'dan keyin zanjir TEZ yiqiladi', () {
    /// Testda vaqt QO'LDA suriladi — real kutish yo'q.
    late DateTime now;
    DateTime clock() => now;

    setUp(() => now = DateTime(2026, 8, 27, 21, 0));

    /// Har bir `send()` ni sanaydi: breaker ochiq bo'lsa transportga
    /// so'rov BORMASLIGI kerak.
    var reached = 0;

    http.BaseClient blackHole() {
      reached = 0;
      return _CountingBlackHoleClient(() => reached++);
    }

    test('ikkinchi so\'rov chegarani KUTMAYDI (transportga ham bormaydi)',
        () async {
      final client = TimeoutHttpClient(
        blackHole(),
        limit: const Duration(milliseconds: 30),
        breakerWindow: const Duration(seconds: 5),
        clock: clock,
      );

      await expectLater(
        client.send(_request()),
        throwsA(isA<TimeoutException>()),
      );
      expect(reached, 1);

      // Zanjirning keyingi bo'g'ini — real ekranda millisekundlar farqi bilan
      // ketadi, ya'ni oyna ichida.
      final started = DateTime.now();
      await expectLater(
        client.send(_request()),
        throwsA(isA<TimeoutException>()),
      );
      expect(reached, 1, reason: 'breaker ochiq — transportga bormasligi kerak');
      expect(
        DateTime.now().difference(started),
        lessThan(const Duration(milliseconds: 30)),
        reason: 'ikkinchi bo\'g\'in chegarani qaytadan kutmasligi SHART',
      );
    });

    test('oyna tugagach REAL zond so\'rovi o\'tadi (qo\'lda qayta urinish)',
        () async {
      final client = TimeoutHttpClient(
        blackHole(),
        limit: const Duration(milliseconds: 30),
        breakerWindow: const Duration(seconds: 5),
        clock: clock,
      );

      await expectLater(
          client.send(_request()), throwsA(isA<TimeoutException>()));
      expect(reached, 1);

      // Foydalanuvchi "Qaytadan urinish"ni bosdi — oyna tugagan.
      now = now.add(const Duration(seconds: 6));
      await expectLater(
          client.send(_request()), throwsA(isA<TimeoutException>()));
      expect(reached, 2, reason: 'qo\'lda qayta urinish REAL so\'rov yuborishi '
          'SHART — aks holda xato YOLG\'ON signal bo\'ladi');
    });

    test('boshqa SINF (AI) DB timeout\'idan o\'lmaydi', () async {
      final client = TimeoutHttpClient(
        blackHole(),
        limit: const Duration(milliseconds: 30),
        breakerWindow: const Duration(seconds: 5),
        clock: clock,
      );

      await expectLater(
          client.send(_request()), throwsA(isA<TimeoutException>()));
      expect(reached, 1);

      // 75 s lik AI so'rovi 20 s lik DB nosozligi sababli yiqilmasligi kerak.
      await expectLater(
        client.send(http.Request('POST',
            Uri.parse('https://example.supabase.co/functions/v1/legal-analysis'))),
        throwsA(isA<TimeoutException>()),
      );
      expect(reached, 2, reason: 'AI sinfi alohida breaker holatiga ega');
    });

    test('muvaffaqiyatli javob breaker holatini TOZALAYDI', () async {
      final flaky = _FlakyClient();
      final client = TimeoutHttpClient(
        flaky,
        limit: const Duration(milliseconds: 30),
        breakerWindow: const Duration(seconds: 5),
        clock: clock,
      );

      // 1-so'rov: timeout -> breaker ochiladi.
      await expectLater(
          client.send(_request()), throwsA(isA<TimeoutException>()));
      // Oyna tugadi, server tiklandi -> 200.
      now = now.add(const Duration(seconds: 6));
      expect((await client.send(_request())).statusCode, 200);
      // Holat tozalanganini tasdiqlash: oyna surilmasa ham keyingi so'rov
      // o'tishi kerak (eskirgan breaker holati QOLMAYDI).
      expect((await client.send(_request())).statusCode, 200);
    });

    test('classOf — yo\'l sinflari', () {
      Uri u(String p) => Uri.parse('https://example.supabase.co$p');
      expect(TimeoutHttpClient.classOf(u('/auth/v1/token')), '/auth/v1');
      expect(TimeoutHttpClient.classOf(u('/functions/v1/x')), '/functions/v1');
      expect(TimeoutHttpClient.classOf(u('/storage/v1/object/a')),
          '/storage/v1');
      expect(TimeoutHttpClient.classOf(u('/rest/v1/questions')), '/rest/v1');
      // Noma'lum yo'l ham DB sinfiga tushadi (fail-safe).
      expect(TimeoutHttpClient.classOf(u('/kelajak/yol')), '/rest/v1');
    });
  });
}
