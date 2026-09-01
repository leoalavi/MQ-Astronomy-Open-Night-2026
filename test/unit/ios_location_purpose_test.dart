import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// B1 regression: the iOS location purpose string must not deny what the app
/// does. `google_routes_service.dart` POSTs the user's origin latLng to the
/// Google Routes API when they choose walking directions, so a string claiming
/// location "is never sent anywhere" / "stays on your device" is false and would
/// be an inaccurate App Store disclosure. This test fails if that false claim is
/// ever reintroduced, and requires the string to disclose the Google path.
void main() {
  test('NSLocationWhenInUseUsageDescription is truthful about Google transmission',
      () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final match = RegExp(
      r'<key>NSLocationWhenInUseUsageDescription</key>\s*<string>(.*?)</string>',
      dotAll: true,
    ).firstMatch(plist);
    expect(match, isNotNull,
        reason: 'the location purpose string must be present');
    final s = match!.group(1)!.toLowerCase();

    // Must NOT deny the transmission that actually happens.
    expect(s, isNot(contains('never sent anywhere')),
        reason: 'false — the Routes path sends the origin to Google');
    expect(s, isNot(contains('stays on your device')),
        reason: 'incomplete — location leaves the device for walking directions');
    // Must disclose the Google walking-directions path.
    expect(s, contains('google'));
    expect(s, contains('directions'));
  });
}
