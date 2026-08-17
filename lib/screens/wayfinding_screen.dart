import 'package:flutter/material.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/utils/bidi.dart';
import 'package:aon2026/models/data_confidence.dart';
import 'package:aon2026/models/walking_route.dart';
import 'package:aon2026/services/providers.dart';
import 'package:aon2026/widgets/confidence_note.dart';
import 'package:aon2026/widgets/dark_tile_layer.dart';
import 'package:aon2026/widgets/empty_state.dart';
import 'package:aon2026/widgets/map_config.dart';

/// Parking-to-venue walking directions.
///
/// The organisers' headline request: attendees get disoriented walking from
/// the car parks to the event after dark. The design answer here is
/// deliberately *not* live turn-by-turn navigation:
///
/// * **Predefined routes, authored once and reviewed by the organisers.** They
///   can encode things no routing engine knows — which paths are lit, which
///   gate is open at 9pm, where the marshals stand.
/// * **Written instructions are the primary output.** They work with the phone
///   at arm's length, they work with a dying battery, and they work when the
///   tile server is unreachable. The map is a supporting visual.
/// * **No GPS.** Requesting location permission would buy us a blue dot whose
///   accuracy between campus buildings is ±20 m — worse than useless for
///   choosing between two paths — in exchange for a permission prompt and a
///   privacy obligation. Not a trade worth making for this MVP.
class WayfindingScreen extends ConsumerStatefulWidget {
  const WayfindingScreen({this.initialDestinationId, super.key});

  final String? initialDestinationId;

  @override
  ConsumerState<WayfindingScreen> createState() => _WayfindingScreenState();
}

class _WayfindingScreenState extends ConsumerState<WayfindingScreen> {
  @override
  void initState() {
    super.initState();
    // Seed the destination from the deep link ("Walk there" on an event),
    // after the first frame so the provider container is ready.
    final destination = widget.initialDestinationId;
    if (destination != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(selectedRouteDestinationProvider.notifier).select(destination);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AonL10n.of(context);
    final theme = Theme.of(context);
    final parking = ref.watch(parkingProvider);
    final routes = ref.watch(routesProvider);

    final fromId = ref.watch(selectedRouteStartProvider);
    final toId = ref.watch(selectedRouteDestinationProvider);
    final route = ref.watch(selectedRouteProvider);

    // Only offer destinations we actually have a route to from the chosen
    // start. Offering an unreachable destination and then apologising is a
    // worse experience than a shorter, honest list.
    final destinationIds = <String>{
      for (final r in routes)
        if (fromId == null || r.fromId == fromId) r.toId,
    };

    final startIds = <String>{
      for (final r in routes)
        if (toId == null || r.toId == toId) r.fromId,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(l.mapWalkingDirections),
        actions: [
          if (fromId != null || toId != null)
            TextButton(
              onPressed: () {
                ref.read(selectedRouteStartProvider.notifier).clear();
                ref.read(selectedRouteDestinationProvider.notifier).clear();
              },
              child: Text(l.wayfindingReset),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AonSpacing.space4,
          AonSpacing.space2,
          AonSpacing.space4,
          AonSpacing.space10,
        ),
        children: [
          // ── Start ──
          Text(l.wayfindingStartingFrom, style: theme.textTheme.titleMedium),
          const SizedBox(height: AonSpacing.space3),
          Wrap(
            spacing: AonSpacing.space2,
            runSpacing: AonSpacing.space2,
            children: [
              for (final p in parking)
                if (startIds.contains(p.id))
                  ChoiceChip(
                    label: Text(p.name),
                    avatar: const Icon(
                      Icons.local_parking_rounded,
                      size: AonSpacing.iconSm,
                    ),
                    selected: fromId == p.id,
                    onSelected: (_) => ref
                        .read(selectedRouteStartProvider.notifier)
                        .toggle(p.id),
                  ),
              // Non-parking origins (Metro, and venue-to-venue hops).
              for (final id in startIds)
                if (parking.every((p) => p.id != id))
                  _VenueChoiceChip(
                    venueId: id,
                    selected: fromId == id,
                    onSelected: () => ref
                        .read(selectedRouteStartProvider.notifier)
                        .toggle(id),
                  ),
            ],
          ),

          const SizedBox(height: AonSpacing.space5),

          // ── Destination ──
          Text(l.wayfindingGoingTo, style: theme.textTheme.titleMedium),
          const SizedBox(height: AonSpacing.space3),
          Wrap(
            spacing: AonSpacing.space2,
            runSpacing: AonSpacing.space2,
            children: [
              for (final id in destinationIds)
                _VenueChoiceChip(
                  venueId: id,
                  selected: toId == id,
                  onSelected: () => ref
                      .read(selectedRouteDestinationProvider.notifier)
                      .toggle(id),
                ),
            ],
          ),

          const SizedBox(height: AonSpacing.space6),

          // ── Result ──
          if (route != null)
            _RouteDetail(route: route)
          else if (fromId != null && toId != null)
            // Both ends chosen but no route exists — a genuinely different
            // message from "you haven't chosen yet".
            EmptyState(
              icon: Icons.wrong_location_rounded,
              title: l.wayfindingNoPairTitle,
              message: l.wayfindingNoPairBody,
            )
          else
            EmptyState(
              icon: Icons.directions_walk_rounded,
              title: l.wayfindingPickTitle,
              message: l.wayfindingPickBody,
            ),
        ],
      ),
    );
  }
}

class _VenueChoiceChip extends ConsumerWidget {
  const _VenueChoiceChip({
    required this.venueId,
    required this.selected,
    required this.onSelected,
  });

  final String venueId;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venue = ref.watch(venueByIdProvider(venueId));
    if (venue == null) return const SizedBox.shrink();

    return ChoiceChip(
      label: Text(Bidi.isolate(venue.chipLabel)),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

class _RouteDetail extends StatelessWidget {
  const _RouteDetail({required this.route});

  final WalkingRoute route;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AonL10n.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Summary header ──
        Container(
          padding: const EdgeInsets.all(AonSpacing.space4),
          decoration: BoxDecoration(
            color: context.aon.surface,
            borderRadius: BorderRadius.circular(AonSpacing.radiusMd),
            border: Border.all(color: context.aon.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.trip_origin_rounded,
                    size: AonSpacing.iconSm,
                    color: context.aon.info,
                  ),
                  const SizedBox(width: AonSpacing.space3),
                  Expanded(
                    child: Text(
                      route.fromLabel,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 2, bottom: 2),
                child: SizedBox(
                  height: 18,
                  child: VerticalDivider(
                    width: 2,
                    thickness: 2,
                    color: context.aon.borderStrong,
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(
                    Icons.place_rounded,
                    size: AonSpacing.iconSm,
                    color: context.aon.accent,
                  ),
                  const SizedBox(width: AonSpacing.space3),
                  Expanded(
                    child: Text(
                      route.toLabel,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
              if (route.walkingMinutes != null ||
                  route.distanceMetres != null) ...[
                const SizedBox(height: AonSpacing.space3),
                const Divider(),
                const SizedBox(height: AonSpacing.space3),
                Row(
                  children: [
                    if (route.walkingMinutes != null)
                      _Stat(
                        icon: Icons.directions_walk_rounded,
                        value: 'About ${route.walkingMinutes} min',
                      ),
                    if (route.distanceMetres != null)
                      _Stat(
                        icon: Icons.straighten_rounded,
                        value: '~${route.distanceMetres} m',
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: AonSpacing.space4),

        // ── Map preview ──
        if (route.hasPolyline) _RouteMap(route: route),
        if (route.hasPolyline) const SizedBox(height: AonSpacing.space4),

        // ── Confidence ──
        ConfidenceNote(
          confidence: route.pathConfidence,
          message: l.wayfindingDraftRoute,
        ),

        const SizedBox(height: AonSpacing.space4),

        // ── Lighting ──
        if (route.lightingNotes != null)
          _InfoRow(
            icon: Icons.lightbulb_outline_rounded,
            color: context.aon.soon,
            text: Bidi.isolate(route.lightingNotes),
          ),

        // ── Accessibility ──
        _InfoRow(
          icon: Icons.accessible_rounded,
          color: context.aon.info,
          text: switch (route.isAccessible) {
            true => Bidi.isolate(route.accessibilityNotes).isEmpty
                ? l.wayfindingStepFree
                : Bidi.isolate(route.accessibilityNotes),
            false => Bidi.isolate(route.accessibilityNotes).isEmpty
                ? l.wayfindingNotStepFree
                : Bidi.isolate(route.accessibilityNotes),
            // `null` is unknown, and must not read as "no".
            null => l.wayfindingStepFreeUnknown,
          },
        ),

        const SizedBox(height: AonSpacing.space5),

        // ── Written steps: the primary output ──
        Text(l.wayfindingDirections, style: theme.textTheme.headlineSmall),
        const SizedBox(height: AonSpacing.space3),
        for (var i = 0; i < route.steps.length; i++)
          _StepRow(index: i + 1, step: route.steps[i]),
      ],
    );
  }
}

class _RouteMap extends StatelessWidget {
  const _RouteMap({required this.route});

  final WalkingRoute route;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDraftGeometry = route.pathConfidence == DataConfidence.placeholder;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AonSpacing.radiusMd),
          child: SizedBox(
            height: 220,
            child: FlutterMap(
              options: MapOptions(
                initialCameraFit: CameraFit.coordinates(
                  coordinates: route.points,
                  padding: const EdgeInsets.all(AonSpacing.space8),
                ),
                minZoom: MapConfig.minZoom,
                maxZoom: MapConfig.maxZoom,
                backgroundColor: context.aon.surfaceBase,
                // A static preview — panning it would just get people lost.
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                const DarkTileLayer(),
                PolylineLayer(
                  polylines: [
                    // Dark casing first, so the route stays legible over any
                    // tile colour.
                    Polyline(
                      points: route.points,
                      strokeWidth: 9,
                      color: context.aon.mapRouteCasing,
                    ),
                    Polyline(
                      points: route.points,
                      strokeWidth: 5,
                      color: context.aon.mapRoute,
                      // Dashed while the geometry is unverified — a solid
                      // line would claim a precision we don't have.
                      pattern: isDraftGeometry
                          ? const StrokePattern.dotted()
                          : const StrokePattern.solid(),
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    _endpoint(context, route.points.first, context.aon.info),
                    _endpoint(context, route.points.last, context.aon.accent),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (isDraftGeometry) ...[
          const SizedBox(height: AonSpacing.space2),
          Text(
            'Straight line shown — this is the general direction, not the '
            'exact path. Follow the written directions below.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.aon.contentTertiary,
            ),
          ),
        ],
      ],
    );
  }

  Marker _endpoint(BuildContext context, LatLng point, Color color) {
    return Marker(
      point: point,
      width: 20,
      height: 20,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: context.aon.surfaceBase, width: 3),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.index, required this.step});

  final int index;
  final RouteStep step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AonSpacing.space4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.aon.surfaceRaised,
              shape: BoxShape.circle,
              border: Border.all(color: context.aon.borderStrong),
            ),
            child: Text(
              '$index',
              style: theme.textTheme.labelMedium?.copyWith(
                color: context.aon.accent,
              ),
            ),
          ),
          const SizedBox(width: AonSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.instruction, style: theme.textTheme.bodyLarge),
                if (step.landmark != null) ...[
                  const SizedBox(height: AonSpacing.space1),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.visibility_outlined,
                        size: AonSpacing.iconSm,
                        color: context.aon.contentTertiary,
                      ),
                      const SizedBox(width: AonSpacing.space2),
                      Expanded(
                        child: Text(
                          step.landmark!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: context.aon.contentTertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AonSpacing.space5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: AonSpacing.iconSm,
            color: context.aon.contentTertiary,
          ),
          const SizedBox(width: AonSpacing.space2),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.aon.contentSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AonSpacing.space3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AonSpacing.iconMd, color: color),
          const SizedBox(width: AonSpacing.space3),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.aon.contentSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
