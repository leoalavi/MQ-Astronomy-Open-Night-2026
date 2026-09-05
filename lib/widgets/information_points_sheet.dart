import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/models/venue.dart';
import 'package:aon2026/services/providers.dart';
import 'package:aon2026/utils/bidi.dart';
import 'package:aon2026/utils/venue_style.dart';
import 'package:aon2026/widgets/nav_metrics.dart';
import 'package:aon2026/widgets/place_action_buttons.dart';

/// Home's information-point chooser. It lists the official registration and
/// information points, and — mirroring [ParkingChoicesSheet] — only offers
/// navigation for a point that has a verified routable position (all three sit
/// on the Central Courtyard coordinate the map already pins as 1/2/3). A point
/// without a coordinate would still be listed, just without fake navigation.
class InformationPointsSheet extends ConsumerWidget {
  const InformationPointsSheet({super.key});

  /// The official points, in map-label order (1, 2, 3).
  static const _venueIds = <String>[
    'registration-point',
    'information-point-2',
    'information-point-3',
  ];

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const InformationPointsSheet(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AonL10n.of(context);
    final theme = Theme.of(context);
    final venues = [
      for (final id in _venueIds) ref.watch(venueByIdProvider(id)),
    ].whereType<Venue>().toList();

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AonSpacing.space5,
          0,
          AonSpacing.space5,
          AonNavMetrics.clearance(context),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.infoRegistrationAndInfo, style: theme.textTheme.headlineSmall),
            const SizedBox(height: AonSpacing.space4),
            for (final venue in venues)
              Card(
                key: Key('info-point-card-${venue.id}'),
                margin: const EdgeInsets.only(bottom: AonSpacing.space3),
                child: Padding(
                  padding: const EdgeInsets.all(AonSpacing.space4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            VenueStyle.iconFor(venue.category),
                            color: VenueStyle.colorFor(context, venue.category),
                          ),
                          const SizedBox(width: AonSpacing.space3),
                          Expanded(
                            child: Text(
                              Bidi.isolate(venue.name),
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      if (venue.building != null &&
                          venue.building != venue.name) ...[
                        const SizedBox(height: AonSpacing.space2),
                        Text(
                          Bidi.isolate(venue.building),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: context.aon.contentSecondary,
                          ),
                        ),
                      ],
                      if (venue.hasCoordinates) ...[
                        const SizedBox(height: AonSpacing.space3),
                        PlaceActionButtons(
                          placeKey: 'venue:${venue.id}',
                          beforeNavigate: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
