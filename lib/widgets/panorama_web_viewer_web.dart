import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'package:aon2026/models/indoor_manifest.dart';

/// Monotonic id so every mounted viewer registers a unique platform-view type.
/// Two tours on screen at once (or a rebuild) must never collide on one iframe.
int _viewSeq = 0;

/// Web 360° viewer: the bundled Pannellum tour hosted in a same-origin
/// `<iframe>`, driven entirely by `postMessage`. See `panorama_web_viewer.dart`
/// for why the web path differs from native.
Widget buildPanoramaWebViewer({
  required IndoorManifest manifest,
  required String? sceneId,
  required ValueChanged<String> onSceneChanged,
  required bool reduceMotion,
}) => _PanoramaIframeView(
  manifest: manifest,
  sceneId: sceneId,
  onSceneChanged: onSceneChanged,
  reduceMotion: reduceMotion,
);

class _PanoramaIframeView extends StatefulWidget {
  const _PanoramaIframeView({
    required this.manifest,
    required this.sceneId,
    required this.onSceneChanged,
    required this.reduceMotion,
  });

  final IndoorManifest manifest;
  final String? sceneId;
  final ValueChanged<String> onSceneChanged;
  final bool reduceMotion;

  @override
  State<_PanoramaIframeView> createState() => _PanoramaIframeViewState();
}

class _PanoramaIframeViewState extends State<_PanoramaIframeView> {
  late final String _viewType;
  late final web.HTMLIFrameElement _iframe;
  late final JSFunction _onMessageJs;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'aon-panorama-${_viewSeq++}';

    // The tour is the SAME bundled viewer native uses. Flutter serves declared
    // assets under `assets/`, and this asset's own key already starts with
    // `assets/`, hence the doubled segment. The path is relative, so it resolves
    // against the app's <base href> — correct whether the app is hosted at the
    // domain root or under /astronomy-open-night/.
    _iframe = web.HTMLIFrameElement()
      ..src = 'assets/assets/web/indoor_viewer.html'
      ..allow = 'fullscreen'
      // Sandboxed to the minimum the viewer needs: run its own scripts and be
      // treated as its own (same) origin so its relative asset loads resolve.
      // No forms, no top-navigation, no popups.
      ..setAttribute('sandbox', 'allow-scripts allow-same-origin')
      ..setAttribute('title', '360° venue tour')
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.display = 'block';

    ui_web.platformViewRegistry
        .registerViewFactory(_viewType, (int _) => _iframe);

    // The iframe reports 'ready' when its listener is armed; we also post on the
    // element's own load event, so whichever settles second still delivers the
    // tour. Both funnel through _postLoadTour, which is idempotent.
    _onMessageJs = _onMessage.toJS;
    web.window.addEventListener('message', _onMessageJs);
    _iframe.addEventListener('load', ((web.Event _) => _postLoadTour()).toJS);
  }

  void _onMessage(web.Event event) {
    final message = event as web.MessageEvent;
    // Same-origin, and specifically from OUR iframe — ignore every other frame.
    if (message.source != _iframe.contentWindow) return;
    if (message.origin != web.window.location.origin) return;
    final data = message.data?.dartify();
    if (data is! Map) return;
    if (data['source'] != 'aon-panorama') return;
    switch (data['type']) {
      case 'ready':
        _ready = true;
        _postLoadTour();
      case 'sceneChanged':
        final id = data['sceneId'];
        if (id is String) widget.onSceneChanged(id);
    }
  }

  void _postLoadTour() {
    final config = widget.manifest.buildPannellumConfig(
      // From the iframe document at assets/assets/web/, the panorama images live
      // one directory up in assets/assets/data/indoor/. `../data` + the node's
      // own `indoor/<file>.jpg` resolves there, same-origin.
      assetBaseUrl: '../data',
      firstSceneId: widget.sceneId,
      reduceMotion: widget.reduceMotion,
    );
    _post(<String, Object?>{
      'source': 'aon-host',
      'type': 'loadTour',
      'config': config,
    });
  }

  void _post(Map<String, Object?> message) {
    final target = _iframe.contentWindow;
    if (target == null) return;
    target.postMessage(message.jsify(), web.window.location.origin.toJS);
  }

  @override
  void didUpdateWidget(covariant _PanoramaIframeView old) {
    super.didUpdateWidget(old);
    // Rail tap → tell the running viewer to switch scene. Before it is ready the
    // scene is delivered as the tour's firstScene instead, so nothing is lost.
    final scene = widget.sceneId;
    if (_ready && scene != null && scene != old.sceneId) {
      _post(<String, Object?>{
        'source': 'aon-host',
        'type': 'selectScene',
        'sceneId': scene,
      });
    }
  }

  @override
  void dispose() {
    web.window.removeEventListener('message', _onMessageJs);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}
