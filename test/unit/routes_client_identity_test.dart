import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/services/maps_nav_providers.dart';
import 'package:aon2026/services/routes_client_identity.dart';

void main() {
  test('iOS → single bundle-id header', () async {
    final c = ProviderContainer(overrides: [
      mapsNavPlatformProvider.overrideWithValue(MapsNavPlatform.ios),
    ]);
    addTearDown(c.dispose);
    final id = await c.read(routesClientIdentityProvider.future);
    expect(id.headers, {'X-Ios-Bundle-Identifier': 'au.edu.mq.astronomy.aon2026'});
  });

  test('Android → BOTH package + cert headers (cert from native seam)', () async {
    final c = ProviderContainer(overrides: [
      mapsNavPlatformProvider.overrideWithValue(MapsNavPlatform.android),
      androidCertSha1Provider.overrideWith((ref) async => 'AB:CD:EF'),
    ]);
    addTearDown(c.dispose);
    final id = await c.read(routesClientIdentityProvider.future);
    // The header must be the SHA-1 WITHOUT colons: Google returns 403
    // "Requests from this Android client application ... are blocked" for the
    // colon-separated display form (verified live 2026-09-07, B3).
    expect(id.headers, {
      'X-Android-Package': 'au.edu.mq.astronomy.aon2026',
      'X-Android-Cert': 'ABCDEF',
    });
  });

  test('X-Android-Cert is normalised: no colons, uppercase, trimmed', () {
    expect(normaliseAndroidCert('a4:26:bd:18 '), 'A426BD18');
    expect(normaliseAndroidCert('A426BD18'), 'A426BD18');
    expect(normaliseAndroidCert(''), '');
  });

  test('unsupported (web/desktop) → no identity headers', () async {
    final c = ProviderContainer(overrides: [
      mapsNavPlatformProvider.overrideWithValue(MapsNavPlatform.unsupported),
    ]);
    addTearDown(c.dispose);
    final id = await c.read(routesClientIdentityProvider.future);
    expect(id.headers, isEmpty);
  });
}
