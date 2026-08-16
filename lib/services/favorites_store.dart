import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's favorited `PlaceKey`s. Buildings are permanent campus
/// places → a GLOBAL key; AON venues are event records → an EVENT-scoped key
/// (so a venue favorite doesn't leak to a future event). §0b.D / G7.
abstract interface class FavoritesStore {
  Future<Set<String>> loadSnapshot();
  Future<bool> save(Set<String> keys);
}

class SharedPrefsFavoritesStore implements FavoritesStore {
  SharedPrefsFavoritesStore({required this.prefs, required this.eventId});

  final SharedPreferencesAsync prefs;
  final String eventId;

  static const _buildingsKey = 'map_favorites.buildings.v1';
  String get _venuesKey => 'map_favorites.venues.$eventId';

  @override
  Future<Set<String>> loadSnapshot() async {
    try {
      final b = await prefs.getStringList(_buildingsKey) ?? const <String>[];
      final v = await prefs.getStringList(_venuesKey) ?? const <String>[];
      return {...b, ...v};
    } catch (_) {
      return <String>{}; // load failure → empty (G25: not a saveFailed)
    }
  }

  @override
  Future<bool> save(Set<String> keys) async {
    try {
      final buildings = keys.where((k) => k.startsWith('building:')).toList();
      final venues = keys.where((k) => k.startsWith('venue:')).toList();
      await prefs.setStringList(_buildingsKey, buildings);
      await prefs.setStringList(_venuesKey, venues);
      return true;
    } catch (_) {
      return false; // G25: save failure → caller flips saveFailed
    }
  }
}

/// Default store: does nothing, holds nothing. Keeps tests + first run working
/// before `main` injects the real store (passport idiom).
class NoopFavoritesStore implements FavoritesStore {
  const NoopFavoritesStore();
  @override
  Future<Set<String>> loadSnapshot() async => const <String>{};
  @override
  Future<bool> save(Set<String> keys) async => true;
}
