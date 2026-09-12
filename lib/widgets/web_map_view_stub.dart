// Non-web stub for [buildWebRouteMap]. The web adapter (web_map_view.dart) pulls
// in dart:js_interop and dart:ui_web, which must not reach mobile or the VM test
// host. `GoogleEmbeddedMapSurface.build` only calls this on `kIsWeb`, so on any
// non-web target it is unreachable — it exists purely so the conditional import
// resolves and the file compiles everywhere.
import 'package:flutter/widgets.dart';

import 'package:aon2026/widgets/embedded_map.dart';

Widget buildWebRouteMap({
  required GeoBounds bounds,
  required (double lat, double lng) origin,
  required (double lat, double lng) destination,
  required List<(double lat, double lng)> route,
}) => throw UnsupportedError('buildWebRouteMap is web-only');
