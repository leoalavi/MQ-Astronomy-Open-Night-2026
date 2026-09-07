import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-manifest regression guard. SDK diagnostics can be collected without
/// sensitive permissions; audit the merged release manifest and Data safety too.
void main() {
  final manifest =
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

  /// Every permission the app is allowed to declare in its own manifest, with
  /// the reason it exists. Manifest-merger additions from plugins are not in
  /// this file; see the `dangerous` check below for those.
  const allowed = <String, String>{
    'android.permission.INTERNET': 'Google services and the loopback panorama viewer',
    'android.permission.CAMERA':
        'QR scanning for the Astronomy Passport, started only on tap',
    'android.permission.ACCESS_FINE_LOCATION':
        'on-device position marker on the campus map',
    'android.permission.ACCESS_COARSE_LOCATION':
        'on-device position marker on the campus map',
  };

  final declared = RegExp(r'<uses-permission\s+android:name="([^"]+)"')
      .allMatches(manifest)
      .map((m) => m.group(1)!)
      .toSet();

  test('the manifest declares only the permissions we can justify', () {
    final unexpected = declared.difference(allowed.keys.toSet());
    expect(
      unexpected,
      isEmpty,
      reason: 'New permission(s) $unexpected appeared in the manifest. Before '
          'allow-listing them, check whether Play\'s Data safety form and the '
          'privacy policy in docs/release/hosted-pages.md are still true.',
    );
  });

  test('every allow-listed permission is actually still declared', () {
    // Keeps the list from rotting the other way: a permission that is no longer
    // needed should be removed here too, not left as documentation of a past.
    final missing = allowed.keys.toSet().difference(declared);
    expect(
      missing,
      isEmpty,
      reason: 'Allow-listed but no longer declared: $missing — drop it from '
          'this test as well.',
    );
  });

  test('no unused sensitive permissions', () {
    // These capabilities are unnecessary for the implemented event features.
    const dangerous = <String, String>{
      'com.google.android.gms.permission.AD_ID': 'Device or other IDs',
      'android.permission.READ_EXTERNAL_STORAGE': 'Files and docs',
      'android.permission.WRITE_EXTERNAL_STORAGE': 'Files and docs',
      'android.permission.MANAGE_EXTERNAL_STORAGE': 'Files and docs',
      'android.permission.READ_MEDIA_IMAGES': 'Photos or videos',
      'android.permission.READ_MEDIA_VIDEO': 'Photos or videos',
      'android.permission.READ_MEDIA_AUDIO': 'Music and audio',
      'android.permission.RECORD_AUDIO': 'Music and audio',
      'android.permission.GET_ACCOUNTS': 'Personal info',
      'android.permission.READ_CONTACTS': 'Contacts',
      'android.permission.READ_CALENDAR': 'Calendar',
      'android.permission.READ_PHONE_STATE': 'Personal info (phone number)',
      'android.permission.READ_SMS': 'Messages',
      'android.permission.ACTIVITY_RECOGNITION': 'Health and fitness',
      'android.permission.BODY_SENSORS': 'Health and fitness',
      'android.permission.ACCESS_BACKGROUND_LOCATION': 'Location (background)',
    };

    for (final entry in dangerous.entries) {
      expect(
        manifest.contains(entry.key),
        isFalse,
        reason: '${entry.key} would require declaring "${entry.value}" in '
            "Play's Data safety form. See docs/release/play-store-listing.md.",
      );
    }
  });

  test('location is foreground-only', () {
    // The app draws a position marker while someone is looking at the map. It
    // has no reason to track anyone across the campus with the screen off, and
    // background location triggers a Play permissions declaration + review.
    expect(manifest, isNot(contains('ACCESS_BACKGROUND_LOCATION')));
  });
}
