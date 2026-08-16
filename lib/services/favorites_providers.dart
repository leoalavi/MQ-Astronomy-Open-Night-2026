import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/services/favorites_store.dart';

class FavoritesState {
  const FavoritesState({this.keys = const {}, this.saveFailed = false});
  final Set<String> keys;
  final bool saveFailed;
  FavoritesState copyWith({Set<String>? keys, bool? saveFailed}) => FavoritesState(
        keys: keys ?? this.keys,
        saveFailed: saveFailed ?? this.saveFailed,
      );
}

/// Overridable in `main` (passport idiom): a fully-loaded snapshot + the real
/// store are injected at startup; tests and first run use the empty/noop defaults.
final favoritesSnapshotProvider = Provider<Set<String>>((_) => const {});
final favoritesStoreProvider = Provider<FavoritesStore>((_) => const NoopFavoritesStore());

/// Local favorites. Seeds synchronously from the injected snapshot; writes are
/// serialized through a single Future chain (latest state wins), a failed save
/// flips [FavoritesState.saveFailed] rather than throwing.
class FavoritesController extends Notifier<FavoritesState> {
  Future<void> _chain = Future<void>.value();
  bool _disposed = false;

  @override
  FavoritesState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true); // a pending save must not touch a disposed notifier
    return FavoritesState(keys: {...ref.read(favoritesSnapshotProvider)});
  }

  void toggle(String placeKey) {
    final next = {...state.keys};
    next.contains(placeKey) ? next.remove(placeKey) : next.add(placeKey);
    state = state.copyWith(keys: next);
    _scheduleSave();
  }

  void _scheduleSave() {
    final store = ref.read(favoritesStoreProvider);
    _chain = _chain.then((_) async {
      final ok = await store.save(state.keys); // persist the LATEST state
      if (_disposed) return; // notifier gone — do not mutate
      if (!ok) {
        state = state.copyWith(saveFailed: true);
      } else if (state.saveFailed) {
        state = state.copyWith(saveFailed: false);
      }
    });
  }

  /// G9: awaitable completion of the serialized save chain (deterministic tests).
  Future<void> flush() => _chain;
}

final favoritesProvider =
    NotifierProvider<FavoritesController, FavoritesState>(FavoritesController.new);
