import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/models/building.dart';
import 'package:aon2026/services/building_providers.dart';
import 'package:aon2026/services/maps_nav_providers.dart';
import 'package:aon2026/utils/bidi.dart';
import 'package:aon2026/widgets/favorite_toggle.dart';
import 'package:aon2026/widgets/nav_metrics.dart';
import 'package:aon2026/utils/haptics.dart';

String buildingCategoryLabel(AonL10n l, BuildingCategory c) => switch (c) {
      BuildingCategory.academic => l.mapCatAcademic,
      BuildingCategory.services => l.mapCatServices,
      BuildingCategory.health => l.mapCatHealth,
      BuildingCategory.food => l.mapCatFood,
      BuildingCategory.sports => l.mapCatSports,
      BuildingCategory.venue => l.mapCatVenue,
      BuildingCategory.research => l.mapCatResearch,
      BuildingCategory.residential => l.mapCatResidential,
      BuildingCategory.parking => l.mapCatParking,
      BuildingCategory.transport => l.mapCatTransport,
      BuildingCategory.smoking => l.mapCatSmoking,
      BuildingCategory.teaching => l.mapCatTeaching,
      BuildingCategory.other => l.mapCatOther,
    };

/// Detail sheet for a registry building. Small content → SingleChildScrollView
/// is appropriate (G19). Directions CTA routes to the existing wayfinding entry
/// in M3; M4 re-points it to the embedded Google Map.
class BuildingSheet extends ConsumerWidget {
  const BuildingSheet({super.key, required this.buildingId});
  final String buildingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AonL10n.of(context);
    final theme = Theme.of(context);
    Building? b;
    for (final x in ref.watch(buildingsProvider).asData?.value ?? const <Building>[]) {
      if (x.id == buildingId) {
        b = x;
        break;
      }
    }
    if (b == null) return const SizedBox.shrink();
    final building = b;

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          // Bottom = the shell's clearance, not a fixed gap: `extendBody: true`
          // runs the floating glass island over the base of every sheet, and a
          // plain space6 left the directions CTA under it (Pouya, 2026-09-08).
          padding: EdgeInsets.fromLTRB(
              AonSpacing.space5, AonSpacing.space4, AonSpacing.space5,
              AonNavMetrics.clearance(context)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.business_rounded, color: context.aon.contentSecondary),
                  const SizedBox(width: AonSpacing.space3),
                  Expanded(
                    child: Text(Bidi.isolate(building.name), style: theme.textTheme.headlineSmall),
                  ),
                  FavoriteToggle(placeKey: 'building:${building.id}'),
                ],
              ),
              const SizedBox(height: AonSpacing.space1),
              Text(
                Bidi.joinIsolated(
                    [building.code, buildingCategoryLabel(l, building.category)]),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: context.aon.contentSecondary),
              ),
              if (building.gridRef != null) ...[
                const SizedBox(height: AonSpacing.space1),
                Text(l.mapBuildingGridRef(building.gridRef!),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: context.aon.contentTertiary)),
              ],
              const SizedBox(height: AonSpacing.space4),
              _BuildingDirectionsButton(building: building),
            ],
          ),
        ),
      ),
    );
  }
}

/// The building directions CTA (M4 augment).
/// - Google nav configured → "Walking directions" opens the embedded Google
///   nav screen (which itself handles a building with no routing coords).
/// - Otherwise → "Open in Google Maps" launches the keyless external directions
///   URL, but ONLY when the building has geographic coords. A pixel-only
///   building (no lat/lng) with no keys has no routing capability, so no button
///   is shown rather than a broken one. Never routes to the curated wayfinding
///   screen (it only handles parking→venue, not arbitrary buildings).
class _BuildingDirectionsButton extends ConsumerWidget {
  const _BuildingDirectionsButton({required this.building});
  final Building building;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AonL10n.of(context);
    // In-app embedded walking directions ONLY. When Google nav isn't available
    // on this build/platform we show no directions button rather than bouncing
    // the visitor out to the external Google Maps app (product requirement
    // 2026-08-30: users always stay inside AON).
    if (ref.watch(googleNavEnabledProvider)) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () {
            AonHaptics.tap();
            Navigator.of(context).pop();
            context.push(Routes.googleNavTo('building:${building.id}'));
          },
          icon: const Icon(Icons.directions_walk_rounded),
          label: Text(l.mapWalkingDirections),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
