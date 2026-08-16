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
- **AON theming for picker chrome** — `context.aon` tokens *or* the AON-derived `Theme.of(context).textTheme` (the app's `ThemeData` is built from AON tokens, so `titleLarge`/`RadioListTile` default theming are already AON; this is why Task 5 uses `Theme.of` for text and `context.aon` for the swatch ring). Swatches are the only *raw*-colour exemption — source-legend ink, documented in the design. (If the app `ThemeData` turns out not to derive text styles from AON tokens, theme the sheet text explicitly via `context.aon` instead.)
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
import 'package:flutter/painting.dart' show Color;
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

  test('registry covers every non-base enum value (no silent drift)', () {
    // assetFor() falls back to base for an unmatched enum. If someone adds a
    // CampusMapVariant and forgets the registry, that new value would quietly
    // render the base map. This makes the omission fail LOUDLY instead.
    final registered = CampusVariantsData.all.map((v) => v.variant).toSet();
    final expected = CampusMapVariant.values
        .where((v) => v != CampusMapVariant.base)
        .toSet();
    expect(registered, expected,
        reason: 'a CampusMapVariant has no registry row → assetFor silently uses base');
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
    // Compare Color objects directly — Color.value is @Deprecated (would flag
    // `flutter analyze`, which check.sh gates on). Color(int) ctor is fine.
    expect(CampusVariantsData.byVariant(CampusMapVariant.parking)!.swatch,
        const Color(0xFF3B82F6));
    expect(CampusVariantsData.byVariant(CampusMapVariant.base), isNull);
  });
}
```

```dart
// test/widget/campus_variant_assets_test.dart
import 'package:flutter/painting.dart'; // decodeImageFromList
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/data/campus_variants_data.dart';

void main() {
  // Real decode guard (design §0 must-fix #4): a renamed/missing PNG *and* a
  // truncated/corrupt one both fail HERE at CI, not as a blank map at runtime.
  // lengthInBytes>0 is NOT enough — a corrupt PNG can be non-empty. decode it,
  // and asserting the exact 2048x1448 also pins the projection-critical
  // dimensions and the §0 memory receipt.
  testWidgets('every base + variant asset decodes at 2048x1448', (t) async {
    // decodeImageFromList does REAL async decoding on the engine; a testWidgets
    // fake-async zone never advances real time, so the await hangs (10-min
    // timeout) unless wrapped in runAsync.
    await t.runAsync(() async {
      final paths = [
        CampusVariantsData.baseAsset,
        for (final v in CampusVariantsData.all) v.assetPath,
      ];
      for (final p in paths) {
        final data = await rootBundle.load(p);
        final image = await decodeImageFromList(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
        expect(image.width, 2048, reason: 'wrong width: $p');
        expect(image.height, 1448, reason: 'wrong height: $p');
        image.dispose();
      }
    });
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

- [ ] **Step 5: Per-task gate, then commit**

`./scripts/check.sh` must be green (analyze + l10n + full suite + reskin) — this is the mandated per-task gate; the `&&` chain will not commit if it fails.
```bash
./scripts/check.sh && \
git add lib/data/campus_variants_data.dart test/unit/campus_variants_data_test.dart test/widget/campus_variant_assets_test.dart && \
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

- [ ] **Step 5: Per-task gate, then commit**

```bash
./scripts/check.sh && \
git add lib/services/campus_variant_providers.dart test/unit/campus_variant_providers_test.dart && \
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

**Before editing, open the existing `test/widget/campus_basemap_layer_test.dart` and confirm its only substantive assertions are `overlayImages.length == 1` and `takeException() == null`.** The rewrite below MUST preserve both (it does — the "base" test keeps `length == 1` and adds the asset check). Do not drop an existing assertion while migrating; if the current file asserts anything not carried below, add it back.

```dart
// test/widget/campus_basemap_layer_test.dart  (migrate in place — preserve every existing assertion)
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
  // imageProvider is declared on BaseOverlayImage (overlay_image.dart:10), so
  // no cast to the OverlayImage subtype is needed.
  final img = layer.overlayImages.single;
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

- [ ] **Step 5: Per-task gate, then commit**

```bash
./scripts/check.sh && \
git add lib/widgets/campus_basemap_layer.dart test/widget/campus_basemap_layer_test.dart && \
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

- [ ] **Step 5: Per-task gate, then commit**

```bash
./scripts/check.sh && \
git add lib/l10n/app_en.arb lib/l10n/app_fa.arb lib/l10n/generated && \
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

  testWidgets('320x568 / 2.0: last row scrolls into view AND is tappable',
      (t) async {
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
    // find.text alone matches an OFF-SCREEN widget inside a SingleChildScrollView
    // (and a scroll view never RenderFlex-overflows, so takeException is vacuous
    // here). Scroll the last row in, then TAP it — that proves hit-testability.
    final target = find.text('Drinking water');
    await t.scrollUntilVisible(target, 100,
        scrollable: find.byType(Scrollable).first);
    await t.pumpAndSettle();
    await t.tap(target);
    await t.pump();
    expect(c.read(campusVariantProvider), CampusMapVariant.water);
    expect(t.takeException(), isNull);
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

- [ ] **Step 5: Per-task gate, then commit**

```bash
./scripts/check.sh && \
git add lib/widgets/campus_variant_picker.dart test/widget/campus_variant_picker_test.dart && \
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
import 'package:flutter/semantics.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/data/campus_variants_data.dart';
import 'package:aon2026/services/campus_variant_providers.dart';
import 'package:aon2026/models/user_location_fix.dart';
import 'package:aon2026/services/location_providers.dart';
import 'package:aon2026/widgets/campus_basemap_layer.dart';
import 'package:aon2026/widgets/campus_variant_picker.dart';
import 'package:aon2026/widgets/map_config.dart';
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

// A near, on-footprint fix — the M1 suite proves this renders a dot, so the
// "dot survives" assertion below is non-vacuous.
UserLocationFix _near() => UserLocationFix(
    position: LatLng(MapConfig.campusCentre.latitude + 0.001,
        MapConfig.campusCentre.longitude),
    accuracyMeters: 10);

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
  // imageProvider is declared on BaseOverlayImage (overlay_image.dart:10), so
  // no cast to the OverlayImage subtype is needed.
  final img = layer.overlayImages.single;
  return (img.imageProvider as AssetImage).assetName;
}

// Total markers across every MarkerLayer (venue pins + the dot's own layer).
int _markerCount(WidgetTester t) => t
    .widgetList<MarkerLayer>(find.byType(MarkerLayer))
    .fold(0, (sum, l) => sum + l.markers.length);

// The picker's own scrollable (not the map's or filter bar's).
Finder _sheetScroll() => find.descendant(
    of: find.byType(CampusVariantPicker), matching: find.byType(Scrollable));

void main() {
  testWidgets('Layers button opens the picker sheet', (t) async {
    final c = _container(FakeLocationService());
    await t.pumpWidget(_app(c));
    await t.pump();
    await t.tap(find.byTooltip('Map layers'));
    await t.pumpAndSettle();
    expect(find.byType(CampusVariantPicker), findsOneWidget);
  });

  testWidgets('variant swap keeps the dot, accuracy circle AND every marker',
      (t) async {
    final svc = FakeLocationService();
    final c = _container(svc);
    await t.pumpWidget(_app(c));
    await c.read(locationControllerProvider.notifier).onLocateTapped();
    svc.emit(_near());
    await t.pump();
    await t.pump();
    expect(find.byType(UserLocationDot), findsOneWidget);    // dot pre-swap
    expect(find.byType(UserLocationCircle), findsOneWidget); // accuracy circle pre-swap
    expect(_basemapAsset(t), CampusVariantsData.baseAsset);
    final markersBefore = _markerCount(t);
    expect(markersBefore, greaterThan(0)); // non-vacuous: markers actually exist
    c.read(campusVariantProvider.notifier).select(CampusMapVariant.parking);
    await t.pump();
    expect(_basemapAsset(t), 'assets/maps/overlay_parking_dark.png'); // ink changed
    expect(find.byType(UserLocationDot), findsOneWidget);            // dot survived
    expect(find.byType(UserLocationCircle), findsOneWidget);         // circle survived
    expect(_markerCount(t), markersBefore);       // same COUNT — not just "a layer"
    expect(t.takeException(), isNull);
  });

  testWidgets('variant swap preserves camera + zoom + FOLLOW + accuracy circle',
      (t) async {
    final svc = FakeLocationService();
    final c = _container(svc);
    await t.pumpWidget(_app(c));
    await c.read(locationControllerProvider.notifier).onLocateTapped();
    svc.emit(_near()); // active + following, on-footprint → dot + circle
    await t.pump();
    await t.pump();
    // Move OFF the fit so "unchanged" is a real assertion, not fit==fit. A
    // programmatic move fires onPositionChanged with hasGesture:false, so it
    // does NOT cancel follow.
    await t.tap(find.byTooltip('Zoom in'));
    await t.pump();
    final before = _cam(t);
    final followBefore = c.read(locationControllerProvider).following;
    expect(followBefore, isTrue); // precondition: we ARE following
    expect(find.byType(UserLocationCircle), findsOneWidget);
    c.read(campusVariantProvider.notifier).select(CampusMapVariant.water);
    await t.pump();
    final after = _cam(t);
    expect(after.zoom, before.zoom); // no re-fit on variant change
    expect(after.center.latitude, before.center.latitude);
    expect(after.center.longitude, before.center.longitude);
    expect(c.read(locationControllerProvider).following, followBefore); // follow intact
    expect(find.byType(UserLocationCircle), findsOneWidget);            // circle intact
    expect(_basemapAsset(t), 'assets/maps/overlay_water_dark.png');     // only ink changed
  });

  testWidgets('Layers button is exactly one "Map layers" button semantics node',
      (t) async {
    final handle = t.ensureSemantics();
    final c = _container(FakeLocationService());
    await t.pumpWidget(_app(c));
    await t.pump();
    // Duplicate-node regression: if a wrapping Semantics AND the IconButton both
    // labelled it, this would be findsNWidgets(2).
    expect(find.bySemanticsLabel('Map layers'), findsOneWidget);
    final node = t.getSemantics(find.byTooltip('Map layers'));
    expect(node.hasFlag(SemanticsFlag.isButton), isTrue);
    handle.dispose();
  });

  testWidgets('Layers button hidden in panorama mode', (t) async {
    final c = _container(FakeLocationService());
    await t.pumpWidget(_app(c));
    await t.tap(find.text('360°'));
    await t.pumpAndSettle();
    expect(find.byTooltip('Map layers'), findsNothing);
  });

  testWidgets('real modal at 320x568 / 2.0: open → scroll to last → select → LAYER swaps',
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
    // Drinking water is the BOTTOM row — Parking sits near the top and would
    // pass even if the sheet were clipped at 320×568/2.0.
    final target = find.text('Drinking water');
    await t.scrollUntilVisible(target, 100, scrollable: _sheetScroll());
    await t.pumpAndSettle();
    await t.tap(target);
    await t.pump();
    // Full path in ONE test: button → sheet → controller → basemap layer.
    expect(c.read(campusVariantProvider), CampusMapVariant.water);
    expect(_basemapAsset(t), 'assets/maps/overlay_water_dark.png');
    expect(t.takeException(), isNull);
  });
}
```

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

- [ ] **Step 5: Per-task gate, then commit**

```bash
./scripts/check.sh && \
git add lib/screens/map_screen.dart test/widget/map_variant_wiring_test.dart && \
git commit -m "feat(map): M2 T6 — Layers button + picker wiring; camera-preserving swap"
```

---

### Task 7: Verification & closeout (no new production code)

**Files:**
- Modify (closeout notes only): `docs/superpowers/specs/2026-08-15-aon-map-M2-thematic-variants-design.md` (§11 scorecard re-score, §8 memory result)

- [ ] **Step 1: Full quality gate**

Run: `./scripts/check.sh full`
Expected: all gates green (analyze, l10n EN+FA, full `flutter test`, reskin tests, web build, apk build, iOS build). Read the full output; if any gate is red, fix the *right* side (code/fixture/doc) — never loosen the gate.

- [ ] **Step 2: iOS *Simulator* smoke test + measured memory (design §8)**

This is a **simulator smoke test, not a physical-device test** — label it as such in the closeout. flutter_map has documented `OverlayImage`/Impeller rendering issues, so the simulator run does not by itself close the rendering/memory requirement (Step 3 records the physical-device IOU).
- `mcp__Claude_Code_iOS_Simulator__control` `attach`, then build + `launch`.
- Open the map, tap Layers, cycle base → Parking → Accessible routes → Drinking water → base several times.
- Confirm each swap repaints the whole basemap (ink changes) and the dot / accuracy circle / markers / camera stay put; no visible jank.
- **Memory — measured, not asserted:** record a BASELINE (before opening the picker) and the DELTA after cycling all five — `PaintingBinding.instance.imageCache.currentSize` (entry count), `.currentSizeBytes`, and DevTools process RSS. Five 2048×1448 RGBA images are ~56 MiB of *raw decoded pixels* — a raw footprint, **not** a hard `ImageCache` or process ceiling (the cache defaults to 100 MiB / 1000 entries and separately tracks live refs). Report the real numbers, not the estimate.
- Only if cache bytes / RSS climb without bound across cycles, open the eviction IOU: resolve the previous asset's key and call `PaintingBinding.instance.imageCache.evict(key, includeLive: false)` — `includeLive: false` is the correct memory-pressure policy (`ImageProvider.evict()` uses the default `includeLive: true`, which can force reloads). Do not build it pre-emptively.
- Capture a screenshot of a selected variant for the closeout note.

- [ ] **Step 3: Re-score, record the result, log the release IOU**

Update the design §11 scorecard with post-build scores (scores may go *down* — explain why), and replace §8's memory estimate with the measured simulator numbers. **Log a release-gate IOU:** "M2 rendering/memory confirmed on the iOS Simulator only; a physical iOS device (release/profile) smoke test — and an Android runtime smoke test — remain before the requirement is closed" (builds alone don't exercise the image swap). Commit:
```bash
git add docs/superpowers/specs/2026-08-15-aon-map-M2-thematic-variants-design.md
git commit -m "docs(map): M2 verification + closeout — scorecard re-score, memory result"
```

- [ ] **Step 4: Finish the branch**

Use the `superpowers:finishing-a-development-branch` skill: verify the full suite is green on the branch, then present the merge/PR/keep menu for `feature/map-M2-thematic-variants` → `main`.

---

## Self-Review

**Every claimed guarantee has executable evidence** (design §0 must-fixes + §10 testing) — each claim below names the test that actually proves it, not a proxy:
- **enum state** → T1/T2 (incl. registry-vs-enum drift test, `select(null)→base`).
- **asset integrity / decode** → T1 *decodes* each PNG and asserts 2048×1448 (not `lengthInBytes>0`).
- **one image, correct image** → T3 (`overlayImages.length==1` + asserted `assetName`, migrated with `ProviderScope`, existing assertions preserved).
- **camera + zoom + follow + accuracy circle preserved** → T6 test 3 asserts all four (zoom moved off-fit first; `following` and `UserLocationCircle` checked before/after).
- **dot + every marker survive** → T6 test 2 asserts a non-zero marker COUNT is unchanged (not merely "a MarkerLayer exists").
- **single "Map layers" semantics node** → T6 dedicated test: `find.bySemanticsLabel` findsOneWidget + `isButton` flag.
- **real button→sheet→controller→layer path at 320×568/2.0** → T6 real-modal test scrolls to the BOTTOM row and asserts the basemap asset swapped.
- **picker reachable at 320×568/2.0** → T5 scrolls the last row in and TAPS it (a scroll view never RenderFlex-overflows, so `takeException` alone was vacuous).
- **content-validity gate** → T1 (`eventVisible ⇒ contentApproved`).
- **memory** → measured (baseline+delta, entry count, cache bytes, RSS) at T7 step 2; ~56 MiB documented as raw footprint, not a ceiling.
- **eviction IOU** → correct policy documented (`imageCache.evict(key, includeLive:false)`), not built.
- **note-clearance token / session-only** → T6 step 3b (`AonSpacing.minTapTarget`) / T2 doc comment.

Registry / controller / layer / picker / wiring all covered with real receipts. The one honest limitation: **the on-screen render is closed on the iOS *Simulator* only** — physical iOS + Android smoke tests are a logged release-gate IOU (T7 step 3), not a silent gap.

**Placeholder scan:** every code step carries complete, compilable code; no TBD/TODO. Persian strings are real (flagged for native review, per `l10n.yaml`).

**Type consistency:** `CampusMapVariant` (enum) and `CampusVariantsData.assetFor`/`byVariant`/`eventVisible`/`baseAsset` are named identically across T1→T6; `campusVariantProvider` / `CampusVariantController.select(CampusMapVariant?)` consistent T2→T6; `_basemapAsset`/`_cam` helpers match the existing `map_platform_wiring_test` idiom. `RadioGroup<CampusMapVariant>` / `RadioListTile<CampusMapVariant>` consistent T5→T6.
