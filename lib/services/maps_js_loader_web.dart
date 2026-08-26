import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:aon2026/services/nav_trace.dart';
import 'package:web/web.dart' as web;

/// The Maps JS libraries the plugin needs.
///
/// `marker` backs the origin/destination pins and `drawing` backs the route
/// polyline — `google_maps_flutter_web`'s README calls both out explicitly.
/// Requesting only the default bundle renders a map with no route on it.
const String _libraries = 'drawing,marker';

/// How long to wait before declaring the load dead.
///
/// Without this the readiness Future could stay pending forever — a blocked
/// script, a captive-portal redirect or an ad-blocker swallowing the request all
/// produce neither `load` nor `error` — and the UI span on a spinner with no way
/// out. A bounded wait turns a hang into a truthful failure the user can retry.
const Duration _loadTimeout = Duration(seconds: 12);

/// Cached SUCCESS only. A failed attempt is deliberately not cached, so Retry
/// can genuinely try again rather than replaying the old failure.
Future<bool>? _loading;

/// True once `window.google.maps` exists.
///
/// Uses the JS global directly: reading through `globalContext` avoids the
/// typed-`Window` extension methods, which are not guaranteed to expose
/// arbitrary properties across compilers.
bool _mapsReady() {
  try {
    final google = globalContext.getProperty('google'.toJS);
    if (google.isUndefinedOrNull) return false;
    return !(google! as JSObject).getProperty('maps'.toJS).isUndefinedOrNull;
  } catch (_) {
    return false;
  }
}

/// Injects the Google Maps JavaScript API and completes when it is usable.
///
/// Never throws: every failure resolves `false` so the caller can render a
/// truthful "map could not load" state instead of an unhandled error, and
/// never stays pending thanks to [_loadTimeout].
Future<bool> loadGoogleMapsJs(String apiKey) {
  if (apiKey.isEmpty) {
    mapsLoaderTrace('no key — not loading');
    return Future.value(false);
  }
  if (_mapsReady()) {
    mapsLoaderTrace('already loaded');
    return Future.value(true);
  }
  return _loading ??= _inject(apiKey);
}

Future<bool> _inject(String apiKey) async {
  final done = Completer<bool>();

  void finish(bool ok, String why) {
    if (done.isCompleted) return;
    mapsLoaderTrace('$why -> ready=$ok');
    // Only a SUCCESS stays cached; drop a failure so Retry re-attempts.
    if (!ok) _loading = null;
    done.complete(ok);
  }

  // Reuse a tag someone else already added (a hand-edited index.html) rather
  // than adding a second one — a duplicate triggers Google's "included multiple
  // times" warning and re-initialises the whole API.
  final existing = web.document
      .querySelector('script[src*="maps.googleapis.com/maps/api/js"]');
  if (existing == null) {
    final script =
        web.document.createElement('script') as web.HTMLScriptElement
          ..type = 'text/javascript'
          ..async = true
          ..defer = true
          // Uri, never string concatenation, so a stray character in the key
          // cannot break out of the query string.
          ..src = Uri.https('maps.googleapis.com', '/maps/api/js', {
            'key': apiKey,
            'libraries': _libraries,
          }).toString();

    script.onload = (JSAny _) {
      // `google.maps` is not always populated the instant `load` fires, so
      // confirm rather than assume; the poll below covers the gap.
      finish(_mapsReady(), 'script onload');
    }.toJS;
    script.onerror = (JSAny _, JSAny _, JSAny _, JSAny _, JSAny _) {
      finish(false, 'script onerror (blocked/offline/bad key)');
    }.toJS;

    web.document.head!.appendChild(script);
    mapsLoaderTrace('script injected');
  } else {
    mapsLoaderTrace('reusing existing script tag');
  }

  // Poll as the authority. It covers three cases the events miss: a tag added
  // by someone else (no handlers of ours), `google.maps` arriving slightly
  // after `load`, and a script that silently never fires either event.
  final poll = Timer.periodic(const Duration(milliseconds: 100), (t) {
    if (_mapsReady()) {
      t.cancel();
      finish(true, 'polled ready');
    }
  });

  final timeout = Timer(_loadTimeout, () {
    poll.cancel();
    finish(false, 'timed out after ${_loadTimeout.inSeconds}s');
  });

  final ok = await done.future;
  poll.cancel();
  timeout.cancel();
  return ok;
}

/// Drops the cached load so a test can exercise the first-load path again.
void resetGoogleMapsJsLoaderForTest() => _loading = null;
