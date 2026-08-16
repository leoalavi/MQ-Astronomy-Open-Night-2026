import 'package:flutter/material.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/config/event_config.dart';
import 'package:aon2026/widgets/map_mode_toggle.dart';
import 'package:aon2026/widgets/nav_metrics.dart';
import 'package:aon2026/widgets/panorama_building_picker.dart';
import 'package:aon2026/models/campus_geometry.dart';
import 'package:aon2026/models/venue.dart';
import 'package:aon2026/services/campus_projection.dart';
import 'package:aon2026/services/location_providers.dart';
import 'package:aon2026/services/maps_nav_providers.dart';
import 'package:aon2026/services/providers.dart';
import 'package:aon2026/utils/time_format.dart';
import 'package:aon2026/utils/venue_style.dart';
import 'package:aon2026/services/map_placement.dart';
import 'package:aon2026/services/search_providers.dart';
import 'package:aon2026/widgets/building_sheet.dart';
import 'package:aon2026/widgets/campus_basemap_layer.dart';
import 'package:aon2026/widgets/campus_search_sheet.dart';
import 'package:aon2026/widgets/campus_variant_picker.dart';
import 'package:aon2026/widgets/confidence_note.dart';
import 'package:aon2026/widgets/favorites_sheet.dart';
import 'package:aon2026/widgets/map_category_filter_bar.dart';
import 'package:aon2026/widgets/map_config.dart';
import 'package:aon2026/widgets/map_control_island.dart';
import 'package:aon2026/widgets/locate_button.dart';
import 'package:aon2026/widgets/user_location_layer.dart';

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
  MapMode _mode = MapMode.campusMap;
  static const CampusProjection _proj = CampusProjection();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AonL10n.of(context);
    final venues = ref.watch(venuesProvider);
    final parking = ref.watch(parkingProvider);
    final loc = ref.watch(locationControllerProvider);

    // Project the current fix ONCE (null off the illustrated footprint — never
    // clamped). Reused by the dot, the accuracy circle, and the note.
    final fix = loc.fix;
    final projected = fix == null ? null : _proj.project(GpsPoint(fix.position));

    // Current search/favorites selection (a stable PlaceKey). A selected venue
    // decorates its existing pin; a selected building gets a transient marker.
    final selectedKey = ref.watch(selectedPlaceKeyProvider);
    final selectedBuilding = (selectedKey != null && selectedKey.startsWith('building:'))
        ? ref.watch(placeResolverProvider(selectedKey)).asData?.value
        : null;

    // Follow-me recenter. Unconditional at the top of build (Riverpod requires
    // ref.listen every build) — never inside a mode branch. The inherited
    // !isLowAccuracy guard stops a fuzzy estimate from yanking the camera
    // (Phase A §5.1). Under CrsSimple the camera moves to the PROJECTED point;
    // `mp != null` (on-footprint) subsumes the old isNearCampus check.
    ref.listen(locationControllerProvider, (_, s) {
      if (s.following && s.fix != null && !s.fix!.isLowAccuracy) {
        final mp = _proj.project(GpsPoint(s.fix!.position));
        if (mp != null) _controller.move(mp.value, _controller.camera.zoom);
      }
    });

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
          if (_proj.project(GpsPoint(LatLng(p.latitude!, p.longitude!)))
              case final CampusMapPoint pt)
            Marker(
              point: pt.value,
              width: 44,
              height: 44,
              child: _MarkerPin(
                icon: Icons.local_parking_rounded,
                color: context.aon.mapParking,
                semanticLabel: '${p.name}. Parking.',
                onTap: () => _showParkingSheet(p.id),
              ),
            ),
      for (final v in visibleVenues)
        if (_venueMarker(v, selectedKey) case final Marker m) m,
    ];

    // G8: transient marker for a selected BUILDING (buildings aren't on the
    // always-on layer). Placed via the resolver's renderPoint (pixel-exact).
    final selectedBuildingMarker = (selectedBuilding?.renderPoint != null)
        ? Marker(
            point: selectedBuilding!.renderPoint!.value,
            width: 56,
            height: 56,
            child: _MarkerPin(
              icon: Icons.business_rounded,
              color: context.aon.accent,
              semanticLabel: selectedBuilding.title,
              onTap: () => _openDetail(selectedBuilding.placeKey),
              selected: true,
            ),
          )
        : null;

    return Scaffold(
      // Content-page AppBar stays opaque (governance rule 4). Recentre moved to
      // the floating glass control island over the tiles (Phase 2).
      appBar: AppBar(
        title: Text(l.mapTitle),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AonSpacing.space3),
            child: Center(
              child: MapModeToggle(
                value: _mode,
                onChanged: (m) => setState(() => _mode = m),
              ),
            ),
          ),
          if (_mode == MapMode.panorama)
            Expanded(
              child: PanoramaBuildingPicker(
                onOpen: (id) => context.push(Routes.panoramaFor(id)),
              ),
            )
          else ...[
          MapCategoryFilterBar(
            selected: _visible,
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
                    // CrsSimple illustrated campus basemap (Map Parity M1).
                    // initialCameraFit is authoritative — it takes precedence
                    // over initialCenter/initialZoom, so those are dropped.
                    crs: const CrsSimple(),
                    initialCameraFit: CameraFit.bounds(
                      bounds: MapConfig.mapBounds,
                      padding: const EdgeInsets.all(12),
                      minZoom: MapConfig.mapMinZoom,
                      maxZoom: MapConfig.mapMaxZoom,
                    ),
                    // initialCameraFit runs before the map is laid out (size 0),
                    // so it under-fits and the map opens zoomed-in. Re-fit once
                    // the real viewport exists (Map Parity M1, on-device fix).
                    onMapReady: () => _controller.fitCamera(
                      CameraFit.bounds(
                        bounds: MapConfig.mapBounds,
                        padding: const EdgeInsets.all(12),
                        minZoom: MapConfig.mapMinZoom,
                        maxZoom: MapConfig.mapMaxZoom,
                      ),
                    ),
                    minZoom: MapConfig.mapMinZoom,
                    maxZoom: MapConfig.mapMaxZoom,
                    // Keep the campus centred. containCenter (not contain) —
                    // the whole campus is smaller than the viewport at fit
                    // zoom, so `contain` is unsatisfiable; containCenter keeps
                    // the map from being panned away.
                    cameraConstraint: CameraConstraint.containCenter(
                      bounds: MapConfig.mapBounds,
                    ),
                    backgroundColor: context.aon.surfaceBase,
                    // A deliberate user pan exits follow but keeps the dot; a
                    // programmatic follow-move fires this with hasGesture:false,
                    // so it does not self-cancel follow (Phase A §5.7).
                    onPositionChanged: (camera, hasGesture) {
                      if (hasGesture) {
                        ref
                            .read(locationControllerProvider.notifier)
                            .onUserPan();
                      }
                    },
                  ),
                  children: [
                    const CampusBasemapLayer(),
                    // Accuracy circle UNDER the venue pins; dot ON TOP (§5.5).
                    if (loc.active && projected != null)
                      UserLocationCircle(center: projected, fix: fix!),
                    MarkerLayer(markers: markers),
                    if (selectedBuildingMarker != null)
                      MarkerLayer(markers: [selectedBuildingMarker]),
                    if (loc.active && projected != null)
                      UserLocationDot(center: projected),
                  ],
                ),
                // One status note: off-campus takes priority over low-accuracy.
                if (loc.active && loc.fix != null)
                  if (!MapConfig.isNearCampus(loc.fix!.position))
                    Positioned(
                      top: AonSpacing.space4,
                      // Clear the top-left Layers button AND the top-right
                      // control island — both are minTapTarget wide.
                      left: AonSpacing.space4 + AonSpacing.minTapTarget,
                      right: AonSpacing.space4 + AonSpacing.minTapTarget,
                      child: _MapNote(
                        text: l.mapOffCampus(
                          (MapConfig.distanceFromCampusMeters(
                                      loc.fix!.position) /
                                  1000)
                              .toStringAsFixed(1),
                        ),
                      ),
                    )
                  else if (loc.fix!.isLowAccuracy)
                    Positioned(
                      top: AonSpacing.space4,
                      left: AonSpacing.space4 + AonSpacing.minTapTarget,
                      right: AonSpacing.space4 + AonSpacing.minTapTarget,
                      child: _MapNote(text: l.mapLowAccuracy),
                    )
                  // Near campus but off the illustrated footprint: honest note,
                  // never a fake dot at a clamped edge.
                  else if (projected == null)
                    Positioned(
                      top: AonSpacing.space4,
                      left: AonSpacing.space4 + AonSpacing.minTapTarget,
                      right: AonSpacing.space4 + AonSpacing.minTapTarget,
                      child: _MapNote(text: l.mapLocatingOnCampus),
                    ),
                Positioned(
                  left: AonSpacing.space2,
                  bottom: AonNavMetrics.clearance(context) - AonSpacing.space4,
                  child: const _MapAttribution(),
                ),
                // Floating glass control island over the live tiles — the Phase 2
                // refraction payoff. Right edge, upper map area: clear of the
                // bottom-right FAB and the filter row above.
                Positioned(
                  top: AonSpacing.space4,
                  right: AonSpacing.space4,
                  child: MapControlIsland(
                    onZoomIn: () => _controller.move(
                      _controller.camera.center,
                      clampZoom(
                        _controller.camera.zoom,
                        1,
                        min: MapConfig.mapMinZoom,
                        max: MapConfig.mapMaxZoom,
                      ),
                    ),
                    onZoomOut: () => _controller.move(
                      _controller.camera.center,
                      clampZoom(
                        _controller.camera.zoom,
                        -1,
                        min: MapConfig.mapMinZoom,
                        max: MapConfig.mapMaxZoom,
                      ),
                    ),
                    locateButton: const LocateButton(),
                  ),
                ),
                // Top-left control column (G18): Layers (M2), Search, Favorites.
                // One minTapTarget-wide stack, mirroring the top-right island;
                // the status notes clear it via `left: space4 + minTapTarget`.
                // This whole Stack only builds in MapMode.campusMap.
                Positioned(
                  top: AonSpacing.space4,
                  left: AonSpacing.space4,
                  child: Column(
                    children: [
                      _GlassMapButton(
                        icon: Icons.layers_rounded,
                        tooltip: l.mapLayersTitle,
                        onTap: () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          builder: (_) => const CampusVariantPicker(),
                        ),
                      ),
                      const SizedBox(height: AonSpacing.space2),
                      _GlassMapButton(
                        icon: Icons.search_rounded,
                        tooltip: l.mapSearchTooltip,
                        onTap: _openSearch,
                      ),
                      const SizedBox(height: AonSpacing.space2),
                      _GlassMapButton(
                        icon: Icons.favorite_rounded,
                        tooltip: l.mapFavoritesTooltip,
                        onTap: _openFavorites,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ],
        ],
      ),
      floatingActionButton: _mode == MapMode.panorama
          ? null
          : Padding(
        padding: EdgeInsets.only(
          bottom: AonNavMetrics.clearance(context) - AonSpacing.space3,
        ),
        child: FloatingActionButton.extended(
          onPressed: () => context.push(Routes.wayfinding),
          backgroundColor: context.aon.accent,
          foregroundColor: context.aon.onAccent,
          icon: const Icon(Icons.directions_walk_rounded),
          label: Text(l.wayfindingDirections),
        ),
      ),
    );
  }

  Marker? _venueMarker(Venue v, String? selectedKey) {
    // G14: linked venues place pixel-exact; unlinked keep GPS-affine — via the
    // single shared placement helper (also used by placeResolver).
    final pt = placeVenue(v, _proj);
    if (pt == null) return null; // off the illustrated footprint (integrity-gated)
    // G8: a selected venue decorates its EXISTING pin (bigger ring), never adds
    // a second marker.
    final selected = selectedKey == 'venue:${v.id}';
    final size = selected ? 56.0 : 44.0;
    return Marker(
      point: pt.value,
      width: size,
      height: size,
      child: _MarkerPin(
        icon: VenueStyle.iconFor(v.category),
        color: VenueStyle.colorFor(context, v.category),
        label: v.mapReference,
        semanticLabel: '${v.name}. ${v.category.label}.',
        onTap: () => _showVenueSheet(v.id),
        selected: selected,
      ),
    );
  }

  void _showVenueSheet(String venueId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => VenueSheet(venueId: venueId),
    );
  }

  void _showParkingSheet(String parkingId) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => ParkingSheet(parkingId: parkingId),
    );
  }

  // ── Search / Favorites orchestration (§0b.F pop→orchestrate) ──

  Future<void> _openSearch() async {
    final key = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const CampusSearchSheet(),
    );
    ref.read(mapSearchQueryProvider.notifier).setQuery(''); // G16: fresh next open
    if (key != null && mounted) await _onPlaceSelected(key);
  }

  Future<void> _openFavorites() async {
    final key = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const FavoritesSheet(),
    );
    if (key != null && mounted) await _onPlaceSelected(key);
  }

  Future<void> _onPlaceSelected(String key) async {
    ref.read(selectedPlaceKeyProvider.notifier).select(key);
    final rp = ref.read(placeResolverProvider(key)).asData?.value?.renderPoint;
    if (rp != null) _controller.move(rp.value, _controller.camera.zoom);
    await _openDetail(key);
    if (mounted) ref.read(selectedPlaceKeyProvider.notifier).clear(); // G15
  }

  Future<void> _openDetail(String key) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => key.startsWith('building:')
            ? BuildingSheet(buildingId: key.substring('building:'.length))
            : VenueSheet(venueId: key.substring('venue:'.length)),
      );
}

class _MarkerPin extends StatelessWidget {
  const _MarkerPin({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.semanticLabel,
    this.label,
    this.selected = false,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  /// Whether this pin is the current selection (decorated, not duplicated — G8).
  final bool selected;

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
            color: context.aon.surfaceBase,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: selected ? 4.0 : 2.5),
            boxShadow: [
              const BoxShadow(color: Color(0x8805070F), blurRadius: 6),
              if (selected) BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 12),
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

/// A glass map-control button in the top-left control column (G18) — Layers,
/// Search, Favorites. `minTapTarget`-sized; the IconButton owns the sole
/// semantics node (its `tooltip` is the accessible name + button role).
class _GlassMapButton extends StatelessWidget {
  const _GlassMapButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AonSpacing.minTapTarget,
      height: AonSpacing.minTapTarget,
      decoration: BoxDecoration(
        color: context.aon.surfaceBase.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(AonSpacing.radiusMd),
        boxShadow: const [BoxShadow(color: Color(0x8805070F), blurRadius: 6)],
      ),
      child: IconButton(
        onPressed: onTap,
        tooltip: tooltip,
        icon: Icon(icon, color: context.aon.contentSecondary),
      ),
    );
  }
}

/// A small content-tier status pill over the map (off-campus / low-accuracy).
/// Solid surface, never glass — it must stay legible over live tiles. The text
/// wraps so it never overflows at 320×568 / 2.0.
class _MapNote extends StatelessWidget {
  const _MapNote({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AonSpacing.space3, vertical: AonSpacing.space2),
      decoration: BoxDecoration(
        color: context.aon.surfaceBase.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AonSpacing.radiusSm),
        boxShadow: const [BoxShadow(color: Color(0x8805070F), blurRadius: 6)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline_rounded,
              size: AonSpacing.iconSm, color: context.aon.contentSecondary),
          const SizedBox(width: AonSpacing.space2),
          Flexible(
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: context.aon.contentSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// The campus basemap is Macquarie University's illustrated map (Map Parity M1
/// replaced the OSM tiles), so it — not OSM — is credited on the map.
class _MapAttribution extends StatelessWidget {
  const _MapAttribution();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: context.aon.surfaceBase.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(AonSpacing.radiusSm),
      ),
      child: Text(
        'Campus map © Macquarie University',
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: context.aon.contentTertiary, fontSize: 11),
      ),
    );
  }
}

@visibleForTesting
class VenueSheet extends ConsumerWidget {
  const VenueSheet({super.key, required this.venueId});

  final String venueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AonL10n.of(context);
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
                color: VenueStyle.colorFor(context, venue.category),
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
                  ?.copyWith(color: context.aon.contentSecondary),
            ),
          ],
          if (venue.notes != null) ...[
            const SizedBox(height: AonSpacing.space3),
            Text(
              venue.notes!,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: context.aon.contentSecondary),
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
              label: Text(l.mapWalkingDirections),
            ),
          ),

          // M4 augment: an embedded Google walking route, in ADDITION to the
          // curated wayfinding above — only when Google nav is configured.
          if (ref.watch(googleNavEnabledProvider)) ...[
            const SizedBox(height: AonSpacing.space3),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push(Routes.googleNavTo('venue:${venue.id}'));
                },
                icon: const Icon(Icons.map_outlined),
                label: Text(l.mapNavGoogle),
              ),
            ),
          ],

          if (venue.hasCoordinates) ...[
            const SizedBox(height: AonSpacing.space3),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push(Routes.pointMeTo(venue.id));
                },
                icon: const Icon(Icons.navigation_rounded),
                label: Text(l.pointMeTitle),
              ),
            ),
          ],

          // 360° entry. Present only when Raouf's panorama layer actually has
          // a tour for this venue id — availability comes from
          // `venuesWithPanoramaProvider`, never from guessing an asset path.
          // No tour => no button, rather than a disabled one that explains
          // nothing.
          if (ref.watch(featuresProvider).panorama &&
              ref.watch(venuesWithPanoramaProvider).contains(venue.id)) ...[
            const SizedBox(height: AonSpacing.space3),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push(Routes.panoramaFor(venue.id));
                },
                icon: const Icon(Icons.threesixty_rounded),
                label: Text(l.mapLookInside360),
              ),
            ),
          ],

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

@visibleForTesting
class ParkingSheet extends ConsumerWidget {
  const ParkingSheet({super.key, required this.parkingId});

  final String parkingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parking = ref.watch(parkingByIdProvider(parkingId));
    if (parking == null) return const SizedBox.shrink();

    final l = AonL10n.of(context);
    final theme = Theme.of(context);
    final routes = ref.watch(routesFromProvider(parkingId));

    return SafeArea(
      child: SingleChildScrollView(
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
                  Icon(
                    Icons.local_parking_rounded,
                    color: context.aon.mapParking,
                  ),
                  const SizedBox(width: AonSpacing.space3),
                  Expanded(
                    child: Text(parking.name,
                        style: theme.textTheme.headlineSmall),
                  ),
                ],
              ),
              if (parking.isFree) ...[
                const SizedBox(height: AonSpacing.space2),
                Text(
                  'Free event parking',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: context.aon.live),
                ),
              ],
              if (parking.notes != null) ...[
                const SizedBox(height: AonSpacing.space3),
                Text(
                  parking.notes!,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: context.aon.contentSecondary),
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
              if (parking.hasCoordinates) ...[
                const SizedBox(height: AonSpacing.space3),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.push(Routes.pointMeTo(parking.id));
                    },
                    icon: const Icon(Icons.navigation_rounded),
                    label: Text(l.pointMeTitle),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
