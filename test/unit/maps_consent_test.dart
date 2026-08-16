import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/services/maps_consent_store.dart';
import 'package:aon2026/services/maps_consent_providers.dart';

/// In-memory store to observe persistence deterministically.
class _MemStore implements MapsConsentStore {
  MapsConsent saved = MapsConsent.unknown;
  int saves = 0;
  // The controller seeds from mapsConsentSnapshotProvider (injected below), not
  // from the store — so loadSnapshot is unused here and returns a fixed default.
  @override
  Future<MapsConsent> loadSnapshot() async => MapsConsent.unknown;
  @override
  Future<bool> save(MapsConsent consent) async {
    saved = consent;
    saves++;
    return true;
  }
}

ProviderContainer _c(_MemStore store, {MapsConsent snapshot = MapsConsent.unknown}) {
  final c = ProviderContainer(overrides: [
    mapsConsentSnapshotProvider.overrideWithValue(snapshot),
    mapsConsentStoreProvider.overrideWithValue(store),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('default is unknown', () {
    expect(_c(_MemStore()).read(mapsConsentProvider), MapsConsent.unknown);
  });

  test('seeds from injected snapshot', () {
    expect(_c(_MemStore(), snapshot: MapsConsent.accepted).read(mapsConsentProvider), MapsConsent.accepted);
  });

  test('accept → accepted + persists', () async {
    final s = _MemStore();
    final c = _c(s);
    c.read(mapsConsentProvider.notifier).accept();
    expect(c.read(mapsConsentProvider), MapsConsent.accepted);
    await c.read(mapsConsentProvider.notifier).flush();
    expect(s.saved, MapsConsent.accepted);
  });

  test('decline → declined + persists', () async {
    final s = _MemStore();
    final c = _c(s);
    c.read(mapsConsentProvider.notifier).decline();
    expect(c.read(mapsConsentProvider), MapsConsent.declined);
    await c.read(mapsConsentProvider.notifier).flush();
    expect(s.saved, MapsConsent.declined);
  });

  test('revoke → unknown + persists (next nav re-asks)', () async {
    final s = _MemStore();
    final c = _c(s, snapshot: MapsConsent.accepted);
    c.read(mapsConsentProvider.notifier).revoke();
    expect(c.read(mapsConsentProvider), MapsConsent.unknown);
    await c.read(mapsConsentProvider.notifier).flush();
    expect(s.saved, MapsConsent.unknown);
  });

  test('consentNeedsDisclosure: unknown & declined → true; accepted → false', () {
    expect(consentNeedsDisclosure(MapsConsent.unknown), isTrue);
    expect(consentNeedsDisclosure(MapsConsent.declined), isTrue); // declined re-asks on explicit tap
    expect(consentNeedsDisclosure(MapsConsent.accepted), isFalse);
  });
}
