import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/theme/aon_colors.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/widgets/nav_metrics.dart';
import 'package:aon2026/models/venue.dart';
import 'package:aon2026/services/providers.dart';
import 'package:aon2026/utils/time_format.dart';
import 'package:aon2026/utils/venue_style.dart';
import 'package:aon2026/widgets/confidence_note.dart';
import 'package:aon2026/widgets/dark_tile_layer.dart';
import 'package:aon2026/widgets/map_config.dart';

/// Campus map showing event venues, facilities, parking and transport.
///
/// ## Why flutter_map and not Google Maps
///
/// Inherited from MQ Journey (REUSE WITH MODIFICATION — same package, new
/// implementation). `flutter_map` renders raster tiles with no SDK key, which
/// keeps this repository entirely free of credentials. MQ Journey's own map
/// *widgets* are not reused: they are built around a campus-raster overlay with
/// an affine GPS-to-pixel projection, indoor floorplans and a compass AR mode —
/// roughly 4,000 lines of machinery for features this MVP does not have.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _controller = MapController();
  final Set<VenueCategory> _visible = {...VenueCategory.values};

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final venues = ref.watch(venuesProvider);
    final parking = ref.watch(parkingProvider);

    // Venues without coordinates are intentionally omitted from the map and
    // surfaced in the list sheet instead — see ParkingData / VenuesData.
    //
    // Ordering matters: several facilities sit at the *same* coordinate as the
    // event venue that contains them (the Macquarie Theatre toilets are, of
    // course, at the Macquarie Theatre). MarkerLayer paints in list order, so
    // without this sort the toilet pin lands on top of the "A" venue pin and
    // the venue vanishes. Event venues are painted last so they always win.
    final visibleVenues = venues
        .where((v) => v.hasCoordinates && _visible.contains(v.category))
        .toList()
      ..sort((a, b) {
        int rank(Venue v) => switch (v.category) {
              VenueCategory.eventVenue => 3,
              VenueCategory.registration => 2,
              VenueCategory.informationPoint => 1,
              _ => 0,
            };
        return rank(a).compareTo(rank(b));
      });

    final markers = <Marker>[
      for (final p in parking)
        if (p.hasCoordinates && _visible.contains(VenueCategory.parking))
          Marker(
            point: LatLng(p.latitude!, p.longitude!),
            width: 44,
            height: 44,
            child: _MarkerPin(
              icon: Icons.local_parking_rounded,
              color: AonColors.mapParking,
              semanticLabel: '${p.name}. Parking.',
              onTap: () => _showParkingSheet(p.id),
            ),
          ),
      for (final v in visibleVenues) _venueMarker(v),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Map'),
        actions: [
          IconButton(
            tooltip: 'Recentre',
            icon: const Icon(Icons.my_location_rounded),
            onPressed: () => _controller.move(
              MapConfig.campusCentre,
              MapConfig.initialZoom,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _CategoryFilterBar(
            visible: _visible,
            onToggle: (category) => setState(() {
              _visible.contains(category)
                  ? _visible.remove(category)
                  : _visible.add(category);
            }),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _controller,
                  options: MapOptions(
                    initialCenter: MapConfig.campusCentre,
                    initialZoom: MapConfig.initialZoom,
                    minZoom: MapConfig.minZoom,
                    maxZoom: MapConfig.maxZoom,
                    // Keep the user inside campus. Panning off to the Pacific
                    // and losing every marker is a real way to get lost.
                    cameraConstraint: CameraConstraint.contain(
                      bounds: MapConfig.campusBounds,
                    ),
                    backgroundColor: AonColors.night950,
                  ),
                  children: [
                    const DarkTileLayer(),
                    MarkerLayer(markers: markers),
                  ],
                ),
                Positioned(
                  left: AonSpacing.space2,
                  bottom: AonNavMetrics.clearance(context) - AonSpacing.space4,
                  child: const _MapAttribution(),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: AonNavMetrics.clearance(context) - AonSpacing.space3,
        ),
        child: FloatingActionButton.extended(
          onPressed: () => context.push(Routes.wayfinding),
          backgroundColor: AonColors.amber,
          foregroundColor: AonColors.onAccent,
          icon: const Icon(Icons.directions_walk_rounded),
          label: const Text('Directions'),
        ),
      ),
    );
  }

  Marker _venueMarker(Venue v) {
    return Marker(
      point: LatLng(v.latitude!, v.longitude!),
      width: 44,
      height: 44,
      child: _MarkerPin(
        icon: VenueStyle.iconFor(v.category),
        color: VenueStyle.colorFor(v.category),
        label: v.mapReference,
        semanticLabel: '${v.name}. ${v.category.label}.',
        onTap: () => _showVenueSheet(v.id),
      ),
    );
  }

  void _showVenueSheet(String venueId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _VenueSheet(venueId: venueId),
    );
  }

  void _showParkingSheet(String parkingId) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => _ParkingSheet(parkingId: parkingId),
    );
  }
}

class _MarkerPin extends StatelessWidget {
  const _MarkerPin({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.semanticLabel,
    this.label,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  /// Spoken description for screen readers. The map itself is a raster image,
  /// so without this each pin is an unlabelled tap target to VoiceOver/TalkBack.
  final String semanticLabel;

  /// Printed-map legend letter, shown instead of the icon when present.
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      // The letter/icon inside is decorative once the pin is labelled.
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: AonColors.night950,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2.5),
            boxShadow: const [
              BoxShadow(color: Color(0x8805070F), blurRadius: 6),
            ],
          ),
          alignment: Alignment.center,
          child: label != null
              ? Text(
                  label!,
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: color),
                )
              : Icon(icon, size: AonSpacing.iconMd, color: color),
        ),
      ),
    );
  }
}

class _CategoryFilterBar extends StatelessWidget {
  const _CategoryFilterBar({required this.visible, required this.onToggle});

  final Set<VenueCategory> visible;
  final ValueChanged<VenueCategory> onToggle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AonSpacing.space4),
        children: [
          for (final category in VenueCategory.values)
            if (category != VenueCategory.other) ...[
              FilterChip(
                label: Text(category.label),
                selected: visible.contains(category),
                onSelected: (_) => onToggle(category),
                avatar: Icon(
                  VenueStyle.iconFor(category),
                  size: AonSpacing.iconSm,
                  color: visible.contains(category)
                      ? AonColors.onAccent
                      : VenueStyle.colorFor(category),
                ),
              ),
              const SizedBox(width: AonSpacing.space2),
            ],
        ],
      ),
    );
  }
}

/// OpenStreetMap requires visible attribution wherever its tiles are shown.
class _MapAttribution extends StatelessWidget {
  const _MapAttribution();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AonColors.night950.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(AonSpacing.radiusSm),
      ),
      child: Text(
        '© OpenStreetMap contributors',
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: AonColors.contentTertiary, fontSize: 11),
      ),
    );
  }
}

class _VenueSheet extends ConsumerWidget {
  const _VenueSheet({required this.venueId});

  final String venueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final venue = ref.watch(venueByIdProvider(venueId));
    if (venue == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final events = ref.watch(eventsAtVenueProvider(venueId));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      maxChildSize: 0.9,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(
          AonSpacing.space5,
          0,
          AonSpacing.space5,
          AonSpacing.space6,
        ),
        children: [
          Row(
            children: [
              Icon(
                VenueStyle.iconFor(venue.category),
                color: VenueStyle.colorFor(venue.category),
              ),
              const SizedBox(width: AonSpacing.space3),
              Expanded(
                child: Text(venue.name, style: theme.textTheme.headlineSmall),
              ),
            ],
          ),
          if (venue.building != null && venue.building != venue.name) ...[
            const SizedBox(height: AonSpacing.space1),
            Text(
              venue.building!,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: AonColors.contentSecondary),
            ),
          ],
          if (venue.notes != null) ...[
            const SizedBox(height: AonSpacing.space3),
            Text(
              venue.notes!,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: AonColors.contentSecondary),
            ),
          ],
          const SizedBox(height: AonSpacing.space3),
          ConfidenceNote(confidence: venue.coordinateConfidence),

          const SizedBox(height: AonSpacing.space4),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                context.push(Routes.wayfindingTo(venue.id));
              },
              icon: const Icon(Icons.directions_walk_rounded),
              label: const Text('Walking directions'),
            ),
          ),

          if (events.isNotEmpty) ...[
            const SizedBox(height: AonSpacing.space5),
            Text('On here tonight', style: theme.textTheme.titleMedium),
            const SizedBox(height: AonSpacing.space2),
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
        ],
      ),
    );
  }
}

class _ParkingSheet extends ConsumerWidget {
  const _ParkingSheet({required this.parkingId});

  final String parkingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parking = ref.watch(parkingByIdProvider(parkingId));
    if (parking == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final routes = ref.watch(routesFromProvider(parkingId));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AonSpacing.space5,
          0,
          AonSpacing.space5,
          AonSpacing.space6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.local_parking_rounded,
                  color: AonColors.mapParking,
                ),
                const SizedBox(width: AonSpacing.space3),
                Text(parking.name, style: theme.textTheme.headlineSmall),
              ],
            ),
            if (parking.isFree) ...[
              const SizedBox(height: AonSpacing.space2),
              Text(
                'Free event parking',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: AonColors.live),
              ),
            ],
            if (parking.notes != null) ...[
              const SizedBox(height: AonSpacing.space3),
              Text(
                parking.notes!,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: AonColors.contentSecondary),
              ),
            ],
            const SizedBox(height: AonSpacing.space3),
            ConfidenceNote(confidence: parking.coordinateConfidence),
            if (routes.isNotEmpty) ...[
              const SizedBox(height: AonSpacing.space4),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push(Routes.wayfinding);
                  },
                  icon: const Icon(Icons.directions_walk_rounded),
                  label: Text('${routes.length} walking routes from here'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
