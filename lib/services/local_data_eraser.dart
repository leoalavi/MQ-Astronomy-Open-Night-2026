import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aon2026/services/favorites_store.dart';
import 'package:aon2026/services/saved_events.dart';
import 'package:aon2026/services/maps_consent_store.dart';
import 'package:aon2026/services/passport_store.dart';

/// Erases everything this app stores on this device.
///
/// Scope is deliberately narrow and stated: local storage only. It does NOT and
/// must not claim to erase anything already transmitted to a third party
/// (spec §2c) — the Settings copy says so in both languages.
abstract interface class LocalDataEraser {
  /// Never throws. Returns false when the platform store refused, so the caller
  /// can report failure instead of claiming a deletion that did not happen.
  Future<bool> eraseAll();
}

class SharedPrefsLocalDataEraser implements LocalDataEraser {
  SharedPrefsLocalDataEraser({required this.prefs, required this.eventId});

  final SharedPreferencesAsync prefs;

  /// Needed because the favourites venue key is per-event. A constant list
  /// cannot express it, which is precisely how the first draft of this class
  /// erased nothing.
  final String eventId;

  /// Sourced from each store's own constant so the two can never drift.
  ///
  /// `settings.*` is excluded on purpose: theme, motion and locale are
  /// preferences, not user data, and clearing someone's language on a
  /// "delete my data" tap would be a surprise. Do not "fix" this.
  List<String> get ownedKeys => <String>[
        SharedPrefsPassportStore.storageKey,
        SharedPrefsFavoritesStore.buildingsKey,
        SharedPrefsFavoritesStore.venuesKeyFor(eventId),
        SharedPrefsMapsConsentStore.storageKey,
        // The saved "My Night" plan is the visitor's data too — "delete my
        // data" must not leave it behind.
        SavedEventsStorage.keyFor(eventId),
      ];

  /// The control says "delete my data", not "delete this event's data", so
  /// favourites left by any previous event id go too.
  static const String _venuesKeyPrefix = 'map_favorites.venues.';

  @override
  Future<bool> eraseAll() async {
    try {
      for (final key in ownedKeys) {
        await prefs.remove(key);
      }
      for (final key in await prefs.getKeys()) {
        if (key.startsWith(_venuesKeyPrefix)) await prefs.remove(key);
      }
      return true;
    } catch (_) {
      return false; // persistence failure is never fatal (passport idiom)
    }
  }
}

/// The default. Fails CLOSED: a forgotten production override must surface as a
/// visible failure, not as a cheerful "Deleted." over data that is still there.
class NoopLocalDataEraser implements LocalDataEraser {
  const NoopLocalDataEraser();

  @override
  Future<bool> eraseAll() async => false;
}

/// Overridden in `main.dart` with the SharedPreferences-backed eraser.
final localDataEraserProvider =
    Provider<LocalDataEraser>((_) => const NoopLocalDataEraser());
