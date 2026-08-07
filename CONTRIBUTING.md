# Contributing

## Setup

```bash
flutter pub get
```

That is all. There is no `.env` to create, no key to obtain, no backend to run.
If something needs one of those, it is a scope change — see
`docs/project-scope.md`.

Requires Flutter `3.44.0` (Dart `3.11+`). Check with `flutter --version`.

## Before you push

```bash
flutter analyze && flutter test
```

Both must be clean. Lints are configured in `analysis_options.yaml`.

## Branches

| Branch | Purpose |
|---|---|
| `main` | Stable. Only merged from `develop` via PR |
| `develop` | Integration branch. Default target for PRs |
| `feature/*` | New work — `feature/personal-schedule` |
| `fix/*` | Bug fixes — `fix/west-6-coordinate` |

```bash
git switch develop
git switch -c feature/your-thing
# ... work ...
git switch develop && git merge --no-ff feature/your-thing
```

## House rules

These are the ones that are specific to this project. Everything else is
ordinary Flutter practice.

### 1. Never re-add the Huntsman Telescope Exploratorium

Room 109, 1 Central Courtyard. It is printed in the official PDF programme and
marked on the official map, but the organisers confirmed it is **cancelled**.

This is the only place where the source material is the wrong answer. If you
are reconciling `lib/data/events_data.dart` against the PDF and notice it
missing, that is intentional.
`test/unit/huntsman_exclusion_test.dart` will fail if you add it.

### 2. Never call `DateTime.now()`

Read `currentTimeProvider` instead. The event is in the future, so anything
that reads the wall clock directly is untestable and undemonstrable.

### 3. Never invent a coordinate

If the supplied materials do not give a location, leave it `null` and set
`DataConfidence.placeholder` with a note explaining what is missing. The UI
renders a warning automatically.

A confident pin in the wrong place is worse at night than no pin. West 6 is
the live example: the official map labels it twice, so it ships with no
coordinate on purpose, and a test pins that.

### 4. Mark provenance

Anything added to `lib/data/` needs a `sourceNote` or a comment saying where it
came from, and a matching row in `docs/data-sources.md`.

### 5. `null` accessibility means unknown, not "no"

`WalkingRoute.isAccessible` is `bool?`. Rendering `null` as "not step-free"
would tell a wheelchair user a viable route is unusable. It renders as "not yet
confirmed".

### 6. Keep it dark

No light theme. The event runs to 10pm next to telescopes; a white screen
destroys the dark adaptation of everyone nearby. Use `AonColors` tokens rather
than literal `Color(0x...)` values.

### 7. Colour is never the only signal

Every category and status also carries a distinct icon — for colour-blind
users and for phones with night-shift filters on.

### 8. No new dependencies without discussion

Six direct dependencies, zero credentials, zero runtime permissions. That is a
deliberate property of this repository, not an accident. See
`docs/mq-journey-reuse-analysis.md` for what was left behind and why.

## MQ Journey

MQ Journey is a **read-only reference**. Do not modify it, do not depend on it
at runtime, and do not copy secrets or `.env` values from it.

Its useful patterns have already been extracted. Note that some of its code
predates Riverpod 3 and uses the removed `StateProvider` — verify any API
before copying it across.

## Adding an event

```dart
AonEvent(
  id: 'kebab-case-id',
  title: 'Exactly as printed in the official programme',
  description: 'Official description, verbatim.',
  category: EventCategory.activity,
  venueId: 'must-match-a-venue-id',   // enforced by data_integrity_test
  room: 'Room 123',
  mapReference: 'D',                   // printed map legend letter
  bookingRequired: false,
  tags: ['searchable', 'keywords'],
  sourceNote: 'Programme p.2 — "4.15pm – 9.30pm".',
  sessions: [
    EventSession(start: EventInfo.at(16, 15), end: EventInfo.at(21, 30)),
  ],
)
```

Multiple sessions go in the list — do **not** create separate events for the
same activity running twice.

If the programme gives no finish time, set
`timeConfidence: DataConfidence.placeholder` and a `note` explaining it.
A test enforces that.
