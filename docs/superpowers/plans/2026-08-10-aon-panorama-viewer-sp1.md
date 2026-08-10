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
- **Security invariants — each earned by a DIRECT test (Task 1/2/4):** (a) main-frame navigation only to `about:blank` or the exact viewer HTML path (`isAllowedViewerUrl` test); (b) panorama image refs gated to safe relative paths (manifest public-boundary test); (c) asset paths resolved by **exact `panorama_data` lookup, never interpolated from `venueId`**; (d) `jsonEncode` for all Dart→JS (`buildLoadTourJs`/`buildSelectSceneJs` hostile-input test); (e) inbound `sceneChanged` validated against the known scene set (`validatedInboundScene` test); (f) the bundled viewer HTML is locally isolated — CSP present, no external origins (isolation test).
- **Web platform:** panorama is **NOT AVAILABLE** — on `kIsWeb`, `PanoramaWebView` renders the unavailable state immediately and constructs no server/webview (matches the frozen design; no half-web path).
- **Reduced motion:** `buildPannellumConfig(reduceMotion: MediaQuery.disableAnimationsOf(context))` → no scene fade, `autoRotate` off.
- **Phase-5 2.0 contract inherited:** every new Flutter surface (toggle, picker, rail, unavailable state) has 320×568 / 414×896 × TextScaler-2.0 no-overflow coverage + ≥56px targets + semantics (Task 8).
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

- [ ] **Step 3: Add the dependency with the stated constraint** (the command must encode the `^6.1.5` floor — not a bare add)

```bash
flutter pub add "flutter_inappwebview:^6.1.5"
```

Verify `pubspec.yaml` shows `flutter_inappwebview: ^6.1.5` and `pubspec.lock` updated.

- [ ] **Step 4: NATIVE smoke builds NOW** (a native plugin's Gradle/CocoaPods integration is not exercised by `analyze`/`test`; catch it while the diff is two lines, not after nine feature tasks). Record `PASS / FAIL / NOT AVAILABLE`:

```bash
flutter build ios --simulator --debug
flutter build apk --debug
```

If either FAILS on native integration, STOP and resolve before writing feature code.

- [ ] **Step 5: Analyze + test still green; commit** (include the iOS plugin-registrant + Podfile changes the plugin generates)

```bash
flutter analyze && flutter test
git add pubspec.yaml pubspec.lock ios/ android/
git commit -m "build: add flutter_inappwebview ^6.1.5 for the 360 panorama viewer (SP1)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 1: Viewer URL policy (pure, security-critical)

Extract MQ's inline `_shouldOverrideUrlLoading` check into a pure, unit-tested function.

This task earns the three "tested" security invariants (b/d/e) with **pure,
directly-tested** helpers: the main-frame URL policy, the Dart→JS encoders, and
the inbound scene validator. The webview host (Task 6) only delegates to these.

**Files:** Create `lib/models/viewer_url_policy.dart`, `lib/models/webview_bridge.dart`, `test/unit/viewer_url_policy_test.dart`, `test/unit/webview_bridge_test.dart`.

**Interfaces:** `const int kPanoramaServerPort = 8459`; `bool isAllowedViewerUrl(Uri? url)`; `String buildLoadTourJs(Map<String,dynamic> config)`; `String buildSelectSceneJs(String sceneId)`; `String? validatedInboundScene(Object? inbound, Set<String> knownScenes)`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/unit/viewer_url_policy_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/models/viewer_url_policy.dart';

void main() {
  test('main-frame policy: only about:blank and the exact viewer HTML path', () {
    // Least privilege: the MAIN FRAME only ever loads the viewer page; panorama
    // JPGs are subresources (never main-frame navigations), so they are NOT
    // allowed here.
    expect(isAllowedViewerUrl(Uri.parse('http://localhost:8459/web/indoor_viewer.html')), isTrue);
    expect(isAllowedViewerUrl(Uri.parse('http://localhost:8459/web/indoor_viewer.html?x=1#s')), isTrue);
    expect(isAllowedViewerUrl(Uri.parse('about:blank')), isTrue);
  });

  test('rejects everything else, by parsed parts not prefix', () {
    for (final u in [
      'http://localhost:8459/data/indoor/x.jpg', // a subresource, not a main-frame target
      'http://localhost:8459/',                  // not the viewer path
      'about:srcdoc',                            // only about:blank exactly
      'https://localhost:8459/web/indoor_viewer.html',
      'http://localhost:8460/web/indoor_viewer.html',
      'http://localhost.evil.example/web/indoor_viewer.html',
      'http://127.0.0.1:8459/web/indoor_viewer.html', // NOT localhost (deliberate)
      'http://localhost:8459@evil.com/web/indoor_viewer.html', // userinfo injection → host evil.com
      'file:///etc/passwd', 'data:text/html,x', 'javascript:alert(1)',
    ]) {
      expect(isAllowedViewerUrl(Uri.parse(u)), isFalse, reason: u);
    }
    expect(isAllowedViewerUrl(null), isFalse);
  });
}
```

```dart
// test/unit/webview_bridge_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/models/webview_bridge.dart';

void main() {
  test('Dart->JS: hostile scene ids are JSON-escaped, not string-interpolated', () {
    // A quote/backslash/newline must be escaped so the injected JS stays a
    // single string literal — never breaks out into executable code.
    expect(buildSelectSceneJs('a"; evilGlobalCall(); "'), 'selectScene("a\\"; evilGlobalCall(); \\"");');
    expect(buildSelectSceneJs('back\\slash'), 'selectScene("back\\\\slash");');
    expect(buildSelectSceneJs('line\nbreak'), 'selectScene("line\\nbreak");');
    expect(buildLoadTourJs({'a': 'x"y'}), 'loadTour({"a":"x\\"y"});');
  });

  test('inbound sceneChanged is validated against the known scene set', () {
    final known = {'a', 'b'};
    expect(validatedInboundScene('a', known), 'a');
    expect(validatedInboundScene('evil', known), isNull);   // unknown → rejected
    expect(validatedInboundScene(null, known), isNull);     // null → rejected
    expect(validatedInboundScene(42, known), isNull);       // non-string → rejected
    expect(validatedInboundScene(['a'], known), isNull);    // list → rejected
  });
}
```

- [ ] **Step 2: Run — FAIL (undefined).**

- [ ] **Step 3: Implement both files**

```dart
// lib/models/viewer_url_policy.dart
const int kPanoramaServerPort = 8459;

/// The single main-frame page the viewer ever loads.
const String _viewerPath = '/web/indoor_viewer.html';

/// Whether the WebView may perform a MAIN-FRAME navigation to [url].
/// Navigation policy only (NOT a subresource/network firewall — that is the
/// page CSP, Task 4). Least privilege: `about:blank` exactly, or the exact
/// viewer HTML on the local origin (parsed scheme+host+port+path — never a
/// prefix; `127.0.0.1` is not `localhost`; userinfo cannot spoof the host).
bool isAllowedViewerUrl(Uri? url) {
  if (url == null) return false;
  final scheme = url.scheme.toLowerCase();
  if (scheme == 'about') return url.path == 'blank';
  return scheme == 'http' &&
      url.host == 'localhost' &&
      url.port == kPanoramaServerPort &&
      url.path == _viewerPath;
}
```

```dart
// lib/models/webview_bridge.dart
import 'dart:convert';

/// Dart→JS command builders. jsonEncode (never string interpolation) keeps a
/// hostile scene id / config inside a single JS string literal — it can never
/// break out into executable code. (The JS runs via evaluateJavascript, not
/// inline in HTML, so `</script>` needs no special handling.)
String buildLoadTourJs(Map<String, dynamic> config) => 'loadTour(${jsonEncode(config)});';
String buildSelectSceneJs(String sceneId) => 'selectScene(${jsonEncode(sceneId)});';

/// JS→Dart trust boundary: an inbound `sceneChanged` payload is accepted only
/// if it is a String naming a KNOWN scene; anything else (null, non-String,
/// unknown id) is rejected.
String? validatedInboundScene(Object? inbound, Set<String> knownScenes) {
  if (inbound is! String) return null;
  return knownScenes.contains(inbound) ? inbound : null;
}
```

> **On-device caveat (least privilege):** narrowing the main-frame policy to the
> viewer path is stricter than MQ (which allowed any localhost:8459 path). If the
> tour fails to load on-device because Pannellum performs an unexpected same-origin
> main-frame navigation, widen to `url.path.startsWith('/web/')` with a recorded
> reason — do not re-open other origins. Verified in the on-device gate.

- [ ] **Step 4: Run — PASS; analyze; commit.**

```bash
flutter test test/unit/viewer_url_policy_test.dart test/unit/webview_bridge_test.dart && flutter analyze
git add lib/models/viewer_url_policy.dart lib/models/webview_bridge.dart test/unit/viewer_url_policy_test.dart test/unit/webview_bridge_test.dart
git commit -m "feat(panorama): tested webview boundary — URL policy + JS encoders + scene validation (SP1)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: IndoorManifest model (config + path-safety via public boundary)

Port MQ's `indoor_manifest.dart` (self-contained — imports only `dart:convert`/`foundation`), with **one adaptation for reduced motion**: MQ's config sets `'sceneFadeDuration': 600` (an animated scene fade) and relies on Pannellum's `autoRotate` default (off). Add a `bool reduceMotion = false` parameter to `buildPannellumConfig` → when true, `'sceneFadeDuration': 0` and `'autoRotate': false` explicitly (no auto-spin, no animated transition). The webview host (Task 6) passes `MediaQuery.disableAnimationsOf(context)`. Test the security invariant through the **public** `buildPannellumConfig`, not the private guard.

**Files:** Create `lib/models/indoor_manifest.dart` (port of `MQ_Journey/lib/features/scan/domain/models/indoor_manifest.dart` + the `reduceMotion` param), `test/unit/indoor_manifest_test.dart`.

**Interfaces:** Produces `IndoorManifest` (`.fromJson(String)`, `nodes`, `isEmpty`, `buildPannellumConfig({required String assetBaseUrl, String? firstSceneId, bool reduceMotion = false})`), `IndoorNode`, `NodeNeighbour`.

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

  test('REDUCED MOTION: no scene fade and autoRotate off', () {
    final m = IndoorManifest.fromJson(_twoScene);
    final normal = m.buildPannellumConfig(assetBaseUrl: 'x')['default'] as Map;
    expect(normal['sceneFadeDuration'], 600); // MQ default (animated)
    final reduced = m.buildPannellumConfig(assetBaseUrl: 'x', reduceMotion: true)['default'] as Map;
    expect(reduced['sceneFadeDuration'], 0);   // no animated transition
    expect(reduced['autoRotate'], false);      // no auto-spin
  });
}

String _json(String s) => '"${s.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
```

- [ ] **Step 2: Run — FAIL (undefined).**
- [ ] **Step 3: Create `lib/models/indoor_manifest.dart`** — copy MQ's file, then add the `bool reduceMotion = false` param to `buildPannellumConfig`; in the `'default'` map set `'sceneFadeDuration': reduceMotion ? 0 : 600` and add `'autoRotate': reduceMotion ? false : false` (explicit off either way). Keep `_isSafeRelativeImagePath` **private**. Imports only `dart:convert` + `package:flutter/foundation.dart`.
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
  - `MQ_Journey/assets/web/indoor_viewer.html` → `assets/web/indoor_viewer.html`. **This HTML is the subresource trust boundary:** it ships a `Content-Security-Policy` (`default-src 'none'; connect-src 'self'; img-src 'self' data: blob:; script-src 'self' 'unsafe-inline' 'unsafe-eval'; …`) and references only local `pannellum/…`. **Readiness (verified):** `loadTour` is defined in a synchronous `<script>` after the synchronous `<script src="pannellum/pannellum.js">`, so both are defined by `onLoadStop` — Task 6's `onLoadStop → loadTour` is a safe handshake, no async race.
  - `MQ_Journey/assets/web/pannellum/pannellum.js` + `pannellum.css` → `assets/web/pannellum/`
  - Add Pannellum's upstream `LICENSE` (MIT) as `assets/web/pannellum/LICENSE`.

- [ ] **Step 2: The one placeholder tour — with NEUTRALISED text**
  - Copy `MQ_Journey/assets/data/indoor/hadenfeld-10.json` → `assets/data/indoor/macquarie-theatre.json`; keep its 2 nodes but repoint `image` to `indoor/macquarie-theatre_entrance.jpg` / `indoor/macquarie-theatre_theatre.jpg`, and **rewrite every visible string** (`description`, neighbour `label`) to neutral demo wording — `"description": "Sample scene 1"` / `"Sample scene 2"`, labels `"Next scene"` / `"Back"`. **No "Hadenfeld"/"10 Hadenfeld Avenue"/"Theatre 1" text may survive inside a manifest labelled Macquarie Theatre** (the demo flag warns it's not this venue; the interior text must not silently reintroduce the real building).
  - Copy MQ's `hadenfeld-10_entrance.jpg` + `hadenfeld-10_t1.jpg`, **downscale** each (e.g. ≤ 4096px wide / ~1–2 MB) to `macquarie-theatre_entrance.jpg` + `_theatre.jpg`. Total ≤ ~8 MB.

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

- [ ] **Step 6: Add the viewer-isolation static test** (proves the subresource trust boundary the navigation policy does not cover — the Goal says the boundary is "explicit and tested") — new `test/unit/viewer_html_isolation_test.dart`:

```dart
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('bundled viewer HTML is locally isolated (CSP present, no external origins)', () async {
    final html = await rootBundle.loadString('assets/web/indoor_viewer.html');
    // A restrictive CSP is present, defaulting to no external anything.
    expect(html, contains('Content-Security-Policy'));
    expect(html, contains("default-src 'none'"));
    expect(html, contains("connect-src 'self'")); // blocks off-origin fetch/beacon
    // No external network origins anywhere in the document (scripts, styles,
    // images, fetch). Only same-origin relative refs are allowed.
    expect(RegExp(r'https?://').hasMatch(html), isFalse,
        reason: 'viewer HTML must reference no external http(s) origin');
  });
}
```

- [ ] **Step 7: Run — PASS; confirm asset budget; analyze; commit**

```bash
flutter test test/unit/panorama_data_test.dart test/unit/viewer_html_isolation_test.dart
du -ch assets/data/indoor/*.jpg | tail -1   # ≤ ~8 MB
flutter analyze
git add assets/ docs/panorama-image-provenance.md pubspec.yaml test/unit/panorama_data_test.dart test/unit/viewer_html_isolation_test.dart
git commit -m "assets(panorama): vendor Pannellum + neutralised placeholder tour + provenance + integrity/isolation tests (SP1)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 5: panorama_server — single localhost-server owner

**Files:** Create `lib/services/panorama_server.dart`, `test/widget/panorama_server_test.dart`.

**Interfaces:** Produces `PanoramaServer({Future<void> Function()? start})` with `Future<void> ensureStarted()`, `bool get isRunning`, `String get baseUrl`; a single module-level `panoramaServer`. **Lifecycle (documented):** the server is **process-lifetime owned** and intentionally **not closed** between panorama routes (one server serves all tours; reopening a route reuses it). Start is **idempotent** (the real `start()` runs at most once) and **retryable** (a failed start clears the memo so a later attempt can retry, rather than permanently disabling panoramas for the session). The underlying start is **injectable** (`start:` param) so idempotency/retry are unit-tested with a fake — the default builds + starts the real `InAppLocalhostServer`.

> **⚠ Verified gotcha (plan-gauntlet):** `InAppLocalhostServer(...)` throws
> *"A platform implementation for flutter_inappwebview has not been set"* when
> **constructed** in a headless `flutter_test` — and if it's constructed
> eagerly (a `final _server = InAppLocalhostServer(...)` field or a module-level
> `final panoramaServer = ...` that builds it), **importing this file crashes
> every test that transitively imports it** (including Task 6's webview test).
> The construction is therefore **deferred into the injectable `_defaultStart`
> function** (invoked only inside `ensureStarted`, never at import/construction),
> so (a) importing is safe, and (b) the platform failure becomes an
> **async-catchable** error the caller maps to the unavailable state. The `start`
> seam also lets the idempotency/retry tests use a fake. Verified: import-safe,
> idempotent, and retryable all green in `flutter_test`.

- [ ] **Step 1: Write the failing test** (import-safety + graceful failure — no real platform needed)

```dart
// test/widget/panorama_server_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/services/panorama_server.dart';
import 'package:aon2026/models/viewer_url_policy.dart';

void main() {
  test('import-safe: baseUrl works without constructing the real server', () {
    expect(panoramaServer.baseUrl, 'http://localhost:$kPanoramaServerPort');
    expect(panoramaServer.isRunning, isFalse);
  });

  test('idempotent: real start runs once across many/concurrent ensureStarted calls', () async {
    var starts = 0;
    final s = PanoramaServer(start: () async => starts++);
    await Future.wait([s.ensureStarted(), s.ensureStarted(), s.ensureStarted()]);
    await s.ensureStarted();
    expect(starts, 1);
    expect(s.isRunning, isTrue);
  });

  test('retryable: a failed start clears the memo so a later call retries', () async {
    var starts = 0;
    final s = PanoramaServer(start: () async {
      starts++;
      if (starts == 1) throw StateError('boom');
    });
    await s.ensureStarted().catchError((_) {});
    expect(s.isRunning, isFalse); // failed, but not permanently
    await s.ensureStarted();       // retries
    expect(starts, 2);
    expect(s.isRunning, isTrue);
  });
}
```

- [ ] **Step 2: Run — FAIL (undefined).**
- [ ] **Step 3: Implement** (single owner; **injectable + deferred start**; import-safe; idempotent + retryable)

```dart
// lib/services/panorama_server.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:aon2026/models/viewer_url_policy.dart';

/// Builds + starts the real localhost server. Constructs `InAppLocalhostServer`
/// only when CALLED (never at import) — keeping the module import-safe in tests.
Future<void> _defaultStart() =>
    InAppLocalhostServer(documentRoot: 'assets', port: kPanoramaServerPort).start();

/// Single, process-lifetime owner of the localhost asset server. Never closed
/// between routes. Start is idempotent (runs at most once) and retryable (a
/// failure clears the memo). [start] is injectable for unit tests.
class PanoramaServer {
  PanoramaServer({Future<void> Function()? start}) : _start = start ?? _defaultStart;
  final Future<void> Function() _start;
  Future<void>? _starting;
  bool _running = false;

  String get baseUrl => 'http://localhost:$kPanoramaServerPort';
  bool get isRunning => _running;

  Future<void> ensureStarted() {
    if (kIsWeb) return Future.value(); // web serves assets same-origin; no server
    if (_running) return Future.value();
    // async closure + try/catch (NOT .then(...).catchError): `_running = true`
    // in a .then arrow would type the future as Future<bool> and break the
    // rethrow — verified. This form is Future<void>, idempotent, and retryable.
    return _starting ??= () async {
      try {
        await _start();
        _running = true;
      } catch (_) {
        _starting = null; // retryable — do not permanently disable the session
        rethrow;
      }
    }();
  }
}

/// Import-safe: the constructor only stores the (default) start function; the
/// real `InAppLocalhostServer` is built lazily inside `_defaultStart` on first
/// non-web `ensureStarted()`.
final panoramaServer = PanoramaServer();
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

Port MQ's `indoor_webview.dart`, adapted to `panoramaServer` (Task 5), the pure `isAllowedViewerUrl` + bridge helpers (Task 1), the `reduceMotion` config (Task 2), inline strings, and an **explicit web policy**. The render is a platform view (on-device); the **real server-failure path** is tested via an **injected start function** (not a `forceUnavailable` teleport).

**Files:** Create `lib/widgets/panorama_web_view.dart`, `test/widget/panorama_web_view_test.dart`.

- [ ] **Step 1: Write the failing widget test — the REAL failure path (injected start throws → unavailable)**

```dart
// test/widget/panorama_web_view_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/models/indoor_manifest.dart';
import 'package:aon2026/widgets/panorama_web_view.dart';

void main() {
  testWidgets('server-start failure → unavailable state (real path), not a crash',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PanoramaWebView(
          manifest: IndoorManifest.fromJson('{"nodes":[{"id":"a","image":"indoor/a.jpg","neighbours":[]}]}'),
          // Inject the start seam so we exercise ensureServer throws → catch →
          // _serverFailed → unavailable UI (the true production failure path).
          ensureServer: () async => throw StateError('no platform'),
        ),
      ),
    ));
    await tester.pump(); // let the async start reject
    await tester.pump();
    expect(find.textContaining('unavailable'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run — FAIL (undefined).**
- [ ] **Step 3: Implement** — port `indoor_webview.dart` with these exact adaptations:
  - **Web is explicitly unavailable (matches the frozen design §9):** if `kIsWeb`, `build` returns the unavailable state immediately and **no server is started and no `InAppWebView` is constructed**. Delete MQ's web `_viewerBase`/same-origin branch entirely — `_viewerBase` is just `panoramaServer.baseUrl`.
  - **Injectable start seam:** constructor takes `Future<void> Function()? ensureServer` defaulting to `panoramaServer.ensureStarted`. In `initState` (non-web) call it inside `try/catch` → failure sets `_serverFailed`.
  - `shouldOverrideUrlLoading` → `return isAllowedViewerUrl(action.request.url) ? ALLOW : CANCEL;` with `useShouldOverrideUrlLoading: true`.
  - `onWebViewCreated` handler `sceneChanged` → `final id = validatedInboundScene(arguments.isEmpty ? null : arguments.first, widget.manifest.nodes.map((n)=>n.id).toSet()); if (id != null) { _currentSceneId = id; widget.onSceneChanged?.call(id); }` (delegates to the Task-1 tested validator).
  - `onLoadStop` → `controller.evaluateJavascript(source: buildLoadTourJs(widget.manifest.buildPannellumConfig(assetBaseUrl: '${panoramaServer.baseUrl}/data', firstSceneId: widget.firstSceneId, reduceMotion: MediaQuery.disableAnimationsOf(context))));` — uses the tested encoder + the reduced-motion config.
  - `selectScene` → `controller.evaluateJavascript(source: buildSelectSceneJs(sceneId));`.
  - Unavailable/loading → inline strings: `Text('360° preview unavailable')`.

- [ ] **Step 4: Run — PASS; analyze; commit.**

```bash
flutter test test/widget/panorama_web_view_test.dart && flutter analyze
git add lib/widgets/panorama_web_view.dart test/widget/panorama_web_view_test.dart
git commit -m "feat(panorama): webview host — server/policy wired, sceneChanged validated (SP1)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 7: scene rail + tour view (glass over the platform view)

Port MQ's `scene_rail.dart` + `indoor_tour_view.dart`, adapted to `GlassSurface(control, allowShader:false)` and inline strings. The render is on-device, but the **scene-state orchestration** (rail↔viewer sync) is the signature interaction and gets a **permanent test via a tiny injected viewer interface** — no real Pannellum needed.

**Files:** Create `lib/widgets/panorama_scene_rail.dart`, `lib/widgets/panorama_tour_view.dart`, `test/widget/panorama_scene_rail_test.dart`, `test/widget/panorama_tour_sync_test.dart`.

- [ ] **Step 1: Failing rail test** — pump `PanoramaSceneRail` with a 2-node manifest; assert 2 chips render and tapping one calls `onSceneSelected` with its id.
- [ ] **Step 2: Failing sync test** — `PanoramaTourView` takes an injectable `PanoramaViewer` interface (default = the real `PanoramaWebView`; a fake in the test). Assert **both directions**: tapping rail chip "b" calls `viewer.selectScene('b')`; the fake emitting `sceneChanged('a')` makes the rail's selected chip become "a". (Abstract the viewer to `abstract class PanoramaViewer { void selectScene(String id); }` + an `onSceneChanged` callback; `PanoramaWebView` implements it; the fake records/emits.)
- [ ] **Step 3: Run — FAIL.**
- [ ] **Step 4: Implement** — port `scene_rail.dart` (drop `kTabBarIslandClearance` → pass 0; SP1's panorama is a full-screen route with no tab bar; keep the collapsible index-scroll). Port `indoor_tour_view.dart` composing the viewer + `PanoramaSceneRail` + a `GlassSurface(control, allowShader:false)` title island (inline title). Wire the injectable viewer seam. `MqColors`→`AonColors`.
- [ ] **Step 5: Run — PASS; analyze; commit.**

```bash
git add lib/widgets/panorama_scene_rail.dart lib/widgets/panorama_tour_view.dart test/widget/panorama_scene_rail_test.dart test/widget/panorama_tour_sync_test.dart
git commit -m "feat(panorama): scene rail + tour view; rail<->viewer sync tested via injected viewer (SP1)

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

- [ ] **Step 2: Write the failing SP1 responsive/a11y test** — new `test/widget/panorama_responsive_test.dart`. Phase 5 made **TextScaler 2.0 an app-wide contract**; SP1's new Flutter surfaces must inherit it. For `MapModeToggle`, `PanoramaBuildingPicker` (incl. the long "Demo 360° — sample imagery, not this venue" flag), `PanoramaSceneRail`, and the **unavailable state**, at **320×568 and 414×896 × TextScaler 2.0**: `expect(tester.takeException(), isNull)` (no overflow). Also assert the toggle segments + tour cards have **≥56px** hit heights and a meaningful semantics label. (The native panorama pixels aren't widget-testable; the Flutter chrome around them is.)
- [ ] **Step 3: Run — FAIL.**
- [ ] **Step 4: Implement**
  - `map_mode_toggle.dart`: port MQ's `MapModeToggle` (rename `ar`→`panorama`; `MqColors`/`MqSpacing`→`AonColors`/`AonSpacing`; labels inline "Campus Map"/"360°"; keep `GlassSurface(control)`; ≥56px segment targets).
  - `panorama_building_picker.dart`: glass cards over the venue list. Availability from `venuesWithPanoramaProvider` (sync). Tour venues → tappable card + the **"Demo 360° — sample imagery, not this venue"** flag; others → "coming soon", non-tappable. **No auto-select** — always render the full list; tapping a tour card calls `onOpen(venueId)`. ≥56px targets, semantics labels, glass fallback ladder, and overflow-safe at 2.0 (Wrap/Flexible/ellipsis as needed).
- [ ] **Step 5: Run — PASS (picker + responsive); analyze; commit.**

```bash
git add lib/widgets/map_mode_toggle.dart lib/widgets/panorama_building_picker.dart test/widget/panorama_picker_test.dart test/widget/panorama_responsive_test.dart
git commit -m "feat(panorama): map toggle + picker; no auto-select, demo flag, 2.0/short-viewport + a11y coverage (SP1)

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

Must include: `viewer_url_policy` (narrow allow/deny), `webview_bridge` (hostile-input JS encoding + `sceneChanged` validation), `indoor_manifest` (config + SECURITY path-blanking + **reduced-motion**), `panorama_data` (exact lookup + bundle data-integrity), `viewer_html_isolation` (CSP + no external origins), `panorama_server` (**idempotent + retryable**, injected fake), `panorama_web_view` (**real** server-failure→unavailable via injected start), `panorama_scene_rail` + `panorama_tour_sync` (rail↔viewer both directions), `panorama_picker` (no auto-select + demo flag), `panorama_responsive` (**2.0 / 320×568 / ≥56px / semantics**), `panorama_route` (deep-link safety).

- [ ] **Platform build gate** — record `PASS / FAIL / NOT AVAILABLE`:

```bash
flutter build ios --simulator --debug
flutter build apk --debug
```

- [ ] **On-device iOS pass (best-effort, screenshotted):** Map → **360°** toggle → picker (one tour card with the demo flag + "coming soon" venues) → open the tour → it loads, pans, **hotspot-navigates between the 2 scenes**, and the **glass island stays legible over the WebView regardless of blur quality**; press back → returns to the picker (no loop). Confirm the **narrowed nav policy still lets the tour load** (if not, apply the Task-1 widen-to-`/web/` note). Force the unavailable state (`/panorama/<unknown>`) → safe back state, no crash. (Web: if built for web at all, the panorama shows the unavailable state.)

- [ ] **Security/provenance/content checks:** all the security/isolation tests green; deep-link to an unknown venue → unavailable state; **`docs/panorama-image-provenance.md` present and complete** (or owned/CC imagery substituted); **`assets/web/pannellum/LICENSE` present**; **no "Hadenfeld"/real-building text survives in `macquarie-theatre.json`**; asset budget ≤ ~8 MB.

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
| `lib/models/viewer_url_policy.dart`, `lib/models/webview_bridge.dart` | create (narrow URL policy + JS encoders + scene validation) | 1 |
| `lib/models/indoor_manifest.dart` | create (port + reduceMotion) | 2 |
| `lib/data/panorama_data.dart` | create (venue→tour, exact lookup) | 3 |
| `lib/services/providers.dart` | modify (2 providers) | 3 |
| `assets/web/…`, `assets/data/indoor/…`, `docs/panorama-image-provenance.md` | create (viewer + Pannellum + LICENSE + 1 tour + provenance) | 4 |
| `lib/services/panorama_server.dart` | create (single owner) | 5 |
| `lib/widgets/panorama_web_view.dart` | create (ported host) | 6 |
| `lib/widgets/panorama_scene_rail.dart`, `panorama_tour_view.dart` | create (ported, glass) | 7 |
| `lib/widgets/map_mode_toggle.dart`, `panorama_building_picker.dart` | create | 8 |
| `lib/screens/panorama_screen.dart` | create (immersive route) | 9 |
| `lib/app/router/app_router.dart` (route table + `Routes` class), `lib/screens/map_screen.dart` | modify (route + toggle entry) | 9 |
| `test/…` | create (~13 test files: url_policy, webview_bridge, indoor_manifest, panorama_data, viewer_html_isolation, panorama_server, panorama_web_view, panorama_scene_rail, panorama_tour_sync, panorama_picker, panorama_responsive, panorama_route) | 1–9 |
