import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/models/indoor_manifest.dart';
import 'package:aon2026/widgets/glass_surface.dart';
import 'package:aon2026/widgets/panorama_scene_rail.dart';
import 'package:aon2026/widgets/panorama_web_view.dart';
import 'package:aon2026/widgets/panorama_web_viewer.dart';

/// Builds the panorama viewer. Injectable so the scene-state orchestration can
/// be tested without a real platform WebView (default = [PanoramaWebView]).
typedef PanoramaViewerBuilder = Widget Function({
  required IndoorManifest manifest,
  required String? sceneId,
  required ValueChanged<String> onSceneChanged,
});

Widget _defaultViewerBuilder({
  required IndoorManifest manifest,
  required String? sceneId,
  required ValueChanged<String> onSceneChanged,
}) {
  // Web hosts the same bundled Pannellum tour in a same-origin iframe (no local
  // server, no flutter_inappwebview). Native keeps the server-backed webview.
  // The `reduceMotion` flag can only be read from a BuildContext, so it is
  // resolved inside the web viewer's own build via the ambient MediaQuery there;
  // here we pass what both paths share.
  if (kIsWeb) {
    return Builder(
      builder: (context) => buildPanoramaWebViewer(
        manifest: manifest,
        sceneId: sceneId,
        onSceneChanged: onSceneChanged,
        reduceMotion: MediaQuery.disableAnimationsOf(context),
      ),
    );
  }
  return PanoramaWebView(
    manifest: manifest,
    firstSceneId: sceneId,
    sceneId: sceneId,
    onSceneChanged: onSceneChanged,
  );
}

/// The immersive tour: viewer (full-bleed) + a glass title island + the scene
/// rail. Owns the selected-scene state and keeps the rail and viewer in sync
/// (rail tap → viewer; viewer hotspot → rail).
class PanoramaTourView extends StatefulWidget {
  const PanoramaTourView({
    super.key,
    required this.manifest,
    this.title,
    this.titleLeadingInset = 0,
    this.firstSceneId,
    this.viewerBuilder,
  });

  final IndoorManifest manifest;
  final String? title;

  /// Horizontal space reserved at the START of the title island for a back
  /// affordance that a PARENT stacks over this widget.
  ///
  /// `PanoramaScreen` floats its back button at the same top/left as this
  /// island, so without a reservation the button covers the title's first
  /// glyph — "Macquarie Theatre" rendered as "◄acquarie Theatre" on a device.
  /// Opt-in rather than baked in, so the tour view stays usable on its own.
  final double titleLeadingInset;
  final String? firstSceneId;
  final PanoramaViewerBuilder? viewerBuilder;

  @override
  State<PanoramaTourView> createState() => _PanoramaTourViewState();
}

class _PanoramaTourViewState extends State<PanoramaTourView> {
  late String? _selected =
      widget.firstSceneId ?? (widget.manifest.nodes.isNotEmpty ? widget.manifest.nodes.first.id : null);

  void _select(String id) {
    if (id != _selected) setState(() => _selected = id);
  }

  /// On web the viewer is an `<iframe>` platform view that captures pointer
  /// events for anything painted over it, so the floated controls would be
  /// dead to touch. [PointerInterceptor] restores their taps. It is a no-op
  /// wrap on native, but gating on `kIsWeb` keeps the mobile widget tree — and
  /// its golden/widget tests — byte-for-byte unchanged.
  Widget _overlay(Widget child) =>
      kIsWeb ? PointerInterceptor(child: child) : child;

  @override
  Widget build(BuildContext context) {
    final build = widget.viewerBuilder ?? _defaultViewerBuilder;
    return Stack(
      fit: StackFit.expand,
      children: [
        build(
          manifest: widget.manifest,
          sceneId: _selected,
          onSceneChanged: _select, // viewer hotspot → rail
        ),
        if (widget.title != null)
          Positioned(
            top: MediaQuery.paddingOf(context).top + AonSpacing.space3,
            left: AonSpacing.space4,
            right: AonSpacing.space4,
            child: _overlay(GlassSurface(
              variant: GlassVariant.control,
              allowShader: false,
              padding: EdgeInsetsDirectional.only(
                start: AonSpacing.space4 + widget.titleLeadingInset,
                end: AonSpacing.space4,
                top: AonSpacing.space3,
                bottom: AonSpacing.space3,
              ),
              child: Text(
                widget.title!,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: context.aon.contentPrimary),
              ),
            )),
          ),
        Positioned(
          left: AonSpacing.space4,
          right: AonSpacing.space4,
          bottom: MediaQuery.paddingOf(context).bottom + AonSpacing.space4,
          child: _overlay(PanoramaSceneRail(
            manifest: widget.manifest,
            selectedSceneId: _selected,
            onSceneSelected: _select, // rail tap → viewer
          )),
        ),
      ],
    );
  }
}
