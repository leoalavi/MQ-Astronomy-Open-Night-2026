import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/widgets/glass_surface.dart';
import 'package:aon2026/widgets/map_control_island.dart';

void main() {
  group('clampZoom', () {
    test('in-range steps change the value', () {
      expect(clampZoom(16, 1, min: 14, max: 19), 17);
      expect(clampZoom(16, -1, min: 14, max: 19), 15);
    });
    test('clamps at the upper bound (no-op past max)', () {
      expect(clampZoom(19, 1, min: 14, max: 19), 19);
      expect(clampZoom(18.5, 1, min: 14, max: 19), 19);
    });
    test('clamps at the lower bound (no-op past min)', () {
      expect(clampZoom(14, -1, min: 14, max: 19), 14);
    });
  });

  Widget harness({
    required VoidCallback onZoomIn,
    required VoidCallback onZoomOut,
    required VoidCallback onRecenter,
  }) {
    return MaterialApp(
      theme: ThemeData(brightness: Brightness.dark),
      home: Scaffold(
        body: Center(
          child: MapControlIsland(
            onZoomIn: onZoomIn,
            onZoomOut: onZoomOut,
            onRecenter: onRecenter,
          ),
        ),
      ),
    );
  }

  testWidgets('renders ONE glass surface with three buttons', (tester) async {
    await tester.pumpWidget(harness(
      onZoomIn: () {},
      onZoomOut: () {},
      onRecenter: () {},
    ));
    expect(find.byType(GlassSurface), findsOneWidget); // one control layer, not three
    expect(find.byType(IconButton), findsNWidgets(3));
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    expect(find.byIcon(Icons.remove_rounded), findsOneWidget);
    expect(find.byIcon(Icons.my_location_rounded), findsOneWidget);
  });

  testWidgets('each button fires its injected callback', (tester) async {
    var zin = 0, zout = 0, rec = 0;
    await tester.pumpWidget(harness(
      onZoomIn: () => zin++,
      onZoomOut: () => zout++,
      onRecenter: () => rec++,
    ));
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.tap(find.byIcon(Icons.remove_rounded));
    await tester.tap(find.byIcon(Icons.my_location_rounded));
    expect([zin, zout, rec], [1, 1, 1]);
  });

  testWidgets('tap targets are >= 56 at 1.0 and 2.0 text scale', (tester) async {
    for (final scale in [1.0, 2.0]) {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            body: Center(
              child: MapControlIsland(
                onZoomIn: () {},
                onZoomOut: () {},
                onRecenter: () {},
              ),
            ),
          ),
        ),
      ));
      final size = tester.getSize(find.widgetWithIcon(IconButton, Icons.add_rounded));
      expect(size.height, greaterThanOrEqualTo(56.0), reason: 'scale $scale');
      expect(size.width, greaterThanOrEqualTo(56.0), reason: 'scale $scale');
    }
  });
}
