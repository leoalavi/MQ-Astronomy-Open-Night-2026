import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Two things are guarded here, and they are different failures.
///
/// **B1 (truthfulness).** `google_routes_service.dart` POSTs the user's origin
/// latLng to the Google Routes API when they choose walking directions, so a
/// purpose string claiming location "is never sent anywhere" / "stays on your
/// device" is false and would be an inaccurate App Store disclosure. Every
/// location purpose string must disclose the Google walking-directions path.
///
/// **ITMS-90683 (presence).** TestFlight Build 2 (1.0.0+2, 2026-09-05) came back
/// with "Missing purpose string in Info.plist … should contain a
/// NSLocationAlwaysAndWhenInUseUsageDescription key". The app never requests
/// Always authorisation — geolocator's `PermissionHandler.m` takes the
/// `requestWhenInUseAuthorization` branch whenever
/// NSLocationWhenInUseUsageDescription is present, which it is — but
/// `requestAlwaysAuthorization` is *compiled into* geolocator_apple, and Flutter
/// links the SwiftPM plugins statically into Runner, so Apple's static scan
/// attributes the API to the Runner bundle and demands the string. Deleting the
/// key re-raises the warning on the next upload.
///
/// The string is therefore written for App Review, and the last group of tests
/// keeps it honest: no location background mode, so "only while it is open" is
/// a claim the binary actually keeps.
void main() {
  final plist = File('ios/Runner/Info.plist').readAsStringSync();

  String purposeString(String key) {
    final match = RegExp(
      '<key>$key</key>\\s*<string>(.*?)</string>',
      dotAll: true,
    ).firstMatch(plist);
    expect(match, isNotNull, reason: '$key must be present in Info.plist');
    return match!.group(1)!.toLowerCase();
  }

  void expectTruthfulAboutGoogle(String key) {
    final s = purposeString(key);

    // Must NOT deny the transmission that actually happens.
    expect(s, isNot(contains('never sent anywhere')),
        reason: 'false — the Routes path sends the origin to Google');
    expect(s, isNot(contains('stays on your device')),
        reason: 'incomplete — location leaves the device for walking directions');
    // Must disclose the Google walking-directions path.
    expect(s, contains('google'));
    expect(s, contains('directions'));
  }

  test('NSLocationWhenInUseUsageDescription is truthful about Google transmission',
      () {
    expectTruthfulAboutGoogle('NSLocationWhenInUseUsageDescription');
  });

  test('NSLocationAlwaysAndWhenInUseUsageDescription is present (ITMS-90683)',
      () {
    // geolocator_apple compiles requestAlwaysAuthorization into Runner, so Apple
    // requires the string even though the app only ever asks for When In Use.
    expect(purposeString('NSLocationAlwaysAndWhenInUseUsageDescription'),
        isNotEmpty);
  });

  test('NSLocationAlwaysAndWhenInUseUsageDescription is truthful about Google transmission',
      () {
    expectTruthfulAboutGoogle('NSLocationAlwaysAndWhenInUseUsageDescription');
  });

  test('the Always string does not promise background location', () {
    // It claims the app only uses location while open. Nothing in the bundle may
    // contradict that: no location background mode, no Always prompt.
    expect(purposeString('NSLocationAlwaysAndWhenInUseUsageDescription'),
        contains('only uses your location while it is open'));
    final backgroundModes = RegExp(
      r'<key>UIBackgroundModes</key>\s*<array>(.*?)</array>',
      dotAll: true,
    ).firstMatch(plist);
    expect(backgroundModes?.group(1) ?? '', isNot(contains('<string>location</string>')),
        reason: 'a location background mode would make the string false');
  });
}
