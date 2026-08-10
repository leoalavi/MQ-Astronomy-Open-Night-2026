import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/models/indoor_manifest.dart';
import 'package:aon2026/widgets/panorama_tour_view.dart';

const _two = '{"nodes":[{"id":"a","image":"indoor/a.jpg","description":"Scene A","neighbours":[]},{"id":"b","image":"indoor/b.jpg","description":"Scene B","neighbours":[]}]}';

void main() {
  testWidgets('rail<->viewer sync both directions', (tester) async {
    String? viewerScene;
    ValueChanged<String>? emit; // lets the test simulate a viewer hotspot
    Widget fakeViewer({required IndoorManifest manifest, required String? sceneId, required ValueChanged<String> onSceneChanged}) {
      viewerScene = sceneId;
      emit = onSceneChanged;
      return const SizedBox.expand();
    }

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: PanoramaTourView(
      manifest: IndoorManifest.fromJson(_two),
      viewerBuilder: fakeViewer,
    ))));

    // Direction 1: rail tap -> viewer.selectScene
    expect(viewerScene, 'a'); // opens on first scene
    await tester.tap(find.text('Scene B'));
    await tester.pump();
    expect(viewerScene, 'b');

    // Direction 2: viewer hotspot emits -> rail selection follows
    emit!('a');
    await tester.pump();
    expect(viewerScene, 'a');
  });
}
