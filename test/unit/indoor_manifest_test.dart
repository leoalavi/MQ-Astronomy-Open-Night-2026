import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/models/indoor_manifest.dart';

const _twoScene = '''
{"nodes":[
 {"id":"a","image":"indoor/a.jpg","neighbours":[{"targetId":"b","heading":10,"label":"B"}]},
 {"id":"b","image":"indoor/b.jpg","neighbours":[{"targetId":"a","heading":-170}]}
]}''';

void main() {
  test('parses nodes and builds an equirectangular Pannellum config', () {
    final m = IndoorManifest.fromJson(_twoScene);
    expect(m.nodes.length, 2);
    final cfg = m.buildPannellumConfig(assetBaseUrl: 'http://localhost:8459/data');
    expect((cfg['default'] as Map)['firstScene'], 'a');
    final scenes = cfg['scenes'] as Map<String, dynamic>;
    expect((scenes['a'] as Map)['type'], 'equirectangular');
    expect((scenes['a'] as Map)['panorama'], 'http://localhost:8459/data/indoor/a.jpg');
    expect(((scenes['a'] as Map)['hotSpots'] as List).first['sceneId'], 'b');
  });

  test('SECURITY: unsafe image refs are blanked, never off-origin', () {
    for (final bad in ['https://evil/x.jpg', '/abs/x.jpg', '//host/x.jpg', '../../secret.jpg', 'data:image/png;base64,AAAA']) {
      final m = IndoorManifest.fromJson('{"nodes":[{"id":"a","image":${_json(bad)},"neighbours":[]}]}');
      final scenes = m.buildPannellumConfig(assetBaseUrl: 'http://localhost:8459/data')['scenes'] as Map;
      expect((scenes['a'] as Map)['panorama'], '', reason: bad);
    }
    final ok = IndoorManifest.fromJson('{"nodes":[{"id":"a","image":"indoor/a.jpg","neighbours":[]}]}');
    final okScenes = ok.buildPannellumConfig(assetBaseUrl: 'http://localhost:8459/data')['scenes'] as Map;
    expect((okScenes['a'] as Map)['panorama'], 'http://localhost:8459/data/indoor/a.jpg');
  });

  test('REDUCED MOTION: no scene fade and autoRotate off', () {
    final m = IndoorManifest.fromJson(_twoScene);
    final normal = m.buildPannellumConfig(assetBaseUrl: 'x')['default'] as Map;
    expect(normal['sceneFadeDuration'], 600);
    final reduced = m.buildPannellumConfig(assetBaseUrl: 'x', reduceMotion: true)['default'] as Map;
    expect(reduced['sceneFadeDuration'], 0);
    expect(reduced['autoRotate'], false);
  });
}

String _json(String s) => '"${s.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
