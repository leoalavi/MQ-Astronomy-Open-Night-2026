import 'dart:math' as math;

import 'package:flutter/foundation.dart';
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

/// Computes the browser's *initial* camera from origin/destination bounds.
///
/// This is intentionally used only in [GoogleMap.initialCameraPosition]. A
/// live camera mutation during the route-result/platform-view resize is what
/// blanks Google Maps' web tile pane in the affected renderer.
({(double lat, double lng) center, double zoom}) webInitialCameraForBounds(
  GeoBounds bounds,
  Size viewport, {
  double padding = 48,
}) {
  final center = (
    (bounds.southwest.$1 + bounds.northeast.$1) / 2,
    (bounds.southwest.$2 + bounds.northeast.$2) / 2,
  );
  final width = math.max(1.0, viewport.width - padding * 2);
  final height = math.max(1.0, viewport.height - padding * 2 - 96);
  final lngSpan = math.max(1e-9, bounds.northeast.$2 - bounds.southwest.$2);

  double mercatorY(double latitude) {
    final lat = latitude.clamp(-85.05112878, 85.05112878) * math.pi / 180;
    return math.log(math.tan(math.pi / 4 + lat / 2)) / (2 * math.pi);
  }

  final latSpan = math.max(
    1e-9,
    (mercatorY(bounds.northeast.$1) - mercatorY(bounds.southwest.$1)).abs(),
  );
  final lngZoom = math.log(width * 360 / (256 * lngSpan)) / math.ln2;
  final latZoom = math.log(height / (256 * latSpan)) / math.ln2;
  return (center: center, zoom: math.min(lngZoom, latZoom).clamp(15.0, 18.0));
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
  }) => _RouteMapView(bounds: bounds, destination: destination, route: route);
}

/// The real Google map, kept alive across the route-state transition
/// (`loading → RouteApiSuccess`) and container resizes.
///
/// On web the route-success rebuild shrinks the slotted platform view while
/// `google_maps_flutter_web` is applying a camera update. In Chrome that leaves
/// the map and its tile nodes mounted but clears their painted tiles. Both
/// `newLatLngBounds` and `newLatLngZoom` reproduce it. The stable web behavior
/// is therefore to keep the initial origin/destination-framed camera and update only
/// the marker/polyline overlays. Native maps retain automatic bounds fitting.
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

  CameraPosition _initialCamera(Size size) {
    if (!kIsWeb) {
      return CameraPosition(target: _ll(widget.destination), zoom: 15);
    }
    final camera = webInitialCameraForBounds(widget.bounds, size);
    navTrace(
      'map_web_initial_camera '
      'target=(${camera.center.$1.toStringAsFixed(5)},'
      '${camera.center.$2.toStringAsFixed(5)}) '
      'zoom=${camera.zoom.toStringAsFixed(2)}',
    );
    return CameraPosition(target: _ll(camera.center), zoom: camera.zoom);
  }

  /// Fit native cameras to the route. Web deliberately keeps the initial
  /// origin/destination-framed camera; see the class-level regression note.
  Future<void> _fit() async {
    final c = _controller;
    if (c == null) return;
    if (kIsWeb) {
      navTrace('map_fit_skipped_web polyline=${widget.route.length}');
      return;
    }
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
    final routeChanged = old.route.length != widget.route.length;
    final boundsChanged =
        old.bounds.southwest != widget.bounds.southwest ||
        old.bounds.northeast != widget.bounds.northeast;
    if (routeChanged || boundsChanged) {
      navTrace(
        'map_didUpdate routeChanged=$routeChanged '
        'boundsChanged=$boundsChanged markers=1 polyline=${widget.route.length}',
      );
      // Native fits after layout. Web logs but skips the camera mutation.
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
        // Track every resize for lifecycle evidence and refit native cameras.
        if (_controller != null && _lastSize != null && size != _lastSize) {
          navTrace(
            'map_resize from=${_lastSize!.width.toStringAsFixed(0)}x'
            '${_lastSize!.height.toStringAsFixed(0)} to='
            '${size.width.toStringAsFixed(0)}x${size.height.toStringAsFixed(0)}',
          );
          _fitAfterLayout();
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
