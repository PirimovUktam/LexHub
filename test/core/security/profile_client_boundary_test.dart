// 2026-09-20: rejects legacy profile wildcards/private columns in client reads.
// Source regression only; hosted ACL and own-profile RPC need runtime tests.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final publicColumns = <String>{
    'id', 'full_name', 'avatar_url', 'role', 'is_verified',
    'reputation_points', 'specialization', 'created_at', 'updated_at',
  };
  final direct = RegExp(
      r'''\.(?:from|db)\(\s*['"]profiles['"]\s*\)[\s\S]{0,400}?\.select\(([^)]*)\)''');
  final embedded = RegExp(r'\bprofiles(?:!\w+)?\(([^()]*)\)');
  bool safe(String selection) {
    final columns = selection.replaceAll(RegExp(r'''['"\s]'''), '').split(',');
    return columns.isNotEmpty && columns.every(publicColumns.contains);
  }

  test('all profile table and embedded reads use explicit public columns', () {
    var checked = 0;
    for (final folder in ['lib', 'test/integration']) {
      for (final file in Directory(folder).listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final source = file.readAsStringSync().split('\n')
            .where((line) => !line.trimLeft().startsWith('//')).join('\n');
        for (final pattern in [direct, embedded]) {
          for (final match in pattern.allMatches(source)) {
            checked++;
            expect(safe(match.group(1) ?? ''), isTrue, reason: file.path);
          }
        }
      }
    }
    expect(checked, greaterThanOrEqualTo(12));
  });

  test('synthetic wildcard and sensitive-column mutations are rejected', () {
    for (final value in ["''", "'*'", "'id,phone'", "'id,password'", "'id,app_metadata'"]) {
      final source = ".from('profiles').select($value)";
      final match = direct.firstMatch(source);
      expect(match, isNotNull);
      expect(safe(match?.group(1) ?? ''), isFalse);
    }
    expect(safe("'id,full_name,role'"), isTrue);
    expect(safe("'id, is_verified, reputation_points'"), isTrue);
  });
}
