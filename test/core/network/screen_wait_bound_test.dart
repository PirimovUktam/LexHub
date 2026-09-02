/// EKRAN YUKLASH VAQTI CHEKLANGANMI — REAL socket ustida o'lchov.
///
/// NIMA UCHUN BU TEST BOR (runtime o'lchov, 2026-08-27, black-hole server +
/// emulator, release build, APK hash MATCH):
///   * `retryEnabled: true` (standart) bilan Hamjamiyat ekrani javob
///     bermaydigan serverda 341–391 s shimmer ko'rsatdi;
///   * `retryEnabled: false` dan keyin ham xato ekrani faqat
///     +88.66 s da chiqdi (`.runtime_evidence/err_89s.png`).
/// Ya'ni PER-SO'ROV chegarasi (20 s) foydalanuvchi ko'rgan vaqtni
/// CHEKLAMAYDI: bitta ekran yuklashi so'rovlarni ZANJIR qiladi va oldingi
/// bo'g'inning nosozligi ataylab yutiladi (katalog o'qilmasa feed yiqilmaydi,
/// `public_questions_view` ishlamasa `questions` jadvaliga tushadi).
///
/// Bu test mock ISHLATMAYDI: real `SupabaseClient`, real `postgrest`, real
/// `TimeoutHttpClient` va real TCP socket (javob bermaydigan server) bilan
/// ishlaydi — faqat chegaralar millisekundlarga siqilgan, shuning uchun
/// o'lchov tez va takrorlanadigan.
///
/// SABAB TOPILDI VA TUZATILDI (2026-08-27): zanjir uzun bo'lgani UCHUN emas,
/// balki HAR bo'g'in `postgrest` ning qayta urinish tsikliga tushgani uchun
/// cho'zilardi — `supabase.from()` `retryEnabled: false` sozlamasini TASHLAB
/// YUBORADI (batafsil: `lib/core/network/supabase_db.dart`). O'lchov:
///   * `from()` bilan: bitta mantiqiy so'rov 7.6 s (4 urinish + 1+2+4 s),
///     zanjir 22.2 s (siqilgan chegarada), qurilmada 88.66 s;
///   * `db()` bilan: bitta urinish, zanjirning qolgani breaker orqali
///     TEZ yiqiladi — jami 324 ms (chegara 300 ms).
///
/// QURILMADA TASDIQLANDI (2026-08-27 22:16, emulator-5554, release build,
/// APK hash MATCH `750a1145…`, black-hole server):
///   * birinchi tarmoq urinishi 22:16:22 (3 parallel TLS ulanish),
///     xato ekrani 22:16:42.5 — ya'ni BITTA `kDbRequestTimeout` (20 s) +
///     render; Hamjamiyat tab bosilganidan +17.55 s
///     (`.runtime_evidence/err_18s.png`);
///   * timeout'dan keyin zanjir uchun BIRORTA yangi ulanish OCHILMADI —
///     breaker ishlagani shundan ko'rinadi;
///   * "Qaytadan urinish" bosilganda AYNAN 1 ta REAL ulanish ketdi va
///     shimmer yana ~20 s davom etdi (+22.05 s, `err_22s.png`) — breaker
///     ilovani "o'lik" holatda qoldirmaydi.
/// Progressiya: 341–391 s -> >110 s -> 88.66 s -> 17.55–22 s.
library;


import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lexhub/core/network/supabase_db.dart';
import 'package:lexhub/core/network/timeout_http_client.dart';
import 'package:lexhub/features/community_forum/data/datasources/community_forum_remote_datasource.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Yuborilgan HAR BIR so'rovni VAQTI bilan yozib boradi — zanjir uzunligini
/// va bo'g'inlar orasidagi masofani shu ko'rsatadi.
class _RecordingClient extends http.BaseClient {
  _RecordingClient(this._inner);

  final http.Client _inner;
  final List<String> sent = [];
  final Stopwatch _clock = Stopwatch()..start();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final at = _clock.elapsedMilliseconds;
    final retry = request.headers['X-Retry-Count'];
    final label = '${request.method} ${request.url.path}'
        '${retry == null ? '' : ' [X-Retry-Count: $retry]'}';
    sent.add('+${at}ms $label');
    return _inner.send(request).then((r) {
      sent.add('  -> javob ${r.statusCode} (+${_clock.elapsedMilliseconds}ms)');
      return r;
    }, onError: (Object e) {
      sent.add('  -> xato ${e.runtimeType} (+${_clock.elapsedMilliseconds}ms)');
      throw e;
    });
  }
}

void main() {
  late ServerSocket blackHole;
  late List<Socket> accepted;
  late _RecordingClient recorder;
  late SupabaseClient supabase;

  /// Bitta so'rov chegarasi — real 20 s ning millisekundga siqilgan modeli.
  const perRequest = Duration(milliseconds: 300);

  setUp(() async {
    accepted = [];
    // Ulanishni QABUL QILADI, javob BERMAYDI: `send()` hech qachon tugamaydi.
    blackHole = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    blackHole.listen((s) => accepted.add(s));

    recorder = _RecordingClient(http.Client());
    supabase = SupabaseClient(
      'http://127.0.0.1:${blackHole.port}',
      'test-anon-key',
      httpClient: TimeoutHttpClient(recorder, limit: perRequest),
      // Ishlab chiqarishdagi sozlama (`main.dart`) bilan bir xil.
      postgrestOptions: const PostgrestClientOptions(retryEnabled: false),
    );
  });

  tearDown(() async {
    for (final s in accepted) {
      s.destroy();
    }
    await blackHole.close();
    recorder.close();
  });

  test('ketma-ket 3 so\'rov: FAQAT 1 tarmoq urinishi (zanjir yig\'iladi)',
      () async {
    final sw = Stopwatch()..start();
    final errors = <Object>[];
    for (var i = 0; i < 3; i++) {
      try {
        await supabase.db('categories').select();
      } catch (e) {
        errors.add(e);
      }
    }
    final elapsed = sw.elapsedMilliseconds;

    // ignore: avoid_print
    print('zanjir:\n${recorder.sent.join('\n')}\njami: ${elapsed}ms');

    expect(errors, hasLength(3));
    // `db()` -> retry YO'Q, ya'ni har mantiqiy so'rov = 1 urinish; breaker
    // esa 2-3-so'rovni transportga QO'YMAYDI.
    final networkSends =
        recorder.sent.where((l) => l.contains('GET /rest/v1')).length;
    expect(networkSends, 1,
        reason: 'ILGARI 4 ta edi: `from()` retry sozlamasini tashlagani uchun '
            'har so\'rov 4 urinish + 1+2+4 s backoff olardi (7.6 s/so\'rov). '
            'Zanjir: ${recorder.sent}');
    expect(elapsed, lessThan(perRequest.inMilliseconds * 2));
  });

  test('javob bermaydigan serverda feed yuklash CHEKLANGAN vaqtda yiqiladi',
      () async {
    final dataSource = CommunityForumDataSourceImpl(supabaseClient: supabase);

    final started = DateTime.now();
    Object? thrown;
    try {
      await dataSource.getPosts();
    } catch (e) {
      thrown = e;
    }
    final elapsed = DateTime.now().difference(started);

    // Diagnostika: zanjirning REAL uzunligi va tarkibi.
    // ignore: avoid_print
    print('--- so\'rov zanjiri ---\n${recorder.sent.join('\n')}\n'
        'jami kutish: ${elapsed.inMilliseconds} ms '
        '(bitta so\'rov chegarasi ${perRequest.inMilliseconds} ms), '
        'xato: ${thrown.runtimeType}');

    expect(thrown, isNotNull, reason: 'javob bermaydigan server xato berishi SHART');

    // ASOSIY INVARIANT: foydalanuvchi kutgan vaqt zanjir uzunligiga
    // KO'PAYMASLIGI kerak. Chegara: bitta so'rov chegarasi + zaxira.
    expect(
      elapsed,
      lessThan(perRequest * 2),
      reason: 'ekran yuklashda ${recorder.sent.length} so\'rov yozildi. '
          'ILGARI bu invariant BUZILARDI: har bo\'g\'in `postgrest` qayta '
          'urinishlari bilan 7.6 s olardi (jami 22.2 s siqilgan chegarada, '
          'qurilmada 88.66 s — `.runtime_evidence/err_89s.png`). Sabab: '
          '`supabase.from()` `retryEnabled: false` ni tashlab yuborardi '
          '(`lib/core/network/supabase_db.dart`).',
    );

  });
}
