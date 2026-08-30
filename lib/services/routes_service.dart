/// A decoded walking route: the polyline (geographic degree pairs), total
/// distance, estimated time, and any Google-supplied warnings.
///
/// `warnings` carries the Routes API's `routes.warnings[]` — the notices Google
/// actually supplies for a given route. The UI renders these verbatim when
/// present (the contractual bit); it does NOT add its own generic "beta" caution
/// on top (removed 2026-08-30 — it read as boilerplate, not guidance).
class NavRoute {
  final List<(double lat, double lng)> polyline;
  final int distanceMeters;
  final Duration eta;
  final List<String> warnings;

  /// Turn-by-turn walking steps, in order, EXACTLY as Google supplied them
  /// (`routes.legs.steps`). Empty when the field mask did not request them or
  /// the response omitted them — the UI then simply shows no step list rather
  /// than inventing instructions (design: never fabricate directions).
  final List<NavStep> steps;

  const NavRoute({
    required this.polyline,
    required this.distanceMeters,
    required this.eta,
    this.warnings = const [],
    this.steps = const [],
  });
}

/// One walking instruction from Google's `routes.legs.steps[]`: the human
/// `navigationInstruction.instructions` text and the step's own distance. Never
/// synthesised locally — only ever a verbatim Google-supplied step.
class NavStep {
  final String instruction;
  final int distanceMeters;
  const NavStep({required this.instruction, required this.distanceMeters});
}

/// The typed outcome of a route request. Auth/quota/network/no-route/malformed
/// are DISTINCT — collapsing them into a nullable would hide "your key is
/// misconfigured" behind "no walking route exists".
sealed class RouteResult {
  const RouteResult();
}

class RouteSuccess extends RouteResult {
  final NavRoute route;
  const RouteSuccess(this.route);
}

/// HTTP 200 but zero routes — genuinely no walking route between the points.
class RouteNoRoute extends RouteResult {
  const RouteNoRoute();
}

/// The request threw before a response (offline, DNS, TLS…).
class RouteNetworkFailure extends RouteResult {
  const RouteNetworkFailure();
}

/// A non-200 response — auth (401/403), quota (429), server (5xx). `status`
/// preserved so the UI/logs can distinguish "fix your key" from "try later".
class RouteApiFailure extends RouteResult {
  final int status;
  const RouteApiFailure(this.status);
}

/// A 200 response whose body could not be parsed OR was missing required
/// fields. NEVER conflated with [RouteNoRoute] (a route object that lacks a
/// distance/polyline is malformed, not an absence of route).
class RouteMalformed extends RouteResult {
  const RouteMalformed();
}

/// The request exceeded [kRouteRequestTimeout] and was abandoned.
///
/// Distinct from [RouteNetworkFailure]: the network did not report an error, it
/// simply never answered. Keeping it separate makes an eternal-spinner
/// regression visible in logs and tests instead of masquerading as an outage.
class RouteTimeout extends RouteResult {
  const RouteTimeout();
}

/// The request was refused locally because maps consent is not `accepted`.
///
/// Distinct from every network and parse outcome: **nothing left the device**.
/// Also returned when consent is withdrawn while a request is in flight — an
/// HTTP request already on the wire cannot be recalled, but its response must
/// never reach the UI or any cache (spec §2c).
class RouteConsentRefused extends RouteResult {
  const RouteConsentRefused();
}

/// The seam the rest of M4 depends on. [GoogleRoutesService] is one
/// implementation; tests and `routesServiceProvider` inject fakes against this.
abstract interface class RoutesService {
  Future<RouteResult> walkingRoute({
    required (double lat, double lng) origin,
    required (double lat, double lng) destination,
  });
}
