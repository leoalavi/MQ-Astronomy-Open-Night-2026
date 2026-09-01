import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'package:aon2026/config/event_config.dart';
import 'package:aon2026/services/saved_events.dart';

/// An in-memory store whose WRITES fail — reads still work, so the notifier can
/// build, but every persist throws. §17: the write path must swallow it.
class _WriteFailsStore extends InMemorySharedPreferencesStore {
  _WriteFailsStore() : super.empty();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      throw Exception('store offline');
}

/// §16 persistence-race audit for saved events.
///
/// `SavedEventsNotifier.toggle` updates state synchronously then persists
/// asynchronously, WITHOUT the serialized Future-chain the snapshot idiom uses.
/// These tests pin the behaviour that matters: after a rapid burst of toggles,
/// the value that survives to disk must be the LAST action the visitor took —
/// never a stale earlier write that resurrects an item they just removed (or
/// drops one they just saved).
void main() {
  final key = SavedEventsStorage.keyFor(EventConfig.astronomyOpenNight.id);

  Future<(ProviderContainer, SavedEventsNotifier)> loaded() async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(savedEventsProvider.future);
    return (c, c.read(savedEventsProvider.notifier));
  }

  Future<List<String>> onDisk() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(key) ?? const <String>[];
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('rapid save→unsave persists the final unsave, never a stale save',
      () async {
    final (c, n) = await loaded();
    final f1 = n.toggle('kids-space'); // save
    final f2 = n.toggle('kids-space'); // unsave
    await Future.wait([f1, f2]);

    expect(c.read(savedEventsProvider).value, isEmpty);
    expect(await onDisk(), isEmpty,
        reason: 'the last action was unsave — it must not resurrect on disk');
  });

  test('rapid unsave→save persists the final save', () async {
    SharedPreferences.setMockInitialValues({
      key: ['kids-space'],
    });
    final (c, n) = await loaded();
    final f1 = n.toggle('kids-space'); // unsave
    final f2 = n.toggle('kids-space'); // save
    await Future.wait([f1, f2]);

    expect(c.read(savedEventsProvider).value, {'kids-space'});
    expect(await onDisk(), ['kids-space']);
  });

  test('a burst of toggles across several events lands the correct final set',
      () async {
    final (c, n) = await loaded();
    final futures = [
      n.toggle('a'), // +a
      n.toggle('b'), // +b
      n.toggle('a'), // -a
      n.toggle('c'), // +c
      n.toggle('b'), // -b
    ];
    await Future.wait(futures);

    // Net result: c only.
    expect(c.read(savedEventsProvider).value, {'c'});
    expect((await onDisk()).toSet(), {'c'});
  });

  test('no duplicate ids can accumulate on repeated saves', () async {
    final (c, n) = await loaded();
    await n.toggle('a'); // save
    await n.toggle('a'); // unsave
    await n.toggle('a'); // save
    expect(c.read(savedEventsProvider).value, {'a'});
    expect(await onDisk(), ['a']); // exactly one, not duplicated
  });

  test('a failing store never throws out of toggle; state stays correct',
      () async {
    // §17: setMockInitialValues resets the singleton cache; then swap in a store
    // whose writes throw. build() reads {} fine; the write inside _persist fails.
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesStorePlatform.instance = _WriteFailsStore();
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(savedEventsProvider.future);
    final n = c.read(savedEventsProvider.notifier);

    // The failed write must NOT surface as an unhandled error out of toggle.
    await expectLater(n.toggle('kids-space'), completes);
    // The optimistic in-memory state is still correct despite the failed write.
    expect(c.read(savedEventsProvider).value, {'kids-space'});
    // remove and clear are equally guarded.
    await expectLater(n.remove('kids-space'), completes);
    await expectLater(n.clear(), completes);
  });
}
