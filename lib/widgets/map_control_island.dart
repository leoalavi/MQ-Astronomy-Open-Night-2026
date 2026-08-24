import 'package:flutter/material.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';

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

/// A floating glass island of map controls: zoom in / zoom out / locate.
///
/// One [GlassSurface] with two plain zoom [IconButton]s plus an injected
/// [locateButton] widget — a single glass control layer, never glass-on-glass.
/// It carries **no** `MapController` dependency, so it is unit-testable without
/// a live `FlutterMap`. The screen wires the zoom callbacks to the controller
/// (via [clampZoom]) and passes a stateful `LocateButton` for the third slot.
class MapControlIsland extends StatelessWidget {
  const MapControlIsland({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.locateButton,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  /// The stateful "you are here" control (a `LocateButton`), placed where the
  /// recentre button used to be — tapping it recenters on the user, and the
  /// camera constraint keeps campus in view (Map Parity Phase A).
  final Widget locateButton;

  @override
  Widget build(BuildContext context) {
    final l = AonL10n.of(context);
    return GlassSurface(
      variant: GlassVariant.control,
      borderRadius: BorderRadius.circular(AonSpacing.radiusFull),
      padding: const EdgeInsets.all(4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _button(context, Icons.add_rounded, l.mapZoomIn, onZoomIn),
          _divider(),
          _button(context, Icons.remove_rounded, l.mapZoomOut, onZoomOut),
          _divider(),
          locateButton,
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
