import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The app-level privacy manifest, and the Xcode wiring that actually ships it.
///
/// A `PrivacyInfo.xcprivacy` sitting on disk but absent from the Runner target's
/// Resources build phase is worse than no manifest at all: the repo looks
/// compliant and the binary is not. Both halves are asserted here.
///
/// Content rules follow the same honesty line the rest of the app is held to —
/// the manifest may not claim tracking or data collection the app does not do,
/// and may not declare required-reason APIs this target never calls.
void main() {
  final manifest = File('ios/Runner/PrivacyInfo.xcprivacy');
  final pbxproj = File('ios/Runner.xcodeproj/project.pbxproj');

  test('the app ships its own privacy manifest', () {
    expect(
      manifest.existsSync(),
      isTrue,
      reason: 'ios/Runner/PrivacyInfo.xcprivacy is missing',
    );
  });

  test('it is referenced AND in a Resources build phase', () {
    final text = pbxproj.readAsStringSync();

    expect(
      text,
      contains('PrivacyInfo.xcprivacy */ = {isa = PBXFileReference'),
      reason: 'no PBXFileReference — Xcode does not know the file exists',
    );
    expect(
      text,
      contains('PrivacyInfo.xcprivacy in Resources */ = {isa = PBXBuildFile'),
      reason: 'no PBXBuildFile — the file is referenced but never built',
    );
    expect(
      text,
      contains('PrivacyInfo.xcprivacy in Resources */,'),
      reason: 'not listed in a Resources phase — it will not reach the bundle',
    );
  });

  test('it declares no tracking and no collected data', () {
    final xml = manifest.readAsStringSync();

    expect(xml, contains('<key>NSPrivacyTracking</key>'));
    expect(
      RegExp(r'<key>NSPrivacyTracking</key>\s*<false/>').hasMatch(xml),
      isTrue,
      reason: 'the app does no tracking; NSPrivacyTracking must be <false/>',
    );

    for (final key in const [
      'NSPrivacyCollectedDataTypes',
      'NSPrivacyTrackingDomains',
      'NSPrivacyAccessedAPITypes',
    ]) {
      expect(
        RegExp('<key>$key</key>\\s*<array/>').hasMatch(xml),
        isTrue,
        reason: '$key must stay an empty array while the app collects nothing '
            'and this target calls no required-reason API. If that changes, '
            'declare it here — do not delete this assertion.',
      );
    }
  });

  test('it is valid property list XML', () {
    final result = Process.runSync('plutil', ['-lint', manifest.path]);
    expect(
      result.exitCode,
      0,
      reason: 'plutil rejected the manifest: ${result.stdout}${result.stderr}',
    );
  });
}
