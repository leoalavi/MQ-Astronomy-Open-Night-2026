import 'package:flutter/material.dart';

import 'package:aon2026/models/indoor_manifest.dart';

/// The web-only 360° viewer, resolved by a conditional import so the mobile
/// build never pulls in `dart:ui_web` / `package:web`.
///
/// ## Why a separate viewer exists on web
///
/// Native (iOS/Android) renders the Pannellum tour through `PanoramaWebView`,
/// which serves the bundled viewer from a local `InAppLocalhostServer` and
/// drives it with `flutter_inappwebview`. Neither exists on web: there is no
/// local file server, and `flutter_inappwebview_web` would need CSP
/// `unsafe-eval` to inject the tour. So on web the tour is hosted in a plain
/// same-origin `<iframe>` pointing at the *same* bundled
/// `assets/web/indoor_viewer.html`, and the config is handed in with
/// `postMessage` — no eval, no server, no extra dependency.
///
/// The stub below is what the mobile build links against; it is never rendered
/// there (the caller gates on `kIsWeb`), but it keeps the seam type-correct.
export 'panorama_web_viewer_stub.dart'
    if (dart.library.js_interop) 'panorama_web_viewer_web.dart';

/// Signature both implementations satisfy.
typedef PanoramaWebViewerBuilder = Widget Function({
  required IndoorManifest manifest,
  required String? sceneId,
  required ValueChanged<String> onSceneChanged,
  required bool reduceMotion,
});
