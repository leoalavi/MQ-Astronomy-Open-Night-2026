import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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
  }) {
    LatLng ll((double, double) p) => LatLng(p.$1, p.$2);
    final gBounds = LatLngBounds(southwest: ll(bounds.southwest), northeast: ll(bounds.northeast));
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: ll(destination), zoom: 15),
      // Inset the Google logo/attribution above a bottom info panel.
      padding: const EdgeInsets.only(bottom: 96),
      myLocationEnabled: false,
      zoomControlsEnabled: false,
      markers: {
        Marker(markerId: const MarkerId('origin'), position: ll(origin)),
        Marker(markerId: const MarkerId('destination'), position: ll(destination)),
      },
      polylines: {
        Polyline(polylineId: const PolylineId('route'), width: 5, points: route.map(ll).toList()),
      },
      onMapCreated: (controller) {
        controller.animateCamera(CameraUpdate.newLatLngBounds(gBounds, 48));
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
