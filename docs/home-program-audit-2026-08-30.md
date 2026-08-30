# Home & Program professional audit — 2026-08-30

Scope: the Home tab (`lib/screens/home_screen.dart` and its cards) and the
Program tab (`lib/screens/program_screen.dart`, `lib/services/event_filter.dart`,
`lib/services/whats_on_service.dart`, and the shared timing/format layer). Run
with the same methodology as the map subsystem audit
(`docs/map-audit-2026-08-30.md`): baseline first, read the app rather than the
plan, fix only clearly-bounded low-risk correctness defects as I go, and flag
anything that is a product or design judgment.

The organising principle audited against is the repo's **time-honesty
invariant**: the app must never present a stand-in (invented) time as fact. A
session only counts down to a finish it actually published; unscheduled and
start-only activities carry stand-in windows flagged with a `TimingConfidence`,
and those stand-ins must never leak into the UI as though they were real.

---

## 1. Executive summary

Home and Program are in good shape and the time-honesty invariant holds across
the screens that matter. The audit found **four** real, bounded defects — all
fixed with a failing-test-first cycle — plus **two** observations that are
product/design judgments, not bugs, and were deliberately left for a decision
rather than "fixed".

The single defect with user-visible consequence was **HP-A**: the Home
"Next in My Night" card counted down "ends in N" for a saved activity whose
finish the programme never published — the exact class of stand-in-as-fact the
invariant forbids, and which the event cards, activity-rail cards and My Night
screen already guarded. The other three were dead code and an unreachable
preview state. Both observations (HP-B, HP-C) concern the *Program time-band
filter* and a *tested-but-unused invariant helper*; both are defensible as-is.

Gate green throughout (`./scripts/check.sh`, coverage 90.97%). Home + Program
E2E flows added and passing (44 commands).

---

## 2. Test summary

| Layer | Result |
|---|---|
| `./scripts/check.sh` (analyze · l10n EN+FA · coverage gate · reskin) | **green**, line coverage **90.97%** |
| New regression test (HP-A) | `home_astronomy_test.dart` — "never counts down to an UNPUBLISHED finish" |
| Home E2E (`.maestro/home.yaml`) | **pass**, 15 commands |
| Program E2E (`.maestro/program.yaml`) | **pass**, 29 commands |
| Combined Home+Program E2E | **pass**, 44 commands |

E2E is not part of `check.sh` (it needs a booted simulator); it was run against
an iPhone 17 Pro Max simulator via the Maestro MCP.

---

## 3. Home findings

- **HP-A (P1, fixed) — the Next-up card counted down to an unpublished finish.**
  `_NextUpCard` in `home_screen.dart` fed `TimeFormat.remaining(...)` for a
  `happeningNow` activity unconditionally. For a start-only activity (e.g.
  `kids-space`: real 4.15pm start, *stand-in* 10pm end) the card rendered
  "ends in N" — presenting the invented finish as fact. Fixed by gating on
  `entry.session.hasPublishedEnd`, the same guard the event/rail cards and My
  Night already apply. Regression test asserts the `TimingBadge.trailingText`
  is `null` for a start-only session at 7pm.
- **HP-E (cleanup, fixed) — dead `_PhasePill.now` field.** `_PhasePill` carried
  a `final DateTime now` that nothing read. Removed the field and its pass-site.

---

## 4. Program findings

- **HP-D (cleanup, fixed) — dead `.replaceFirst('ends ', '')`.** Three call
  sites (`event_card.dart`, `activity_rail_card.dart`, `my_night_screen.dart`)
  post-processed `TimeFormat.remaining(...)` to strip an "ends " prefix that the
  method stopped emitting after the i18n audit. The strip was a no-op on every
  input. Removed.
- **HP-F (correctness, fixed) — organiser time-preview could not reach the
  "ended" state.** `event_time_preview.dart` built its half-hourly chips with
  `for (h = startsAt.hour; h < endsAt.hour; h++)`, stopping at 9.30pm — so an
  organiser reviewing the app before the night could never preview the
  post-close "that's a wrap" UI. Added the 10pm close as an explicit final step.

---

## 5. Observations (product / design judgments — deliberately NOT auto-fixed)

- **HP-B — the Program time-band filter includes stand-in-window activities
  under every band.** `TimeBand.overlaps` (`event_filter.dart`) tests
  `s.start.isBefore(bandEnd) && s.end.isAfter(bandStart)` against the session's
  raw start/end, with no `hasPublishedEnd`/confidence check. For a genuine
  all-evening drop-in (Cosmic arcade, 4.15–9.30pm) this is **correct and
  helpful** — it really is available during 6–8pm, so it should appear under
  that chip. For a *fully unscheduled* activity (stand-in 16:00–22:00,
  `timeUnpublished`) the same logic makes it match all three bands, which is
  arguably placing an invented time under a specific band. But excluding such
  activities from every band would make them invisible to a band-filtering
  visitor — a worse outcome — and the card still shows "On the night" with the
  confidence flag. This is a UX call (show-under-every-band vs. show-under-none),
  not a correctness bug. **Recommendation: leave as-is unless organisers want
  unscheduled activities suppressed from time-band filtering.**
- **HP-C — `TimedEvent.isAllEvening` is tested but has no production caller.**
  Its doc comment says "The UI groups them separately", but no `lib/` code
  references it any more (a past refactor moved the grouping). It is *not* dead
  code to delete: `unpublished_time_test.dart` uses it to assert a real
  time-honesty invariant — that no fabricated-end activity is ever classified as
  an all-evening drop-in (`isAllEvening && !hasPublishedEnd` is always empty).
  Removing the getter would remove that guard. **Recommendation: keep; the doc
  comment's "the UI groups them" clause is mildly stale but harmless.**

---

## 6. Time-honesty invariant compliance

Verified the invariant holds across every Home/Program surface that renders a
countdown or a finish time:

| Surface | Guards the stand-in finish? |
|---|---|
| Home — Next-up card (`_NextUpCard`) | **now yes** (HP-A) |
| Home / Program — `EventCard` | yes (pre-existing `hasPublishedEnd`) |
| Home — `ActivityRailCard` | yes (pre-existing) |
| My Night — `my_night_screen` | yes (pre-existing) |
| `WhatsOnService.isAllEvening` | yes — requires `hasPublishedEnd` by construction |

No surface was found presenting a stand-in start or end as fact after HP-A.

---

## 7. l10n / bidi

- No hardcoded user-facing English introduced by any fix (HP-A/D/E/F touch only
  control flow around already-localised strings).
- Program event rows and the section header are merged multi-line a11y strings
  with **bidi-isolated** room/venue names (`⁨…⁩`, U+2068/U+2069). The E2E flows
  match them with `(?s).*…*` (DOTALL, isolate-absorbing) — the same trap the map
  suite documents.
- No new `int` placeholders were introduced (the `decimalPattern` requirement is
  unaffected).

---

## 8. Accessibility & professional UX

- The Program event card exposes one merged semantic label per row
  (category · timing · title · time · venue), which reads coherently to a screen
  reader; the favourite button carries its own "Save X to My Night" / "Remove X
  from My Night" label. No icon-only control was found without an accessible
  name.
- Search field placeholder ("Search talks, activities, presenters") is a real
  label; clearing search restores it (verified in E2E). The query **survives**
  navigating into an event detail and back — good state hygiene, now covered.

---

## 9. Fixed during the audit

| ID | File(s) | Change |
|---|---|---|
| HP-A | `home_screen.dart`, `home_astronomy_test.dart` | gate Next-up countdown on `hasPublishedEnd` + regression test |
| HP-D | `event_card.dart`, `activity_rail_card.dart`, `my_night_screen.dart` | drop the dead `.replaceFirst('ends ', '')` |
| HP-E | `home_screen.dart` | remove unused `_PhasePill.now` field |
| HP-F | `event_time_preview.dart` | add the 10pm close so preview can reach the "ended" state |
| — | `.maestro/home.yaml`, `.maestro/program.yaml` | add Home + Program E2E flows |

Commits (branch `fix/home-program-audit`): `1b6599b`, `20080dd`, `8288ec2`,
`5eb5693` (+ this report).

---

## 10. Remaining issues

- **HP-B** and **HP-C** above — product/design decisions, left for the user.
- No P1/P2 correctness defect remains open on Home or Program.

---

## 11. Final recommendation

Home and Program are **release-ready** on correctness and time-honesty. Ship the
four fixes; put HP-B (band-filtering of unscheduled activities) and HP-C (stale
doc comment on a retained invariant helper) to the organisers/product owner as
low-priority judgment calls, not blockers.
