import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/services/providers.dart';
import 'package:aon2026/utils/bidi.dart';
import 'package:aon2026/widgets/place_action_buttons.dart';

/// Home's parking chooser. It lists every official free parking area but only
/// enables navigation when the repository has a verified routable position.
class ParkingChoicesSheet extends ConsumerWidget {
  const ParkingChoicesSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const ParkingChoicesSheet(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AonL10n.of(context);
    final theme = Theme.of(context);
    final parking = ref.watch(parkingProvider);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AonSpacing.space5,
          0,
          AonSpacing.space5,
          // `space6`, not the shell clearance: this sheet opens on the ROOT
          // navigator, so it sits ABOVE the floating island rather than under
          // it, and the SafeArea above already absorbs the home indicator.
          // Clearance here just left ~124pt of dead space (2026-09-08).
          AonSpacing.space6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.infoParking, style: theme.textTheme.headlineSmall),
            const SizedBox(height: AonSpacing.space2),
            Text(
              l.infoParkingFree,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.aon.contentSecondary,
              ),
            ),
            const SizedBox(height: AonSpacing.space4),
            for (final area in parking)
              Card(
                key: Key('parking-card-${area.id}'),
                margin: const EdgeInsets.only(bottom: AonSpacing.space3),
                child: Padding(
                  padding: const EdgeInsets.all(AonSpacing.space4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.local_parking_rounded,
                            color: context.aon.mapParking,
                          ),
                          const SizedBox(width: AonSpacing.space3),
                          Expanded(
                            child: Text(
                              Bidi.isolate(area.name),
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      if (area.notes != null) ...[
                        const SizedBox(height: AonSpacing.space2),
                        Text(
                          Bidi.isolate(area.notes),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: context.aon.contentSecondary,
                          ),
                        ),
                      ],
                      if (area.hasCoordinates) ...[
                        const SizedBox(height: AonSpacing.space3),
                        PlaceActionButtons(
                          placeKey: 'parking:${area.id}',
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
