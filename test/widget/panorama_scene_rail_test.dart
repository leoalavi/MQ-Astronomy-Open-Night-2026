import 'package:flutter/material.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/models/indoor_manifest.dart';
import 'package:aon2026/widgets/panorama_scene_rail.dart';

const _two =
    '{"nodes":[{"id":"a","image":"indoor/a.jpg","description":"Scene A","neighbours":[]},{"id":"b","image":"indoor/b.jpg","description":"Scene B","neighbours":[]}]}';

void main() {
  testWidgets('renders a chip per scene; tapping one reports its id', (
    tester,
  ) async {
    String? picked;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: Scaffold(
          body: PanoramaSceneRail(
            manifest: IndoorManifest.fromJson(_two),
            selectedSceneId: 'a',
            onSceneSelected: (id) => picked = id,
          ),
        ),
      ),
    );
    expect(find.text('Scene A'), findsOneWidget);
    expect(find.text('Scene B'), findsOneWidget);
    await tester.tap(find.text('Scene B'));
    expect(picked, 'b');
  });
}
