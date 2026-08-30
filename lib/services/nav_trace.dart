import 'package:flutter/foundation.dart';

/// Debug-only tracing for the Google navigation pipeline.
///
/// ## Why this exists as a helper rather than bare `debugPrint`
///
/// The trace is what located the web Directions hang: the pipeline reached
/// `provider_complete result=RouteSuccess` and then stopped, which is how we
/// found that `mapsSdkReadyProvider` was only ever watched inside the
/// route-success branch. That diagnostic value is worth keeping — but not at
/// the cost of shipping a chatty log to visitors.
///
/// `kDebugMode` is a compile-time constant, so in profile and release builds
/// every call below is dead code the tree-shaker removes entirely: no strings
/// are retained and nothing reaches the console.
///
/// ## What may be traced
///
/// Booleans, enum names, counts, byte sizes, HTTP status codes and elapsed
/// milliseconds ONLY. Never an API key, never a coordinate, never a response
/// body — a diagnostic that leaks a secret is worse than no diagnostic.
void navTrace(String message) {
  if (kDebugMode) debugPrint('GoogleNavTrace: $message');
}

/// Same contract, for the web Maps JavaScript loader.
void mapsLoaderTrace(String message) {
  if (kDebugMode) debugPrint('MapsJsLoader: $message');
}

/// A NON-SECRET fingerprint of an API key, for diagnosing "which key is the
/// device actually using". Returns a length + a 32-bit FNV-1a hash in hex.
///
/// This is deliberately one-way and lossy: two runs with the SAME key print the
/// same `fp`, and a stale baked key prints a DIFFERENT `fp` — which is exactly
/// how the on-device Routes 401 (a valid key here, 401 there) is pinned to a
/// key mismatch without ever printing key material. An 8-hex-digit hash of a
/// ≥39-char key cannot be inverted to the key. Empty key → `fp=none`.
String keyFingerprint(String key) {
  if (key.isEmpty) return 'len=0 fp=none';
  var hash = 0x811c9dc5;
  for (final unit in key.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return 'len=${key.length} fp=${hash.toRadixString(16).padLeft(8, '0')}';
}
