import 'package:flutter/material.dart';

import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/widgets/glass_surface.dart';
import 'package:aon2026/utils/haptics.dart';

enum MapMode { campusMap, panorama }

/// A glass segmented control switching the Map tab between the campus map and
/// the 360° panorama picker.
class MapModeToggle extends StatelessWidget {
  const MapModeToggle({super.key, required this.value, required this.onChanged});

  final MapMode value;
  final ValueChanged<MapMode> onChanged;

  static String _label(AonL10n l, MapMode m) => switch (m) {
        MapMode.campusMap => l.mapModeMap,
        MapMode.panorama => l.mapModePanorama,
      };

  @override
  Widget build(BuildContext context) {
    final l = AonL10n.of(context);
    return GlassSurface(
      variant: GlassVariant.control,
      borderRadius: BorderRadius.circular(AonSpacing.radiusFull),
      padding: const EdgeInsets.all(4),
      // §0-D: scale the 2-segment row down rather than overflow at 320/2.0.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final mode in MapMode.values) ...[
              if (mode != MapMode.values.first) const SizedBox(width: 2),
              _Segment(
                label: _label(l, mode),
                selected: value == mode,
                onTap: () {
                  AonHaptics.select();
                  onChanged(mode);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      container: true, // §0-E: one node…
      excludeSemantics: true, // …not two (drop the child Text's implicit label)
      child: Material(
        color: selected ? context.aon.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(AonSpacing.radiusFull),
        child: InkWell(
          borderRadius: BorderRadius.circular(AonSpacing.radiusFull),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56), // ≥56px target
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AonSpacing.space2, vertical: AonSpacing.space3),
              child: Center(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color:
                        selected ? context.aon.surfaceBase : context.aon.contentPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
