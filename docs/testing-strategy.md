# Testing strategy

```bash
flutter test                  # the suite
./scripts/check.sh            # the suite with coverage, plus the coverage gate
```

1131 tests. No network, no golden files, no device required.

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

## Coverage, and why it is not 100%

`scripts/check.sh` runs the suite with `--coverage` and enforces
`tools/coverage/policy.json` against the result. Current figure:
**87.96% of hand-written `lib/` lines** (5624/6394), 75 of 133 files at 100%.

**There is no function-coverage number to report.** `flutter test --coverage`
writes only `DA:` (line) records — `grep -c '^FN:' coverage/lcov.info` returns
`0`. Any claim of "100% of functions" for a Flutter project is measuring
something the toolchain does not emit.

Three rules, each a one-way ratchet:

1. hand-written `lib/` coverage may not fall below `minimum_total_pct`
2. every hand-written file reaches 80%, unless it is `platform_exempt` or
   carries its own lower floor in `debt`
3. a `debt` entry that has been paid off, or an exemption naming a file that
   no longer exists, **fails** — so neither list can rot into an amnesty

Rule 3 is the one doing the work. Without it, `debt` is permanent; with it,
covering a file forces you to delete its entry and live under the 80% minimum
from then on. Raise a floor when coverage improves; lowering one to go green
defeats the point of having it.

Seven files are exempt by name, each with its reason recorded, rather than
hidden inside a lower global number: the geolocator service, the camera
scanner, the WebView panorama host, the native map view, the GPU shader, the
`url_launcher` hand-off, and the `runApp` bootstrap. None of them can execute
in the Flutter test VM. Generated l10n is excluded from both numerator and
denominator — covering it means calling every string getter, which moves the
percentage and tests nothing.

Eight ordinary Flutter files sit on `debt` at their current values. They have
no platform obstacle, only missing widget tests; `lib/screens/wayfinding_screen.dart`
is the largest at 39%. See `tools/coverage/README.md`.

## Not covered, and why

| Not tested | Reason |
|---|---|
| Golden / screenshot tests | The design is still moving. Worth adding once the visual design is signed off |
| Map rendering | `flutter_map` needs a tile server; testing the library is not our job. The *data* going into the map is tested |
| Integration / E2E | MQ Journey uses Maestro. Worth adding for the wayfinding flow once routes are confirmed |
| Accessibility automation | A manual pass is on the v1.0 checklist. Contrast ratios are documented in `aon_colors.dart` but not asserted |
| Real-device outdoor testing | Cannot be automated, and is the single most valuable test for this product. On the v1.0 checklist |
| 360° panorama rendering | The viewer is an `InAppWebView` over a localhost asset server; it needs a real engine. The manifests, the tour table and every bundled image ARE asserted (`test/unit/panorama_data_test.dart`), so only the render itself is unproven |

## Before the event

1. Run `./scripts/check.sh` on CI for every PR — it carries the coverage gate.
2. Add golden tests once the design is frozen.
3. Manual accessibility pass — TalkBack/VoiceOver, 200% text, contrast.
4. **Walk the campus at night with the app.** Nothing above substitutes for it.
