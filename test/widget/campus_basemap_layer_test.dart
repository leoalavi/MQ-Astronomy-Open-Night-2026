import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/data/campus_variants_data.dart';
import 'package:aon2026/services/campus_variant_providers.dart';
import 'package:aon2026/widgets/campus_basemap_layer.dart';
import 'package:aon2026/widgets/map_config.dart';

String _asset(WidgetTester t) {
  final layer = t.widget<OverlayImageLayer>(find.byType(OverlayImageLayer));
  // imageProvider is declared on BaseOverlayImage (overlay_image.dart:10), so
  // no cast to the OverlayImage subtype is needed.
  final img = layer.overlayImages.single;
  return (img.imageProvider as AssetImage).assetName;
}

Widget _host(ProviderContainer c) => UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        home: Scaffold(
          body: FlutterMap(
            options: MapOptions(
              crs: const CrsSimple(),
              initialCameraFit: CameraFit.bounds(bounds: MapConfig.mapBounds),
            ),
            children: const [CampusBasemapLayer()],
          ),
        ),
      ),
    );

void main() {
  testWidgets('base: one overlay image = the dark campus (migrated)', (t) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await t.pumpWidget(_host(c));
    await t.pump();
    final layer = t.widget<OverlayImageLayer>(find.byType(OverlayImageLayer));
    expect(layer.overlayImages.length, 1); // still exactly one image
    expect(_asset(t), CampusVariantsData.baseAsset);
    expect(t.takeException(), isNull);
  });

  testWidgets('variant selected: renders that variant asset, still one image',
      (t) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(campusVariantProvider.notifier).select(CampusMapVariant.water);
    await t.pumpWidget(_host(c));
    await t.pump();
    final layer = t.widget<OverlayImageLayer>(find.byType(OverlayImageLayer));
    expect(layer.overlayImages.length, 1);
    expect(_asset(t), 'assets/maps/overlay_water_dark.png');
    expect(t.takeException(), isNull);
  });
}
