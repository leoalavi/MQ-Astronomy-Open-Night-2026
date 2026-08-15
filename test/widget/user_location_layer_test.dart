import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:aon2026/models/campus_geometry.dart';
import 'package:aon2026/models/user_location_fix.dart';
import 'package:aon2026/services/campus_projection.dart';
import 'package:aon2026/widgets/user_location_layer.dart';

const _proj = CampusProjection();
const _gps = LatLng(-33.7737, 151.1134);
final _centre = _proj.project(const GpsPoint(_gps))!;

// Explicit initialCenter + initialZoom (not initialCameraFit) so zoom is
// controllable and the accuracy-circle radius can be read at a known zoom.
Widget _host(Widget child, {required double zoom}) => MaterialApp(
      home: Scaffold(
        body: FlutterMap(
          // Unique key per zoom so a second pumpWidget builds a FRESH map state
          // (initialZoom only applies at init; a reused State ignores it).
          key: ValueKey(zoom),
          options: MapOptions(
            crs: const CrsSimple(),
            initialCenter: _centre.value,
            initialZoom: zoom,
            minZoom: -5, // allow the negative CrsSimple zooms (default clamps at 0)
            maxZoom: 0,
          ),
          children: [child],
        ),
      ),
    );

double _radius(WidgetTester t) =>
    t.widget<CircleLayer>(find.byType(CircleLayer)).circles.single.radius;

void main() {
  testWidgets('normal fix renders a circle (migrated)', (t) async {
    final fix = UserLocationFix(position: _gps, accuracyMeters: 15);
    await t.pumpWidget(
        _host(UserLocationCircle(center: _centre, fix: fix), zoom: -3.4));
    await t.pump();
    expect(find.byType(CircleLayer), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('dot renders a MarkerLayer (migrated)', (t) async {
    await t.pumpWidget(
        _host(UserLocationDot(center: _centre), zoom: -3.4));
    await t.pump();
    expect(find.byType(MarkerLayer), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('low-accuracy fix omits the circle (migrated, Phase A §5.1)',
      (t) async {
    final fix = UserLocationFix(position: _gps, accuracyMeters: 500);
    await t.pumpWidget(
        _host(UserLocationCircle(center: _centre, fix: fix), zoom: -3.4));
    await t.pump();
    expect(find.byType(CircleLayer), findsNothing);
  });

  testWidgets('circle radius GROWS with zoom, same footprint (the P0 fix)',
      (t) async {
    final fix = UserLocationFix(position: _gps, accuracyMeters: 20);
    await t.pumpWidget(
        _host(UserLocationCircle(center: _centre, fix: fix), zoom: -3.8));
    await t.pump();
    final rLow = _radius(t);
    await t.pumpWidget(
        _host(UserLocationCircle(center: _centre, fix: fix), zoom: -2.8));
    await t.pump();
    final rHigh = _radius(t);
    expect(rLow, greaterThan(0));
    expect(rHigh, greaterThan(rLow)); // more screen px when zoomed in
  });
}
