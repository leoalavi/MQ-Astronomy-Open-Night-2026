import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/services/maps_nav_providers.dart';

ProviderContainer _c({required MapsNavPlatform platform, bool routes = false, bool nativeMap = false}) {
  final c = ProviderContainer(overrides: [
    mapsNavPlatformProvider.overrideWithValue(platform),
    routesConfiguredProvider.overrideWithValue(routes),
    embeddedMapConfiguredProvider.overrideWithValue(nativeMap),
  ]);
  addTearDown(c.dispose);
  return c;
}

// Cross-key container: overrides the RAW keys (not routesConfigured) so the
// platform-selection logic itself is under test (#5).
ProviderContainer _cKeys({required MapsNavPlatform platform, String android = '', String ios = ''}) {
  final c = ProviderContainer(overrides: [
    mapsNavPlatformProvider.overrideWithValue(platform),
    androidRoutesKeyProvider.overrideWithValue(android),
    iosRoutesKeyProvider.overrideWithValue(ios),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('enabled only when native map AND routes AND mobile', () {
    expect(_c(platform: MapsNavPlatform.android, routes: true, nativeMap: true).read(googleNavEnabledProvider), isTrue);
    expect(_c(platform: MapsNavPlatform.ios, routes: true, nativeMap: true).read(googleNavEnabledProvider), isTrue);
    expect(_c(platform: MapsNavPlatform.android, routes: false, nativeMap: true).read(googleNavEnabledProvider), isFalse); // no routes key
    expect(_c(platform: MapsNavPlatform.ios, routes: true, nativeMap: false).read(googleNavEnabledProvider), isFalse); // native map missing → the #5 trap
    expect(_c(platform: MapsNavPlatform.unsupported, routes: true, nativeMap: true).read(googleNavEnabledProvider), isFalse); // web/desktop
  });

  test('routesConfigured tracks the ACTIVE platform key, not "either key" (#5)', () {
    expect(_cKeys(platform: MapsNavPlatform.android, ios: 'iosKey').read(routesConfiguredProvider), isFalse); // Android build, only iOS key
    expect(_cKeys(platform: MapsNavPlatform.ios, android: 'androidKey').read(routesConfiguredProvider), isFalse); // iOS build, only Android key
    expect(_cKeys(platform: MapsNavPlatform.android, android: 'androidKey').read(routesConfiguredProvider), isTrue);
    expect(_cKeys(platform: MapsNavPlatform.ios, ios: 'iosKey').read(routesConfiguredProvider), isTrue);
    expect(_cKeys(platform: MapsNavPlatform.unsupported, android: 'a', ios: 'b').read(routesConfiguredProvider), isFalse); // web: no active key
  });

  test('activeRoutesKey selects by platform', () {
    expect(_cKeys(platform: MapsNavPlatform.android, android: 'A', ios: 'B').read(activeRoutesKeyProvider), 'A');
    expect(_cKeys(platform: MapsNavPlatform.ios, android: 'A', ios: 'B').read(activeRoutesKeyProvider), 'B');
    expect(_cKeys(platform: MapsNavPlatform.unsupported, android: 'A', ios: 'B').read(activeRoutesKeyProvider), '');
  });
}
