import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/screens/home_screen.dart';
import 'package:aon2026/screens/info_screen.dart';
import 'package:aon2026/screens/map_screen.dart';
import 'package:aon2026/screens/my_night_screen.dart';
import 'package:aon2026/screens/passport_screen.dart';
import 'package:aon2026/screens/point_me_screen.dart';
import 'package:aon2026/screens/program_screen.dart';
import 'package:aon2026/screens/settings_screen.dart';
import 'package:aon2026/screens/wayfinding_screen.dart';

import '../support/fake_location_service.dart';
import '../support/map_harness.dart';

/// iPad support comes from `TARGETED_DEVICE_FAMILY = "1,2"` in
/// `ios/Runner.xcodeproj/project.pbxproj` (three configurations) — not from the
/// orientation keys in Info.plist. That is what obliges a 13" screenshot set and
/// a layout that actually works, and no milestone had ever verified one.
///
/// 13-inch iPad, portrait and landscape, in logical pixels.
const _portrait = Size(1032, 1376);
const _landscape = Size(1376, 1032);

/// Both shipped locales. RTL is exactly where a "looks fine on iPad" test
/// betrays you: mirrored padding, clipped trailing widgets, rows that were
/// comfortable left-to-right.
const _locales = <Locale>[Locale('en'), Locale('fa')];

Future<void> _expectNoOverflow(
  WidgetTester t,
  Widget screen,
  Size size,
  double textScale,
  Locale locale,
) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);

  // MapScreen and PointMeScreen need a location service; the shared harness
  // supplies one. Everything else is unaffected by the extra override.
  final container = mapContainer(FakeLocationService());

  await t.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AonL10n.localizationsDelegates,
      supportedLocales: AonL10n.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: screen,
      ),
    ),
  ));
  await t.pumpAndSettle();

  // A RenderFlex overflow is reported as a framework exception, so an empty
  // exception queue IS the assertion.
  expect(t.takeException(), isNull);
}

void main() {
  // EVERY public route, not a comfortable subset. A screen absent from this map
  // is a screen nobody checked.
  final screens = <String, Widget Function()>{
    'home': () => const HomeScreen(),
    'program': () => const ProgramScreen(),
    'map': () => const MapScreen(),
    'passport': () => const PassportScreen(),
    'myNight': () => const MyNightScreen(),
    'info': () => const InfoScreen(),
    'settings': () => const SettingsScreen(),
    'wayfinding': () => const WayfindingScreen(),
    // point_me_screen.dart:18 — venueId is REQUIRED.
    'pointMe': () => const PointMeScreen(venueId: 'observatory'),
  };

  for (final entry in screens.entries) {
    for (final locale in _locales) {
      for (final scale in <double>[1.0, 2.0]) {
        final tag = '${entry.key} ${locale.languageCode} @${scale}x';

        // Only MapScreen needs runAsync: it loads the basemap through
        // rootBundle, which does real I/O and would hang a fake-async zone.
        // Wrapping the others costs nothing but breaks Flutter's error
        // formatting (demangleStackTrace) and masks real failures.
        final needsRealAsync = entry.key == 'map';

        testWidgets('$tag does not overflow on iPad portrait', (t) async {
          Future<void> body() =>
              _expectNoOverflow(t, entry.value(), _portrait, scale, locale);
          await (needsRealAsync ? t.runAsync(body) : body());
        });

        testWidgets('$tag does not overflow on iPad landscape', (t) async {
          Future<void> body() =>
              _expectNoOverflow(t, entry.value(), _landscape, scale, locale);
          await (needsRealAsync ? t.runAsync(body) : body());
        });
      }
    }
  }
}
