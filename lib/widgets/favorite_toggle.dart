import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/services/favorites_providers.dart';

/// Heart toggle for a `PlaceKey`. One semantics node via the IconButton's
/// state-aware tooltip (announces add vs remove).
class FavoriteToggle extends ConsumerWidget {
  const FavoriteToggle({super.key, required this.placeKey});
  final String placeKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AonL10n.of(context);
    final isFav = ref.watch(favoritesProvider).keys.contains(placeKey);
    return IconButton(
      onPressed: () => ref.read(favoritesProvider.notifier).toggle(placeKey),
      tooltip: isFav ? l.mapFavoriteRemove : l.mapFavoriteAdd,
      icon: Icon(
        isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        color: isFav ? context.aon.accent : context.aon.contentSecondary,
      ),
    );
  }
}
