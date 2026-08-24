import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/data/panorama_data.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/services/providers.dart';
import 'package:aon2026/widgets/glass_surface.dart';

/// Demo-content disclosure for a PLACEHOLDER tour lives in the ARB as
/// `panoramaDemoFlag` — the imagery is a different building. Nothing shipped is
/// a placeholder any more (see [PanoramaData]); the string exists so that if one
/// ever returns it cannot pass as the real venue, in either language.
/// The 360° building picker: a card per *event* location — the A–I entries of
/// the official AON program map's legend, in the order the sheet letters them.
/// Unlettered service points (toilets, first aid, transport) are not offered.
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
      padding: const EdgeInsets.all(AonSpacing.space4),
      children: [
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
  const _VenueCard({required this.label, required this.tour, this.onTap});

  /// Already letter-prefixed, e.g. "A · Macquarie Theatre".
  final String label;

  /// Null when this venue has no tour yet.
  final PanoramaTour? tour;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AonL10n.of(context);
    final hasTour = tour != null;
    final isDemo = tour?.placeholder ?? false;
    final subtitle = tour == null
        ? l10n.panoramaComingSoon
        : (isDemo ? l10n.panoramaDemoFlag : l10n.panoramaTapToExplore);
    final card = GlassSurface(
      variant: GlassVariant.control,
      borderRadius: BorderRadius.circular(AonSpacing.radiusMd),
      padding: const EdgeInsets.all(AonSpacing.space4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(
          children: [
            Icon(
              hasTour ? Icons.panorama_photosphere : Icons.lock_outline_rounded,
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
              Icon(Icons.chevron_right_rounded,
                  color: context.aon.contentSecondary),
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
