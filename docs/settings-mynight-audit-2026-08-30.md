# Settings & My Night professional audit — 2026-08-30

Scope: the Settings tab (`lib/screens/settings_screen.dart`) and the My Night
tab (`lib/screens/my_night_screen.dart` + `lib/services/itinerary_service.dart`)
— the two remaining bottom-nav tabs with no end-to-end coverage. Same
methodology as the map and Home/Program audits: baseline on-device, **read the
app, not the plan**, fix only clearly-bounded low-risk correctness defects, flag
judgment calls, and close the E2E gap with Maestro. Audited against the repo's
**time-honesty invariant** (never present a stand-in time as fact) and the
Settings brief (**every control must change real behaviour**).

---

## 1. Executive summary

Both screens are **release-ready**. The audit found **no correctness or
time-honesty defect** in either — an honest outcome, not a thin one: both are
already careful where it matters, and inventing a defect to look productive is
exactly the failure the "read the app" lesson warns against.

- **Settings** honours its own brief — every control was verified to change real
  behaviour on-device, including the language switch flipping the whole app to
  Persian/RTL and back.
- **My Night** already applies the time-honesty gate: its 10pm *stand-in* ends
  never render a countdown, unscheduled activities sort out of the chronological
  run and are never marked "finished", and conflicts are flagged only between
  two genuinely-timed sessions.

The real gap was **coverage**: neither tab had an E2E flow. Two were added
(`settings.yaml`, `my-night.yaml`), both passing. One latent, non-user-visible
inefficiency (SET-A) is flagged, not fixed.

---

## 2. Test summary

| Layer | Result |
|---|---|
| Existing widget tests | 30 across the two screens (settings 11 + consent 4 + my_night 15) |
| `settings.yaml` (new E2E) | **pass**, 20 commands |
| `my-night.yaml` (new E2E) | **pass**, 21 commands |
| Full page suite (settings · my-night · home · program) | **pass**, 85 commands, order-independent |

E2E runs against an iPhone 17 Pro Max simulator via the Maestro MCP (not part of
`check.sh`, which needs no booted device).

---

## 3. Settings findings

No defect. Verified on-device that every control changes real behaviour:

- **Appearance** — System / Light / **Dark (Recommended)** three-way; Dark
  selected by default.
- **Language** — selecting **فارسی** flips the entire app to Persian and RTL
  (title تنظیمات, mirrored bottom nav, sections ظاهر/زبان/حرکت), and **English**
  flips it back. Endonyms ("English", "فارسی") are correctly never translated, so
  they stay recognisable and tappable in either direction.
- **Motion & feedback** — Reduce motion / Haptics toggles are live switches.
- **Privacy** — the Google Maps notice is always shown; the revoke control
  appears only once consent has been given.
- **Your data** — "Delete my data" raises a confirm dialog ("Delete data stored
  on this device?") before doing anything; Cancel dismisses cleanly.
- **Last-row reachability** — the final actionable control (Google Maps
  licences) clears the floating tab bar (rendered at y≈682 of 956, tab bar at
  844) and opens the bundled open-source licences (static text, no network).

No hardcoded user-facing strings — every string routes through `AonL10n`.

---

## 4. My Night findings

No defect. The screen and its `ItineraryService` are careful about time-honesty:

- **Stand-in ends are never a countdown.** Kids' space shows its window
  "4.15pm – 10pm" but its timing badge carries no "ends in N" — the 10pm end is
  a stand-in, gated by `session.hasPublishedEnd` (the same guard fixed on Home
  as HP-A). Verified on the populated timeline.
- **Unscheduled activities are handled honestly** — `_timingFor` returns
  `unscheduled` first (never falls through to `upcoming`/`finished`), the sort
  collects them at the end alphabetically, and `remaining()` keeps them visible
  rather than ever marking them "finished" off an invented end.
- **Conflicts are provable, not fabricated.** `_overlaps` returns false if
  either session is unscheduled, so a clash warning is never derived from a
  stand-in window. Saving Cosmic arcade (4.15–9.30pm, published) and Kids' space
  (4.15pm start) correctly flags a genuine overlap both ways — both really begin
  at 4.15pm.
- **Remove + Undo, Clear-all** work; the empty-state CTA routes to the
  programme. (The remove's Undo snackbar closes over the ProviderContainer's
  notifier, not the widget's `ref` — the fix for the earlier unmount bug is
  intact.)

---

## 5. Observations (flagged, NOT fixed)

- **SET-A — `FutureBuilder` future created in `build()`
  (`settings_screen.dart:744`, `_MapsLicenceLink`).** Each rebuild of the
  Credits card calls `openSourceLicenseInfo()` afresh and restarts the builder.
  This is the textbook FutureBuilder anti-pattern, but here it is a *latent*
  inefficiency, not a user-visible defect: the widget rebuilds rarely (only on a
  settings/theme change), the future resolves bundled static text idempotently,
  and the worst case is a momentary re-resolve of one button. Fixing it means
  caching the future (a `StatefulWidget` or a memoised provider) — low value
  during a release freeze, and the same reasoning that defers P2/P3 version bumps
  applies. **Recommendation: leave; revisit post-launch if the Credits card ever
  becomes rebuild-heavy.**

---

## 6. Fixed during the audit

Nothing in production code — both screens were already correct.

| Added | File(s) |
|---|---|
| Settings E2E | `.maestro/settings.yaml` (20 cmds) |
| My Night E2E | `.maestro/my-night.yaml` (21 cmds) |

Commit (branch `audit/settings-mynight`): `52ae52a`, + this report.

---

## 7. Final recommendation

Settings and My Night are **release-ready**. Ship the two E2E flows as
regression cover for the last two untested tabs; keep SET-A as a post-launch
housekeeping note. With this, all six bottom-nav tabs (Home, Program, My Night,
Map, Info-pending, Settings) except Info now carry an E2E flow — **Info is the
last untested tab** if a further pass is wanted.
