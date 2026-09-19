/// Guards the empty Git deployment regression measured on 2026-09-02.
/// Updated 2026-09-19: auto-deploy requires an explicit Flutter build/output.
/// Local configuration checks do not prove a successful Vercel deployment.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Git deployment builds Flutter before publishing build/web', () {
    final decoded = jsonDecode(File('vercel.json').readAsStringSync());
    expect(decoded, isA<Map<String, dynamic>>());
    final cfg = decoded as Map<String, dynamic>;
    expect(cfg.containsKey('framework'), isTrue);
    expect(cfg['framework'], isNull);
    expect(cfg['buildCommand'], 'python3 tool/vercel_build.py');
    expect(cfg['installCommand'], 'python3 --version');
    expect(cfg['outputDirectory'], 'build/web');
    expect(cfg['git'], {
      'deploymentEnabled': {'main': true},
    });
    expect(File('tool/vercel_build.py').existsSync(), isTrue);
    expect(File('pubspec.lock').existsSync(), isTrue);
    expect(cfg.containsKey('env'), isFalse,
        reason: 'Client configuration belongs in Vercel environment settings.');
  });
}
