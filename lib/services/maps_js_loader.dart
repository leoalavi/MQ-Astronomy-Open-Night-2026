/// Loads the Google Maps JavaScript API at RUNTIME, with the key resolved from
/// config rather than baked into `web/index.html`.
///
/// ## Why this exists
///
/// `google_maps_flutter_web` does not ship a loader: it assumes
/// `https://maps.googleapis.com/maps/api/js?key=…` is already on the page, which
/// the package README tells you to paste into `web/index.html`. We cannot do
/// that — `index.html` is committed, and the key is a secret. So the app injects
/// the script itself, once, using the same `MAPS_API_KEY` every other platform
/// resolves.
///
/// The conditional export keeps `dart:js_interop` out of the mobile builds:
/// non-web targets get the stub, which reports "not applicable" so the native
/// MethodChannel path stays in charge there.
library;

export 'maps_js_loader_stub.dart'
    if (dart.library.js_interop) 'maps_js_loader_web.dart';
