import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/services/providers.dart';
import 'package:aon2026/widgets/glass_surface.dart';

/// Demo-content disclosure shown on every placeholder tour card and inside the
/// panorama — the imagery is a different building.
const String kPanoramaDemoFlag = 'Demo 360° — sample imagery, not this venue';

/// The 360° building picker: a card per venue. Venues with a tour are tappable
/// (with the demo flag); the rest show "coming soon". No auto-select — the
/// picker is always shown so availability + the disclosure stay visible.
class PanoramaBuildingPicker extends ConsumerWidget {
  const PanoramaBuildingPicker({super.key, required this.onOpen});

  final void Function(String venueId) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venues = ref.watch(venuesProvider);
    final withTour = ref.watch(venuesWithPanoramaProvider);

    return ListView(
      padding: const EdgeInsets.all(AonSpacing.space4),
      children: [
        for (final v in venues)
          Padding(
            padding: const EdgeInsets.only(bottom: AonSpacing.space3),
            child: _VenueCard(
              name: v.name,
              hasTour: withTour.contains(v.id),
              onTap: withTour.contains(v.id) ? () => onOpen(v.id) : null,
            ),
          ),
      ],
    );
  }
}

class _VenueCard extends StatelessWidget {
  const _VenueCard({required this.name, required this.hasTour, this.onTap});

  final String name;
  final bool hasTour;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                  Text(name, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    hasTour ? kPanoramaDemoFlag : 'Coming soon',
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
      return Semantics(label: '$name, coming soon', child: card);
    }
    return Semantics(
      button: true,
      label: '$name, demo 360 tour',
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
