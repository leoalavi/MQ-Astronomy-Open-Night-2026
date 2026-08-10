import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/models/indoor_manifest.dart';
import 'package:aon2026/widgets/map_mode_toggle.dart';
import 'package:aon2026/widgets/panorama_building_picker.dart';
import 'package:aon2026/widgets/panorama_scene_rail.dart';
import 'package:aon2026/widgets/panorama_web_view.dart';

const _two = '{"nodes":[{"id":"a","image":"indoor/a.jpg","description":"Scene A","neighbours":[]},{"id":"b","image":"indoor/b.jpg","description":"Scene B","neighbours":[]}]}';

void main() {
  Widget wrap(Widget child) => ProviderScope(child: MaterialApp(
        theme: AonTheme.build(),
        home: Scaffold(body: child),
      ));

  final surfaces = <String, Widget>{
    'toggle': MapModeToggle(value: MapMode.panorama, onChanged: (_) {}),
    'picker': PanoramaBuildingPicker(onOpen: (_) {}),
    'rail': PanoramaSceneRail(
        manifest: IndoorManifest.fromJson(_two), selectedSceneId: 'a', onSceneSelected: (_) {}),
    'unavailable': const PanoramaUnavailable(),
  };

  for (final size in [const Size(320, 568), const Size(414, 896)]) {
    surfaces.forEach((name, w) {
      testWidgets('$name @ ${size.width.toInt()}x${size.height.toInt()} / 2.0 no overflow', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: wrap(w),
        ));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    });
  }
}
