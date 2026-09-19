// LexHub: detect hardcoded credential assignments without retaining real secrets.
// Updated 2026-09-20. A hash is not a login credential, but a low-entropy
// credential fingerprint can enable offline guessing. Real credential values
// and fingerprints are therefore never retained in this regression test.
// This syntactic guard covers credential fields/config defaults, not arbitrary
// obfuscation, all possible secret formats, or remote credential revocation.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../support/live_test_password.dart';

const _syntheticCredential = 'synthetic-fixture-only-credential';
const _thisTest = 'test/core/security/no_leaked_test_password_test.dart';
const List<String> _scanDirs = ['lib', 'test', 'tool', 'supabase', 'docs'];
const List<String> _scanExtensions = [
  '.dart',
  '.py',
  '.ts',
  '.sql',
  '.md',
  '.json',
  '.yaml',
  '.sh',
  '.ps1',
];

// Exact value AND path exceptions for reviewed mocks/negative-auth fixtures.
// A new value in these files, or the same value in other code, must fail.
const Map<String, Set<String>> _syntheticFixtures = {
  _thisTest: {_syntheticCredential},
  "supabase/functions/legal-ai/index_contract_test.ts": {
    "local-test-placeholder"
  },
  "test/features/auth/domain/usecases/auth_usecases_test.dart": {"password123"},
  "test/features/auth/email_confirmation_required_test.dart": {"parol123"},
  "test/features/auth/presentation/bloc/auth_bloc_test.dart": {
    "bad",
    "password123"
  },
  "test/features/legal_experts/data/datasources/apply_verification_no_fake_success_test.dart":
      {"test-access-token", "test-refresh-token"},
  "test/integration/real_supabase_e2e_test.dart": {
    "intentionally-invalid-not-a-credential"
  },
  "tool/test_vercel_build.py": {"private-fixture"},
};

const List<String> _mustUseHelper = [
  'test/integration/cleanup_live_test_data_test.dart',
  'test/integration/community_write_session_rls_live_test.dart',
  'test/integration/debug_signup_repro_test.dart',
  'test/integration/forensic_auth_split_diagnosis_test.dart',
  'test/integration/forensic_db_triggers_and_schema_test.dart',
  'test/integration/real_db_error_diagnostic_test.dart',
  'test/integration/real_supabase_mvp_fixes_verification_test.dart',
  'test/integration/real_supabase_signup_cloud_verification_test.dart',
  'test/integration/verify_community_answer_live_test.dart',
  'test/integration/verify_legal_ai_proxy_live_test.dart',
  'test/integration/verify_mvp_blockers_live_test.dart',
  'test/integration/verify_profile_invariant_live_test.dart',
  'test/integration/verify_rate_limit_error_mapping_test.dart',
];

String _norm(String p) => p.split(Platform.pathSeparator).join('/');

List<File> _sourceFiles() {
  final out = <File>[];
  for (final dir in _scanDirs) {
    final d = Directory(dir);
    if (!d.existsSync()) continue;
    for (final e in d.listSync(recursive: true, followLinks: false)) {
      if (e is! File) continue;
      if (_scanExtensions.any(e.path.endsWith)) out.add(e);
    }
  }
  return out;
}

// No match text or value leaves this function: diagnostics contain line numbers.
List<int> _hardcodedCredentialLines(String source, String path) {
  final assignment = RegExp(
    r'''(?:['"])?\b([a-z0-9_]*(?:password|passwd|pwd|secret|api_?key|access_?token|refresh_?token|(?:credential|password|leaked)_?(?:fingerprint|hash|digest)))\b(?:['"])?\s*[:=]\s*r?(['"])((?:\\.|(?!\2)[^\r\n])*?)\2''',
    caseSensitive: false,
  );
  final configDefault = RegExp(
    r'''String\.fromEnvironment\(\s*['"][^'"]*(?:PASSWORD|SECRET|KEY|TOKEN)[^'"]*['"]\s*,\s*defaultValue:\s*(['"])((?:\\.|(?!\1)[^\r\n])*?)\1''',
    caseSensitive: false,
  );
  final lines = <int>[];
  void inspect(RegExpMatch match, int valueGroup) {
    final value = match.group(valueGroup) ?? '';
    // Empty/template values and an interpolated variable are not credentials.
    if (value.isEmpty ||
        value == '...' ||
        RegExp(r'^<[^<>]+>$').hasMatch(value) ||
        RegExp(r'^\$(?:[a-zA-Z_]\w*|\{[^}]+\})$').hasMatch(value) ||
        (_syntheticFixtures[path]?.contains(value) ?? false)) {
      return;
    }
    lines.add('\n'.allMatches(source.substring(0, match.start)).length + 1);
  }

  for (final match in assignment.allMatches(source)) {
    inspect(match, 3);
  }
  for (final match in configDefault.allMatches(source)) {
    inspect(match, 2);
  }
  return lines.toSet().toList();
}

void main() {
  test('hardcoded credentials and stored credential digests are rejected', () {
    final syntheticDigest = List.filled(64, '0').join();
    final examples = [
      "const String password = '$_syntheticCredential';",
      "login(password: '$_syntheticCredential');",
      'const apiKey = "$_syntheticCredential";',
      '{"access_token": "$_syntheticCredential"}',
      "PASSWORD = '$_syntheticCredential'",
      "const password = '$_syntheticCredential' 'suffix';",
      "const credentialFingerprint = '$syntheticDigest';",
      "String.fromEnvironment('PASSWORD', defaultValue: '$_syntheticCredential');",
    ];
    for (var i = 0; i < examples.length; i++) {
      expect(_hardcodedCredentialLines(examples[i], 'lib/example.dart'), [1],
          reason: 'Credential syntax case $i must be rejected.');
    }
  });

  test('synthetic exceptions require both the exact value and test path', () {
    final source = "login(password: '$_syntheticCredential');";
    expect(_hardcodedCredentialLines(source, _thisTest), isEmpty);
    expect(_hardcodedCredentialLines(source, 'lib/example.dart'), [1]);
    expect(_hardcodedCredentialLines(source, 'test/integration/new_live.dart'),
        [1]);
    expect(
        _hardcodedCredentialLines(
            source.replaceAll(
                _syntheticCredential, 'different-synthetic-value'),
            _thisTest),
        [1]);
  });

  test('environment/config helpers are allowed without a static fallback', () {
    final source = r"""
const password = String.fromEnvironment('LEXHUB_TEST_PASSWORD');
login(password: liveTestPassword());
login(password: config.password);
const accessToken = '';
""";
    expect(_hardcodedCredentialLines(source, 'lib/example.dart'), isEmpty);
  });

  test('credential diagnostics never contain the offending value', () {
    final source = "// header\nlogin(password: '$_syntheticCredential');";
    final lines = _hardcodedCredentialLines(source, 'lib/example.dart');
    expect(lines, [2]);
    expect(lines.toString().contains(_syntheticCredential), isFalse);
  });

  test('source credential assignments contain only reviewed safe fixtures', () {
    final files = _sourceFiles();
    expect(files.length, greaterThan(400),
        reason:
            'Source scan must not pass with an empty or incomplete inventory.');
    final hits = <String>[];
    for (final file in files) {
      final path = _norm(file.path);
      for (final line
          in _hardcodedCredentialLines(file.readAsStringSync(), path)) {
        hits.add('$path:$line');
      }
    }
    expect(hits, isEmpty,
        reason: 'Hardcoded credential candidates (paths only).');
  });

  // 2026-09-20: prevent a static credential from reaching the real signup path.
  // This local source regression does not verify remote account revocation.
  test('Live MVP signup obtains its password from the environment helper', () {
    final source = File(
      'test/integration/real_supabase_mvp_fixes_verification_test.dart',
    ).readAsStringSync();
    expect(
      RegExp(r'password:\s*liveTestPassword\(\)').hasMatch(source),
      isTrue,
      reason: 'The real signup call must use the existing environment helper.',
    );
    expect(
      RegExp(r'''(?:const|final)\s+(?:String\s+)?testPassword\s*=\s*['"]''')
          .hasMatch(source),
      isFalse,
      reason: 'A static live-test password must not remain in the source.',
    );
  });

  test('live testlar parolni HELPER dan oladi', () {
    for (final path in _mustUseHelper) {
      final src = File(path).readAsStringSync();
      expect(src.contains('liveTestPassword()'), isTrue,
          reason: '$path parolni `liveTestPassword()` dan olishi kerak');
      expect(
          src.contains("import '../support/live_test_password.dart';"), isTrue,
          reason: '$path da helper import`i yo`q');
    }
  });

  test(
      'helper rejects missing or short defines and returns valid configuration',
      () {
    // Bu STATIK tekshiruv EMAS: funksiyaning O'ZI chaqiriladi.
    if (kLiveTestPasswordRaw.length < 16) {
      expect(liveTestPassword, throwsStateError,
          reason: 'Define yo`q — sukutdagi parol bilan JIM ishlamasligi kerak');
    } else {
      // Live yugurtirishda (`--dart-define=LEXHUB_TEST_PASSWORD=...`) qiymat
      // qaytadi va uzunlik sharti BAJARILGAN bo'lishi kerak.
      expect(liveTestPassword() == kLiveTestPasswordRaw, isTrue,
          reason: 'The helper must return exactly the configured value.');
    }
  });
}
