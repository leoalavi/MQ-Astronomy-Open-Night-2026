# Testing strategy

```bash
flutter test
```

109 tests. No network, no golden files, no device required.

## What is worth testing here

This is a small offline app with no backend and no auth, so the usual
integration surface barely exists. The risks that *do* exist are unusual, and
the suite is shaped around them:

| Risk | Why it matters | Guard |
|---|---|---|
| The cancelled Huntsman session gets re-added | It is still printed in the official PDF, so a maintainer reconciling data against the source will find it "missing" | `test/unit/huntsman_exclusion_test.dart` |
| Time logic only works on event night | The event is in the future; naive tests would pass today and fail forever after | Injected clock, every test pins an instant |
| A typo puts a marker in the wrong place | Someone follows it into the dark | `test/unit/data_integrity_test.dart` |
| A guess gets presented as fact | Breaks trust and the brief | Placeholder-discipline tests |

## Layout

```
test/
├── unit/
│   ├── huntsman_exclusion_test.dart   the cancelled session, 4 tests
│   ├── whats_on_service_test.dart     time classification, 21 tests
│   ├── event_filter_test.dart         filtering + search, 25 tests
│   ├── data_integrity_test.dart       structural checks, 30 tests
│   └── lookup_test.dart               venue/route/provider lookups, 22 tests
└── widget/
    ├── whats_on_screen_test.dart      the time-dependent screen, 7 tests
    └── program_screen_test.dart       search and filter chips, 6 tests
```

## Coverage by requirement

The brief asked for tests covering six areas:

| Required | Where |
|---|---|
| Event filtering | `event_filter_test.dart` — categories, venues, time bands, search, booking, AND/OR combination, boundary conditions |
| What's On Now logic | `whats_on_service_test.dart` — bucket classification, half-open intervals, the 30-minute boundary, multi-session events, sort order |
| Excluded Huntsman event | `huntsman_exclusion_test.dart` + assertions in `event_filter_test.dart` and both widget tests |
| Location lookup | `lookup_test.dart` — by id, by alias, by map-legend letter, entrance-vs-centroid preference |
| Route lookup | `lookup_test.dart` — by pair, directionality, routes-from, text-only routes |
| Missing data handling | `lookup_test.dart` — every lookup returns `null` rather than throwing; `data_integrity_test.dart` — placeholder discipline |
| Component tests | `test/widget/` |

## Conventions

### Never call `DateTime.now()`

Widget tests override `baseClockProvider`:

```dart
ProviderScope(
  overrides: [baseClockProvider.overrideWithValue(FixedClock(EventInfo.at(19, 0)))],
  child: ...,
)
```

Note it is the *base* clock, not `clockProvider` — so the in-app time simulator
still layers on top and can itself be tested.

Unit tests pass an explicit instant to the pure functions in `WhatsOnService`.

### Assert on unknown-vs-false

`lookup_test.dart` asserts that every route's `isAccessible` is currently
`null`. That looks odd, but it is deliberate: it means a future change from
"unknown" to a real value is a **conscious act** that updates the test,
rather than something that slips through.

### Test the negative cases

Missing venue, unknown event id, undefined route pair, empty filter result.
These are the paths a stale shared link takes, and they must degrade to a
friendly message rather than an exception.

### Widget tests must scroll

`ListView` and horizontal chip bars build lazily. Use
`tester.scrollUntilVisible`. The programme filter bar carries
`Key('program-filter-bar')` for exactly this reason.

## Not covered, and why

| Not tested | Reason |
|---|---|
| Golden / screenshot tests | The design is still moving. Worth adding once the visual design is signed off |
| Map rendering | `flutter_map` needs a tile server; testing the library is not our job. The *data* going into the map is tested |
| Integration / E2E | MQ Journey uses Maestro. Worth adding for the wayfinding flow once routes are confirmed |
| Accessibility automation | A manual pass is on the v1.0 checklist. Contrast ratios are documented in `aon_colors.dart` but not asserted |
| Real-device outdoor testing | Cannot be automated, and is the single most valuable test for this product. On the v1.0 checklist |

## Before the event

1. Run `flutter test` on CI for every PR.
2. Add golden tests once the design is frozen.
3. Manual accessibility pass — TalkBack/VoiceOver, 200% text, contrast.
4. **Walk the campus at night with the app.** Nothing above substitutes for it.
