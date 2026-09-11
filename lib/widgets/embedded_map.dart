import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:aon2026/services/nav_trace.dart';

/// A geographic bounding box in plain tuples — deliberately NOT
/// `google_maps_flutter`'s `LatLngBounds`, so the bounds math is unit-testable
/// without touching the plugin.
class GeoBounds {
  final (double lat, double lng) southwest;
  final (double lat, double lng) northeast;
  const GeoBounds(this.southwest, this.northeast);
}

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

/// The production surface: a `GoogleMap` with origin+destination markers, the
/// route polyline, and a camera that fits [bounds] once the map is created.
class GoogleEmbeddedMapSurface implements EmbeddedMapSurface {
  const GoogleEmbeddedMapSurface();

  @override
  Widget build({
    required GeoBounds bounds,
    required (double lat, double lng) origin,
    required (double lat, double lng) destination,
    required List<(double lat, double lng)> route,
  }) =>
      _RouteMapView(bounds: bounds, destination: destination, route: route);
}

/// The real Google map, kept ALIVE and CORRECT across the route-state
/// transition (`loading → RouteApiSuccess`) and across container resizes.
///
/// ## The regression this fixes
///
/// The map is one child of a `Column`; its sibling grows from a one-line
/// "finding route" strip to the full distance + steps panel when the route
/// arrives. That shrinks the map's `Expanded`, so the **web** platform view is
/// resized. `google_maps_flutter_web` leaves the tile layer BLANK/GREY after a
/// container resize until the camera is moved — and the original code fit the
/// camera only once, inside `onMapCreated`, so nothing ever nudged it again.
/// Result: the map showed correctly during loading, then went grey on success
/// (Google logo/controls/attribution stayed, because only the tile layer died).
///
/// The map element is NOT remounted here (no keys change, same position in the
/// tree), so the controller and JS map instance persist. The fix is to hold
/// that controller and re-fit the camera after:
///   1. creation (initial fit),
///   2. a route/bounds change (fits the polyline AND repaints the tiles), and
///   3. any container resize (route panel appears, browser width changes).
/// Re-fitting is the documented cure for the web resize-to-grey: a camera move
/// forces the tile layer to re-render at the current size.
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

  /// Re-fit the camera to the current bounds. This is the load-bearing repaint:
  /// on web a camera move forces the tile layer to re-render, so it doubles as
  /// the cure for the resize-to-grey. `animate` on route arrival (a nicety),
  /// straight `moveCamera` on a bare resize (no gratuitous motion).
  Future<void> _fit({required bool animate}) async {
    final c = _controller;
    if (c == null) return;
    final sw = widget.bounds.southwest, ne = widget.bounds.northeast;
    navTrace('map_fit animate=$animate '
        'sw=(${sw.$1.toStringAsFixed(5)},${sw.$2.toStringAsFixed(5)}) '
        'ne=(${ne.$1.toStringAsFixed(5)},${ne.$2.toStringAsFixed(5)}) '
        'polyline=${widget.route.length}');
    try {
      final update = CameraUpdate.newLatLngBounds(_gBounds, 48);
      if (animate) {
        await c.animateCamera(update);
      } else {
        await c.moveCamera(update);
      }
    } catch (e) {
      // Invalid/degenerate bounds or a not-yet-laid-out map must never throw out
      // of a frame callback and take the screen down (#9/#10). The map stays;
      // the next transition re-fits.
      navTrace('map_fit_threw (${e.runtimeType})');
    }
  }

  void _fitAfterFrame({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fit(animate: animate);
    });
  }

  @override
  void didUpdateWidget(covariant _RouteMapView old) {
    super.didUpdateWidget(old);
    final routeChanged = old.route.length != widget.route.length;
    final boundsChanged = old.bounds.southwest != widget.bounds.southwest ||
        old.bounds.northeast != widget.bounds.northeast;
    if (routeChanged || boundsChanged) {
      navTrace('map_didUpdate routeChanged=$routeChanged '
          'boundsChanged=$boundsChanged markers=1 polyline=${widget.route.length}');
      // After the frame, so the platform view has finished resizing to the new
      // (smaller) height the success panel forces — THEN re-fit/repaint.
      _fitAfterFrame(animate: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    _buildCount++;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        navTrace('map_build #$_buildCount '
            'size=${size.width.toStringAsFixed(0)}x${size.height.toStringAsFixed(0)} '
            'controller=${_controller?.hashCode} polyline=${widget.route.length}');
        // A resize that is NOT already covered by a bounds/route change (e.g. the
        // browser width changed, or the panel appeared without changing bounds):
        // re-fit after this frame so the web tiles repaint at the new size.
        if (_controller != null && _lastSize != null && size != _lastSize) {
          navTrace('map_resize from=${_lastSize!.width.toStringAsFixed(0)}x'
              '${_lastSize!.height.toStringAsFixed(0)} to='
              '${size.width.toStringAsFixed(0)}x${size.height.toStringAsFixed(0)}');
          _fitAfterFrame(animate: false);
        }
        _lastSize = size;
        return GoogleMap(
          initialCameraPosition:
              CameraPosition(target: _ll(widget.destination), zoom: 15),
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
                position: _ll(widget.destination)),
          },
          polylines: {
            // A coloured, rounded walking line reads as a route, not a stray
            // black stroke (field report, Pouya 2026-08-28: "it's just a black
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
            _fitAfterFrame(animate: true);
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
    final bounds = boundsFor(origin: origin, destination: destination, route: route);
    return surface.build(bounds: bounds, origin: origin, destination: destination, route: route);
  }
}
