import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/models/user_location_fix.dart';

/// Accuracy circle (metre radius) that sits UNDER the venue pins (spec §5.5).
/// Renders nothing for a low-accuracy fix so it never paints a suburb-sized
/// blob (spec §5.1). A StatelessWidget wrapping a flutter_map layer — the same
/// pattern as [DarkTileLayer] — so colour comes from `context.aon`, not a hex.
class UserLocationCircle extends StatelessWidget {
  const UserLocationCircle({required this.fix, super.key});
  final UserLocationFix fix;

  @override
  Widget build(BuildContext context) {
    if (fix.isLowAccuracy) return const SizedBox.shrink();
    final accent = context.aon.accent;
    return CircleLayer(circles: [
      CircleMarker(
        point: fix.position,
        radius: fix.accuracyMeters,
        useRadiusInMeter: true,
        color: accent.withValues(alpha: 0.12),
        borderColor: accent.withValues(alpha: 0.4),
        borderStrokeWidth: 1,
      ),
    ]);
  }
}

/// The "you are here" dot — an accent dot on a white ring — ON TOP of the pins.
///
/// The `Colors.white` ring + `Colors.black26` shadow are the one sanctioned
/// palette exception: a "you-are-here" dot must read as *you* against any tile
/// independent of theme. The dot's centre still reads from `context.aon`.
class UserLocationDot extends StatelessWidget {
  const UserLocationDot({required this.fix, super.key});
  final UserLocationFix fix;

  @override
  Widget build(BuildContext context) => MarkerLayer(markers: [
        Marker(
          point: fix.position,
          width: 22,
          height: 22,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(blurRadius: 3, color: Colors.black26)],
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: DecoratedBox(
                decoration: BoxDecoration(
                    color: context.aon.accent, shape: BoxShape.circle),
              ),
            ),
          ),
        ),
      ]);
}
