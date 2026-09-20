// 2026-09-20: prevent debug signing fallback and tracked private key material.
// Static contracts; actual production signing requires a real key/certificate.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release uses only the explicit release signing configuration', () {
    final source = File('android/app/build.gradle.kts').readAsStringSync();
    expect(source, contains('signingConfigs.findByName("release")'));
    expect(source, isNot(contains('signingConfigs.getByName("debug")')));
    expect(source, isNot(contains('signingConfigs.findByName("debug")')));
    expect(source, contains('check(releaseSigningReady)'));
    for (final task in ['assembleRelease', 'bundleRelease', 'packageRelease']) {
      expect(source, contains('"$task"'));
    }
  });

  test('release signing supports private CI variables without literal defaults',
      () {
    final source = File('android/app/build.gradle.kts').readAsStringSync();
    for (final name in [
      'STORE_FILE',
      'STORE_PASSWORD',
      'KEY_ALIAS',
      'KEY_PASSWORD',
    ]) {
      expect(source, contains('"LEXHUB_ANDROID_$name"'));
    }
    final template = File('android/key.properties.example').readAsLinesSync();
    final settings =
        template.where((line) => !line.startsWith('#') && line.contains('='));
    expect(settings.map((line) => line.split('=').first).toList(),
        ['storeFile', 'storePassword', 'keyAlias', 'keyPassword']);
    expect(settings.every((line) => line.split('=').last.isEmpty), isTrue);
    final ignores = File('android/.gitignore').readAsLinesSync();
    expect(
        ignores, containsAll(['key.properties', '**/*.keystore', '**/*.jks']));
  });
}
