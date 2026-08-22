import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'google_routes_service.dart';
import 'location_providers.dart';
import 'location_service.dart';
import 'maps_consent_providers.dart';
import 'maps_consent_store.dart';
import 'routes_client_identity.dart';
import 'routes_service.dart';

/// Which native surface the app is running on, for Google-nav capability.
/// `unsupported` covers web and desktop — the embedded Google map + direct
/// Routes calls are mobile-only in M4.
enum MapsNavPlatform { unsupported, android, ios }

/// The running platform. Web-safe: `kIsWeb` short-circuits before
/// `defaultTargetPlatform` (which on web reports the *browser's* OS and would
/// otherwise mislabel a mobile browser as android/ios). Overridable in tests.
final mapsNavPlatformProvider = Provider<MapsNavPlatform>((ref) {
  if (kIsWeb) return MapsNavPlatform.unsupported;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => MapsNavPlatform.android,
    TargetPlatform.iOS => MapsNavPlatform.ios,
    _ => MapsNavPlatform.unsupported,
  };
});

/// The Android / iOS Routes web-service keys, injected at build time via
/// `--dart-define`. Empty when not supplied. These are DIFFERENT keys from the
/// native Maps SDK keys (which live in the platform secret files, T0).
final androidRoutesKeyProvider = Provider<String>(
    (ref) => const String.fromEnvironment('GOOGLE_MAPS_ANDROID_ROUTES_KEY'));
final iosRoutesKeyProvider = Provider<String>(
    (ref) => const String.fromEnvironment('GOOGLE_MAPS_IOS_ROUTES_KEY'));

/// The Routes key for the ACTIVE platform — NOT "either key" (#5). An Android
/// build carrying only the iOS key must resolve to empty here.
final activeRoutesKeyProvider = Provider<String>((ref) {
  return switch (ref.watch(mapsNavPlatformProvider)) {
    MapsNavPlatform.android => ref.watch(androidRoutesKeyProvider),
    MapsNavPlatform.ios => ref.watch(iosRoutesKeyProvider),
    MapsNavPlatform.unsupported => '',
  };
});

/// True when the active platform has a non-empty Routes key.
final routesConfiguredProvider =
    Provider<bool>((ref) => ref.watch(activeRoutesKeyProvider).isNotEmpty);

/// Whether the native Maps SDK key was configured for THIS build.
///
/// This is a BUILD-TIME assertion, not runtime detection: there is no clean way
/// for Dart to query whether iOS `GMSServices.provideAPIKey` / the Android
/// manifest key were actually set. The build that provides the native secret
/// files ALSO passes `--dart-define=MAPS_NATIVE_CONFIGURED=true`. Keeping it a
/// separate flag from [routesConfiguredProvider] is what lets the capability
/// matrix prove the "routes present but native map absent → disabled" trap is
/// closed. Overridable in tests.
final embeddedMapConfiguredProvider = Provider<bool>(
    (ref) => const bool.fromEnvironment('MAPS_NATIVE_CONFIGURED'));

/// The single gate every Google-nav entry point checks: native map configured
/// AND an active-platform Routes key AND a mobile surface.
final googleNavEnabledProvider = Provider<bool>((ref) {
  return ref.watch(embeddedMapConfiguredProvider) &&
      ref.watch(routesConfiguredProvider) &&
      ref.watch(mapsNavPlatformProvider) != MapsNavPlatform.unsupported;
});

/// The production [RoutesService], built from the active-platform Routes key +
/// the assembled identity headers (async because the Android cert is read
/// natively). Tests override this with a fake. The `http.Client` is closed when
/// the provider is disposed.
final routesServiceProvider = FutureProvider<RoutesService>((ref) async {
  final identity = await ref.watch(routesClientIdentityProvider.future);
  final key = ref.watch(activeRoutesKeyProvider);
  final client = http.Client();
  ref.onDispose(client.close);
  return ConsentGuardedRoutesService(
    inner: GoogleRoutesService(
      client: client,
      apiKey: key,
      platformHeaders: identity.headers,
    ),
    consent: () => ref.read(mapsConsentProvider),
  );
});

/// Wraps a [RoutesService] so no request leaves the device unless maps consent
/// is `accepted` at the moment of the call.
///
/// Consent is read through a callback rather than captured at construction:
/// caching it would let a request slip out after the user revoked in Settings,
/// which is precisely the leak spec §2c exists to close.
class ConsentGuardedRoutesService implements RoutesService {
  ConsentGuardedRoutesService({required this.inner, required this.consent});

  final RoutesService inner;
  final MapsConsent Function() consent;

  @override
  Future<RouteResult> walkingRoute({
    required (double lat, double lng) origin,
    required (double lat, double lng) destination,
  }) async {
    if (consent() != MapsConsent.accepted) return const RouteConsentRefused();

    final result =
        await inner.walkingRoute(origin: origin, destination: destination);

    // Re-check AFTER the await. An HTTP request already on the wire cannot be
    // recalled — claiming otherwise would be a lie — but its response must not
    // reach the UI or any cache once the user has revoked. That is the
    // enforceable half of "cancel or block in-flight requests".
    if (consent() != MapsConsent.accepted) return const RouteConsentRefused();
    return result;
  }
}

/// One walking-route request per (origin, destination). `autoDispose` frees it
/// when the nav screen closes; the family key dedups simultaneous consumers so
/// a single (origin,dest) bills a single Routes call. Retry = invalidate on an
/// explicit user action, never an automatic re-fetch.
final navRouteProvider = FutureProvider.autoDispose
    .family<RouteResult, ((double, double), (double, double))>((ref, args) async {
  final service = await ref.watch(routesServiceProvider.future);
  return service.walkingRoute(origin: args.$1, destination: args.$2);
});

/// The origin GPS for a nav session, captured ONCE (a snapshot — the route is
/// not re-computed as the attendee walks). Ensures permission, then takes the
/// first fix. Returns null when permission is refused or no fix arrives, so the
/// screen can offer a curated/external fallback. Overridable in tests.
final navOriginProvider = FutureProvider.autoDispose<(double, double)?>((ref) async {
  final svc = ref.watch(locationServiceProvider);
  var status = await svc.status();
  if (status != LocationStatus.granted) {
    status = await svc.request();
  }
  if (status != LocationStatus.granted) return null;
  try {
    final fix = await svc.watch().first.timeout(const Duration(seconds: 12));
    return (fix.position.latitude, fix.position.longitude);
  } catch (_) {
    return null;
  }
});
