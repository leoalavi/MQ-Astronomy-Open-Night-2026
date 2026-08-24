import 'package:flutter/material.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';

import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/data/stamp_stations_data.dart';
import 'package:aon2026/data/venues_data.dart';
import 'package:aon2026/widgets/aon_tactile_button.dart';

/// The 9-cell passport. Adaptive columns + content-driven height so long venue
/// names never clip, including at text scale 2.0 (design §6.1). After Phase 7 a
/// collected cell is a button that opens its astronomy fact.
class PassportGrid extends StatelessWidget {
  const PassportGrid({
    required this.collectedVenueIds,
    this.onTapCollected,
    super.key,
  });

  final Set<String> collectedVenueIds;

  /// Tapping a collected cell reveals its fact. When null, collected cells are
  /// inert and announce no button role.
  final void Function(String venueId)? onTapCollected;

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
                  onTapCollected: onTapCollected,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.venueId,
    required this.collected,
    this.onTapCollected,
  });

  final String venueId;
  final bool collected;
  final void Function(String venueId)? onTapCollected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AonL10n.of(context);
    final venue = VenuesData.byId(venueId);
    final name = venue?.shortName ?? venue?.name ?? venueId;

    // The Phase 6 cell visual (colours migrated to the AonPalette theme
    // extension after the localisation/theme merge).
    final visual = Container(
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
            color:
                collected ? context.aon.accent : context.aon.contentTertiary,
            size: AonSpacing.iconMd,
          ),
          const SizedBox(height: AonSpacing.space2),
          Text(name, style: theme.textTheme.titleSmall),
        ],
      ),
    );

    // Interactive ONLY when collected AND a callback exists — an inert cell must
    // never announce a button role. Reuses the Phase 3 AonTactileButton
    // (keyboard Enter/Space, focus ring, reduced-motion press) rather than a raw
    // GestureDetector; haptics off (revisit fires none, §11.4).
    if (collected && onTapCollected != null) {
      return Semantics(
        container: true,
        button: true,
        label: l.passportCellCollected(name),
        hint: l.passportCellOpensFact,
        child: AonTactileButton(
          onTap: () => onTapCollected!(venueId),
          hapticsEnabled: false,
          borderRadius: AonSpacing.radiusMd,
          child: ExcludeSemantics(child: visual),
        ),
      );
    }
    // Collected-but-no-callback or uncollected: inert, no button role.
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: collected
          ? l.passportCellCollected(name)
          : l.passportCellNotCollected(name),
      child: visual,
    );
  }
}
