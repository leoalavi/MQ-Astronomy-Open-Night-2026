import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/services/providers.dart';
import 'package:aon2026/utils/bidi.dart';
import 'package:aon2026/utils/time_format.dart';
import 'package:aon2026/utils/venue_style.dart';
import 'package:aon2026/widgets/confidence_note.dart';
import 'package:aon2026/widgets/map_config.dart';

/// What a Quick Access shortcut opens.
///
/// ## Why this exists
///
/// Quick Access used to send every tile straight into the walking-directions
/// planner. That works for the two venues we have authored routes to — but
/// five of the eight tiles (Toilets, First aid, Food and drink, Talks, Kids'
/// activities) have no route, so tapping them dropped the visitor onto an
/// empty planner with nothing selected. On the first screen of the app, that
/// reads as "this app is broken".
///
/// A sheet answers the actual question — *where is this, and what's on here* —
/// and only offers walking directions when we genuinely have them.
class VenueInfoSheet extends ConsumerWidget {
  const VenueInfoSheet({required this.venueId, super.key});

  final String venueId;

  /// Shows the sheet for [venueId].
  static Future<void> show(BuildContext context, String venueId) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => VenueInfoSheet(venueId: venueId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AonL10n.of(context);
    final theme = Theme.of(context);
    final venue = ref.watch(venueByIdProvider(venueId));

    if (venue == null) {
      // Defensive: a config typo must not produce a blank sheet.
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AonSpacing.space5),
          child: Text(
            l.infoLocationToBeConfirmed,
            style: theme.textTheme.titleMedium,
          ),
        ),
      );
    }

    final events = ref.watch(eventsAtVenueProvider(venueId));
    // Only offer directions we actually have. `routesToProvider` is a pure
    // frontend lookup over the authored route list — no map internals.

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: MapConfig.venueSheetInitialExtent,
      minChildSize: MapConfig.venueSheetMinExtent,
      maxChildSize: MapConfig.venueSheetMaxExtent,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(
          AonSpacing.space5,
          0,
          AonSpacing.space5,
          AonSpacing.space6,
        ),
        children: [
          // ── Heading ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                VenueStyle.iconFor(venue.category),
                color: VenueStyle.colorFor(context, venue.category),
              ),
              const SizedBox(width: AonSpacing.space3),
              Expanded(
                child: Text(venue.name, style: theme.textTheme.headlineSmall),
              ),
              if (venue.mapReference != null) _MapRefBadge(venue.mapReference!),
            ],
          ),

          if (venue.building != null && venue.building != venue.name) ...[
            const SizedBox(height: AonSpacing.space1),
            Text(
              Bidi.isolate(venue.building),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.aon.contentSecondary,
              ),
            ),
          ],

          if (venue.notes != null) ...[
            const SizedBox(height: AonSpacing.space3),
            Text(
              venue.notes!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.aon.contentSecondary,
              ),
            ),
          ],

          if (venue.accessibilityNotes != null) ...[
            const SizedBox(height: AonSpacing.space3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.accessible_rounded,
                  size: AonSpacing.iconSm,
                  color: context.aon.info,
                ),
                const SizedBox(width: AonSpacing.space2),
                Expanded(
                  child: Text(
                    venue.accessibilityNotes!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.aon.info,
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: AonSpacing.space3),
          ConfidenceNote(confidence: venue.coordinateConfidence),

          // ── Actions ──
          const SizedBox(height: AonSpacing.space4),
          // One directions action, always Google Maps. GoogleNavScreen shows the
          // interactive route with a key, or a clear "not configured yet"
          // message without one — never a dead button or a draft screen.
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                context.push(Routes.googleNavTo('venue:$venueId'));
              },
              icon: const Icon(Icons.directions_walk_rounded),
              label: Text(l.mapDirections),
            ),
          ),

          const SizedBox(height: AonSpacing.space3),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                context.go(Routes.mapFocus('venue:$venueId'));
              },
              icon: const Icon(Icons.map_rounded),
              label: Text(l.actionShowOnMap),
            ),
          ),

          // ── What's on here ──
          const SizedBox(height: AonSpacing.space5),
          Text(l.mapOnHereTonight, style: theme.textTheme.titleMedium),
          const SizedBox(height: AonSpacing.space2),
          if (events.isEmpty)
            Text(
              l.venueNothingScheduled,
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.aon.contentTertiary,
              ),
            )
          else
            for (final e in events)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(e.title, style: theme.textTheme.titleSmall),
                subtitle: Text(TimeFormat.allSessions(e)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(context).pop();
                  context.push(Routes.eventDetailFor(e.id));
                },
              ),
        ],
      ),
    );
  }
}

class _MapRefBadge extends StatelessWidget {
  const _MapRefBadge(this.letter);

  final String letter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.aon.accent,
        shape: BoxShape.circle,
      ),
      child: Text(
        letter,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: context.aon.onAccent),
      ),
    );
  }
}
