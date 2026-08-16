import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'maps_consent_store.dart';

/// Overridable in `main` (passport idiom): a loaded snapshot + the real store
/// are injected at startup; tests and first run use unknown/noop defaults.
final mapsConsentSnapshotProvider = Provider<MapsConsent>((_) => MapsConsent.unknown);
final mapsConsentStoreProvider = Provider<MapsConsentStore>((_) => const NoopMapsConsentStore());

/// The Google-nav consent state. Seeds synchronously from the injected
/// snapshot; writes serialize through a single Future chain and never throw
/// (a failed persist just means the next launch re-asks, which is safe).
class MapsConsentController extends Notifier<MapsConsent> {
  Future<void> _chain = Future<void>.value();
  bool _disposed = false;

  @override
  MapsConsent build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true); // a pending save must not touch a disposed notifier
    return ref.read(mapsConsentSnapshotProvider);
  }

  void accept() => _set(MapsConsent.accepted);
  void decline() => _set(MapsConsent.declined);

  /// Settings "revoke": back to unknown so the next nav re-asks.
  void revoke() => _set(MapsConsent.unknown);

  void _set(MapsConsent next) {
    if (state == next) return;
    state = next;
    _scheduleSave();
  }

  void _scheduleSave() {
    final store = ref.read(mapsConsentStoreProvider);
    _chain = _chain.then((_) async {
      await store.save(state); // persist the LATEST state
      if (_disposed) return; // notifier gone — do not mutate
    });
  }

  /// Awaitable completion of the serialized save chain (deterministic tests).
  Future<void> flush() => _chain;
}

final mapsConsentProvider =
    NotifierProvider<MapsConsentController, MapsConsent>(MapsConsentController.new);
