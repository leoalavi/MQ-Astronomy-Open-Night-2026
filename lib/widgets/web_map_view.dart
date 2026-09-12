// The WEB Directions map: an isolated same-origin `<iframe>` (web/maps/
// directions_map.html) that owns its own google.maps runtime, driven entirely
// by postMessage. This mirrors the app's proven panorama viewer
// (panorama_web_viewer_web.dart).
//
// Why an iframe, after three in-document attempts failed in production:
//   * `google_maps_flutter_web` blanked tiles on camera move and never painted
//     the polyline;
//   * a `google.maps` node inside an `HtmlElementView`, and then a body-level
//     overlay, both still hit Flutter's platform-view resize / `aria-hidden`
//     lifecycle and google.maps fitting mid-resize → a world-zoom stale strip.
//   * An iframe runs google.maps in a SEPARATE document. Flutter only sees an
//     opaque frame element; the map, its tiles, its polyline and its camera are
//     out of reach of Flutter's DOM. The frame handles its own sizing
//     (ResizeObserver) and framing (`fitBounds`), and Flutter never sends route
//     geometry until the frame reports `map_ready`, so there is no init race.
//
// Native (iOS/Android) is untouched and still uses `google_maps_flutter`.
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'package:aon2026/services/nav_trace.dart';
import 'package:aon2026/widgets/embedded_map.dart';

/// The referrer-restricted browser Maps key (build-time define, same source the
/// rest of the app uses). Sent to the frame over postMessage — never placed in
/// the iframe URL, and it is already public in the shipped JS bundle regardless.
const String _mapsKey = String.fromEnvironment('MAPS_API_KEY');

const String _hostTag = 'aon-host';
const String _frameTag = 'aon-directions';

/// Monotonic id so each mounted map registers a unique platform-view type — two
/// Directions screens (or a rebuild) must never collide on one iframe.
int _viewSeq = 0;

/// The web build of [GoogleEmbeddedMapSurface.build]. Native never calls this.
Widget buildWebRouteMap({
  required GeoBounds bounds,
  required (double lat, double lng) origin,
  required (double lat, double lng) destination,
  required List<(double lat, double lng)> route,
}) => _WebDirectionsIframe(
  origin: origin,
  destination: destination,
  route: route,
);

class _WebDirectionsIframe extends StatefulWidget {
  const _WebDirectionsIframe({
    required this.origin,
    required this.destination,
    required this.route,
  });

  final (double lat, double lng) origin;
  final (double lat, double lng) destination;
  final List<(double lat, double lng)> route;

  @override
  State<_WebDirectionsIframe> createState() => _WebDirectionsIframeState();
}

class _WebDirectionsIframeState extends State<_WebDirectionsIframe> {
  late final String _viewType;
  late final web.HTMLIFrameElement _iframe;
  late final JSFunction _onMessageJs;
  bool _initSent = false;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'aon-directions-${_viewSeq++}';
    _iframe = web.HTMLIFrameElement()
      // Relative, so it resolves against the app's <base href> whether hosted at
      // the domain root or a sub-path.
      ..src = 'maps/directions_map.html'
      ..allow = 'fullscreen'
      // Its own scripts + same origin (for the Maps JS it injects and its
      // storage); no forms, popups or top-navigation.
      ..setAttribute('sandbox', 'allow-scripts allow-same-origin')
      ..setAttribute('title', 'Walking directions map')
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.display = 'block';

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) => _iframe);

    _onMessageJs = _onMessage.toJS;
    web.window.addEventListener('message', _onMessageJs);
    // Belt-and-suspenders with the frame's own `iframe_ready`: the inline script
    // (and its listener) runs during parse, before this load event, so an init
    // sent here cannot be missed. `_initSent` dedupes the two triggers.
    _iframe.addEventListener('load', ((web.Event _) => _sendInit()).toJS);
  }

  void _onMessage(web.Event event) {
    final message = event as web.MessageEvent;
    if (message.source != _iframe.contentWindow) return; // only OUR frame
    if (message.origin != web.window.location.origin) return; // same-origin
    final data = message.data?.dartify();
    if (data is! Map) return;
    if (data['source'] != _frameTag) return;
    switch (data['type']) {
      case 'iframe_ready':
        navTrace('WebMapFrame iframe_ready');
        _sendInit();
      case 'map_ready':
        navTrace('WebMapFrame map_ready');
        _mapReady = true;
        _sendRoute();
      case 'route_applied':
        navTrace('WebMapFrame route_applied points=${data['points']}');
    }
  }

  void _sendInit() {
    if (_initSent) return;
    _initSent = true;
    _post(<String, Object?>{
      'source': _hostTag,
      'type': 'init',
      'key': _mapsKey,
    });
  }

  /// Only ever sent after `map_ready`, so the frame is fully initialised and
  /// correctly sized before it fits the route — no init/size race.
  void _sendRoute() {
    if (!_mapReady) return;
    _post(<String, Object?>{
      'source': _hostTag,
      'type': 'setRoute',
      'origin': <String, Object?>{'lat': widget.origin.$1, 'lng': widget.origin.$2},
      'destination': <String, Object?>{
        'lat': widget.destination.$1,
        'lng': widget.destination.$2,
      },
      'polyline': <Map<String, Object?>>[
        for (final p in widget.route) <String, Object?>{'lat': p.$1, 'lng': p.$2},
      ],
    });
  }

  void _post(Map<String, Object?> message) {
    final target = _iframe.contentWindow;
    if (target == null) return;
    target.postMessage(message.jsify(), web.window.location.origin.toJS);
  }

  @override
  void didUpdateWidget(covariant _WebDirectionsIframe old) {
    super.didUpdateWidget(old);
    // A new destination / a route that arrived / a replaced route → push it.
    // Geometry, not length, so a same-length new route still refreshes.
    final changed =
        routeGeometryChanged(old.route, widget.route) ||
        old.destination != widget.destination ||
        old.origin != widget.origin;
    if (changed) _sendRoute();
  }

  @override
  void dispose() {
    web.window.removeEventListener('message', _onMessageJs);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}
