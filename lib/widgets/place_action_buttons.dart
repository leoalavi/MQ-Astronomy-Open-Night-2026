import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';

/// Compact, paired navigation actions for one verified destination.
///
/// Both actions receive the same stable [placeKey], so the map focus and the
/// embedded walking route cannot drift to different places.
class PlaceActionButtons extends StatelessWidget {
  const PlaceActionButtons({
    required this.placeKey,
    this.beforeNavigate,
    super.key,
  });

  final String placeKey;
  final VoidCallback? beforeNavigate;

  @override
  Widget build(BuildContext context) {
    final l = AonL10n.of(context);

    void navigate(String route, {required bool replace}) {
      // Capture this before a modal callback pops the route that owns context.
      final router = GoRouter.of(context);
      beforeNavigate?.call();
      if (replace) {
        router.go(route);
      } else {
        router.push(route);
      }
    }

    return Wrap(
      spacing: AonSpacing.space2,
      runSpacing: AonSpacing.space2,
      children: [
        OutlinedButton.icon(
          key: Key('show-map-$placeKey'),
          onPressed: () => navigate(Routes.mapFocus(placeKey), replace: true),
          icon: const Icon(Icons.location_on_outlined),
          label: Text(l.actionShowOnMap),
        ),
        OutlinedButton.icon(
          key: Key('directions-$placeKey'),
          onPressed: () =>
              navigate(Routes.googleNavTo(placeKey), replace: false),
          icon: const Icon(Icons.directions_walk_rounded),
          label: Text(l.mapDirections),
        ),
      ],
    );
  }
}
