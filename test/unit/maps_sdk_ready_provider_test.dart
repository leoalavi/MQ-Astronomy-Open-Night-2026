import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/services/maps_consent_providers.dart';
import 'package:aon2026/services/maps_consent_store.dart';
import 'package:aon2026/services/maps_sdk_initializer.dart';

class _CountingInitializer implements MapsSdkInitializer {
  int calls = 0;

  @override
  Future<bool> ensureInitialized() async {
    calls++;
    return true;
  }

  @override
  Future<String?> openSourceLicenseInfo() async => null;

  @override
  Future<String> resolveKey() async => '';
}

ProviderContainer _container(_CountingInitializer init, MapsConsent seed) {
  final c = ProviderContainer(overrides: [
    mapsSdkInitializerProvider.overrideWithValue(init),
    mapsConsentSnapshotProvider.overrideWithValue(seed),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('unknown consent never touches the initializer', () async {
    final init = _CountingInitializer();
    final c = _container(init, MapsConsent.unknown);

    expect(await c.read(mapsSdkReadyProvider.future), isFalse);
    expect(init.calls, 0, reason: 'spec §2b: no init before consent resolves');
  });

  test('declined consent never touches the initializer', () async {
    final init = _CountingInitializer();
    final c = _container(init, MapsConsent.declined);

    expect(await c.read(mapsSdkReadyProvider.future), isFalse);
    expect(init.calls, 0);
  });

  test('accepted consent initializes exactly once', () async {
    final init = _CountingInitializer();
    final c = _container(init, MapsConsent.accepted);

    expect(await c.read(mapsSdkReadyProvider.future), isTrue);
    expect(init.calls, 1);
  });

  test('accepting after decline initializes; revoking then reports not ready',
      () async {
    final init = _CountingInitializer();
    final c = _container(init, MapsConsent.unknown);

    expect(await c.read(mapsSdkReadyProvider.future), isFalse);
    expect(init.calls, 0);

    c.read(mapsConsentProvider.notifier).accept();
    expect(await c.read(mapsSdkReadyProvider.future), isTrue);
    expect(init.calls, 1);

    c.read(mapsConsentProvider.notifier).revoke();
    expect(await c.read(mapsSdkReadyProvider.future), isFalse,
        reason: 'revocation must report not-ready even though GMSServices '
            'cannot be un-initialised');
    expect(init.calls, 1, reason: 'revocation must not re-initialise');
  });

  test('the default initializer fails closed', () async {
    // A forgotten production override must mean "no Google surface", never a
    // silently-permitted one.
    expect(await const NoopMapsSdkInitializer().ensureInitialized(), isFalse);
  });
}
