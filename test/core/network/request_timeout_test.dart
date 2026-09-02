/// CHEKSIZ SPINNER GUARD — `withTimeout` + `ErrorHandler` zanjiri.
///
/// RUNTIME KUZATUV (2026-08-27, emulator): Global Search shimmer holatida
/// 4 daqiqadan ortiq qotib qoldi, `adb logcat` da birorta flutter satri yo'q
/// (exception ham tashlanmagan). Sabab: `lib/` da BIRORTA `.timeout(...)`
/// yo'q edi — `http`/PostgREST standart holatda CHEKSIZ kutadi.
///
/// Bu test uch bo'g'inni qulflaydi:
///   1. `withTimeout` chegaradan keyin HAQIQATAN `TimeoutException` tashlaydi;
///   2. vaqtida tugagan so'rov TEGILMAYDI (false positive yo'q);
///   3. `ErrorHandler` uni `FailureCode.timeout` ga aylantiradi — ya'ni UI
///      `errorTimeout` ARB matnini oladi, "Kutilmagan xatolik" EMAS.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexhub/core/errors/failure_code.dart';
import 'package:lexhub/core/errors/failures.dart';
import 'package:lexhub/core/errors/error_handler.dart';
import 'package:lexhub/core/network/request_timeout.dart';

void main() {
  group('withTimeout', () {
    test('chegaradan keyin TimeoutException tashlaydi (cheksiz kutish yo\'q)',
        () async {
      // Hech qachon yopilmaydigan Future — qotib qolgan socket modeli.
      final never = Completer<String>().future;

      await expectLater(
        never.withTimeout(const Duration(milliseconds: 40), label: 'test_rpc'),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('vaqtida tugagan so\'rovga tegmaydi', () async {
      final result = await Future.value('ok')
          .withTimeout(const Duration(seconds: 5), label: 'test_rpc');
      expect(result, 'ok');
    });

    test('label `details` ga tushadi, UI matniga aylanmaydi', () async {
      try {
        await Completer<void>()
            .future
            .withTimeout(const Duration(milliseconds: 20), label: 'global_search');
        fail('TimeoutException kutilgandi');
      } on TimeoutException catch (e) {
        expect(e.message, 'global_search');
        expect(e.duration, const Duration(milliseconds: 20));
      }
    });
  });

  group('ErrorHandler', () {
    test('TimeoutException -> FailureCode.timeout', () {
      final failure = ErrorHandler.handle(
        TimeoutException('global_search', const Duration(seconds: 20)),
      );

      expect(failure, isA<NetworkFailure>());
      expect(failure.code, FailureCode.timeout);
      expect(failure.statusCode, 408);
      // Texnik detal `details` da qoladi, `message` da EMAS.
      expect(failure.message, isNot(contains('TimeoutException')));
      expect(failure.details.toString(), contains('global_search'));
    });

    test('timeout `unknown` ga tushib qolmaydi (regressiya)', () {
      final failure = ErrorHandler.handle(TimeoutException('x'));
      expect(failure.code, isNot(FailureCode.unknown));
    });
  });
}
