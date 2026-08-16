import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:aon2026/services/favorites_store.dart';
import 'package:aon2026/services/favorites_providers.dart';

/// In-memory FavoritesStore for controller tests.
class _FakeStore implements FavoritesStore {
  _FakeStore([Set<String>? initial]) : saved = {...?initial};
  Set<String> saved;
  bool failNextSave = false;
  @override
  Future<Set<String>> loadSnapshot() async => {...saved};
  @override
  Future<bool> save(Set<String> keys) async {
    if (failNextSave) {
      failNextSave = false;
      return false;
    }
    saved = {...keys};
    return true;
  }
}

ProviderContainer _c(_FakeStore store, {Set<String> snapshot = const {}}) {
  final c = ProviderContainer(overrides: [
    favoritesStoreProvider.overrideWithValue(store),
    favoritesSnapshotProvider.overrideWithValue(snapshot),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('default empty; toggle add/remove', () {
    final c = _c(_FakeStore());
    final n = c.read(favoritesProvider.notifier);
    expect(c.read(favoritesProvider).keys, isEmpty);
    n.toggle('building:LIB');
    expect(c.read(favoritesProvider).keys, {'building:LIB'});
    n.toggle('building:LIB');
    expect(c.read(favoritesProvider).keys, isEmpty);
  });

  test('seeds from injected snapshot', () {
    final c = _c(_FakeStore(), snapshot: {'building:LIB'});
    expect(c.read(favoritesProvider).keys, {'building:LIB'});
  });

  test('G8/G9: rapid add A, add B, remove A → persisted {venue:b} via flush()', () async {
    final store = _FakeStore();
    final c = _c(store);
    final n = c.read(favoritesProvider.notifier);
    n.toggle('venue:a');
    n.toggle('venue:b');
    n.toggle('venue:a');
    await n.flush(); // deterministic — no sleep
    expect(store.saved, {'venue:b'});
  });

  test('G25: save failure sets saveFailed, next success resets it', () async {
    final store = _FakeStore()..failNextSave = true;
    final c = _c(store);
    final n = c.read(favoritesProvider.notifier);
    n.toggle('building:X');
    await n.flush();
    expect(c.read(favoritesProvider).saveFailed, isTrue);
    n.toggle('building:Y');
    await n.flush();
    expect(c.read(favoritesProvider).saveFailed, isFalse);
  });

  group('SharedPrefsFavoritesStore namespacing (G7)', () {
    setUp(() {
      SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    });

    test('building keys → global key; venue keys → event-scoped key; round-trips', () async {
      final store = SharedPrefsFavoritesStore(
          prefs: SharedPreferencesAsync(), eventId: 'aon-2026');
      await store.save({'building:LIB', 'venue:obs'});
      // a fresh store for the SAME event sees both
      final same = SharedPrefsFavoritesStore(
          prefs: SharedPreferencesAsync(), eventId: 'aon-2026');
      expect(await same.loadSnapshot(), {'building:LIB', 'venue:obs'});
      // a DIFFERENT event keeps the global building but not the venue
      final other = SharedPrefsFavoritesStore(
          prefs: SharedPreferencesAsync(), eventId: 'aon-2027');
      expect(await other.loadSnapshot(), {'building:LIB'});
    });
  });
}
