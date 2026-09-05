import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/models/venue.dart';
import 'package:aon2026/services/providers.dart';
import 'package:aon2026/utils/bidi.dart';
import 'package:aon2026/widgets/nav_metrics.dart';
import 'package:aon2026/widgets/place_action_buttons.dart';

/// Home's toilet chooser. The programme names three buildings with toilets, so
/// the Home shortcut lists all of them — each with directions and a map pin —
/// rather than silently sending everyone to a single one.
///
/// Mirrors [ParkingChoicesSheet]: same card shape, same per-item
/// [PlaceActionButtons], so the two Home choosers read as one pattern.
class ToiletChoicesSheet extends ConsumerWidget {
  const ToiletChoicesSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const ToiletChoicesSheet(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AonL10n.of(context);
    final theme = Theme.of(context);
    final toilets = ref
        .watch(venuesProvider)
        .where((v) => v.category == VenueCategory.toilets)
        .toList();

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
            Text(l.infoToilets, style: theme.textTheme.headlineSmall),
            const SizedBox(height: AonSpacing.space4),
            for (final v in toilets)
              Card(
                key: Key('toilet-card-${v.id}'),
                margin: const EdgeInsets.only(bottom: AonSpacing.space3),
                child: Padding(
                  padding: const EdgeInsets.all(AonSpacing.space4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.wc_rounded,
                            color: context.aon.mapFacility,
                          ),
                          const SizedBox(width: AonSpacing.space3),
                          Expanded(
                            child: Text(
                              Bidi.isolate(v.building ?? v.name),
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      if (v.notes != null) ...[
                        const SizedBox(height: AonSpacing.space2),
                        Text(
                          Bidi.isolate(v.notes),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: context.aon.contentSecondary,
                          ),
                        ),
                      ],
                      if (v.hasCoordinates) ...[
                        const SizedBox(height: AonSpacing.space3),
                        PlaceActionButtons(
                          placeKey: 'venue:${v.id}',
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
