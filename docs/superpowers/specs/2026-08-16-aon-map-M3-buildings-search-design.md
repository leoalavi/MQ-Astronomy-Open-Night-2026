# M3 — Buildings + Search + Favorites (design)

**Status:** design, gauntletted (self §0 + external §0b). Phase M3 of the map-parity program. On `feature/map-M3-buildings-search` off `main` (post M0+M1+M2).

**Parent:** `2026-08-15-aon-map-parity-program-design.md` — M3 row (§capability matrix), §8 hybrid authority split, IOU-P4/P6, open question #3. This spec discharges those.

## 0b. External-review amendment — AUTHORITATIVE (supersedes §0 + body where they conflict)

An external gauntlet found 16 issues (7 red). Verified each against the recon facts + installed patterns; **all 16 adopted**. The spine (async registry, pixel placement, search-only building pins, local favorites) is unchanged — these make async state and canonical identity explicit. Where this conflicts with §0/§3–§12, **this wins**.

### A. Async/state model (findings #3, #1, #4)
- **Split query from derived results (#3).** Replace the `mapSearchProvider = Notifier<String>` (query + derived results conflated) with three composed providers so results react to the registry loading→data:
  ```
  mapSearchQueryProvider    -> Notifier<String>                     (mutable user input)
  searchIndexProvider       -> Provider<AsyncValue<List<SearchEntry>>>  (venues ⊕ buildings, deduped)
  mapSearchResultsProvider  -> Provider<List<SearchEntry>>  watches (query, index)
  ```
  Test: type `LIB` while buildings load → query stays `LIB` → the building result appears automatically when the asset finishes.
- **Selection identity is a stable key, not a live object (architecture note).** `selectedPlaceKeyProvider = Notifier<String?>` holding a namespaced `PlaceKey` string (`venue:<id>` / `building:<id>`), resolved to an entry via a `placeResolverProvider`. No long-lived rebuilt `SearchEntry` as map state (uses AON's `SelectedIdNotifier` idiom).
- **Linked-venue cold-start (#1, BLOCKER).** `buildingsProvider` is async but the 21 venue markers render immediately, so a linked venue cannot depend on the async registry for its position. **Fix: linked venues carry curated `campusX`/`campusY` baked onto the Venue record** (const data, so placement is fully synchronous), copied from the linked building and **drift-tested against `buildings.json`**. The async registry is used only for *search vocab + dedup*, never for placement timing. No GPS-bootstrap-then-snap.

### B. Canonical identity & search (findings #2, #10, #13)
- **Linked venue inherits the building's search vocabulary (#2, BLOCKER).** Dedup must not make search worse: searching `LIB` must still find the Library after it's curated as a venue. The canonical linked `VenueEntry` scores as **max(score over venue fields, score over the linked building's id/code/aliases/searchTokens/tags)** while its *displayed* row stays the venue. So the entry inherits the building's tokens for ranking.
- **Deterministic mixed comparator (#13).** Order = **score desc, then `PlaceKey` asc** (stable). Empty trimmed query → first 15 default entries (`PlaceKey`-asc); non-empty → `score>0` filtered, score desc, `PlaceKey`-asc tiebreak. `searchIndexProvider` count invariant: `venues + buildings − linkedIdentities`.
- **Linked-identity integrity tests (#10).** Because `buildingId` drives dedup+placement+favorites, each link is load-bearing. Gate: every non-null `Venue.buildingId` resolves to exactly one `Building`; no duplicate `Building.id`; no two venues link the same building; index count == `venues + buildings − links`.

### C. Selection markers (finding #8)
- **No duplicate pin (#8).** A selected **building** gets a transient single marker (it has none when idle). A selected **venue** is already on the always-on layer → **highlight/decorate the existing marker** (enlarge + badge), never add a second pin. Both center the camera + open the detail sheet.

### D. Favorites (findings #4, #5, #6, #7)
- **Async init, explicit (#4).** Use the **passport idiom**: `main.dart` loads a snapshot via `SharedPreferencesAsync` (recommended over legacy `SharedPreferences` for new code), injected through `ProviderScope` overrides; `favoritesProvider = NotifierProvider<FavoritesController, FavoritesState>` seeds from the injected snapshot (synchronous state, empty default for tests). Not the legacy `saved_events` `AsyncNotifier`.
- **Serialized writes (#5).** Writes go through a single serialized `Future` chain (passport `_scheduleSave`), always persisting the *latest* state; a failed save flips a `saveFailed` flag, never throws. Test: add A → add B → remove A rapidly → restart store → persisted == `{B}`.
- **Never prune on transient loading (#6).** A `building:LIB` favorite is *temporarily unresolved* while the registry loads — keep it. The favorites **store** retains all keys; the favorites **list** resolves what it can and shows the rest as pending during `AsyncLoading`, classifying a key orphaned **only after** a successful registry load proves the id absent (and even then keeps it in the store).
- **Namespaced scope (#7).** Buildings are permanent → **global** key `map_favorites.buildings.v1`. AON venues are event records (e.g. `registration-point`) → **event-scoped** key `map_favorites.venues.<eventId>` (the `saved_events` keyFor pattern), so a venue favorite doesn't leak to a future event.

### E. Routing authority — the third axis (finding #11)
Placement authority ≠ routing authority. The Directions CTA (wired by M4) targets **entrance GPS if present, else centre GPS**, taken from the **semantic-plus-precision winner**: for a **linked venue**, use the **building's** `routingLatitude/Longitude` (entrance ?? centre — the real-world nav target); for an **unlinked venue**, the venue's `routingLatitude/Longitude`; for a **building**, the building's. So a pin and its Directions target are defined from one rule, never divergent by accident.

### F. Sheet→sheet navigation contract (finding #12)
Search/Favorites sheets **never stack another modal from their own context**. They `Navigator.pop(selectedPlaceKey)`; `MapScreen` receives it and orchestrates: set `selectedPlaceKeyProvider` → move camera → open the detail sheet. Mirrors MQ's `BuildingSearchSheet` (`Navigator.pop(building)`). Same for `FavoritesSheet`.

### G. Executable invariants + provenance (findings #9, #14, #16)
Turn the §0 prose receipts into **Task-0 test gates** (not prose): exactly **170** records; ids unique + non-empty; every `name`/`code` non-empty; every `campusX/Y` within `[0,_pw]×[0,_ph]`; **all 170 `projectPixel` succeed**; no `(0,0)` sentinel; **exactly 21** GPS-affine-domain misses (guards the pixel-necessity claim); the **18WW** pixel-vs-affine fixture (`4.04` map-units); and **every raw `category` string in `buildings.json` is a known enum value** (a typo like `"residental"` fails CI, not silently → `other`). **Provenance (#16):** record `buildings.json` source repo/path + source commit + licence/permission + **SHA-256** in a vendored `docs/fixtures/buildings_provenance.json`, drift-tested (mirrors the M1 `campus_overlay_meta.json` vendoring).

### H. A11y — executable, not promised (finding #15)
Same rigor as the M2 gauntlet fixes: **semantics-tree assertions** (search field labelled; each result row is a button with a spoken label; favorite toggle has a state-aware label announcing selected/not). For 320×568 / 2.0: **scroll the last actionable row into view and TAP it** (not just "no overflow"), including the search sheet under keyboard/view-inset pressure.

## 0. Gauntlet amendment — AUTHORITATIVE

Self-gauntlet against the real data + M1 projection. **Where this conflicts with §4/§6/§12 below, this wins.** Verify-before-apply, receipts inline:

1. **Pixel-exact building placement — CONFIRMED viable *and necessary* (my §4 hedge was backwards).** MQ's `campusX/Y` are in **M1's exact calibration pixel space** — `campus_projection.dart:13` declares `_pw=4678, _ph=3307`, and the 170 buildings' `campusX/Y` span `218..4678 × 0..3307`. The M0 2048px downscale is irrelevant (the `OverlayImage` stretches to fixed map-bounds). The transform is pure existing constants:
   `projectPixel(x,y) = CampusMapPoint(LatLng((_ph - y)/_scale, x/_scale))`, `_scale = _ph/85 = 38.905882`, bounds-checked to `[0,_pw]×[0,_ph]`, null on the `(0,0)` sentinel (no building hits it — min `campusX` is 218).
   Decisive receipt: **21 of 170 buildings fall OUTSIDE the GPS-affine domain** (`project()` → null), so GPS placement would silently **drop 21 buildings**; `projectPixel` places all 170. And affine residual is real — **18WW: GPS-affine (40.55,57.63) vs pixel (36.63,57.63) = 4.04 map-units apart** (~4.7% of the 85-unit height); pixel is the position that matches the illustration. **Decision: buildings ALWAYS use `projectPixel`. No GPS-affine fallback for buildings.**

2. **§8 render-placement authority, applied to linked venues too.** A curated `Venue.buildingId` link → semantic content from the **venue** (label/event-status/`DataConfidence`), but **placement from the linked building's `campusX/Y` via `projectPixel`** (pixel-exact, the §8 render-authority winner). Unlinked venues keep their **verified GPS-affine** `project()` placement (M1/M2, confirmed on-device). This slightly moves the *few* linked venue pins to a more-accurate spot → **re-verify those on-device at closeout.** (Re-resolves IOU-P6: no persistent `campusX/Y` backfill onto venue *data*; placement is computed at render from the link.)

3. **Method names (real M1 API):** the projection method is `CampusProjection.project(GpsPoint) → CampusMapPoint?` — **not** `gpsToCampusPoint` (which does not exist). M3 **adds** `CampusMapPoint? projectPixel(double x, double y)` to `CampusProjection` (formula above), unit-tested against `campus_overlay_meta.json`.

4. **Data shape:** the vendored `buildings.json` is **flat** (`latitude`/`longitude`/`campusX`/`campusY` at top level), all 170 carry both GPS and `campusX/Y`, plus MQ-only fields we drop (`levels`, `wheelchair`, `studentServicesGroups`, `campusHubGroups`). `Building.fromJson` stays nested-tolerant (harmless) but the asset is flat.

5. **`shared_preferences` on web — no gate risk:** it already ships (`^2.5.5`) and is used by `passport_store`/`saved_events`; the M2 `check.sh full` web build is green with it. Favorites add no new platform surface.

## 1. Goal

Give the campus map a **searchable building registry** — port MQ Journey's 170-building dataset + its ranked search — reconciled with AON's 21 curated event venues, plus a **local favorites** list. An attendee can find *any* campus building ("where's 14SCO / the Library?"), not just the 21 event venues, and bookmark places for the night.

## 2. Scope

**In:**
- Port `buildings.json` (170) + a **trimmed** `Building` model + `Building.fromJson` (tolerant of flat + nested coord shapes).
- Port MQ's **pure ranked search scorer** (`building_search.dart`) verbatim — score bands 120/110/100/90/80/70/50, `id`-asc tiebreak.
- A **unified search sheet** over {21 venues + 170 buildings}, deduped on curated identity links.
- **Marker density:** idle map unchanged (21 curated venues); buildings appear only as a selected search result.
- **Local favorites:** heart toggle on venue/building sheets + a favorites list, `shared_preferences`.
- EN + FA for every new string; 320×568 / 2.0; `context.aon` chrome; TDD; `./scripts/check.sh` gate.

**Out (YAGNI for a one-night astronomy event — logged, not silently dropped):**
- MQ's **faculty / student-services / campus-hub browse drill-downs** (`selectFacultyGroup` etc.) — MQ-open-day taxonomy, irrelevant here.
- MQ's **Supabase + secure-storage 3-tier** building source — the bundled asset is a complete dataset; sync-ish `FutureProvider` over the asset only.
- MQ's **Supabase + auth favorites** — replaced by local `shared_preferences` (no auth in AON).
- **Turn-by-turn / live navigation** — that is **M4** (embedded Google Map). M3's building sheet exposes a "Directions" CTA that M4 wires; in M3 it routes to the existing wayfinding entry (unchanged).
- **Marker clustering** — MQ has none; density is controlled by "search-only buildings", so no clusterer is added.

## 3. Architecture (data-seam preserved)

```
buildings.json (asset, 170)                VenuesData.all (const, 21)   ParkingData.all (3)
        │ rootBundle + Building.fromJson             │                        │
        ▼                                            ▼                        ▼
buildingsProvider (FutureProvider<List<Building>>)   venuesProvider (sync)   parkingProvider
        └──────────────┬───────────────────────────┘
                       ▼
        searchIndexProvider (Provider<List<SearchEntry>>)   ← unified, deduped
                       │ watch
                       ▼
        MapSearchController (query → ranked List<SearchEntry>)
                       │
        CampusSearchSheet ──opened by── a Search button on the map
                       │ select
                       ▼
        map_screen: selectedResult → center + one marker + sheet (VenueSheet | BuildingSheet)

favoritesProvider (Notifier<Set<String>>, shared_preferences)  ← independent graph
        └── FavoriteToggle (on both sheets) · FavoritesSheet (list)
```

Screens read **providers only**, never `data/*`. The building registry is introduced behind the seam (`buildingsProvider`), so `map_screen`/`VenueSheet` change minimally.

**Files (create):**
- `lib/models/building.dart` — trimmed `Building` + `BuildingCategory` + `Building.fromJson`.
- `lib/data/buildings_asset.dart` — asset loader (`loadBuildings(AssetBundle)` → `List<Building>`).
- `assets/data/buildings.json` — vendored from MQ (declared in `pubspec.yaml`).
- `lib/services/building_search.dart` — pure scorer (ported).
- `lib/models/search_entry.dart` — `SearchEntry` (sealed: `VenueEntry` | `BuildingEntry`).
- `lib/services/search_providers.dart` — `buildingsProvider`, `searchIndexProvider`, `mapSearchProvider`.
- `lib/services/favorites_store.dart` + `lib/services/favorites_providers.dart` — local favorites.
- `lib/widgets/campus_search_sheet.dart`, `lib/widgets/building_sheet.dart`, `lib/widgets/favorites_sheet.dart`, `lib/widgets/favorite_toggle.dart`.
- mirrored tests.

**Files (modify):** `lib/screens/map_screen.dart` (Search button + Favorites entry + selected-result marker/center), `lib/l10n/app_en.arb` + `app_fa.arb`, `pubspec.yaml` (asset).

**No new dependency** (`shared_preferences` already present).

## 4. The `Building` model (trimmed)

Keep only what AON uses; drop MQ's faculty/student-services/campus-hub group taxonomy, `levels`, `facultyGroup`, etc.

```dart
enum BuildingCategory { academic, services, health, food, sports, venue, research, residential, parking, transport, smoking, other }
// BuildingCategory.fromString(String?) → other on miss (JSON strings are load-bearing)

@immutable
class Building {
  final String id;            // primary key, e.g. 'LIB', '18WW'
  final String code;          // marker/short label
  final String name;
  final String? description;
  final String? address;
  final BuildingCategory category;   // default other
  final double? latitude, longitude;
  final double? entranceLatitude, entranceLongitude;   // routing coords
  final double? campusX, campusY;    // MQ pixel-exact overlay coords
  final String? gridRef;             // printed-map ref e.g. 'K18'
  final List<String> aliases, searchTokens, tags;
  // getters: routingLatitude/Longitude (entrance ?? centre); hasCampusCoordinates ((x,y)!=(0,0)); hasGeographicCoordinates
  // fromJson tolerant of flat (latitude) AND nested (location:{lat,lng}, campusLocation:{x,y})
  // == / hashCode by id only
}
```

Render placement (see §0.1–0.2, authoritative): buildings ALWAYS place via the **new** `CampusProjection.projectPixel(campusX, campusY)` — pixel-exact, aligns with the illustration, and places all 170 (21 of which fall outside the GPS-affine domain and would otherwise be dropped). A curated-linked venue also places via its building's `projectPixel`; unlinked venues keep verified GPS-affine `project()`. The `(0,0)` sentinel / out-of-range → null (no fake pin); no building hits it.

## 5. Search — ported scorer + unified index

`lib/services/building_search.dart` (pure, ported verbatim):
- `int scoreBuildingMatch(Building, String normalizedQuery)` — bands 120 (id==q) / 110 (alias exact) / 100 (field exact) / 90 (id prefix) / 80 (alias prefix) / 70 (field prefix) / 50 (contains) / 0.
- `List<Building> searchCampusBuildings(List<Building>, String query)` — score desc, `id` asc tiebreak.

**Unified index (`searchIndexProvider`)** merges venues + buildings into `List<SearchEntry>`:
```dart
sealed class SearchEntry { String get id; String get title; String? get subtitle; }
class VenueEntry extends SearchEntry   { final Venue v; ... }     // title=v.name, subtitle=category label
class BuildingEntry extends SearchEntry { final Building b; ... } // title=b.name, subtitle=b.code
```
**Scoring across mixed types:** venues are scored with a Venue-adapted call to the *same* band function (name/aliases/mapReference/building as searchable fields; venue `id` as the id band). One ranking function, two adapters — identical semantics, so results interleave correctly by score.

**Dedup (identity match, §8 semantic authority):** an AON `Venue` gains an optional curated `String? buildingId`. When a `Venue.buildingId` equals a `Building.id`, they are the **same place** → the `VenueEntry` wins and that `BuildingEntry` is dropped from the index. Only a **handful** of the 21 venues map to registry buildings; those get hand-authored links (curation, listed in the plan). Unlinked name collisions are **rare** and both may appear — logged as accepted, never hand-forced.

**Controller (`mapSearchProvider`):** `Notifier<String>` query + a derived `results` = ranked, `score>0` filtered, idle-capped at 15 (parity with MQ's `_defaultVisibleBuildings`). No auto-select in M3 (MQ's single-strong-match auto-select is nav-flow sugar deferred to M4).

## 6. Marker density + selection

- **Idle:** map shows the 21 curated venues (+parking), exactly as M1/M2. **No building pins.**
- **Select a search result:** `map_screen` holds `selectedResult: SearchEntry?` (a `Notifier<SearchEntry?>` per the Riverpod-3 `SelectedIdNotifier` idiom). On select → center the camera on the entry's projected point + render **one** marker for it (venue pin style, or a building pin using `code`) + open its sheet (`VenueSheet` for a venue, `BuildingSheet` for a building). Clearing selection removes the transient building marker.
- Buildings never join the always-on `MarkerLayer`; the selected building is a separate single-marker layer above it.

## 7. Building sheet + favorites

- **`BuildingSheet`** (`ConsumerWidget`, modal): name, `code` + category, `gridRef` if present, `FavoriteToggle`, and a **Directions** CTA. In M3 the CTA pushes the existing wayfinding entry (unchanged); **M4 re-points it to the embedded Google Map.** No fake turn-by-turn in M3.
- **`FavoriteToggle`** (`ConsumerWidget`): heart (filled = favorited), calls `favoritesProvider.notifier.toggle(entryKey)`. Added to both `VenueSheet` and `BuildingSheet`.
- **Favorites store (local):** `favoritesProvider = NotifierProvider<FavoritesController, Set<String>>`, persisted via `shared_preferences` (the `saved_events` optimistic pattern: update state → persist `setStringList`, swallow failure). **Id namespacing:** keys are `venue:<id>` / `building:<id>` (the two id spaces are disjoint strings, but the prefix makes intent explicit and future-proofs collisions). **Key is NOT event-scoped** (a campus building is event-agnostic; a favourite persists across events) → `'map_favorites.v1'`.
- **`FavoritesSheet`:** a list of favorited entries (resolve each key → Venue/Building; drop unresolved keys silently), tap → select it on the map, swipe/long-press → remove.

## 8. Data flow / async + error handling

- `buildingsProvider` (`FutureProvider`) reads `assets/data/buildings.json` once. While loading, `searchIndexProvider` yields **venues-only** (21) so search works instantly on cold start; buildings fold in when ready. A decode failure → registry is empty (venues-only search still works); logged, non-fatal (never a blank map).
- Favorites load is best-effort (injected snapshot like passport, or lazy first-read); a persistence failure never throws (optimistic).
- All coordinate placement goes through `CampusProjection` — a building that can't project is listed in search but shows no pin (honest), matching M1's off-footprint discipline.

## 9. Global constraints (inherited)

- **No new dependency.** New asset (`buildings.json`) declared in `pubspec.yaml`; web build stays a gate (asset read is web-safe; `shared_preferences` has a web impl).
- **EN + FA** for every new string (search hint, empty states, favorites, building sheet, categories) — `check.sh` l10n gate.
- **`context.aon`** chrome; building/venue category styling via `VenueStyle` (extended for building categories).
- **320×568 / 2.0** for the search sheet, building sheet, favorites sheet.
- **A11y:** search field labelled; result rows are buttons with spoken labels; favorites heart has a state-aware label.
- **TDD; never weaken a test.** Full suite green; `check.sh` per task; `full` + on-device at closeout.

## 10. Testing

- **Model:** `Building.fromJson` flat + nested coord shapes; category `fromString` fallback; `id`-equality; the vendored `buildings.json` parses to 170 with non-empty ids (asset-integrity test).
- **Search scorer (pure):** the band ladder (exact id 120 … contains 50 … miss 0); score-desc/id-asc ordering; empty query → all sorted by id. Ported MQ test vectors.
- **Unified index:** venue + building interleave by score; a linked `Venue.buildingId` de-dupes the matching `BuildingEntry`; venues-only during buildings-loading.
- **Favorites:** default empty; toggle adds/removes; namespaced keys; persists across a store round-trip (fake store); unresolved key dropped from the list.
- **Search UI:** typing filters + ranks; empty-results state (EN+FA); 320×568/2.0 no overflow; result select sets `selectedResult`.
- **Wiring (regression):** Search button opens the sheet; selecting a building centers + drops one marker + opens `BuildingSheet`; the 21 curated venue markers + M2 variant swap + M1 dot all still work; favorites toggle round-trips from a sheet.
- **Projection:** `buildingPixelToMapPoint` matches the vendored calibration; a no-coord building shows no pin.
- **Verification:** `check.sh full`; on-device search → select a building → sheet → favorite → favorites list.

## 11. Scorecard (M3, post-gauntlet target — pre-build)

Re-scored after the external gauntlet's fixes (§0b). Targets the design must hold to at closeout:

| Axis | Score | Raises it |
|---|---:|---|
| Parity coverage | 7/10 | Registry + ranked search + favorites closed; browse drill-downs intentionally out; routing M4, AR M5. |
| Hybrid correctness | 9/10 | Three axes now explicit — semantic (venue), render (pixel `projectPixel`), routing (entrance GPS); linked venues carry drift-tested curated `campusX/Y` (no cold-start hole); integrity tests gate every link. |
| Additive safety | 9/10 | Buildings search-only; selected venue decorates its existing pin (no dup); idle map + M1/M2 untouched; wiring regression. |
| Search quality | 8.5/10 | Ported scorer + venue adapter; linked venue inherits building vocab (dedup can't worsen search); deterministic mixed comparator. |
| Persistence correctness | 8.5/10 | Passport-idiom async init (injected snapshot), serialized latest-state writes, transient-loading keys never pruned, event-scoped venue vs global building namespaces. |
| A11y / 2.0 / FA | 9/10 | Semantics-tree assertions + scroll-and-tap last row + EN/FA; not just "no overflow". |

## 12. Open questions / IOUs discharged

1. **IOU-P4 (merge policy):** resolved — semantic authority = curated `Venue.buildingId` link (venue wins), render-placement = each source's own best coordinate.
2. **IOU-P6 (backfill campusX/Y onto venues):** resolved (§0.2) — no persistent data backfill; buildings + curated-linked venues place via `projectPixel` (pixel-exact) computed at render, unlinked venues keep verified GPS-affine. Pixel-exact is necessary, not just nicer: 21/170 buildings are outside the GPS-affine domain.
3. **Open Q#3 (hybrid conflict specifics):** resolved by §5 dedup + §4 placement.
4. **New (M3):** which of the 21 venues get curated `buildingId` links — enumerated in the plan (a short hand-authored table, each verified against `buildings.json`).

## 13. Next step

On approval → **gauntlet this design**, then the M3 TDD plan (asset+model → scorer → unified index/dedup → favorites store → search sheet → building sheet → map wiring + regression → verification). No code before the plan is gauntletted. **M4 follows M3** (embedded Google Map, gated on the API key).
