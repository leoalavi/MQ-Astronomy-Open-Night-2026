> **⚠️ SUPERSEDED — never executed. Preserved as design history (2026-09-01).**
>
> This plan targets an **OSM + dark WGS84** map that no longer exists. The Map
> Parity programme replaced the basemap with MQ Journey's `CrsSimple` illustrated
> platform (M1), then with the official AON programme artwork, and **M2's
> thematic-variant picker was RETIRED** — one official basemap leaves nothing to
> swap, so the picker, providers, registry, the four overlay assets and the EN+FA
> layer strings were all removed. There are no OSM tiles in the app; a test fails
> if a tile endpoint reappears (`test/unit/maps_sdk_boundary_test.dart`).
>
> Rescued from the abandoned `feature/map-overlays-phaseC1` branch before that
> branch was deleted — it was the only copy, and every other milestone plan
> (including the equally-retired M2) lives here. Do **not** execute this plan.
> See `ARCHITECTURE.md` §8 for how the map actually works.

# Map Parity Phase C1 — Campus overlay layers + picker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Toggleable campus overlay layers (parking, accessible routes, drinking water — permits built but hidden) on AON's existing OSM+dark WGS84 map, via a picker. Additive — Phase A live-location and Phase B "Point me there" keep working because the map CRS does not change.

**Architecture:** MQ Journey's 4 overlay PNGs, placed by three affine-calibration-derived geographic corners as `RotatedOverlayImage`s in one `OverlayImageLayer`, sitting under the venue/parking markers on the current `FlutterMap`. A pure registry (`eventVisible` flag), a `Set<String>` controller, and a picker sheet.

**Tech Stack:** Flutter 3.44.7, Riverpod 3.4.2 (plain `Notifier`), `flutter_map` 8.3.1 (`OverlayImageLayer`/`RotatedOverlayImage` — **no new dependency**), `latlong2`. l10n (EN+FA), Palette (`context.aon`).

## Global Constraints

- **No new dependency.** `OverlayImageLayer`/`RotatedOverlayImage` ship with `flutter_map` 8.3.1 (verified: `topLeftCorner`/`bottomLeftCorner`/`bottomRightCorner`, `opacity`).
- **Map CRS is UNCHANGED** — WGS84 tiles. Phase A GPS (dot/follow/off-campus) and Phase B Point-me stay untouched; their tests must remain green.
- **Placement is affine-calibration-derived, empirically verified** — `RotatedOverlayImage` (3 corners) is the ONLY placement; a rectangular `OverlayImage` is used only if the on-device ≤5 m test shows the rotation/shear is below tolerance. Never discard calibration for convenience.
- **Web build stays a hard gate** — re-verify after adding assets (`OverlayImageLayer` is web-safe).
- **`context.aon` colours** for the picker/swatches; overlay tint is the PNG + opacity.
- **All new strings** in **both** `app_en.arb` and `app_fa.arb` (build fails if FA misses a key).
- **Every new surface passes 320×568 / 2.0**; picker switches a11y-labelled; overlays never the sole info channel.
- **Opacity-first night treatment** (per-overlay default opacity); a dark PNG export / `ColorFilter` is IOU-C1a, only if opacity is insufficient.
- **Non-exclusive, non-persistent** active set (`Set<String>`).
- **Registry built for all 4; picker exposes only `eventVisible`** (parking/accessibility/water; permits hidden).
- **Licence/provenance is a HARD RELEASE gate** (not a code gate): `C1 CODE COMPLETE ≠ C1 RELEASE READY`.
- **Per-task gate:** `flutter analyze && flutter test`; web build re-verified where assets/layers change.

---

## File Structure

**Create:** `lib/data/campus_overlays_data.dart` (registry), `lib/services/overlay_providers.dart` (`overlayControllerProvider`), `lib/widgets/campus_overlay_layer.dart`, `lib/widgets/overlay_picker_sheet.dart`, and mirrored tests.
**Modify:** `pubspec.yaml` (assets), `lib/widgets/map_config.dart` (3 corner constants), `lib/screens/map_screen.dart` (insert the layer + a picker button), `lib/l10n/app_en.arb`, `lib/l10n/app_fa.arb`.
**Assets:** copy `overlay_parking.png`, `overlay_accessibility.png`, `overlay_water.png`, `overlay_permits.png` from MQ Journey into `assets/maps/`.

**Task order:** 0 preflight + asset-integrity gate + copy assets → 1 pubspec assets + web gate → 2 corner constants → 3 registry → 4 controller → 5 overlay layer → 6 l10n → 7 picker → 8 map wiring + regression → 9 verification.

---

## Task 0: Preflight & baseline + asset-integrity gate

- [ ] **Step 1: Branch + clean tree** — Run:
```bash
git status --short          # expect empty
git rev-parse HEAD          # record base SHA
git branch --show-current   # expect feature/map-overlays-phaseC1
```

- [ ] **Step 2: Baseline** — Run: `flutter analyze && flutter test` — Expected: clean; **record the passing count** (Phase B left it at 527).

- [ ] **Step 3: Baseline builds** — Run: `flutter build web && flutter build apk --debug` — Expected: both succeed.

- [ ] **Step 4: Asset-integrity gate — record each overlay's geometry.** Run and record:
```bash
MQ=/Users/raoof.r12/Desktop/Raouf/MQ_Journey/assets/maps
for f in mq-campus overlay_parking overlay_accessibility overlay_water overlay_permits; do
  echo "$f.png: $(sips -g pixelWidth -g pixelHeight "$MQ/$f.png" | grep pixel | awk '{print $2}' | paste -sd'x' -)"
done
```
Expected receipt (freeze it): basemap `4678×3307`; all four overlays `3509×2481` = **0.75× the basemap in both axes → one shared footprint, lower resolution**. **If any overlay is NOT 3509×2481** (cropped / re-origined / different aspect), STOP: it needs its own corner transform — do not place it with the shared corners (§8 of the spec).

- [ ] **Step 5: Copy the 4 overlay assets into AON** — Run:
```bash
mkdir -p assets/maps
cp /Users/raoof.r12/Desktop/Raouf/MQ_Journey/assets/maps/overlay_parking.png \
   /Users/raoof.r12/Desktop/Raouf/MQ_Journey/assets/maps/overlay_accessibility.png \
   /Users/raoof.r12/Desktop/Raouf/MQ_Journey/assets/maps/overlay_water.png \
   /Users/raoof.r12/Desktop/Raouf/MQ_Journey/assets/maps/overlay_permits.png \
   assets/maps/
ls -1 assets/maps/
```
(Basemap `mq-campus.png` and `campus_overlay_meta.json` are **not** needed for C1 — the corners are precomputed constants; the affine json is a C2 concern.)

- [ ] **Step 6: Record the 3 corners** (computed by inverting the MQ `gcp_affine` at the footprint pixel corners `(0,0)`, `(0,3307)`, `(4678,3307)` — for the Task 2 constants):
```text
topLeft      lat -33.7687704  lng 151.1050378
bottomLeft   lat -33.7785195  lng 151.1050973
bottomRight  lat -33.7787467  lng 151.1208338
(source: MQ campus_overlay_meta.json gcp_affine; all corners inside AON campusBounds)
```
- [ ] **Step 7: No commit yet** (assets commit with pubspec in Task 1).

---

## Task 1: Register assets + web-build gate

**Files:** Modify `pubspec.yaml`.

- [ ] **Step 1: Add the asset dir** — in `pubspec.yaml` under `flutter: assets:`, add:
```yaml
    - assets/maps/
```
(Alongside the existing `assets/images/`, `assets/web/…`, `assets/data/indoor/` entries.)

- [ ] **Step 2: Verify the web build still compiles with the new assets** — Run: `flutter build web` — Expected: SUCCESS (assets bundle; `OverlayImageLayer` compiles for web). If it fails, STOP.

- [ ] **Step 3: Analyze + commit**
```bash
flutter analyze
git add pubspec.yaml assets/maps/
git commit -m "feat(map): add campus overlay PNG assets (parking/accessibility/water/permits) (Phase C1)"
```

---

## Task 2: Overlay corner constants in `MapConfig`

**Files:** Modify `lib/widgets/map_config.dart`; Create `test/unit/overlay_corners_test.dart`.

**Interfaces:** Produces `MapConfig.overlayTopLeft`, `MapConfig.overlayBottomLeft`, `MapConfig.overlayBottomRight` (`LatLng`).

- [ ] **Step 1: Write the failing test** — `test/unit/overlay_corners_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/widgets/map_config.dart';

void main() {
  test('overlay corners lie inside the campus bounds', () {
    for (final c in [
      MapConfig.overlayTopLeft,
      MapConfig.overlayBottomLeft,
      MapConfig.overlayBottomRight,
    ]) {
      expect(MapConfig.campusBounds.contains(c), isTrue, reason: '$c');
    }
  });

  test('corners form a roughly north-up, slightly-skewed quad', () {
    // topLeft is north of bottomLeft; bottomRight is east of bottomLeft.
    expect(MapConfig.overlayTopLeft.latitude,
        greaterThan(MapConfig.overlayBottomLeft.latitude));
    expect(MapConfig.overlayBottomRight.longitude,
        greaterThan(MapConfig.overlayBottomLeft.longitude));
  });
}
```

- [ ] **Step 2: Run to verify it fails** — FAIL (undefined).

- [ ] **Step 3: Implement** — add to `map_config.dart` (after the Phase B heading block):
```dart
  /// Geographic corners of the campus overlay image footprint, derived once by
  /// inverting MQ Journey's `gcp_affine` calibration (campus_overlay_meta.json)
  /// at the image pixel corners (0,0)/(0,3307)/(4678,3307). All four overlay
  /// PNGs share this footprint (3509×2481 = 0.75× the 4678×3307 basemap canvas;
  /// Phase C1 Task 0 integrity gate). Placement is affine-calibration-derived and
  /// verified on-device (≤5 m). Used by RotatedOverlayImage.
  static const LatLng overlayTopLeft = LatLng(-33.7687704, 151.1050378);
  static const LatLng overlayBottomLeft = LatLng(-33.7785195, 151.1050973);
  static const LatLng overlayBottomRight = LatLng(-33.7787467, 151.1208338);
```

- [ ] **Step 4: Run to verify it passes** — PASS.
- [ ] **Step 5: Commit**
```bash
git add lib/widgets/map_config.dart test/unit/overlay_corners_test.dart
git commit -m "feat(map): campus overlay geographic corners (affine-derived) in MapConfig (Phase C1)"
```

---

## Task 3: Overlay registry

**Files:** Create `lib/data/campus_overlays_data.dart`, `test/unit/campus_overlays_data_test.dart`.

**Interfaces:** `class CampusOverlayDefinition { String id; String assetPath; double defaultOpacity; Color swatch; bool eventVisible; }`; `CampusOverlaysData.all` (`List`), `CampusOverlaysData.eventVisible` (`List`). Pure data — the picker localizes labels by `id` (no l10n import here).

- [ ] **Step 1: Write the failing test** — `test/unit/campus_overlays_data_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/data/campus_overlays_data.dart';

void main() {
  test('all four overlays are registered', () {
    expect(CampusOverlaysData.all.map((d) => d.id).toSet(),
        {'parking', 'accessibility', 'water', 'permits'});
  });

  test('permits is built but not event-visible; the other three are', () {
    expect(CampusOverlaysData.eventVisible.map((d) => d.id).toList(),
        ['parking', 'accessibility', 'water']);
    expect(CampusOverlaysData.all.firstWhere((d) => d.id == 'permits').eventVisible,
        isFalse);
  });

  test('every asset path is under assets/maps and opacity is in (0,1]', () {
    for (final d in CampusOverlaysData.all) {
      expect(d.assetPath, startsWith('assets/maps/'));
      expect(d.defaultOpacity, greaterThan(0));
      expect(d.defaultOpacity, lessThanOrEqualTo(1));
    }
  });
}
```

- [ ] **Step 2: Run to verify it fails** — FAIL.

- [ ] **Step 3: Implement** — `lib/data/campus_overlays_data.dart`:
```dart
import 'dart:ui' show Color; // canonical home of Color; keeps this file widget-free

/// A campus overlay image, registered to the shared overlay footprint
/// (MapConfig.overlay* corners). Pure config — the picker localizes by [id].
class CampusOverlayDefinition {
  const CampusOverlayDefinition({
    required this.id,
    required this.assetPath,
    required this.defaultOpacity,
    required this.swatch,
    required this.eventVisible,
  });
  final String id;
  final String assetPath;
  final double defaultOpacity; // opacity-first night treatment (Phase C1 spec §10)
  final Color swatch;
  final bool eventVisible; // built for all; picker shows only these
}

abstract final class CampusOverlaysData {
  static const List<CampusOverlayDefinition> all = [
    CampusOverlayDefinition(
      id: 'parking',
      assetPath: 'assets/maps/overlay_parking.png',
      defaultOpacity: 0.30,
      swatch: Color(0xFF4F86C6),
      eventVisible: true,
    ),
    CampusOverlayDefinition(
      id: 'accessibility',
      assetPath: 'assets/maps/overlay_accessibility.png',
      defaultOpacity: 0.40,
      swatch: Color(0xFF5AB98A),
      eventVisible: true,
    ),
    CampusOverlayDefinition(
      id: 'water',
      assetPath: 'assets/maps/overlay_water.png',
      defaultOpacity: 0.35,
      swatch: Color(0xFF57C7E3),
      eventVisible: true,
    ),
    CampusOverlayDefinition(
      id: 'permits',
      assetPath: 'assets/maps/overlay_permits.png',
      defaultOpacity: 0.30,
      swatch: Color(0xFFC98BDB),
      eventVisible: false,
    ),
  ];

  static List<CampusOverlayDefinition> get eventVisible =>
      all.where((d) => d.eventVisible).toList();

  static CampusOverlayDefinition? byId(String id) {
    for (final d in all) {
      if (d.id == id) return d;
    }
    return null;
  }
}
```

- [ ] **Step 4: Run to verify it passes** — PASS.
- [ ] **Step 5: Commit**
```bash
git add lib/data/campus_overlays_data.dart test/unit/campus_overlays_data_test.dart
git commit -m "feat(map): campus overlay registry (4 defs, eventVisible flag) (Phase C1)"
```

---

## Task 4: `OverlayController` + provider

**Files:** Create `lib/services/overlay_providers.dart`, `test/unit/overlay_controller_test.dart`.

**Interfaces:** `overlayControllerProvider` (`NotifierProvider<OverlayController, Set<String>>`, default `{}`); `OverlayController.toggle(String)`, `.clear()`.

- [ ] **Step 1: Write the failing test** — `test/unit/overlay_controller_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/services/overlay_providers.dart';

void main() {
  ProviderContainer c() {
    final x = ProviderContainer();
    addTearDown(x.dispose);
    return x;
  }

  test('default is empty', () {
    expect(c().read(overlayControllerProvider), isEmpty);
  });

  test('toggle adds then removes; non-exclusive', () {
    final x = c();
    final n = x.read(overlayControllerProvider.notifier);
    n.toggle('parking');
    n.toggle('accessibility');
    expect(x.read(overlayControllerProvider), {'parking', 'accessibility'});
    n.toggle('parking');
    expect(x.read(overlayControllerProvider), {'accessibility'});
  });

  test('clear empties the set', () {
    final x = c();
    final n = x.read(overlayControllerProvider.notifier);
    n.toggle('parking');
    n.clear();
    expect(x.read(overlayControllerProvider), isEmpty);
  });
}
```

- [ ] **Step 2: Run to verify it fails** — FAIL.

- [ ] **Step 3: Implement** — `lib/services/overlay_providers.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Active campus-overlay ids. Non-exclusive (any combination) and NOT persisted
/// — overlays are transient viewing state (Phase C1 spec §6).
final overlayControllerProvider =
    NotifierProvider<OverlayController, Set<String>>(OverlayController.new);

class OverlayController extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  void toggle(String id) {
    final next = {...state};
    next.contains(id) ? next.remove(id) : next.add(id);
    state = next;
  }

  void clear() => state = <String>{};
}
```

- [ ] **Step 4: Run to verify it passes** — PASS.
- [ ] **Step 5: Commit**
```bash
git add lib/services/overlay_providers.dart test/unit/overlay_controller_test.dart
git commit -m "feat(map): OverlayController — non-exclusive active overlay set (Phase C1)"
```

---

## Task 5: `CampusOverlayLayer`

**Files:** Create `lib/widgets/campus_overlay_layer.dart`, `test/widget/campus_overlay_layer_test.dart`.

**Interfaces:** `CampusOverlayLayer` (`ConsumerWidget`) → an `OverlayImageLayer` with one `RotatedOverlayImage` per active overlay (registry order), at each overlay's `defaultOpacity`, placed by the `MapConfig.overlay*` corners.

- [ ] **Step 1: Write the failing test** — `test/widget/campus_overlay_layer_test.dart` (same StatelessWidget-wrapping-a-layer pattern as Phase A's `UserLocationCircle`; `RotatedOverlayImage`/`OverlayImage` are `BaseOverlayImage`s so count them via the layer's list):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/services/overlay_providers.dart';
import 'package:aon2026/widgets/map_config.dart';
import 'package:aon2026/widgets/campus_overlay_layer.dart';

OverlayImageLayer _layer(WidgetTester t) =>
    t.widget<OverlayImageLayer>(find.byType(OverlayImageLayer));

Widget _map(ProviderContainer c) => UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        home: Scaffold(
          body: FlutterMap(
            options: const MapOptions(initialCenter: MapConfig.campusCentre),
            children: const [_EmptyTiles(), CampusOverlayLayer()],
          ),
        ),
      ),
    );

class _EmptyTiles extends StatelessWidget {
  const _EmptyTiles();
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void main() {
  testWidgets('no active overlays → an empty overlay layer', (t) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await t.pumpWidget(_map(c));
    expect(_layer(t).overlayImages, isEmpty);
    expect(t.takeException(), isNull);
  });

  testWidgets('two active → two RotatedOverlayImages at their opacity', (t) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(overlayControllerProvider.notifier).toggle('parking');
    c.read(overlayControllerProvider.notifier).toggle('water');
    await t.pumpWidget(_map(c));
    await t.pump();
    final imgs = _layer(t).overlayImages;
    expect(imgs.length, 2);
    expect(imgs.every((i) => i is RotatedOverlayImage), isTrue);
    expect(imgs.first.opacity, closeTo(0.30, 1e-9)); // parking default
  });
}
```

- [ ] **Step 2: Run to verify it fails** — FAIL.

- [ ] **Step 3: Implement** — `lib/widgets/campus_overlay_layer.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/data/campus_overlays_data.dart';
import 'package:aon2026/services/overlay_providers.dart';
import 'package:aon2026/widgets/map_config.dart';

/// The active campus overlays as one flutter_map [OverlayImageLayer]. Each is a
/// [RotatedOverlayImage] pinned to the affine-derived footprint corners
/// (MapConfig.overlay*) — placement is calibration-derived and verified ≤5 m
/// on-device (Phase C1 spec §7). Sits UNDER the venue markers.
class CampusOverlayLayer extends ConsumerWidget {
  const CampusOverlayLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(overlayControllerProvider);
    return OverlayImageLayer(
      overlayImages: [
        for (final d in CampusOverlaysData.all)
          if (active.contains(d.id))
            RotatedOverlayImage(
              topLeftCorner: MapConfig.overlayTopLeft,
              bottomLeftCorner: MapConfig.overlayBottomLeft,
              bottomRightCorner: MapConfig.overlayBottomRight,
              opacity: d.defaultOpacity,
              imageProvider: AssetImage(d.assetPath),
            ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run to verify it passes** — PASS.
- [ ] **Step 5: Commit**
```bash
git add lib/widgets/campus_overlay_layer.dart test/widget/campus_overlay_layer_test.dart
git commit -m "feat(map): CampusOverlayLayer — active overlays as RotatedOverlayImages (Phase C1)"
```

---

## Task 6: Localised strings (EN + FA)

**Files:** Modify `lib/l10n/app_en.arb`, `lib/l10n/app_fa.arb`; regenerate. **Before the picker (Task 7).**

- [ ] **Step 1: Add keys to `app_en.arb`**:
```json
  "overlaysTitle": "Map layers",
  "@overlaysTitle": { "description": "Overlay picker sheet title + button" },
  "overlaysNone": "No layers on",
  "@overlaysNone": { "description": "Empty-state hint in the picker" },
  "overlayParking": "Parking",
  "@overlayParking": { "description": "Overlay label" },
  "overlayParkingDesc": "Event parking areas",
  "overlayAccessibility": "Accessible routes",
  "overlayAccessibilityDesc": "Step-free paths and access points",
  "overlayWater": "Drinking water",
  "overlayWaterDesc": "Water refill points",
  "overlayPermits": "Permit areas",
  "overlayPermitsDesc": "Restricted / permit-only areas",
```

- [ ] **Step 2: Add the same keys to `app_fa.arb`** (Persian):
```json
  "overlaysTitle": "لایه‌های نقشه",
  "overlaysNone": "هیچ لایه‌ای روشن نیست",
  "overlayParking": "پارکینگ",
  "overlayParkingDesc": "محل‌های پارک رویداد",
  "overlayAccessibility": "مسیرهای دسترس‌پذیر",
  "overlayAccessibilityDesc": "مسیرهای بدون پله و نقاط دسترسی",
  "overlayWater": "آب آشامیدنی",
  "overlayWaterDesc": "نقاط پرکردن آب",
  "overlayPermits": "مناطق مجوزدار",
  "overlayPermitsDesc": "مناطق محدود / فقط با مجوز",
```

- [ ] **Step 3: Regenerate + verify** — Run: `flutter gen-l10n && flutter analyze` — Expected: getters exist; no untranslated-key failure; clean.

- [ ] **Step 4: Commit**
```bash
git add lib/l10n/app_en.arb lib/l10n/app_fa.arb lib/l10n/generated/
git commit -m "feat(map): l10n for map layers picker (EN/FA) (Phase C1)"
```

---

## Task 7: `OverlayPickerSheet`

**Files:** Create `lib/widgets/overlay_picker_sheet.dart`, `test/widget/overlay_picker_sheet_test.dart`.

**Interfaces:** `OverlayPickerSheet` (`ConsumerWidget`) lists `CampusOverlaysData.eventVisible` as `SwitchListTile`s bound to `overlayControllerProvider`; localizes label/description by `id`.

- [ ] **Step 1: Write the failing test** — `test/widget/overlay_picker_sheet_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/services/overlay_providers.dart';
import 'package:aon2026/widgets/overlay_picker_sheet.dart';

Widget _host(ProviderContainer c, {Locale? locale}) => UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: const Scaffold(body: OverlayPickerSheet()),
      ),
    );

void main() {
  testWidgets('lists the three event-visible overlays, not permits', (t) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await t.pumpWidget(_host(c));
    expect(find.text('Parking'), findsOneWidget);
    expect(find.text('Accessible routes'), findsOneWidget);
    expect(find.text('Drinking water'), findsOneWidget);
    expect(find.text('Permit areas'), findsNothing); // built but hidden
  });

  testWidgets('toggling a switch updates the controller', (t) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await t.pumpWidget(_host(c));
    await t.tap(find.widgetWithText(SwitchListTile, 'Parking'));
    await t.pump();
    expect(c.read(overlayControllerProvider), contains('parking'));
  });

  testWidgets('no overflow at 320x568 / 2.0', (t) async {
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1.0;
    t.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await t.pumpWidget(_host(c));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  testWidgets('renders under FA locale', (t) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await t.pumpWidget(_host(c, locale: const Locale('fa')));
    await t.pump();
    expect(find.text('پارکینگ'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run to verify it fails** — FAIL.

- [ ] **Step 3: Implement** — `lib/widgets/overlay_picker_sheet.dart`. A `ConsumerWidget`: a scrollable `Column`/`ListView` with a title (`l.overlaysTitle`) and, for each `CampusOverlaysData.eventVisible`, a `SwitchListTile` whose `value = active.contains(d.id)`, `onChanged = (_) => ref.read(overlayControllerProvider.notifier).toggle(d.id)`, `title = Text(_label(l, d.id))`, `subtitle = Text(_desc(l, d.id))`, `secondary = a swatch dot (d.swatch)`. `_label`/`_desc` switch on `id` → the `l.overlay*` getters (like PointMeScreen's cardinal switch). Content-tier surface, `context.aon`, scroll-safe for 2.0. Wrap in `SafeArea` + `SingleChildScrollView` so a modal sheet never overflows.

- [ ] **Step 4: Run to verify it passes** — PASS.
- [ ] **Step 5: Commit**
```bash
git add lib/widgets/overlay_picker_sheet.dart test/widget/overlay_picker_sheet_test.dart
git commit -m "feat(map): overlay picker sheet — event-visible switches, a11y, 2.0, FA (Phase C1)"
```

---

## Task 8: Wire into the map + additive-safety regression

**Files:** Modify `lib/screens/map_screen.dart`; Create `test/widget/map_overlays_wiring_test.dart`.

- [ ] **Step 1: Write the failing wiring test** — `test/widget/map_overlays_wiring_test.dart`. Two cases: (a) a **layers button** opens the picker (tap it, `find.byType(OverlayPickerSheet)` findsOneWidget); (b) **additive safety** — with an overlay active AND a location fix, BOTH the overlay (`find.byType(OverlayImageLayer)` whose single item's `overlayImages` has length 1) AND the user dot (`find.byType(UserLocationDot)`) render, and `t.takeException()` is null. Reuse the Phase A `FakeLocationService` container pattern (`map_location_wiring_test.dart`) — override `locationServiceProvider`, `mapVisibleProvider=true`, `onLocateTapped`, emit a near fix — then `overlayControllerProvider.notifier).toggle('parking')`. (Do NOT assert z-order in the widget test — that's brittle; it's guaranteed by source order in `children` and verified on-device in Task 9.)

- [ ] **Step 2: Run to verify it fails** — FAIL.

- [ ] **Step 3: Wire `map_screen.dart`:**
  1. **Import** `campus_overlay_layer.dart` and `overlay_picker_sheet.dart` only. Do NOT import `overlay_providers.dart` — `map_screen` doesn't read the provider directly (the layer reads it internally, the button just opens the sheet); an unused import would fail analyze.
  2. **Insert the layer** in the `FlutterMap` children, directly after `DarkTileLayer` and before the location circle / venue `MarkerLayer` (spec render order):
     ```dart
     const DarkTileLayer(),
     const CampusOverlayLayer(),
     if (loc.active && loc.fix != null) UserLocationCircle(fix: loc.fix!),
     MarkerLayer(markers: markers),
     if (loc.active && loc.fix != null) UserLocationDot(fix: loc.fix!),
     ```
  3. **Layers button** — a `Positioned` control (top-left, mirroring the top-right `MapControlIsland`) that opens the picker:
     ```dart
     Positioned(
       top: AonSpacing.space4,
       left: AonSpacing.space4,
       child: _LayersButton(onTap: () => showModalBottomSheet<void>(
         context: context,
         isScrollControlled: true,
         useSafeArea: true,
         builder: (_) => const OverlayPickerSheet(),
       )),
     ),
     ```
     where `_LayersButton` is a small themed glass/opaque icon button (`Icons.layers_rounded`, `Semantics(button:true, label: l.overlaysTitle)`), only shown in `MapMode.campusMap` (hidden in panorama).

- [ ] **Step 4: Run tests + web build** — Run: `flutter test test/widget/map_overlays_wiring_test.dart && flutter analyze && flutter build web` — Expected: PASS; clean; web green.

- [ ] **Step 5: Commit**
```bash
git add lib/screens/map_screen.dart test/widget/map_overlays_wiring_test.dart
git commit -m "feat(map): wire overlay layer + layers picker into the map; dot survives (Phase C1)"
```

---

## Task 9: Verification gate + closeout

**Files:** Append a closeout to `docs/superpowers/specs/2026-08-13-aon-map-overlays-phaseC1-design.md`.

- [ ] **Step 1: Full static + test** — Run: `flutter analyze && flutter test` — Expected: clean; suite = Task 0 baseline + new; **Phase A/B map tests still green** (CRS unchanged).
- [ ] **Step 2: Builds** — Run: `flutter build web`, `flutter build ios --simulator --debug`, `flutter build apk --debug` — Expected: all succeed.
- [ ] **Step 3: iOS render check (Impeller)** — launch on the iOS simulator, open Map → Layers → enable Parking. Confirm the overlay actually **paints** (not blank/garbled) over the tiles — flutter_map has flagged historical Impeller overlay-image issues, so this is a required visual check. Record PASS/FAIL.
- [ ] **Step 4: Alignment acceptance (≤5 m)** — with an overlay on, compare ≥4 known features (a building corner, a car-park edge, a main-path intersection, a water point) against the OSM base:
```text
≤ 5 m   → PASS
5–10 m  → review (accept w/ noted caveat, or recalibrate the corners)
> 10 m  → FAIL — recalibrate the MapConfig.overlay* corners; do not ship misaligned
```
- [ ] **Step 5: Closeout** — append: asset-integrity receipt (Task 0), the 3 corners, all build results, the iOS render + ≤5 m alignment results, and the **split status**:
  - **C1 CODE COMPLETE** — analyze/tests green, all three builds green, overlay renders on-device, alignment within tolerance, Phase A/B untouched.
  - **C1 RELEASE READY — gated on LICENCE/PROVENANCE.** Confirm reuse rights + attribution for MQ Journey's overlay art before shipping; otherwise swap for recreated/organiser-supplied assets (the code is asset-agnostic).
- [ ] **Step 6: Final re-gate** — Run: `flutter analyze && flutter test && git diff --check && git status --short`, then a hostile read of `git diff main...HEAD`.
- [ ] **Step 7: Commit**
```bash
git add docs/superpowers/specs/2026-08-13-aon-map-overlays-phaseC1-design.md
git commit -m "docs(map): Phase C1 verification + closeout (code-complete; release gated on licence)"
```

---

## Self-Review

**1. Spec coverage**

| Spec § | Task |
|---|---|
| §3 assets + registry (eventVisible) | 0, 1, 3 |
| §4 render order + no CRS change | 8 |
| §5 registry (4 defs, opacities) | 3 |
| §6 non-exclusive non-persistent Set | 4 |
| §7 affine-derived corners + ≤5 m test | 2, 9 |
| §8 asset-integrity gate | 0 |
| §9 licence release gate | 9 (closeout) |
| §10 opacity-first night treatment | 3, 5 |
| §11 iOS Impeller render check | 9 |
| §12 web gate / l10n / 2.0 / a11y | 1, 6, 7 |
| §13 tests | every task + 9 |

**2. Placeholder scan** — clean. The 3 corner values are concrete (Task 0 records them, Task 2 hardcodes them). Task 7 Step 3 and Task 8 Steps 1/3 describe the widget/wiring against complete interfaces + a fully-written test that pins each branch (picker switches by id; layers button opens sheet; both-layers-render regression) — the executor writes the bodies to satisfy those tests. No TBD/TODO.

**3. Type consistency** — `CampusOverlayDefinition{id,assetPath,defaultOpacity,swatch,eventVisible}`, `CampusOverlaysData.{all,eventVisible,byId}`, `overlayControllerProvider` (`NotifierProvider<OverlayController, Set<String>>`, `.toggle`/`.clear`), `CampusOverlayLayer`, `OverlayPickerSheet`, `MapConfig.{overlayTopLeft,overlayBottomLeft,overlayBottomRight}`, `l.overlay*`/`l.overlaysTitle` — consistent across tasks. `RotatedOverlayImage(topLeftCorner,bottomLeftCorner,bottomRightCorner,opacity,imageProvider)` matches flutter_map 8.3.1.

---

## Notes for the executor

- **The map CRS does not change** — do NOT touch `MapOptions`/`CameraConstraint`; the whole point of C1 is that Phase A/B keep working. The regression test (Task 8) proves the dot still renders with overlays on.
- **`RotatedOverlayImage` only** — do not substitute a rectangular `OverlayImage` unless the ≤5 m test (Task 9) shows the skew is below tolerance; the corners are slightly skewed by design (topLeft/bottomLeft lng differ ~5 m).
- **Asset-integrity gate is real** (Task 0) — if any overlay isn't 3509×2481, it doesn't share the corner set and needs its own transform; stop and reassess.
- **Opacity first** for night legibility; a dark PNG / ColorFilter is IOU-C1a only if opacity is insufficient.
- **Licence/provenance gates RELEASE, not code** — keep the split in the closeout; do not claim release-ready until reuse rights + attribution are confirmed.
- **iOS Impeller overlay render is a required on-device check** (Task 9) — a green web build does not prove the overlay paints on iOS.
- Never weaken an existing test to make Phase C1 pass.
