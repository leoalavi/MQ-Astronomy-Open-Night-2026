# Architecture

## Stack

| Concern | Choice | Why |
|---|---|---|
| Framework | Flutter 3.44 / Dart 3.11+ | Inherited from MQ Journey — known team, proven version matrix, one codebase for iOS + Android + web |
| State | `flutter_riverpod` 3 | Same as MQ Journey. Compile-safe DI, and provider overrides are what make the clock injectable |
| Routing | `go_router` 17 | Same as MQ Journey. Deep-linkable, and `StatefulShellRoute` keeps per-tab stacks |
| Maps | `flutter_map` 8 + `latlong2` | **No API key.** Keeps the repository free of credentials |
| Dates | `intl` | Formatting only |

Six direct dependencies. Everything else was deliberately left behind — see
`docs/mq-journey-reuse-analysis.md`.

## Layout

Flutter has no `src/`; `lib/` is the equivalent. The requested conceptual
structure maps onto it directly:

```
lib/
├── main.dart                  app entry, theme + orientation setup
├── app/
│   ├── router/app_router.dart routes and the tab shell    → src/navigation
│   └── theme/                 colours, spacing, type, ThemeData
├── models/                    types/models               → src/types
│   ├── data_confidence.dart   confirmed | derived | placeholder
│   ├── event.dart             AonEvent, EventSession, EventCategory
│   ├── venue.dart             Venue, VenueCategory
│   ├── parking_area.dart
│   └── walking_route.dart     WalkingRoute, RouteStep
├── data/                      static event data          → src/data
│   ├── event_info.dart        date, times, host
│   ├── events_data.dart       the programme
│   ├── venues_data.dart       venue registry
│   ├── parking_data.dart
│   └── routes_data.dart       predefined walking routes
├── services/                  logic + providers          → src/services
│   ├── clock.dart             injectable "now"
│   ├── event_filter.dart      filtering + grouping
│   ├── whats_on_service.dart  time classification
│   └── providers.dart         Riverpod wiring
├── utils/                     helpers                    → src/utils
│   ├── time_format.dart
│   └── venue_style.dart       category → colour + icon
├── widgets/                   shared UI                  → src/components
└── screens/                   pages                      → src/screens
assets/images/                 hero image
docs/                          this directory
docs/source-materials/         original supplied files (not bundled)
test/unit/, test/widget/       tests
```

## Key decisions

### Data is compiled in, not loaded

`lib/data/*.dart` are `const` Dart lists exposed through synchronous
`Provider`s. No asset read, no JSON parse, no cache, no `AsyncValue`.

MQ Journey does the opposite, correctly — 170 buildings in a 127 KB file that
changes between semesters needs async loading and a cache. Roughly 35 events
fixed on the day does not. Compiling them in eliminates loading states, error
states and cache-invalidation bugs at no measurable cost, and guarantees the
programme works with no connectivity.

**The seam:** if event data ever needs to change without an app release, swap
the providers in `services/providers.dart` for `FutureProvider`s. Screens that
already handle `AsyncValue` keep working.

### Time is injected, never read directly

Nothing calls `DateTime.now()`. Everything reads `currentTimeProvider`.

```
baseClockProvider   ← tests override this
      ↓
clockProvider       ← applies the in-app time simulator, if engaged
      ↓
tickingNowProvider  ← re-emits every 30s
      ↓
currentTimeProvider ← what the UI watches
```

Tests override `baseClockProvider` rather than `clockProvider`, so the
simulator layers on top and can itself be tested.

The 30-second tick is chosen against the shortest thing displayed: the
"starting soon" window is 30 minutes and sessions are 30–45 minutes, so half a
minute of staleness is never visible, while polling faster would cost battery
on a night when phones need to last until 10pm.

### Data confidence is a first-class type

`DataConfidence` (`confirmed` | `derived` | `placeholder`) is a field on
venues, sessions, parking and routes — not a comment. `ConfidenceNote` renders
it, so anywhere the app shows a placeholder it also says so. Tests assert that
placeholders carry an explanation and that nothing without coordinates claims
to be confirmed.

### Dark theme only

There is no light theme, by design. The event runs dusk to 10pm, and a white
screen next to a telescope eyepiece destroys the dark adaptation of everyone
nearby. The accent is warm amber rather than blue-white for the same reason.

Colour is never the only signal — every venue category and timing state also
has a distinct icon, for colour-blind users and for phones with night-shift
filters active.

### No location permission

The app never asks for GPS. Between campus buildings, accuracy is roughly
±20 m — not enough to choose between two paths — so a blue dot would buy a
permission prompt and a privacy obligation in exchange for nothing useful.
Wayfinding is start-point selection plus written directions instead.

## Timezone handling

Event times are naive local `DateTime`s built by `EventInfo.at(hour, minute)`.
This is correct for the MVP: a single-day event, attended in person, on devices
set to Sydney time.

**If the app ever needs to show correct times to someone outside Australia/Sydney,
this is the thing to change** — introduce the `timezone` package (MQ Journey
already depends on it) and pin to `Australia/Sydney` in `event_info.dart`. Every
other file reads times through that one constructor, so the change is contained.

## Testing

`flutter test` — 109 tests, no network, no golden files.

- `test/unit/` — filtering, "what's on now", data integrity, lookups, and the
  Huntsman exclusion guard
- `test/widget/` — the two time-dependent screens, with an overridden clock

See `docs/testing-strategy.md`.
