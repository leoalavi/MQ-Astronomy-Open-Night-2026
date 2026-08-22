import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/widgets/map_config.dart';
import 'package:aon2026/services/clock.dart';
import 'package:aon2026/services/location_service.dart';
import 'package:aon2026/services/preview_location.dart';

void main() {
  group('AonPalette', () {
    test('brightness is the single source of isDark', () {
      expect(AonPalette.dark.isDark, isTrue);
      expect(AonPalette.light.isDark, isFalse);
      // Derived, not stored separately — flipping brightness flips isDark, so
      // the two can never disagree.
      expect(AonPalette.dark.copyWith(brightness: Brightness.light).isDark,
          isFalse);
    });

    test('copyWith changes only what it is given', () {
      const base = AonPalette.dark;
      final tweaked = base.copyWith(accent: const Color(0xFF00FF00));

      expect(tweaked.accent, const Color(0xFF00FF00));
      // Everything else is carried through untouched.
      expect(tweaked.brightness, base.brightness);
      expect(tweaked.surfaceBase, base.surfaceBase);
      expect(tweaked.border, base.border);
      expect(tweaked.mapVenue, base.mapVenue);
      expect(tweaked.mapRouteCasing, base.mapRouteCasing);
    });

    test('copyWith with no arguments is the same palette', () {
      const base = AonPalette.light;
      final same = base.copyWith();
      expect(same.brightness, base.brightness);
      expect(same.accent, base.accent);
      expect(same.surfaceRaised, base.surfaceRaised);
      expect(same.mapTransport, base.mapTransport);
    });

    // A theme with no AonPalette extension: chrome must still resolve rather
    // than crash a screen mid-render, and it must follow the ambient
    // brightness rather than forcing dark onto a light scaffold.
    for (final (name, brightness, wantDark) in [
      ('dark', Brightness.dark, true),
      ('light', Brightness.light, false),
    ]) {
      testWidgets('context.aon follows a bare $name theme', (tester) async {
        late AonPalette resolved;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(useMaterial3: true, brightness: brightness),
            home: Builder(
              builder: (context) {
                resolved = context.aon;
                return const SizedBox();
              },
            ),
          ),
        );
        expect(resolved.isDark, wantDark);
      });
    }
  });

  group('PreviewLocationService', () {
    const service = PreviewLocationService();

    test('permission is always granted — nothing real is being read', () async {
      expect(await service.request(), LocationStatus.granted);
    });

    test('emits exactly one fix, at the campus centre, then closes', () async {
      final fixes = await service.watch().toList();
      expect(fixes, hasLength(1));
      expect(fixes.single.position, MapConfig.campusCentre);
      expect(fixes.single.accuracyMeters, 8);
    });

    test('service-enabled changes never fire — there is no service', () async {
      expect(await service.serviceEnabledChanges().toList(), isEmpty);
    });

    test('the settings escape hatches are inert, not missing', () async {
      // They must exist and do nothing: sending a preview user to the real OS
      // location settings would be a confusing no-op at best.
      await expectLater(service.openAppSettings(), completes);
      await expectLater(service.openLocationSettings(), completes);
    });
  });

  group('nowProvider', () {
    test('reads through whatever clock is installed', () {
      final fixed = DateTime(2026, 9, 19, 19, 30);
      final container = ProviderContainer(
        overrides: [clockProvider.overrideWithValue(FixedClock(fixed))],
      );
      addTearDown(container.dispose);
      expect(container.read(nowProvider), fixed);
    });
  });
}
