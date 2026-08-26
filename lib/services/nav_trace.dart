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
