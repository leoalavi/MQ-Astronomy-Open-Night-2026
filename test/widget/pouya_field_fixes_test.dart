import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/models/campus_geometry.dart';
import 'package:aon2026/models/data_confidence.dart';
import 'package:aon2026/models/search_entry.dart';
import 'package:aon2026/models/user_location_fix.dart';
import 'package:aon2026/services/campus_projection.dart';
import 'package:aon2026/services/compass_controller.dart';
import 'package:aon2026/services/heading_service.dart';
import 'package:aon2026/services/nearby_targets.dart';
import 'package:aon2026/widgets/compass_radar_view.dart';
import 'package:aon2026/widgets/nav_metrics.dart';
import 'package:aon2026/widgets/panorama_building_picker.dart';
import 'package:aon2026/widgets/user_location_layer.dart';
import '../support/fake_compass_controller.dart';

// Field fixes from Pouya's 28 Aug on-device testing (voice notes + screenshots):
//   1. The user-location dot/circle was amber (accent) — he asked for the
//      conventional BLUE "you are here" indicator.
//   2. The 360° picker's last card ("I · 17 Wally's Walk") hid behind the
//      floating glass tab bar — it never reserved the nav clearance the compass
//      list already does.
//   3. The compass rose showed targets' bearings but no marker for the user's
//      OWN position at the centre, so the facing pin at the rim read as
//      "a person over there".

const _proj = CampusProjection();
const _gps = LatLng(-33.7737, 151.1134);
final _centre = _proj.project(const GpsPoint(_gps))!;

Widget _mapHost(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      localizationsDelegates: AonL10n.localizationsDelegates,
      supportedLocales: AonL10n.supportedLocales,
      theme: ThemeData(brightness: brightness),
      home: Scaffold(
        body: FlutterMap(
          options: MapOptions(
            crs: const CrsSimple(),
            initialCenter: _centre.value,
            initialZoom: -3.4,
            minZoom: -5,
            maxZoom: 0,
          ),
          children: [child],
        ),
      ),
    );

Widget _pickerHost(void Function(String) onOpen) => ProviderScope(
  child: MaterialApp(
    localizationsDelegates: AonL10n.localizationsDelegates,
    supportedLocales: AonL10n.supportedLocales,
    theme: AonTheme.build(),
    home: Scaffold(body: PanoramaBuildingPicker(onOpen: onOpen)),
  ),
);

Future<void> _pumpCompass(WidgetTester t, ProviderContainer c) async {
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: Scaffold(body: CompassRadarView()),
      ),
    ),
  );
  await t.pump();
}

void main() {
  group('location indicator is the conventional blue, not amber', () {
    for (final (name, brightness, palette) in [
      ('light', Brightness.light, AonPalette.light),
      ('dark', Brightness.dark, AonPalette.dark),
    ]) {
      testWidgets('$name: the dot centre uses mapUserLocation, never accent', (
        t,
      ) async {
        await t.pumpWidget(
          _mapHost(UserLocationDot(center: _centre), brightness: brightness),
        );
        await t.pump();
        final colors = t
            .widgetList<DecoratedBox>(find.byType(DecoratedBox))
            .map((d) => (d.decoration as BoxDecoration).color)
            .toList();
        expect(colors, contains(palette.mapUserLocation));
        expect(colors, isNot(contains(palette.accent)));
      });
    }

    testWidgets('the accuracy circle is tinted from mapUserLocation', (
      t,
    ) async {
      final fix = UserLocationFix(position: _gps, accuracyMeters: 15);
      await t.pumpWidget(
        _mapHost(UserLocationCircle(center: _centre, fix: fix)),
      );
      await t.pump();
      final circle = t
          .widget<CircleLayer>(find.byType(CircleLayer))
          .circles
          .single;
      expect(
        circle.borderColor.withValues(alpha: 1.0),
        AonPalette.light.mapUserLocation,
      );
      expect(
        circle.color.withValues(alpha: 1.0),
        AonPalette.light.mapUserLocation,
      );
    });
  });

  group('360° picker clears the floating tab bar', () {
    testWidgets('the ListView reserves the island clearance', (t) async {
      t.view.physicalSize = const Size(800, 2400);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      await t.pumpWidget(_pickerHost((_) {}));
      await t.pump();
      final padding = t
          .widget<ListView>(find.byType(ListView))
          .padding!
          .resolve(TextDirection.ltr);
      expect(padding.bottom, greaterThanOrEqualTo(AonNavMetrics.barHeight));
      // ...and far above the old uniform 16px that caused the overlap.
      expect(padding.bottom, greaterThan(16));
    });

    testWidgets('the LAST card ("I · 17 Wally\'s Walk") is reachable AND tappable '
        'on a short screen (not just non-overflowing)', (t) async {
      // A short viewport forces the list to scroll — otherwise "reachable"
      // proves nothing (CLAUDE.md: prove the last row is reachable+tappable).
      t.view.physicalSize = const Size(360, 640);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      String? opened;
      await t.pumpWidget(_pickerHost((id) => opened = id));
      await t.pump();

      final lastCard = find.textContaining('17 Wally');
      await t.scrollUntilVisible(
        lastCard,
        200,
        scrollable: find.byType(Scrollable),
      );
      expect(lastCard, findsOneWidget);
      // scrollUntilVisible may stop as soon as one edge is visible. Centre it
      // before tapping so this checks the card action rather than the viewport.
      await t.ensureVisible(lastCard);
      await t.pump();
      await t.tap(lastCard);
      await t.pump();
      // Tapping the fully-cleared last card opens its tour — it is not trapped
      // behind the tab bar.
      expect(opened, '17-wallys-walk');
    });
  });

  group('compass rose marks the user\'s own position', () {
    const target = NearbyTarget(
      placeKey: 'building:T',
      title: 'Tower',
      kind: PlaceKind.building,
      lat: -33.77,
      lng: 151.11,
      distanceMeters: 20, // close: exactly the case where blips crowd centre
      trueBearingDegrees: 90,
      confidence: DataConfidence.confirmed,
    );

    testWidgets('a "you are here" marker sits at the rose centre', (t) async {
      final c = ProviderContainer(
        overrides: [
          compassControllerProvider.overrideWith(
            () => FakeCompassController(
              const CompassState(
                availability: HeadingAvailability.available,
                trueHeadingDegrees: 30,
              ),
            ),
          ),
          nearbyTargetsProvider.overrideWithValue(const [target]),
        ],
      );
      addTearDown(c.dispose);
      await _pumpCompass(t, c);
      expect(find.byKey(const ValueKey('compass-you-marker')), findsOneWidget);
      final viewCenter = t.getCenter(find.byType(CompassRadarView));
      final you = t.getCenter(find.byKey(const ValueKey('compass-you-marker')));
      expect((you.dx - viewCenter.dx).abs(), lessThan(20));
      expect((you.dy - viewCenter.dy).abs(), lessThan(20));
    });

    testWidgets(
      'the marker shows even while heading is acquiring (no fix yet)',
      (t) async {
        // On the simulator / indoors the magnetometer never resolves — the "you"
        // marker must still anchor the centre, since the facing pin is absent.
        final c = ProviderContainer(
          overrides: [
            compassControllerProvider.overrideWith(
              () => FakeCompassController(
                const CompassState(availability: HeadingAvailability.acquiring),
              ),
            ),
            nearbyTargetsProvider.overrideWithValue(const [target]),
          ],
        );
        addTearDown(c.dispose);
        await _pumpCompass(t, c);
        expect(
          find.byKey(const ValueKey('compass-you-marker')),
          findsOneWidget,
        );
      },
    );

    testWidgets('the marker is painted ON TOP of the target blips (z-order)', (
      t,
    ) async {
      // Regression guard: on the night every venue is close, so blips cluster at
      // the centre. If "you" is painted before them it gets buried — it must be
      // a LATER child of the rose Stack than the blips.
      final c = ProviderContainer(
        overrides: [
          compassControllerProvider.overrideWith(
            () => FakeCompassController(
              const CompassState(
                availability: HeadingAvailability.available,
                trueHeadingDegrees: 30,
              ),
            ),
          ),
          nearbyTargetsProvider.overrideWithValue(const [target]),
        ],
      );
      addTearDown(c.dispose);
      await _pumpCompass(t, c);

      final stack = t.widget<Stack>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('compass-you-marker')),
              matching: find.byType(Stack),
            )
            .first,
      );
      int youIndex = -1;
      final blipIndices = <int>[];
      for (var i = 0; i < stack.children.length; i++) {
        final child = stack.children[i];
        if (child.key == const ValueKey('compass-you-marker')) youIndex = i;
        if (child is Positioned && child.child is ExcludeSemantics) {
          blipIndices.add(i); // the target blips
        }
      }
      expect(youIndex, greaterThanOrEqualTo(0));
      expect(blipIndices, isNotEmpty);
      expect(
        youIndex,
        greaterThan(blipIndices.reduce((a, b) => a > b ? a : b)),
        reason: '"you" must paint after (on top of) every blip',
      );
    });
  });
}
