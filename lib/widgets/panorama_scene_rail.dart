import 'package:flutter/material.dart';

import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/models/indoor_manifest.dart';
import 'package:aon2026/widgets/glass_surface.dart';

/// A floating glass rail of scene chips over the panorama. Controlled:
/// [selectedSceneId] in, [onSceneSelected] out. Frost-forced (`allowShader:
/// false`) — it floats over a platform-view panorama a shader cannot sample.
class PanoramaSceneRail extends StatelessWidget {
  const PanoramaSceneRail({
    super.key,
    required this.manifest,
    required this.selectedSceneId,
    required this.onSceneSelected,
  });

  final IndoorManifest manifest;
  final String? selectedSceneId;
  final ValueChanged<String> onSceneSelected;

  @override
  Widget build(BuildContext context) {
    if (manifest.nodes.length < 2) return const SizedBox.shrink();
    return GlassSurface(
      variant: GlassVariant.control,
      allowShader: false,
      padding: const EdgeInsets.all(AonSpacing.space2),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final node in manifest.nodes)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _SceneChip(
                  label: node.description.isEmpty ? node.id : node.description,
                  selected: node.id == selectedSceneId,
                  onTap: () => onSceneSelected(node.id),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SceneChip extends StatelessWidget {
  const _SceneChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? context.aon.accent : Colors.transparent,
      borderRadius: BorderRadius.circular(AonSpacing.radiusFull),
      child: InkWell(
        borderRadius: BorderRadius.circular(AonSpacing.radiusFull),
        onTap: onTap,
        child: ConstrainedBox(
          // ≥56px tap target.
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AonSpacing.space4, vertical: AonSpacing.space2),
            child: Center(
              child: Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: selected ? context.aon.surfaceBase : context.aon.contentPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
