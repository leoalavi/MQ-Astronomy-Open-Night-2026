import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/models/building.dart';
import 'package:aon2026/services/building_providers.dart';
import 'package:aon2026/widgets/favorite_toggle.dart';

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
          padding: const EdgeInsets.fromLTRB(
              AonSpacing.space5, AonSpacing.space4, AonSpacing.space5, AonSpacing.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.business_rounded, color: context.aon.contentSecondary),
                  const SizedBox(width: AonSpacing.space3),
                  Expanded(
                    child: Text(building.name, style: theme.textTheme.headlineSmall),
                  ),
                  FavoriteToggle(placeKey: 'building:${building.id}'),
                ],
              ),
              const SizedBox(height: AonSpacing.space1),
              Text(
                '${building.code} · ${buildingCategoryLabel(l, building.category)}',
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
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push(Routes.wayfinding);
                  },
                  icon: const Icon(Icons.directions_walk_rounded),
                  label: Text(l.mapWalkingDirections),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
