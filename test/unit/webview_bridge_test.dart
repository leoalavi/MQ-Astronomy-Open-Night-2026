import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/models/webview_bridge.dart';

void main() {
  test(
    'Dart->JS: hostile scene ids are JSON-escaped, not string-interpolated',
    () {
      expect(
        buildSelectSceneJs('a"; evilGlobalCall(); "'),
        'selectScene("a\\"; evilGlobalCall(); \\"");',
      );
      expect(
        buildSelectSceneJs('back\\slash'),
        'selectScene("back\\\\slash");',
      );
      expect(buildSelectSceneJs('line\nbreak'), 'selectScene("line\\nbreak");');
      expect(buildLoadTourJs({'a': 'x"y'}), 'loadTour({"a":"x\\"y"});');
    },
  );
  test('inbound sceneChanged is validated against the known scene set', () {
    final known = {'a', 'b'};
    expect(validatedInboundScene('a', known), 'a');
    expect(validatedInboundScene('evil', known), isNull);
    expect(validatedInboundScene(null, known), isNull);
    expect(validatedInboundScene(42, known), isNull);
    expect(validatedInboundScene(['a'], known), isNull);
  });
}
