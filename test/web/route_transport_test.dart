@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;
import 'package:aon2026/services/polyline_codec.dart';
import 'package:aon2026/services/web_route_payload.dart';
import '../unit/web_route_payload_test.dart'
    show courtyardRoute, courtyardPoints;

void main() {
  test(
    'compiled Dart -> jsify -> actual iframe postMessage preserves six points',
    () async {
      final frame = web.HTMLIFrameElement()
        ..srcdoc =
            '''
      <script>window.addEventListener('message', e => {
        parent.postMessage({source:'geometry-test', points:e.data.polyline}, e.origin);
      });</script>'''
                .toJS;
      final loaded = Completer<void>();
      frame.addEventListener(
        'load',
        ((web.Event _) {
          loaded.complete();
        }).toJS,
      );
      final received = Completer<Object?>();
      final listener = ((web.MessageEvent e) {
        if (e.source != frame.contentWindow) return;
        final data = e.data.dartify();
        if (data is Map && data['source'] == 'geometry-test') {
          received.complete(data['points']);
        }
      }).toJS;
      web.window.addEventListener('message', listener);
      web.document.body!.appendChild(frame);
      addTearDown(() {
        web.window.removeEventListener('message', listener);
        frame.remove();
      });
      await loaded.future;
      final decoded = decodePolyline(courtyardRoute);
      expect(
        decoded,
        courtyardPoints,
      ); // Fails on the old unsigned web decoder.
      final payload = webRoutePayload(
        origin: (-33.7737, 151.1134),
        destination: (-33.7746267, 151.1151193),
        route: decoded,
      );
      final wire = payload.jsify();
      final sent = (wire.dartify() as Map)['polyline'];
      expect(sent, payload['polyline']);
      frame.contentWindow!.postMessage(wire, web.window.location.origin.toJS);
      final echoed = await received.future.timeout(const Duration(seconds: 10));
      expect(echoed, sent);
    },
  );
}
