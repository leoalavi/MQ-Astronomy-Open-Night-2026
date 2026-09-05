import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/data/buildings_asset.dart';
import 'package:aon2026/models/building.dart';

/// Seam (G6): the bundle the registry reads from. Overridable in tests to inject
/// malformed content and prove the non-fatal failure path.
final buildingsBundleProvider = Provider<AssetBundle>((_) => rootBundle);

/// Async campus building registry (170). A decode/load failure yields an empty
/// list (search still works over venues) — never a fatal error / blank map.
final buildingsProvider = FutureProvider<List<Building>>((ref) async {
  try {
    return await loadBuildings(ref.watch(buildingsBundleProvider));
  } catch (e, s) {
    // Debug-only: a release build must not write diagnostics to the device
    // log (nothing sensitive here, but release logging is release noise).
    if (kDebugMode) debugPrint('buildings.json load failed: $e\n$s');
    return const <Building>[];
  }
});
