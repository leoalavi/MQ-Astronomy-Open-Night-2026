# SP1 — 360° Panorama Viewer — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give aon2026 a venue 360° panorama tour — a Map "360°" mode toggle → a building picker → an immersive Pannellum-in-webview tour with hotspot scene navigation — porting MQ_Journey's viewer faithfully, stripped of MQ's couplings, with the webview trust boundary made explicit and tested.

**Architecture:** Port MQ's `flutter_inappwebview` + Pannellum core. A single localhost asset server hosts a vendored `indoor_viewer.html` + Pannellum; the manifest model builds the Pannellum config; a pure URL-policy gate + a relative-path guard form the security boundary; the entry is a Map mode toggle → picker → a pushed full-screen panorama route (no shell coupling). Content is one flagged placeholder tour.

**Tech Stack:** Flutter 3.44.7 / Dart 3.12; flutter_riverpod, go_router, flutter_map, **flutter_inappwebview (new)**; MQ_Journey (`/Users/raoof.r12/Desktop/Raouf/MQ_Journey`) is the port reference.

**Design spec:** `docs/superpowers/specs/2026-08-10-aon-panorama-viewer-sp1-design.md` (frozen; incorporates the self-gauntlet + Raouf's 14-finding security review). This is **SP1 of 5** — QR/stamps/persistence/Supabase are out of scope.

## Global Constraints

- **flutter_inappwebview floor `^6.1.5`**; commit the updated `pubspec.lock`. Not an exact pin.
- **Do NOT run `dart format`** (repo isn't tall-style formatted); match surrounding style; `flutter analyze` must stay **clean** (zero issues, info-level included) at every commit.
- **Dark-only**; adapt MQ `MqColors`/`MqSpacing` → `AonColors`/`AonSpacing`; MQ l10n `AppLocalizations.of(context)!.x` → inline aon2026 strings; MQ `GlassAppBar`/glass → aon2026 `GlassSurface` (**`control` variant, `allowShader: false`** for anything over the webview — the `bar` variant's top-only border is wrong for a title island).
- **Security invariants (tested, §8 of spec):** (a) main-frame navigation only to `http://localhost:8459` (or `about:`); (b) panorama image refs gated to safe relative paths; (c) asset paths resolved by **exact `panorama_data` lookup, never interpolated from `venueId`**; (d) `jsonEncode` for all Dart→JS; (e) inbound `sceneChanged` validated against the manifest scene set.
- **Content:** exactly **one** placeholder tour, **two** scenes, mapped to venue `macquarie-theatre`; downscaled JPGs, ≤ ~8 MB; flagged **"Demo 360° — sample imagery, not this venue"**. Gated by an image-provenance note.
- **Branch:** `feature/panorama-viewer-sp1` off `main`. Never commit to `main`.
- **Commits:** `type(scope): summary` + `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
- **On-device-only:** the Pannellum render is a platform view — not `flutter_test`-able; verified on the iOS simulator.

---

## Task 0: Preflight — clean tree, branch, dependency, baseline

**Files:** `pubspec.yaml`, `pubspec.lock`.

- [ ] **Step 1: Clean tree + branch**

```bash
git status --short   # MUST be empty
git rev-parse HEAD   # record base commit
git checkout main && git checkout -b feature/panorama-viewer-sp1
```

- [ ] **Step 2: Baseline green (record the actual count)**

```bash
flutter analyze
flutter test
```

Expected: analyze clean; all pass. **Record the actual test total** (compare at the final gate).

- [ ] **Step 3: Add the dependency**

```bash
flutter pub add flutter_inappwebview
```

Verify `pubspec.yaml` shows `flutter_inappwebview: ^6.1.5` (or newer 6.x) and `pubspec.lock` updated.

- [ ] **Step 4: Analyze + test still green; commit**

```bash
flutter analyze && flutter test
git add pubspec.yaml pubspec.lock
git commit -m "build: add flutter_inappwebview for the 360 panorama viewer (SP1)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 1: Viewer URL policy (pure, security-critical)

Extract MQ's inline `_shouldOverrideUrlLoading` check into a pure, unit-tested function.

**Files:** Create `lib/models/viewer_url_policy.dart`, `test/unit/viewer_url_policy_test.dart`.

**Interfaces:** Produces `const int kPanoramaServerPort = 8459;` and `bool isAllowedViewerUrl(Uri? url)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/unit/viewer_url_policy_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/models/viewer_url_policy.dart';

void main() {
  test('allows exactly the local viewer origin and about:', () {
    expect(isAllowedViewerUrl(Uri.parse('http://localhost:8459/web/indoor_viewer.html')), isTrue);
    expect(isAllowedViewerUrl(Uri.parse('http://localhost:8459/data/indoor/x.jpg')), isTrue);
    expect(isAllowedViewerUrl(Uri.parse('about:blank')), isTrue);
  });

  test('rejects everything else (scheme/host/port), by parsed parts not prefix', () {
    for (final u in [
      'https://localhost:8459/',        // wrong scheme
      'http://localhost:8460/',         // wrong port
      'http://localhost.evil.example/', // wrong host (not a prefix match)
      'http://127.0.0.1:8459/',         // NOT treated as localhost (deliberate)
      'http://example.com/',
      'file:///etc/passwd',
      'data:text/html,<script>1</script>',
      'javascript:alert(1)',
    ]) {
      expect(isAllowedViewerUrl(Uri.parse(u)), isFalse, reason: u);
    }
    expect(isAllowedViewerUrl(null), isFalse);
  });
}
```

- [ ] **Step 2: Run — FAIL (undefined)**

```bash
flutter test test/unit/viewer_url_policy_test.dart
```

- [ ] **Step 3: Implement**

```dart
// lib/models/viewer_url_policy.dart
/// The fixed localhost port the bundled panorama viewer is served on.
const int kPanoramaServerPort = 8459;

/// Whether the WebView may perform a MAIN-FRAME navigation to [url].
///
/// This is a navigation policy, not a network firewall (subresource fetches are
/// governed by the page, not this hook). Allows only `about:` and the exact
/// local viewer origin, compared by parsed scheme+host+port — never a string
/// prefix. `127.0.0.1` is deliberately NOT treated as `localhost`.
bool isAllowedViewerUrl(Uri? url) {
  if (url == null) return false;
  final scheme = url.scheme.toLowerCase();
  if (scheme == 'about') return true;
  return scheme == 'http' &&
      url.host == 'localhost' &&
      url.port == kPanoramaServerPort;
}
```

- [ ] **Step 4: Run — PASS. Commit.**

```bash
flutter test test/unit/viewer_url_policy_test.dart && flutter analyze
git add lib/models/viewer_url_policy.dart test/unit/viewer_url_policy_test.dart
git commit -m "feat(panorama): pure isAllowedViewerUrl navigation policy + tests (SP1)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: IndoorManifest model (config + path-safety via public boundary)

Port MQ's `indoor_manifest.dart` verbatim (it is self-contained — no MQ imports except `dart:convert`/`foundation`). Test the security invariant through the **public** `buildPannellumConfig`, not the private guard.

**Files:** Create `lib/models/indoor_manifest.dart` (port of `MQ_Journey/lib/features/scan/domain/models/indoor_manifest.dart` — copy verbatim; it has no MQ-specific imports), `test/unit/indoor_manifest_test.dart`.

**Interfaces:** Produces `IndoorManifest` (`.fromJson(String)`, `nodes`, `isEmpty`, `buildPannellumConfig({required String assetBaseUrl, String? firstSceneId})`), `IndoorNode`, `NodeNeighbour`.

- [ ] **Step 1: Write the failing test**

```dart
// test/unit/indoor_manifest_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/models/indoor_manifest.dart';

const _twoScene = '''
{"nodes":[
 {"id":"a","image":"indoor/a.jpg","neighbours":[{"targetId":"b","heading":10,"label":"B"}]},
 {"id":"b","image":"indoor/b.jpg","neighbours":[{"targetId":"a","heading":-170}]}
]}''';

void main() {
  test('parses nodes and builds an equirectangular Pannellum config', () {
    final m = IndoorManifest.fromJson(_twoScene);
    expect(m.nodes.length, 2);
    final cfg = m.buildPannellumConfig(assetBaseUrl: 'http://localhost:8459/data');
    expect((cfg['default'] as Map)['firstScene'], 'a');
    final scenes = cfg['scenes'] as Map<String, dynamic>;
    expect((scenes['a'] as Map)['type'], 'equirectangular');
    expect((scenes['a'] as Map)['panorama'], 'http://localhost:8459/data/indoor/a.jpg');
    expect(((scenes['a'] as Map)['hotSpots'] as List).first['sceneId'], 'b');
  });

  test('SECURITY: unsafe image refs are blanked, never turned into an off-origin URL', () {
    for (final bad in ['https://evil/x.jpg', '/abs/x.jpg', '//host/x.jpg', '../../secret.jpg', 'data:image/png;base64,AAAA']) {
      final m = IndoorManifest.fromJson('{"nodes":[{"id":"a","image":${_json(bad)},"neighbours":[]}]}');
      final scenes = m.buildPannellumConfig(assetBaseUrl: 'http://localhost:8459/data')['scenes'] as Map;
      expect((scenes['a'] as Map)['panorama'], '', reason: bad); // blanked, not off-origin
    }
    // A safe relative path IS resolved.
    final ok = IndoorManifest.fromJson('{"nodes":[{"id":"a","image":"indoor/a.jpg","neighbours":[]}]}');
    final okScenes = ok.buildPannellumConfig(assetBaseUrl: 'http://localhost:8459/data')['scenes'] as Map;
    expect((okScenes['a'] as Map)['panorama'], 'http://localhost:8459/data/indoor/a.jpg');
  });
}

String _json(String s) => '"${s.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
```

- [ ] **Step 2: Run — FAIL (undefined).**
- [ ] **Step 3: Create `lib/models/indoor_manifest.dart`** — copy MQ's file verbatim (change only the `library`/none; it imports only `dart:convert` + `package:flutter/foundation.dart`, both available). Keep `_isSafeRelativeImagePath` **private**.
- [ ] **Step 4: Run — PASS** (both the config-shape and the SECURITY test). This proves the guard through the public boundary. **Commit.**

```bash
git add lib/models/indoor_manifest.dart test/unit/indoor_manifest_test.dart
git commit -m "feat(panorama): IndoorManifest + Pannellum config; path-safety tested via public API (SP1)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: panorama_data + providers + data-integrity

The venue→tour map (the single source of availability + the ONLY place a `venueId` becomes an asset path) and its providers.

**Files:** Create `lib/data/panorama_data.dart`, `test/unit/panorama_data_test.dart`; modify `lib/services/providers.dart`.

**Interfaces:** Produces `PanoramaTour({required String venueId, required String manifestAsset, required bool placeholder})`; `PanoramaData.tours` (list); `PanoramaData.tourFor(String venueId) -> PanoramaTour?` (exact lookup); providers `venuesWithPanoramaProvider` and `indoorManifestProvider(venueId)`.

- [ ] **Step 1: Write the failing exact-lookup test** (the bundle data-integrity test is added in **Task 4**, once assets exist — keeping this task's commit green)

```dart
// test/unit/panorama_data_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/data/panorama_data.dart';

void main() {
  test('tourFor is an exact lookup — unknown venueId returns null (no path injection)', () {
    expect(PanoramaData.tourFor('macquarie-theatre'), isNotNull);
    expect(PanoramaData.tourFor('../../etc/passwd'), isNull);
    expect(PanoramaData.tourFor('does-not-exist'), isNull);
  });
}
```

- [ ] **Step 2: Run — FAIL** (undefined).
- [ ] **Step 3: Implement `panorama_data.dart`**

```dart
// lib/data/panorama_data.dart
import 'package:meta/meta.dart';

@immutable
class PanoramaTour {
  const PanoramaTour({
    required this.venueId,
    required this.manifestAsset,
    required this.placeholder,
  });
  final String venueId;
  final String manifestAsset; // e.g. 'assets/data/indoor/macquarie-theatre.json'
  final bool placeholder;
}

/// The venue→tour map. SP1 ships exactly one flagged placeholder tour.
abstract final class PanoramaData {
  static const List<PanoramaTour> tours = [
    PanoramaTour(
      venueId: 'macquarie-theatre',
      manifestAsset: 'assets/data/indoor/macquarie-theatre.json',
      placeholder: true,
    ),
  ];

  /// Exact lookup — the ONLY way a venueId becomes an asset path.
  static PanoramaTour? tourFor(String venueId) {
    for (final t in tours) {
      if (t.venueId == venueId) return t;
    }
    return null;
  }

  static bool hasTour(String venueId) => tourFor(venueId) != null;
}
```

- [ ] **Step 4: Add providers to `lib/services/providers.dart`**

```dart
// (add near the other providers; imports: panorama_data.dart, indoor_manifest.dart, flutter/services rootBundle)
final venuesWithPanoramaProvider = Provider<Set<String>>((ref) =>
    PanoramaData.tours.map((t) => t.venueId).toSet());

final indoorManifestProvider =
    FutureProvider.family<IndoorManifest?, String>((ref, venueId) async {
  final tour = PanoramaData.tourFor(venueId); // exact lookup — never interpolate venueId
  if (tour == null) return null;
  final raw = await rootBundle.loadString(tour.manifestAsset);
  return IndoorManifest.fromJson(raw);
});
```

- [ ] **Step 5: Run the exact-lookup test — PASS; analyze; commit** (all green).

```bash
flutter test test/unit/panorama_data_test.dart && flutter analyze
git add lib/data/panorama_data.dart lib/services/providers.dart test/unit/panorama_data_test.dart
git commit -m "feat(panorama): venue->tour map with exact lookup + providers (SP1)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: Assets — viewer, Pannellum, the one placeholder tour, provenance

**Files (create under `assets/`):** `assets/web/indoor_viewer.html`; `assets/web/pannellum/pannellum.js`, `pannellum.css`, `LICENSE`; `assets/data/indoor/macquarie-theatre.json`; two downscaled JPGs `assets/data/indoor/macquarie-theatre_entrance.jpg` + `_theatre.jpg`; `docs/panorama-image-provenance.md`. Modify `pubspec.yaml` (asset dirs).

- [ ] **Step 1: Vendor the viewer + Pannellum** — copy verbatim from MQ_Journey:
  - `MQ_Journey/assets/web/indoor_viewer.html` → `assets/web/indoor_viewer.html`
  - `MQ_Journey/assets/web/pannellum/pannellum.js` + `pannellum.css` → `assets/web/pannellum/`
  - Add Pannellum's upstream `LICENSE` (MIT) as `assets/web/pannellum/LICENSE`.

- [ ] **Step 2: The one placeholder tour**
  - Copy `MQ_Journey/assets/data/indoor/hadenfeld-10.json` → `assets/data/indoor/macquarie-theatre.json`; keep its 2 nodes but repoint `image` to `indoor/macquarie-theatre_entrance.jpg` and `indoor/macquarie-theatre_theatre.jpg`.
  - Copy MQ's `hadenfeld-10_entrance.jpg` + `hadenfeld-10_t1.jpg`, **downscale** each (e.g. to ≤ 4096px wide / ~1–2 MB) to `macquarie-theatre_entrance.jpg` + `_theatre.jpg`. Total ≤ ~8 MB.

- [ ] **Step 3: Provenance note** — create `docs/panorama-image-provenance.md` recording, for the two JPGs: **source** (MQ_Journey `assets/data/indoor/`), **copyright owner**, **licence/permission** (confirm redistribution rights — MQ_Journey and aon2026 are sibling projects; state the permission basis), **attribution**, and that **downscaling is permitted**. **If rights can't be confirmed, STOP and substitute owned/CC-licensed demo panoramas** (the viewer is content-agnostic — no code changes). Note Pannellum is MIT (`assets/web/pannellum/LICENSE`).

- [ ] **Step 4: Declare assets in `pubspec.yaml`**

```yaml
  assets:
    - assets/web/indoor_viewer.html
    - assets/web/pannellum/
    - assets/data/indoor/
```

- [ ] **Step 5: Add the bundle data-integrity test** (assets now exist — append to `test/unit/panorama_data_test.dart`)

```dart
import 'package:flutter/services.dart' show rootBundle;
import 'package:aon2026/models/indoor_manifest.dart';
// add inside main():
  test('DATA INTEGRITY: every tour manifest loads from the bundle, parses, and hotspots + images resolve', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final tour in PanoramaData.tours) {
      final raw = await rootBundle.loadString(tour.manifestAsset); // the bundle, not pubspec lines
      final m = IndoorManifest.fromJson(raw);
      expect(m.isEmpty, isFalse, reason: tour.venueId);
      final ids = m.nodes.map((n) => n.id).toSet();
      for (final n in m.nodes) {
        for (final nb in n.neighbours) {
          expect(ids.contains(nb.id), isTrue, reason: '${tour.venueId} hotspot ${nb.id}');
        }
        final img = 'assets/data/${n.image}'; // manifest image is 'indoor/x.jpg'
        expect((await rootBundle.load(img)).lengthInBytes, greaterThan(0), reason: img);
      }
    }
  });
```

- [ ] **Step 6: Run — PASS; confirm asset budget; analyze; commit**

```bash
flutter test test/unit/panorama_data_test.dart
du -ch assets/data/indoor/*.jpg | tail -1   # ≤ ~8 MB
flutter analyze
git add assets/ docs/panorama-image-provenance.md pubspec.yaml test/unit/panorama_data_test.dart
git commit -m "assets(panorama): vendor Pannellum + one flagged placeholder tour + provenance + integrity test (SP1)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 5: panorama_server — single localhost-server owner

**Files:** Create `lib/services/panorama_server.dart`, `test/widget/panorama_server_test.dart`.

**Interfaces:** Produces `PanoramaServer` with `Future<void> ensureStarted()` (idempotent), `bool get isRunning`, `String get baseUrl`. A single module-level instance (MQ's pattern).

> **⚠ Verified gotcha (plan-gauntlet):** `InAppLocalhostServer(...)` throws
> *"A platform implementation for flutter_inappwebview has not been set"* when
> **constructed** in a headless `flutter_test` — and if it's constructed
> eagerly (a `final _server = InAppLocalhostServer(...)` field or a module-level
> `final panoramaServer = ...` that builds it), **importing this file crashes
> every test that transitively imports it** (including Task 6's webview test).
> The construction is therefore **deferred into `ensureStarted`'s Future** below,
> so (a) importing is safe, and (b) the platform failure becomes an
> **async-catchable** error the caller maps to the unavailable state. Verified:
> import-safe + graceful failure both green in `flutter_test`.

- [ ] **Step 1: Write the failing test** (import-safety + graceful failure — no real platform needed)

```dart
// test/widget/panorama_server_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/services/panorama_server.dart';
import 'package:aon2026/models/viewer_url_policy.dart';

void main() {
  test('import-safe: baseUrl works without constructing the server', () {
    expect(panoramaServer.baseUrl, 'http://localhost:$kPanoramaServerPort');
    expect(panoramaServer.isRunning, isFalse);
  });

  test('ensureStarted failure is graceful (async-catchable), isRunning stays false', () async {
    // Headless VM has no platform impl → the deferred construction errors, but
    // as a catchable async error, not a crash-at-import.
    await panoramaServer.ensureStarted().catchError((_) {});
    expect(panoramaServer.isRunning, isFalse);
    expect(() => panoramaServer.baseUrl, returnsNormally);
  });
}
```

- [ ] **Step 2: Run — FAIL (undefined).**
- [ ] **Step 3: Implement** (single owner; **lazy + deferred construction**)

```dart
// lib/services/panorama_server.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:aon2026/models/viewer_url_policy.dart';

/// Single owner of the localhost asset server serving the bundled viewer +
/// panoramas. The `InAppLocalhostServer` is built LAZILY inside [ensureStarted]
/// (never at import/construction), so importing this file is safe in unit tests
/// and on web; the deferred build turns a platform/bind failure into an async
/// error the caller maps to the unavailable state.
class PanoramaServer {
  PanoramaServer._();
  InAppLocalhostServer? _server;
  Future<void>? _starting;
  bool _running = false;

  String get baseUrl => 'http://localhost:$kPanoramaServerPort';
  bool get isRunning => _running;

  Future<void> ensureStarted() {
    if (kIsWeb) return Future.value(); // web serves assets same-origin; no server
    return _starting ??= Future(() async {
      _server ??=
          InAppLocalhostServer(documentRoot: 'assets', port: kPanoramaServerPort);
      await _server!.start();
      _running = true;
    });
  }
}

final panoramaServer = PanoramaServer._();
```

- [ ] **Step 4: Run — PASS; analyze; commit.**

```bash
flutter test test/widget/panorama_server_test.dart && flutter analyze
git add lib/services/panorama_server.dart test/widget/panorama_server_test.dart
git commit -m "feat(panorama): single idempotent localhost-server owner (SP1)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 6: panorama_web_view — the ported host (webview render is on-device)

Port MQ's `indoor_webview.dart`, adapted: use `panoramaServer` (Task 5) instead of the module-level server, `isAllowedViewerUrl` (Task 1) in `shouldOverrideUrlLoading`, inline aon2026 strings, and the aon2026 unavailable state. The webview render is a platform view (on-device); the **failure state and the `sceneChanged` validation are the testable parts** (both already unit-covered by Tasks 1/2 policy + manifest — here we cover the widget's failure path).

**Files:** Create `lib/widgets/panorama_web_view.dart`, `test/widget/panorama_web_view_test.dart`.

- [ ] **Step 1: Write the failing widget test (failure path — no real webview needed)**

```dart
// test/widget/panorama_web_view_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/models/indoor_manifest.dart';
import 'package:aon2026/widgets/panorama_web_view.dart';

void main() {
  testWidgets('shows the unavailable state, not a crash, when the server is unavailable',
      (tester) async {
    // Force the unavailable branch via the widget's @visibleForTesting hook.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PanoramaWebView.forTest(
          manifest: IndoorManifest.fromJson('{"nodes":[{"id":"a","image":"indoor/a.jpg","neighbours":[]}]}'),
          forceUnavailable: true,
        ),
      ),
    ));
    await tester.pump();
    expect(find.textContaining('unavailable'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run — FAIL (undefined).**
- [ ] **Step 3: Implement** — port `indoor_webview.dart` with these exact adaptations:
  - Delete the module-level server; call `panoramaServer.ensureStarted()` in `initState` (non-web), map its failure to `_serverFailed`.
  - `_viewerBase` = `panoramaServer.baseUrl` (non-web) / `Uri.base.resolve('assets/assets')` (web).
  - `shouldOverrideUrlLoading` → `return isAllowedViewerUrl(action.request.url) ? ALLOW : CANCEL;` (drops the inline check; keep `useShouldOverrideUrlLoading: true`).
  - Keep verbatim: `onWebViewCreated` handler `sceneChanged` **validating `sceneId` against `widget.manifest.nodes`** before `onSceneChanged`; `onLoadStop` → `loadTour(${jsonEncode(config)})` with `assetBaseUrl: '$_viewerBase/data'`; `selectScene(${jsonEncode(sceneId)})`.
  - Failure/loading states use inline strings: unavailable → `Text('360° preview unavailable')`.
  - Add `@visibleForTesting PanoramaWebView.forTest({required manifest, bool forceUnavailable})` that renders the unavailable branch without starting a webview.

- [ ] **Step 4: Run — PASS; analyze; commit.**

```bash
flutter test test/widget/panorama_web_view_test.dart && flutter analyze
git add lib/widgets/panorama_web_view.dart test/widget/panorama_web_view_test.dart
git commit -m "feat(panorama): webview host — server/policy wired, sceneChanged validated (SP1)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 7: scene rail + tour view (glass over the platform view)

Port MQ's `scene_rail.dart` + `indoor_tour_view.dart`, adapted to `GlassSurface(control, allowShader:false)` and inline strings. Composition is on-device; the scene-rail's pure bits (chip list from manifest) are widget-testable.

**Files:** Create `lib/widgets/panorama_scene_rail.dart`, `lib/widgets/panorama_tour_view.dart`, `test/widget/panorama_scene_rail_test.dart`.

- [ ] **Step 1: Failing test** — pump `PanoramaSceneRail` with a 2-node manifest; assert 2 scene chips render and tapping one calls `onSceneSelected` with its id.
- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Implement** — port `scene_rail.dart` (drop `kTabBarIslandClearance` usage → pass 0, since SP1's panorama is a full-screen route with no tab bar; keep the collapsible index-scroll). Port `indoor_tour_view.dart` composing `PanoramaWebView` + `PanoramaSceneRail` + a `GlassSurface(control, allowShader:false)` title island (inline title string). Replace `MqColors`→`AonColors`.
- [ ] **Step 4: Run — PASS; analyze; commit.**

```bash
git add lib/widgets/panorama_scene_rail.dart lib/widgets/panorama_tour_view.dart test/widget/panorama_scene_rail_test.dart
git commit -m "feat(panorama): scene rail + tour view with glass island (allowShader:false) (SP1)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 8: map mode toggle + building picker (no auto-select)

**Files:** Create `lib/widgets/map_mode_toggle.dart`, `lib/widgets/panorama_building_picker.dart`, `test/widget/panorama_picker_test.dart`.

**Interfaces:** `enum MapMode { campusMap, panorama }`; `MapModeToggle({required MapMode value, required ValueChanged<MapMode> onChanged})`; `PanoramaBuildingPicker({required void Function(String venueId) onOpen})`.

- [ ] **Step 1: Write the failing picker test**

```dart
// test/widget/panorama_picker_test.dart — assert:
// - a venue WITH a tour (macquarie-theatre) renders tappable with a "Demo 360° — sample imagery, not this venue" flag;
// - tapping it calls onOpen('macquarie-theatre');
// - at least one venue WITHOUT a tour renders a non-tappable "coming soon" card;
// - the picker is ALWAYS shown (there is no auto-open path even though exactly one tour exists).
```
(Pump inside `ProviderScope`; the picker reads the full venue list from
**`venuesProvider`** (`Provider<List<Venue>>` = `VenuesData.all`, in
`services/providers.dart`) and availability from `venuesWithPanoramaProvider`;
**no manifest I/O**.)

- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Implement**
  - `map_mode_toggle.dart`: port MQ's `MapModeToggle` (rename `ar`→`panorama`; `MqColors`/`MqSpacing`→`AonColors`/`AonSpacing`; labels inline "Campus Map"/"360°"; keep `GlassSurface(control)`).
  - `panorama_building_picker.dart`: glass cards over the venue list. Availability from `venuesWithPanoramaProvider` (sync). Tour venues → tappable card (scene-count optional) + the **"Demo 360° — sample imagery, not this venue"** flag; others → "coming soon", non-tappable. **No auto-select** — always render the full list; tapping a tour card calls `onOpen(venueId)`. ≥56px targets, glass fallback ladder.
- [ ] **Step 4: Run — PASS; analyze; commit.**

```bash
git add lib/widgets/map_mode_toggle.dart lib/widgets/panorama_building_picker.dart test/widget/panorama_picker_test.dart
git commit -m "feat(panorama): map mode toggle + building picker, no auto-select, demo flag (SP1)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 9: panorama route + map screen integration (failure states, deep-link safety)

**Files:** Create `lib/screens/panorama_screen.dart`; modify `lib/app/router/app_router.dart` (both the route table **and** the `Routes` class live here — there is no separate `routes.dart`) and `lib/screens/map_screen.dart`.

- [ ] **Step 1: Write the failing test (deep-link safety + failure state)**

```dart
// test/widget/panorama_route_test.dart — via buildRouter():
// - go('/panorama/does-not-exist')  -> renders the unavailable/back state, NOT a crash, NO asset read;
// - go('/panorama/macquarie-theatre') -> renders the tour view scaffold (PanoramaTourView present);
//   (the webview itself is a platform view; assert the screen scaffold + no exception, not the render.)
```

- [ ] **Step 2: Run — FAIL.**
- [ ] **Step 3: Implement**
  - `panorama_screen.dart`: a full-screen `Scaffold`; resolve the tour via `PanoramaData.tourFor(venueId)` — **null → the "360° preview unavailable" back state** (never interpolate a path). Watch `indoorManifestProvider(venueId)`; `null`/error/empty manifest → unavailable state; loaded → `PanoramaTourView(manifest: …)`. All the §5 failure states land here.
  - `app_router.dart`: add a **top-level** route (outside the `StatefulShellRoute`, beside `eventDetail`/`wayfinding`) `path: '/panorama/:venueId'` → `PanoramaScreen(venueId: state.pathParameters['venueId']!)`; and add to the `Routes` class (same file, alongside `eventDetailFor`/`wayfindingTo`): `static String panoramaFor(String id) => '/panorama/$id';`.
  - `map_screen.dart`: hold `MapMode` state; render the `MapModeToggle` (floating, glass); `campusMap` → existing map; `panorama` → `PanoramaBuildingPicker(onOpen: (id) => context.push(Routes.panoramaFor(id)))`.
- [ ] **Step 4: Run — PASS; analyze; full suite; commit.**

```bash
flutter analyze && flutter test
git add lib/screens/panorama_screen.dart lib/app/router/ lib/screens/map_screen.dart test/widget/panorama_route_test.dart
git commit -m "feat(panorama): immersive route + map toggle entry; safe deep-link/failure states (SP1)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Verification gate (SP1 complete only when ALL hold)

- [ ] **Static + tests**

```bash
flutter analyze          # clean
flutter test             # green; compare total to Task 0 baseline (+ the new SP1 tests)
```

Must include: `viewer_url_policy` (allow/deny), `indoor_manifest` (config + SECURITY path-blanking), `panorama_data` (exact lookup + bundle data-integrity), `panorama_server` (idempotent), `panorama_web_view` (unavailable state), `panorama_scene_rail`, `panorama_picker` (no auto-select + demo flag), `panorama_route` (deep-link safety).

- [ ] **Platform build gate** — record `PASS / FAIL / NOT AVAILABLE`:

```bash
flutter build ios --simulator --debug
flutter build apk --debug
```

- [ ] **On-device iOS pass (best-effort, screenshotted):** Map → **360°** toggle → picker (one tour card with the demo flag + "coming soon" venues) → open the tour → it loads, pans, **hotspot-navigates between the 2 scenes**, and the **glass island stays legible over the WebView regardless of blur quality**; press back → returns to the picker (no loop). Force the unavailable state (`/panorama/<unknown>`) → safe back state, no crash.

- [ ] **Security/provenance checks:** `isAllowedViewerUrl` tests green; deep-link to an unknown venue reaches the unavailable state; **`docs/panorama-image-provenance.md` present and complete**; **`assets/web/pannellum/LICENSE` present**; asset budget ≤ ~8 MB.

- [ ] **MANDATORY final re-gate (after any on-device fix / probe removal):**

```bash
flutter analyze && flutter test
git diff --check
git status --short   # only intended files; no debug residue
```

Then a hostile read of `git diff main..HEAD` and record evidence describing the **final** tree.

- [ ] **Finish the branch** — REQUIRED SUB-SKILL: superpowers:finishing-a-development-branch.

## Files summary

| File | Change | Task |
|---|---|---|
| `pubspec.yaml` / `pubspec.lock` | + `flutter_inappwebview`; asset dirs | 0, 4 |
| `lib/models/viewer_url_policy.dart` | create (pure policy) | 1 |
| `lib/models/indoor_manifest.dart` | create (port) | 2 |
| `lib/data/panorama_data.dart` | create (venue→tour, exact lookup) | 3 |
| `lib/services/providers.dart` | modify (2 providers) | 3 |
| `assets/web/…`, `assets/data/indoor/…`, `docs/panorama-image-provenance.md` | create (viewer + Pannellum + LICENSE + 1 tour + provenance) | 4 |
| `lib/services/panorama_server.dart` | create (single owner) | 5 |
| `lib/widgets/panorama_web_view.dart` | create (ported host) | 6 |
| `lib/widgets/panorama_scene_rail.dart`, `panorama_tour_view.dart` | create (ported, glass) | 7 |
| `lib/widgets/map_mode_toggle.dart`, `panorama_building_picker.dart` | create | 8 |
| `lib/screens/panorama_screen.dart` | create (immersive route) | 9 |
| `lib/app/router/app_router.dart` (route table + `Routes` class), `lib/screens/map_screen.dart` | modify (route + toggle entry) | 9 |
| `test/…` | create (8 test files) | 1–9 |
