import 'dart:async';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/data/stamp_stations_data.dart';
import 'package:aon2026/models/stamp_io.dart';
import 'package:aon2026/services/passport_store.dart';
import 'package:aon2026/services/stamp_service.dart';

/// Immutable passport state. `count`/`isComplete` use the intersection with the
/// current station set, so a stale persisted id can never falsely complete.
class PassportState {
  const PassportState({
    required this.collectedVenueIds,
    this.saveFailed = false,
  });

  final Set<String> collectedVenueIds;

  /// True after a persistence write failed this session. Surfaced as a subtle,
  /// non-blocking note — never an error dialog, never a lost stamp.
  final bool saveFailed;

  int get count => PassportPolicy.completedCount(collectedVenueIds);
  bool get isComplete => PassportPolicy.isComplete(collectedVenueIds);

  PassportState copyWith({Set<String>? collectedVenueIds, bool? saveFailed}) =>
      PassportState(
        collectedVenueIds: collectedVenueIds ?? this.collectedVenueIds,
        saveFailed: saveFailed ?? this.saveFailed,
      );
}

/// The result of a capture plus whether it was the completing stamp.
class CollectOutcome {
  const CollectOutcome({required this.result, required this.justCompleted});
  final StampResult result;
  final bool justCompleted;
}

/// Harmless defaults so any Phase 1–5 test that pumps the app WITHOUT overrides
/// still works (empty passport, no-op save). Production `main()` overrides the
/// snapshot + store with real persistence.
final passportSnapshotProvider =
    Provider<Set<String>>((ref) => const <String>{});

final passportStoreProvider =
    Provider<PassportStore>((ref) => const _NoopPassportStore());

/// The DOMAIN release gate. Default: disabled in release while any code is a
/// placeholder; always enabled in debug. Overridable for tests.
final passportCollectionEnabledProvider = Provider<bool>(
  (ref) => PassportPolicy.isCollectionEnabled(
    StampStationsData.all,
    isRelease: kReleaseMode,
  ),
);

final passportProvider =
    NotifierProvider<PassportNotifier, PassportState>(PassportNotifier.new);

class PassportNotifier extends Notifier<PassportState> {
  Future<void> _writes = Future<void>.value();

  @override
  PassportState build() => PassportState(
        collectedVenueIds: {...ref.read(passportSnapshotProvider)},
      );

  CollectOutcome collect(StampInput input) {
    if (!ref.read(passportCollectionEnabledProvider)) {
      return const CollectOutcome(
        result: StampDisabled(),
        justCompleted: false,
      );
    }
    final wasComplete = state.isComplete;
    final result = StampService.resolve(input, state.collectedVenueIds);
    if (result is StampCollected) {
      state = state.copyWith(
        collectedVenueIds: {...state.collectedVenueIds, result.venueId},
      );
      _scheduleSave();
    }
    return CollectOutcome(
      result: result,
      justCompleted: !wasComplete && state.isComplete,
    );
  }

  void reset() {
    state = state.copyWith(collectedVenueIds: <String>{});
    _scheduleSave();
  }

  /// Serializes writes so two saves can never complete out of order; each write
  /// persists the CURRENT set, so the last write always reflects final state.
  /// Awaitable completion of the serialized write chain, so a caller that must
  /// order storage work after a session reset (Settings' "Delete my data") can
  /// wait rather than race it.
  Future<void> flush() => _writes;

  void _scheduleSave() {
    _writes = _writes.then((_) async {
      final ok = await ref.read(passportStoreProvider).save(
            state.collectedVenueIds,
          );
      if (!ok) state = state.copyWith(saveFailed: true);
    });
    unawaited(_writes);
  }
}

class _NoopPassportStore implements PassportStore {
  const _NoopPassportStore();
  @override
  Future<Set<String>> loadSnapshot() async => <String>{};
  @override
  Future<bool> save(Set<String> venueIds) async => true;
}
