import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/models/event.dart';
import 'package:aon2026/services/favorites_providers.dart';
import 'package:aon2026/services/providers.dart';
import 'package:aon2026/services/saved_events.dart';
import 'package:aon2026/services/search_providers.dart';
import 'package:aon2026/utils/bidi.dart';
import 'package:aon2026/utils/time_format.dart';
import 'package:aon2026/widgets/nav_metrics.dart';
import 'package:aon2026/widgets/place_action_buttons.dart';

/// Map → Favourites.
///
/// The source of truth for saved **activities** is [savedEventsProvider] — the
/// exact set shown on Home, Program and My Night — so a night saved anywhere
/// shows here too, with no second store (map audit / consistency fix). Places
/// the visitor hearts on the map ([favoritesProvider]) also appear, below the
/// activities. Each item offers Show on Map + Directions only where a verified
/// map destination exists; a saved activity whose venue has no coordinate, or a
/// list-only place, is kept but shown without fake navigation.
class FavoritesSheet extends ConsumerWidget {
  const FavoritesSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AonL10n.of(context);
    final theme = Theme.of(context);

    final savedIds = ref.watch(savedEventsProvider).value ?? const <String>{};
    // Preserve programme order rather than set/iteration order.
    final savedEvents = ref
        .watch(eventsProvider)
        .where((e) => savedIds.contains(e.id))
        .toList(growable: false);
    final placeKeys = ref.watch(favoritesProvider).keys.toList()..sort();

    final isEmpty = savedEvents.isEmpty && placeKeys.isEmpty;

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
            Text(l.mapFavoritesTitle, style: theme.textTheme.headlineSmall),
            const SizedBox(height: AonSpacing.space4),
            if (isEmpty)
              _EmptyState(l: l)
            else ...[
              for (final event in savedEvents) _SavedEventCard(event: event),
              for (final key in placeKeys) _FavoritePlaceCard(placeKey: key),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.l});
  final AonL10n l;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AonSpacing.space6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border_rounded,
            size: AonSpacing.iconLg,
            color: context.aon.contentTertiary,
          ),
          const SizedBox(height: AonSpacing.space3),
          Text(
            l.mapFavoritesEmpty,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AonSpacing.space1),
          Text(
            l.mapFavoritesEmptyHint,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.aon.contentSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// A saved activity. Its venue supplies the map destination — Show on Map and
/// Directions route to `venue:<id>`, the same key its detail sheet uses.
class _SavedEventCard extends ConsumerWidget {
  const _SavedEventCard({required this.event});
  final AonEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AonL10n.of(context);
    final theme = Theme.of(context);
    final venue = ref.watch(venueByIdProvider(event.venueId));

    final subtitle = [
      if (venue != null) Bidi.isolate(venue.name),
      TimeFormat.allSessionsLabel(l, event),
    ].join(' · ');

    return Card(
      key: Key('favorite-event-${event.id}'),
      margin: const EdgeInsets.only(bottom: AonSpacing.space3),
      child: Padding(
        padding: const EdgeInsets.all(AonSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.star_rounded,
                  color: context.aon.accent,
                  size: AonSpacing.iconMd,
                ),
                const SizedBox(width: AonSpacing.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event.title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: context.aon.contentSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // A verified map destination only. No coordinate → no fake nav.
            if (venue != null && venue.hasCoordinates) ...[
              const SizedBox(height: AonSpacing.space3),
              PlaceActionButtons(
                placeKey: 'venue:${event.venueId}',
                beforeNavigate: () => Navigator.of(context).pop(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A place the visitor favourited on the map. Kept even when it can't resolve
/// yet (registry still loading) — a pending row is never silently dropped (G6).
class _FavoritePlaceCard extends ConsumerWidget {
  const _FavoritePlaceCard({required this.placeKey});
  final String placeKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AonL10n.of(context);
    final theme = Theme.of(context);
    final resolved = ref.watch(placeResolverProvider(placeKey));

    Widget shell({required Widget child}) => Card(
      key: Key('favorite-place-$placeKey'),
      margin: const EdgeInsets.only(bottom: AonSpacing.space3),
      child: Padding(
        padding: const EdgeInsets.all(AonSpacing.space4),
        child: child,
      ),
    );

    return resolved.when(
      loading: () => shell(
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AonSpacing.space3),
            Text(l.mapFavoritesLoading),
          ],
        ),
      ),
      error: (_, _) => shell(child: Text(l.mapFavoriteUnavailable)),
      data: (place) {
        if (place == null) {
          return shell(child: Text(l.mapFavoriteUnavailable));
        }
        final listOnly = place.renderPoint == null;
        return shell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    listOnly
                        ? Icons.location_off_rounded
                        : Icons.place_rounded,
                    color: listOnly
                        ? context.aon.contentTertiary
                        : context.aon.accent,
                    size: AonSpacing.iconMd,
                  ),
                  const SizedBox(width: AonSpacing.space3),
                  Expanded(
                    child: Text(
                      Bidi.isolate(place.title),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: l.mapFavoriteRemove,
                    icon: const Icon(Icons.favorite_rounded),
                    onPressed: () =>
                        ref.read(favoritesProvider.notifier).toggle(placeKey),
                  ),
                ],
              ),
              if (listOnly)
                Padding(
                  padding: const EdgeInsets.only(top: AonSpacing.space1),
                  child: Text(
                    l.mapPlaceListOnly,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.aon.contentTertiary,
                    ),
                  ),
                )
              else ...[
                const SizedBox(height: AonSpacing.space3),
                PlaceActionButtons(
                  placeKey: placeKey,
                  beforeNavigate: () => Navigator.of(context).pop(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
