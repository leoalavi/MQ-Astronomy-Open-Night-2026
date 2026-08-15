import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/widgets/map_config.dart';
import 'package:aon2026/widgets/campus_basemap_layer.dart';

void main() {
  testWidgets('basemap renders one overlay image, no exception', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FlutterMap(
          options: MapOptions(
            crs: const CrsSimple(),
            initialCameraFit: CameraFit.bounds(bounds: MapConfig.mapBounds),
          ),
          children: const [CampusBasemapLayer()],
        ),
      ),
    ));
    await t.pump();
    final layer = t.widget<OverlayImageLayer>(find.byType(OverlayImageLayer));
    expect(layer.overlayImages.length, 1);
    expect(t.takeException(), isNull);
  });
}
