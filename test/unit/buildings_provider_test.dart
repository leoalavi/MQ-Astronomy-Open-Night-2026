import 'dart:convert';
import 'package:flutter/services.dart'; // provides Uint8List/ByteData too
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/data/buildings_asset.dart';
import 'package:aon2026/services/building_providers.dart';

/// A bundle that returns whatever string it's given for any key (G6 seam test).
class _StubBundle extends CachingAssetBundle {
  _StubBundle(this.payload);
  final String payload;
  @override
  Future<ByteData> load(String key) async {
    final bytes = utf8.encode(payload);
    return ByteData.view(Uint8List.fromList(bytes).buffer);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async => payload;
}

void main() {
  testWidgets('loadBuildings parses the bundled asset to 170', (t) async {
    await t.runAsync(() async {
      final list = await loadBuildings(rootBundle);
      expect(list.length, 170);
    });
  });

  testWidgets('buildingsProvider resolves to 170', (t) async {
    await t.runAsync(() async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final list = await c.read(buildingsProvider.future);
      expect(list.length, 170);
    });
  });

  test('G6: malformed JSON → buildingsProvider yields [] (non-fatal), no throw', () async {
    final c = ProviderContainer(overrides: [
      buildingsBundleProvider.overrideWithValue(_StubBundle('{ not json')),
    ]);
    addTearDown(c.dispose);
    final list = await c.read(buildingsProvider.future);
    expect(list, isEmpty);
  });
}
