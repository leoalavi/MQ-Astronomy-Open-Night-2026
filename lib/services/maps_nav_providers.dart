import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:aon2026/config/qa_mode.dart';

import 'campus_scope.dart';
import 'nav_trace.dart';
import 'google_routes_service.dart';
import 'location_providers.dart';
import 'location_service.dart';
import 'maps_build_keys.dart';
import 'maps_consent_providers.dart';
import 'maps_consent_store.dart';
import 'routes_client_identity.dart';
import 'routes_service.dart';

/// Which surface the app is running on, for Google-nav capability.
///
/// `web` is a FIRST-CLASS target: `google_maps_flutter_web` renders a real
/// embedded map, and the Routes API accepts browser requests (its CORS preflight
/// allows POST with our `x-goog-api-key` / `x-goog-fieldmask` headers). It was
/// previously lumped into `unsupported`, which is what made the web build claim
/// the API key was missing when it was present.
///
/// `unsupported` now means desktop only — macOS/Windows/Linux have no
/// `google_maps_flutter` implementation at all.
enum MapsNavPlatform { unsupported, android, ios, web }

/// The running platform. Web-safe: `kIsWeb` short-circuits before
/// `defaultTargetPlatform` (which on web reports the *browser's* OS and would
/// otherwise mislabel a mobile browser as android/ios). Overridable in tests.
final mapsNavPlatformProvider = Provider<MapsNavPlatform>((ref) {
  // kIsWeb FIRST: on web `defaultTargetPlatform` reports the *browser's* OS and
  // would mislabel a phone browser as android/ios.
  if (kIsWeb) return MapsNavPlatform.web;
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
  (ref) => configuredAndroidRoutesKey,
);
final iosRoutesKeyProvider = Provider<String>((ref) => configuredIosRoutesKey);

/// The web Routes key is the same HTTP-referrer-restricted `MAPS_API_KEY` used
/// by Maps JavaScript. The conditional build-key import ensures a web build has
/// no references to either native route-key define.
final webRoutesKeyProvider = Provider<String>((ref) => configuredWebRoutesKey);

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
  final platform = ref.watch(mapsNavPlatformProvider);
  final explicit = switch (platform) {
    MapsNavPlatform.android => ref.watch(androidRoutesKeyProvider),
    MapsNavPlatform.ios => ref.watch(iosRoutesKeyProvider),
    MapsNavPlatform.web => ref.watch(webRoutesKeyProvider),
    MapsNavPlatform.unsupported => '',
  };
  if (explicit.isNotEmpty) return explicit;
  // Desktop cannot host a map, so it never routes.
  if (platform == MapsNavPlatform.unsupported) return '';
  return ref.watch(nativeMapsApiKeyProvider);
});

/// True when the active platform has a non-empty Routes key.
final routesConfiguredProvider = Provider<bool>(
  (ref) => ref.watch(activeRoutesKeyProvider).isNotEmpty,
);

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
  (ref) => configuredMapsApiKey,
);

/// Whether the native Maps SDK key was configured for THIS build.
///
/// Derived from [nativeMapsApiKeyProvider] rather than a separate hand-set flag:
/// supplying `MAPS_API_KEY` (via `.env`) is now the ONE action that both keys
/// the native map and flips this true, so there is no second flag to forget.
/// Kept a distinct provider from [routesConfiguredProvider] so the capability
/// matrix can still prove the "routes present but native map absent → disabled"
/// trap is closed. Overridable in tests.
final embeddedMapConfiguredProvider = Provider<bool>(
  (ref) => ref.watch(nativeMapsApiKeyProvider).isNotEmpty,
);

/// WHY embedded Google navigation is or is not available.
///
/// The gate used to be a bare bool, so three very different causes all surfaced
/// as the same "Google Maps is not configured yet. Please add the Google Maps
/// API key" panel. On web and macOS — where `google_maps_flutter` has no
/// implementation at all — that message is simply untrue: the key is present
/// and irrelevant. Someone reading it goes hunting for a credentials bug that
/// does not exist. Naming the cause is what makes the screen diagnosable.
enum GoogleNavAvailability {
  /// Everything needed is present.
  ready,

  /// No native Maps SDK key resolved (neither Dart define nor platform config).
  missingMapsKey,

  /// A Maps key exists but this platform has no Routes key.
  missingRoutesKey,

  /// This platform cannot host an embedded Google map at all.
  /// `google_maps_flutter` ships android/ios/web implementations only, so this
  /// is now desktop (macOS/Windows/Linux) alone.
  platformUnsupported,
}

/// The diagnosable form of the gate. Order matters: platform support is checked
/// FIRST, because on an unsupported platform the keys are beside the point.
final googleNavAvailabilityProvider = Provider<GoogleNavAvailability>((ref) {
  if (ref.watch(mapsNavPlatformProvider) == MapsNavPlatform.unsupported) {
    return GoogleNavAvailability.platformUnsupported;
  }
  if (!ref.watch(embeddedMapConfiguredProvider)) {
    return GoogleNavAvailability.missingMapsKey;
  }
  if (!ref.watch(routesConfiguredProvider)) {
    return GoogleNavAvailability.missingRoutesKey;
  }
  return GoogleNavAvailability.ready;
});

/// The single gate every Google-nav entry point checks. Derived from
/// [googleNavAvailabilityProvider] so the boolean and the reason can never
/// disagree.
final googleNavEnabledProvider = Provider<bool>(
  (ref) =>
      ref.watch(googleNavAvailabilityProvider) == GoogleNavAvailability.ready,
);

/// Boolean-only capability trace for QA. Contains NO key material — only
/// whether each input is present — so it is safe in logs and bug reports.
/// Takes the READ surface shared by `Ref` and `WidgetRef`, so both providers
/// and widgets can emit the same trace.
String describeGoogleNavState(WidgetRef ref) {
  return [
    'platform=${ref.read(mapsNavPlatformProvider).name}',
    'mapsKeyPresent=${ref.read(nativeMapsApiKeyProvider).isNotEmpty}',
    'routesKeyPresent=${ref.read(activeRoutesKeyProvider).isNotEmpty}',
    'availability=${ref.read(googleNavAvailabilityProvider).name}',
    'googleNavEnabled=${ref.read(googleNavEnabledProvider)}',
  ].join(' ');
}

/// The production [RoutesService], built from the active-platform Routes key +
/// the assembled identity headers (async because the Android cert is read
/// natively). Tests override this with a fake. The `http.Client` is closed when
/// the provider is disposed.
final routesServiceProvider = FutureProvider<RoutesService>((ref) async {
  navTrace('routes_service_build_start');
  final identity = await ref.watch(routesClientIdentityProvider.future);
  navTrace('identity_resolved headers=${identity.headers.length}');
  final key = ref.watch(activeRoutesKeyProvider);
  // NON-SECRET diagnostic: which key is this build actually routing with, and
  // where did it come from. On device the 401 came from a build with no
  // `--dart-define-from-file=.env`, so the key fell back to the native Info.plist
  // value — if that `fp` differs from the `.env` key's, the installed binary
  // baked a stale key. Never prints key material (see keyFingerprint).
  final platform = ref.read(mapsNavPlatformProvider);
  final explicitRoutesKey = switch (platform) {
    MapsNavPlatform.android => ref.read(androidRoutesKeyProvider),
    MapsNavPlatform.ios => ref.read(iosRoutesKeyProvider),
    MapsNavPlatform.web => ref.read(webRoutesKeyProvider),
    MapsNavPlatform.unsupported => '',
  };
  final source = explicitRoutesKey.isNotEmpty
      ? 'platform-routes-define'
      : (configuredMapsApiKey.isNotEmpty ? 'maps-define' : 'native-runtime');
  navTrace('routes_key source=$source ${keyFingerprint(key)}');
  final client = http.Client();
  ref.onDispose(client.close);
  navTrace('routes_service_ready');
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

    final result = await inner.walkingRoute(
      origin: origin,
      destination: destination,
    );

    // Re-check AFTER the await. An HTTP request already on the wire cannot be
    // recalled — claiming otherwise would be a lie — but its response must not
    // reach the UI or any cache once the user has revoked. That is the
    // enforceable half of "cancel or block in-flight requests".
    if (consent() != MapsConsent.accepted) return const RouteConsentRefused();
    return result;
  }
}

/// How long a single route request may take before it is declared failed.
const Duration kRouteRequestTimeout = Duration(seconds: 15);

/// One walking-route request per (origin, destination). `autoDispose` frees it
/// when the nav screen closes; the family key dedups simultaneous consumers so
/// a single (origin,dest) bills a single Routes call. Retry = invalidate on an
/// explicit user action, never an automatic re-fetch.
final navRouteProvider = FutureProvider.autoDispose
    .family<RouteResult, ((double, double), (double, double))>((
      ref,
      args,
    ) async {
      navTrace('nav_route_provider_start');
      final service = await ref.watch(routesServiceProvider.future);
      navTrace('nav_route_got_service');
      // HARD BOUND. Nothing downstream may leave the screen pending forever: a
      // stalled socket, a captive portal or a silently-dropped response all used to
      // mean an eternal spinner. A timeout becomes a typed failure like any other,
      // so the map stays up and Retry is offered.
      final r = await service
          .walkingRoute(origin: args.$1, destination: args.$2)
          .timeout(
            kRouteRequestTimeout,
            onTimeout: () {
              navTrace(
                'route_timeout after '
                '${kRouteRequestTimeout.inSeconds}s',
              );
              return const RouteTimeout();
            },
          );
      navTrace('provider_complete result=${r.runtimeType}');
      return r;
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
  // The EFFECTIVE service, not the raw one: preview mode (§3c) substitutes a
  // simulated on-campus fix, and nav origin must honour it exactly as the map
  // dot and compass do — otherwise a tester far from campus is blocked here
  // even with preview on. The map/compass already read the effective service
  // via LocationController; this was the one surface that bypassed it.
  final svc = ref.watch(effectiveLocationServiceProvider);
  var status = await svc.status();
  if (status != LocationStatus.granted) {
    status = await svc.request();
  }
  if (status != LocationStatus.granted) return const NavOriginUnavailable();
  try {
    // Prefer the CANONICAL settled fix (the same filtered position the map dot
    // and compass show) when the controller already has one — it is the
    // sharpest fix seen, not the coarse first sample `watch().first` returns.
    // The route then starts from where the visitor actually is, not the cell
    // fix that put the dot 150 m away on the day. Falls back to a fresh one-shot
    // when nothing has settled yet (Directions opened without visiting the map).
    final settled = ref.read(locationControllerProvider).fix;
    final fix =
        settled ?? await svc.watch().first.timeout(const Duration(seconds: 12));
    final lat = fix.position.latitude, lng = fix.position.longitude;
    // QA mode lifts the campus-scope refusal so the walking flow can be
    // exercised from wherever the tester actually is. Walking-only and
    // Google-only are untouched — only the geographic gate is relaxed.
    if (!ref.watch(allowOffCampusTestingProvider) &&
        !const CampusScope().contains(lat, lng)) {
      return const NavOriginOffCampus();
    }
    return NavOriginOnCampus((lat, lng));
  } catch (_) {
    return const NavOriginUnavailable();
  }
});
