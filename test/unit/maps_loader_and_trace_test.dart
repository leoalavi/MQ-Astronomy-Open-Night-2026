import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/services/maps_js_loader.dart';
import 'package:aon2026/services/nav_trace.dart';

/// Coverage for the two debug/platform seams the web-Maps + nav work added
/// (`maps_js_loader_stub.dart`, `nav_trace.dart`). Both are tiny, but the
/// coverage policy has no exemption for them and they assert real contracts,
/// so a test is honester than a policy waiver.
void main() {
  test(
    'non-web Maps JS loader reports "not applicable"; its reset is a no-op',
    () async {
      // On the VM (non-web) the conditional export resolves to the stub, whose
      // documented contract is that the JS API is meaningless here — the native
      // `aon2026/maps_sdk` MethodChannel owns Maps on mobile, so the loader
      // must report false rather than pretend it loaded anything.
      expect(await loadGoogleMapsJs('unused-key'), isFalse);
      // Seam parity with the web implementation; must not throw.
      resetGoogleMapsJsLoaderForTest();
    },
  );

  test(
    'debug tracers execute the live branch under test without throwing',
    () {
      // The tracers are debug-only: in profile/release the tree-shaker drops
      // them because `kDebugMode` is a const false. Under `flutter test`
      // `kDebugMode` is true, so this exercises the real debugPrint branch and
      // proves neither tracer throws on a plain diagnostic string.
      expect(() {
        navTrace('provider_complete result=RouteSuccess');
        mapsLoaderTrace('loaded=true status=200 elapsedMs=42');
      }, returnsNormally);
    },
  );
}
