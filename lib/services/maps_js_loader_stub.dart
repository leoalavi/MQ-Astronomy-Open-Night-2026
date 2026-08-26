/// Non-web builds: the Maps JS API is meaningless here, and the native SDK is
/// keyed through the `aon2026/maps_sdk` MethodChannel instead. Never called on
/// mobile — the initialiser branches on `kIsWeb` before reaching this.
Future<bool> loadGoogleMapsJs(String apiKey) async => false;

/// Test seam parity with the web implementation.
void resetGoogleMapsJsLoaderForTest() {}
