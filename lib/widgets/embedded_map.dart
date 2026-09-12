import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:aon2026/services/nav_trace.dart';
// The web Directions map is a dedicated google.maps adapter; native keeps the
// google_maps_flutter plugin. The conditional import keeps dart:js_interop out
// of mobile/VM builds — the stub throws and is only reachable on kIsWeb.
import 'package:aon2026/widgets/web_map_view_stub.dart'
    if (dart.library.js_interop) 'package:aon2026/widgets/web_map_view.dart';

/// A geographic bounding box in plain tuples — deliberately NOT
/// `google_maps_flutter`'s `LatLngBounds`, so the bounds math is unit-testable
/// without touching the plugin.
class GeoBounds {
  final (double lat, double lng) southwest;
  final (double lat, double lng) northeast;
  const GeoBounds(this.southwest, this.northeast);
}

/// True when [a] and [b] describe a DIFFERENT route line. Compared by value,
/// not by length: swapping to a new destination whose polyline happens to have
/// the same number of points is still a change, and a length-only check would
/// leave the previous line and camera framing in place (stale geometry, #B/#C).
bool routeGeometryChanged(
  List<(double lat, double lng)> a,
  List<(double lat, double lng)> b,
) => !listEquals(a, b);

/// The camera box: origin ∪ destination ∪ every route point. Origin and
/// destination are included EXPLICITLY because a returned polyline may not
/// contain the exact device origin/destination, and a box over only `route`
/// could clip them (design §0b.D / #18).
GeoBounds boundsFor({
  required (double lat, double lng) origin,
  required (double lat, double lng) destination,
  required List<(double lat, double lng)> route,
}) {
  final pts = <(double, double)>[origin, destination, ...route];
  var minLat = pts.first.$1, maxLat = pts.first.$1;
  var minLng = pts.first.$2, maxLng = pts.first.$2;
  for (final p in pts) {
    if (p.$1 < minLat) minLat = p.$1;
    if (p.$1 > maxLat) maxLat = p.$1;
    if (p.$2 < minLng) minLng = p.$2;
    if (p.$2 > maxLng) maxLng = p.$2;
  }
  return GeoBounds((minLat, minLng), (maxLat, maxLng));
}

/// The tile-rendering surface. Production renders a real `GoogleMap`; widget
/// tests inject a fake so they never need a platform view. Keeping this a local
/// seam avoids faking `google_maps_flutter`'s platform interface (which would
/// pull that package into the declared deps, #19).
abstract interface class EmbeddedMapSurface {
  Widget build({
    required GeoBounds bounds,
    required (double lat, double lng) origin,
    required (double lat, double lng) destination,
    required List<(double lat, double lng)> route,
  });
}

/// The production surface. Web and native diverge here:
///
///  * **Native** (iOS/Android) renders a `google_maps_flutter` `GoogleMap`
///    ([_RouteMapView]) — markers, polyline, and a camera fitted to [bounds].
///  * **Web** renders a dedicated `google.maps` adapter ([buildWebRouteMap]),
///    because the plugin's web camera move blanks the tiles and its web polyline
///    overlay does not render. See `web_map_view.dart`.
class GoogleEmbeddedMapSurface implements EmbeddedMapSurface {
  const GoogleEmbeddedMapSurface();

  @override
  Widget build({
    required GeoBounds bounds,
    required (double lat, double lng) origin,
    required (double lat, double lng) destination,
    required List<(double lat, double lng)> route,
  }) => kIsWeb
      ? buildWebRouteMap(
          bounds: bounds,
          origin: origin,
          destination: destination,
          route: route,
        )
      : _RouteMapView(bounds: bounds, destination: destination, route: route);
}

/// The NATIVE (iOS/Android) Google map, kept alive across the route-state
/// transition (`loading → RouteApiSuccess`) and container resizes.
///
/// Web does NOT use this widget — `GoogleEmbeddedMapSurface.build` routes web to
/// the `google.maps` adapter (`web_map_view.dart`) because the plugin's web
/// camera move blanks the tiles and its web polyline overlay does not render.
/// Everything below therefore runs only on a real device, where
/// `moveCamera(newLatLngBounds)` and the plugin's overlays behave correctly.
class _RouteMapView extends StatefulWidget {
  const _RouteMapView({
    required this.bounds,
    required this.destination,
    required this.route,
  });

  final GeoBounds bounds;
  final (double lat, double lng) destination;
  final List<(double lat, double lng)> route;

  @override
  State<_RouteMapView> createState() => _RouteMapViewState();
}

class _RouteMapViewState extends State<_RouteMapView> {
  GoogleMapController? _controller;
  int _buildCount = 0;
  Size? _lastSize;

  static LatLng _ll((double, double) p) => LatLng(p.$1, p.$2);

  LatLngBounds get _gBounds => LatLngBounds(
    southwest: _ll(widget.bounds.southwest),
    northeast: _ll(widget.bounds.northeast),
  );

  // Native only (web uses the google.maps adapter). Start centred on the
  // destination; `_fit` reframes to the whole route once the map is laid out.
  CameraPosition _initialCamera(Size size) =>
      CameraPosition(target: _ll(widget.destination), zoom: 15);

  /// Fit the native camera to origin ∪ destination ∪ route with padding.
  Future<void> _fit() async {
    final c = _controller;
    if (c == null) return;
    final sw = widget.bounds.southwest, ne = widget.bounds.northeast;
    navTrace(
      'map_fit '
      'sw=(${sw.$1.toStringAsFixed(5)},${sw.$2.toStringAsFixed(5)}) '
      'ne=(${ne.$1.toStringAsFixed(5)},${ne.$2.toStringAsFixed(5)}) '
      'polyline=${widget.route.length}',
    );
    try {
      await c.moveCamera(CameraUpdate.newLatLngBounds(_gBounds, 48));
    } catch (e) {
      // Invalid/degenerate bounds or a not-yet-laid-out map must never throw out
      // of a frame callback and take the screen down (#9/#10). The map stays;
      // the next transition re-fits.
      navTrace('map_fit_threw (${e.runtimeType})');
    }
  }

  void _fitAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fit();
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _RouteMapView old) {
    super.didUpdateWidget(old);
    // Geometry, not length: a new destination whose polyline has the same number
    // of points must still replace the stale line and re-fit the camera (#B/#C).
    final routeChanged = routeGeometryChanged(old.route, widget.route);
    final boundsChanged =
        old.bounds.southwest != widget.bounds.southwest ||
        old.bounds.northeast != widget.bounds.northeast;
    if (routeChanged || boundsChanged) {
      navTrace(
        'map_didUpdate routeChanged=$routeChanged '
        'boundsChanged=$boundsChanged markers=1 polyline=${widget.route.length}',
      );
      // Both platforms fit after layout. On web this is the moment the route
      // geometry arrives (info panel already laid out), so the fit lands on a
      // settled size — clear of the resize race the old workaround avoided.
      _fitAfterLayout();
    }
  }

  @override
  Widget build(BuildContext context) {
    _buildCount++;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        navTrace(
          'map_build #$_buildCount '
          'size=${size.width.toStringAsFixed(0)}x${size.height.toStringAsFixed(0)} '
          'controller=${_controller?.hashCode} polyline=${widget.route.length}',
        );
        // Track every resize for lifecycle evidence. Refit on resize is NATIVE
        // ONLY: on web a camera move landing on the route-success shrink is the
        // exact tile-blanking race the old workaround hit, and the web camera is
        // already fitted on create and on every route-geometry change — the two
        // moments that actually matter — so an extra resize-driven web fit only
        // reintroduces the race for no framing benefit.
        if (_controller != null && _lastSize != null && size != _lastSize) {
          navTrace(
            'map_resize from=${_lastSize!.width.toStringAsFixed(0)}x'
            '${_lastSize!.height.toStringAsFixed(0)} to='
            '${size.width.toStringAsFixed(0)}x${size.height.toStringAsFixed(0)}',
          );
          if (!kIsWeb) _fitAfterLayout();
        }
        _lastSize = size;
        return GoogleMap(
          initialCameraPosition: _initialCamera(size),
          // Inset the Google logo/attribution AND the my-location button above
          // the bottom info/steps panel.
          padding: const EdgeInsets.only(bottom: 96),
          // The live blue "you are here" dot IS the current-location indicator —
          // it tracks the walker as they move (real GPS), so there is no separate
          // static origin marker (two "you" pins that drift apart is worse than
          // one live dot). The my-location button is the recenter control.
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          zoomControlsEnabled: false,
          markers: {
            // Destination only — a clear pin for where you're headed. "You" is
            // the blue dot above.
            Marker(
              markerId: const MarkerId('destination'),
              position: _ll(widget.destination),
            ),
          },
          polylines: {
            // A coloured, rounded walking line reads as a route, not a stray
            // black stroke (field report, Leo Alavi 2026-08-28: "it's just a black
            // line"). Omitted while the route is empty (loading/failed) so no
            // zero-point polyline is diffed onto the map.
            if (widget.route.isNotEmpty)
              Polyline(
                polylineId: const PolylineId('route'),
                width: 6,
                color: const Color(0xFF1A73E8), // Google-walking blue
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
                jointType: JointType.round,
                points: widget.route.map(_ll).toList(),
              ),
          },
          onMapCreated: (controller) {
            _controller = controller;
            navTrace('map_created controller=${controller.hashCode}');
            // First fit once the view has a size.
            _fitAfterLayout();
          },
        );
      },
    );
  }
}

/// An embedded Google map showing the walking route from [origin] to
/// [destination]. Pure `(double,double)` geographic tuples in; rendering is
/// delegated to [surface] (production Google map / test fake).
class EmbeddedMap extends StatelessWidget {
  const EmbeddedMap({
    super.key,
    required this.origin,
    required this.destination,
    required this.route,
    this.surface = const GoogleEmbeddedMapSurface(),
  });

  final (double lat, double lng) origin;
  final (double lat, double lng) destination;
  final List<(double lat, double lng)> route;
  final EmbeddedMapSurface surface;

  @override
  Widget build(BuildContext context) {
    final bounds = boundsFor(
      origin: origin,
      destination: destination,
      route: route,
    );
    return surface.build(
      bounds: bounds,
      origin: origin,
      destination: destination,
      route: route,
    );
  }
}
