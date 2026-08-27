import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The iOS Maps key must not go stale after a key rotation.
///
/// ## The bug this file exists to prevent
///
/// `ios/Flutter/Secrets.xcconfig` feeds Info.plist's `GMSApiKey`, and it is
/// generated from `.env` by `tool/sync_ios_secrets.rb`. The script rewrites the
/// file correctly — but it only runs from the Podfile's `pre_install` hook, and
/// `pod install` does NOT run on every build. So after a key rotation the
/// generated file kept the OLD key while `.env` had the new one, and the iOS
/// build silently shipped a dead key. That cost a debugging session chasing
/// phantom 401s that were really a stale artifact.
///
/// This test is the tripwire: it compares the two WITHOUT ever printing either,
/// so drift fails the suite instead of reaching a device.
void main() {
  String? valueOf(String path, String key) {
    final f = File(path);
    if (!f.existsSync()) return null;
    for (final raw in f.readAsLinesSync()) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#') || line.startsWith('//')) continue;
      final i = line.indexOf('=');
      if (i < 0) continue;
      if (line.substring(0, i).trim() == key) return line.substring(i + 1).trim();
    }
    return null;
  }

  test('the generated iOS secret matches .env (or both are absent)', () {
    final envKey = valueOf('.env', 'MAPS_API_KEY');
    final iosKey = valueOf('ios/Flutter/Secrets.xcconfig', 'MAPS_API_KEY');

    if (envKey == null || envKey.isEmpty) {
      // A clean checkout / CI has no .env. Nothing to be stale against — the
      // app ships "dark" by design, which other tests already cover.
      return;
    }

    expect(iosKey, isNotNull,
        reason: 'ios/Flutter/Secrets.xcconfig is missing while .env has a key. '
            'Run: ruby tool/sync_ios_secrets.rb');

    // Compare only — never surface either value in the failure message.
    expect(
      iosKey == envKey,
      isTrue,
      reason: 'ios/Flutter/Secrets.xcconfig is STALE relative to .env '
          '(lengths ${iosKey!.length} vs ${envKey.length}). The generator only '
          'runs during `pod install`, so a key rotation does not reach it on an '
          'ordinary build. Run: ruby tool/sync_ios_secrets.rb',
    );
  });

  test('neither secret file is tracked by git', () {
    // Belt and braces: the tripwire above reads real key material, so the files
    // it reads must never be committed.
    final tracked = Process.runSync(
      'git',
      ['ls-files', '.env', 'ios/Flutter/Secrets.xcconfig'],
    ).stdout.toString().trim();
    expect(tracked, isEmpty,
        reason: 'a secret input is tracked by git: $tracked');
  });
}
