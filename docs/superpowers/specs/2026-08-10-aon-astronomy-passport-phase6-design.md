# Astronomy Passport (scan + gamification) — Phase 6 design

Ported in spirit — not in code — from MQ Journey's `features/scan/` QR stamp
trail. The reuse analysis (`docs/mq-journey-reuse-analysis.md` §2) marked that
feature **DO NOT REUSE** for the MVP: it carried a signed-QR verification
scheme with private signing keys (~25 files) and leaned on Supabase/accounts.
This phase rebuilds the *experience* under this app's constraints — **no
backend, no accounts, no secrets** — keeping those rejections intact.

Status: **design — not yet approved for implementation.** No production code
until this is approved and a plan is written (writing-plans skill).

---

## 0. Revision history

- **v1** — initial design after brainstorming + self-gauntlet (13 findings).
- **v2 (this doc)** — Raouf's review applied: **9 findings, all adopted**, two
  with reinforcement, one correcting a v1 finding of my own. Every version fact
  re-verified against pub.dev and MQ Journey's lockfile (receipts in §16).

---

## 1. What we're building

An **Astronomy Passport**: attendees collect a stamp at each of the **9 event
venues (map legend A–I)** by scanning a QR code on the venue's sign — or typing
a short code from the same sign. Collect **all 9** and the app shows a live
completion screen to redeem a prize at a staffed booth.

The staff booth is the real gate. The app is an **honest tracker, not a vault**:
it makes the trail fun and keeps the count. It does **not** prove attendance and
does not treat its codes as secrets (§4.1). That is a deliberate, fully-honest
posture — chosen below.

### The 9 stamp stations

The `VenueCategory.eventVenue` set from `lib/data/venues_data.dart`:

| Legend | Venue |
|---|---|
| A | Macquarie Theatre |
| B | Mason Theatre |
| C | Central Courtyard |
| D | 14 Sir Christopher Ondaatje Avenue |
| E | 1 Central Courtyard |
| F | Sport and Aquatic Centre |
| G | Astronomical Observatory |
| H | 11 Wally's Walk |
| I | 17 Wally's Walk |

Registration/information/toilet/transport venues are **not** stations.

---

## 2. Decisions (from brainstorming)

| # | Decision | Choice |
|---|---|---|
| D1 | Core loop | **Stamp trail + real reward** (scan → collect → redeem) |
| D2 | Anti-cheat posture | **Human gate at the booth** — no crypto, no signing keys; codes are not secrets |
| D3 | Capture method | **Scan (QR) *and* manual code entry as equal peers**; camera permission requested lazily |
| D4 | Reward structure | **Single completion reward** (all 9) |
| D5 | Threshold | **All 9 event venues** |
| D6 | Placement | **Home card + Info-screen ("menu") entry** — **no 6th nav tab** |
| D7 | Reward-screen proof | **Live dynamic screen** as a *nudge*, explicitly not a security control |
| D8 | Celebration | **`confetti` package** (explicit dependency) |

### Explicitly NOT built (kept from the MVP rejections)

Signed-QR crypto · private signing keys · accounts · backend/Supabase · points ·
leaderboards · cross-device or cross-reinstall sync.

---

## 3. Architecture

### 3.1 First persisted mutable state — and it must never block startup

Verified: **this app persists nothing today.** Every provider in
`lib/services/providers.dart` is synchronous over `const` data; the only
`SharedPreferences` mention in `lib/` is a comment describing what MQ Journey
does and this app deliberately does *not* (`providers.dart:25`). The passport
introduces the app's **first** persisted mutable state, on an isolated seam.

**Hydration is best-effort and non-fatal *(review P1-3)*:**

```
startup
  → best-effort read of persisted snapshot (guarded)
      success → inject persisted Set<String>
      failure/absent → inject empty Set<String>   // NEVER blocks launch
  → build UI synchronously (no AsyncValue in the tree)
```

- A persistence read failure, timeout, or first run **must not prevent aon2026
  from launching.** Worst case is an empty passport, not a crash.
- **Writes return `Future`s and are non-fatal.** The in-memory `Set` is the
  source of truth for the session; persistence is a write-through cache. A
  failed write leaves the session correct and is surfaced only as a subtle,
  non-blocking "progress may not be saved on this device" note — never an error
  dialog, never a lost stamp mid-session. The UI does **not** become
  `AsyncValue`; only the write is async.
- **API selection at plan time.** The `shared_preferences` maintainers now
  describe the classic `SharedPreferences` API as legacy and steer new code to
  `SharedPreferencesAsync` / `SharedPreferencesWithCache`, and caution that the
  classic API's writes are not guaranteed. The plan picks the current
  recommended cached/async API; this design fixes only the *behaviour* above,
  not the class name.

`main()` already `await`s `GlassShaderCache.ensureLoaded()` (itself "non-fatal
by construction"); passport hydration follows the same non-fatal pattern.

### 3.2 The domain seam — typed input, one resolver  *(review P1-2)*

A single `resolve(String)` **cannot** honour the two input rules (a bare token
is valid from the keypad but a bare, un-namespaced string from the *scanner*
must be rejected). The boundary is therefore **typed by source**:

```
StampInput.scan(String rawQr)      // requires the AON2026: namespace
StampInput.manual(String rawCode)  // accepts the bare token

  resolveScan(rawQr):    strip+require "AON2026:" → token   (no namespace ⇒ unknown)
  resolveManual(rawCode): trim/upcase              → token

        both normalise to a token, then:

  resolveToken(String token, Set<String> alreadyCollected) → StampResult
      .collected(venueId)    // valid, newly added
      .alreadyHave(venueId)  // valid, already collected (idempotent)
      .unknown               // token not in the station table
```

All of `resolveScan` / `resolveManual` / `resolveToken` are **pure and
unit-tested with no camera hardware**. `PassportNotifier` calls the resolver,
applies the result, and persists (best-effort, §3.1). The scanner and the text
field are thin adapters that construct the right `StampInput`.

### 3.3 Routing

New pushed routes (not a tab branch), like `wayfinding`:

- `Routes.passport` — the passport grid screen.
- `Routes.passportScan` — the scan / enter-code capture screen.

---

## 4. Data model

```dart
// lib/models/stamp_station.dart
class StampStation {
  final String venueId;          // FK into VenuesData (one of the 9 eventVenues)
  final String code;             // event token printed on the sign (see §4.1)
  final DataConfidence codeConfidence;  // confirmed vs placeholder  (review P1-4)
}
```

```dart
// lib/data/stamp_stations_data.dart
abstract final class StampStationsData {
  static const List<StampStation> all = [ /* 9 entries */ ];
}
```

### 4.1 Codes are event tokens, NOT secrets  *(review P1-1 — reframed & honest)*

The QR payload and the manual code are the **same short token** (e.g. `K7Q2`),
one per station, namespaced in the QR as `AON2026:K7Q2`.

**They are not secrets and not proof of attendance.** An offline app that can
validate a code necessarily contains enough information to validate it, and this
app is open-source, so the tokens are recoverable by anyone who looks. Hashing
would not save this either: a 4-character token is trivially brute-forced
offline. So the design makes the honest claim:

> Station codes are **low-friction event tokens**. Their only jobs are to make
> the *physical trail the normal way to play* and to stop accidental/obvious
> completion. Inspecting, sharing, or extracting a code remains possible.
> **Staff redemption at the booth is the actual control.**

This is why anti-cheat is scored **4/10**, not higher (§12), and why a stronger
mechanism is a deferred, opt-in IOU (§13, IOU-2) rather than a claim made here.

The namespace still earns its keep: a foreign QR (no `AON2026:` prefix) is
rejected with a specific message rather than a generic "unknown code."

### 4.2 Confirmed vs placeholder  *(review P1-4)*

Codes are organiser-supplied. Until confirmed each ships as
`DataConfidence.placeholder`; confirmed codes are `DataConfidence.confirmed`
(or the project's equivalent reliable tier). The model carries this per station
so the release gate (§10) and the integrity test (§11) can enforce it.

### 4.3 Threshold = intersection, not raw count  *(review: approved)*

Completion is `collectedVenueIds ∩ {station venueIds}` having size 9 — never the
raw persisted set size. A stale or renamed persisted id can neither falsely
complete nor falsely block the trail.

---

## 5. Capture flow

Scan and manual entry are **equal peers** *(review P2-6)* — the capture screen
presents **"Scan"** and **"Enter code"** together; neither is reached only by
first hitting a permission wall.

- **Scan** → camera permission requested **only on first tap** → live scanner
  with a torch toggle (night use) and **debounce** (§7). On decode → resolve →
  apply → feedback.
- **Enter code** → text field for the sign's short code → same resolver.
- **Permission denied / no camera / web** → the Scan control explains and the
  already-present Enter code path carries on.
- **Same station twice** → `alreadyHave` → "You already have this one."
- **Foreign / garbage QR** → `unknown` → "That's not an Astronomy Open Night
  code."

### 5.1 Web is manual-only — a product choice, not a build necessity  *(review P2-5, corrects v1 B2)*

Re-verified (§16): `mobile_scanner` **7.4.0 supports Web**, and MQ Journey
already ships **7.2.0**. So the earlier claim that the scanner would break the
*web build* is **withdrawn** — a web-safe package imports fine on web. SP6 still
makes web **manual-entry-only**, but as a deliberate product decision for this
event, not a compile-safety workaround:

> SP6 intentionally disables QR scanning on web even though the selected scanner
> package supports web; **manual entry is the supported web experience.**

Mechanics: `kIsWeb` is a runtime guard and does **not** strip a static import,
but because the package is web-safe that's fine — the app simply does **not
instantiate** the scanner widget on web. A conditional import/adapter is
optional cleanliness, not a requirement. A web build check remains in the gate.

---

## 6. UI and entry points  *(no 6th tab — review: approved)*

The signature Liquid Glass nav stays at **5 tabs**. Verified: `LiquidTabBar`
lays tabs as equal `Expanded` slots with single-line ellipsized labels
(`liquid_tab_bar.dart:216, 263–270`) and has **no** icon-only/priority mode — a
6th tab would just shrink and ellipsize every label, worst at 2.0. So the
passport is reached from two non-nav entry points:

- **Home entry card** — a prominent tile showing live progress ("4 / 9 stamps")
  that pushes `Routes.passport`.
- **Info-screen entry** — the app has no standalone Settings screen (reuse
  analysis dropped `features/settings/`); the **Info** screen is the app's menu
  surface (`info_screen.dart`, a sectioned `ListView`). A passport entry — the
  same `FilledButton.icon` CTA pattern already used there for "Walking
  directions from parking" — sits near the top.

### 6.1 Passport grid is adaptive, not a frozen 3×3  *(review S-1)*

The grid must **not** be frozen as 3×3. Venue names such as "14 Sir Christopher
Ondaatje Avenue" under the permanent 2.0 text-scale contract need:

- **adaptive column count** (responsive to width and text scale), and
- **content-driven card height** (no fixed height that clips a wrapped name).

Verified at **320×568 / text scale 2.0** in the widget tests (§11), extending
the Phase 5 short-viewport regression.

---

## 7. Reward / completion + scan state machine  *(review P2-7)*

### 7.1 Scanner debounce

`mobile_scanner` can emit repeated detections for one physical code. Freeze:

```
first accepted decode
  → pause/lock the scanner
  → resolveScan exactly once
  → show the result
  → explicit resume (scan another) or dismiss
```

Idempotency of the stamp *set* is not enough on its own — without the pause a
single sign can fire multiple feedback/navigation events.

### 7.2 Completion fires from the transition, not a standing condition

The reward screen is triggered by the **successful transition result**, once:

```
resolveToken → StampResult.collected
  AND count was 8 before
  AND count is 9 after
      → emit completedNow  (exactly once)
```

It is **not** driven by a listener on `isComplete == true` — that would re-navigate
every time an already-complete app is opened ("route-popcorn"). Completion is a
persistent state: the reward screen is **re-openable any time** from the
passport, and a re-scan while already complete does **not** re-fire the
celebration or the takeover.

### 7.3 The reward screen itself

`confetti` burst + a live ticking clock + the event name.

**Honest framing** *(v1 C1, review: approved)*: the live clock is a **nudge**,
not a security control — a screen recording, handing over a phone, or reopening
all defeat it. The **staff member + wristband/lanyard is the actual control.**
The confetti **respects the reduced-motion setting** already wired through
Phase 3 `AonAnimations` (reduced motion ⇒ a static celebratory state).

---

## 8. Accessibility & text scale

- Full **2.0 text-scale** support on every new surface — grid (§6.1), capture,
  manual-entry field, reward — held to the Phase 5 discipline
  (`lib/app/text_scale.dart`, `kMaxTextScale`).
- **Manual entry is necessary but not sufficient for accessibility**
  *(review P2-6)*. A blind or low-vision attendee who cannot visually read the
  printed code gains nothing from a text field alone. The physical trail must
  participate — see the organiser requirement in §14.
- **Reduced motion** honored on the celebration (§7.3).
- Scanner and grid carry semantic labels; the grid announces collected count.

---

## 9. Dependencies, platform & manifests

New direct dependencies (6 → **9**), all **keyless, no secrets**, versions
pinned at plan time to the working MQ Journey baseline (§16) or newer as
verified:

| Dep | Why | Baseline proven in MQ Journey |
|---|---|---|
| `shared_preferences` | First persisted state (§3.1) | 2.5.5 |
| `mobile_scanner` | QR scanning | 7.2.0 (latest 7.4.0) |
| `confetti` | Completion celebration (§7.3) | 0.8.0 |

### 9.1 Scanner ↔ iOS minimum — likely no change  *(review P2-5)*

Verified: `IPHONEOS_DEPLOYMENT_TARGET = 13.0`
(`ios/Runner.xcodeproj/project.pbxproj`). The **6.0.0** line raised the minimum
to iOS 15.5, but the **7.x line brought Apple's minimum back to iOS 12**; iOS 15
now only gates *optional* features (e.g. best close-range lens, GS1 DataBar) with
fallbacks. So the v1 "declared bump to iOS 15" work is **withdrawn** — 13.0
likely stands. The plan pins a 7.x version and confirms with `flutter pub get` +
a build; any deployment-target change would be intentional and declared, not a
surprise.

### 9.2 Camera permission — concrete, precise manifest work  *(review S-2)*

- **iOS**: `NSCameraUsageDescription` in `Info.plist` (night-appropriate copy).
- **Android**: `<uses-permission android:name="android.permission.CAMERA"/>`
  **and** `<uses-feature android:name="android.hardware.camera"
  android:required="false"/>` — matching Android's guidance for optional camera
  hardware, so camera-less devices still install and use manual entry. The plan
  also checks whether **autofocus/flash** need explicit
  `android:required="false"` `<uses-feature>` entries for the same reason.
- **Store / privacy**: worded precisely — a permission alone does **not** mean
  data is "collected," and QR frames processed **only on-device** are outside
  Play "Data safety" collection. Disclosure copy:

  > Update privacy/store disclosures based on the final scanner SDK behaviour;
  > camera frames used only on-device for QR recognition are not automatically
  > "collected data."

The app's "usable with zero permissions" property is preserved *in substance*:
decline the camera and the whole passport still works via manual entry.

---

## 10. Release gate for codes  *(review P1-4)*

Placeholder/demo codes must be **impossible to activate in a production
release**:

> **Release builds must not enable prize passport collection while any station
> code is `placeholder`/unconfirmed.**

- **Release**: fails safe — if any of the 9 codes is unconfirmed, prize
  collection is not enabled (the feature can still show an honest "coming soon /
  see staff" state rather than collecting against demo codes).
- **Debug**: may carry demo codes and a "collect all" affordance (§11 demo path)
  for pre-event QA.

Enforced by the integrity test in §11.

---

## 11. Testing strategy

- **Resolver (pure)**: `resolveManual("K7Q2")` → `collected`; `resolveScan("AON2026:K7Q2")`
  → `collected`; **`resolveScan("K7Q2")` (no namespace) → `unknown`**; duplicate
  → `alreadyHave`; foreign/unknown token → `unknown`; 8→9 transition detected.
- **`PassportNotifier`**: persistence round-trip via in-memory prefs;
  **hydration failure ⇒ empty set, app still builds** (§3.1); **write failure ⇒
  session state intact, non-fatal**; idempotent add; intersection completion
  (§4.3) incl. a stale-id case.
- **Release integrity test** *(P1-4)*: 9 unique event venues; 9 unique codes; **0
  placeholder codes in a release configuration**; all `venueId`s exist in
  `VenuesData`; completion threshold == confirmed-station-set size.
- **Grid** *(S-1)*: empty / partial / complete; adaptive columns + no clip at
  **320×568 / 2.0**.
- **Reward / state machine** *(P2-7)*: `completedNow` fires once on 8→9;
  re-openable; no re-fire on re-scan; reduced-motion static path; scanner
  debounce (one decode ⇒ one resolve/feedback).
- **Entry points**: Home card and Info entry both navigate to `Routes.passport`.
- **Web build**: builds green with the scanner un-instantiated on web; capture
  screen shows manual-only.
- **A11y/scale**: new surfaces pass at 2.0; manual entry reachable by screen
  reader without the camera.

No test relies on real camera hardware — the §3.2 seam is what makes that true.

### 11.1 Demo & reset before event night  *(v1 C8, review: approved)*

- **Reset** — a documented control to clear passport progress (shared demo
  devices, repeat runs).
- **Demo path** — a **debug-only** "collect all" (compiled out of release, per
  §10) and/or the 9 test codes handed to staff, so the trail and reward are
  exercisable end-to-end before the night.

---

## 12. Honest scorecard

Scored now; re-scored at closeout (scores may drop — that's a feature).

| Axis | Score | What moves it higher (named, buildable) |
|---|---:|---|
| Anti-cheat integrity (human-gate) | **4/10** | Codes are event tokens, not secrets (§4.1); sharing/extraction is possible by design. Higher = IOU-2 (signed/rotating offline-verifiable codes), explicitly deferred. |
| A11y & 2.0 parity | **7/10** | Manual entry as a peer + reduced motion + 2.0 + adaptive grid. **Ceiling now includes the physical trail** (§14) — screen-side a11y alone can't reach higher. |
| Keyless / no-secrets fidelity | **8/10** | Still no backend/keys; camera is the one concession, softened by manual entry. |
| Testability | **8/10** | Pure resolver decoupled from camera; release integrity + failure-mode tests. Higher = golden-image reward test + a Maestro collect→reward flow. |
| Ambition / species | **3/10** | A stamp rally is recombination, not a new kind of thing. Higher = IOU-1 (micro science moments). Stated, not inflated. |
| Robustness (startup/persistence) | **7/10** | Non-fatal hydrate + defined write-failure (§3.1). Higher = an integration test that injects a prefs failure and asserts launch. |

---

## 13. IOU ledger

- **IOU-1 — Educational layer (the 10/10 delta).** Each stamp reveals a *micro
  science moment* (a fact, an observing target, "look up and find X"). Turns a
  checkbox rally into a guided astronomy experience. **Deferred**: D1 chose
  reward over educational-quest; logged so the ceiling is named, not lost.
- **IOU-2 — Stronger anti-cheat if the prize value rises.** Signed or rotating
  offline-verifiable codes (baked *public* key; still keyless). Revisit only if
  the prize becomes scarce/valuable enough to defend (D2 says it isn't).
- **IOU-3 — Cross-device / cross-reinstall progress.** Explicitly **NOT** done:
  one-night event, one device. Would require identity/backend the app has chosen
  never to have.

---

## 14. Open questions for the organisers (placeholders)

Modeled as `placeholder` until confirmed — the app never guesses:

1. The **9 station codes** (and confirmation the QR/signage will physically
   exist on the night). Until confirmed, the release gate (§10) keeps prize
   collection off.
2. The **actual prize** and where the booth is.
3. **Accessible codes** *(review P2-6)*: station codes must be available in an
   accessible form — staff assistance, large high-contrast print, and/or a
   spoken/tactile alternative — so a blind or low-vision attendee can obtain a
   code without reading signage unaided. Manual entry must not assume unaided
   visual reading of the sign.
4. Whether the **Observatory (G)** — a ~10-minute walk on cold open ground —
   stays a required station or becomes optional. (Design ships "all 9";
   softening to "any N" is a one-line threshold change.)

---

## 15. Next step

On approval → **writing-plans skill** for the TDD implementation plan (one task
cluster per §11 test group, gated). No implementation before that plan is
written and reviewed.

---

## 16. Verification receipts (v2)

- **No existing persistence**: `grep -rn shared_preferences lib/` → only the
  descriptive comment at `providers.dart:25`.
- **Tab bar has no icon-only mode**: `liquid_tab_bar.dart:216` (equal `Expanded`
  slots), `:263–270` (single-line ellipsized labels).
- **iOS deployment target 13.0**: `ios/Runner.xcodeproj/project.pbxproj`.
- **MQ Journey lockfile** (`MQ_Journey/pubspec.lock`): `mobile_scanner 7.2.0`,
  `confetti 0.8.0`, `shared_preferences 2.5.5` — the proven baseline.
- **pub.dev `mobile_scanner`** (fetched 2026-08-10): latest **7.4.0**; platforms
  **Android/iOS/macOS/Web** (Linux/Windows unsupported); iOS 15 only for optional
  features with fallback — no hard 7.x minimum above 12. → withdraws v1 B2 (web
  build break) and the v1 "iOS 15 bump" work.

---

## 17. Implementation verification results (Phase 6 executed)

Executed on branch `feature/astronomy-passport-phase6`, 14 tasks (0–13),
Flutter 3.44.7.

- **Resolved dependency versions:** `shared_preferences 2.5.5`,
  `mobile_scanner 7.4.0`, `confetti 0.8.0`,
  `shared_preferences_platform_interface 2.4.2` (dev, for the real-adapter test).
- **iOS deployment target:** **unchanged at 13.0** — `mobile_scanner` 7.x
  requires no bump (confirms §9.1; the v1 "bump to 15" work was correctly
  withdrawn).
- **Tests:** baseline 266 → **309 passing** (43 new passport tests); `flutter
  analyze` clean throughout.
- **Builds:** `flutter build web` ✅, `flutter build ios --no-codesign` ✅,
  `flutter build apk --debug` ✅ — all green with the three new deps.
- **Web:** builds with the scanner present and `kIsWeb`-guarded (never
  instantiated) — confirms the withdrawn B2.
- **iOS runtime (simulator, iPhone 17 Pro, iOS 26 point-space 402×874):**
  passport card on Home ✅; adaptive 9-cell grid + progress ✅; opening the
  capture screen shows **no camera permission prompt** (lazy) ✅; Scan / Enter-code
  equal peers ✅; manual entry collects a stamp ("Stamp collected!") ✅; "Scan
  another" resume ✅; grid reflects 1/9 with the venue marked ✅; **progress
  persists across a full app relaunch** (real SharedPreferences round-trip on
  device) ✅.
- **Still requires a PHYSICAL iOS device** (the simulator has no camera): real
  QR decode, torch toggle, and the live permission grant/deny flow. The pure
  resolver, the injected-scanner QR→collect integration test, and the on-device
  lazy-permission + persistence checks cover everything else.
