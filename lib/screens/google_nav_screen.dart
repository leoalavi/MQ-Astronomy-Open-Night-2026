import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/models/search_entry.dart';
import 'package:aon2026/config/qa_mode.dart';
import 'package:aon2026/services/campus_scope.dart';
import 'package:aon2026/services/external_maps_launcher.dart';
import 'package:aon2026/services/maps_consent_providers.dart';
import 'package:aon2026/services/maps_consent_store.dart';
import 'package:aon2026/services/maps_nav_providers.dart';
import 'package:aon2026/services/maps_sdk_initializer.dart';
import 'package:aon2026/services/maps_url.dart';
import 'package:aon2026/services/nav_trace.dart';
import 'package:aon2026/services/nav_format.dart';
import 'package:aon2026/services/routes_service.dart';
import 'package:aon2026/services/search_providers.dart';
import 'package:aon2026/widgets/embedded_map.dart';
import 'package:aon2026/widgets/maps_nav_disclosure.dart';

/// Embedded Google walking-navigation for an M3 place key. Runs the strict
/// sequence: capability → resolve destination → consent → location (snapshot) →
/// route → map. Every failure lands on a standalone AON panel, never a blank
/// Google-tiles view. Renders the Google-mandated walking warning on success.
class GoogleNavScreen extends ConsumerStatefulWidget {
  const GoogleNavScreen({
    super.key,
    required this.placeKey,
    this.surface = const GoogleEmbeddedMapSurface(),
  });

  final String placeKey;

  /// Injectable so widget tests build without a real Google platform view.
  final EmbeddedMapSurface surface;

  @override
  ConsumerState<GoogleNavScreen> createState() => _GoogleNavScreenState();
}

class _GoogleNavScreenState extends ConsumerState<GoogleNavScreen> {
  bool _disclosureRequested = false;

  @override
  Widget build(BuildContext context) {
    final l = AonL10n.of(context);
    // Maps SDK readiness is requested HERE, at the top of build, so it starts
    // the moment the screen exists and is never gated behind the route. It used
    // to be watched only inside the route-success branch, so a route that never
    // resolved meant `ensureInitialized()` was never even called and the map
    // could not appear — the screen span on a spinner forever.
    final sdkAsync = ref.watch(mapsSdkReadyProvider);
    navTrace('build_start sdkLoading=${sdkAsync.isLoading} '
        'sdkReady=${sdkAsync.asData?.value}');
    final resolved = ref.watch(placeResolverProvider(widget.placeKey));

    // (1) Capability guard — feature disabled → unavailable panel (with an
    // optional external-Maps button if we can resolve a destination).
    // Gate on the boolean (the long-established seam every caller and test
    // overrides); consult the availability enum only to explain WHY.
    if (!ref.watch(googleNavEnabledProvider)) {
      final availability = ref.watch(googleNavAvailabilityProvider);
      final dest = _destOf(resolved.asData?.value);
      // Boolean-only trace (never the key) so a QA report can say WHY.
      navTrace(describeGoogleNavState(ref));
      // Tell the truth about the cause. Blaming a missing key on a platform
      // that simply has no Google map surface sends people hunting for a
      // credentials bug that does not exist.
      final message = switch (availability) {
        GoogleNavAvailability.platformUnsupported => l.mapNavPlatformUnsupported,
        _ => l.mapNavUnavailable,
      };
      return _scaffold(
        l,
        title: resolved.asData?.value?.title,
        body: _panel(
          context,
          icon: Icons.map_outlined,
          message: message,
          actions: [if (dest != null) _externalButton(context, l, dest)],
        ),
      );
    }

    // (2) Resolve the local destination (no location, no Google contact yet).
    return resolved.when(
      loading: () => _scaffold(l, title: null, body: _spinner(context)),
      error: (_, _) => _scaffold(l, title: null, body: _errorBack(context, l)),
      data: (place) {
        final dest = _destOf(place);
        if (place == null || dest == null) {
          return _scaffold(l, title: place?.title, body: _errorBack(context, l));
        }

        // (2b) Destination scope — a place off the AON campus map is never
        // routed to (defensive: every curated destination sits inside the
        // campus extent by construction, but nothing downstream should assume
        // it). Honest message instead of a kilometres-long walk-out.
        if (!ref.watch(allowOffCampusTestingProvider) &&
            !const CampusScope().contains(dest.$1, dest.$2)) {
          return _scaffold(
            l,
            title: place.title,
            body: _panel(
              context,
              icon: Icons.wrong_location_outlined,
              message: l.mapNavDestinationOffCampus,
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Text(MaterialLocalizations.of(context).backButtonTooltip),
                ),
              ],
            ),
          );
        }

        // (3) Consent gate — only `accepted` proceeds; unknown/declined show the
        // disclosure before any location read or Google call.
        final consent = ref.watch(mapsConsentProvider);
        if (consentNeedsDisclosure(consent)) {
          _ensureDisclosure();
          // Static placeholder (NOT an animating spinner) — the modal disclosure
          // is shown over it; a spinner here would never let tests settle and
          // burns frames behind a blocking dialog.
          return _scaffold(l, title: place.title, body: const SizedBox.shrink());
        }

        // (4) Location origin, captured once (snapshot), scope-validated.
        final originAsync = ref.watch(navOriginProvider);
        navTrace('origin_state loading=${originAsync.isLoading} '
            'hasValue=${originAsync.hasValue} hasError=${originAsync.hasError} '
            'type=${originAsync.asData?.value.runtimeType}');
        return originAsync.when(
          loading: () => _scaffold(l, title: place.title, body: _spinner(context)),
          error: (_, _) => _scaffold(
              l, title: place.title, body: _needLocation(context, l, dest)),
          data: (origin) => switch (origin) {
            // No permission / no fix — external Maps can still start from the
            // device location, so offer that.
            NavOriginUnavailable() =>
              _scaffold(l, title: place.title, body: _needLocation(context, l, dest)),
            // A real fix, but off campus. Do NOT route a long walk-in; say so.
            NavOriginOffCampus() =>
              _scaffold(l, title: place.title, body: _offCampusOrigin(context, l)),
            // On campus — (5) route request → (6) map / typed error panels.
            NavOriginOnCampus(:final point) => _routeFlow(context, l, place.title, point, dest),
          },
        );
      },
    );
  }

  /// (5) → (6): request the walking route for an on-campus origin and render
  /// the map / typed error panel. Split out so the origin `switch` stays flat.
  Widget _routeFlow(BuildContext context, AonL10n l, String? title,
      (double, double) origin, (double, double) dest) {
    final routeAsync = ref.watch(navRouteProvider((origin, dest)));
    navTrace('route_flow loading=${routeAsync.isLoading} '
        'hasValue=${routeAsync.hasValue} hasError=${routeAsync.hasError}');
    // The MAP does not wait for the route. A pending or failed route only
    // changes the strip under the map, never whether the map exists.
    final RouteResult? result = routeAsync.hasError
        ? const RouteMalformed()
        : routeAsync.asData?.value;
    return _scaffold(
      l,
      title: title,
      body: _resultBody(context, l, result, origin, dest,
          routeLoading: routeAsync.isLoading),
    );
  }

  /// The GPS fix is real but outside campus. The in-app walking flow is
  /// campus-only, so route nothing — tell the visitor to come to campus. The
  /// keyless external hand-off is NOT offered here: it would start the very
  /// long off-campus walk this scope gate exists to prevent.
  Widget _offCampusOrigin(BuildContext context, AonL10n l) => _panel(
        context,
        icon: Icons.explore_off_outlined,
        message: l.mapNavOffCampusOrigin,
      );

  (double, double)? _destOf(ResolvedPlace? place) {
    if (place?.routingLat == null || place?.routingLng == null) return null;
    // Geographic WGS84 (entrance ?? latitude) — NEVER renderPoint (map-units).
    return (place!.routingLat!, place.routingLng!);
  }

  void _ensureDisclosure() {
    if (_disclosureRequested) return;
    _disclosureRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final accepted = await showMapsNavDisclosure(context);
      if (!mounted) return;
      final notifier = ref.read(mapsConsentProvider.notifier);
      if (accepted) {
        notifier.accept(); // rebuild proceeds (consent now accepted)
      } else {
        notifier.decline();
        await Navigator.of(context).maybePop();
      }
      // Re-arm: if consent is later revoked while this screen stays mounted
      // (e.g. via Settings pushed on top), the next disclosure-needed build must
      // show the sheet again instead of a permanent blank body (map audit P2).
      if (mounted) _disclosureRequested = false;
    });
  }

  Widget _resultBody(BuildContext context, AonL10n l, RouteResult? result,
      (double, double) origin, (double, double) dest,
      {bool routeLoading = false}) {
    // Consent withdrawn mid-flight is the ONE case with no map: nothing reached
    // the UI and no Google surface may be constructed, so offer the way back
    // rather than a map the user just revoked permission for.
    if (result is RouteConsentRefused) {
      return _panel(
        context,
        icon: Icons.privacy_tip_outlined,
        message: l.mapNavDisclosureBody,
        actions: [
          FilledButton(
            key: const Key('nav-reopen-disclosure'),
            onPressed: () {
              // Re-arm so the next build shows the disclosure again.
              setState(() => _disclosureRequested = false);
              ref.read(mapsConsentProvider.notifier).revoke();
            },
            child: Text(l.mapNavDisclosureAccept),
          ),
          _externalButton(context, l, dest),
        ],
      );
    }

    // Task 1 deferred GMSServices.provideAPIKey off app launch, so a GoogleMap
    // constructed against an unkeyed SDK would render blank. Consent alone is
    // not sufficient — readiness must be true.
    navTrace('map_render_branch reached');
    final sdkAsync = ref.watch(mapsSdkReadyProvider);
    navTrace('sdk_ready_requested '
        'loading=${sdkAsync.isLoading} value=${sdkAsync.asData?.value}');
    final sdkReady = sdkAsync.asData?.value == true;
    // Distinguish "still initialising" from "resolved: cannot key the SDK".
    // Showing a spinner for the latter span forever, which reads as a hang.
    final sdkStillLoading = sdkAsync.isLoading;

    // THE MAP IS NOT GATED ON THE ROUTE. A failed route used to replace the
    // whole screen with an error panel, which threw away the part that still
    // worked: the visitor could no longer even see WHERE they were going. The
    // map, both markers and the camera fit depend only on the SDK; only the
    // polyline and the distance/ETA depend on the route. So render the map
    // whenever the SDK is ready and let the route decorate it — or not.
    final route = result is RouteSuccess ? result.route : null;

    return Column(
      children: [
        if (sdkReady)
          Expanded(
            child: EmbeddedMap(
              origin: origin,
              destination: dest,
              // Empty on failure: markers and camera still work, no polyline.
              route: route?.polyline ?? const <(double, double)>[],
              surface: widget.surface,
            ),
          )
        else if (sdkStillLoading)
          Expanded(child: _spinner(context))
        else
          // The SDK resolved unusable (no key, or init refused). Say so once
          // rather than spinning forever behind a route error.
          Expanded(
            child: _panel(
              context,
              icon: Icons.map_outlined,
              message: l.mapNavUnavailable,
            ),
          ),
        if (route != null)
          _successPanel(context, l, route, dest)
        else if (routeLoading || result == null)
          // Map is already up; the route is still on its way.
          Container(
            width: double.infinity,
            color: context.aon.surface,
            padding: const EdgeInsets.all(AonSpacing.space4),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: context.aon.accent),
                ),
                const SizedBox(width: AonSpacing.space3),
                Text(l.mapNavFindingRoute,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.aon.contentSecondary)),
              ],
            ),
          )
        else
          _routeErrorBanner(context, l, result, origin, dest),
      ],
    );
  }

  /// A COMPACT route-failure strip under a still-visible map.
  ///
  /// Deliberately a banner, not a full-screen panel: the destination is on the
  /// map above it, so the honest message is "the route is unavailable", not
  /// "navigation is unavailable".
  Widget _routeErrorBanner(BuildContext context, AonL10n l, RouteResult result,
      (double, double) origin, (double, double) dest) {
    final theme = Theme.of(context);
    final (icon, message) = switch (result) {
      RouteNoRoute() => (Icons.directions_off_outlined, l.mapNavNoRoute),
      RouteNetworkFailure() => (Icons.wifi_off_rounded, l.mapNavOffline),
      RouteApiFailure(:final status) => () {
          // Surface the status to logs so 401/403 (key) vs 429 (quota) vs 5xx
          // stays diagnosable from a QA report.
          navTrace('route API failure HTTP $status');
          return (Icons.error_outline_rounded, l.mapNavRouteUnavailable);
        }(),
      _ => (Icons.error_outline_rounded, l.mapNavRouteUnavailable),
    };

    return Container(
      width: double.infinity,
      color: context.aon.surface,
      padding: const EdgeInsets.all(AonSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: context.aon.contentTertiary),
              const SizedBox(width: AonSpacing.space2),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: context.aon.contentSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AonSpacing.space2),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Wrap(
              spacing: AonSpacing.space2,
              children: [
                _retryButton(context, l, origin, dest),
                _externalButton(context, l, dest),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _needLocation(BuildContext context, AonL10n l, (double, double) dest) => _panel(
        context,
        icon: Icons.location_off_outlined,
        message: l.mapNavNeedLocation,
        actions: [_externalButton(context, l, dest)],
      );

  Widget _errorBack(BuildContext context, AonL10n l) => _panel(
        context,
        icon: Icons.error_outline_rounded,
        message: l.mapNavError,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(MaterialLocalizations.of(context).backButtonTooltip),
          ),
        ],
      );

  Widget _successPanel(
      BuildContext context, AonL10n l, NavRoute route, (double, double) dest) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: context.aon.surface,
      padding: const EdgeInsets.all(AonSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${formatNavDistance(l, route.distanceMeters)} · ${formatNavEta(l, route.eta)}',
            style: theme.textTheme.titleMedium?.copyWith(color: context.aon.contentPrimary),
          ),
          const SizedBox(height: AonSpacing.space2),
          // Google-mandated baseline walking caution (WALK is beta) — always shown.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: context.aon.contentTertiary),
              const SizedBox(width: AonSpacing.space2),
              Expanded(
                child: Text(
                  l.mapNavWalkingWarning,
                  style: theme.textTheme.bodySmall?.copyWith(color: context.aon.contentTertiary),
                ),
              ),
            ],
          ),
          // Google-supplied route warnings, if any.
          if (route.warnings.isNotEmpty) ...[
            const SizedBox(height: AonSpacing.space2),
            Text(l.mapNavWarningsTitle,
                style: theme.textTheme.labelMedium?.copyWith(color: context.aon.contentSecondary)),
            for (final w in route.warnings)
              Text('• $w',
                  style: theme.textTheme.bodySmall?.copyWith(color: context.aon.contentTertiary)),
          ],
          const SizedBox(height: AonSpacing.space3),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: _externalButton(context, l, dest),
          ),
        ],
      ),
    );
  }

  Widget _retryButton(
          BuildContext context, AonL10n l, (double, double) origin, (double, double) dest) =>
      FilledButton.tonal(
        onPressed: () => ref.invalidate(navRouteProvider((origin, dest))),
        child: Text(l.mapNavRetry),
      );

  Widget _externalButton(BuildContext context, AonL10n l, (double, double) dest) => TextButton.icon(
        icon: const Icon(Icons.open_in_new_rounded, size: 18),
        // The keyless external hand-off is the last-resort action on every error
        // panel, so a silent throw / false return would strand the user. Await,
        // catch, and surface a failure toast (map audit P2).
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          var ok = false;
          try {
            ok = await ref
                .read(externalMapsLauncherProvider)
                .open(buildWalkingMapsUrl(destLat: dest.$1, destLng: dest.$2));
          } catch (_) {
            ok = false;
          }
          if (!ok) {
            messenger.showSnackBar(SnackBar(content: Text(l.mapNavOpenExternalFailed)));
          }
        },
        label: Text(l.mapNavOpenExternal),
      );

  Widget _spinner(BuildContext context) =>
      Center(child: CircularProgressIndicator(color: context.aon.accent));

  Widget _panel(BuildContext context,
      {required IconData icon, required String message, List<Widget> actions = const []}) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AonSpacing.space4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: context.aon.contentTertiary),
            const SizedBox(height: AonSpacing.space3),
            Text(message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(color: context.aon.contentSecondary)),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: AonSpacing.space3),
              Wrap(spacing: AonSpacing.space2, alignment: WrapAlignment.center, children: actions),
            ],
          ],
        ),
      ),
    );
  }

  Widget _scaffold(AonL10n l, {required String? title, required Widget body}) => Scaffold(
        backgroundColor: context.aon.surfaceBase,
        appBar: AppBar(title: Text(title ?? l.mapNavGoogle)),
        body: SafeArea(child: body),
      );
}
