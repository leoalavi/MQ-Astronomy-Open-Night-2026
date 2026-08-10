import 'package:flutter/material.dart';

import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/data/stamp_stations_data.dart';
import 'package:aon2026/data/venues_data.dart';

/// The 9-cell passport. Adaptive columns + content-driven height so long venue
/// names never clip, including at text scale 2.0 (design §6.1).
class PassportGrid extends StatelessWidget {
  const PassportGrid({required this.collectedVenueIds, super.key});

  final Set<String> collectedVenueIds;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = AonSpacing.space3;
        final columns = (constraints.maxWidth / 150).floor().clamp(1, 3);
        final cellWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final s in StampStationsData.all)
              SizedBox(
                width: cellWidth,
                child: _Cell(
                  venueId: s.venueId,
                  collected: collectedVenueIds.contains(s.venueId),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.venueId, required this.collected});

  final String venueId;
  final bool collected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final venue = VenuesData.byId(venueId);
    final name = venue?.shortName ?? venue?.name ?? venueId;

    // One clean semantics node per cell: the human name + collection state.
    // excludeSemantics drops the inner Text node so the announced label is
    // exactly "<name>, stamp collected" / "<name>, not yet collected".
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: '$name, ${collected ? 'stamp collected' : 'not yet collected'}',
      child: Container(
        padding: const EdgeInsets.all(AonSpacing.space3),
        decoration: BoxDecoration(
          color: collected
              ? context.aon.accent.withValues(alpha: 0.12)
              : context.aon.surface,
          borderRadius: BorderRadius.circular(AonSpacing.radiusMd),
          border: Border.all(
            color: collected ? context.aon.accent : context.aon.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              collected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: collected ? context.aon.accent : context.aon.contentTertiary,
              size: AonSpacing.iconMd,
            ),
            const SizedBox(height: AonSpacing.space2),
            Text(name, style: theme.textTheme.titleSmall),
          ],
        ),
      ),
    );
  }
}
