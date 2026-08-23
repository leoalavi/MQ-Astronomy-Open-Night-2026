import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Android permission set is a **Play Data safety declaration in disguise**.
///
/// The Data safety form for this app answers "no user data collected", and that
/// answer is only defensible because of what the manifest does NOT ask for. A
/// single new plugin that drags in `AD_ID`, `READ_MEDIA_IMAGES` or
/// `GET_ACCOUNTS` would silently make the published declaration false — and Play
/// now runs automated checks against the binary before human review, so the
/// mismatch gets caught by Google rather than by us.
///
/// This test is the tripwire. If it fails, the fix is usually NOT to add the
/// permission to the allow-list: it is to work out which dependency added it and
/// whether the Data safety form and privacy policy now need to change too.
void main() {
  final manifest =
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

  /// Every permission the app is allowed to declare in its own manifest, with
  /// the reason it exists. Manifest-merger additions from plugins are not in
  /// this file; see the `dangerous` check below for those.
  const allowed = <String, String>{
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
          'privacy policy in docs/release/mq-hosted-pages.md are still true.',
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

  test('no permission that would force a Data safety disclosure', () {
    // Each of these maps to a data type the app currently declares as NOT
    // collected. Any of them appearing makes that declaration false.
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
