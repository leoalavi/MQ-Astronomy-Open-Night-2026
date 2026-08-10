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
- Add dependency `flutter_inappwebview` at **floor `^6.1.5`** (verified: resolves
  cleanly against aon2026's Flutter 3.44.7 / Dart 3.12, currently to 6.1.5 —
  MQ's line). The caret is a compatible range, **not** an exact pin; the
  **lockfile records the resolved version** and is committed for reproducibility.
- The viewer core: a webview host (localhost asset server + Pannellum + JS
  bridge + **origin allowlist**), a tour view, a scene rail.
- A self-contained `IndoorManifest` model + an asset-backed repository/provider.
- A **Map mode toggle** (Campus Map ↔ 360°) and a **panorama building picker**.
- A full-screen immersive **panorama route** with a glass island title bar.
- **Exactly one placeholder tour** with **2 scenes** (proves hotspot
  navigation), mapped to one aon2026 venue (`macquarie-theatre`); every other
  venue shows "coming soon" (§9). **Placeholder asset budget ≤ ~8 MB** — MQ's
  full 3-tour set is ~23 MB (individual equirectangular scenes are 1.7–4.2 MB),
  excessive for throwaway content, so the two placeholder JPGs are **downscaled**
  and full-resolution real photos land later. One tour also keeps the picker's
  "coming soon" state prominent — the honest look. (Subject to the image
  provenance/licensing check in §9.)
- Bundled assets: `indoor_viewer.html`, vendored `pannellum.{js,css}` (MIT,
  ~65 KB — trivial), per-venue manifest JSON + the downscaled equirectangular
  JPGs.

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
| `lib/data/panorama_data.dart` | **create** — the venue→panorama map: which venue ids have a tour + their manifest asset path, each carrying a `placeholder` flag. SP1 maps **1–2** downscaled placeholder tours to real aon2026 venue ids (e.g. `macquarie-theatre`, and optionally `mason-theatre`); every other venue has no tour → "coming soon" |
| `lib/services/panorama_server.dart` | **create** — a **single owner** for the `InAppLocalhostServer` (fixed port 8459): idempotent `start()` (memoized future, like MQ's `??=`), `isRunning()`, ref-counted `close()`. Never bound per-widget. On `start()` failure or port-in-use → surfaces an error the viewer maps to the unavailable state (§7). |
| `lib/models/viewer_url_policy.dart` | **create** — a **pure** `isAllowedViewerUrl(Uri)` (compares **scheme + host + port**, not string prefix): allows exactly `http://localhost:8459`; rejects other scheme/host/port and `file:`/`data:`/`javascript:`/`https:`. `127.0.0.1` is **deliberately not** treated as `localhost`. Unit-tested (§8). |
| `lib/services/providers.dart` | **modify** — add `indoorManifestProvider(venueId)` (resolves the venue's asset path **only via an exact `panorama_data` lookup — never string-interpolated from `venueId`**, §7; loads + caches manifest JSON via `rootBundle`) and `venuesWithPanoramaProvider` (synchronous availability from `panorama_data`, no manifest I/O) |
| `lib/widgets/panorama_web_view.dart` | **create** — `InAppWebView` host using the shared server; `InAppWebViewSettings(useShouldOverrideUrlLoading: true)`; `shouldOverrideUrlLoading` delegates to `isAllowedViewerUrl` (main-frame **navigation** policy — not a network firewall, §7); `loadTour(config)` fired in **`onLoadStop`** (viewer-ready handshake) with `jsonEncode(config)`; `selectScene(id)` via `jsonEncode(id)`; JS handler `sceneChanged` **validates the incoming id against the manifest's scene set before touching Flutter state** (§4b) |
| `lib/widgets/panorama_tour_view.dart` | **create** — composes the webview + scene rail + glass island title bar; owns scene state |
| `lib/widgets/panorama_scene_rail.dart` | **create** — glass scene chips (`GlassSurface(control)`, `allowShader:false`) |
| `lib/widgets/map_mode_toggle.dart` | **create** — glass segmented control (Campus Map / 360°) |
| `lib/widgets/panorama_building_picker.dart` | **create** — glass cards; venues-with-tour tappable (scene-count subtitle), others "coming soon". **No auto-select** — the picker is always shown, even with one tour (§5), so availability is always visible and there is no back-loop |
| `lib/screens/map_screen.dart` | **modify** — host the mode toggle; in 360° mode swap the map for the picker |
| `lib/screens/panorama_screen.dart` | **create** — full-screen immersive panorama page (pushed route) |
| `lib/app/router/app_router.dart` | **modify** — add the top-level `panorama` route (`/panorama/:venueId`) |
| `assets/web/indoor_viewer.html`, `assets/web/pannellum/pannellum.{js,css}` | **create/vendor** (MIT-licensed Pannellum) |
| `assets/data/indoor/*.json` + `*.jpg` | **create** — MQ's manifests + panoramas, as placeholders |
| `pubspec.yaml` | **modify** — dependency + asset entries |

## 5. Data flow & navigation

Map tab → glass **`MapModeToggle`**:
- *Campus Map* = today's `map_screen` (glass control island + markers) — unchanged.
- *360°* = **`PanoramaBuildingPicker`** — availability comes **synchronously from
  `panorama_data` / `venuesWithPanoramaProvider`** (which venues have a tour +
  the placeholder flag). It does **not** load every manifest JSON just to test
  existence (that would be needless I/O). Manifests are loaded lazily, only by
  the panorama screen for the chosen venue.

Tap a venue-with-tour → **push the top-level `/panorama/:venueId` route** (above
the `StatefulShellRoute` → tab bar hidden → true immersion; back returns to the
picker). The screen resolves the manifest via `indoorManifestProvider(venueId)`,
whose asset path comes from an **exact `panorama_data` lookup — never a path
interpolated from the raw route param** (§7). Viewer flow: WebView created →
`indoor_viewer.html` loaded → **`onLoadStop` (viewer ready)** → `loadTour(config)`.
A hotspot tap fires `sceneChanged`; the id is **validated against the manifest's
scenes** before the scene rail updates.

**Defined failure states** (every one → a safe in-app "360° preview unavailable"
/ back state, never a crash): unknown `venueId`; a known venue with no tour;
a malformed/absent manifest; a missing panorama image; localhost-server
start/port failure; webview failure. **No auto-select** — even with a single
tour, the picker is shown and the user taps to enter (removes the
one-tour → auto-push → back → auto-push loop).

**Adaptation from MQ (deliberate):** MQ *embeds* the panorama inside the map tab
(tab bar visible) and needs an `immersiveViewerActiveProvider` to tell the shell
glass to frost-not-shader. SP1 **pushes a full-screen route** instead, so the tab
bar is not over the panorama and **no shell-level coupling is needed** — the only
glass over the webview is the panorama screen's own title bar + scene rail, both
`allowShader:false` locally. One fewer coupling than MQ.

## 6. Glass treatment (pays the deferred parity IOU)

Mode toggle + picker cards + the panorama title bar all use
**`GlassSurface(control)` with `allowShader: false`** — the platform-view case
its own doc-comment names (*"glass floating over a platform view (e.g. an
InAppWebView panorama)"*, verified verbatim). **Use `control`, not `bar`:** the
`bar` variant renders a *top-only* hairline (`Border(top: side)`), shaped for the
screen-bottom tab bar; a floating title island wants a full border + floating
radius + shadow, which is `control` — and is exactly what MQ's own `GlassAppBar`
is built on (`GlassSurface(variant: control)`). This is the first legitimate home
in aon2026 for the frosted media-page island that MQ had and aon2026 lacked (it
previously had no media page to host one). Branding adapts MQ → aon2026:
`MqColors`/`MqSpacing` → `AonColors`/`AonSpacing`; `GlassAppBar` →
`GlassSurface(control)`.

## 7. Fallback, accessibility & security boundary

**Fallback / accessibility:**
- **Unsupported/failed viewer:** a graceful **"360° preview unavailable"** state
  (icon + message + back), never a crash — covers web platform
  (`InAppLocalhostServer.start()` throws there), server/port failure, and
  asset/load failure (all the failure states in §5).
- **Reduced motion:** Pannellum `autoRotate` **off**; under
  `MediaQuery.disableAnimations`, no auto-spin and no motion-based affordances.
- Picker cards keep ≥56px targets and the existing glass fallback ladder
  (high-contrast → solid, reduced-motion → frost).

**Security boundary — stated precisely (this is a webview loading local HTML/JS,
so it gets a trust boundary):**
- **Main-frame navigation** is restricted to the **exact** local viewer origin
  (`http://localhost:8459`), enforced by `isAllowedViewerUrl` (scheme+host+port)
  via `shouldOverrideUrlLoading` with `useShouldOverrideUrlLoading: true`. This is
  a **navigation** policy, **not** a general network/subresource firewall
  (`shouldOverrideUrlLoading` governs URL navigations, not `fetch`/resource loads).
- **Panorama image references** are separately constrained to **validated bundled
  relative paths** — the path guard (§4) rejects absolute/off-origin/`..`
  traversal; this is the subresource control the navigation policy does not cover.
- **No path from untrusted input:** the asset path for a tour is resolved by an
  **exact `panorama_data` lookup**, never interpolated from the route's `venueId`
  (`'assets/data/indoor/$venueId.json'` is forbidden — an unknown id yields the
  unavailable state, not an arbitrary asset read).
- **JS bridge is a trust boundary both ways:** Dart→JS uses `jsonEncode` (never
  string interpolation) for `loadTour`/`selectScene`; JS→Dart `sceneChanged(id)`
  is **validated against the manifest's scene set** before any Flutter state
  changes — an unknown id is ignored.

## 8. Testing plan

**Widget/unit-testable (the real gate). The security controls are tested, not
just asserted in prose:**
- `IndoorManifest.buildPannellumConfig()` — emitted config shape
  (`type: equirectangular`, scene hotspots, yaw/pitch/hfov) for a sample manifest.
- **Path-safety via the public boundary (not the private helper):**
  `_isSafeRelativeImagePath` stays private; the test drives the **public API** —
  constructing/parsing a manifest whose image is absolute / off-origin / `..`
  traversal is **rejected**; safe relative refs are accepted. (Tests the
  invariant, not the implementation detail — same reason we test behaviour, not
  privates.)
- **URL-policy `isAllowedViewerUrl` (pure, directly unit-tested):** allows
  exactly `http://localhost:8459/...`; **rejects** `https://localhost:8459/`,
  `http://localhost:8460/`, `http://localhost.evil.example/`, `http://example.com/`,
  `file:///…`, `data:…`, `javascript:…`; `127.0.0.1:8459` is rejected
  (deliberately not treated as `localhost`). Compares parsed scheme+host+port.
- **`sceneChanged` validation:** a known scene id updates state; an unknown id is
  ignored (the manifest scene set is the allowlist).
- **Server failure → unavailable:** the viewer maps a `start()`/port failure to
  the unavailable state rather than crashing (exercised where the harness allows;
  otherwise covered by the failure-state widget path).
- Manifest JSON parsing (repository) — a fixture manifest round-trips.
- `PanoramaBuildingPicker` logic — venues-with-tour tappable, others "coming
  soon"; **the picker is always shown (no auto-select)**; availability comes from
  `panorama_data` without loading manifests.
- `MapModeToggle` — toggles state; the picker replaces the map in 360° mode.
- **Data-integrity test — via the bundled asset manifest, not literal pubspec
  lines:** every venue in `panorama_data.dart` resolves (through the exact lookup)
  to a manifest that `rootBundle` can load and parse; every hotspot
  `targetSceneId` exists in its manifest; every referenced JPG is loadable via
  `rootBundle`/`AssetManifest` (directory-based asset declarations are valid, so
  the test checks the *bundle*, not per-file `pubspec.yaml` entries).

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
- **Content is placeholder — and it is a DIFFERENT building.** The imagery is
  MQ's Hadenfeld/Ondaatje interiors shown under an aon2026 venue name, so the
  flag must say so explicitly — **"Demo 360° — sample imagery, not this venue"**
  on the picker card and inside the panorama — not merely "photos coming" (which
  would read as this venue). Placeholder JPGs are downscaled (≤ ~8 MB total; see
  §3). Real full-resolution photos of the actual venues replace both later.
- **Image licensing / provenance (gating — placeholder honesty ≠ copyright).**
  Pannellum's **MIT licence covers the software, not panoramic images** (its repo
  separates the two). Before bundling any panorama JPG, a `docs/` provenance note
  must record, per image: **source, copyright owner, licence/permission,
  required attribution, and whether redistribution + downscaling is allowed.** If
  MQ's photos can't be confirmed redistributable (even between sibling apps),
  SP1 uses **photos we own or explicitly-licensed/CC demo panoramas** instead —
  the viewer is content-agnostic, so this does not change the code. The vendored
  Pannellum **`LICENSE`/third-party notice ships alongside `pannellum.{js,css}`**.
- **Frozen SP1 content:** **exactly one** placeholder tour with **two scenes**
  (enough to prove hotspot navigation) mapped to `macquarie-theatre`; every other
  venue shows "coming soon." One tour keeps the asset budget small and the
  "coming soon" state prominent. (Exact manifest file, scene ids, image files,
  and total bytes are pinned in the implementation plan, subject to the
  provenance note above.)
- **Not a full port** — this is SP1 only. The QR/stamps/backend halves are
  separate specs with their own external dependencies (signing keys, Supabase,
  content), deliberately not started here.

## 10. Acceptance gate (SP1 complete only when ALL hold)

- `flutter analyze` clean; `flutter test` green including manifest, **path-guard
  (via public boundary)**, **`isAllowedViewerUrl` URL-policy**, **`sceneChanged`
  validation**, **server-failure → unavailable**, repository, picker (always
  shown, no auto-select), toggle, and the bundle-based data-integrity tests.
- `flutter build ios --simulator --debug` PASS; `flutter build apk --debug`
  PASS/NOT AVAILABLE recorded.
- **On-device iOS:** Map 360° toggle → picker → the placeholder tour loads, pans,
  hotspot-navigates between scenes, and the **glass island stays fully legible
  over the WebView regardless of whether the native backdrop blur visually
  samples the platform view** (readability must not depend on the frost looking
  gorgeous — the actual frost-over-WebView appearance is runtime-observed, not
  assumed); the unavailable state renders when forced. Reported with a screenshot.
- **Security:** deep-linking `/panorama/<unknown-id>` reaches the unavailable
  state (no arbitrary asset read); main-frame navigation stays on the viewer
  origin.
- Placeholder content carries the **"Demo 360° — sample imagery, not this
  venue"** flag on card and panorama; no building reads as an aon2026 venue
  interior. **Image-provenance note present**, and the **Pannellum `LICENSE`
  ships** with the vendored assets.
- **Placeholder asset budget:** the bundled panorama JPGs total **≤ ~8 MB**
  (downscaled); the Pannellum lib + HTML add ~65 KB.

## 11. Scope check

Single implementation plan: yes — one cohesive vertical slice (dependency +
viewer + entry + content + tests). The other four sub-projects are explicitly
separate. No decomposition needed within SP1.

## 12. Scorecard (0–10, re-scored at closeout)

| Axis | Score | What raises it (named artifact) |
|---|---|---|
| Feature fidelity to MQ | 7 → target 9 | Faithful Pannellum core + hotspot scene graph + scene rail; the +2 is on-device confirmation of multi-scene hotspot navigation |
| Portability / decoupling | 6 → target 9 | Self-contained manifest (no trail/settings/open_day/Supabase/l10n); the picker + viewer move as a unit |
| Honesty of content & provenance | — target 10 | In-UI "demo, not this venue" flag + image-provenance note + vendored Pannellum LICENSE; nothing faked as real venue, nothing shipped without rights |
| Security of the webview boundary | 5 → target 9 | Tested `isAllowedViewerUrl` (scheme+host+port), path guard via public API, `sceneChanged` allowlist, no path from raw `venueId`; +the on-device deep-link check |
| Change surface / risk | 8 → target 9 | Additive (new files + one dep + map-screen toggle); the ported-verbatim risk (localhost server + navigation policy) is made explicit + tested, not left implicit |

## 13. Files summary

Create: `models/indoor_manifest.dart`, `models/viewer_url_policy.dart`,
`data/panorama_data.dart`, `services/panorama_server.dart`,
`widgets/panorama_web_view.dart`, `widgets/panorama_tour_view.dart`,
`widgets/panorama_scene_rail.dart`, `widgets/map_mode_toggle.dart`,
`widgets/panorama_building_picker.dart`, `screens/panorama_screen.dart`; assets
under `assets/web/` (incl. Pannellum `LICENSE`) + `assets/data/indoor/`; a
`docs/` image-provenance note; tests (incl. the URL-policy, path-guard,
scene-validation, and server-failure tests). Modify: `screens/map_screen.dart`,
`app/router/app_router.dart`, `services/providers.dart`, `pubspec.yaml`.
