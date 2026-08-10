# SP1 — 360° Panorama Viewer (Design)

**Status:** frozen for review · 2026-08-10
**Part of:** the "AR" port from MQ_Journey. Audit finding: MQ's "AR" is **not
augmented reality** — it is a 360° equirectangular panorama tour (Pannellum/WebGL
in a `flutter_inappwebview` webview). This spec is **sub-project 1 of 5** (the
panorama viewer); QR scanning (SP3), stamps/passport (SP4), local persistence
(SP2), and Supabase sync (SP5) are separate specs, deliberately out of scope.

## 1. Intent

Give aon2026 a venue 360° tour: from the Map tab, a mode toggle switches the map
for a picker of venues that have a panorama; selecting a venue opens an immersive
photo-sphere with hotspot navigation between scenes. Port MQ's proven
Pannellum-in-webview core faithfully (Approach A), adapted to aon2026's flat
architecture and glass system, stripped of MQ's cross-feature couplings. Ship it
working end-to-end using MQ's panoramas as **visibly-flagged placeholder
content**, so the whole pipeline is proven; real aon2026 venue photos swap in
later through the same manifest.

## 2. What "AR" actually is (audit receipts)

Verified in MQ_Journey: zero references to ARKit/ARCore/`sensors_plus`/gyroscope.
`location_ar_page.dart` comments *"the body is a platform-view panorama"* and
renders `IndoorTourView`; `indoor_webview.dart` uses `InAppLocalhostServer` +
`InAppWebView` loading `web/indoor_viewer.html` (Pannellum). The mechanism, not
the "AR" label, is what we port.

## 3. Scope

**In:**
- Add dependency `flutter_inappwebview` (`^6.x`, matching MQ's 6.1.5 line).
- The viewer core: a webview host (localhost asset server + Pannellum + JS
  bridge + **origin allowlist**), a tour view, a scene rail.
- A self-contained `IndoorManifest` model + an asset-backed repository/provider.
- A **Map mode toggle** (Campus Map ↔ 360°) and a **panorama building picker**.
- A full-screen immersive **panorama route** with a glass island title bar.
- MQ's 3 panoramas as **placeholder content**, mapped to 3 aon2026 venues.
- Bundled assets: `indoor_viewer.html`, vendored `pannellum.{js,css}` (MIT),
  per-venue manifest JSON + equirectangular JPGs.

**Out (later sub-projects / content):**
- QR scanning, camera, `mobile_scanner`, signed-QR verification → **SP3**.
- Stamps/passport, gamification, confetti → **SP4**.
- Local visited/saved-state persistence → **SP2**.
- Supabase / any backend → **SP5**.
- Real aon2026 360° photography → content task, not code.
- MQ's location-card page (that was the *scan→card→AR* path; SP1 uses only the
  *map-toggle* path).
- MQ's trail manifest, settings-controller coupling, `open_day` import cycle,
  l10n locale files (aon2026 uses inline strings).

## 4. Architecture — MQ's layered `features/scan/` collapsed to aon2026's flat layout

| File | Role |
|---|---|
| `lib/models/indoor_manifest.dart` | **create** — `IndoorManifest` / `IndoorScene` / `SceneHotspot`; `buildPannellumConfig()` (emits Pannellum `equirectangular` config with `hotSpots` of `type: scene`); the `_isSafeRelativeImagePath()` guard (ported — gates panorama refs against off-origin fetches) |
| `lib/data/panorama_data.dart` | **create** — the venue→panorama map: which venue ids have a tour + their manifest asset path, each carrying a `placeholder` flag. SP1 maps MQ's 3 tours to 3 real aon2026 venue ids: `macquarie-theatre`, `mason-theatre`, `central-courtyard` |
| `lib/services/providers.dart` | **modify** — add `indoorManifestProvider(venueId)` (loads + caches manifest JSON via `rootBundle`) and `venuesWithPanoramaProvider` |
| `lib/widgets/panorama_web_view.dart` | **create** — `InAppLocalhostServer` (fixed port 8459) + `InAppWebView` host; `loadTour(config)`/`selectScene(id)` via `evaluateJavascript`; JS handler `sceneChanged`; `_shouldOverrideUrlLoading` **origin allowlist** (localhost viewer only — ported verbatim) |
| `lib/widgets/panorama_tour_view.dart` | **create** — composes the webview + scene rail + glass island title bar; owns scene state |
| `lib/widgets/panorama_scene_rail.dart` | **create** — glass scene chips (`GlassSurface(control)`, `allowShader:false`) |
| `lib/widgets/map_mode_toggle.dart` | **create** — glass segmented control (Campus Map / 360°) |
| `lib/widgets/panorama_building_picker.dart` | **create** — glass cards; venues-with-tour tappable (scene-count subtitle), others "coming soon"; auto-select if exactly one |
| `lib/screens/map_screen.dart` | **modify** — host the mode toggle; in 360° mode swap the map for the picker |
| `lib/screens/panorama_screen.dart` | **create** — full-screen immersive panorama page (pushed route) |
| `lib/app/router/app_router.dart` | **modify** — add the top-level `panorama` route (`/panorama/:venueId`) |
| `assets/web/indoor_viewer.html`, `assets/web/pannellum/pannellum.{js,css}` | **create/vendor** (MIT-licensed Pannellum) |
| `assets/data/indoor/*.json` + `*.jpg` | **create** — MQ's manifests + panoramas, as placeholders |
| `pubspec.yaml` | **modify** — dependency + asset entries |

## 5. Data flow & navigation

Map tab → glass **`MapModeToggle`**:
- *Campus Map* = today's `map_screen` (glass control island + markers) — unchanged.
- *360°* = **`PanoramaBuildingPicker`** — reads venues, checks `indoorManifestProvider` for a non-empty manifest, renders glass cards.

Tap a venue-with-tour → **push the top-level `/panorama/:venueId` route** (above
the `StatefulShellRoute` → tab bar hidden → true immersion; back returns to the
picker). `panorama_screen` loads `indoor_viewer.html` over the localhost server,
calls `loadTour(config)`; a hotspot tap fires `sceneChanged` over the JS bridge,
updating the scene rail.

**Adaptation from MQ (deliberate):** MQ *embeds* the panorama inside the map tab
(tab bar visible) and needs an `immersiveViewerActiveProvider` to tell the shell
glass to frost-not-shader. SP1 **pushes a full-screen route** instead, so the tab
bar is not over the panorama and **no shell-level coupling is needed** — the only
glass over the webview is the panorama screen's own title bar + scene rail, both
`allowShader:false` locally. One fewer coupling than MQ.

## 6. Glass treatment (pays the deferred parity IOU)

Mode toggle + picker cards: `GlassSurface(control)`. Panorama title bar: a
`GlassSurface(bar)` **island with `allowShader: false`** — the platform-view case
its own doc-comment names (*"glass floating over a platform view (e.g. an
InAppWebView panorama)"*). This is the first legitimate home in aon2026 for the
frosted media-page bar that MQ had and aon2026 lacked (it previously had no media
page to host one). Branding adapts MQ → aon2026: `MqColors`/`MqSpacing` →
`AonColors`/`AonSpacing`; `GlassAppBar` → `GlassSurface(bar)`.

## 7. Fallback & accessibility

- **Unsupported/failed viewer:** a graceful **"360° preview unavailable"** state
  (icon + message + back), never a crash — covers web platform
  (`InAppLocalhostServer.start()` throws there) and asset/load failure.
- **Reduced motion:** Pannellum `autoRotate` **off**; under
  `MediaQuery.disableAnimations`, no auto-spin and no motion-based affordances.
- Picker cards keep ≥56px targets and the existing glass fallback ladder
  (high-contrast → solid, reduced-motion → frost).
- The webview **origin allowlist** is a security control, ported verbatim: the
  webview may only navigate to the localhost viewer origin.

## 8. Testing plan

**Widget/unit-testable (the real gate):**
- `IndoorManifest.buildPannellumConfig()` — asserts the emitted config shape
  (`type: equirectangular`, scene hotspots, yaw/pitch/hfov) for a sample manifest.
- `_isSafeRelativeImagePath()` — accepts safe relative refs, rejects
  absolute/off-origin/`..` traversal.
- Manifest JSON parsing (repository) — a fixture manifest round-trips.
- `PanoramaBuildingPicker` logic — venues-with-manifest tappable, others locked,
  auto-select when exactly one.
- `MapModeToggle` — toggles state; the picker replaces the map in 360° mode.
- **Data-integrity test** — every venue in `panorama_data.dart` has a manifest
  asset that exists and parses; every hotspot `targetSceneId` exists in its
  manifest; every referenced JPG is declared in `pubspec.yaml` assets.

**On-device only (honest flag):** the actual Pannellum render is a platform view
/ webview — **not exercisable in `flutter_test`**. Verified on the iOS simulator
(load a tour, pan, tap a hotspot to change scene, confirm the glass island frosts
over it), exactly as MQ verifies it.

## 9. Honest bounds & deferrals

- **Web platform: panorama NOT AVAILABLE** — `InAppLocalhostServer` is unsupported
  on Flutter web; SP1 shows the fallback state there. (aon2026's primary targets
  are iOS/Android.)
- **Android runtime & performance traces: NOT AVAILABLE** in this environment (no
  emulator, no profiler) — as flagged in Phases 2–5. Android *build* is gated.
- **Content is placeholder** — the panoramas are MQ's buildings, flagged in-UI
  ("Sample 360° · actual venue photos coming"). Not presented as real aon2026
  venue interiors.
- **Not a full port** — this is SP1 only. The QR/stamps/backend halves are
  separate specs with their own external dependencies (signing keys, Supabase,
  content), deliberately not started here.

## 10. Acceptance gate (SP1 complete only when ALL hold)

- `flutter analyze` clean; `flutter test` green including the new manifest,
  path-guard, repository, picker, toggle, and data-integrity tests.
- `flutter build ios --simulator --debug` PASS; `flutter build apk --debug`
  PASS/NOT AVAILABLE recorded.
- **On-device iOS:** Map 360° toggle → picker → a placeholder tour loads, pans,
  hotspot-navigates between scenes, the glass island frosts over it, and the
  fallback state renders when forced. Reported honestly with a screenshot.
- Placeholder content is visibly flagged; no MQ building shown as an aon2026
  venue interior unlabelled.

## 11. Scope check

Single implementation plan: yes — one cohesive vertical slice (dependency +
viewer + entry + content + tests). The other four sub-projects are explicitly
separate. No decomposition needed within SP1.

## 12. Scorecard (0–10, re-scored at closeout)

| Axis | Score | What raises it (named artifact) |
|---|---|---|
| Feature fidelity to MQ | 7 → target 9 | Faithful Pannellum core + hotspot scene graph + scene rail; the +2 is on-device confirmation of multi-scene hotspot navigation |
| Portability / decoupling | 6 → target 9 | Self-contained manifest (no trail/settings/open_day/Supabase/l10n); the picker + viewer move as a unit |
| Honesty of content | — target 10 | Placeholder flag in-UI + data-integrity test; nothing faked as real venue |
| Change surface / risk | 8 → target 9 | Additive (new files + one dep + map-screen toggle); the only ported-verbatim risk is the webview allowlist + localhost server, kept intact |

## 13. Files summary

Create: `indoor_manifest.dart`, `panorama_data.dart`, `panorama_web_view.dart`,
`panorama_tour_view.dart`, `panorama_scene_rail.dart`, `map_mode_toggle.dart`,
`panorama_building_picker.dart`, `panorama_screen.dart`; assets under
`assets/web/` + `assets/data/indoor/`; tests. Modify: `map_screen.dart`,
`app_router.dart`, `services/providers.dart`, `pubspec.yaml`.
