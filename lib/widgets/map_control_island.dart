import 'package:flutter/material.dart';

import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/widgets/glass_surface.dart';

/// Clamps a zoom step to `[min, max]`. Pure and unit-tested. A step past a bound
/// is a safe no-op (returns the bound) — this is what lets the zoom buttons stay
/// enabled without live-camera state (Phase 2 spec §5.2).
double clampZoom(double current, double delta,
    {required double min, required double max}) {
  final next = current + delta;
  if (next < min) return min;
  if (next > max) return max;
  return next;
}

/// A floating glass island of map controls: zoom in / zoom out / recentre.
///
/// One [GlassSurface] with three plain [IconButton]s — a single glass control
/// layer, never glass-on-glass. It takes injected callbacks and carries **no**
/// `MapController` dependency, so it is unit-testable without a live `FlutterMap`.
/// The screen wires the callbacks to the controller (via [clampZoom]).
class MapControlIsland extends StatelessWidget {
  const MapControlIsland({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onRecenter,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onRecenter;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      variant: GlassVariant.control,
      borderRadius: BorderRadius.circular(AonSpacing.radiusFull),
      padding: const EdgeInsets.all(4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _button(context, Icons.add_rounded, 'Zoom in', onZoomIn),
          _divider(),
          _button(context, Icons.remove_rounded, 'Zoom out', onZoomOut),
          _divider(),
          _button(context, Icons.my_location_rounded, 'Recentre', onRecenter),
        ],
      ),
    );
  }

  Widget _button(
    BuildContext context,
    IconData icon,
    String tooltip,
    VoidCallback onPressed,
  ) {
    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: onPressed,
      color: context.aon.contentPrimary,
      iconSize: AonSpacing.iconDefault,
      constraints: const BoxConstraints(
        minWidth: AonSpacing.minTapTarget,
        minHeight: AonSpacing.minTapTarget,
      ),
    );
  }

  Widget _divider() => Container(
        width: AonSpacing.minTapTarget - 24,
        height: 1,
        color: Colors.white.withValues(alpha: 0.12),
      );
}
