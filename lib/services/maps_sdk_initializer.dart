import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'maps_js_loader.dart';

import 'maps_consent_providers.dart';
import 'maps_consent_store.dart';

/// Initialises the native Google Maps SDK on demand.
///
/// Deliberately NOT called at app launch. Spec §2b: no Google surface capable of
/// transmitting user or location data may initialise before consent resolves
/// positively. `AppDelegate` used to call `GMSServices.provideAPIKey` inside
/// `didFinishLaunchingWithOptions`, which no render-time consent gate can catch —
/// the `!key.isEmpty` guard only made that harmless while the app shipped
/// keyless.
abstract interface class MapsSdkInitializer {
  /// Idempotent on success. Returns true when the SDK is (now) initialised.
  /// A failure is NOT cached — a later attempt may succeed.
  Future<bool> ensureInitialized();

  /// The Maps SDK's open-source licence text, for Legal/About. Null where the
  /// platform supplies none. Static bundled text, so reading it never contacts
  /// Google and it is safe to call before consent.
  Future<String?> openSourceLicenseInfo();

  /// The effective Maps key for this run: the Dart `MAPS_API_KEY` define if the
  /// build carried one, else the platform's own configured key (iOS Info.plist
  /// `GMSApiKey`, Android manifest `com.google.android.geo.API_KEY`). Empty when
  /// neither supplies one.
  ///
  /// This is a pure configuration *read* — it keys nothing and contacts nobody,
  /// so it is safe to call before consent, and the value never leaves the
  /// process. It exists because the Dart define is COMPILE-time: an app launched
  /// without `--dart-define-from-file=.env` (from Xcode, or a plain
  /// `flutter run`) would otherwise report "not configured" even though the
  /// platform itself is perfectly well keyed.
  Future<String> resolveKey();
}

class PlatformMapsSdkInitializer implements MapsSdkInitializer {
  PlatformMapsSdkInitializer({MethodChannel? channel, this.apiKey = ''})
      : _channel = channel ?? const MethodChannel('aon2026/maps_sdk');

  final MethodChannel _channel;

  /// The native Maps SDK key, supplied from a single source (`--dart-define`
  /// `MAPS_API_KEY`, populated from `.env`). Passed to the native `initialize`
  /// call so iOS can `GMSServices.provideAPIKey` it at consent time without a
  /// separate Xcode build setting. Empty falls back to the platform's own
  /// configured key (Info.plist `GMSApiKey` / Android manifest), so a build
  /// that keys the native side the old way still works.
  final String apiKey;

  bool _initialized = false;

  @override
  Future<bool> ensureInitialized() async {
    if (_initialized) return true;
    // WEB: there is no `aon2026/maps_sdk` MethodChannel in a browser — invoking
    // one throws MissingPluginException and the map would never be allowed to
    // render. Web readiness means "the Maps JavaScript API is loaded", which we
    // do ourselves because the plugin ships no loader and the key must not live
    // in the committed index.html.
    if (kIsWeb) {
      _initialized = await loadGoogleMapsJs(apiKey);
      return _initialized;
    }
    try {
      // A non-empty arg overrides the platform's own key; native treats an
      // absent/empty arg as "use my configured key" (Android must key via the
      // manifest regardless — its SDK reads the key when a MapView is built).
      final ok = await _channel.invokeMethod<bool>(
        'initialize',
        apiKey.isEmpty ? null : {'apiKey': apiKey},
      );
      _initialized = ok ?? false;
      return _initialized;
    } on PlatformException {
      return false; // retryable; never latched
    } on MissingPluginException {
      return false; // unsupported platform / test host
    }
  }

  @override
  Future<String?> openSourceLicenseInfo() async {
    try {
      return await _channel.invokeMethod<String>('openSourceLicenseInfo');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<String> resolveKey() async {
    // A Dart-supplied key wins: it is handed to native at initialise time.
    if (apiKey.isNotEmpty) return apiKey;
    // Web has no native config to fall back on — the define is the only source.
    if (kIsWeb) return '';
    try {
      return await _channel.invokeMethod<String>('getMapsKey') ?? '';
    } on PlatformException {
      return '';
    } on MissingPluginException {
      return ''; // unsupported platform / test host
    }
  }
}

/// A no-op initialiser for tests and unsupported platforms.
///
/// Fails CLOSED: a forgotten production override must surface as "no Google
/// surface", never as a silently-permitted one.
class NoopMapsSdkInitializer implements MapsSdkInitializer {
  const NoopMapsSdkInitializer();

  @override
  Future<bool> ensureInitialized() async => false;

  @override
  Future<String?> openSourceLicenseInfo() async => null;

  @override
  Future<String> resolveKey() async => '';
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Overridden in `main.dart` with [PlatformMapsSdkInitializer]; tests inject a
/// fake. Defaults to the no-op so a forgotten override fails closed (no Google
/// surface) rather than open.
final mapsSdkInitializerProvider =
    Provider<MapsSdkInitializer>((_) => const NoopMapsSdkInitializer());

/// Whether a Google map surface may be constructed.
///
/// This provider is the spec §2b invariant's single enforcement point: it
/// short-circuits on consent before touching the initialiser, so every call site
/// that goes through it is safe by construction.
///
/// It is not a hermetic seal — [mapsSdkInitializerProvider] is still readable,
/// so a call site could bypass this and call `ensureInitialized()` directly.
/// `test/unit/maps_sdk_boundary_test.dart` fails if anything outside this file
/// does.
final mapsSdkReadyProvider = FutureProvider<bool>((ref) async {
  final consent = ref.watch(mapsConsentProvider);
  if (consent != MapsConsent.accepted) return false;
  return ref.read(mapsSdkInitializerProvider).ensureInitialized();
});
