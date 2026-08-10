import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/config/event_config.dart';
import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/screens/home_screen.dart';
import 'package:aon2026/screens/my_night_screen.dart';
import 'package:aon2026/screens/program_screen.dart';
import 'package:aon2026/screens/settings_screen.dart';
import 'package:aon2026/services/app_settings.dart';
import 'package:aon2026/services/clock.dart';
import 'package:aon2026/services/saved_events.dart';

/// Light/dark theme correctness.
///
/// The rule this file enforces is simple and unforgiving: **no text may be
/// rendered at less than WCAG AA contrast against the surface behind it.** A
/// half-migrated palette shows up here as grey-on-grey, which is exactly the
/// failure mode a "partial light theme" produces.
void main() {
  /// WCAG relative luminance.
  double luminance(Color c) {
    double ch(double v) {
      v = v / 255.0;
      return v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) as double;
    }

    return 0.2126 * ch(c.r * 255) + 0.7152 * ch(c.g * 255) + 0.0722 * ch(c.b * 255);
  }

  double contrast(Color a, Color b) {
    final la = luminance(a), lb = luminance(b);
    final hi = math.max(la, lb), lo = math.min(la, lb);
    return (hi + 0.05) / (lo + 0.05);
  }

  group('palette contrast', () {
    for (final (name, p) in [
      ('dark', AonPalette.dark),
      ('light', AonPalette.light),
    ]) {
      group(name, () {
        test('body text clears AA on both surfaces', () {
          for (final bg in [p.surfaceBase, p.surface, p.surfaceRaised]) {
            expect(contrast(p.contentPrimary, bg), greaterThanOrEqualTo(4.5),
                reason: '$name contentPrimary on $bg');
            expect(contrast(p.contentSecondary, bg), greaterThanOrEqualTo(4.5),
                reason: '$name contentSecondary on $bg');
            expect(contrast(p.contentTertiary, bg), greaterThanOrEqualTo(4.5),
                reason: '$name contentTertiary on $bg');
          }
        });

        test('accent and semantic colours clear AA on the base surface', () {
          for (final (label, c) in [
            ('accent', p.accent),
            ('info', p.info),
            ('live', p.live),
            ('soon', p.soon),
            ('error', p.error),
            ('tertiary', p.tertiary),
          ]) {
            expect(contrast(c, p.surfaceBase), greaterThanOrEqualTo(4.5),
                reason: '$name $label on surfaceBase');
            expect(contrast(c, p.surface), greaterThanOrEqualTo(4.5),
                reason: '$name $label on surface');
          }
        });

        test('onAccent is legible on an accent fill', () {
          expect(contrast(p.onAccent, p.accent), greaterThanOrEqualTo(4.5),
              reason: '$name onAccent over accent');
        });

        test('map marker colours are distinguishable from the base surface',
            () {
          for (final (label, c) in [
            ('mapVenue', p.mapVenue),
            ('mapParking', p.mapParking),
            ('mapFacility', p.mapFacility),
            ('mapTransport', p.mapTransport),
          ]) {
            // 3:1 — these are large graphical elements, not body text.
            expect(contrast(c, p.surfaceBase), greaterThanOrEqualTo(3.0),
                reason: '$name $label');
          }
        });
      });
    }

    test('the light theme is designed, not an inversion of dark', () {
      // If light were just inverted dark, the accents would be complements.
      // They are not — light gets its own deep amber, because #FFB945 on white
      // is about 1.9:1 and unusable.
      expect(AonPalette.light.accent, isNot(AonPalette.dark.accent));
      expect(contrast(AonPalette.dark.accent, AonPalette.light.surface),
          lessThan(4.5),
          reason: 'this is precisely why light needs its own accent');
      expect(contrast(AonPalette.light.accent, AonPalette.light.surface),
          greaterThanOrEqualTo(4.5));
    });

    test('route casing inverts between themes so the line always shows', () {
      expect(contrast(AonPalette.dark.mapRoute, AonPalette.dark.mapRouteCasing),
          greaterThanOrEqualTo(3.0));
      expect(
          contrast(
              AonPalette.light.mapRoute, AonPalette.light.mapRouteCasing),
          greaterThanOrEqualTo(3.0));
    });
  });

  group('ThemeData wiring', () {
    test('both themes attach the palette extension', () {
      for (final b in Brightness.values) {
        final t = AonTheme.forBrightness(b);
        final p = t.extension<AonPalette>();
        expect(p, isNotNull, reason: '$b theme has no AonPalette');
        expect(p!.brightness, b);
        expect(t.brightness, b);
        expect(t.scaffoldBackgroundColor, p.surfaceBase);
      }
    });

    for (final b in Brightness.values) {
      testWidgets('context.aon resolves the $b palette', (tester) async {
        late AonPalette resolved;
        await tester.pumpWidget(MaterialApp(
          theme: AonTheme.forBrightness(b),
          home: Builder(builder: (context) {
            resolved = context.aon;
            return const SizedBox.shrink();
          }),
        ));
        expect(resolved.brightness, b);
      });
    }
  });

  group('runtime switching', () {
    Widget app(Widget home) => ProviderScope(
          overrides: [
            baseClockProvider
                .overrideWithValue(FixedClock(EventInfo.at(19, 0))),
          ],
          child: Consumer(
            builder: (context, ref, _) => MaterialApp(
              localizationsDelegates: AonL10n.localizationsDelegates,
              supportedLocales: AonL10n.supportedLocales,
              theme: AonTheme.light(),
              darkTheme: AonTheme.build(),
              themeMode: ref.watch(themeModeProvider).themeMode,
              home: home,
            ),
          ),
        );

    testWidgets('switching Dark → Light repaints without a restart',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        SavedEventsStorage.keyFor(EventConfig.astronomyOpenNight.id):
            <String>[],
      });
      await tester.pumpWidget(app(const SettingsScreen()));
      await tester.pumpAndSettle();

      Brightness current() => Theme.of(
            tester.element(find.byType(SettingsScreen)),
          ).brightness;

      expect(current(), Brightness.dark, reason: 'event default is dark');

      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();
      expect(current(), Brightness.light);

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(current(), Brightness.dark);
    });

    testWidgets('System follows the platform brightness both ways',
        (tester) async {
      SharedPreferences.setMockInitialValues(
          {'settings.themeMode': AppThemeMode.system.name});

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await tester.pumpWidget(app(const SettingsScreen()));
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
        Brightness.light,
      );

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
        Brightness.dark,
      );
    });
  });

  group('major surfaces render in both themes', () {
    for (final (name, b) in [
      ('dark', Brightness.dark),
      ('light', Brightness.light),
    ]) {
      testWidgets('Home, Program, My Night and Settings — $name',
          (tester) async {
        SharedPreferences.setMockInitialValues({
          SavedEventsStorage.keyFor(EventConfig.astronomyOpenNight.id): [
            'keynote-artemis',
          ],
        });

        for (final screen in <Widget>[
          const HomeScreen(),
          const ProgramScreen(),
          const MyNightScreen(),
          const SettingsScreen(),
        ]) {
          await tester.pumpWidget(ProviderScope(
            overrides: [
              baseClockProvider
                  .overrideWithValue(FixedClock(EventInfo.at(19, 0))),
            ],
            child: MaterialApp(
              localizationsDelegates: AonL10n.localizationsDelegates,
              supportedLocales: AonL10n.supportedLocales,
              theme: AonTheme.forBrightness(b),
              home: screen,
            ),
          ));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull,
              reason: '${screen.runtimeType} threw in $name');
        }
      });
    }
  });
}
