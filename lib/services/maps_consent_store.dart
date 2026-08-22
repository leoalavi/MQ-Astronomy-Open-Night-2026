import 'package:shared_preferences/shared_preferences.dart';

/// Whether the user has agreed to share their location with Google Maps for
/// walking directions. `unknown` = never asked; `declined` = asked and said no
/// (NOT a permanent brick — an explicit tap can re-ask); `accepted` = agreed.
enum MapsConsent { unknown, accepted, declined }

/// The gate T7 uses on an explicit Google-nav tap: only `accepted` proceeds
/// straight through; both `unknown` and `declined` show the disclosure first
/// (a declined user who taps again is asking to reconsider).
bool consentNeedsDisclosure(MapsConsent c) => c != MapsConsent.accepted;

/// Persists [MapsConsent]. Passport idiom: `main` loads a snapshot at startup
/// and injects the real store; tests/first-run use the noop default.
abstract interface class MapsConsentStore {
  Future<MapsConsent> loadSnapshot();
  Future<bool> save(MapsConsent consent);
}

class SharedPrefsMapsConsentStore implements MapsConsentStore {
  SharedPrefsMapsConsentStore({required this.prefs});

  final SharedPreferencesAsync prefs;
  static const String storageKey = 'map_google_consent.v1';

  @override
  Future<MapsConsent> loadSnapshot() async {
    try {
      return switch (await prefs.getString(storageKey)) {
        'accepted' => MapsConsent.accepted,
        'declined' => MapsConsent.declined,
        _ => MapsConsent.unknown,
      };
    } catch (_) {
      return MapsConsent.unknown; // load failure → re-ask (fail toward consent)
    }
  }

  @override
  Future<bool> save(MapsConsent consent) async {
    try {
      await prefs.setString(storageKey, consent.name);
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Default store: holds nothing, always unknown. Keeps tests + first run working
/// before `main` injects the real store.
class NoopMapsConsentStore implements MapsConsentStore {
  const NoopMapsConsentStore();
  @override
  Future<MapsConsent> loadSnapshot() async => MapsConsent.unknown;
  @override
  Future<bool> save(MapsConsent consent) async => true;
}
