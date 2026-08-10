import 'package:flutter/material.dart';

import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/models/indoor_manifest.dart';
import 'package:aon2026/widgets/glass_surface.dart';
import 'package:aon2026/widgets/panorama_scene_rail.dart';
import 'package:aon2026/widgets/panorama_web_view.dart';

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
}) =>
    PanoramaWebView(
      manifest: manifest,
      firstSceneId: sceneId,
      sceneId: sceneId,
      onSceneChanged: onSceneChanged,
    );

/// The immersive tour: viewer (full-bleed) + a glass title island + the scene
/// rail. Owns the selected-scene state and keeps the rail and viewer in sync
/// (rail tap → viewer; viewer hotspot → rail).
class PanoramaTourView extends StatefulWidget {
  const PanoramaTourView({
    super.key,
    required this.manifest,
    this.title,
    this.firstSceneId,
    this.viewerBuilder,
  });

  final IndoorManifest manifest;
  final String? title;
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
            child: GlassSurface(
              variant: GlassVariant.control,
              allowShader: false,
              padding: const EdgeInsets.symmetric(
                  horizontal: AonSpacing.space4, vertical: AonSpacing.space3),
              child: Text(
                widget.title!,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: context.aon.contentPrimary),
              ),
            ),
          ),
        Positioned(
          left: AonSpacing.space4,
          right: AonSpacing.space4,
          bottom: MediaQuery.paddingOf(context).bottom + AonSpacing.space4,
          child: PanoramaSceneRail(
            manifest: widget.manifest,
            selectedSceneId: _selected,
            onSceneSelected: _select, // rail tap → viewer
          ),
        ),
      ],
    );
  }
}
