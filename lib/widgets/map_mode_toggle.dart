import 'package:flutter/material.dart';

import 'package:aon2026/app/theme/aon_colors.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/widgets/glass_surface.dart';

enum MapMode { campusMap, panorama }

/// A glass segmented control switching the Map tab between the campus map and
/// the 360° panorama picker.
class MapModeToggle extends StatelessWidget {
  const MapModeToggle({super.key, required this.value, required this.onChanged});

  final MapMode value;
  final ValueChanged<MapMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      variant: GlassVariant.control,
      borderRadius: BorderRadius.circular(AonSpacing.radiusFull),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final mode in MapMode.values) ...[
            if (mode != MapMode.values.first) const SizedBox(width: 2),
            _Segment(
              label: mode == MapMode.campusMap ? 'Map' : '360°',
              selected: value == mode,
              onTap: () => onChanged(mode),
            ),
          ],
        ],
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
      child: Material(
        color: selected ? AonColors.amber : Colors.transparent,
        borderRadius: BorderRadius.circular(AonSpacing.radiusFull),
        child: InkWell(
          borderRadius: BorderRadius.circular(AonSpacing.radiusFull),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56), // ≥56px target
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AonSpacing.space3, vertical: AonSpacing.space3),
              child: Center(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color:
                        selected ? AonColors.night950 : AonColors.contentPrimary,
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
