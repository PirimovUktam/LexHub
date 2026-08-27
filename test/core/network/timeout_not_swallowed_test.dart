/// TIMEOUT JIM YUTILMASLIGI — STATIK INVARIANT.
///
/// `lib/core/network/timeout_http_client.dart` BARCHA Supabase so'rovlariga
/// chegara qo'ydi. Lekin chegara faqat `TimeoutException` UI'ga TO'G'RI
/// yetib borsa foyda beradi: datasource'lardagi generic `catch (e)` shoxlari
/// ilgari uni `ServerException(message: '...: $e')` ga o'rab tashlagan, ya'ni
///   * `ErrorHandler` `FailureCode.server` bergan (ingliz UI `errorTimeout`
///     ARB matnini TANLAY OLMAGAN), va
///   * ba'zi joylarda XOM `TimeoutException after 0:00:20.000000: ...` matni
///     to'g'ridan-to'g'ri ekranga chiqqan.
///
/// INVARIANT: remote datasource'dagi har bir generic `} catch (e) {` bloki
/// ikkitadan bittasini BAJARISHI shart:
///   1. `if (e is TimeoutException) rethrow;` — timeout yuqoriga uzatiladi; yoki
///   2. `debugPrint(...)` — ataylab pasayish (degradation) shoxi, lekin JIM
///      emas: nosozlik log'da ko'rinadi.
///
/// Ikkisi ham bo'lmasa — bu jim yutilish, ya'ni CLAUDE.md §3 buzilishi.
/// Bu test yangi datasource yozilganda ham AVTOMATIK qamrab oladi.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _catchStart = '} catch (e) {';

class _Violation {
  _Violation(this.path, this.line);
  final String path;
  final int line;
  @override
  String toString() => '$path:$line';
}

/// `} catch (e) {` dan boshlab, AYNI chekinishdagi yopuvchi `}` gacha bo'lgan
/// satrlarni qaytaradi (ichki bloklar chekinishi kattaroq bo'lgani uchun
/// ular ham qamrab olinadi).
List<String> _blockBody(List<String> lines, int startIndex) {
  final indent = lines[startIndex].indexOf('}');
  final body = <String>[];
  for (var i = startIndex + 1; i < lines.length; i++) {
    final line = lines[i];
    final trimmed = line.trimLeft();
    final closes = trimmed.startsWith('}') &&
        line.length - trimmed.length <= indent;
    if (closes) break;
    body.add(line);
  }
  return body;
}

void main() {
  test('remote datasource generic `catch (e)` timeout\'ni yutmaydi', () {
    final files = Directory('lib/features')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.replaceAll(r'\', '/').contains('/data/datasources/'))
        .where((f) => f.path.endsWith('_remote_datasource.dart'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    // Qamrov o'zi ham qulflanadi: fayl nomlash qoidasi o'zgarsa yoki
    // datasource ko'chirilsa, bu test JIM ravishda bo'sh qolmasligi kerak.
    expect(files.length, greaterThanOrEqualTo(8),
        reason: 'Remote datasource fayllari topilmadi — skaner yo\'li eskirgan.');

    final violations = <_Violation>[];
    for (final file in files) {
      final path = file.path.replaceAll(r'\', '/');
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].trim() != _catchStart) continue;
        final body = _blockBody(lines, i).join('\n');
        final rethrowsTimeout = body.contains('e is TimeoutException) rethrow');
        final logs = body.contains('debugPrint(');
        if (!rethrowsTimeout && !logs) {
          violations.add(_Violation(path, i + 1));
        }
      }
    }

    expect(violations, isEmpty,
        reason: 'Bu bloklar timeout\'ni JIM yutadi. Yechim: '
            '`if (e is TimeoutException) rethrow;` qo\'sh, yoki ataylab '
            'pasayish bo\'lsa `debugPrint` bilan sababini log\'ga yoz:\n'
            '${violations.join('\n')}');
  });
}
