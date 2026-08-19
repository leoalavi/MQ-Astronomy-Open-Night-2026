import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/services/favorites_providers.dart';
import 'package:aon2026/services/search_providers.dart';

/// Favourites list. Layout is `Column(header, Expanded(ListView))` (G19).
/// A key that can't resolve YET (registry still loading) shows a pending row —
/// it is NEVER dropped (G6); only a confirmed-absent key reads "unavailable".
class FavoritesSheet extends ConsumerWidget {
  const FavoritesSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AonL10n.of(context);
    final keys = ref.watch(favoritesProvider).keys.toList()..sort();

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AonSpacing.space5, AonSpacing.space4,
                AonSpacing.space5, AonSpacing.space2),
            child: Text(l.mapFavoritesTitle,
                style: Theme.of(context).textTheme.titleLarge),
          ),
          if (keys.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AonSpacing.space5),
              child: Text(l.mapFavoritesEmpty,
                  style: TextStyle(color: context.aon.contentSecondary)),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: keys.length,
                itemBuilder: (context, i) => _FavoriteRow(placeKey: keys[i]),
              ),
            ),
        ],
      ),
    );
  }
}

class _FavoriteRow extends ConsumerWidget {
  const _FavoriteRow({required this.placeKey});
  final String placeKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AonL10n.of(context);
    final resolved = ref.watch(placeResolverProvider(placeKey));
    return resolved.when(
      loading: () => ListTile(
        leading: const SizedBox(
            width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        title: Text(l.mapFavoritesLoading), // G6: pending, not dropped
      ),
      error: (_, _) => ListTile(title: Text(l.mapFavoriteUnavailable)),
      data: (place) => place == null
          ? ListTile(
              leading: const Icon(Icons.help_outline_rounded),
              title: Text(l.mapFavoriteUnavailable)) // confirmed-absent (kept, not dropped)
          : ListTile(
              // A favourite with no map coordinate is list-only — encode it by
              // icon + hint, not a normal pin that pans nowhere (map audit P2).
              leading: place.renderPoint == null
                  ? Icon(Icons.location_off_rounded, color: context.aon.contentTertiary)
                  : Icon(Icons.place_rounded, color: context.aon.accent),
              title: Text(place.title),
              subtitle: place.renderPoint == null
                  ? Text(l.mapPlaceListOnly,
                      style: TextStyle(color: context.aon.contentTertiary))
                  : (place.subtitle == null ? null : Text(place.subtitle!)),
              trailing: FavoriteToggleTrailing(placeKey: placeKey),
              onTap: () => Navigator.of(context).pop(placeKey),
            ),
    );
  }
}

/// A small remove control on a favourites row.
class FavoriteToggleTrailing extends ConsumerWidget {
  const FavoriteToggleTrailing({super.key, required this.placeKey});
  final String placeKey;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AonL10n.of(context);
    return IconButton(
      tooltip: l.mapFavoriteRemove,
      icon: const Icon(Icons.favorite_rounded),
      onPressed: () => ref.read(favoritesProvider.notifier).toggle(placeKey),
    );
  }
}
