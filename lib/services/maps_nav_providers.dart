import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'campus_scope.dart';
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
///
/// Falls back to [nativeMapsApiKeyProvider] when the platform's own Routes
/// define is absent. The Routes defines are COMPILE-time, so a run without
/// `--dart-define-from-file=.env` has none — while the device itself may be
/// perfectly well keyed (iOS Info.plist / Android manifest, resolved at runtime
/// in `main.dart`). A single Google key legitimately serves both the Maps SDK
/// and the Routes API when its API restrictions allow both, which is exactly
/// the "same key in every entry" setup. A per-platform Routes define still wins
/// when supplied, so a properly restricted production build is unaffected.
final activeRoutesKeyProvider = Provider<String>((ref) {
  final explicit = switch (ref.watch(mapsNavPlatformProvider)) {
    MapsNavPlatform.android => ref.watch(androidRoutesKeyProvider),
    MapsNavPlatform.ios => ref.watch(iosRoutesKeyProvider),
    MapsNavPlatform.unsupported => '',
  };
  if (explicit.isNotEmpty) return explicit;
  // Web/desktop never route from the device, so no fallback there.
  if (ref.watch(mapsNavPlatformProvider) == MapsNavPlatform.unsupported) return '';
  return ref.watch(nativeMapsApiKeyProvider);
});

/// True when the active platform has a non-empty Routes key.
final routesConfiguredProvider =
    Provider<bool>((ref) => ref.watch(activeRoutesKeyProvider).isNotEmpty);

/// The effective native Maps SDK key for this run — one key drives every Google
/// surface (the embedded map, and the Routes call when no platform Routes key
/// was supplied).
///
/// The default here is the COMPILE-time `MAPS_API_KEY` define. `main.dart`
/// OVERRIDES it with the value resolved at runtime, which additionally picks up
/// the platform's own configuration (iOS Info.plist `GMSApiKey`, Android
/// manifest `geo.API_KEY`) — so a build launched from Xcode or a plain
/// `flutter run`, with no `--dart-define-from-file=.env`, still finds its key
/// instead of falsely reporting "Google Maps is not configured yet".
/// Overridable in tests.
final nativeMapsApiKeyProvider = Provider<String>(
    (ref) => const String.fromEnvironment('MAPS_API_KEY'));

/// Whether the native Maps SDK key was configured for THIS build.
///
/// Derived from [nativeMapsApiKeyProvider] rather than a separate hand-set flag:
/// supplying `MAPS_API_KEY` (via `.env`) is now the ONE action that both keys
/// the native map and flips this true, so there is no second flag to forget.
/// Kept a distinct provider from [routesConfiguredProvider] so the capability
/// matrix can still prove the "routes present but native map absent → disabled"
/// trap is closed. Overridable in tests.
final embeddedMapConfiguredProvider =
    Provider<bool>((ref) => ref.watch(nativeMapsApiKeyProvider).isNotEmpty);

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

/// The resolved walking-origin for a nav session. Three distinct outcomes,
/// because they need three different screens:
///
/// * [NavOriginOnCampus] — a live fix inside the campus scope; route it.
/// * [NavOriginOffCampus] — a live fix OUTSIDE campus; the app must NOT route a
///   long walk in from an arbitrary Sydney location. The screen says directions
///   are available once you are on campus.
/// * [NavOriginUnavailable] — permission refused or no fix arrived; offer the
///   external hand-off, which can start from the device's own location.
sealed class NavOrigin {
  const NavOrigin();
}

class NavOriginOnCampus extends NavOrigin {
  final (double, double) point;
  const NavOriginOnCampus(this.point);
}

class NavOriginOffCampus extends NavOrigin {
  const NavOriginOffCampus();
}

class NavOriginUnavailable extends NavOrigin {
  const NavOriginUnavailable();
}

/// The origin for a nav session, captured ONCE (a snapshot — the route is not
/// re-computed as the attendee walks). Ensures permission, takes the first fix,
/// then validates it against the campus scope so an off-campus GPS position
/// cannot silently generate a kilometres-long walk-in route. Overridable in
/// tests.
final navOriginProvider = FutureProvider.autoDispose<NavOrigin>((ref) async {
  final svc = ref.watch(locationServiceProvider);
  var status = await svc.status();
  if (status != LocationStatus.granted) {
    status = await svc.request();
  }
  if (status != LocationStatus.granted) return const NavOriginUnavailable();
  try {
    final fix = await svc.watch().first.timeout(const Duration(seconds: 12));
    final lat = fix.position.latitude, lng = fix.position.longitude;
    if (!const CampusScope().contains(lat, lng)) {
      return const NavOriginOffCampus();
    }
    return NavOriginOnCampus((lat, lng));
  } catch (_) {
    return const NavOriginUnavailable();
  }
});
