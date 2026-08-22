import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
}

class PlatformMapsSdkInitializer implements MapsSdkInitializer {
  PlatformMapsSdkInitializer({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('aon2026/maps_sdk');

  final MethodChannel _channel;
  bool _initialized = false;

  @override
  Future<bool> ensureInitialized() async {
    if (_initialized) return true;
    try {
      final ok = await _channel.invokeMethod<bool>('initialize');
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
