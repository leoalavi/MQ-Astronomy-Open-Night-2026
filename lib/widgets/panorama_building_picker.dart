import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/data/panorama_data.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/services/providers.dart';
import 'package:aon2026/widgets/glass_surface.dart';
import 'package:aon2026/widgets/nav_metrics.dart';

/// Demo-content disclosure for a PLACEHOLDER tour lives in the ARB as
/// `panoramaDemoFlag` — the imagery is a different building. Nothing shipped is
/// a placeholder any more (see [PanoramaData]); the string exists so that if one
/// ever returns it cannot pass as the real venue, in either language.
/// The 360° building picker: the planned D–I catalogue, in official map-letter
/// order. C (Food and drink) is intentionally absent because no panorama is
/// planned; unlettered service points are not offered either.
///
/// Venues with a tour are tappable (with the demo flag); the rest show
/// "coming soon". No auto-select — the picker is always shown so availability
/// + the disclosure stay visible.
class PanoramaBuildingPicker extends ConsumerWidget {
  const PanoramaBuildingPicker({super.key, required this.onOpen});

  final void Function(String venueId) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AonL10n.of(context);
    final venues = ref.watch(panoramaPickerVenuesProvider);
    final tours = ref.watch(panoramaToursProvider);

    return ListView(
      // Runs under the floating glass tab bar (shell `extendBody`), so reserve
      // the same clearance the compass NearbyList does — otherwise the last
      // legend card ("I · 17 Wally's Walk") hides behind the island (field
      // report, Leo Alavi 2026-08-28).
      padding: EdgeInsets.fromLTRB(
        AonSpacing.space4,
        AonSpacing.space4,
        AonSpacing.space4,
        AonNavMetrics.clearance(context),
      ),
      children: [
        // Solar system walk — pinned at the top, ABOVE the D–I letter list. It
        // is a route, not a lettered venue (Gymnasium Road carries no map disc),
        // so it never goes through the letter path below — which is also why the
        // unguarded `v.mapReference!` there is still safe.
        if (tours.containsKey('gymnasium-road'))
          Padding(
            padding: const EdgeInsets.only(bottom: AonSpacing.space3),
            child: _VenueCard(
              label: l10n.panoramaSolarWalkTitle,
              subtitleOverride: l10n.panoramaSolarWalkSubtitle,
              iconOverride: Icons.directions_walk_rounded,
              tour: tours['gymnasium-road'],
              onTap: () => onOpen('gymnasium-road'),
            ),
          ),
        for (final v in venues)
          Padding(
            padding: const EdgeInsets.only(bottom: AonSpacing.space3),
            child: _VenueCard(
              // Every venue in this list carries a legend letter by
              // construction — that is what put it in the list.
              label: l10n.panoramaVenueWithMapLetter(v.mapReference!, v.name),
              tour: tours[v.id],
              onTap: tours.containsKey(v.id) ? () => onOpen(v.id) : null,
            ),
          ),
      ],
    );
  }
}

class _VenueCard extends StatelessWidget {
  const _VenueCard({
    required this.label,
    required this.tour,
    this.onTap,
    this.subtitleOverride,
    this.iconOverride,
  });

  /// Already letter-prefixed, e.g. "A · Macquarie Theatre".
  final String label;

  /// Null when this venue has no tour yet.
  final PanoramaTour? tour;
  final VoidCallback? onTap;

  /// Non-null replaces the default subtitle (used by the Solar system walk,
  /// which names its route rather than reading "Tap to explore").
  final String? subtitleOverride;

  /// Non-null replaces the default leading icon (the walk uses a route glyph).
  final IconData? iconOverride;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AonL10n.of(context);
    final hasTour = tour != null;
    final isDemo = tour?.placeholder ?? false;
    final subtitle =
        subtitleOverride ??
        (tour == null
            ? l10n.panoramaComingSoon
            : (isDemo ? l10n.panoramaDemoFlag : l10n.panoramaTapToExplore));
    final card = GlassSurface(
      variant: GlassVariant.control,
      borderRadius: BorderRadius.circular(AonSpacing.radiusMd),
      padding: const EdgeInsets.all(AonSpacing.space4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(
          children: [
            Icon(
              iconOverride ??
                  (hasTour
                      ? Icons.panorama_photosphere
                      : Icons.lock_outline_rounded),
              color: hasTour ? context.aon.accent : context.aon.contentTertiary,
            ),
            const SizedBox(width: AonSpacing.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: hasTour
                          ? context.aon.soon
                          : context.aon.contentTertiary,
                    ),
                  ),
                ],
              ),
            ),
            if (hasTour)
              Icon(
                Icons.chevron_right_rounded,
                color: context.aon.contentSecondary,
              ),
          ],
        ),
      ),
    );

    if (onTap == null) {
      return Semantics(label: l10n.panoramaCardComingSoon(label), child: card);
    }
    return Semantics(
      button: true,
      label: isDemo
          ? l10n.panoramaCardDemoTour(label)
          : l10n.panoramaCardTour(label),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AonSpacing.radiusMd),
          onTap: onTap,
          child: card,
        ),
      ),
    );
  }
}
