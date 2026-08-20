import 'package:flutter/material.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/widgets/campus_basemap_layer.dart';
import 'package:aon2026/widgets/map_config.dart';

OverlayImage _overlay(WidgetTester t) {
  final layer = t.widget<OverlayImageLayer>(find.byType(OverlayImageLayer));
  // imageProvider is declared on BaseOverlayImage (overlay_image.dart:10), so
  // no cast to the OverlayImage subtype is needed.
  return layer.overlayImages.single as OverlayImage;
}

Widget _host() => MaterialApp(
      localizationsDelegates: AonL10n.localizationsDelegates,
      supportedLocales: AonL10n.supportedLocales,
      home: Scaffold(
        body: FlutterMap(
          options: MapOptions(
            crs: const CrsSimple(),
            initialCameraFit:
                CameraFit.bounds(bounds: MapConfig.aonMapBounds),
          ),
          children: const [CampusBasemapLayer()],
        ),
      ),
    );

void main() {
  testWidgets('renders exactly one overlay: the official AON event map',
      (t) async {
    await t.pumpWidget(_host());
    await t.pump();
    final layer = t.widget<OverlayImageLayer>(find.byType(OverlayImageLayer));
    expect(layer.overlayImages.length, 1);
    expect((_overlay(t).imageProvider as AssetImage).assetName,
        'assets/maps/aon_event_map.png');
    expect(t.takeException(), isNull);
  });

  testWidgets('the overlay is pinned to the AON footprint, NOT the MQ frame',
      (t) async {
    // The artwork is a different crop of the same master. Pinning it to
    // MapConfig.mapBounds would stretch it ~2.4% and slide every pin off the
    // ink — a regression that looks *almost* right, so assert it explicitly.
    await t.pumpWidget(_host());
    await t.pump();
    final bounds = _overlay(t).bounds;
    expect(bounds, MapConfig.aonMapBounds);
    expect(bounds, isNot(MapConfig.mapBounds));
    // The AON crop overhangs west/north of the MQ frame's origin.
    expect(bounds.west, lessThan(0));
    expect(bounds.north, greaterThan(MapConfig.mapBounds.north));
  });
}
