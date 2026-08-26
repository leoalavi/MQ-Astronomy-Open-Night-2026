import 'package:flutter/material.dart';
import 'dart:async';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/utils/timing_labels.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/config/event_config.dart';
import 'package:aon2026/widgets/compass_mode_view.dart';
import 'package:aon2026/widgets/map_mode_toggle.dart';
import 'package:aon2026/widgets/nav_metrics.dart';
import 'package:aon2026/widgets/preview_location_badge.dart';
import 'package:aon2026/widgets/panorama_building_picker.dart';
import 'package:aon2026/models/campus_geometry.dart';
import 'package:aon2026/models/venue.dart';
import 'package:aon2026/services/campus_projection.dart';
import 'package:aon2026/services/location_providers.dart';
import 'package:aon2026/services/providers.dart';
import 'package:aon2026/utils/time_format.dart';
import 'package:aon2026/utils/venue_style.dart';
import 'package:aon2026/services/map_branch_lifecycle.dart';
import 'package:aon2026/services/map_placement.dart';
import 'package:aon2026/services/search_providers.dart';
import 'package:aon2026/widgets/building_sheet.dart';
import 'package:aon2026/widgets/campus_basemap_layer.dart';
import 'package:aon2026/widgets/campus_search_sheet.dart';
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
  const MapScreen({super.key, this.focusPlaceKey});

  /// A place key ("venue:x" / "building:y") to open focused on, supplied by
  /// `Routes.mapFocus` from every "Show on map" action.
  final String? focusPlaceKey;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _controller = MapController();
  final Set<VenueCategory> _visible = {...VenueCategory.values};
  MapMode _mode = MapMode.campusMap;
  static const CampusProjection _proj = CampusProjection();

  /// The focus request already handled, so a rebuild (filter toggle, location
  /// tick, keyboard) does not re-open the sheet under the visitor. Reset once
  /// the focus is consumed (see [_maybeHandleFocus]) so a repeat "Show on map"
  /// for the SAME place fires again rather than being swallowed by the latch.
  String? _handledFocus;

  @override
  void initState() {
    super.initState();
    _maybeHandleFocus();
  }

  @override
  void didUpdateWidget(covariant MapScreen old) {
    super.didUpdateWidget(old);
    // Tapping "Show on map" for a DIFFERENT venue while the tab is already
    // alive arrives as a widget update, not a fresh state.
    if (widget.focusPlaceKey != old.focusPlaceKey) _maybeHandleFocus();
  }

  /// Selects the requested place, moves the camera onto it and opens its sheet.
  /// Deferred to after the first frame so the map has a real viewport to move.
  void _maybeHandleFocus() {
    final key = widget.focusPlaceKey;
    if (key == null || key == _handledFocus) return;
    _handledFocus = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Focus is a campus-map concept; a pending 360°/compass mode would hide it.
      if (_mode != MapMode.campusMap) setState(() => _mode = MapMode.campusMap);
      _onPlaceSelected(key, zoom: MapConfig.mapFocusZoom);
      // Consume the focus. The Map tab is kept alive by the StatefulShellRoute
      // indexedStack, so without this a repeat "Show on map" for the SAME place
      // is inert: go_router sees an identical `/map?focus=X` location (no
      // rebuild) and the latch would block it anyway. Reset the latch AND strip
      // `?focus=` by REPLACEMENT — not a push, so no phantom history entry —
      // so the next tap is a genuine navigation change that fires afresh.
      _handledFocus = null;
      context.replace(Routes.map);
    });
  }

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

    // Leaving the Map tab discards the transient exploration state, so coming
    // back lands on a clean map rather than a venue selected minutes ago on a
    // different errand. The branch stays mounted in the shell's IndexedStack,
    // so nothing clears itself — see map_branch_lifecycle.dart.
    ref.listen<bool>(mapVisibleProvider, (wasVisible, isVisible) {
      if (shouldResetMapExplorationOnBranchChange(
        wasVisible: wasVisible,
        isVisible: isVisible,
        // AON's map is only ever a shell branch today; the flag keeps the
        // ported contract intact if a pushed map is ever added.
        isPushedEntry: false,
      )) {
        ref.read(mapSelectionProvider.notifier).clear();
        _handledFocus = null; // let a later Show-on-map for the same venue work
      }
    });

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
                semanticLabel: '${p.name}. ${l.venueCatParking}.',
                onTap: () => _showParkingSheet(p.id),
              ),
            ),
      for (final v in visibleVenues)
        if (_venueMarker(v, selectedKey, l) case final Marker m) m,
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
          else if (_mode == MapMode.compass)
            const Expanded(child: CompassModeView()) // M5 (§0-A/§0.4)
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
                LayoutBuilder(
                  builder: (context, constraints) {
                    // STRICT zoom-OUT floor for THIS viewport (Pouya): the map
                    // can never shrink below COVERING its box (fills the screen,
                    // long edges crop — Raouf's choice over black letterbox
                    // bands). Wired as flutter_map's native, idempotent
                    // MapOptions.minZoom — a zoom-clamping CameraConstraint breaks
                    // its option-change invariant. Clamped to the absolute
                    // [mapMinZoom, mapMaxZoom] range so minZoom <= maxZoom holds.
                    final minZoom = MapConfig
                        .minZoomForViewport(constraints.biggest)
                        .clamp(MapConfig.mapMinZoom, MapConfig.mapMaxZoom);
                    return FlutterMap(
                      mapController: _controller,
                      options: MapOptions(
                        // CrsSimple illustrated campus basemap (Map Parity M1).
                        // initialCameraFit is authoritative — it takes precedence
                        // over initialCenter/initialZoom, so those are dropped.
                        crs: const CrsSimple(),
                        initialCameraFit: CameraFit.bounds(
                          bounds: MapConfig.aonMapBounds,
                          padding: MapConfig.mapFitPadding,
                          minZoom: minZoom,
                          maxZoom: MapConfig.mapMaxZoom,
                        ),
                        // initialCameraFit runs before the map is laid out (size
                        // 0), so it under-fits and the map opens zoomed-in. Re-fit
                        // once the real viewport exists (Map Parity M1).
                        onMapReady: () => _controller.fitCamera(
                          CameraFit.bounds(
                            bounds: MapConfig.aonMapBounds,
                            padding: MapConfig.mapFitPadding,
                            minZoom: minZoom,
                            maxZoom: MapConfig.mapMaxZoom,
                          ),
                        ),
                        minZoom: minZoom,
                        maxZoom: MapConfig.mapMaxZoom,
                        // North-up only: the official artwork is unreadable rotated.
                        interactionOptions: const InteractionOptions(
                          flags: MapConfig.mapInteractiveFlags,
                        ),
                        // Per-axis contain-or-centre: the artwork can never be
                        // dragged off into empty background, and it stays centred
                        // at zoom levels where it is smaller than the viewport.
                        cameraConstraint: ContainOrCentreCamera(
                          bounds: MapConfig.aonMapBounds,
                        ),
                        backgroundColor: context.aon.surfaceBase,
                        // A deliberate user pan exits follow but keeps the dot; a
                        // programmatic follow-move fires with hasGesture:false, so
                        // it does not self-cancel follow (Phase A §5.7).
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
                    );
                  },
                ),
                // One status note: off-campus takes priority over low-accuracy.
                if (loc.active && loc.fix != null)
                  if (!MapConfig.isNearCampus(GpsPoint(loc.fix!.position)))
                    Positioned(
                      top: AonSpacing.space4,
                      // Clear the top-left control column AND the top-right
                      // control island — both are minTapTarget wide.
                      left: AonSpacing.space4 + AonSpacing.minTapTarget,
                      right: AonSpacing.space4 + AonSpacing.minTapTarget,
                      child: _MapNote(
                        text: l.mapOffCampus(
                          (MapConfig.distanceFromCampusMeters(
                                      GpsPoint(loc.fix!.position)) /
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
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MapAttribution(),
                      SizedBox(width: AonSpacing.space2),
                      // §3c: the dot may be simulated, and the Settings toggle
                      // that says so is not on this screen.
                      PreviewLocationBadge(),
                    ],
                  ),
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
                // Top-left control column (G18): Search, Favorites.
                // One minTapTarget-wide stack, mirroring the top-right island;
                // the status notes clear it via `left: space4 + minTapTarget`.
                // This whole Stack only builds in MapMode.campusMap.
                Positioned(
                  top: AonSpacing.space4,
                  left: AonSpacing.space4,
                  child: Column(
                    children: [
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
      // Wayfinding FAB is campus-map only — panorama and compass are their own
      // finders and must not overlay a walk-route FAB (§0.4/§0-N).
      //
      // It is ALSO hidden whenever a place is selected. The selected-place sheet
      // carries its own Directions button for THAT venue, so showing the FAB too
      // put two identical-looking primary actions on screen pointing at
      // different destinations (the sheet's venue vs the Central Courtyard
      // default) — the FAB is a general "route me to the middle of campus"
      // affordance, which is only meaningful when nothing is selected.
      floatingActionButton: (_mode != MapMode.campusMap || selectedKey != null)
          ? null
          : Padding(
        padding: EdgeInsets.only(
          bottom: AonNavMetrics.clearance(context) - AonSpacing.space3,
        ),
        child: FloatingActionButton.extended(
          onPressed: () =>
              context.push(Routes.googleNavTo('venue:central-courtyard')),
          backgroundColor: context.aon.accent,
          foregroundColor: context.aon.onAccent,
          icon: const Icon(Icons.directions_walk_rounded),
          label: Text(l.wayfindingDirections),
        ),
      ),
    );
  }

  Marker? _venueMarker(Venue v, String? selectedKey, AonL10n l) {
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
        semanticLabel: '${v.name}. ${v.category.labelOf(l)}.',
        onTap: () => unawaited(_showVenueSheet(v.id)),
        selected: selected,
      ),
    );
  }

  /// Opens a venue's sheet from a marker tap.
  ///
  /// Routes through the CANONICAL selection so a tapped marker behaves exactly
  /// like one opened from search, favourites or "Show on map": the pin gets its
  /// selected decoration and the map's general Directions FAB steps aside (the
  /// sheet carries the Directions action for this venue). Tapping used to show
  /// the sheet without selecting, which left two Directions controls on screen
  /// pointing at different destinations and no highlight on the pin.
  Future<void> _showVenueSheet(String venueId) async {
    final key = 'venue:$venueId';
    ref.read(mapSelectionProvider.notifier).select(key);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => VenueSheet(venueId: venueId),
    );
    // Dismissing the sheet ends the selection, so the map returns to its
    // neutral state (and the general FAB comes back).
    if (mounted) ref.read(mapSelectionProvider.notifier).clear();
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
    if (key == null || !mounted) return;
    // Parking search hands off to the Wayfinding planner (every car park + its
    // walking route) rather than a map pin — the carparks are at the campus
    // edges and West 6 has no confirmed coordinate, so a pin would be false.
    if (key == kParkingSearchAction) {
      // Google walking/driving directions to the primary free car park.
      unawaited(context.push(Routes.googleNavTo('parking:west-5')));
      return;
    }
    await _onPlaceSelected(key);
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

  Future<void> _onPlaceSelected(String key, {double? zoom}) async {
    ref.read(mapSelectionProvider.notifier).select(key);
    final resolved = ref.read(placeResolverProvider(key)).asData?.value;
    final rp = resolved?.renderPoint;
    if (rp != null) {
      // Clamp: a focus zoom must still obey the campus map's zoom bounds.
      final z = (zoom ?? _controller.camera.zoom)
          .clamp(MapConfig.mapMinZoom, MapConfig.mapMaxZoom);
      _controller.move(rp.value, z);
    } else if (zoom != null && mounted) {
      // Focused from another screen on a place with no map placement. Say so
      // rather than silently leaving the camera wherever it was — the sheet
      // alone would look like the map simply ignored the tap.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AonL10n.of(context).compassUnlocatable)),
      );
    }
    await _openDetail(key);
    if (mounted) ref.read(mapSelectionProvider.notifier).clear(); // G15
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

/// The campus basemap is Macquarie University's own illustrated map, so it is
/// what the map credits.
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
        AonL10n.of(context).mapAttributionCampus,
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
      initialChildSize: MapConfig.venueSheetInitialExtent,
      minChildSize: MapConfig.venueSheetMinExtent,
      maxChildSize: MapConfig.venueSheetMaxExtent,
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
          const SizedBox(height: AonSpacing.space4),
          // ORDER MATTERS. The sheet opens at ~35% of the viewport so the map
          // stays dominant, which means only the first ~180pt is visible before
          // the visitor has to drag. The primary action therefore comes FIRST:
          // notes, the confidence note and the activity list used to sit above
          // it, pushing "Directions" below the fold on a phone — the button the
          // sheet exists to offer was the one thing you could not see.
          // Everything secondary now follows, reachable by dragging up.
          // One directions action, always Google Maps. The GoogleNavScreen
          // shows the interactive route when the key is present, or a clear
          // "not configured yet" message when it is not — never a draft screen.
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                context.push(Routes.googleNavTo('venue:${venue.id}'));
              },
              icon: const Icon(Icons.directions_walk_rounded),
              label: Text(l.mapDirections),
            ),
          ),

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

          // Secondary detail, below the actions: visible on drag, never in the
          // way of the primary CTA.
          if (venue.notes != null) ...[
            const SizedBox(height: AonSpacing.space4),
            Text(
              venue.notes!,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: context.aon.contentSecondary),
            ),
          ],
          const SizedBox(height: AonSpacing.space3),
          ConfidenceNote(confidence: venue.coordinateConfidence),

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
            Text(l.mapOnHereTonight, style: theme.textTheme.titleMedium),
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
                  l.infoParkingFree,
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
              // Google directions to this car park (only when it has a confirmed
              // coordinate — West 6 does not, so no false destination).
              if (parking.hasCoordinates) ...[
                const SizedBox(height: AonSpacing.space4),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.push(Routes.googleNavTo('parking:${parking.id}'));
                    },
                    icon: const Icon(Icons.directions_walk_rounded),
                    label: Text(l.mapDirections),
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
