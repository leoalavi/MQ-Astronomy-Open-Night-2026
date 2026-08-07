# MQ Journey reuse analysis

Assessment of the existing **MQ Journey** codebase as a technical foundation
for Astronomy Open Night 2026.

MQ Journey was inspected **read-only**. Nothing in that repository was
modified, and this project has **no runtime dependency** on it. Everything
reused was copied or rewritten into this repository.

---

## 1. What MQ Journey is

| Aspect | Finding |
|---|---|
| Framework | Flutter `3.44.0`, Dart SDK `^3.11.0` |
| Language | Dart |
| Architecture | Feature-first Clean Architecture — `lib/features/<name>/{data,domain,presentation}` |
| Size | 217 Dart files in `lib/` |
| State management | Riverpod 3 (`flutter_riverpod ^3.3.2`) |
| Navigation | `go_router ^17.3.0` |
| Maps | `flutter_map ^8.3.0` + `latlong2` — **not** Google Maps SDK |
| Routing/directions | Google **Routes API v2 / Directions API** over HTTP (requires a billed API key) |
| Backend | Supabase (`supabase_flutter`), Firebase (core + messaging) |
| Location | `geolocator`, `permission_handler`, `flutter_compass` |
| Storage | `shared_preferences`, `flutter_secure_storage`, `cryptography` |
| Other | `mobile_scanner` (QR), `torch_light`, `confetti`, `flutter_inappwebview`, `icalendar_parser` |
| Build/deploy | Android, iOS, macOS, Linux, Windows, web; GitHub Actions in `.github/`; Maestro E2E tests |
| Feature set | auth, map, open_day, timetable, transit, favorites, notifications, safety, scan (QR stamp trail), settings |

### Data assets found

| Asset | Contents |
|---|---|
| `assets/data/buildings.json` | **170 campus buildings**, 127 KB. Each has `latitude`/`longitude`, a separate `entranceLatitude`/`entranceLongitude`, campus-image pixel coordinates (`campusX`/`campusY`), grid reference, aliases, search tokens, wheelchair flag |
| `assets/data/campus_overlay_meta.json` | GPS↔pixel affine projection for the campus raster |
| `assets/maps/mq-campus.png` | 4678×3307 campus map raster (3.3 MB) + parking/accessibility/water/permit overlays |
| `assets/data/indoor/*.json` | Indoor floorplans for ~10 buildings |
| `assets/data/open_day.json` | Open Day 2026 programme (38 KB) |

### Secrets and credentials — NOT copied

`MQ-Journey/.env.example` declares `SUPABASE_URL`, `SUPABASE_ANON_KEY`,
`TFNSW_API_KEY`, `TFNSW_STOP_ID`, `ALLOWED_WEB_ORIGINS`. Its `.gitignore`
additionally excludes `google-services.json`, `GoogleService-Info.plist`,
`android/secrets.properties`, `ios/Flutter/Secrets.xcconfig` and QR signing
keys (`*.key`, `*.pem`, `*.seed`).

**None of these were read, copied or referenced.** This project has no
`.env` requirement at all — see `.env.example` here, which documents that
absence explicitly.

---

## 2. Reuse decisions

### REUSE AS-IS

Nothing was copied verbatim. Every file carries at minimum a changed package
name (`mq_journey` → `aon2026`) and a rewritten doc comment explaining its
role here. Listed below are the items reused with only mechanical changes.

| Item | Rationale |
|---|---|
| **Technology stack choice** — Flutter 3.44 + Riverpod 3 + go_router + flutter_map | The single highest-value reuse. The team already knows it, CI already targets it, and the version matrix is proven to work together. Adopting it removed most of the technical risk from this project. |
| **`analysis_options.yaml`** | Same lint rules, so both codebases read identically. Copied with the `*.g.dart` / l10n exclusions dropped (we generate neither). |
| **Building coordinate data** | The `latitude`/`longitude` values in `buildings.json` for the ten venues this event uses. This is real, verified campus survey data and re-deriving it would have been both wasteful and less accurate. Transcribed into `lib/data/venues_data.dart` and marked `DataConfidence.derived`. |

### REUSE WITH MODIFICATION

| Item | Change made | Rationale |
|---|---|---|
| **Design tokens** (`mq_colors` → `aon_colors`, `mq_spacing` → `aon_spacing`, `mq_typography` → `aon_typography`) | Structure kept (`abstract final class` of `static const` tokens); **every value replaced** | The pattern is good and gives one place to re-theme from. But MQ Journey's palette is Open Day magenta on a light alabaster background — the opposite of what a night event needs. Type sizes were raised one step and tap targets went 48pt → 56pt for outdoor one-handed use. |
| **`Building` entity → `Venue`** | 448 lines → ~120 | Dropped faculty groups, student-services groups, campus-hub groups, indoor level counts and the 40-token search index — all of which serve MQ Journey's year-round student-services browse and mean nothing for a six-hour public event. **Kept** the entrance-vs-centroid coordinate split (routing to a centroid drops people on the wrong side of a building at night) and `aliases` (attendees search "Mason Theatre", not "14SCO"). |
| **`go_router` setup** | Same `StatefulShellRoute.indexedStack` structure, new routes | Per-tab navigation stacks matter here: attendees bounce between map and programme constantly. |
| **`flutter_map` usage** | Same package, new implementation | See "DO NOT REUSE" below for why the widgets themselves were not taken. |
| **Riverpod provider patterns** | Same idioms, but `StateProvider` → `NotifierProvider` | **Riverpod 3 removed `StateProvider`.** Parts of MQ Journey still use it and would not compile fresh. A caution against assuming "same stack" means "same API". |
| **`.gitignore`** | Copied and extended | Its secret-exclusion rules are thorough and worth inheriting even though we currently have no secrets. |

### DO NOT REUSE

| Item | Rationale |
|---|---|
| **Supabase, Firebase, `firebase_messaging`, `flutter_secure_storage`, `cryptography`** | Backend, auth, push and encrypted storage. The brief explicitly excludes auth, accounts and backend infrastructure. Each would add a credential to a repository that currently has none. |
| **`features/auth/`** | No accounts in this product. |
| **`features/scan/`** (QR stamp trail) | ~25 files including a signed-QR verification scheme with private signing keys. Wholly Open Day gamification. |
| **`features/timetable/`, `features/transit/`** | Timetable is student-enrolment data. Transit calls the Transport for NSW Open Data API with `TFNSW_API_KEY` — a credential we will not introduce. |
| **`features/notifications/`, `features/favorites/`, `features/safety/`, `features/settings/`** | Out of MVP scope. Favourites is a plausible v2. |
| **`MapsRoutesRemoteSource` / `CampusRoutesRemoteSource` / `MapRoute` / `NavInstruction`** | **The most important rejection.** MQ Journey's routing is a thin client over the Google Routes/Directions API. It needs a billed API key, a network round-trip, and it returns generic turn-by-turn text with no knowledge of which campus paths are lit or open at 9pm. The brief said to avoid complex routing "unless MQ Journey already provides a safe and reliable reusable solution" — it does not, for this use case. See `docs/navigation-strategy.md`. |
| **`map_page.dart` (1,747 lines), `map_controller.dart` (1,008), `route_panel.dart` (1,071), `map_shell.dart` (751)** | ~4,600 lines built around live-location tracking, indoor floorplans, a compass AR mode and an overlay picker. Adopting them would import their whole dependency surface (`geolocator`, `permission_handler`, `flutter_compass`, `torch_light`) for features this MVP does not have. |
| **`assets/maps/mq-campus.png` + `campus_overlay_meta.json`** | Technically excellent — an affine-projected campus raster. Not reused for a **licensing** reason: it is Macquarie University cartography, and this is a separate product whose rights position is not yet settled (see `docs/licensing`, in README). Revisit once the university confirms. |
| **`assets/data/open_day.json`, `open_day_trail.json`, stamps catalogue** | Different event. |
| **`AGENT.md` (293 KB), `CHANGELOG.md` (445 KB), `REPO_MAP.md`** | MQ Journey project history. |
| **`.github/` workflows, `maestro/`, `supabase/`, `shaders/`** | CI targets MQ Journey's build matrix and secrets; Maestro flows test its screens; the Supabase directory is backend schema; the glass-refraction shader belongs to its visual identity, not ours. |

### REBUILD

| Item | Rationale |
|---|---|
| **Wayfinding** (`models/walking_route.dart`, `data/routes_data.dart`, `screens/wayfinding_screen.dart`) | Replaces the Google-Routes dependency with predefined, hand-authored, organiser-reviewable campus walking routes that ship offline. Written instructions are the primary output; the map line is supporting. Rationale in full: `docs/navigation-strategy.md`. |
| **Event/session model** (`models/event.dart`) | MQ Journey's Open Day model does not handle an activity with **multiple non-contiguous sessions** (the Physics magic show runs three times). `AonEvent` owns a `List<EventSession>`. |
| **"What's On Now"** (`services/whats_on_service.dart`, `services/clock.dart`) | No equivalent in MQ Journey. Built as pure functions over an injected clock so it is testable at any instant and demonstrable before event night. |
| **Data-confidence model** (`models/data_confidence.dart`) | No equivalent. Makes "confirmed vs placeholder" a property of the data and a visible UI state, rather than a note in a spreadsheet. |
| **Data loading** (`services/providers.dart`) | MQ Journey loads `buildings.json` through an asset read, JSON decode, versioned `SharedPreferences` cache and `AsyncValue` wrapper. Justified for 170 buildings that change each semester; unnecessary for ~35 events fixed on the day. Compiled-in `const` data removes a whole class of loading, error and cache-invalidation states. |
| **All screens and widgets** | New product, new information architecture. |

---

## 3. Net effect

| | MQ Journey | This project |
|---|---|---|
| Dart files in `lib/` | 217 | 38 |
| Direct dependencies | 28 | 6 |
| Requires API keys | Yes (Supabase, Firebase, TfNSW, Google Routes) | **No** |
| Requires network to be useful | Yes | Only for map tiles; all event data is offline |
| Requires runtime permissions | Location, camera, notifications | **None** |

The stack was reused. The application was not.
