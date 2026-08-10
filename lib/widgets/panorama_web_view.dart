import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/models/indoor_manifest.dart';
import 'package:aon2026/models/viewer_url_policy.dart';
import 'package:aon2026/models/webview_bridge.dart';
import 'package:aon2026/services/panorama_server.dart';

/// A graceful "360° preview unavailable" state — shown on web, on server/webview
/// failure, and while the server starts.
class PanoramaUnavailable extends StatelessWidget {
  const PanoramaUnavailable({super.key, this.loading = false});
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AonSpacing.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.panorama_photosphere_outlined,
                size: AonSpacing.iconLg, color: context.aon.contentTertiary),
            const SizedBox(height: AonSpacing.space3),
            Text(
              '360° preview unavailable',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: context.aon.contentSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hosts the Pannellum panorama in an [InAppWebView] served from the local
/// [panoramaServer]. The trust boundary is delegated to the tested pure helpers
/// (`isAllowedViewerUrl`, `buildLoadTourJs`/`buildSelectSceneJs`,
/// `validatedInboundScene`). Web is explicitly unavailable — no server/webview.
class PanoramaWebView extends StatefulWidget {
  const PanoramaWebView({
    super.key,
    required this.manifest,
    this.firstSceneId,
    this.sceneId,
    this.onSceneChanged,
    this.ensureServer,
  });

  final IndoorManifest manifest;
  final String? firstSceneId;

  /// Scene the existing viewer should switch to after initial load.
  final String? sceneId;

  /// Reports scene changes from inside Pannellum (validated hotspot taps).
  final ValueChanged<String>? onSceneChanged;

  /// Injectable server-start seam (defaults to the shared server). Lets tests
  /// drive the real failure path without a platform webview.
  final Future<void> Function()? ensureServer;

  @override
  State<PanoramaWebView> createState() => _PanoramaWebViewState();
}

class _PanoramaWebViewState extends State<PanoramaWebView> {
  bool _serverReady = false;
  bool _serverFailed = false;
  InAppWebViewController? _controller;
  String? _currentSceneId;
  bool _tourLoaded = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return; // web is unavailable — never start a server/webview
    _startServer();
  }

  Future<void> _startServer() async {
    try {
      await (widget.ensureServer ?? panoramaServer.ensureStarted)();
      if (mounted) setState(() => _serverReady = true);
    } catch (_) {
      if (mounted) setState(() => _serverFailed = true);
    }
  }

  @override
  void didUpdateWidget(covariant PanoramaWebView old) {
    super.didUpdateWidget(old);
    if (widget.sceneId != old.sceneId) _loadScene(widget.sceneId);
  }

  Future<void> _loadScene(String? sceneId) async {
    final c = _controller;
    if (!_tourLoaded ||
        c == null ||
        sceneId == null ||
        sceneId == _currentSceneId ||
        !widget.manifest.nodes.any((n) => n.id == sceneId)) {
      return;
    }
    _currentSceneId = sceneId;
    await c.evaluateJavascript(source: buildSelectSceneJs(sceneId));
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || _serverFailed) return const PanoramaUnavailable();
    if (!_serverReady) return const PanoramaUnavailable(loading: true);

    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return InAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri('${panoramaServer.baseUrl}/web/indoor_viewer.html'),
      ),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        transparentBackground: true,
        mediaPlaybackRequiresUserGesture: true,
        useShouldOverrideUrlLoading: true,
        iframeAllow: 'fullscreen',
      ),
      shouldOverrideUrlLoading: (controller, action) async =>
          isAllowedViewerUrl(action.request.url)
              ? NavigationActionPolicy.ALLOW
              : NavigationActionPolicy.CANCEL,
      onWebViewCreated: (controller) {
        _controller = controller;
        final known = widget.manifest.nodes.map((n) => n.id).toSet();
        controller.addJavaScriptHandler(
          handlerName: 'indoorSceneChanged',
          callback: (args) {
            final id = validatedInboundScene(
                args.isEmpty ? null : args.first, known);
            if (id != null) {
              _currentSceneId = id;
              widget.onSceneChanged?.call(id);
            }
            return null;
          },
        );
      },
      onLoadStop: (controller, _) async {
        final config = widget.manifest.buildPannellumConfig(
          assetBaseUrl: '${panoramaServer.baseUrl}/data',
          firstSceneId: widget.firstSceneId,
          reduceMotion: reduceMotion,
        );
        await controller.evaluateJavascript(source: buildLoadTourJs(config));
        _tourLoaded = true;
        _currentSceneId = widget.sceneId ?? widget.firstSceneId;
        await _loadScene(widget.sceneId);
      },
    );
  }
}
