import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/models/search_entry.dart';
import 'package:aon2026/config/qa_mode.dart';
import 'package:aon2026/services/campus_scope.dart';
import 'package:aon2026/services/maps_consent_providers.dart';
import 'package:aon2026/services/maps_consent_store.dart';
import 'package:aon2026/services/maps_nav_providers.dart';
import 'package:aon2026/services/maps_sdk_initializer.dart';
import 'package:aon2026/services/nav_trace.dart';
import 'package:aon2026/services/nav_format.dart';
import 'package:aon2026/services/routes_service.dart';
import 'package:aon2026/services/search_providers.dart';
import 'package:aon2026/widgets/embedded_map.dart';

/// Embedded Google walking-navigation for an M3 place key. Runs the strict
/// sequence: capability → resolve destination → consent → location (snapshot) →
/// route → map. Every failure lands on a standalone AON panel, never a blank
/// Google-tiles view — and NEVER a hand-off to the external Google Maps app: the
/// visitor always stays inside AON (product requirement 2026-08-30). A route
/// that cannot be fetched shows an in-app error with Retry, not a way out.
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
  bool _autoAccepted = false;

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

    // (1) Capability guard — feature disabled → unavailable panel. No external
    // hand-off: if in-app directions can't run we say so and offer the way back,
    // never a bounce out to the Google Maps app.
    // Gate on the boolean (the long-established seam every caller and test
    // overrides); consult the availability enum only to explain WHY.
    if (!ref.watch(googleNavEnabledProvider)) {
      final availability = ref.watch(googleNavAvailabilityProvider);
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
          actions: [_backButton(context)],
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

        // (3) Consent — NO blocking modal. Google is the only directions
        // provider, so opening this screen IS the choice to use it. A first-run
        // `unknown` consent is auto-accepted so the map + route load immediately;
        // the passive privacy notice lives in Settings (settingsGoogleMapsNotice),
        // where the user can also turn sharing OFF. `declined` is the one state
        // that shows a panel (with a one-tap re-enable) instead of routing —
        // never a modal on every Directions tap (field report, Pouya 2026-08-28).
        final consent = ref.watch(mapsConsentProvider);
        if (consent == MapsConsent.unknown) {
          _autoAcceptOnce();
          return _scaffold(l, title: place.title, body: _spinner(context));
        }
        if (consent == MapsConsent.declined) {
          return _scaffold(
              l, title: place.title, body: _sharingOffPanel(context, l));
        }

        // (4) Location origin, captured once (snapshot), scope-validated.
        final originAsync = ref.watch(navOriginProvider);
        navTrace('origin_state loading=${originAsync.isLoading} '
            'hasValue=${originAsync.hasValue} hasError=${originAsync.hasError} '
            'type=${originAsync.asData?.value.runtimeType}');
        return originAsync.when(
          loading: () => _scaffold(l, title: place.title, body: _spinner(context)),
          error: (_, _) => _scaffold(
              l, title: place.title, body: _needLocation(context, l)),
          data: (origin) => switch (origin) {
            // No permission / no fix — we can't draw the route without an origin.
            // Offer a Retry (re-request the fix) in-app; never a bounce out.
            NavOriginUnavailable() =>
              _scaffold(l, title: place.title, body: _needLocation(context, l)),
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

  /// First-run consent is accepted silently (no modal) once per screen, after
  /// the frame so we never mutate a provider mid-build. Latched so a rebuild
  /// while the accept is in flight does not re-post it.
  void _autoAcceptOnce() {
    if (_autoAccepted) return;
    _autoAccepted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(mapsConsentProvider.notifier).accept();
    });
  }

  /// The visitor turned directions data-sharing OFF in Settings. No modal — a
  /// plain panel with a one-tap re-enable. No external hand-off: turning sharing
  /// back on is the only path to directions, and it keeps them inside AON.
  Widget _sharingOffPanel(BuildContext context, AonL10n l) => _panel(
        context,
        icon: Icons.location_disabled_outlined,
        message: l.mapNavDisclosureBody,
        actions: [
          FilledButton(
            key: const Key('nav-enable-sharing'),
            onPressed: () => ref.read(mapsConsentProvider.notifier).accept(),
            child: Text(l.mapNavDisclosureAccept),
          ),
        ],
      );

  Widget _resultBody(BuildContext context, AonL10n l, RouteResult? result,
      (double, double) origin, (double, double) dest,
      {bool routeLoading = false}) {
    // Consent withdrawn mid-flight is the ONE case with no map: nothing reached
    // the UI and no Google surface may be constructed, so offer the way back
    // rather than a map the user just revoked permission for.
    if (result is RouteConsentRefused) {
      // Sharing was turned off (in Settings) between opening this screen and the
      // route returning. Offer a one-tap re-enable, not a modal.
      return _sharingOffPanel(context, l);
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
          // In-app Retry ONLY — the destination is on the map above, so the way
          // forward is to re-fetch the route, never to leave AON.
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: _retryButton(context, l, origin, dest),
          ),
        ],
      ),
    );
  }


  Widget _needLocation(BuildContext context, AonL10n l) => _panel(
        context,
        icon: Icons.location_off_outlined,
        message: l.mapNavNeedLocation,
        // Re-request the fix in-app. `navOriginProvider` is autoDispose, so
        // invalidating it re-runs the location read on the next watch.
        actions: [
          FilledButton.tonal(
            key: const Key('nav-retry-location'),
            onPressed: () => ref.invalidate(navOriginProvider),
            child: Text(l.mapNavRetry),
          ),
        ],
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
          // Distance · ETA · a WALK badge — the walking headline of the route.
          Row(
            children: [
              Icon(Icons.directions_walk_rounded,
                  size: 20, color: context.aon.accent),
              const SizedBox(width: AonSpacing.space2),
              Expanded(
                child: Text(
                  '${formatNavDistance(l, route.distanceMeters)} · ${formatNavEta(l, route.eta)}',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: context.aon.contentPrimary),
                ),
              ),
            ],
          ),
          // Google-supplied route warnings, if any (rendered verbatim — the
          // contractual bit; the app adds no generic "beta" caution of its own).
          if (route.warnings.isNotEmpty) ...[
            const SizedBox(height: AonSpacing.space2),
            Text(l.mapNavWarningsTitle,
                style: theme.textTheme.labelMedium?.copyWith(color: context.aon.contentSecondary)),
            for (final w in route.warnings)
              Text('• $w',
                  style: theme.textTheme.bodySmall?.copyWith(color: context.aon.contentTertiary)),
          ],
          // A compact, SCROLLABLE step list — only ever the steps Google actually
          // returned (`route.steps`). Bounded so it can't crowd the map above it.
          if (route.steps.isNotEmpty) ...[
            const SizedBox(height: AonSpacing.space3),
            Text(l.mapNavStepsTitle,
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: context.aon.contentSecondary)),
            const SizedBox(height: AonSpacing.space1),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 148),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: route.steps.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AonSpacing.space2),
                itemBuilder: (_, i) => _StepRow(step: route.steps[i], l: l),
              ),
            ),
          ],
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

  Widget _backButton(BuildContext context) => TextButton(
        onPressed: () => Navigator.of(context).maybePop(),
        child: Text(MaterialLocalizations.of(context).backButtonTooltip),
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

/// One Google-supplied walking step: a walk glyph, the instruction text exactly
/// as Google phrased it, and the step's distance. Never a locally invented step.
class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.l});
  final NavStep step;
  final AonL10n l;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.directions_walk_rounded,
            size: 16, color: context.aon.contentTertiary),
        const SizedBox(width: AonSpacing.space2),
        Expanded(
          child: Text(step.instruction,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: context.aon.contentSecondary)),
        ),
        if (step.distanceMeters > 0) ...[
          const SizedBox(width: AonSpacing.space2),
          Text(formatNavDistance(l, step.distanceMeters),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: context.aon.contentTertiary)),
        ],
      ],
    );
  }
}
