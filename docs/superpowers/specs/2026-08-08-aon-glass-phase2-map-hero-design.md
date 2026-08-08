# Phase 2 — Map + Hero Glass (Design)

**Date:** 2026-08-08 (Australia/Sydney)
**App:** aon2026 (Astronomy Open Night 2026)
**Reference implementation:** `../MQ_Journey` (design source of truth; behaviour read from source
line-by-line, not reconstructed from memory).
**Naming:** "Liquid Glass-inspired" / "Glass UI layer" only — never "Liquid Glass" unqualified.
**Builds on:** Phase 1 (`2026-08-08-aon-glass-liquid-nav-phase1-design.md`) — the `GlassSurface`
primitive, `AonGlass` tokens, `GlassShaderCache`, fallback ladder, and `AonNavMetrics` all shipped
and are **consumed**, not re-built, here.
**Status:** Frozen for spec self-review → user review → implementation plan. Not implemented.

---

## 1. Goal

Deliver the **glass payoff Phase 1 deliberately deferred**: real refraction over the app's rich
backdrops — the **live map tiles** and the **hero photograph** — plus the faithful map filter-chip
treatment. On completion the app *visibly* turns to glass where MQ_Journey's governance says glass
belongs, and **only** there.

**Nature of this work (honest framing):** a **governance-faithful port** of MQ_Journey's non-nav
glass usage, adapted to an app that is materially simpler than the reference (no camera, AR,
panorama, or webview). The value is *distribution* (aon2026 inherits a proven, governed system) plus
two honest aon2026 adaptations — the **floating map control island** (recenter relocated from the app
bar + zoom, over live tiles) and the **hero glass date pill** (glass over the galaxy photo). It is
recombination, not invention, and does not pretend otherwise.

**The governance finding that shapes this phase (load-bearing):** MQ_Journey enforces four rules that
make a naive "glass everything" reading *wrong*:
1. **No nested or overlapping glass layers.** A grouped/segmented control uses **one** glass parent
   (never a glass child inside a glass parent); **independent** sibling controls may each use glass when
   that matches the reference pattern. (This is why the map control island is one glass surface with three
   plain buttons — §5.2 — while the category chips are independently glassed, exactly as MQ does them,
   `map_page.dart:1231` — §5.3. The forbidden thing is glass-*on*-glass, not two glass siblings.)
2. **Text-bearing sheets/panels = `content` tier (near-opaque, no refraction).** Sheets stay solid.
3. **Primary actions stay solid brand colour, deliberately not glass** (MQ's recenter FAB and
   *selected* chips are solid; glass carries only secondary/inactive state).
4. **Content pages keep the standard opaque AppBar** — *"glass is a navigation/control-layer material,
   not a texture for everything"* (`glass_app_bar.dart:8-10`). MQ reserves glass app bars for **immersive
   media surfaces** that use `extendBodyBehindAppBar: true` (camera / 360° panorama / AR). The aon2026 Map
   is live visual content, but it is **not** that immersive pattern: its opaque AppBar stays the
   navigation/content boundary while glass is confined to controls *over* the map. So the Map AppBar stays
   opaque by design — not because "the map isn't live," but because it isn't adopting the immersive-media
   app-bar pattern.

Phase 2 therefore has a small, sharp adoption set and an explicit, reasoned **non**-adoption set. Doing
less on the app bars / FAB / sheets is not laziness — it is what parity with the reference *requires*.

### Non-goals (Phase 2)
- No glass on app bars (rule 4 — aon2026 content pages keep the opaque `night950` AppBar).
- No glass on the Directions FAB (rule 3 — primary action stays solid amber).
- No glass on bottom sheets (rule 2 — already solid `night900` = the `content` rung).
- No glass on marker pins or the OSM attribution label (not a control layer; tiny night text legibility).
- No `GlassPane` port (see §3 — it is a legacy shim; the real primitive already shipped in Phase 1).
- No new routes, screens, or IA. **One** new product behaviour only: explicit map zoom controls
  (recenter is a *relocation*, not new). The hero pill reuses existing content — no new behaviour.
- No app-wide text-scale policy change (still deferred to Phase 5, per Phase 1 §6.3).

## 2. Source-of-truth model (unchanged from Phase 1)

- **From MQ_Journey:** which surfaces are glass and at which tier; the two-tier governance; the
  control-glass patterns for map controls and filter chips; glass-over-imagery practice.
- **aon2026 owns (do not regress):** `AonColors`/`AonTheme`/`AonSpacing`/`AonTypography`, dark-only,
  night readability (≥13px floor), 56px targets, larger radii, the hero photo, the **dark tile
  layer** (single layer — see §5.1), product behaviour + IA.
- **Portability principle (unchanged):** the shell/screens inject aon2026 colours/config into the
  generic `GlassSurface`; no portable primitive imports `AonColors`/`AonTheme`.

## 3. No new primitive — a corrected Phase-1 deferral

Phase 1 §10 deferred *"`GlassPane` primitive (no Phase-1 consumer) → Phase 2, where the map controls
first consume it."* Reconnaissance against the reference **corrects this**: `GlassPane`
(`MQ_Journey/lib/shared/widgets/glass_pane.dart`, 36 lines) is a **legacy shim** — `GlassSurface(control)`
with a `borderRadius` and a debug `assert`, retained only for old call sites; its own doc says new code
should call `GlassSurface` directly, which MQ's newer map/scan code does. aon2026's `GlassSurface`
already shipped in Phase 1. **Phase 2 consumes it directly and ports no shim.** This is a
verify-against-reality simplification, not a scope cut — the deferral assumed the wrong primitive.

**No new reusable glass widget either (gauntlet R1).** An earlier draft proposed an `AonGlassIconButton`
"circular glass icon button" justified as "the island reuses it 3×" — but that is a contradiction: the
island is deliberately **one** `GlassSurface` with plain buttons inside (§5.2), because three separate
glass circles would be the glass-on-glass this phase forbids (governance rule 1). Every other candidate
(attribution, FAB, marker pins) is a non-adoption (§6). So such a widget would have **no consumer** and
violate the Phase-1 "every abstraction has a caller" rule. It is **cut**. `MapControlIsland` is a single
self-contained widget composing `GlassSurface(control)` + a `Column` of plain `IconButton`s.

## 4. Concrete files

**Create**
- `lib/widgets/map_control_island.dart` — `MapControlIsland` (a single vertical `GlassSurface(control)`
  island composing zoom-in / zoom-out / recenter as **one** glass surface = one control layer). Takes
  **injected callbacks** `onRecenter` / `onZoomIn` / `onZoomOut` (no `MapController` dependency — the
  screen wires them). Exposes a pure top-level `double clampZoom(double current, double delta, {required
  double min, required double max})` helper used by the screen's zoom wiring and unit-tested directly.
- `test/widget/map_control_island_test.dart` — renders one `GlassSurface` + three buttons; each button
  fires its injected callback; reduced-motion → frost rung; unit tests for `clampZoom` at/inside/outside
  both bounds. **No `FlutterMap` mounted** (R2).
- `lib/widgets/map_category_filter_bar.dart` — **`MapCategoryFilterBar`** (public), extracted from the
  private `_CategoryFilterBar` so it is test-mountable **without** the live map (P1-#1). Map-specific
  presentation, **not** a new glass primitive; injected `categories` / `selected` / `onToggle`. Owns the
  glass chip rendering; `MapScreen` keeps the filter *state*. A private `_MapCategoryChip` may live inside
  this file (the test mounts the public bar and inspects chip subtrees).
- `test/widget/map_glass_surfaces_test.dart` — mounts the public `MapCategoryFilterBar` (no live map):
  an unselected chip subtree contains `GlassSurface(control)`; a selected chip subtree is solid amber (no
  `GlassSurface`); tapping fires `onToggle`; one coherent `Semantics(button, selected, label)` node per
  chip (no duplicate label read — P2-#7); chip hit target ≥ `AonSpacing.minTapTarget` (56) at 1.0 and 2.0
  (P2-#6).
- `test/widget/hero_glass_test.dart` — hero date pill renders (structure/rung/text/wrap/overflow only;
  visual legibility is a runtime check, §8/P2-#10).

**Modify**
- `lib/screens/map_screen.dart` —
  - remove the app-bar **Recentre** `IconButton` (relocated into the island); Map AppBar becomes
    title-only, still opaque `night950` (governance rule 4).
  - add `MapControlIsland` as a `Positioned` child of the map `Stack` per the placement rule in §5.2;
    wire its callbacks to `_controller.move(...)` using `clampZoom` for the zoom bounds (§5.2).
  - replace the private `_CategoryFilterBar` with the extracted `MapCategoryFilterBar` (state stays here).
  - `_MapAttribution`, `_MarkerPin`, the Directions FAB: **unchanged** (non-adoptions, §6).
- `lib/screens/home_screen.dart` — wrap the `_Hero` date/time `Row` (lines 223-245) in a
  `GlassSurface(control)` pill over the galaxy photo (§5.4); title/eyebrow/scrim unchanged.
- `test/widget/responsive_layout_test.dart` — add the **home hero** at 320/414 × {1.0, 1.3, 1.6, 2.0}
  (Home is already a safe mount). The map is covered at the **component** level (island + glass chips
  standalone, R3) — `MapScreen` is **not** added here because its live `DarkTileLayer` hits the network
  and has no `errorBuilder`, which is exactly why the existing suite omits Map. Integrated map layout
  (island / FAB / attribution non-overlap) is verified on-device (§8).

No changes to `glass_surface.dart`, `aon_glass.dart`, `glass_shader.dart`, `nav_metrics.dart`,
`liquid_tab_bar.dart`, `pubspec.yaml`, or `main.dart` — Phase 2 is pure consumption of Phase 1.

## 5. Architecture

### 5.1 Map: single tile layer (verified — bounds the design)
`DarkTileLayer` renders **one** OSM raster layer, colour-matrix-darkened; `MapConfig` defines
`minZoom 14 / maxZoom 19 / initialZoom 16.2` and `campusCentre`. There is **no** alternate base map,
so a "layers" control has no basis and is **not** built. The controls with a real basis are **recenter**
(exists) and **zoom** (the range is defined; pinch-only is a weak affordance for gloved/one-handed
use at a dark field). Confirmed: `dark_tile_layer.dart:17`, `map_config.dart:13-15,35`.

### 5.2 Map control island (the refraction payoff)
`control`-tier glass over the live tiles is MQ's signature map look and the strongest refraction in the
app (real tiles behind the glass; `flutter_map` renders tiles as ordinary Flutter widgets on mobile —
**not** a platform view — so a `BackdropFilter` shader *can* sample them; `allowShader` stays default
`true`).

- **`MapControlIsland`** — a **single** `GlassSurface(control)` (one control layer — governance rule 1),
  `borderRadius: radiusFull`, `padding: EdgeInsets.all(4)`, child a vertical `Column(mainAxisSize.min)` of
  three transparent `IconButton`s (zoom-in `add_rounded`, zoom-out `remove_rounded`, recenter
  `my_location_rounded`) separated by thin dividers. It is one glass surface with three glyphs (exactly
  MQ's segmented-toggle construction: one `GlassSurface` + a `Row/Column` of segments), **not** three
  glass circles (glass-on-glass, R1). It has **no `MapController` dependency** — it takes injected
  callbacks `onRecenter` / `onZoomIn` / `onZoomOut`, which is what makes it unit-testable without a map.
- **Camera wiring (in `map_screen.dart`, not the island):** the screen wires the callbacks to the live
  `MapController`, using the pure `clampZoom` helper so the *logic* is testable in isolation:
  - recenter: `move(MapConfig.campusCentre, MapConfig.initialZoom)` (identical to today's app-bar action).
  - zoom-in: `move(camera.center, clampZoom(camera.zoom, +1, min: MapConfig.minZoom, max: MapConfig.maxZoom))`.
  - zoom-out: `move(camera.center, clampZoom(camera.zoom, −1, min: MapConfig.minZoom, max: MapConfig.maxZoom))`.
  - `MapConfig.minZoom` / `maxZoom` are the **single source of truth** for the bounds — the wiring and the
    tests reference the constants, never the literals `14`/`19` (P2-#5).
  - flutter_map **8.3.1** API confirmed: `MapController.camera` → `MapCamera{center, zoom}`; `move(LatLng,
    double)` (`camera.dart:34,37`, `map_controller.dart:131`). Reading `camera` is valid post-build inside
    a tap handler.
- **Zoom-at-bounds behaviour — FROZEN now, not an on-device call (P1-#3):** the zoom buttons stay
  **always enabled** and `clampZoom` makes them **safe no-ops at the bounds**. This is intentional Phase-2
  behaviour and it is what keeps `MapControlIsland` **stateless** (pure callbacks, no camera observation).
  A reactive *disabled* state (`canZoomIn`/`canZoomOut` synced to the live camera on every pinch) would
  change the widget API, require `MapEventCallback` observation, disabled styling, and different
  semantics/tests — that whole fork is **deferred** (recorded in §10), not discovered mid-implementation.
- **Placement rule (frozen, not "top or centre":** a *rule*, so the plan derives exact pixels from the
  real widget geometry — P2-#9):
  - right edge of the map `Stack`, `right: AonSpacing.space4` from the edge;
  - vertically in the **upper** map area (top-aligned, `top: AonSpacing.space4` from the map-area top),
    which is already **below** the category-filter row (that row is a separate `Column` sibling *above*
    the map `Stack`, `map_screen.dart:103-113` — so this is adjacency, not overlap, P2-#8) and well
    **above** the bottom-right Directions FAB's exclusion zone;
  - **minimum `AonSpacing.space4` separation** from every neighbour (filter row, FAB, attribution) and
    from the system/safe-area edges.
  Exact coordinates are derived in the plan; the on-device pass verifies the four clearances in §8.
- **Testability bound (R2 — stated, not hidden):** because the map is widget-test-hostile (its live
  `DarkTileLayer` fetches network tiles with no `errorBuilder`; no existing test mounts `FlutterMap`), the
  automated tests cover the **island rendering + callback dispatch + `clampZoom` math**. That the wired
  buttons *actually move the live camera* is verified **on-device** (§8), documented as a coverage bound
  exactly like the shader path — not asserted by a mounted-map unit test.
- **Semantics:** each `IconButton` keeps its `tooltip` (→ semantics label); targets ≥ `minTapTarget`
  (56) — icon buttons get explicit `constraints`/`padding` to hold the floor at every text scale (MQ's
  `_GlassIconButton` uses ~54; aon2026's 56 floor is the honest adaptation).

### 5.3 Map filter chips (faithful `_CategoryChip` port, in the extracted component)
The chips live in the extracted **`MapCategoryFilterBar`** (§4/P1-#1), rewriting the Material
`FilterChip`s to MQ's rule (`map_page.dart:1231`): **glass carries only the inactive state.** Each chip is
an **independent glass control** (governance rule 1 permits glass siblings — MQ glasses each chip
separately; the forbidden thing is glass nested in glass, which the chips never do).
- **Unselected** → `GlassSurface(variant: control, borderRadius: radiusFull, borderColor:
  <category colour @ low alpha>)` wrapping a transparent `Material`/`InkWell` with the category-coloured
  icon + label.
- **Selected** → **solid amber** fill (`AonColors.amber`), `onAccent` icon + label — a plain
  `DecoratedBox`/`Material`, no glass (governance rule 3: selected = solid brand).
- **Hit geometry — owning it now that `FilterChip` is gone (P2-#6):** Material `FilterChip` gave a
  compliant target for free; a custom chip must re-earn it. Each chip enforces `minHeight ≥
  AonSpacing.minTapTarget` (56), adequate horizontal hit padding, and a hit area covering the **whole
  visible chip**. Tested at 1.0 and 2.0 text scale.
- **Semantics — one coherent node, no duplication (P2-#7, was O3):** Material `FilterChip` announces
  selected state automatically; a custom chip does not, *and* a naive `Semantics(label:)` wrapped around a
  subtree that still contains the label `Text` can make VoiceOver/TalkBack read the label twice. Each chip
  is therefore a **single merged semantics node** — `Semantics(button: true, selected: isSelected, label:
  category.label)` with the inner visual `Text` under `ExcludeSemantics` (or an equivalent `MergeSemantics`
  structure). The test asserts the **semantics tree** (one node, correct `selected` + `label`, no
  duplicate), not merely that "some node has `selected: true`".
- Toggle behaviour, `onToggle`, and the `iconSm` avatar are preserved. The bar sits above the map (not
  over tiles), so the unselected chips' refraction is subtle — that is fine and still faithful (MQ chips
  are `control` glass regardless of backdrop richness; the tier is chosen by *role*, not by how much
  refraction shows).

### 5.4 Hero glass date pill (glass over the photo)
Wrap the hero's existing date/time content (`home_screen.dart:223-245`) in a
`GlassSurface(variant: control, borderRadius: radiusFull)` **content-width, wrapping** pill, bottom-left,
floating over the galaxy image (and its scrim). The eyebrow, event name, year, and the two-stop scrim are
**unchanged** — the title stays bare scrim text (already contrast-checked), and the pill is the region's
single glass element (rule 1).
- **`control` is a rendering tier, not an interactivity claim (conceptual):** `GlassVariant.control` names
  the design system's **translucent glass rung**; it does **not** imply the child is interactive. The hero
  pill is non-interactive event metadata that uses the translucent tier — that is correct and intended,
  and it carries no button/tap semantics.
- **Sizing (O1 — "pill" ≠ full-width `Expanded`; rule, not placeholder — P3-#13):** a hugging pill
  (`mainAxisSize.min`) cannot contain an unbounded `Expanded`. The pill is a `Row(mainAxisSize.min)` of the
  `event_rounded` icon + the date/time `Text` wrapped in `Flexible`, the whole `Row` inside a
  `ConstrainedBox` whose **`maxWidth` = the available hero text-column width** (derived from the hero
  padding + incoming constraints during implementation — the pill never exceeds the hero's horizontal
  content bounds; no fixed magic width). Short strings hug; the long "long date · time-range" string wraps
  to ≥2 lines inside the pill instead of overflowing. Overflow-safe at 320 × 2.0 (guarded by the hero
  responsive case).
- **Legibility (governance rule 2 applied honestly):** the pill is `control` tier (translucent, 0.45
  tint) so the galaxy refracts through it — but the date text sits over the existing `0xCC05070F` scrim
  band *and* the tinted glass, so `contentSecondary bodySmall` stays legible. Verified on-device; if the
  scrim+glass proves insufficient over the galaxy core, the fallback is a per-call darker `color:` tint
  on the pill (MQ's `color: Colors.black` hero pattern, `scan_page.dart:281`) — **not** dropping to a
  different tier.
- Reduced-motion / high-contrast: inherits the ladder — the pill renders **frost** under reduced motion
  and **solid** under high contrast (both fully legible; text never depends on refraction).

### 5.5 Reuse of the Phase 1 ladder (no policy changes)
Every new **glass** surface uses the existing `GlassSurface(control)` primitive (P3-#12 — the *selected*
chips are deliberately solid, not glass) and inherits the shipped, unit-tested `resolveGlassRenderMode`
policy: shader where Impeller supports it → frost → solid, with high-contrast → solid and reduced-motion →
frost. Phase 2 writes **zero** new rendering/policy code; it only chooses variants and injects aon2026
colours. This is the whole point of Phase 1's generic primitive.

## 6. Non-adoptions (explicit, each with its governance reason)

| Surface | Stays as | Reason (reference rule) |
|---|---|---|
| App bars (Map/Info/Program/What's On/Wayfinding/Event detail) | opaque `night950` AppBar | Rule 4 — content pages; glass is not a texture for everything |
| Directions FAB | solid amber | Rule 3 — primary action is solid brand |
| Venue/parking/time-sim bottom sheets | solid `night900` | Rule 2 — text-bearing sheets are the `content`/solid rung |
| Marker pins | solid `night950` circles | Not a control layer; tiny night labels need opaque contrast |
| OSM attribution | solid `night950 @ 0.75` chip | A legal label, not a control; texture-for-everything temptation |

The Map AppBar loses its **Recentre** action (relocated to the island); it becomes title-only and stays
opaque — a net simplification, not a regression.

## 7. Testing plan

Impeller is **off** in `flutter test`, so every `control` surface renders **frost** in tests (same bound
as Phase 1 §7 / G4). The automated suite proves **variant selection + fallback ladder + `clampZoom` math +
callback dispatch + layout + semantics**, and **never executes the real refraction shader** — that path is
verified only by the on-device check in §8. **Two documented coverage bounds** (both mirror Phase 1's
honesty about the shader): (a) the real refraction shader is not run in tests; (b) the wired buttons
*actually moving the live camera* is not asserted by a mounted-map test (the map is widget-test-hostile,
R2) — it is verified on-device. Tests cover the island's logic, not the live `FlutterMap`.

- **`map_control_island_test.dart`** — renders **one** `GlassSurface` (not three) with three buttons;
  recenter/zoom-in/zoom-out each invoke their injected callback; reduced-motion → the surface is frost
  (policy), buttons still fire; icon-button targets ≥ 56 at 1.0 and 2.0. Plus pure `clampZoom` unit tests:
  in-range `+1`/`−1` change the value; `+1` at `MapConfig.maxZoom` stays `maxZoom`; `−1` at
  `MapConfig.minZoom` stays `minZoom` (bounds via the constants, not `14`/`19` — P2-#5). **No
  `FlutterMap` is mounted** — the camera *math* is proven by `clampZoom`, the *wiring* by the callbacks.
- **`map_glass_surfaces_test.dart`** — mounts the public `MapCategoryFilterBar` (P1-#1; no live map):
  an unselected chip subtree contains a `GlassSurface(control)`; a selected chip subtree is solid amber (no
  `GlassSurface`); tapping fires `onToggle`. **Hit target (P2-#6):** each chip's rendered height ≥
  `AonSpacing.minTapTarget` (56) and the whole chip is tappable, at 1.0 and 2.0. **Semantics tree
  (P2-#7):** assert **one** merged node per chip with `button: true` + correct `selected` + `label`, and
  that the inner label is **not** independently read (no duplicate) — inspect the semantics tree, not just
  "some node has `selected: true`".
- **`hero_glass_test.dart`** — **structure/rung/wrap only** (P2-#10): the date/time text is wrapped by a
  `GlassSurface` over the hero and is findable; high-contrast → solid rung, reduced-motion → frost rung; no
  overflow at 320×2.0. This does **not** prove visual legibility — `find.text()` passing is not a contrast
  check; actual readability over the galaxy is a runtime-visual item in §8.
- **Responsive** — **home hero** at 320/414 × {1.0, 1.3, 1.6, 2.0}: no overflow; hero pill + last hero
  line fit. Map surfaces are covered at the component level above (the live `MapScreen` is not mounted,
  R3); integrated map non-overlap (island / filter row / FAB / attribution) is an on-device check (§8).
- **Regression (baseline, not a frozen count — P3-#14):** capture the pre-Phase-2 `flutter test` result
  (pass/fail + total) **before** editing; every pre-existing test must stay green; report the before/after
  totals rather than asserting a hard-coded number. The home widget tests keep passing (the hero gains a
  glass wrapper but the same text/semantics remain findable).

## 8a. Verification results (recorded 2026-08-09, iPhone 17 Pro simulator / Impeller-Metal)

| Item | Result | Evidence |
|---|---|---|
| `flutter analyze` | **PASS** | No issues found |
| Tests | **PASS** | 186 pass (171 baseline + 15 new); no regression |
| iOS build | **PASS** | `Runner.app` for device + simulator built |
| Android build | **PASS** | `app-debug.apk` built |
| iOS runtime | **PASS** | app launches; tab nav works |
| Live camera wiring | **PASS** | zoom-in tapped → map zoomed (Central Courtyard). Zoom-out/recenter share identical wiring + `clampZoom` (unit-tested); not each tapped |
| Shader over live map tiles | **PASS** | dark OSM tiles visibly refract through the control island + nav island rims (lensing, not flat blur) |
| Shader over hero photo | **PASS** | glass date pill renders over the galaxy; refraction path active on Impeller |
| Hero legibility | **PASS** | date text legible over the (scrim-darkened) galaxy in the shader render |
| Frost fallback | **PASS (policy)** | `resolveGlassRenderMode` fallback ladder unit-tested; runtime forced-frost not separately toggled |
| Governance audit | **PASS** | one glass layer per region, no glass-on-glass; app bar opaque, FAB + selected chips + attribution + pins solid |
| Layout clearances | **PASS** | island (top-right) clears FAB (bottom-right), filter row (above), attribution (bottom-left) — visually confirmed |
| Android runtime | **NOT AVAILABLE** | no emulator booted this session |
| Performance profiling | **NOT AVAILABLE** | no profile-mode trace run this session |

## 8. Acceptance gate (Phase 2 is complete only when ALL hold)

**Functional/UX:** map controls work (recenter returns to `campusCentre`/`initialZoom`; zoom in/out clamp
to `MapConfig.minZoom`/`maxZoom` — currently 14/19 — and stay enabled no-ops at the bounds per the frozen
§5.2 decision); the Map AppBar is title-only and opaque; filter chips toggle with correct
selected(solid amber)/unselected(glass) states; the hero date pill renders over the photo; every existing
route/sheet/behaviour is unchanged.

**Rendering/fallback:** the new `control` surfaces take the shader path where Impeller supports it; frost
where not; solid under high-contrast; frost under reduced motion. Startup + map + home never regress.

**Governance audit (the parity that matters here):** **no nested/overlapping glass** anywhere — the map
control island is one glass parent with plain buttons; the category chips are independent glass siblings
(permitted, rule 1); the hero pill is one glass element. The non-adoptions in §6 are all still solid;
selected chips + FAB + app bars are solid; legibility over every glass surface holds in all three rungs.

**A11y/responsive:** reduced-motion + high-contrast paths legible; per-control single-node semantics +
≥56 targets (island buttons **and** chips); the island + chips + hero pass the synthetic `TextScaler`
sweep through 2.0 as **components** (the live `MapScreen` is not test-mountable, R3); the integrated app is
1.6 (root clamp still in place); safe areas + nav-island clearance respected; on-device, the control
island clears **all four** neighbours — category-filter row, Directions FAB, attribution, and the
system/safe-area edges (P2-#8), each with ≥ `AonSpacing.space4`.

**Verification & evidence** — record **each** as `PASS` / `FAIL` / `NOT AVAILABLE` (never inherited):
- `flutter analyze` clean (or documented pre-existing exceptions).
- Tests pass.
- Android **build**; Android **runtime** (map controls + hero work).
- iOS **build**; iOS **runtime**.
- **Live camera wiring** — on-device, the island buttons actually recenter/zoom the map and clamp to
  `MapConfig.minZoom`/`maxZoom` (the coverage bound from §7(b): verified here, not by a mounted-map test).
- **Shader path over live map tiles — two-part evidence (P2-#11):** (1) runtime reports
  `GlassShaderCache.ready == true` (support + cache loaded), **and** (2) visual proof the *refraction* path
  renders — **pan the map under the stationary island** in a short runtime inspection so the tiles distort
  through the glass (motion distinguishes refraction from a flat frost blur far better than a still). No
  permanent diagnostics ship.
- **Shader path over the hero photo — two-part evidence (P2-#11):** (1) `GlassShaderCache.ready == true`,
  **and** (2) visual proof by comparing the shader render against a forced-frost render of the same pill
  (a static still of frost vs refraction can look deceptively alike, so the comparison — not a lone
  screenshot — is the evidence).
- **Frost fallback** — verified where the shader is unavailable.
- **Hero pill legibility (runtime visual, P2-#10)** — the date text is actually readable over the
  **brightest** (galaxy core) *and* **darkest** parts of the hero photo, in each of shader / frost / solid.
  This is the legibility evidence — the automated `hero_glass_test` proves structure/rung only, not
  contrast. If the default `control` translucency fails over the core, apply the darker `color:` tint
  fallback (§5.4) and re-verify.
- **Performance sanity pass measured in aon2026** — scrolling/panning behind the glass over live tiles,
  rapid zoom taps, shader warm-up on the map (this is the map-over-glass interaction Phase 1 §9
  explicitly deferred to here). If profiling can't be run in this environment, record `NOT AVAILABLE`.

Then: **visual parity comparison vs MQ_Journey** (map controls + glass-over-imagery), and a **second
hostile audit** for glass-on-glass, legibility, or governance breaches introduced by the port.

## 9. Honest scorecard (re-scored at freeze)

| Axis | Now | What moves it up (named artifact) |
|---|---|---|
| Reference fidelity | 9 | control-tier map controls + inactive-only chip glass + glass-over-imagery all ported line-by-line; non-adoptions match MQ governance |
| Internal consistency | 9 | §3 corrects the `GlassPane` deferral; rule 1 reworded to "no nested/overlapping glass" so the glass chips no longer contradict it (P1-#2); rule 4 rationale fixed (live map ≠ no-live-media, P1-#4); one ladder, no new policy |
| Honesty / falsifiability | 9 | §7/§8 state **three** honest bounds (shader path, live-camera, and "structure-test ≠ legibility"); shader evidence is two-part, not a lone still (P2-#11); the map's test-hostility is named, not hidden |
| aon2026 ergonomic fit | 8 | zoom controls for gloved/one-handed night use; ≥56 targets on island **and** chips (P2-#6); single-node chip semantics (P2-#7); legibility guarded in all rungs + proven at runtime (P2-#10) |
| Ambition / invention | 4 | it is a **port**; the two honest adaptations (map control island, hero pill) are recombination, not a new species — a genuinely new astronomy-native map interaction would raise it |
| Implementation-readiness | 9 | the standalone-chip seam is now real — `_CategoryFilterBar` is extracted to the public `MapCategoryFilterBar` (P1-#1); zoom-at-bounds frozen so no mid-task API fork (P1-#3); placement is a rule, bounds via `MapConfig` constants; files/variants/`clampZoom`/tests all named; no speculative machinery |

**Honest verdict:** a governance-faithful port that finally delivers the refraction payoff over live
tiles and the hero photo, with a sharply reasoned non-adoption set that *is* the parity work. It is not
an invention and the scorecard says so; the one place ambition could rise (a new astronomy-native map
interaction) is named and deliberately held out of this phase.

## 10. Open decisions & deferrals

**Frozen in this spec (no longer open — moved here for the record):**
- **Zoom-at-bounds = enabled, safe no-op** (§5.2, P1-#3). The reactive *disabled* state
  (`canZoomIn`/`canZoomOut` synced to live-camera events, disabled styling, event observation) is a
  **deferred** future item — a later polish phase, **not** a mid-implementation fork.
- **Island placement is a rule** (§5.2, P2-#9), not a per-run choice: right edge, upper map area, ≥
  `AonSpacing.space4` from every neighbour. Only the exact derived pixels are tuned on-device.

**Genuinely open (tuned on-device during the parity pass):**
- Hero pill tint: default `control` translucency vs a darker `color:` override if the galaxy core defeats
  legibility (§5.4).
- Unselected filter-chip border colour/alpha (category colour vs neutral hairline) — tuned for night.

(The earlier "OSM attribution could later become frost" item is **removed** — P3-#15 — it contradicted
§6's own reasoning that attribution stays solid because it is a legal label, not a control. If governance
ever changes, that is a fresh decision then, not a standing open question now.)
