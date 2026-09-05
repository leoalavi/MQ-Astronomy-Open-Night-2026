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

  test('it declares no tracking', () {
    final xml = manifest.readAsStringSync();

    expect(xml, contains('<key>NSPrivacyTracking</key>'));
    expect(
      RegExp(r'<key>NSPrivacyTracking</key>\s*<false/>').hasMatch(xml),
      isTrue,
      reason: 'the app does no tracking; NSPrivacyTracking must be <false/>',
    );
    expect(
      RegExp(r'<key>NSPrivacyTrackingDomains</key>\s*<array/>').hasMatch(xml),
      isTrue,
      reason: 'NSPrivacyTrackingDomains must stay an empty array while the app '
          'tracks nobody. If that changes, declare it here — do not delete '
          'this assertion.',
    );
  });

  test('it declares precise location as collected, and nothing else', () {
    // This assertion used to require NSPrivacyCollectedDataTypes to be an EMPTY
    // array, with the note "if that changes, declare it here". It changed: the
    // app transmits the visitor's live latLng to the Google Routes API as the
    // route origin (`google_routes_service.dart:58`) once they ask for walking
    // directions and have accepted the Google disclosure. Apple's definition of
    // "collect" covers transmission to a third-party partner, so an empty array
    // was a claim the app does not keep — the same defect class as blocker B1,
    // one file over.
    final xml = manifest.readAsStringSync();

    expect(xml, contains('NSPrivacyCollectedDataTypePreciseLocation'),
        reason: 'the Routes origin is precise location leaving the device');
    expect(xml, contains('NSPrivacyCollectedDataTypePurposeAppFunctionality'),
        reason: 'routing is app functionality — not analytics, not advertising');

    // Exactly one collected type. Over-declaring is as wrong as under-declaring:
    // the passport, favourites and saved plan never leave the device.
    expect(
      RegExp('<key>NSPrivacyCollectedDataType</key>').allMatches(xml).length,
      1,
      reason: 'only PreciseLocation is collected; nothing else leaves',
    );

    // Neither linked to an identity (there is no account and no identifier is
    // sent) nor used for tracking.
    for (final key in const [
      'NSPrivacyCollectedDataTypeLinked',
      'NSPrivacyCollectedDataTypeTracking',
    ]) {
      expect(
        RegExp('<key>$key</key>\\s*<false/>').hasMatch(xml),
        isTrue,
        reason: '$key must be <false/> — no account, no cross-app combination',
      );
    }
  });

  test(
      'it declares exactly the required-reason APIs statically linked into '
      'Runner, each with one approved reason', () {
    final xml = manifest.readAsStringSync();

    // Evidence (pub cache, 2026-09-05): sensors_plus 7.1.0 calls
    // ProcessInfo.systemUptime and package_info_plus 10.2.1 calls
    // fileModificationDate, and BOTH ship an empty NSPrivacyAccessedAPITypes.
    // Flutter links SwiftPM plugins statically, so App Store Connect attributes
    // those calls to the Runner executable — the app manifest must carry them.
    // Anything beyond these two would be an undocumented claim; anything less
    // is an ITMS-91053 "missing API declaration" at upload.
    final declared = RegExp(
      r'<key>NSPrivacyAccessedAPIType</key>\s*<string>(\w+)</string>\s*'
      r'<key>NSPrivacyAccessedAPITypeReasons</key>\s*<array>\s*'
      r'<string>([\w.]+)</string>\s*</array>',
    ).allMatches(xml).map((m) => (m.group(1)!, m.group(2)!)).toList();

    expect(
      declared,
      unorderedEquals(const [
        ('NSPrivacyAccessedAPICategorySystemBootTime', '35F9.1'),
        ('NSPrivacyAccessedAPICategoryFileTimestamp', 'C617.1'),
      ]),
      reason: 'the declared required-reason APIs must match what is actually '
          'linked into Runner (sensors_plus → systemUptime; package_info_plus → '
          'fileModificationDate). Re-verify the plugin manifests before '
          'changing this list.',
    );
    for (final cat in const ['DiskSpace', 'ActiveKeyboards', 'UserDefaults']) {
      expect(
        xml,
        isNot(contains('NSPrivacyAccessedAPICategory$cat')),
        reason: 'no linked code in the app target uses $cat '
            '(shared_preferences_foundation declares UserDefaults itself)',
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
