import 'package:shared_preferences/shared_preferences.dart';

/// The app's first persisted mutable state.
///
/// Every method is best-effort and MUST NOT throw to its caller — a persistence
/// problem can never break the passport session or block launch (design §3.1).
/// The real adapter's round-trip is unit-tested in `passport_store_test.dart`
/// via the in-memory async platform.
abstract interface class PassportStore {
  /// Collected venue ids, or `{}` on first run or any failure.
  Future<Set<String>> loadSnapshot();

  /// Persists the set; returns `false` on failure instead of throwing.
  Future<bool> save(Set<String> venueIds);
}

/// Backed by the current recommended [SharedPreferencesAsync] API.
class SharedPrefsPassportStore implements PassportStore {
  SharedPrefsPassportStore(this._prefs);

  final SharedPreferencesAsync _prefs;
  /// Public so `LocalDataEraser` can never drift from the real key.
  static const String storageKey = 'passport.collectedVenueIds';

  @override
  Future<Set<String>> loadSnapshot() async {
    try {
      final list = await _prefs.getStringList(storageKey);
      return list?.toSet() ?? <String>{};
    } catch (_) {
      return <String>{};
    }
  }

  @override
  Future<bool> save(Set<String> venueIds) async {
    try {
      await _prefs.setStringList(storageKey, venueIds.toList());
      return true;
    } catch (_) {
      return false;
    }
  }
}
