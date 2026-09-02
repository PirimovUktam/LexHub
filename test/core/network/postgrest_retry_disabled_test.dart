/// `PostgrestClientOptions(retryEnabled: false)` HAQIQATAN ishlayaptimi?
///
/// Bu test MOCK BACKEND emas — real `SupabaseClient`, real `postgrest` va
/// urinishlarni SANAYDIGAN `http` transporti bilan ishlaydi. Ya'ni sozlama
/// "kodda bor" degan da'vo emas, XATTI-HARAKAT o'lchanadi.
///
/// NIMA UCHUN KERAK: `supabase 2.16.1` da sozlama `supabase.from()` yo'lida
/// TASHLAB YUBORILADI (batafsil: `lib/core/network/supabase_db.dart`).
/// Shu sababli `main.dart` dagi `retryEnabled: false` FAQAT `rest`/`rpc`
/// uchun kuchga kiradi, ilova esa hamma joyda `from()` ishlatardi —
/// natijada javob bermaydigan serverda ekran 88.66 s kutdi
/// (`.runtime_evidence/err_89s.png`).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lexhub/core/network/supabase_db.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Har bir so'rovni SANAYDI va `X-Retry-Count` sarlavhasini yozib oladi.
/// Bu sarlavhani FAQAT `postgrest` ning qayta urinish tsikli qo'yadi
/// (`postgrest_builder.dart:432`), ya'ni u tsikl ishlaganining ISBOTI.
class _CountingClient extends http.BaseClient {
  var sends = 0;
  final List<String> retryHeader = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    sends++;
    retryHeader.add(request.headers['X-Retry-Count'] ?? 'yo\'q');
    // `Exception` — postgrest uchun "qayta urinishga arziydigan" nosozlik.
    return Future.error(http.ClientException('tarmoq yo\'q', request.url));
  }
}

void main() {
  late _CountingClient counter;
  late SupabaseClient supabase;

  setUp(() {
    counter = _CountingClient();
    supabase = SupabaseClient(
      'http://127.0.0.1:1',
      'test-anon-key',
      httpClient: counter,
      // Ishlab chiqarishdagi sozlama (`main.dart`) bilan bir xil.
      postgrestOptions: const PostgrestClientOptions(retryEnabled: false),
    );
  });

  test('DEFEKT: from() sozlamani TASHLAYDI — 4 urinish yuboriladi', () async {
    await expectLater(
      supabase.from('categories').select(),
      throwsA(isA<Exception>()),
    );

    // 1 asosiy + 3 qayta urinish. Bu YOMON xatti-harakat ataylab qulflanadi:
    // paket yangilanganda tuzatilsa, test yiqiladi va biz `db()` qobig'ini
    // olib tashlashimiz mumkinligini BILAMIZ.
    expect(counter.sends, 4,
        reason: 'supabase_client.dart:209-221 `retryEnabled` ni uzatmaydi');
    expect(counter.retryHeader, ['yo\'q', '1', '2', '3']);
    // Diqqat: bu test ~7 s davom etadi — postgrest 1+2+4 s kutadi.
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('YECHIM: db() BITTA so\'rov yuboradi (qayta urinish YO\'Q)', () async {
    await expectLater(
      supabase.db('categories').select(),
      throwsA(isA<Exception>()),
    );

    expect(counter.sends, 1,
        reason: 'db() -> rest.from() -> retryEnabled: false');
    expect(counter.retryHeader, ['yo\'q']);
  });

  test('YECHIM: rpc() ham retry\'siz (rest.rpc orqali ketadi)', () async {
    await expectLater(
      supabase.rpc('search_law_articles', params: const {'q': 'test'}),
      throwsA(isA<Exception>()),
    );

    expect(counter.sends, 1);
  });

  // ---------------------------------------------------------------------------
  // STATIK QO'RIQCHI: yangi kod yana `from()` ga qaytmasligi kerak.
  //
  // Behavioural test faqat MAVJUD chaqiruvni tekshiradi; kelajakdagi yangi
  // datasource yana `from()` yozsa, u himoyasiz qoladi va buni hech kim
  // sezmaydi (nosozlik faqat javob bermaydigan serverda ko'rinadi).
  // ---------------------------------------------------------------------------
  test('lib/ ichida jadval nomi bilan `.from(` QOLMAGAN', () {
    final offenders = <String>[];
    // Jadval nomi string yoki `kXxxTable` konstantasi bo'lgan chaqiruvlar.
    final pattern = RegExp(r"""\.from\((?:['"]|k[A-Z])""");

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (pattern.hasMatch(lines[i])) {
          offenders.add('${entity.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: '`supabaseClient.from(...)` O\'RNIGA `supabaseClient.db(...)` '
          'ishlatilishi SHART — sabab `lib/core/network/supabase_db.dart` '
          'da yozilgan. Topildi:\n${offenders.join('\n')}',
    );
  });
}
