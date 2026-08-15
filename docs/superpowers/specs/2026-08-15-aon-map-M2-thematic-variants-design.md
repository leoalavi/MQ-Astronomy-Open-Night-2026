# M2 — Thematic Map Variants (design)

**Status:** design, pre-gauntlet. Phase M2 of the map-parity program. On `feature/map-M2-thematic-variants` (off `main`, post M0+M1).

**Parent:** `2026-08-15-aon-map-parity-program-design.md` §3 (capability matrix: "thematic layers = exclusive reskinned variants") + §6 M2.

## 0. Gauntlet amendment (post external review) — AUTHORITATIVE

An external review of this design landed six must-fixes. Verified each against
installed Flutter source (`/opt/homebrew/share/flutter`) and the real M0 assets;
**where this section conflicts with the body below (§§3–8), this section wins.**
Verify-before-apply split — all six adopted, receipts inline:

1. **State is a non-null `enum`, not `String?`/`null=base` — ADOPTED (real bug).**
   `RadioGroup` uses `null` as the framework's *deselect / nothing-selected*
   sentinel: `radio_group.dart:159` calls `onChanged(null)` when a selected
   radio is toggled off, and `:71` documents "The value can be null when
   unselect." So `null=base` overloads the one value the framework already owns.
   Fix: `enum CampusMapVariant { base, parking, accessibility, water, permits }`;
   `NotifierProvider<CampusVariantController, CampusMapVariant>` with
   `build() => CampusMapVariant.base`. Picker is `RadioGroup<CampusMapVariant>`
   (non-null `groupValue`); `onChanged` maps a stray `null` (framework deselect)
   back to `base` — `select(v ?? CampusMapVariant.base)` — so base is always an
   explicit, highlighted row and `select('banana')` is now a compile error.
   (My earlier self-gauntlet held `String?` as valid — it was wrong; this is the
   deeper semantic collision it missed.)

2. **Memory numbers now carry receipts — ADOPTED; the estimates were correct.**
   Measured (`sips`) — every M0 output is **2048×1448**, decoded RGBA **11.3 MiB**
   each; disk: base 825 KiB, parking 1032, water 1191, permits 1267,
   accessibility 1450. One on screen = 11.3 MiB; all five in `ImageCache` ≈
   **56 MiB** (5×11.3), inside the 100 MiB default. §8's numbers stand, verified.

3. **Future eviction API corrected — ADOPTED.** `ImageCache.evict` takes a
   *resolved key* (`image_cache.dart:244 bool evict(Object key)`), not an
   `ImageProvider`; the design's `imageCache.evict(AssetImage(prev))` was wrong.
   Correct (if ever needed): `await AssetImage(prev).evict();`
   (`image_provider.dart:611 Future<bool> evict(...)`). Still not built
   pre-emptively — gated behind the §8 on-device measurement.

4. **Swap contract defined — ADOPTED, scoped to bundled reality.** All 5 are
   **bundled** assets, so "decode failure" is a *missing/renamed asset*, caught
   at CI by an asset-integrity test (`rootBundle.load` + non-zero dimensions for
   every asset), not a runtime handler. The layer keeps a `?? base` fallback for
   an unknown id. "Seamless" means: the swap changes only `OverlayImage.imageProvider`;
   `MapConfig.mapBounds` is unchanged, so the campus does not move; the picker
   `precacheImage`s a variant on first build to warm the cache. No loading-state
   machinery (bundled decode is sub-frame); no full precache-all (would pin 56 MiB).

5. **Camera/zoom/follow preservation regression — ADOPTED.** New wiring test:
   move the camera off the fit, select a variant, assert `camera.center`,
   `camera.zoom` and the follow state are byte-identical afterwards and only the
   asset changed. This is what proves "only its ink changes."

6. **Content-validity gate before `eventVisible` — ADOPTED as a release assert.**
   A variant may be `eventVisible: true` only once its underlying data is signed
   off for the event. M2 asserts an inherited receipt (`docs/fixtures/` provenance
   already gates M0 content); the test fails if a variant is event-visible without
   a recorded approval. Permits stays `eventVisible: false`.

Tightenings folded in: the note-clearance magic `+56` is exactly
`AonSpacing.minTapTarget` (verified `aon_spacing.dart:31`) — use the token, and
size the Layers button to `minTapTarget`; the Layers button exposes **one**
semantics node (let the `IconButton` own it, no wrapping `Semantics`); persistence
language is **"session-only, not persisted to storage."** The real-modal 2.0 test
pumps the actual `MapScreen` → Layers → sheet, not the picker in isolation.

## 1. Goal

A **single-select** picker that swaps the illustrated basemap between the plain dark campus and one **reskinned thematic variant** — Parking, Accessible routes, Drinking water (Permit areas built but hidden). Because each M0 variant *is* a full reskinned basemap (the whole campus re-inked for one theme, ~94% opaque), a "layer" is just **which single image `CampusBasemapLayer` renders** — one decode at a time. This is the coherent replacement for the abandoned C1's translucent stacking.

## 2. Why exclusive (not the dead C1's `Set<String>`)

The M0 assets are alternate full basemaps, not additive deltas (measured: ~94% opaque, ~95% shared canvas). Stacking three at partial opacity would be visual mud and ~3× the memory. So M2 renders **exactly one** image: the base, or one variant. State is `String?` (null = base), never a set. This also caps decoded raster to one 11.3 MiB image on screen (§8).

## 3. Architecture

```
campusVariantProvider (String? — null=base, or a variant id)   ← single-select controller
        ↓ watch
CampusBasemapLayer (M1, now Consumer) → OverlayImage(asset = selected variant OR base)
        ↑ select
CampusVariantPicker (radio sheet) ── opened by ── a "Layers" button on the map
```

**Files (create):** `lib/data/campus_variants_data.dart` (registry), `lib/services/campus_variant_providers.dart` (controller), `lib/widgets/campus_variant_picker.dart` (sheet), mirrored tests.
**Files (modify):** `lib/widgets/campus_basemap_layer.dart` (M1 `StatelessWidget` → `ConsumerWidget` reading the variant; its M1 test migrates to add a `ProviderScope`), `lib/screens/map_screen.dart` (+Layers button), `lib/l10n/app_en.arb` + `app_fa.arb`.
**No new assets** (M0 shipped all 5), **no new dependency.**

## 4. Registry

`CampusVariant { String id; String assetPath; Color swatch; bool eventVisible; }` — labels/descriptions localised by `id` in the picker (data stays widget/l10n-free, like Phase A/B).

| id | asset (M0) | swatch (MQ legend) | eventVisible |
|---|---|---|:--:|
| `parking` | `assets/maps/overlay_parking_dark.png` | `#3B82F6` blue | ✅ |
| `accessibility` | `assets/maps/overlay_accessibility_dark.png` | `#A855F7` purple | ✅ |
| `water` | `assets/maps/overlay_water_dark.png` | `#06B6D4` cyan | ✅ |
| `permits` | `assets/maps/overlay_permits_dark.png` | `#F97316` orange | ❌ (built, hidden) |

`CampusVariantsData.all` (4), `.eventVisible` (3), `.byId(id)`. Base is **not** a registry row — it's the `null`/absent state (asset `assets/maps/mqcampus_dark.png`, owned by `CampusBasemapLayer`). Swatches are **source-legend colours** (documented exemption from `context.aon`, as the C1 review allowed — they identify the map's own ink, not app chrome).

## 5. State — single-select, not persisted

`campusVariantProvider = NotifierProvider<CampusVariantController, String?>` (default `null` = base; `Notifier<String?>` with `build() => null` — plain Notifier, valid in Riverpod 3.4.2). `CampusVariantController.select(String? id)` sets the state (`null` clears to base). **No separate `toggle`** — the picker is a radio group whose base is an explicit `select(null)` row, so a single `select` covers every transition (YAGNI; drop the method). **Non-persistent** — transient viewing state (matches M1's overlay stance; persistence is a program IOU if a need appears). Only valid ids take effect: `select(id)` with an unknown non-null id is ignored (`CampusVariantsData.byId(id) == null` → no-op), so state is always `null` or a real variant.

## 6. Rendering — one image swap

`CampusBasemapLayer` becomes a `ConsumerWidget`:
```dart
final id = ref.watch(campusVariantProvider);
final asset = id == null
    ? 'assets/maps/mqcampus_dark.png'
    : (CampusVariantsData.byId(id)?.assetPath ?? 'assets/maps/mqcampus_dark.png');
return OverlayImageLayer(overlayImages: [
  OverlayImage(bounds: MapConfig.mapBounds, imageProvider: AssetImage(asset)),
]);
```
Full opacity (the variant *is* the basemap — no translucency). The M1 dot/accuracy-circle/markers sit **on top**, unaffected by the swap (they read the projection, not the image). The swap is seamless because every variant shares the same calibrated footprint (`MapConfig.mapBounds`) — the campus doesn't move, only its ink changes.

## 7. Picker + Layers button

- **`CampusVariantPicker`** (`ConsumerWidget`, bottom sheet): a **`RadioGroup<String?>`** — **not** `RadioListTile.groupValue`/`.onChanged`, which are **`@Deprecated` in Flutter 3.44** (verified: `radio_list_tile.dart:164,169` — "use a RadioGroup ancestor"; the deprecation would fail `flutter analyze`, which `check.sh` blocks on). Shape:
  ```dart
  RadioGroup<String?>(
    groupValue: ref.watch(campusVariantProvider),
    onChanged: (id) => ref.read(campusVariantProvider.notifier).select(id),
    child: Column(children: [
      RadioListTile<String?>(value: null, title: Text(l.mapVariantBase), ...),   // "Campus map"
      for (final v in CampusVariantsData.eventVisible)
        RadioListTile<String?>(value: v.id, title: Text(_label(l, v.id)),
            subtitle: Text(_desc(l, v.id)), secondary: _swatch(v.swatch)),
    ]),
  )
  ```
  `SafeArea` + `SingleChildScrollView` for 320×568/2.0. a11y: one radio group, each option labelled; the selected state is announced by the framework. Permits never listed.
- **Layers button** (`map_screen`): a `Positioned(top-left)` themed glass icon button (`Icons.layers_rounded`), `Semantics(button, label: l.mapVariantsTitle)`, **only in `MapMode.campusMap`** (hidden in panorama). Mirrors M1's top-right control island on the opposite corner. Opens the picker via `showModalBottomSheet(isScrollControlled, useSafeArea)`. **Collision fix:** the map status notes (off-campus / low-accuracy / locating) are `Positioned(left: space4, right: space4+56)` — the `+56` clears M1's right-hand island but NOT a new left button; M2 must widen the notes to `left: space4+56` so they clear the Layers button too (verified against `map_screen.dart` — the notes currently start at `left: space4`).

## 8. Memory — one on screen, cache-bounded

Only one variant renders at a time (11.3 MiB decoded — M0 gate). But Flutter's `ImageCache` retains recently-decoded images, so cycling all 5 could hold ~56 MiB in cache (5 × 11.3). That's within the default 100 MiB cache but non-trivial. **Verification gate (Task N):** switch through all variants + base repeatedly on-device; confirm no memory-pressure/jank and that the cache doesn't grow unbounded. If it does, evict the previous variant on swap (`imageCache.evict(AssetImage(prev))`) — not built pre-emptively.

## 9. Global constraints (inherited)

- **No new dependency / no new asset.** Web build stays a hard gate (asset swap is web-safe).
- **`context.aon`** for picker chrome; swatches are source-legend colours (documented exemption).
- **EN + FA** for the picker title + 3 variant labels/descriptions (build asserts FA completeness via `check.sh`).
- **320×568 / 2.0** for the picker and the new Layers button (collision check on the map).
- **Accessibility (program §9, narrowed):** the picker is a fully-labelled radio group; the *variant artwork* carries baked English legend — an accepted limitation (IOU-P1), not a critical channel (all event tasks remain reachable without reading the map).
- **TDD; never weaken an existing test.** M1's `campus_basemap_layer_test` migrates (add `ProviderScope`), not deleted. Full suite stays green.
- **Per-task gate:** `./scripts/check.sh` (analyze + l10n + test + reskin); `full` (web/apk/iOS) + on-device variant-swap render at closeout.

## 10. Testing

- **Registry:** exactly `{parking, accessibility, water, permits}`; `eventVisible` = the first three; `byId` works; every `assetPath` under `assets/maps/` and ends `_dark.png`.
- **Controller:** default `null`; `select('parking')` → `'parking'`; `select(null)` → base; exclusive (selecting a second variant replaces the first, never accumulates); unknown non-null id → no-op (state stays as it was).
- **`CampusBasemapLayer`:** `null` → renders the base asset; `'water'` → renders `overlay_water_dark.png` (assert the `OverlayImage.imageProvider` `AssetImage.assetName`); one image only.
- **Picker:** lists "Campus map" + Parking + Accessible routes + Drinking water (NOT Permit areas); selecting Parking sets the controller and checks that row; a11y radio semantics; 320×568/2.0 no overflow; renders under FA.
- **Wiring (regression):** the Layers button opens the picker; selecting a variant swaps the basemap asset while the user dot + venue markers still render (M1 intact); panorama toggle still switches; Layers button hidden in panorama.
- **Verification:** `check.sh full`; on-device **variant swap repaints** (iOS) + the memory/jank gate (§8).

## 11. Scorecard (M2, pre-build)

| Axis | Score | Raises it |
|---|---:|---|
| Parity coverage | 4/10 | Overlay-variant system closed (M2); buildings/search (M3), routing (M4), AR (M5) remain. |
| Additive safety | 8/10 | Only the basemap image changes; M1 dot/markers/projection untouched; proven by the wiring regression. |
| Night legibility | 7/10 | Variants are the M0 reskin (already gated); full opacity, no muddy stacking. |
| Memory | 7/10 | One decode on screen; cache bound verified on-device (§8). |
| A11y / 2.0 / FA | 8/10 | Radio group labelled + 2.0 + EN/FA; baked-legend limitation named. |

## 12. Open questions

1. **Deselect UX** — RESOLVED: the "Campus map" (`value: null`) radio row is the way back to base; no `toggle` (radios don't self-deselect, and an explicit base row is clearer).
2. **Layers-button corner** — top-left (opposite M1's top-right island); notes widened to clear it (§7); re-check at 2.0 for collision with the mode toggle / filter bar above.
3. **Permits reveal** — stays hidden (`eventVisible=false`) unless operations asks; one-line data flip.

## 13. Next step

On approval → gauntlet this design, then the M2 TDD plan (registry → controller → basemap-layer swap + migrate M1 test → l10n → picker → map wiring + regression → verification incl. on-device swap + memory). No code before the plan is gauntletted.
