import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aon2026/config/event_config.dart';

/// Persistence for the visitor's saved activities ("My Night").
///
/// ## Local-first, no account
///
/// The brief is firm that a visitor downloading this app in the car park must
/// not hit a sign-up wall. So saving is **device-local** via
/// `shared_preferences` — no auth, no sync, no backend. The cost is that a
/// saved night does not follow the user to another phone, which is the right
/// trade for a single six-hour event.
///
/// If Raouf's Supabase layer later offers an anonymous per-device profile, this
/// class is the seam: keep [SavedEventsNotifier]'s public surface and swap the
/// storage calls. Nothing in the UI reads `SharedPreferences` directly.
///
/// ## Why the storage key is event-scoped
///
/// The key includes [EventConfig.id], so a future event on the same install
/// starts with an empty plan rather than inheriting last year's saved sessions.
abstract final class SavedEventsStorage {
  static String keyFor(String eventId) => 'saved_events.$eventId';
}

/// The set of saved event ids.
///
/// An `AsyncNotifier` rather than a plain one because the first read hits disk.
/// Every screen that shows saved state already handles `AsyncValue`, so the
/// one-frame load is a skeleton, not a spinner.
class SavedEventsNotifier extends AsyncNotifier<Set<String>> {
  late final String _key;

  @override
  Future<Set<String>> build() async {
    _key = SavedEventsStorage.keyFor(ref.watch(eventConfigProvider).id);
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? const <String>[]).toSet();
  }

  /// Adds or removes [eventId], returning the new saved state.
  ///
  /// Optimistic: state updates immediately so the tap feels instant, then the
  /// write happens. A failed write is not surfaced — losing one saved item is
  /// not worth an error dialog mid-event, and the next toggle will retry.
  Future<bool> toggle(String eventId) async {
    final current = state.value ?? <String>{};
    final next = Set<String>.from(current);
    final nowSaved = !next.contains(eventId);
    nowSaved ? next.add(eventId) : next.remove(eventId);

    state = AsyncData(next);
    await _persist(next);
    return nowSaved;
  }

  Future<void> remove(String eventId) async {
    final next = Set<String>.from(state.value ?? <String>{})..remove(eventId);
    state = AsyncData(next);
    await _persist(next);
  }

  Future<void> clear() async {
    state = const AsyncData(<String>{});
    await _persist(const <String>{});
  }

  Future<void> _persist(Set<String> value) async {
    // Never throws (repo persistence convention). The optimistic in-memory state
    // is already set before this runs, so a failed write must not surface as an
    // unhandled Future error out of toggle/remove/clear — losing one write
    // mid-event is not worth an error into the UI, and the next toggle retries.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, value.toList());
    } catch (_) {
      /* persistence failure is never fatal */
    }
  }
}

final savedEventsProvider =
    AsyncNotifierProvider<SavedEventsNotifier, Set<String>>(
  SavedEventsNotifier.new,
);

/// Whether a single event is saved.
///
/// Defaults to `false` while loading rather than showing an indeterminate
/// state — a save button that flickers between three appearances on every
/// list scroll is worse than one that settles a frame late.
final isSavedProvider = Provider.family<bool, String>((ref, eventId) {
  return ref.watch(savedEventsProvider).value?.contains(eventId) ?? false;
});

/// How many activities are saved. Drives the Home preview and the tab badge.
final savedCountProvider = Provider<int>(
  (ref) => ref.watch(savedEventsProvider).value?.length ?? 0,
);
