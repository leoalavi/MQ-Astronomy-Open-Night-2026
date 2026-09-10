import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

({int width, int height, int colourType}) _pngHeader(String path) {
  final bytes = File(path).readAsBytesSync();
  expect(bytes.sublist(0, 8), const [
    137,
    80,
    78,
    71,
    13,
    10,
    26,
    10,
  ], reason: '$path must be a PNG');
  final data = ByteData.sublistView(Uint8List.fromList(bytes));
  return (
    width: data.getUint32(16),
    height: data.getUint32(20),
    colourType: bytes[25],
  );
}

void main() {
  const source = 'assets/branding/app_icon_source.png';

  test('approved artwork is the exact iOS marketing icon', () {
    expect(File(source).readAsBytesSync(), isNotEmpty);
    expect(
      File(
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/'
        'Icon-App-1024x1024@1x.png',
      ).readAsBytesSync(),
      File(source).readAsBytesSync(),
    );
  });

  test('every platform icon has its required square dimensions and no alpha', () {
    const icons = <String, int>{
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png': 20,
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png': 40,
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png': 60,
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png': 29,
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png': 58,
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png': 87,
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png': 40,
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png': 80,
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png':
          120,
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png':
          120,
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png':
          180,
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png': 76,
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png':
          152,
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png':
          167,
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/'
              'Icon-App-1024x1024@1x.png':
          1024,
      'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': 48,
      'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': 72,
      'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': 96,
      'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 144,
      'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 192,
      // Adaptive-icon foreground layers (108dp canvas per density). Added for
      // the Google Play audit 2026-09-05: without mipmap-anydpi-v26, Android
      // 8+ launchers masked the square legacy PNG onto a white plate.
      'android/app/src/main/res/mipmap-mdpi/ic_launcher_foreground.png': 108,
      'android/app/src/main/res/mipmap-hdpi/ic_launcher_foreground.png': 162,
      'android/app/src/main/res/mipmap-xhdpi/ic_launcher_foreground.png': 216,
      'android/app/src/main/res/mipmap-xxhdpi/ic_launcher_foreground.png': 324,
      'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png':
          432,
      'web/favicon.png': 32,
      'web/icons/Icon-192.png': 192,
      'web/icons/Icon-512.png': 512,
      'web/icons/Icon-maskable-192.png': 192,
      'web/icons/Icon-maskable-512.png': 512,
      'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png': 16,
      'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png': 32,
      'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png': 64,
      'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png': 128,
      'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png': 256,
      'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png': 512,
      'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png': 1024,
    };

    for (final entry in icons.entries) {
      final header = _pngHeader(entry.key);
      expect(header.width, entry.value, reason: entry.key);
      expect(header.height, entry.value, reason: entry.key);
      expect(
        header.colourType,
        isNot(anyOf(4, 6)),
        reason: '${entry.key} must not contain an alpha channel',
      );
    }
  });

  test('visitor-facing mobile names use the 2026 app identity', () {
    expect(
      File('ios/Runner/Info.plist').readAsStringSync(),
      contains('<string>Astronomy Open Night 2026</string>'),
    );
    expect(
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
      contains('android:label="Astronomy Open Night 2026"'),
    );
    expect(
      File('web/manifest.json').readAsStringSync(),
      contains('"short_name": "Astronomy Open Night"'),
    );
    expect(
      File('macos/Runner/Info.plist').readAsStringSync(),
      contains('<string>Astronomy Open Night</string>'),
    );
  });

  test('Android adaptive icon is declared with a dark background and no '
      'monochrome layer', () {
    final xml = File('android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml')
        .readAsStringSync();
    expect(xml, contains('<adaptive-icon'));
    expect(xml, contains('@color/ic_launcher_background'));
    expect(xml, contains('@mipmap/ic_launcher_foreground'));
    // The artwork is a full-bleed square; a monochrome layer built from it
    // renders as a solid tile under themed icons. Add one only with a
    // purpose-drawn silhouette.
    expect(xml, isNot(contains('<monochrome')));
    final colour =
        File('android/app/src/main/res/values/ic_launcher_background.xml')
            .readAsStringSync();
    expect(colour, contains('#05070F'));
  });
}
