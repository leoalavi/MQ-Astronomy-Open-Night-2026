# M2 — Thematic Map Variants Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A single-select picker that swaps the illustrated campus basemap between the plain dark map and one reskinned thematic variant (Parking, Accessible routes, Drinking water; Permits built but hidden), with M1's projection/dot/markers untouched.

**Architecture:** A `CampusMapVariant` enum drives a plain-`Notifier` provider. `CampusBasemapLayer` becomes a `ConsumerWidget` that watches the provider and renders exactly one `OverlayImage` (the base or one variant asset) — never a stack. A glass "Layers" button on the map opens a `RadioGroup`-based bottom sheet. Only the basemap image changes on select; the camera, the user dot, the accuracy circle and the venue markers are read from the projection and are unaffected.

**Tech Stack:** Flutter 3.44 · flutter_map 8.3.1 · Riverpod 3.4.2 (plain `Notifier`/`NotifierProvider`) · flutter gen-l10n (EN + FA).

**Design:** `docs/superpowers/specs/2026-08-15-aon-map-M2-thematic-variants-design.md` — **read §0 (gauntlet amendment) first; it is authoritative and supersedes the `String?` model in §§3–8 with the enum model used throughout this plan.**

## Global Constraints

- **State is `enum CampusMapVariant`, never `String?`/`null`.** `RadioGroup` reserves `null` for its deselect sentinel (`radio_group.dart:159` `onChanged(null)`); a null arriving at the controller maps to `CampusMapVariant.base`.
- **No new dependency, no new asset.** M0 shipped all 5 PNGs (`assets/maps/{mqcampus,overlay_parking,overlay_accessibility,overlay_water,overlay_permits}_dark.png`, each 2048×1448, 11.3 MiB decoded).
- **Exactly one image on screen.** The variant *is* the basemap (full opacity, no translucent stacking).
- **`context.aon` for all picker chrome;** swatches are the only exemption — source-legend ink colours, documented in the design.
- **EN + FA both required** for every new key. `flutter gen-l10n` fails the build on any FA key missing (`untranslated-messages-file`), which `./scripts/check.sh` blocks on.
- **320×568 / 2.0** must not overflow for the picker or the new Layers button.
- **TDD; never weaken an existing test.** M1's `campus_basemap_layer_test` is *migrated* (add `ProviderScope`), not deleted; the full suite stays green.
- **Note-clearance uses the token,** not a magic number: `AonSpacing.minTapTarget` (= 56, verified `aon_spacing.dart:31`).
- **Per-task gate:** `./scripts/check.sh` (analyze + l10n + test + reskin). Closeout adds `./scripts/check.sh full` (web/apk/iOS) + on-device variant-swap render + the §8 memory/jank check.

---

### Task 1: `CampusMapVariant` enum + registry + integrity/content gates

**Files:**
- Create: `lib/data/campus_variants_data.dart`
- Test: `test/unit/campus_variants_data_test.dart`
- Test: `test/widget/campus_variant_assets_test.dart` (asset-integrity — needs the widget binding for `rootBundle`)

**Interfaces:**
- Produces: `enum CampusMapVariant { base, parking, accessibility, water, permits }`; `class CampusVariant { CampusMapVariant variant; String assetPath; Color swatch; bool eventVisible; bool contentApproved; }`; `abstract final class CampusVariantsData` with `static const String baseAsset`, `static const List<CampusVariant> all`, `static List<CampusVariant> get eventVisible`, `static CampusVariant? byVariant(CampusMapVariant)`, `static String assetFor(CampusMapVariant)`.

- [ ] **Step 1: Write the failing registry + gate tests**

```dart
// test/unit/campus_variants_data_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/data/campus_variants_data.dart';

void main() {
  test('registry is exactly the four thematic variants', () {
    expect(CampusVariantsData.all.map((v) => v.variant).toSet(), {
      CampusMapVariant.parking,
      CampusMapVariant.accessibility,
      CampusMapVariant.water,
      CampusMapVariant.permits,
    });
    expect(CampusMapVariant.base, isNot(isIn(CampusVariantsData.all.map((v) => v.variant))));
  });

  test('eventVisible is the three public variants (permits hidden)', () {
    expect(CampusVariantsData.eventVisible.map((v) => v.variant), [
      CampusMapVariant.parking,
      CampusMapVariant.accessibility,
      CampusMapVariant.water,
    ]);
  });

  test('content-validity gate: eventVisible ⇒ contentApproved (must-fix #6)', () {
    for (final v in CampusVariantsData.all) {
      if (v.eventVisible) {
        expect(v.contentApproved, isTrue, reason: '${v.variant} is event-visible without approval');
      }
    }
  });

  test('every asset is under assets/maps/ and ends _dark.png', () {
    for (final v in CampusVariantsData.all) {
      expect(v.assetPath, startsWith('assets/maps/'));
      expect(v.assetPath, endsWith('_dark.png'));
    }
    expect(CampusVariantsData.baseAsset, 'assets/maps/mqcampus_dark.png');
  });

  test('assetFor is total: base → baseAsset, water → water asset', () {
    expect(CampusVariantsData.assetFor(CampusMapVariant.base), CampusVariantsData.baseAsset);
    expect(CampusVariantsData.assetFor(CampusMapVariant.water), 'assets/maps/overlay_water_dark.png');
  });

  test('byVariant returns the row, null for base', () {
    expect(CampusVariantsData.byVariant(CampusMapVariant.parking)!.swatch.value, 0xFF3B82F6);
    expect(CampusVariantsData.byVariant(CampusMapVariant.base), isNull);
  });
}
```

```dart
// test/widget/campus_variant_assets_test.dart
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/data/campus_variants_data.dart';

void main() {
  // Must-fix #4: bundled-asset integrity is the "decode failure" guard —
  // a renamed/missing PNG fails HERE at CI, not as a blank map at runtime.
  testWidgets('every base + variant asset is bundled and non-empty', (t) async {
    final paths = [
      CampusVariantsData.baseAsset,
      for (final v in CampusVariantsData.all) v.assetPath,
    ];
    for (final p in paths) {
      final bytes = await rootBundle.load(p);
      expect(bytes.lengthInBytes, greaterThan(0), reason: 'missing/empty asset: $p');
    }
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/unit/campus_variants_data_test.dart test/widget/campus_variant_assets_test.dart`
Expected: FAIL — `campus_variants_data.dart` does not exist (compile error).

- [ ] **Step 3: Write the registry**

```dart
// lib/data/campus_variants_data.dart
import 'package:flutter/painting.dart' show Color;

/// Which single illustrated basemap the map renders. Exactly one is shown at a
/// time — these are alternate full basemaps (M0), not stacked layers. `base` is
/// the plain dark campus; the rest are reskinned thematic variants.
enum CampusMapVariant { base, parking, accessibility, water, permits }

/// One *thematic* variant. `base` is not a row here — it is the enum default and
/// its asset is owned by [CampusVariantsData.baseAsset].
class CampusVariant {
  const CampusVariant({
    required this.variant,
    required this.assetPath,
    required this.swatch,
    required this.eventVisible,
    required this.contentApproved,
  });

  final CampusMapVariant variant;
  final String assetPath;

  /// Source-legend ink colour (documented `context.aon` exemption — it names the
  /// map's own ink, not app chrome).
  final Color swatch;

  /// Listed in the event picker. Permits is built but hidden.
  final bool eventVisible;

  /// Content-validity gate (design §0 must-fix #6): a variant may be
  /// [eventVisible] only once its underlying data is signed off for the event.
  final bool contentApproved;
}

abstract final class CampusVariantsData {
  static const String baseAsset = 'assets/maps/mqcampus_dark.png';

  static const List<CampusVariant> all = [
    CampusVariant(
      variant: CampusMapVariant.parking,
      assetPath: 'assets/maps/overlay_parking_dark.png',
      swatch: Color(0xFF3B82F6),
      eventVisible: true,
      contentApproved: true,
    ),
    CampusVariant(
      variant: CampusMapVariant.accessibility,
      assetPath: 'assets/maps/overlay_accessibility_dark.png',
      swatch: Color(0xFFA855F7),
      eventVisible: true,
      contentApproved: true,
    ),
    CampusVariant(
      variant: CampusMapVariant.water,
      assetPath: 'assets/maps/overlay_water_dark.png',
      swatch: Color(0xFF06B6D4),
      eventVisible: true,
      contentApproved: true,
    ),
    CampusVariant(
      variant: CampusMapVariant.permits,
      assetPath: 'assets/maps/overlay_permits_dark.png',
      swatch: Color(0xFFF97316),
      eventVisible: false,
      contentApproved: true,
    ),
  ];

  static List<CampusVariant> get eventVisible =>
      all.where((v) => v.eventVisible).toList();

  static CampusVariant? byVariant(CampusMapVariant v) {
    for (final row in all) {
      if (row.variant == v) return row;
    }
    return null;
  }

  /// The asset for any variant, total. `base` (and any unmatched value) →
  /// [baseAsset] — the map is never left without a basemap.
  static String assetFor(CampusMapVariant v) => v == CampusMapVariant.base
      ? baseAsset
      : (byVariant(v)?.assetPath ?? baseAsset);
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/unit/campus_variants_data_test.dart test/widget/campus_variant_assets_test.dart`
Expected: PASS (all).

- [ ] **Step 5: Commit**

```bash
git add lib/data/campus_variants_data.dart test/unit/campus_variants_data_test.dart test/widget/campus_variant_assets_test.dart
git commit -m "feat(map): M2 T1 — CampusMapVariant enum + registry + integrity/content gates"
```

---

### Task 2: Single-select controller/provider

**Files:**
- Create: `lib/services/campus_variant_providers.dart`
- Test: `test/unit/campus_variant_providers_test.dart`

**Interfaces:**
- Consumes: `CampusMapVariant` (Task 1).
- Produces: `class CampusVariantController extends Notifier<CampusMapVariant>` with `void select(CampusMapVariant? variant)`; `final campusVariantProvider = NotifierProvider<CampusVariantController, CampusMapVariant>(...)`.

- [ ] **Step 1: Write the failing controller test**

```dart
// test/unit/campus_variant_providers_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/data/campus_variants_data.dart';
import 'package:aon2026/services/campus_variant_providers.dart';

void main() {
  ProviderContainer harness() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  test('default is base', () {
    final c = harness();
    expect(c.read(campusVariantProvider), CampusMapVariant.base);
  });

  test('select(parking) → parking', () {
    final c = harness();
    c.read(campusVariantProvider.notifier).select(CampusMapVariant.parking);
    expect(c.read(campusVariantProvider), CampusMapVariant.parking);
  });

  test('exclusive: a second select replaces, never accumulates', () {
    final c = harness();
    final n = c.read(campusVariantProvider.notifier);
    n.select(CampusMapVariant.parking);
    n.select(CampusMapVariant.water);
    expect(c.read(campusVariantProvider), CampusMapVariant.water);
  });

  test('select(base) returns to base', () {
    final c = harness();
    final n = c.read(campusVariantProvider.notifier);
    n.select(CampusMapVariant.water);
    n.select(CampusMapVariant.base);
    expect(c.read(campusVariantProvider), CampusMapVariant.base);
  });

  test('select(null) — RadioGroup deselect sentinel — maps to base', () {
    final c = harness();
    final n = c.read(campusVariantProvider.notifier);
    n.select(CampusMapVariant.parking);
    n.select(null);
    expect(c.read(campusVariantProvider), CampusMapVariant.base);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/campus_variant_providers_test.dart`
Expected: FAIL — `campus_variant_providers.dart` does not exist.

- [ ] **Step 3: Write the controller**

```dart
// lib/services/campus_variant_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/data/campus_variants_data.dart';

/// Single-select thematic-variant state. **Session-only, not persisted to
/// storage** — it resets on app restart (a persistence IOU if a need appears).
class CampusVariantController extends Notifier<CampusMapVariant> {
  @override
  CampusMapVariant build() => CampusMapVariant.base;

  /// Select a variant. A `null` argument is `RadioGroup`'s framework deselect
  /// sentinel (`radio_group.dart:159`); it maps to [CampusMapVariant.base] so
  /// the map is never left with no basemap.
  void select(CampusMapVariant? variant) =>
      state = variant ?? CampusMapVariant.base;
}

final campusVariantProvider =
    NotifierProvider<CampusVariantController, CampusMapVariant>(
        CampusVariantController.new);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/unit/campus_variant_providers_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/campus_variant_providers.dart test/unit/campus_variant_providers_test.dart
git commit -m "feat(map): M2 T2 — single-select CampusVariantController (null→base)"
```

---

### Task 3: `CampusBasemapLayer` → `ConsumerWidget` (image swap) + migrate M1 test

**Files:**
- Modify: `lib/widgets/campus_basemap_layer.dart`
- Modify (migrate, do not delete): `test/widget/campus_basemap_layer_test.dart`

**Interfaces:**
- Consumes: `campusVariantProvider`, `CampusVariantsData.assetFor` (Tasks 1–2).
- Produces: `CampusBasemapLayer` unchanged public shape (`const CampusBasemapLayer({super.key})`), now a `ConsumerWidget` requiring a `ProviderScope` ancestor.

- [ ] **Step 1: Migrate the M1 test (add ProviderScope) and add a variant-render assertion — expect it to fail**

```dart
// test/widget/campus_basemap_layer_test.dart  (REPLACE the file)
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/data/campus_variants_data.dart';
import 'package:aon2026/services/campus_variant_providers.dart';
import 'package:aon2026/widgets/campus_basemap_layer.dart';
import 'package:aon2026/widgets/map_config.dart';

String _asset(WidgetTester t) {
  final layer = t.widget<OverlayImageLayer>(find.byType(OverlayImageLayer));
  final img = layer.overlayImages.single as OverlayImage;
  return (img.imageProvider as AssetImage).assetName;
}

Widget _host(ProviderContainer c) => UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        home: Scaffold(
          body: FlutterMap(
            options: MapOptions(
              crs: const CrsSimple(),
              initialCameraFit: CameraFit.bounds(bounds: MapConfig.mapBounds),
            ),
            children: const [CampusBasemapLayer()],
          ),
        ),
      ),
    );

void main() {
  testWidgets('base: one overlay image = the dark campus (migrated)', (t) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await t.pumpWidget(_host(c));
    await t.pump();
    final layer = t.widget<OverlayImageLayer>(find.byType(OverlayImageLayer));
    expect(layer.overlayImages.length, 1); // still exactly one image
    expect(_asset(t), CampusVariantsData.baseAsset);
    expect(t.takeException(), isNull);
  });

  testWidgets('variant selected: renders that variant asset, still one image',
      (t) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(campusVariantProvider.notifier).select(CampusMapVariant.water);
    await t.pumpWidget(_host(c));
    await t.pump();
    final layer = t.widget<OverlayImageLayer>(find.byType(OverlayImageLayer));
    expect(layer.overlayImages.length, 1);
    expect(_asset(t), 'assets/maps/overlay_water_dark.png');
    expect(t.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget/campus_basemap_layer_test.dart`
Expected: FAIL — `CampusBasemapLayer` is a `StatelessWidget`, so `campus_variant_providers` import is unused and the asset is hard-coded (the variant test finds the base asset, and/or the file fails to compile on the new imports).

- [ ] **Step 3: Convert the layer to a ConsumerWidget**

```dart
// lib/widgets/campus_basemap_layer.dart  (REPLACE the file)
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/data/campus_variants_data.dart';
import 'package:aon2026/services/campus_variant_providers.dart';
import 'package:aon2026/widgets/map_config.dart';

/// The reskinned illustrated campus basemap as a `CrsSimple` `OverlayImage`,
/// pinned to the full map bounds. M2: renders exactly one image — the base or
/// the selected thematic variant (design §0/§6). Only the ink changes; the
/// footprint ([MapConfig.mapBounds]) is fixed, so the campus never moves.
class CampusBasemapLayer extends ConsumerWidget {
  const CampusBasemapLayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final variant = ref.watch(campusVariantProvider);
    return OverlayImageLayer(
      overlayImages: [
        OverlayImage(
          bounds: MapConfig.mapBounds,
          imageProvider: AssetImage(CampusVariantsData.assetFor(variant)),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widget/campus_basemap_layer_test.dart`
Expected: PASS (both).

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/campus_basemap_layer.dart test/widget/campus_basemap_layer_test.dart
git commit -m "feat(map): M2 T3 — CampusBasemapLayer swaps variant image (ConsumerWidget)"
```

---

### Task 4: Localised strings (EN + FA)

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_fa.arb`
- Regenerate: `lib/l10n/generated/app_localizations*.dart` (via `flutter gen-l10n`)

**Interfaces:**
- Produces on `AonL10n`: `mapLayersTitle`, `mapVariantBase`, `mapVariantParking`, `mapVariantParkingDesc`, `mapVariantAccessibility`, `mapVariantAccessibilityDesc`, `mapVariantWater`, `mapVariantWaterDesc`.

- [ ] **Step 1: Add the EN keys** (insert after `"mapZoomOut"` in `app_en.arb`; `@`-metadata mirrors the existing `mapLowAccuracy` style)

```json
  "mapLayersTitle": "Map layers",
  "@mapLayersTitle": { "description": "Title of the thematic-variant picker sheet; label of the Layers button" },
  "mapVariantBase": "Campus map",
  "@mapVariantBase": { "description": "Picker row for the plain illustrated campus basemap (no theme)" },
  "mapVariantParking": "Parking",
  "mapVariantParkingDesc": "Visitor and event parking areas",
  "mapVariantAccessibility": "Accessible routes",
  "mapVariantAccessibilityDesc": "Step-free paths and accessible entrances",
  "mapVariantWater": "Drinking water",
  "mapVariantWaterDesc": "Water refill points across campus",
```

- [ ] **Step 2: Add the FA keys** (insert in `app_fa.arb`; real translations, not machine fill — flag for native-translator review per `l10n.yaml`)

```json
  "mapLayersTitle": "لایه‌های نقشه",
  "mapVariantBase": "نقشهٔ پردیس",
  "mapVariantParking": "پارکینگ",
  "mapVariantParkingDesc": "پارکینگ بازدیدکنندگان و رویداد",
  "mapVariantAccessibility": "مسیرهای دسترس‌پذیر",
  "mapVariantAccessibilityDesc": "مسیرهای بدون پله و ورودی‌های دسترس‌پذیر",
  "mapVariantWater": "آب آشامیدنی",
  "mapVariantWaterDesc": "ایستگاه‌های پرکردن آب در پردیس",
```

- [ ] **Step 3: Regenerate and assert completeness**

Run: `flutter gen-l10n && test ! -s .dart_tool/untranslated_messages.json && echo "L10N COMPLETE"`
Expected: prints `L10N COMPLETE` (no untranslated keys — every EN key has a FA match).

- [ ] **Step 4: Confirm the generated getters exist**

Run: `grep -c "mapVariantWaterDesc" lib/l10n/generated/app_localizations.dart`
Expected: `1` or more (getter generated).

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/app_en.arb lib/l10n/app_fa.arb lib/l10n/generated
git commit -m "feat(map): M2 T4 — EN+FA strings for the layers picker"
```

---

### Task 5: `CampusVariantPicker` (RadioGroup bottom sheet)

**Files:**
- Create: `lib/widgets/campus_variant_picker.dart`
- Test: `test/widget/campus_variant_picker_test.dart`

**Interfaces:**
- Consumes: `campusVariantProvider`, `CampusVariantsData.eventVisible` (Tasks 1–2), the Task 4 strings, `context.aon`, `AonSpacing`.
- Produces: `class CampusVariantPicker extends ConsumerWidget` (`const CampusVariantPicker({super.key})`).

- [ ] **Step 1: Write the failing picker tests**

```dart
// test/widget/campus_variant_picker_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/data/campus_variants_data.dart';
import 'package:aon2026/services/campus_variant_providers.dart';
import 'package:aon2026/widgets/campus_variant_picker.dart';

Widget _host(ProviderContainer c, {Locale? locale}) => UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: const Scaffold(body: CampusVariantPicker()),
      ),
    );

void main() {
  testWidgets('lists Campus map + 3 public variants, NOT Permit areas', (t) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await t.pumpWidget(_host(c));
    await t.pumpAndSettle();
    expect(find.text('Campus map'), findsOneWidget);
    expect(find.text('Parking'), findsOneWidget);
    expect(find.text('Accessible routes'), findsOneWidget);
    expect(find.text('Drinking water'), findsOneWidget);
    // exactly the four rows (base + 3), permits absent
    expect(find.byType(RadioListTile<CampusMapVariant>), findsNWidgets(4));
  });

  testWidgets('selecting Parking updates the controller', (t) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await t.pumpWidget(_host(c));
    await t.pumpAndSettle();
    await t.tap(find.text('Parking'));
    await t.pump();
    expect(c.read(campusVariantProvider), CampusMapVariant.parking);
  });

  testWidgets('one RadioGroup owns the selection semantics', (t) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await t.pumpWidget(_host(c));
    await t.pumpAndSettle();
    expect(find.byType(RadioGroup<CampusMapVariant>), findsOneWidget);
  });

  testWidgets('320x568 / 2.0: all rows reachable, no overflow', (t) async {
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
    expect(t.takeException(), isNull); // no RenderFlex overflow
    expect(find.text('Drinking water'), findsOneWidget);
  });

  testWidgets('renders under FA without exception', (t) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await t.pumpWidget(_host(c, locale: const Locale('fa')));
    await t.pumpAndSettle();
    expect(find.text('پارکینگ'), findsOneWidget); // FA "Parking"
    expect(t.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/widget/campus_variant_picker_test.dart`
Expected: FAIL — `campus_variant_picker.dart` does not exist.

- [ ] **Step 3: Write the picker**

```dart
// lib/widgets/campus_variant_picker.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/data/campus_variants_data.dart';
import 'package:aon2026/services/campus_variant_providers.dart';

/// Bottom-sheet picker for the single thematic basemap variant. Uses a
/// `RadioGroup` ancestor (Flutter 3.44) — not the deprecated per-tile
/// `groupValue`/`onChanged`. Exactly one selection; base is an explicit row.
class CampusVariantPicker extends ConsumerWidget {
  const CampusVariantPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AonL10n.of(context);
    final selected = ref.watch(campusVariantProvider);
    return SafeArea(
      child: SingleChildScrollView(
        child: RadioGroup<CampusMapVariant>(
          groupValue: selected,
          // A null (framework deselect) maps to base in the controller.
          onChanged: (v) => ref.read(campusVariantProvider.notifier).select(v),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AonSpacing.space5,
                    AonSpacing.space4, AonSpacing.space5, AonSpacing.space2),
                child: Text(l.mapLayersTitle,
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              RadioListTile<CampusMapVariant>(
                value: CampusMapVariant.base,
                title: Text(l.mapVariantBase),
              ),
              for (final v in CampusVariantsData.eventVisible)
                RadioListTile<CampusMapVariant>(
                  value: v.variant,
                  title: Text(_label(l, v.variant)),
                  subtitle: Text(_desc(l, v.variant)),
                  secondary: _Swatch(color: v.swatch),
                ),
              const SizedBox(height: AonSpacing.space4),
            ],
          ),
        ),
      ),
    );
  }

  String _label(AonL10n l, CampusMapVariant v) => switch (v) {
        CampusMapVariant.parking => l.mapVariantParking,
        CampusMapVariant.accessibility => l.mapVariantAccessibility,
        CampusMapVariant.water => l.mapVariantWater,
        _ => l.mapVariantBase,
      };

  String _desc(AonL10n l, CampusMapVariant v) => switch (v) {
        CampusMapVariant.parking => l.mapVariantParkingDesc,
        CampusMapVariant.accessibility => l.mapVariantAccessibilityDesc,
        CampusMapVariant.water => l.mapVariantWaterDesc,
        _ => '',
      };
}

/// A legend colour chip. Uses the source-legend ink colour directly (documented
/// `context.aon` exemption); the ring uses theme chrome.
class _Swatch extends StatelessWidget {
  const _Swatch({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: AonSpacing.iconMd,
        height: AonSpacing.iconMd,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: context.aon.contentTertiary, width: 1),
        ),
      );
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/widget/campus_variant_picker_test.dart`
Expected: PASS (all). If `RadioListTile` asserts on a missing `groupValue`/`onChanged` under a `RadioGroup` ancestor, that is a real API mismatch — stop and re-check the installed `radio_list_tile.dart` signature rather than re-adding the deprecated params.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/campus_variant_picker.dart test/widget/campus_variant_picker_test.dart
git commit -m "feat(map): M2 T5 — CampusVariantPicker (RadioGroup sheet, EN+FA, 2.0)"
```

---

### Task 6: Map wiring — Layers button + note-clearance token + regressions

**Files:**
- Modify: `lib/screens/map_screen.dart`
- Test: `test/widget/map_variant_wiring_test.dart`

**Interfaces:**
- Consumes: `CampusVariantPicker` (Task 5), `campusVariantProvider`/`CampusMapVariant` (Tasks 1–2), `AonSpacing.minTapTarget`.
- Produces: a `MapMode.campusMap`-only glass Layers button opening the picker; the three status-note `Positioned`s clear both controls.

- [ ] **Step 1: Write the failing wiring + camera-preservation + real-modal tests**

```dart
// test/widget/map_variant_wiring_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/data/campus_variants_data.dart';
import 'package:aon2026/services/campus_variant_providers.dart';
import 'package:aon2026/services/location_providers.dart';
import 'package:aon2026/widgets/campus_basemap_layer.dart';
import 'package:aon2026/widgets/campus_variant_picker.dart';
import 'package:aon2026/widgets/user_location_layer.dart';
import 'package:aon2026/screens/map_screen.dart';
import '../support/fake_location_service.dart';

ProviderContainer _container(FakeLocationService svc) {
  final c = ProviderContainer(
      overrides: [locationServiceProvider.overrideWithValue(svc)]);
  addTearDown(c.dispose);
  c.read(mapVisibleProvider.notifier).set(true);
  return c;
}

Widget _app(ProviderContainer c) => UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: MapScreen(),
      ),
    );

MapCamera _cam(WidgetTester t) =>
    MapCamera.of(t.element(find.byType(MarkerLayer).first));

String _basemapAsset(WidgetTester t) {
  final layer = t.widget<OverlayImageLayer>(find.descendant(
      of: find.byType(CampusBasemapLayer),
      matching: find.byType(OverlayImageLayer)));
  final img = layer.overlayImages.single as OverlayImage;
  return (img.imageProvider as AssetImage).assetName;
}

void main() {
  testWidgets('Layers button opens the picker sheet', (t) async {
    final c = _container(FakeLocationService());
    await t.pumpWidget(_app(c));
    await t.pump();
    await t.tap(find.byTooltip('Map layers'));
    await t.pumpAndSettle();
    expect(find.byType(CampusVariantPicker), findsOneWidget);
  });

  testWidgets('selecting a variant swaps the basemap; dot + markers survive',
      (t) async {
    final svc = FakeLocationService();
    final c = _container(svc);
    await t.pumpWidget(_app(c));
    await c.read(locationControllerProvider.notifier).onLocateTapped();
    svc.emit(UserLocationFix(
        position: MapConfig.campusCentre, accuracyMeters: 10));
    await t.pump();
    await t.pump();
    expect(_basemapAsset(t), CampusVariantsData.baseAsset);
    final dotsBefore = find.byType(UserLocationDot).evaluate().length;
    c.read(campusVariantProvider.notifier).select(CampusMapVariant.parking);
    await t.pump();
    expect(_basemapAsset(t), 'assets/maps/overlay_parking_dark.png');
    expect(find.byType(UserLocationDot).evaluate().length, dotsBefore); // intact
    expect(find.byType(MarkerLayer), findsWidgets); // venue markers intact
    expect(t.takeException(), isNull);
  });

  testWidgets('variant swap preserves camera center + zoom (must-fix #5)',
      (t) async {
    final c = _container(FakeLocationService());
    await t.pumpWidget(_app(c));
    await t.pump();
    // Move OFF the fit so "unchanged" is a real assertion, not fit==fit.
    await t.tap(find.byTooltip('Zoom in'));
    await t.pump();
    final before = _cam(t);
    c.read(campusVariantProvider.notifier).select(CampusMapVariant.water);
    await t.pump();
    final after = _cam(t);
    expect(after.zoom, before.zoom); // no re-fit on variant change
    expect(after.center.latitude, before.center.latitude);
    expect(after.center.longitude, before.center.longitude);
    expect(_basemapAsset(t), 'assets/maps/overlay_water_dark.png'); // only ink changed
  });

  testWidgets('Layers button hidden in panorama mode', (t) async {
    final c = _container(FakeLocationService());
    await t.pumpWidget(_app(c));
    await t.tap(find.text('360°'));
    await t.pumpAndSettle();
    expect(find.byTooltip('Map layers'), findsNothing);
  });

  testWidgets('real modal at 320x568 / 2.0: open, select, no overflow',
      (t) async {
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1.0;
    t.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    final c = _container(FakeLocationService());
    await t.pumpWidget(_app(c));
    await t.pump();
    await t.tap(find.byTooltip('Map layers'));
    await t.pumpAndSettle();
    await t.tap(find.text('Parking'));
    await t.pump();
    expect(c.read(campusVariantProvider), CampusMapVariant.parking);
    expect(t.takeException(), isNull);
  });
}
```

Note: `MapConfig` and `UserLocationFix` are pulled in transitively; add explicit imports (`package:aon2026/widgets/map_config.dart`, `package:aon2026/models/user_location_fix.dart`, `package:latlong2/latlong.dart`) if the analyzer flags them.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/widget/map_variant_wiring_test.dart`
Expected: FAIL — no widget has tooltip `Map layers` (button not wired yet).

- [ ] **Step 3: Wire the Layers button and switch the note clearance to the token**

In `lib/screens/map_screen.dart`:

(a) Add the import near the other widget imports:
```dart
import 'package:aon2026/widgets/campus_variant_picker.dart';
```

(b) Replace **all three** status-note `Positioned` insets so they clear the left Layers button too. Change each occurrence of:
```dart
                      top: AonSpacing.space4,
                      left: AonSpacing.space4,
                      right: AonSpacing.space4 + 56, // clear the control island
```
to (the first note block — repeat the `left`/`right` edit for the other two, which currently read `right: AonSpacing.space4 + 56`):
```dart
                      top: AonSpacing.space4,
                      left: AonSpacing.space4 + AonSpacing.minTapTarget,
                      right: AonSpacing.space4 + AonSpacing.minTapTarget,
```

(c) Add the Layers button to the `Stack` (campus-map branch), immediately after the `MapControlIsland` `Positioned` (both live in the same `Stack`, which only builds in `MapMode.campusMap`):
```dart
                Positioned(
                  top: AonSpacing.space4,
                  left: AonSpacing.space4,
                  child: _LayersButton(
                    onTap: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      builder: (_) => const CampusVariantPicker(),
                    ),
                  ),
                ),
```

(d) Add the `_LayersButton` widget (next to `_MapNote` / `_MapAttribution`). One semantics node: the `IconButton`'s `tooltip` provides both the label and `button:true`; the glass `Container` is decorative and adds none.
```dart
/// Glass Layers button (top-left, campus-map only) — mirrors the top-right
/// control island. `minTapTarget`-sized; the note pills clear it via the same
/// token. The IconButton owns the sole semantics node (no wrapping Semantics).
class _LayersButton extends StatelessWidget {
  const _LayersButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AonL10n.of(context);
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
        tooltip: l.mapLayersTitle,
        icon: Icon(Icons.layers_rounded, color: context.aon.contentSecondary),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/widget/map_variant_wiring_test.dart`
Expected: PASS (all five). Then run the migrated M1 wiring suite to prove nothing regressed:
Run: `flutter test test/widget/map_platform_wiring_test.dart test/widget/map_location_wiring_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/map_screen.dart test/widget/map_variant_wiring_test.dart
git commit -m "feat(map): M2 T6 — Layers button + picker wiring; camera-preserving swap"
```

---

### Task 7: Verification & closeout (no new production code)

**Files:**
- Modify (closeout notes only): `docs/superpowers/specs/2026-08-15-aon-map-M2-thematic-variants-design.md` (§11 scorecard re-score, §8 memory result)

- [ ] **Step 1: Full quality gate**

Run: `./scripts/check.sh full`
Expected: all gates green (analyze, l10n EN+FA, full `flutter test`, reskin tests, web build, apk build, iOS build). Read the full output; if any gate is red, fix the *right* side (code/fixture/doc) — never loosen the gate.

- [ ] **Step 2: On-device variant swap (iOS) + memory/jank check (design §8)**

- `mcp__Claude_Code_iOS_Simulator__control` `attach`, then build+`launch`.
- Open the map, tap Layers, cycle base → Parking → Accessible routes → Drinking water → base, several times.
- Confirm: each swap repaints the whole basemap (ink changes), the user dot / markers / camera stay put, and there is no memory-pressure warning or visible jank. Record whether `ImageCache` growth stays bounded (≈56 MiB ceiling per §0 must-fix #2). If it grows unbounded or janks, open the eviction IOU (`await AssetImage(prev).evict()` on swap) — do not build it pre-emptively.
- Capture a screenshot of a variant selected for the closeout note.

- [ ] **Step 3: Re-score and record the result**

Update the design §11 scorecard with post-build scores (scores may go *down* — explain why), and replace §8's memory estimate with the on-device observation. Commit:
```bash
git add docs/superpowers/specs/2026-08-15-aon-map-M2-thematic-variants-design.md
git commit -m "docs(map): M2 verification + closeout — scorecard re-score, memory result"
```

- [ ] **Step 4: Finish the branch**

Use the `superpowers:finishing-a-development-branch` skill: verify the full suite is green on the branch, then present the merge/PR/keep menu for `feature/map-M2-thematic-variants` → `main`.

---

## Self-Review

**Spec coverage** (design §0 must-fixes + §10 testing): enum state (T1/T2), memory receipts (verified in §0; on-device confirm T7 step 2), evict API (documented §0, not built — correct), swap contract / asset-integrity (T1 integrity test + T3 single-image + T6 camera-preservation), camera/zoom/follow regression (T6 step 1 test 3), content-validity gate (T1 gate test), real-modal 2.0 (T6 step 1 test 5), single-semantics Layers button (T5 group test + T6 tooltip), note-clearance token (T6 step 3b), session-only wording (T2 doc comment). Registry / controller / layer / picker / wiring all covered. **No gaps.**

**Placeholder scan:** every code step carries complete, compilable code; no TBD/TODO. Persian strings are real (flagged for native review, per `l10n.yaml`).

**Type consistency:** `CampusMapVariant` (enum) and `CampusVariantsData.assetFor`/`byVariant`/`eventVisible`/`baseAsset` are named identically across T1→T6; `campusVariantProvider` / `CampusVariantController.select(CampusMapVariant?)` consistent T2→T6; `_basemapAsset`/`_cam` helpers match the existing `map_platform_wiring_test` idiom. `RadioGroup<CampusMapVariant>` / `RadioListTile<CampusMapVariant>` consistent T5→T6.
