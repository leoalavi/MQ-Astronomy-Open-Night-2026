# M3 — Buildings + Search + Favorites Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add MQ's 170-building registry + ranked search + local favorites to the campus map, reconciled with AON's 21 curated venues.

**Architecture:** A bundled `buildings.json` loads through an async `buildingsProvider`; venues stay always-on and buildings are search-only. Search state is three composed providers (query / index / results). Selection is a stable `PlaceKey` string. Buildings + curated-linked venues place pixel-exact via `projectPixel`; unlinked venues keep GPS-affine. Favorites use the passport persistence idiom (injected `SharedPreferencesAsync` snapshot, serialized writes).

**Tech Stack:** Flutter 3.44 · flutter_map 8.3.1 · Riverpod 3 (plain `Notifier`/`Provider`/`FutureProvider`) · `shared_preferences` (`SharedPreferencesAsync`) · gen-l10n (EN+FA).

**Design:** `docs/superpowers/specs/2026-08-16-aon-map-M3-buildings-search-design.md` — **read §0b (external-review amendment) and §0 first; both are authoritative and supersede the body where they conflict.**

## Gauntlet-2 amendment — AUTHORITATIVE (read before any task; supersedes the task bodies where they conflict)

A second external gauntlet found 31 plan-level issues (13 red). Verified each against the code; **all adopted**. The design is unchanged — these are implementation seams, false-positive tests, two real logic bugs, and lifecycle rules. Where this conflicts with a task below, **this wins.**

**Concrete logic bugs (fix in the task code):**
- **G1 — `projectPixel` uses STRICT bounds, no `_eps` (T2).** `_eps` on a fixed raster lets `x=-_eps/2` through → negative longitude. Use `if (x < 0 || x > _pw || y < 0 || y > _ph) return null;` (keep the `(0,0)` sentinel guard). Add exact-edge tests: `(0,1)` valid, `(_pw,0)` valid, `(0,_ph)` valid, `(-0.001,100)`/`(_pw+0.001,100)` null.
- **G2 — routing coords must be chosen as a PAIR (T1 Building AND T5 Venue).** `entranceLat ?? lat` mixed with `entranceLng ?? lng` can fabricate a coordinate that never existed. Both models: `bool get hasEntranceCoordinates => entranceLatitude != null && entranceLongitude != null;` then `routingLatitude => hasEntranceCoordinates ? entranceLatitude : latitude;` (same for lng). Fixes the *existing* `venue.dart:86` bug too. Add a partial-entrance regression test.
- **G3 — immutable lists (T1).** Wrap `aliases`/`searchTokens`/`tags` in `List.unmodifiable(...)` inside `fromJson`.

**Drop / simplify:**
- **G4 — drop `searchCampusBuildings` (T4).** It's unused: T6 ranks `SearchEntry`s directly. Keep only `scoreBuildingMatch`, and **normalize inside it** (`q = q.toLowerCase().trim()` at the top; empty → 0) so it has no "caller must pre-normalize" footgun. Remove T4's ordering test (ordering is proven in T6); keep the band-ladder test.

**Missing seams — define these (they were consumed but never produced):**
- **G5 — `placeResolverProvider` (NEW, define in T6) + ONE shared placement helper.** `enum PlaceKind { venue, building }`; `class ResolvedPlace { PlaceKind kind; String placeKey; String title; String? subtitle; CampusMapPoint? renderPoint; double? routingLat, routingLng; }`. `final placeResolverProvider = Provider.family<AsyncValue<ResolvedPlace?>, String>((ref, key) …)`. Contract: `venue:<id>` → `AsyncData(resolved)` synchronously (venues are const); `building:<id>` → follows `buildingsProvider` (`AsyncLoading` → `AsyncData(place)` or `AsyncData(null)` if absent after load); malformed/unknown key → `AsyncData(null)`.
  - **G5a — single source of placement truth (fixes a drift risk):** both `placeResolver.renderPoint` (G5) AND the idle marker builder (G14) MUST use one helper, `lib/services/map_placement.dart`:
    ```dart
    CampusMapPoint? placeVenue(Venue v, CampusProjection p) =>
        (v.buildingId != null && v.campusX != null && v.campusY != null)
            ? p.projectPixel(v.campusX!, v.campusY!)                        // linked → pixel-exact
            : (v.hasCoordinates ? p.project(GpsPoint(LatLng(v.latitude!, v.longitude!))) : null);
    CampusMapPoint? placeBuilding(Building b, CampusProjection p) =>
        b.hasCampusCoordinates ? p.projectPixel(b.campusX!, b.campusY!) : null;
    ```
    Unit-test the helper directly (linked→pixel, unlinked→affine, no-coord→null); G14's map test then just asserts the rendered marker uses it. `routingLat/Lng` per §0b.E (M4 consumes; M3 only populates). T9/T10 consume `placeResolverProvider`.
- **G6 — buildings bundle seam (T3).** Add `final buildingsBundleProvider = Provider<AssetBundle>((_) => rootBundle);`; `buildingsProvider` reads `ref.watch(buildingsBundleProvider)`. Failure test overrides it with a bundle returning malformed JSON → asserts `buildingsProvider` value is `[]`, does not throw, and venue search still works.
- **G7 — favorites `eventId` (T7).** `SharedPrefsFavoritesStore({required SharedPreferencesAsync prefs, required String eventId})`; `eventId` comes from `ref.watch(eventConfigProvider).id` (= `'aon-2026'`, the `saved_events` pattern). Keys: `map_favorites.buildings.v1` (global) + `map_favorites.venues.$eventId`.

**False-positive tests — make them real:**
- **G8 — favorites race (T7) uses `Completer`s, not `sleep`.** Store `save` blocks on a test-controlled `Completer`; request 3 toggles; release; **`await controller.flush()`**; assert persisted `{venue:b}`. Add **G9 — `Future<void> flush()`** on the controller (awaits the serialized save chain) so tests are deterministic — no `Future.delayed`.
- **G10 — async search (T6) is deterministic.** Override `buildingsProvider` with a `Completer<List<Building>>`; assert: query `OBS` while incomplete → no building vocab / building entry absent; complete the registry (query unchanged) → `venue:astronomical-observatory` appears. No reliance on real-asset timing.
- **G11 — ordering test actually asserts order (T6).** Equal-score Venue/Building tie → assert `placeKey`-lexical order; assert a band-interleaving sequence. **G12 — exact links (T5):** assert the full 7-entry `venue→building` map AND `linked.length == 7` (not `>= 7`). **G13 — non-match contract (T4):** `scoreBuildingMatch(anything, 'zzznomatch') == 0` (explicit).

**Lifecycle & UI (define + test):**
- **G14 — linked-venue IDLE placement is wired + tested (T10).** The always-on venue marker builder MUST place each venue via `placeVenue(v, _proj)` (the G5a shared helper) — not an inline branch. Regression: the `astronomical-observatory` marker point `== projectPixel(1745,480)`; an unlinked venue's `== project(GPS)`.
- **G15 — selection clears on detail-sheet close (T10).** Orchestration: `set selectedPlaceKey → center → await showModalBottomSheet(...) → clear selectedPlaceKey`. Test: after the sheet closes, the transient building marker / venue decoration is gone.
- **G16 — search query clears on sheet close (T9).** The `TextField` seeds from `mapSearchQueryProvider`; closing the sheet resets the query to `''`. Test open→type→close→reopen shows empty.
- **G17 — `context.mounted` guard (T10).** After `final key = await showModalBottomSheet<String>(...)`, `if (key == null || !context.mounted) return;` — else `use_build_context_synchronously` reddens `flutter analyze` (a `check.sh` gate).
- **G18 — concrete control geometry (T10).** One **top-left vertical control column** stacking, top→down: Layers (M2), Search, Favorites — each `minTapTarget`, spaced `space2`, wrapped in the same glass style as the M2 Layers button. Status notes clear it via `left: space4 + minTapTarget` (already so). No new independent magic positions.
- **G19 — nested-scroll fix (T9).** Search/Favorites sheets: `SafeArea > Column(header, Expanded(ListView(...)))` — NOT `ListView` inside `SingleChildScrollView`. Building sheet (small) keeps `SingleChildScrollView`.

**Process / provenance / claims:**
- **G20 — T0 is a vendoring precondition, split red/green (T0).** T0a: write an **asset-registration test** (`rootBundle.loadString(buildingsAssetPath)` succeeds + parses to 170) → run RED (before pubspec declares it) → vendor + declare → GREEN. The `File(...)` invariant tests are data checks that run after. (The `File` test does NOT prove pubspec registration; the `rootBundle` one does.)
- **G21 — provenance actually gates + is permanent.** Chain the SHA check with `&&` into the commit (`test … && ./scripts/check.sh && git add … && git commit …`), AND add a provenance step to `scripts/check.sh` (recompute `shasum -a 256 assets/data/buildings.json`, compare to `docs/fixtures/buildings_provenance.json`) so every later task + closeout revalidates it.
- **G22 — no literal placeholders in the asset (T0).** Generate `buildings_provenance.json` via heredoc substituting `$SHA`/`$SRCCOMMIT` (not `<SHA>`). Soften the licence line to an honest IOU: *"vendored from the MQ_Journey sibling project; confirm redistribution permission before any public/store release"* — do not assert permission we can't evidence.
- **G23 — the `21` invariant is authoritative (T0).** Remove the "update if eps shifts" self-permission. `misses == 21` is a regression receipt; a failure means investigate, not edit.
- **G24 — l10n enumerated (T8).** Add all **13** `BuildingCategory` label keys (`mapCat<Name>`), plus `mapFavoritesLoading`, `mapFavoriteUnavailable`, `mapSearchTooltip`, `mapFavoritesTooltip`, and (only if `saveFailed` is surfaced) `mapFavoritesSaveFailed` — with **real Persian** in the plan, like M2.
- **G25 — `saveFailed` semantics (T7):** set `true` when a `save` throws; reset to `false` on the next successful save; a load failure yields empty favorites + `saveFailed=false` (load ≠ save). `FavoritesStore.save` wraps `SharedPreferencesAsync.setStringList` (returns `Future<void>`) in try/catch → `Future<bool>`. M3 does not surface `saveFailed` in UI (favorites are non-critical) unless G24's key is added.
- **G26 — headings + self-review honesty.** T11 heading → "**iOS Simulator smoke test**". Self-review: drop "**No gap**" and "every code step complete" — state instead that G5/G7/G15/G16 seams are now defined, and that vendoring/`Step 2–4 implement` steps are engineering notes, not literal code. **Routing authority is M4's**, not M3's: M3 exposes `routingLatitude/Longitude` on the models (G2) but does NOT wire/test the Directions target — remove routing from M3's "covered" list; the authority *rule* + test live in M4.

## Global Constraints

- **Async registry, synchronous placement.** `buildingsProvider` is `FutureProvider`; the 21 venue markers + any linked-venue placement must NOT wait on it (linked venues carry curated `campusX/Y` baked onto the Venue). Registry drives search vocab + dedup only.
- **Authority axes (§0b.E):** semantic = curated venue wins on link; render = `projectPixel` (pixel-exact) for buildings + linked venues, GPS-affine `project()` for unlinked venues. **Routing authority is M4's** — M3 only exposes paired `routingLatitude/Longitude` (G2) on the models; it does not wire/test a Directions target.
- **Selection identity is a `PlaceKey` string** (`venue:<id>` / `building:<id>`), never a long-lived `SearchEntry`.
- **Search providers are split:** `mapSearchQueryProvider` (Notifier<String>) / `searchIndexProvider` (derived, AsyncValue) / `mapSearchResultsProvider` (derived).
- **Favorites:** passport idiom (injected snapshot + `SharedPreferencesAsync`), serialized latest-state writes, never prune keys on transient loading, **event-scoped venue namespace** vs **global building namespace**.
- **No new dependency.** New asset `assets/data/buildings.json` in `pubspec.yaml`; web build stays a gate; EN+FA for every new string; `context.aon` chrome; 320×568/2.0; TDD; `./scripts/check.sh` green before every commit.
- **Never weaken an existing test.** Full suite + M1/M2 map behaviour stay green.

---

### Task 0: Vendor `buildings.json` + provenance + raw-data invariants

**Files:**
- Create: `assets/data/buildings.json` (copied from MQ), declared in `pubspec.yaml` under `assets:`.
- Create: `docs/fixtures/buildings_provenance.json` (source repo/path, source commit, SHA-256, licence note).
- Test: `test/unit/buildings_asset_integrity_test.dart`.

**Interfaces:** Produces the vendored asset + provenance fixture. No Dart model yet — tests parse raw JSON + reuse the existing `CampusProjection.project`.

- [ ] **Step 1: Vendor the asset + provenance, declare in pubspec**

```bash
cp /Users/raoof.r12/Desktop/Raouf/MQ_Journey/assets/data/buildings.json \
   /Users/raoof.r12/Desktop/Raouf/MQ-Astronomy-Open-Night-2026/assets/data/buildings.json
cd /Users/raoof.r12/Desktop/Raouf/MQ-Astronomy-Open-Night-2026
SHA=$(shasum -a 256 assets/data/buildings.json | awk '{print $1}')
SRCCOMMIT=$(git -C /Users/raoof.r12/Desktop/Raouf/MQ_Journey rev-parse HEAD)
```
Write `docs/fixtures/buildings_provenance.json`:
```json
{
  "source_repo": "MQ_Journey",
  "source_path": "assets/data/buildings.json",
  "source_commit": "<SRCCOMMIT>",
  "sha256": "<SHA>",
  "record_count": 170,
  "licence": "Macquarie University campus data, vendored with permission for the AON2026 event app (same provenance as campus_overlay_meta.json).",
  "vendored_on": "2026-08-16"
}
```
Add to `pubspec.yaml` `flutter: assets:` list: `    - assets/data/buildings.json`.

- [ ] **Step 2: Write the failing invariant tests**

```dart
// test/unit/buildings_asset_integrity_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:aon2026/models/campus_geometry.dart';
import 'package:aon2026/services/campus_projection.dart';

// NOTE: the asset uses 'teaching' (13 distinct categories), which MQ's own enum
// lacked → MQ silently maps it to 'other'. We add 'teaching' so no data is lost
// (finding #14). Keep this set in lock-step with BuildingCategory.
const _known = {
  'academic','services','health','food','sports','venue','research',
  'residential','parking','transport','smoking','teaching','other',
};

List<Map<String, dynamic>> _load() {
  final raw = File('assets/data/buildings.json').readAsStringSync();
  return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
}

void main() {
  final data = _load();
  const proj = CampusProjection();

  test('exactly 170 records', () => expect(data.length, 170));

  test('ids unique + non-empty; name/code non-empty', () {
    final ids = <String>{};
    for (final b in data) {
      final id = b['id'] as String;
      expect(id.trim(), isNotEmpty);
      expect(ids.add(id), isTrue, reason: 'duplicate id: $id');
      expect((b['name'] as String).trim(), isNotEmpty, reason: id);
      expect((b['code'] as String).trim(), isNotEmpty, reason: id);
    }
  });

  test('every campusX/Y within [0,4678]x[0,3307], none is the (0,0) sentinel', () {
    for (final b in data) {
      final x = (b['campusX'] as num).toDouble(), y = (b['campusY'] as num).toDouble();
      expect(x, inInclusiveRange(0, 4678), reason: b['id'] as String);
      expect(y, inInclusiveRange(0, 3307), reason: b['id'] as String);
      expect(x == 0 && y == 0, isFalse, reason: '${b['id']} is (0,0) sentinel');
    }
  });

  test('every raw category string is a known enum value (catches typos)', () {
    for (final b in data) {
      expect(_known.contains(b['category']), isTrue,
          reason: 'unknown category "${b['category']}" on ${b['id']}');
    }
  });

  test('exactly 21 buildings fall outside the GPS-affine domain '
      '(justifies pixel-exact necessity)', () {
    var misses = 0;
    for (final b in data) {
      final p = proj.project(GpsPoint(
          LatLng((b['latitude'] as num).toDouble(), (b['longitude'] as num).toDouble())));
      if (p == null) misses++;
    }
    expect(misses, greaterThan(0)); // hard requirement: pixel path is NECESSARY
    expect(misses, 21);             // receipt (python-derived); if the Dart eps
    // shifts it by 1, update to the real count — the >0 assertion is the contract.
  });
}
```
The SHA-256 provenance match is the shell step in Step 4, not an in-Dart assertion — no `crypto` import.

- [ ] **Step 3: Run tests to verify they fail, then pass**

Run: `flutter test test/unit/buildings_asset_integrity_test.dart`
Expected: FAILS if the asset/pubspec isn't wired; once Step 1 is done, PASSES.

- [ ] **Step 4: Provenance SHA drift check + gate + commit**

```bash
test "$(shasum -a 256 assets/data/buildings.json | awk '{print $1}')" = "$(python3 -c "import json;print(json.load(open('docs/fixtures/buildings_provenance.json'))['sha256'])")" && echo "PROVENANCE OK"
./scripts/check.sh && \
git add assets/data/buildings.json docs/fixtures/buildings_provenance.json pubspec.yaml test/unit/buildings_asset_integrity_test.dart && \
git commit -m "feat(map): M3 T0 — vendor buildings.json (170) + provenance + data invariants"
```

---

### Task 1: `Building` model + `BuildingCategory` + `fromJson`

**Files:** Create `lib/models/building.dart`; Test `test/unit/building_model_test.dart`.

**Interfaces:**
- Produces: `enum BuildingCategory { academic, services, health, food, sports, venue, research, residential, parking, transport, smoking, teaching, other }
// 'teaching' IS present in buildings.json (13 distinct categories); include it so
// no building silently degrades to `other` (finding #14).` with `static BuildingCategory fromString(String?)` (→ other); `class Building` (fields per design §4) with `factory Building.fromJson(Map<String,dynamic>)`, getters `routingLatitude/Longitude` (entrance ?? centre), `hasCampusCoordinates`, `hasGeographicCoordinates`, `==`/`hashCode` by `id`.

- [ ] **Step 1: Write the failing model test**

```dart
// test/unit/building_model_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/models/building.dart';

void main() {
  test('fromJson (flat) parses core fields', () {
    final b = Building.fromJson(const {
      'id': '18WW', 'code': '18WW', 'name': "18 Wally's Walk",
      'category': 'services', 'latitude': -33.7739781, 'longitude': 151.1126116,
      'entranceLatitude': -33.77388, 'entranceLongitude': 151.11275,
      'campusX': 2281, 'campusY': 1882, 'gridRef': 'N16',
      'aliases': ['Tech Bar'], 'searchTokens': ['it help'], 'tags': ['services'],
    });
    expect(b.id, '18WW');
    expect(b.category, BuildingCategory.services);
    expect(b.campusX, 2281);
    expect(b.routingLatitude, -33.77388); // entrance wins
    expect(b.hasCampusCoordinates, isTrue);
  });

  test('fromJson (nested) tolerates location/campusLocation', () {
    final b = Building.fromJson(const {
      'id': 'X', 'code': 'X', 'name': 'X', 'category': 'other',
      'location': {'lat': -33.77, 'lng': 151.11},
      'campusLocation': {'x': 100, 'y': 200},
    });
    expect(b.latitude, -33.77);
    expect(b.campusX, 100);
  });

  test('unknown category → other; equality by id', () {
    expect(BuildingCategory.fromString('nope'), BuildingCategory.other);
    expect(BuildingCategory.fromString(null), BuildingCategory.other);
    expect(Building.fromJson(const {'id': 'A', 'code': 'A', 'name': 'A', 'category': 'other'}),
        Building.fromJson(const {'id': 'A', 'code': 'A2', 'name': 'A2', 'category': 'food'}));
  });

  test('the vendored asset parses to 170 Buildings, all campus-placeable', () {
    final data = (jsonDecode(File('assets/data/buildings.json').readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();
    final built = data.map(Building.fromJson).toList();
    expect(built.length, 170);
    expect(built.every((b) => b.hasCampusCoordinates), isTrue);
  });
}
```

- [ ] **Step 2: Run → fail** (`flutter test test/unit/building_model_test.dart` — no `building.dart`).

- [ ] **Step 3: Implement `lib/models/building.dart`**

```dart
import 'package:flutter/foundation.dart';

enum BuildingCategory {
  academic, services, health, food, sports, venue, research,
  residential, parking, transport, smoking, teaching, other;  // 'teaching' is in the asset (#14)

  static BuildingCategory fromString(String? s) =>
      BuildingCategory.values.firstWhere((c) => c.name == s,
          orElse: () => BuildingCategory.other);
}

@immutable
class Building {
  const Building({
    required this.id, required this.code, required this.name,
    this.description, this.address, this.category = BuildingCategory.other,
    this.latitude, this.longitude, this.entranceLatitude, this.entranceLongitude,
    this.campusX, this.campusY, this.gridRef,
    this.aliases = const [], this.searchTokens = const [], this.tags = const [],
  });

  final String id, code, name;
  final String? description, address, gridRef;
  final BuildingCategory category;
  final double? latitude, longitude, entranceLatitude, entranceLongitude, campusX, campusY;
  final List<String> aliases, searchTokens, tags;

  // G2: entrance is used ONLY when the PAIR is present, else fall back to the
  // centre pair — never mix entrance-lat with centre-lng (fabricated coordinate).
  bool get hasEntranceCoordinates =>
      entranceLatitude != null && entranceLongitude != null;
  double? get routingLatitude => hasEntranceCoordinates ? entranceLatitude : latitude;
  double? get routingLongitude => hasEntranceCoordinates ? entranceLongitude : longitude;
  bool get hasGeographicCoordinates => latitude != null && longitude != null;
  bool get hasCampusCoordinates =>
      campusX != null && campusY != null && !(campusX == 0 && campusY == 0);

  factory Building.fromJson(Map<String, dynamic> j) {
    double? d(Object? v) => v == null ? null : (v as num).toDouble();
    final loc = j['location'] as Map<String, dynamic>?;
    final ent = j['entranceLocation'] as Map<String, dynamic>?;
    final camp = j['campusLocation'] as Map<String, dynamic>?;
    List<String> ls(Object? v) =>
        List.unmodifiable((v as List?)?.cast<String>() ?? const []); // G3
    return Building(
      id: j['id'] as String, code: j['code'] as String, name: j['name'] as String,
      description: j['description'] as String?, address: j['address'] as String?,
      category: BuildingCategory.fromString(j['category'] as String?),
      latitude: d(j['latitude'] ?? loc?['lat']),
      longitude: d(j['longitude'] ?? loc?['lng']),
      entranceLatitude: d(j['entranceLatitude'] ?? ent?['lat']),
      entranceLongitude: d(j['entranceLongitude'] ?? ent?['lng']),
      campusX: d(j['campusX'] ?? camp?['x']),
      campusY: d(j['campusY'] ?? camp?['y']),
      gridRef: j['gridRef'] as String?,
      aliases: ls(j['aliases']), searchTokens: ls(j['searchTokens']), tags: ls(j['tags']),
    );
  }

  @override
  bool operator ==(Object other) => other is Building && other.id == id;
  @override
  int get hashCode => id.hashCode;
}
```

- [ ] **Step 4: Run → pass.** `flutter test test/unit/building_model_test.dart`
- [ ] **Step 5: `./scripts/check.sh && git add … && git commit -m "feat(map): M3 T1 — Building model + tolerant fromJson"`**

---

### Task 2: `projectPixel` on `CampusProjection`

**Files:** Modify `lib/services/campus_projection.dart`; Test `test/unit/campus_projection_pixel_test.dart`.

**Interfaces:**
- Consumes: existing `_pw/_ph/_scale`, `CampusMapPoint`.
- Produces: `CampusMapPoint? projectPixel(double x, double y)` — `null` outside `[0,_pw]×[0,_ph]` or on the `(0,0)` sentinel; else `CampusMapPoint(LatLng((_ph - y)/_scale, x/_scale))`.

- [ ] **Step 1: Write the failing test**

```dart
// test/unit/campus_projection_pixel_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/models/building.dart';
import 'package:aon2026/services/campus_projection.dart';

void main() {
  const p = CampusProjection();

  test('18WW pixel (2281,1882) → map (36.63, 58.63) [receipt]', () {
    final m = p.projectPixel(2281, 1882)!;
    expect(m.value.latitude, closeTo(36.63, 0.05));
    expect(m.value.longitude, closeTo(58.63, 0.05));
  });

  test('(0,0) sentinel and out-of-range → null; exact edges valid (G1 strict)', () {
    expect(p.projectPixel(0, 0), isNull);       // sentinel
    expect(p.projectPixel(-0.001, 100), isNull); // just under 0 → null (no _eps slack)
    expect(p.projectPixel(4678.001, 100), isNull);
    expect(p.projectPixel(0, 1), isNotNull);    // exact edges valid
    expect(p.projectPixel(4678, 0), isNotNull);
    expect(p.projectPixel(0, 3307), isNotNull);
  });

  test('ALL 170 buildings projectPixel successfully (necessity of pixel path)', () {
    final data = (jsonDecode(File('assets/data/buildings.json').readAsStringSync()) as List)
        .cast<Map<String, dynamic>>().map(Building.fromJson);
    for (final b in data) {
      expect(p.projectPixel(b.campusX!, b.campusY!), isNotNull, reason: b.id);
    }
  });
}
```

- [ ] **Step 2: Run → fail** (no `projectPixel`).

- [ ] **Step 3: Add the method** (after `project`, before `canProject`)

```dart
  /// Pixel-exact placement for MQ building `campusX/Y`, which live in the same
  /// 4678x3307 calibration space as [project]'s internal pixel step. NEVER
  /// clamps: null outside the raster or on the (0,0) "no campus coords" sentinel.
  CampusMapPoint? projectPixel(double x, double y) {
    if (x == 0 && y == 0) return null;             // "no campus coords" sentinel
    if (x < 0 || x > _pw || y < 0 || y > _ph) return null; // STRICT raster bounds (G1: no _eps)
    return CampusMapPoint(LatLng((_ph - y) / _scale, x / _scale)); // Y-flip, same as project
  }
```

- [ ] **Step 4: Run → pass.**
- [ ] **Step 5: `./scripts/check.sh && git commit -m "feat(map): M3 T2 — CampusProjection.projectPixel (pixel-exact building placement)"`**

---

### Task 3: Buildings asset loader + `buildingsProvider`

**Files:** Create `lib/data/buildings_asset.dart`, `lib/services/building_providers.dart`; Test `test/unit/buildings_provider_test.dart`.

**Interfaces:**
- Produces: `Future<List<Building>> loadBuildings(AssetBundle bundle)`; `final buildingsProvider = FutureProvider<List<Building>>(...)` reading `rootBundle` (decode failure → `[]`, logged, non-fatal).

- [ ] **Step 1: Failing test**

```dart
// test/unit/buildings_provider_test.dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/data/buildings_asset.dart';
import 'package:aon2026/services/building_providers.dart';

void main() {
  // testWidgets (not plain test) so rootBundle is backed by the test asset
  // bundle — the pattern proven by M2's campus_variant_assets_test.
  testWidgets('loadBuildings parses the bundled asset to 170', (t) async {
    final list = await loadBuildings(rootBundle);
    expect(list.length, 170);
  });

  testWidgets('buildingsProvider resolves to 170', (t) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final list = await c.read(buildingsProvider.future);
    expect(list.length, 170);
  });
}
```

- [ ] **Step 2: Run → fail.**
- [ ] **Step 3: Implement**

```dart
// lib/data/buildings_asset.dart
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:aon2026/models/building.dart';

const String buildingsAssetPath = 'assets/data/buildings.json';

Future<List<Building>> loadBuildings(AssetBundle bundle) async {
  final raw = await bundle.loadString(buildingsAssetPath);
  final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  return list.map(Building.fromJson).toList(growable: false);
}
```
```dart
// lib/services/building_providers.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/data/buildings_asset.dart';
import 'package:aon2026/models/building.dart';

/// Async campus building registry (170). A decode failure yields an empty list
/// (search still works over venues) — never a fatal error / blank map.
final buildingsProvider = FutureProvider<List<Building>>((ref) async {
  try {
    return await loadBuildings(rootBundle);
  } catch (e, s) {
    debugPrint('buildings.json load failed: $e\n$s');
    return const <Building>[];
  }
});
```

- [ ] **Step 4: Run → pass.**
- [ ] **Step 5: `./scripts/check.sh && git commit -m "feat(map): M3 T3 — buildingsProvider (async registry, non-fatal)"`**

---

### Task 4: Pure ranked search scorer

**Files:** Create `lib/services/building_search.dart`; Test `test/unit/building_search_test.dart`.

**Interfaces:**
- Produces: `String normalizeMapSearch(String)`; `int scoreBuildingMatch(Building, String rawQuery)` (bands 120/110/100/90/80/70/50/0; **normalizes internally**, G4). Pure — no Flutter import beyond the model. (`searchCampusBuildings` is NOT produced — dropped as unused; T6 ranks entries.)

- [ ] **Step 1: Failing test** (ported band vectors)

```dart
// test/unit/building_search_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/models/building.dart';
import 'package:aon2026/services/building_search.dart';

Building _b(String id, {String? code, String? name, List<String> aliases = const [], List<String> tokens = const []}) =>
    Building(id: id, code: code ?? id, name: name ?? id, aliases: aliases, searchTokens: tokens);

void main() {
  test('band ladder', () {
    final lib = _b('LIB', name: 'Library', aliases: ['books'], tokens: ['study']);
    expect(scoreBuildingMatch(lib, 'lib'), 120);        // id exact
    expect(scoreBuildingMatch(lib, 'books'), 110);      // alias exact
    expect(scoreBuildingMatch(lib, 'library'), 100);    // field exact
    expect(scoreBuildingMatch(lib, 'li'), 90);          // id prefix
    expect(scoreBuildingMatch(lib, 'boo'), 80);         // alias prefix
    expect(scoreBuildingMatch(lib, 'libr'), 70);        // 'lib' can't prefix 'libr'; 'library' field-prefix → 70
    expect(scoreBuildingMatch(lib, 'rary'), 50);        // contains
    expect(scoreBuildingMatch(lib, 'zzznomatch'), 0);   // G13: explicit non-match → 0
  });

  test('G4: normalizes internally — raw "  LIB  " scores like "lib"', () {
    expect(scoreBuildingMatch(_b('LIB', name: 'Library'), '  LIB  '), 120);
  });
  // Ranked ORDERING is proven in T6 (mapSearchResultsProvider), not here.
}
```

- [ ] **Step 2: Run → fail.**
- [ ] **Step 3: Port the scorer** (verbatim semantics from MQ `building_search.dart`)

```dart
// lib/services/building_search.dart
import 'package:aon2026/models/building.dart';

String normalizeMapSearch(String value) => value.toLowerCase().trim();

// G4: normalizes internally (no "caller must pre-normalize" footgun). searchCampus-
// Buildings dropped — T6's results provider ranks SearchEntries directly.
int scoreBuildingMatch(Building b, String rawQuery) {
  final q = normalizeMapSearch(rawQuery);
  if (q.isEmpty) return 0;
  final fields = <String>[
    b.id, b.code, b.name,
    if (b.description != null) b.description!,
    if (b.gridRef != null) b.gridRef!,
    if (b.address != null) b.address!,
    ...b.aliases, ...b.searchTokens, ...b.tags,
  ].map((s) => s.toLowerCase()).toList();
  final aliases = [...b.aliases, ...b.searchTokens].map((s) => s.toLowerCase()).toList();
  final id = b.id.toLowerCase();

  if (id == q) return 120;
  if (aliases.any((a) => a == q)) return 110;
  if (fields.any((f) => f == q)) return 100;
  if (id.startsWith(q)) return 90;
  if (aliases.any((a) => a.startsWith(q))) return 80;
  if (fields.any((f) => f.startsWith(q))) return 70;
  if (fields.any((f) => f.contains(q))) return 50;
  return 0;
}
```

- [ ] **Step 4: Run → pass.**
- [ ] **Step 5: `./scripts/check.sh && git commit -m "feat(map): M3 T4 — ported ranked search scorer (pure)"`**

---

### Task 5: `Venue.buildingId` + curated links + baked `campusX/Y` + integrity/drift

**Files:** Modify `lib/models/venue.dart` (+ `lib/data/venues_data.dart` for the 7 links); Test `test/unit/venue_building_links_test.dart`.

**Interfaces:**
- Produces on `Venue`: `final String? buildingId; final double? campusX, campusY;` (all default null); getter `bool get hasCampusCoordinates`.
- Curated links (seed, verified against `buildings.json` by the drift test): `macquarie-theatre→MQTH(2140,1954)`, `1-central-courtyard→1CC(2547,1618)`, `11-wallys-walk→11WW(2987,1937)`, `17-wallys-walk→17WW(2516,1883)`, `sport-and-aquatic-centre→SPORT(1637,1289)`, `astronomical-observatory→OBS(1745,480)`, `14-sir-christopher-ondaatje-avenue→14SCO(2766,1761)`. (Ambiguous/sub-space venues stay unlinked.)

- [ ] **Step 1: Failing integrity + drift test**

```dart
// test/unit/venue_building_links_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/data/venues_data.dart';
import 'package:aon2026/models/building.dart';

void main() {
  final buildingsById = {
    for (final b in (jsonDecode(File('assets/data/buildings.json').readAsStringSync()) as List)
        .cast<Map<String, dynamic>>().map(Building.fromJson))
      b.id: b
  };
  final linked = VenuesData.all.where((v) => v.buildingId != null).toList();

  test('every buildingId resolves to exactly one Building', () {
    for (final v in linked) {
      expect(buildingsById.containsKey(v.buildingId), isTrue, reason: '${v.id}→${v.buildingId}');
    }
  });

  test('one venue ↔ one building (no building linked twice)', () {
    final ids = linked.map((v) => v.buildingId).toList();
    expect(ids.toSet().length, ids.length, reason: 'a building is linked by two venues');
  });

  test('drift: each linked venue campusX/Y == its building campusX/Y', () {
    for (final v in linked) {
      final b = buildingsById[v.buildingId]!;
      expect(v.campusX, b.campusX, reason: '${v.id} campusX drifted from ${b.id}');
      expect(v.campusY, b.campusY, reason: '${v.id} campusY drifted from ${b.id}');
    }
  });

  test('at least the 7 seed links exist', () => expect(linked.length, greaterThanOrEqualTo(7)));
}
```

- [ ] **Step 2: Run → fail** (Venue has no `buildingId`).
- [ ] **Step 3:** Add `buildingId`, `campusX`, `campusY` (nullable, default null) + `hasCampusCoordinates` to `Venue`; set them on the 7 linked venues in `venues_data.dart` (copy `campusX/Y` from the buildings above). Do NOT touch unlinked venues.
- [ ] **Step 4: Run → pass** (drift test guarantees the baked coords match the asset).
- [ ] **Step 5: `./scripts/check.sh && git commit -m "feat(map): M3 T5 — venue↔building links + baked campusX/Y (drift-tested)"`**

---

### Task 6: `SearchEntry` + unified index + query/results providers

**Files:** Create `lib/models/search_entry.dart`, `lib/services/search_providers.dart`; Test `test/unit/search_index_test.dart`.

**Interfaces:**
- Produces: `sealed class SearchEntry { String get placeKey; String get title; String? get subtitle; }`, `VenueEntry`, `BuildingEntry`; `int scoreEntry(SearchEntry, String q, {Building? linkedBuilding})`; providers `mapSearchQueryProvider` (`NotifierProvider<MapSearchQuery, String>` with `void setQuery(String)` — a method, matching AON's `EventFilterNotifier.setQuery`/`SelectedIdNotifier.select` idiom; do NOT set `.state` externally), `searchIndexProvider` (`Provider<AsyncValue<List<SearchEntry>>>`), `mapSearchResultsProvider` (`Provider<List<SearchEntry>>`).

**Design notes for the implementer:**
- `placeKey` = `venue:<id>` / `building:<id>`.
- **Dedup:** build the index from venues (always) + buildings (when loaded); drop any `BuildingEntry` whose `id` equals some `Venue.buildingId`.
- **Vocab inheritance (§0b.B):** a `VenueEntry` for a *linked* venue scores `max(scoreVenueFields(v,q), scoreBuildingMatch(linkedBuilding,q))`.
- **Venue field scoring** reuses the band logic over `[id?, name, building?, address?, mapReference?, ...aliases]` (venue has no code/searchTokens/tags).
- **Comparator:** score desc, then `placeKey` asc. Empty query → first 15 by `placeKey` asc. Non-empty → `score>0`, sorted, capped at 15.
- `searchIndexProvider` returns `AsyncValue` — `AsyncData(venues-only)` while `buildingsProvider` is loading (so search works instantly), folding buildings in on `AsyncData`.

- [ ] **Step 1: Failing tests**

```dart
// test/unit/search_index_test.dart  (key cases — implementer adds the rest)
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/services/building_providers.dart';
import 'package:aon2026/services/search_providers.dart';
import 'package:aon2026/models/search_entry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('venues-only before buildings load; folds buildings in after', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final loading = c.read(searchIndexProvider); // buildings still loading
    expect(loading.hasValue, isTrue);
    expect(loading.value!.whereType<BuildingEntry>(), isEmpty);
    await c.read(buildingsProvider.future);
    final loaded = c.read(searchIndexProvider);
    expect(loaded.value!.whereType<BuildingEntry>(), isNotEmpty);
  });

  test('linked building is deduped (venue wins) but search still finds it by code', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(buildingsProvider.future);
    c.read(mapSearchQueryProvider.notifier).setQuery('OBS'); // building code for observatory
    final results = c.read(mapSearchResultsProvider);
    // no BuildingEntry with id OBS (deduped); the venue entry surfaces instead
    expect(results.whereType<BuildingEntry>().any((e) => e.placeKey == 'building:OBS'), isFalse);
    expect(results.any((e) => e.placeKey == 'venue:astronomical-observatory'), isTrue);
  });

  test('idle cap 15; non-empty filters score>0; deterministic order', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(buildingsProvider.future);
    c.read(mapSearchQueryProvider.notifier).setQuery('');
    expect(c.read(mapSearchResultsProvider).length, 15);
    c.read(mapSearchQueryProvider.notifier).setQuery('zzzznomatch');
    expect(c.read(mapSearchResultsProvider), isEmpty);
  });
}
```
Note: tests drive the query via the `setQuery(String)` method (AON idiom — `EventFilterNotifier.setQuery`/`SelectedIdNotifier.select`), never by setting `.state` externally.

- [ ] **Step 2–4:** Run → fail; implement `search_entry.dart` + `search_providers.dart` per the design notes; run → pass. (The `mapSearchResultsProvider` watches `mapSearchQueryProvider` + `searchIndexProvider`, applies score/sort/cap; vocab-inherit uses the venue's `buildingId` to fetch the linked `Building` from `buildingsProvider`'s value.)
- [ ] **Step 5: `./scripts/check.sh && git commit -m "feat(map): M3 T6 — unified search index (dedup + vocab inherit) + split providers"`**

---

### Task 7: Favorites store + providers (passport idiom) + main wiring

**Files:** Create `lib/services/favorites_store.dart`, `lib/services/favorites_providers.dart`; Modify `lib/main.dart`; Test `test/unit/favorites_test.dart`.

**Interfaces:**
- Produces: `abstract interface class FavoritesStore { Future<Set<String>> loadSnapshot(); Future<bool> save(Set<String>); }` + `SharedPrefsFavoritesStore` (keys `map_favorites.buildings.v1` global + `map_favorites.venues.<eventId>` event-scoped, merged into one namespaced `Set<String>` of `PlaceKey`s); `favoritesSnapshotProvider`/`favoritesStoreProvider` (overridable, noop+empty defaults); `favoritesProvider = NotifierProvider<FavoritesController, FavoritesState>` with `toggle(String placeKey)`, serialized saves, `bool saveFailed`.

- [ ] **Step 1: Failing tests** (default empty; toggle; serialized race → {B}; namespacing; never-throw)

```dart
// test/unit/favorites_test.dart  (core cases)
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/services/favorites_store.dart';
import 'package:aon2026/services/favorites_providers.dart';

class _FakeStore implements FavoritesStore {
  Set<String> saved = {};
  int writes = 0;
  @override Future<Set<String>> loadSnapshot() async => {...saved};
  @override Future<bool> save(Set<String> s) async { writes++; saved = {...s}; return true; }
}

ProviderContainer _c(_FakeStore store, {Set<String> snapshot = const {}}) {
  final c = ProviderContainer(overrides: [
    favoritesStoreProvider.overrideWithValue(store),
    favoritesSnapshotProvider.overrideWithValue(snapshot),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('default empty; toggle add/remove', () {
    final c = _c(_FakeStore());
    final n = c.read(favoritesProvider.notifier);
    expect(c.read(favoritesProvider).keys, isEmpty);
    n.toggle('building:LIB');
    expect(c.read(favoritesProvider).keys, {'building:LIB'});
    n.toggle('building:LIB');
    expect(c.read(favoritesProvider).keys, isEmpty);
  });

  test('rapid add A, add B, remove A → persisted {B} (serialized latest-state)', () async {
    final store = _FakeStore();
    final c = _c(store);
    final n = c.read(favoritesProvider.notifier);
    n.toggle('venue:a'); n.toggle('venue:b'); n.toggle('venue:a');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(store.saved, {'venue:b'});
  });

  test('seeds from injected snapshot', () {
    final c = _c(_FakeStore(), snapshot: {'building:LIB'});
    expect(c.read(favoritesProvider).keys, {'building:LIB'});
  });
}
```

- [ ] **Step 2–4:** Run → fail; implement store (`SharedPreferencesAsync`, split the namespaced set on save: `building:`→global key, `venue:`→event key; merge on load) + controller (serialized `Future` chain like passport `_scheduleSave`, optimistic state, `saveFailed` on failure, never throws); wire `main.dart` (`loadFavorites()` → snapshot + store, `ProviderScope` overrides). Run → pass.
- [ ] **Step 5: `./scripts/check.sh && git commit -m "feat(map): M3 T7 — local favorites (passport idiom, serialized, namespaced)"`**

---

### Task 8: Localised strings (EN + FA)

**Files:** Modify `lib/l10n/app_en.arb`, `app_fa.arb`; regenerate.

**Interfaces:** Produces on `AonL10n`: `mapSearchTitle`, `mapSearchHint`, `mapSearchEmpty(query)`, `mapFavoritesTitle`, `mapFavoritesEmpty`, `mapFavoriteAdd`, `mapFavoriteRemove`, `mapBuildingDirections`, `mapBuildingGridRef(ref)`, and building-category labels as needed.

- [ ] **Step 1–3:** Add keys to both arb files (real Persian; `mapSearchEmpty`/`mapBuildingGridRef` take an ICU placeholder → `@`-metadata). Run `flutter gen-l10n`, assert `.dart_tool/untranslated_messages.json` is `{}`/empty (per check.sh's strip rule).
- [ ] **Step 4: `./scripts/check.sh && git commit -m "feat(map): M3 T8 — EN+FA strings for search + favorites + building sheet"`**

---

### Task 9: Search / Favorites / Building sheets + Favorite toggle

**Files:** Create `lib/widgets/campus_search_sheet.dart`, `lib/widgets/building_sheet.dart`, `lib/widgets/favorites_sheet.dart`, `lib/widgets/favorite_toggle.dart`; Tests mirrored.

**Interfaces (the pop→orchestrate contract, §0b.F):**
- `CampusSearchSheet` (`ConsumerStatefulWidget`): text field → `mapSearchQueryProvider`; `ListView` of `mapSearchResultsProvider`; row tap → `Navigator.pop(context, entry.placeKey)` (returns a `PlaceKey` String). **Never** opens a detail sheet itself.
- `FavoritesSheet` (`ConsumerWidget`): resolves `favoritesProvider.keys` → entries via `placeResolverProvider`; **pending** rows while `buildingsProvider` loads (never drop); tap → `Navigator.pop(context, placeKey)`.
- `BuildingSheet` (`ConsumerWidget`, `{required String buildingId}`): name, `code` + category, `gridRef`, `FavoriteToggle(placeKey:'building:$id')`, Directions CTA (M3: existing wayfinding entry; M4 re-points).
- `FavoriteToggle` (`ConsumerWidget`, `{required String placeKey}`): heart filled iff `favoritesProvider.keys.contains(placeKey)`; `toggle`; state-aware semantics label (`mapFavoriteAdd`/`mapFavoriteRemove`).

- [ ] **Step 1: Failing tests** — search filters/ranks + pop returns placeKey; empty state EN+FA; **320×568/2.0 scroll-and-tap the last result row**; **semantics** (search field labelled, each result row `isButton` with a spoken label, favorite toggle state-aware label); favorites pending-vs-resolved; building sheet renders name/code/gridRef + toggle. (Reuse the M2 picker test harness patterns: `ensureSemantics`, `getSemantics`, `scrollUntilVisible`+`tap`, `flagsCollection.isButton`, `find.byTooltip`.)
- [ ] **Step 2–4:** Run → fail; implement the four widgets; run → pass. Use `SafeArea`+`SingleChildScrollView`, `context.aon` chrome, `VenueStyle` for icons.
- [ ] **Step 5: `./scripts/check.sh && git commit -m "feat(map): M3 T9 — search/favorites/building sheets + favorite toggle"`**

---

### Task 10: Map wiring — Search + Favorites buttons, selection, markers, regression

**Files:** Modify `lib/screens/map_screen.dart`; Test `test/widget/map_m3_wiring_test.dart`.

**Interfaces:**
- Consumes: the sheets (T9), `selectedPlaceKeyProvider` (add: `NotifierProvider<SelectedPlaceKey, String?>`), `placeResolverProvider`, `buildingsProvider`.
- Produces: a **Search** control + a **Favorites** entry on the map (campus-map mode only); orchestration `openSheet → pop(placeKey) → set selectedPlaceKeyProvider → center camera → open detail sheet`; **selection markers** — selected *building* = one transient marker (placed via `projectPixel`); selected *venue* = decorate its existing always-on pin (enlarge/badge), **no second pin**.

- [ ] **Step 1: Failing regression tests** (reuse the `map_platform_wiring` harness): Search button opens the sheet; selecting a building result centers + drops exactly ONE transient building marker + opens `BuildingSheet`; selecting a venue result adds **no** extra marker (count unchanged) and decorates the existing one; favorites round-trip from a sheet; **M1 dot + M2 variant swap + the 21 venue markers all still work**; Layers button (M2) + Search button coexist without collision at 320×568/2.0.
- [ ] **Step 2–4:** Run → fail; wire `map_screen` (buttons, `selectedPlaceKeyProvider`, transient building `MarkerLayer`, venue decoration, camera move on select, note-clearance still clears all top controls); run → pass. Then run the M1/M2 suites to prove no regression.
- [ ] **Step 5: `./scripts/check.sh && git commit -m "feat(map): M3 T10 — search/favorites wiring + selection markers (no dup pin)"`**

---

### Task 11: Verification & closeout

- [ ] **Step 1:** `./scripts/check.sh full` — all 8 gates green (incl. web/apk/iOS builds with the new 127 KB asset).
- [ ] **Step 2: iOS Simulator smoke test:** search "library"/"OBS"/"18WW" → ranked results → select a building → transient pin lands on the illustration + `BuildingSheet` → favorite it → open Favorites → it's there. **Re-verify the 7 linked venue pins** moved to their pixel-exact spot correctly (they shifted from GPS-affine), and that closing a detail sheet clears the transient pin/decoration (G15). Confirm no dup pin on venue-select. Simulator only; physical iOS + Android remain the standing release IOU.
- [ ] **Step 3:** Re-score the design §11 scorecard against shipped code (scores may move; explain); note any residual IOU.
- [ ] **Step 4:** `superpowers:finishing-a-development-branch` → verify full suite green on the branch, present merge/PR/keep for `feature/map-M3-buildings-search` → `main`.

---

## Self-Review

**Coverage (§0b + Gauntlet-2 → tasks):** §0b #1 cold-start → T5 baked `campusX/Y` + drift; #2 vocab inherit → T6; #3 split providers → T6; #4 favorites init → T7; #5 serialized writes → T7 (**G8 Completer race**, not sleep); #6 no transient prune → T9 pending rows; #7 namespacing → T7 (**G7 eventId**); #8 no dup pin → T10; #9 invariants → T0/T1/T2; #10 links → T5 (**G12 exact 7**); #12 pop contract → T9; #13 comparator → T6 (**G11 real ordering test**); #14 category → T0 (`teaching` added); #15 a11y → T9; #16 provenance → T0 (**G21 permanent gate**). New seams: **G5 `placeResolverProvider`** (T6), **G6 bundle seam** (T3), **G14 linked-idle placement + test** (T10), **G15/G16 selection/query lifecycle** (T10/T9).

**Known scope boundary (not a gap — stated honestly):** **routing authority is M4's**, not M3's. M3 exposes `routingLatitude/Longitude` on both models (G2, paired) but does NOT wire or test the Directions target — the authority *rule* + test live in M4. M3's Directions CTA routes to the existing wayfinding entry unchanged.

**Concreteness:** the two real logic bugs (G1 `projectPixel` bounds, G2 routing pair) and G3/G4 are fixed inline in the task code. Vendoring shell (T0) and the `Step 2–4: implement …` notes for the UI/index tasks (T6/T7/T9/T10) are **engineering notes with defined interfaces + concrete test cases (G5–G19)**, not literal line-by-line code — an executor implements them against those contracts and the in-repo M2 harness. This is NOT a placeholder-free copy-paste script; it is a contract-complete plan.

**Type consistency:** `projectPixel(double,double)→CampusMapPoint?` (T2) used in T5/T10/G5; `buildingsProvider`/`buildingsBundleProvider` (T3) consumed T6/G5; `PlaceKey` string consistent T6→T10; `placeResolverProvider` (G5) consumed T9/T10; `favoritesProvider`/`toggle(String)`/`flush()` (G9) consistent T7→T10; `scoreBuildingMatch` (T4) reused by T6.
