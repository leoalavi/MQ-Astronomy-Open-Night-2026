import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// The Maps JS libraries the plugin needs.
///
/// `marker` backs the destination/origin pins and `drawing` backs the route
/// polyline — `google_maps_flutter_web`'s README calls both out explicitly.
/// Requesting only the default bundle renders a map with no route on it.
const String _libraries = 'drawing,marker';

/// Cached so a second Directions visit reuses the already-loaded SDK instead of
/// appending another `<script>` (Google logs a "included multiple times"
/// warning and re-initialises the whole API). Survives navigating away and back,
/// which is exactly the repeat-visit case.
Future<bool>? _loading;

/// True once `window.google.maps` exists — i.e. someone (us, or a hand-added
/// tag in index.html) has already loaded the API.
bool _alreadyLoaded() {
  final google = web.window.getProperty('google'.toJS);
  if (google.isUndefinedOrNull) return false;
  return !(google as JSObject).getProperty('maps'.toJS).isUndefinedOrNull;
}

/// Injects the Google Maps JavaScript API and completes when it is usable.
///
/// Returns false rather than throwing on any failure (bad key, offline, blocked
/// by an extension) so the caller can render a truthful "map could not load"
/// state instead of an unhandled error.
Future<bool> loadGoogleMapsJs(String apiKey) {
  if (apiKey.isEmpty) return Future.value(false);
  if (_alreadyLoaded()) return Future.value(true);
  return _loading ??= _inject(apiKey);
}

Future<bool> _inject(String apiKey) {
  final done = Completer<bool>();
  final script = web.document.createElement('script') as web.HTMLScriptElement
    ..type = 'text/javascript'
    ..async = true
    ..defer = true
    // Uri, never string concatenation, so a stray character in the key cannot
    // break out of the query string.
    ..src = Uri.https('maps.googleapis.com', '/maps/api/js', {
      'key': apiKey,
      'libraries': _libraries,
    }).toString();

  script.onload = (JSAny _) {
    if (!done.isCompleted) done.complete(_alreadyLoaded());
  }.toJS;

  // window.onerror signature: (message, source, lineno, colno, error).
  script.onerror = (JSAny _, JSAny _, JSAny _, JSAny _, JSAny _) {
    // A rejected key or a network failure. Clear the cache so a later retry can
    // try again rather than being stuck on this failed attempt forever.
    _loading = null;
    if (!done.isCompleted) done.complete(false);
  }.toJS;

  web.document.head!.appendChild(script);
  return done.future;
}

/// Drops the cached load so a test can exercise the first-load path again.
void resetGoogleMapsJsLoaderForTest() => _loading = null;
