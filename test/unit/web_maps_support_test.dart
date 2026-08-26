import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/services/maps_nav_providers.dart';
import 'package:aon2026/services/routes_client_identity.dart';

/// Web is a real Google Maps platform, not a second-class one.
///
/// ## The bug this file exists to prevent
///
/// `MapsNavPlatform` had no `web` member, so `kIsWeb` mapped to `unsupported`.
/// That closed `googleNavEnabledProvider`, emptied `activeRoutesKeyProvider`,
/// and made the web build display "Google Maps is not configured yet. Please add
/// the Google Maps API key" — on a build whose key was present and correct. The
/// key was never the problem; the platform model was.
void main() {
  ProviderContainer container({
    required MapsNavPlatform platform,
    String mapsKey = 'shared-key',
    String? webRoutesKey,
    String? iosRoutesKey,
    String? androidRoutesKey,
  }) {
    final c = ProviderContainer(overrides: [
      mapsNavPlatformProvider.overrideWithValue(platform),
      nativeMapsApiKeyProvider.overrideWithValue(mapsKey),
      if (webRoutesKey != null)
        webRoutesKeyProvider.overrideWithValue(webRoutesKey),
      if (iosRoutesKey != null)
        iosRoutesKeyProvider.overrideWithValue(iosRoutesKey),
      if (androidRoutesKey != null)
        androidRoutesKeyProvider.overrideWithValue(androidRoutesKey),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  group('web is a supported platform', () {
    test('the enum has a distinct web member', () {
      expect(MapsNavPlatform.values, contains(MapsNavPlatform.web));
      expect(MapsNavPlatform.web, isNot(MapsNavPlatform.unsupported));
    });

    test('web with a key reaches READY — the exact reported failure', () {
      final c = container(platform: MapsNavPlatform.web);
      expect(c.read(googleNavAvailabilityProvider),
          GoogleNavAvailability.ready);
      expect(c.read(googleNavEnabledProvider), isTrue,
          reason: 'web must be allowed to render the embedded map');
    });

    test('unsupported now means DESKTOP only', () {
      final c = container(platform: MapsNavPlatform.unsupported);
      expect(c.read(googleNavAvailabilityProvider),
          GoogleNavAvailability.platformUnsupported);
    });
  });

  group('web Routes key resolution', () {
    test('web no longer returns an empty Routes key', () {
      final c = container(platform: MapsNavPlatform.web);
      expect(c.read(activeRoutesKeyProvider), 'shared-key',
          reason: 'web used to be hard-coded to "" purely because of platform');
      expect(c.read(routesConfiguredProvider), isTrue);
    });

    test('a dedicated web Routes key wins over the shared key', () {
      // Production: the web key is referrer-restricted and must be its own.
      final c = container(
          platform: MapsNavPlatform.web, webRoutesKey: 'web-only-key');
      expect(c.read(activeRoutesKeyProvider), 'web-only-key');
    });

    test('web does NOT borrow the android or ios Routes key', () {
      final c = container(
        platform: MapsNavPlatform.web,
        mapsKey: '',
        iosRoutesKey: 'ios-key',
        androidRoutesKey: 'android-key',
      );
      expect(c.read(activeRoutesKeyProvider), isEmpty,
          reason: 'a platform-restricted key would be rejected from a browser');
      expect(c.read(googleNavAvailabilityProvider),
          GoogleNavAvailability.missingMapsKey);
    });

    test('desktop still gets no Routes key at all', () {
      final c = container(platform: MapsNavPlatform.unsupported);
      expect(c.read(activeRoutesKeyProvider), isEmpty);
    });
  });

  group('web identity headers', () {
    test('web sends NO app-identity headers', () async {
      // A browser key is restricted by HTTP referrer, which the browser sets
      // itself. Sending X-Ios-Bundle-Identifier / X-Android-Package from a page
      // is meaningless and a referrer-restricted key rejects it.
      final c = container(platform: MapsNavPlatform.web);
      final identity = await c.read(routesClientIdentityProvider.future);
      expect(identity.headers, isEmpty);
    });

    test('iOS still sends its bundle header (native unchanged)', () async {
      final c = container(platform: MapsNavPlatform.ios);
      final identity = await c.read(routesClientIdentityProvider.future);
      expect(identity.headers.keys, contains('X-Ios-Bundle-Identifier'));
    });
  });

  group('mobile behaviour is untouched', () {
    test('ios and android still resolve their own Routes keys', () {
      expect(
        container(platform: MapsNavPlatform.ios, iosRoutesKey: 'i')
            .read(activeRoutesKeyProvider),
        'i',
      );
      expect(
        container(platform: MapsNavPlatform.android, androidRoutesKey: 'a')
            .read(activeRoutesKeyProvider),
        'a',
      );
    });

    test('an android build carrying only the ios key still resolves empty',
        () {
      // The original cross-key trap must stay closed.
      final c = container(
          platform: MapsNavPlatform.android, mapsKey: '', iosRoutesKey: 'ios');
      expect(c.read(activeRoutesKeyProvider), isEmpty);
    });
  });
}
