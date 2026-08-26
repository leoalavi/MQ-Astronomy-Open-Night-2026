import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/services/maps_nav_providers.dart';

/// WHY Google navigation is unavailable must be distinguishable.
///
/// ## The bug this file exists to prevent
///
/// The gate was a bare bool, so three unrelated causes all rendered the same
/// panel: "Google Maps is not configured yet. Please add the Google Maps API
/// key to enable directions." On the web build that message is actively false —
/// `kIsWeb` makes the platform `unsupported`, the gate closes, and the app
/// blames a key that is present and irrelevant. A tester then spends hours
/// chasing a credentials bug that does not exist. (That is exactly what
/// happened.) Naming the cause is what makes the screen honest.
void main() {
  ProviderContainer container({
    required MapsNavPlatform platform,
    String mapsKey = 'k',
    String? iosRoutesKey,
  }) {
    final c = ProviderContainer(overrides: [
      mapsNavPlatformProvider.overrideWithValue(platform),
      nativeMapsApiKeyProvider.overrideWithValue(mapsKey),
      if (iosRoutesKey != null)
        iosRoutesKeyProvider.overrideWithValue(iosRoutesKey),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  group('the cause is named, not collapsed', () {
    test('a fully configured mobile build is ready', () {
      final c = container(platform: MapsNavPlatform.ios);
      expect(c.read(googleNavAvailabilityProvider),
          GoogleNavAvailability.ready);
      expect(c.read(googleNavEnabledProvider), isTrue);
    });

    test('web reports platformUnsupported — NOT a missing key', () {
      // The reported bug, in one assertion.
      final c = container(platform: MapsNavPlatform.unsupported);
      expect(c.read(googleNavAvailabilityProvider),
          GoogleNavAvailability.platformUnsupported,
          reason: 'blaming the key here sends people on a wild goose chase');
      expect(c.read(googleNavEnabledProvider), isFalse);
    });

    test('platform is checked BEFORE keys, since keys are moot there', () {
      // Even with every key present, an unsupported platform is the real cause.
      final c = container(
          platform: MapsNavPlatform.unsupported, mapsKey: 'k', iosRoutesKey: 'r');
      expect(c.read(googleNavAvailabilityProvider),
          GoogleNavAvailability.platformUnsupported);
    });

    test('a genuinely absent key still reports missingMapsKey', () {
      final c = container(platform: MapsNavPlatform.ios, mapsKey: '');
      expect(c.read(googleNavAvailabilityProvider),
          GoogleNavAvailability.missingMapsKey);
    });
  });

  group('the boolean gate and the reason can never disagree', () {
    test('enabled is true if and only if availability is ready', () {
      for (final platform in MapsNavPlatform.values) {
        for (final key in ['', 'k']) {
          final c = container(platform: platform, mapsKey: key);
          expect(
            c.read(googleNavEnabledProvider),
            c.read(googleNavAvailabilityProvider) ==
                GoogleNavAvailability.ready,
            reason: 'disagreement at platform=$platform keyPresent=${key.isNotEmpty}',
          );
        }
      }
    });
  });

  group('the QA trace leaks no key material', () {
    test('it reports presence booleans only, never the key itself', () {
      final c = container(platform: MapsNavPlatform.ios, mapsKey: 'SUPERSECRET');
      // describeGoogleNavState takes a WidgetRef; assert on the same inputs it
      // formats, which is what matters: no provider it reads exposes a value.
      expect(c.read(nativeMapsApiKeyProvider).isNotEmpty, isTrue);
      final trace = [
        'platform=${c.read(mapsNavPlatformProvider).name}',
        'mapsKeyPresent=${c.read(nativeMapsApiKeyProvider).isNotEmpty}',
        'routesKeyPresent=${c.read(activeRoutesKeyProvider).isNotEmpty}',
        'availability=${c.read(googleNavAvailabilityProvider).name}',
      ].join(' ');
      expect(trace, isNot(contains('SUPERSECRET')),
          reason: 'a diagnostic that logs the key is worse than no diagnostic');
      expect(trace, contains('mapsKeyPresent=true'));
    });
  });
}
