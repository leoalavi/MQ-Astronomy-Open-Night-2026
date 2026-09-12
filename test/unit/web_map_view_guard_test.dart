import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The web Directions map is an isolated same-origin `<iframe>`
/// (`web/maps/directions_map.html`) with its own google.maps runtime, driven by
/// postMessage — after in-document approaches (plugin, HtmlElementView overlay,
/// body overlay) all failed in production to Flutter's platform-view resize /
/// aria-hidden lifecycle. These source guards keep that architecture, and the
/// handshake/polyline/fitBounds that make it work, from regressing. The runtime
/// itself is verified in a browser, which unit tests do not have.
void main() {
  final host = File('lib/widgets/web_map_view.dart').readAsStringSync();
  final page = File('web/maps/directions_map.html').readAsStringSync();
  final surface = File('lib/widgets/embedded_map.dart').readAsStringSync();

  group('web map runs in an isolated iframe (its own document)', () {
    test('host builds an iframe pointing at the directions page', () {
      expect(host.contains('HTMLIFrameElement'), isTrue);
      expect(host.contains('maps/directions_map.html'), isTrue);
    });
    test('the directions page exists and is a real Maps runtime', () {
      expect(page.contains('google.maps.Map('), isTrue);
      expect(page.contains('loading=async'), isTrue);
    });
    test('no in-document map surface remains (plugin / overlay / camera hacks)', () {
      // Import/usage syntax, so the history note in the doc comment is not a hit.
      expect(host.contains("import 'package:google_maps_flutter"), isFalse);
      expect(host.contains('.moveCamera('), isFalse);
      expect(host.contains('aon-web-directions-map-host'), isFalse); // old body overlay
      // The camera fit happens INSIDE the iframe, never in Dart.
      expect(host.contains('fitBounds('), isFalse);
    });
  });

  group('postMessage handshake gates route on map_ready', () {
    test('host waits for map_ready before sending geometry', () {
      expect(host.contains("case 'map_ready'"), isTrue);
      expect(host.contains("'type': 'setRoute'"), isTrue);
      // _sendRoute is guarded so nothing is pushed before the map is ready.
      expect(host.contains('if (!_mapReady) return;'), isTrue);
    });
    test('frame announces iframe_ready then map_ready', () {
      expect(page.contains("type: 'iframe_ready'"), isTrue);
      expect(page.contains("type: 'map_ready'"), isTrue);
    });
    test('the key is sent by message, never placed in the iframe URL', () {
      expect(host.contains("'type': 'init'"), isTrue);
      // The iframe src is the clean page path with no query/key.
      expect(host.contains("..src = 'maps/directions_map.html'"), isTrue);
      expect(host.contains('?key='), isFalse);
    });
  });

  group('the blue route + camera are created with the native Maps JS API', () {
    test('a google.maps.Polyline is created with the walking-blue style', () {
      expect(page.contains('new google.maps.Polyline('), isTrue);
      expect(page.contains('#1A73E8'), isTrue);
      expect(page.contains('strokeWeight: 6'), isTrue);
    });
    test('camera fits a LatLngBounds over origin + destination + route', () {
      expect(page.contains('new google.maps.LatLngBounds('), isTrue);
      expect(page.contains('map.fitBounds('), isTrue);
    });
    test('resize refits only on a real size change (no frame loop)', () {
      expect(page.contains('ResizeObserver'), isTrue);
      expect(page.contains('w === lastW && h === lastH'), isTrue);
    });
  });

  group('web is wired to the adapter, native to the plugin (unchanged)', () {
    test('GoogleEmbeddedMapSurface routes web to buildWebRouteMap', () {
      expect(surface.contains('kIsWeb'), isTrue);
      expect(surface.contains('buildWebRouteMap'), isTrue);
    });
    test('native still builds the plugin _RouteMapView', () {
      expect(surface.contains('_RouteMapView('), isTrue);
    });
    test('the plugin surface no longer moves the web camera', () {
      expect(surface.contains('newCameraPosition'), isFalse);
    });
  });
}
