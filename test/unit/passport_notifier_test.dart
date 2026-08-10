import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/models/stamp_io.dart';
import 'package:aon2026/services/passport_providers.dart';
import 'package:aon2026/services/passport_store.dart';
import 'package:aon2026/data/stamp_stations_data.dart';

/// Records write ORDER + concurrency so we can prove writes are serialized.
class _RecordingStore implements PassportStore {
  final List<Set<String>> writes = [];
  int _inFlight = 0;
  int maxConcurrent = 0;

  @override
  Future<Set<String>> loadSnapshot() async => {};

  @override
  Future<bool> save(Set<String> v) async {
    _inFlight++;
    maxConcurrent = maxConcurrent < _inFlight ? _inFlight : maxConcurrent;
    await Future<void>.delayed(Duration.zero);
    writes.add({...v});
    _inFlight--;
    return true;
  }
}

class _FailingStore implements PassportStore {
  @override
  Future<Set<String>> loadSnapshot() async => {};
  @override
  Future<bool> save(Set<String> v) async => false;
}

ProviderContainer _c(
  PassportStore store, {
  Set<String> snapshot = const {},
  bool enabled = true,
}) {
  return ProviderContainer(
    overrides: [
      passportSnapshotProvider.overrideWithValue(snapshot),
      passportStoreProvider.overrideWithValue(store),
      passportCollectionEnabledProvider.overrideWithValue(enabled),
    ],
  );
}

void main() {
  const codeA = 'AON-A-TBC';
  const venueA = 'macquarie-theatre';

  test('collect adds a stamp', () {
    final c = _c(_RecordingStore());
    final out = c
        .read(passportProvider.notifier)
        .collect(const StampInput.manual(codeA));
    expect(out.result, isA<StampCollected>());
    expect(c.read(passportProvider).count, 1);
  });

  test('disabled -> StampDisabled and no mutation', () {
    final c = _c(_RecordingStore(), enabled: false);
    final out = c
        .read(passportProvider.notifier)
        .collect(const StampInput.manual(codeA));
    expect(out.result, isA<StampDisabled>());
    expect(c.read(passportProvider).count, 0);
  });

  test('justCompleted fires only on the 8->9 transition', () {
    const nine = StampStationsData.all;
    final eight = nine.take(8).map((s) => s.venueId).toSet();
    final c = _c(_RecordingStore(), snapshot: eight);
    final out = c
        .read(passportProvider.notifier)
        .collect(StampInput.manual(nine[8].code));
    expect(out.justCompleted, isTrue);
    final again = c
        .read(passportProvider.notifier)
        .collect(StampInput.manual(nine[8].code));
    expect(again.justCompleted, isFalse);
  });

  test('writes are serialized and last-write-wins (no reorder)', () async {
    final store = _RecordingStore();
    final c = _c(store);
    final n = c.read(passportProvider.notifier);
    n.collect(const StampInput.manual('AON-A-TBC'));
    n.collect(const StampInput.manual('AON-B-TBC'));
    await pumpEventQueue();
    expect(store.maxConcurrent, 1); // never two writes at once
    expect(store.writes.last, {'macquarie-theatre', 'mason-theatre'});
  });

  test('a failed save flips saveFailed, keeps the stamp in session', () async {
    final c = _c(_FailingStore());
    c.read(passportProvider.notifier).collect(const StampInput.manual(codeA));
    expect(c.read(passportProvider).collectedVenueIds, contains(venueA));
    await pumpEventQueue();
    expect(c.read(passportProvider).saveFailed, isTrue);
  });

  test('reset clears progress', () {
    final c = _c(_RecordingStore(), snapshot: {venueA});
    c.read(passportProvider.notifier).reset();
    expect(c.read(passportProvider).count, 0);
  });
}
