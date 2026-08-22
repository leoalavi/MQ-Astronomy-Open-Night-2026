# Store Release — App-Code Compliance & Reviewability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make aon2026's app code truthful, consent-correct and reviewable by a
reviewer who is not on Macquarie campus, so it can be submitted to the App Store
and Google Play.

**Architecture:** One invariant drives most of this — no Google surface capable of
transmitting data may initialise before consent resolves positively. That is
enforced structurally by a `mapsSdkReadyProvider` that simply never calls the
native initialiser unless consent is `accepted`, rather than by discipline at each
call site. Around it sit honest privacy copy, a second (map-only) disclosure whose
wording matches what that surface actually does, local-data deletion, and the
off-campus states that let App Review exercise a campus app from Cupertino.

**Tech Stack:** Flutter 3.44.7 / Dart ^3.11, Riverpod 3 (hand-written providers,
no codegen), `google_maps_flutter`, `flutter_map` 8.3.1, `shared_preferences`,
`flutter_test`.

**Spec:** `docs/superpowers/specs/2026-08-22-app-store-release-program-design.md`
(revision 3). Read it before starting; this plan argues from it.

**Companion plan:** release mechanics (§4 signing, §5a credentials, §6 store
metadata) is a separate checklist-shaped plan, not this document. Nothing here
requires the GCP keys to exist.

## Global Constraints

Every task's requirements implicitly include this section.

- **Riverpod 3.** Use a `Notifier<T>` exposing a **method** (`set`, `toggle`,
  `select`) — never external `.state =`.
  `AsyncValue.valueOrNull` is NOT in the resolved core: use `.asData?.value`.
- **Every new string needs EN *and* FA.** `lib/l10n/app_en.arb` +
  `lib/l10n/app_fa.arb`. Placeholders require an `@key` metadata block in EN.
  Real Persian, never machine-fill. `flutter gen-l10n` after editing.
- **Theme tokens only.** `context.aon.*` (`lib/app/theme/aon_palette.dart`) for
  chrome; `AonSpacing.spaceN`; `AonSpacing.minTapTarget` = 56.
- **Accessibility bar.** 320×568 at textScale 2.0 must not overflow. For icon
  buttons the **tooltip IS the accessible name** — assert with
  `find.byTooltip(...)`, never `find.bySemanticsLabel(...)`.
- **Data honesty.** `DataConfidence { confirmed, derived, placeholder }`. Never
  invent coordinates. Unknowns stay null and are surfaced.
- **Persistence idiom.** Inject a pre-loaded snapshot + store via `ProviderScope`
  overrides in `main.dart`, seed a sync `Notifier`, serialize writes through a
  single `Future` chain, never throw on failure. See `maps_consent_*`.
- **Lints.** `(_, _)` not `(_, __)` (`unnecessary_underscores`). `dart:typed_data`
  is re-exported by `flutter/services.dart` (`unnecessary_import`).
- **Async I/O in widget tests.** `rootBundle.load*` / `decodeImageFromList` do real
  async I/O and hang a `testWidgets` fake-async zone to a 10-minute timeout unless
  wrapped in `await t.runAsync(() async { ... })`.
- **The commit gate is exit-code-gated, never piped:**
  ```bash
  ./scripts/check.sh > /tmp/gate.log 2>&1 && git add … && git commit … || { echo "GATE FAILED"; tail /tmp/gate.log; }
  ```
  `check.sh | tail && git commit` is a trap — the pipeline's status is `tail`'s, so
  a red analyze/test still commits. This landed two red commits in M3.
- **Prove the shipped wiring, not a stand-in.** Review round 2 found this same
  defect five times: a test that exercises a helper, a getter or a wrapper while
  the production path stays unproven. A localisation getter test does not prove
  the screen renders it; a wrapper test does not prove the provider returns the
  wrapper; a `RouteMapForTest` test does not prove `GoogleNavScreen` is gated.
  **Every task must contain at least one test that drives the real widget or the
  real provider container.** If a task only asserts on a helper, it is not done.
- **Riverpod legacy APIs are not used in this repo.** `StateProvider`,
  `StateNotifierProvider` and `ChangeNotifierProvider` were *moved* to
  `package:flutter_riverpod/legacy.dart` in Riverpod 3, not deleted. The
  rule here is a project convention, not a language fact: use a `Notifier` with a
  method, and never reach for `package:flutter_riverpod/legacy.dart`.
- **`dart format` is informational only.** The whole repo fails it under the 3.12
  tall style. Never blanket-reformat.

## Sequencing, sizing, and the cut rule

19 days remain to 19 Sep, shared with the release-mechanics plan. Sizes are
working hours for one engineer, including the test cycle and the gate run.

| Task | Size | Tier | Blocks |
|---|---|---|---|
| 0 · shared map test harness | 2h | 1 | 8, 12 |
| 1 · defer Maps SDK init | 3h | 1 | 2, 4 |
| 2 · readiness gated on consent | 2h | 1 | 4, 15 |
| 3 · map-only disclosure | 2h | 1 | 4 |
| 4 · wayfinding + nav on Google | 5h | 1 | 5 |
| 5 · attribution truth-up | 3h | 1 | — |
| 6 · delete local data | 6h | 1 | — |
| 7 · privacy copy EN+FA | 2h | 1 | — |
| 13 · Routes consent guard | 4h | 1 | — |
| 15 · architecture test | 1h | 1 | — |
| **Tier 1 subtotal** | **30h** | | **submission-blocking** |
| 8 · off-campus notice | 3h | 2 | — |
| 9 · campus radius + copy | 3h | 2 | — |
| 10 · pre-event message | 2h | 2 | — |
| 11 · preview from anywhere | 6h | 2 | — |
| **Tier 2 subtotal** | **14h** | | **the Guideline 2.1 defence** |
| 12 · iPad, 9 routes x EN/FA | 10h + fixes | 3 | — |
| 14 · legal notices | 3h | 3 | — |
| **Total** | **~57h ≈ 8 working days** | | |

**Tier 1 is what makes the app truthful and consent-correct** — without it the
app ships claims that are false. Tier 2 is what lets App Review exercise a
campus app from Cupertino; skipping it risks a 2.1 rejection cycle costing 5-10
days, which is worse than the 14 hours. Tier 3 is real but severable.

**The cut rule, decided now rather than in week three.** Task 12 is the only
task with an unbounded tail: the overflow fix count is unknown until it runs.
If Tier 1 + 2 are not complete with 7 days left, **drop iPad** — set
`TARGETED_DEVICE_FAMILY = "1"` in all three configurations. That is a one-line
change per configuration, it removes the 13" screenshot requirement entirely,
and it deletes Task 12 outright. The app is explicitly designed for one-handed
use while walking in the dark; iPhone-only is a defensible product decision, not
a retreat. Task 14 goes with it (iOS licence text is the only surviving half,
and it is 3h whenever it happens).

Nothing in Tier 1 is cuttable. If Tier 1 cannot land, the submission slips —
that is the honest trade, and it is better made in advance.

---

### Task 0: Promote the map test harness to shared support

Tasks 8 and 12 both need to pump `MapScreen` with a chosen fix.
`test/widget/map_platform_wiring_test.dart:19` already has
`ProviderContainer _container(FakeLocationService svc)` — private to that file.
Copying it twice is how harnesses drift.

**Files:**
- Create: `test/support/map_harness.dart`
- Modify: `test/widget/map_platform_wiring_test.dart`

**Interfaces:**
- Produces: `mapHarness({UserLocationFix? fix})` returning a `ProviderContainer`
  with `locationServiceProvider` overridden by a `FakeLocationService` seeded
  with `fix`, and `mapVisibleProvider` set true. Tasks 8 and 12 consume it.

- [ ] **Step 1: Move the helper**

Create `test/support/map_harness.dart` containing `FakeLocationService` and the
container builder, lifted verbatim from `map_platform_wiring_test.dart` lines
1-40 and widened:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/models/user_location_fix.dart';
import 'package:aon2026/services/location_providers.dart';
import 'package:aon2026/services/location_service.dart';

/// The shared map harness. Lifted from map_platform_wiring_test.dart so Tasks 8
/// and 12 do not each grow their own copy.
class FakeLocationService implements LocationService {
  FakeLocationService({this.fix});

  final UserLocationFix? fix;

  @override
  Future<LocationStatus> status() async => LocationStatus.granted;
  @override
  Future<LocationStatus> request() async => LocationStatus.granted;
  @override
  Stream<UserLocationFix> watch() =>
      fix == null ? const Stream<UserLocationFix>.empty() : Stream.value(fix!);
  @override
  Stream<bool> serviceEnabledChanges() => const Stream<bool>.empty();
  @override
  Future<void> openAppSettings() async {}
  @override
  Future<void> openLocationSettings() async {}
}

/// A container ready to pump `MapScreen` against a chosen position.
ProviderContainer mapHarness({UserLocationFix? fix}) {
  final container = ProviderContainer(overrides: [
    locationServiceProvider.overrideWithValue(FakeLocationService(fix: fix)),
  ]);
  container.read(mapVisibleProvider.notifier).set(true);
  container.read(locationControllerProvider);
  return container;
}
```

If the existing `FakeLocationService` in `map_platform_wiring_test.dart` has a
different shape, move *that* one and add the `fix` parameter — do not invent a
second implementation.

- [ ] **Step 2: Point the existing test at it**

In `test/widget/map_platform_wiring_test.dart`, delete the local
`FakeLocationService` and `_container`, and
`import 'package:aon2026/../test/support/map_harness.dart';` — use the package
relative form the repo's other test helpers use.

- [ ] **Step 3: Prove nothing regressed**

Run: `flutter test test/widget/map_platform_wiring_test.dart`
Expected: PASS, same test count as before the move.

- [ ] **Step 4: Run the full gate and commit**

```bash
./scripts/check.sh > /tmp/gate.log 2>&1 && {
  git add test/support/map_harness.dart test/widget/map_platform_wiring_test.dart
  git commit -m "test: promote the map harness to shared support"
} || { echo "GATE FAILED"; tail -30 /tmp/gate.log; }
```

---

### Task 1: Defer the native Maps SDK behind consent

The architectural core. `ios/Runner/AppDelegate.swift` currently calls
`GMSServices.provideAPIKey` inside `didFinishLaunchingWithOptions` — at launch,
before any UI and before any consent. The `!key.isEmpty` guard only made that
harmless while the app shipped keyless; once the keys ship it becomes a
launch-time Google SDK initialisation for every user.

**Files:**
- Create: `lib/services/maps_sdk_initializer.dart`
- Create: `test/unit/maps_sdk_initializer_test.dart`
- Modify: `ios/Runner/AppDelegate.swift`
- Modify: `android/app/src/main/kotlin/au/edu/mq/astronomy/aon2026/MainActivity.kt`

**Interfaces:**
- Consumes: `mapsConsentProvider` / `MapsConsent` from
  `lib/services/maps_consent_store.dart` and `lib/services/maps_consent_providers.dart`.
- Produces: `MapsSdkInitializer` (abstract interface, `Future<bool> ensureInitialized()`),
  `PlatformMapsSdkInitializer`, `mapsSdkInitializerProvider`,
  and `mapsSdkReadyProvider` (`FutureProvider<bool>`). Tasks 4 and 5 gate on
  `mapsSdkReadyProvider`.

- [ ] **Step 1: Write the failing test**

Create `test/unit/maps_sdk_initializer_test.dart`:

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/services/maps_sdk_initializer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('aon2026/maps_sdk');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('ensureInitialized invokes initialize exactly once', () async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return true;
    });

    final init = PlatformMapsSdkInitializer();
    expect(await init.ensureInitialized(), isTrue);
    expect(await init.ensureInitialized(), isTrue);
    expect(calls, ['initialize'], reason: 'second call must be a no-op');
  });

  test('a PlatformException returns false and does not latch as done', () async {
    var attempts = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      attempts++;
      if (attempts == 1) throw PlatformException(code: 'NO_KEY');
      return true;
    });

    final init = PlatformMapsSdkInitializer();
    expect(await init.ensureInitialized(), isFalse);
    expect(await init.ensureInitialized(), isTrue,
        reason: 'a failed attempt must be retryable, not cached as failure');
    expect(attempts, 2);
  });

  test('a missing platform handler returns false rather than throwing', () async {
    // No mock handler registered at all.
    final init = PlatformMapsSdkInitializer();
    expect(await init.ensureInitialized(), isFalse);
  });

  test('a null result from the platform is treated as not initialised', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => null);
    final init = PlatformMapsSdkInitializer();
    expect(await init.ensureInitialized(), isFalse);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/unit/maps_sdk_initializer_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'aon2026' ... maps_sdk_initializer.dart` / `Undefined name 'PlatformMapsSdkInitializer'`.

- [ ] **Step 3: Write the minimal implementation**

Create `lib/services/maps_sdk_initializer.dart`:

```dart
import 'package:flutter/services.dart';

/// Initialises the native Google Maps SDK on demand.
///
/// Deliberately NOT called at app launch. Spec §2b: no Google surface capable of
/// transmitting user or location data may initialise before consent resolves
/// positively. `AppDelegate` used to call `GMSServices.provideAPIKey` in
/// `didFinishLaunchingWithOptions`, which no render-time consent gate can catch.
abstract interface class MapsSdkInitializer {
  /// Idempotent on success. Returns true when the SDK is (now) initialised.
  /// A failure is NOT cached — a later attempt may succeed.
  Future<bool> ensureInitialized();
}

class PlatformMapsSdkInitializer implements MapsSdkInitializer {
  PlatformMapsSdkInitializer({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('aon2026/maps_sdk');

  final MethodChannel _channel;
  bool _initialized = false;

  @override
  Future<bool> ensureInitialized() async {
    if (_initialized) return true;
    try {
      final ok = await _channel.invokeMethod<bool>('initialize');
      _initialized = ok ?? false;
      return _initialized;
    } on PlatformException {
      return false; // retryable; never latched
    } on MissingPluginException {
      return false; // unsupported platform / test host
    }
  }
}

/// A no-op initialiser for tests and unsupported platforms.
class NoopMapsSdkInitializer implements MapsSdkInitializer {
  const NoopMapsSdkInitializer();
  @override
  Future<bool> ensureInitialized() async => false;
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/unit/maps_sdk_initializer_test.dart`
Expected: PASS — 4 tests.

- [ ] **Step 5: Move the iOS init off launch**

Replace `ios/Runner/AppDelegate.swift` in full:

```swift
import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Latched once GMSServices has been keyed. GMSServices cannot be
  /// un-initialised, which is why the app-level invariant (spec §2c) is enforced
  /// above the SDK: revocation blocks surfaces and requests, it does not pretend
  /// to tear the SDK down.
  private var mapsSdkInitialized = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Spec §2b: NO GMSServices.provideAPIKey here. Initialisation is deferred to
    // the "initialize" method call, which Dart only issues once maps consent has
    // resolved positively.
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AonMapsSdk") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "aon2026/maps_sdk",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "initialize" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(self?.initializeMapsSdk() ?? false)
    }
  }

  private func initializeMapsSdk() -> Bool {
    if mapsSdkInitialized { return true }
    guard let key = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
          !key.isEmpty else {
      return false // built without the secret → feature stays dark
    }
    GMSServices.provideAPIKey(key)
    mapsSdkInitialized = true
    return true
  }
}
```

- [ ] **Step 6: Add the Android handler**

Replace `android/app/src/main/kotlin/au/edu/mq/astronomy/aon2026/MainActivity.kt` in full:

```kotlin
package au.edu.mq.astronomy.aon2026

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Android has no deferrable Maps SDK init: the SDK reads
        // com.google.android.geo.API_KEY from the manifest when a MapView is
        // first constructed. The spec §2b invariant is therefore enforced by not
        // CONSTRUCTING a map view before consent — mapsSdkReadyProvider does
        // that. This handler only reports whether a key is present, so Dart's
        // readiness check means the same thing on both platforms.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "aon2026/maps_sdk"
        ).setMethodCallHandler { call, result ->
            if (call.method == "initialize") {
                result(hasMapsApiKey())
            } else {
                result.notImplemented()
            }
        }
    }

    private fun hasMapsApiKey(): Boolean = try {
        val info = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
        !info.metaData?.getString("com.google.android.geo.API_KEY").isNullOrEmpty()
    } catch (_: PackageManager.NameNotFoundException) {
        false
    }
}
```

- [ ] **Step 7: Run the full gate and commit**

```bash
./scripts/check.sh > /tmp/gate.log 2>&1 && {
  git add lib/services/maps_sdk_initializer.dart \
          test/unit/maps_sdk_initializer_test.dart \
          ios/Runner/AppDelegate.swift \
          android/app/src/main/kotlin/au/edu/mq/astronomy/aon2026/MainActivity.kt
  git commit -m "feat(maps): defer native Maps SDK init off app launch"
} || { echo "GATE FAILED"; tail -30 /tmp/gate.log; }
```

---

### Task 2: Gate SDK readiness on consent

Task 1 built the initialiser. This wires it so it is structurally impossible to
call before consent is `accepted` — the invariant lives in one provider rather
than in discipline at each call site.

**Files:**
- Modify: `lib/services/maps_sdk_initializer.dart`
- Create: `test/unit/maps_sdk_ready_provider_test.dart`

**Interfaces:**
- Consumes: `MapsSdkInitializer` (Task 1), `mapsConsentProvider`, `MapsConsent`.
- Produces: `mapsSdkInitializerProvider` (`Provider<MapsSdkInitializer>`) and
  `mapsSdkReadyProvider` (`FutureProvider<bool>`). Tasks 4 and 5 watch
  `mapsSdkReadyProvider` and render a Google surface only when it resolves true.

- [ ] **Step 1: Write the failing test**

Create `test/unit/maps_sdk_ready_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/services/maps_consent_providers.dart';
import 'package:aon2026/services/maps_consent_store.dart';
import 'package:aon2026/services/maps_sdk_initializer.dart';

class _CountingInitializer implements MapsSdkInitializer {
  int calls = 0;
  @override
  Future<bool> ensureInitialized() async {
    calls++;
    return true;
  }
}

ProviderContainer _container(_CountingInitializer init, MapsConsent seed) {
  final c = ProviderContainer(overrides: [
    mapsSdkInitializerProvider.overrideWithValue(init),
    mapsConsentSnapshotProvider.overrideWithValue(seed),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('unknown consent never touches the initializer', () async {
    final init = _CountingInitializer();
    final c = _container(init, MapsConsent.unknown);

    expect(await c.read(mapsSdkReadyProvider.future), isFalse);
    expect(init.calls, 0, reason: 'spec §2b: no init before consent resolves');
  });

  test('declined consent never touches the initializer', () async {
    final init = _CountingInitializer();
    final c = _container(init, MapsConsent.declined);

    expect(await c.read(mapsSdkReadyProvider.future), isFalse);
    expect(init.calls, 0);
  });

  test('accepted consent initializes exactly once', () async {
    final init = _CountingInitializer();
    final c = _container(init, MapsConsent.accepted);

    expect(await c.read(mapsSdkReadyProvider.future), isTrue);
    expect(init.calls, 1);
  });

  test('accepting after decline initializes; revoking then reports not ready',
      () async {
    final init = _CountingInitializer();
    final c = _container(init, MapsConsent.unknown);

    expect(await c.read(mapsSdkReadyProvider.future), isFalse);
    expect(init.calls, 0);

    c.read(mapsConsentProvider.notifier).accept();
    expect(await c.read(mapsSdkReadyProvider.future), isTrue);
    expect(init.calls, 1);

    c.read(mapsConsentProvider.notifier).revoke();
    expect(await c.read(mapsSdkReadyProvider.future), isFalse,
        reason: 'revocation must report not-ready even though GMSServices '
            'cannot be un-initialised');
    expect(init.calls, 1, reason: 'revocation must not re-initialise');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/unit/maps_sdk_ready_provider_test.dart`
Expected: FAIL — `Undefined name 'mapsSdkInitializerProvider'` and `'mapsSdkReadyProvider'`.

- [ ] **Step 3: Write the minimal implementation**

Append to `lib/services/maps_sdk_initializer.dart`:

```dart
// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Overridden in `main.dart` with [PlatformMapsSdkInitializer]; tests inject a
/// fake. Defaults to the no-op so a forgotten override fails closed (no Google
/// surface) rather than open.
final mapsSdkInitializerProvider =
    Provider<MapsSdkInitializer>((_) => const NoopMapsSdkInitializer());

/// Whether a Google map surface may be constructed.
///
/// This provider is the spec §2b invariant's single enforcement point: it
/// short-circuits on consent before touching the initialiser, so every call site
/// that goes through it is safe by construction.
///
/// It is not a hermetic seal — `mapsSdkInitializerProvider` is still readable,
/// so a call site could bypass this and call `ensureInitialized()` directly.
/// Task 15 adds an architecture test that fails if anything outside this file
/// does.
final mapsSdkReadyProvider = FutureProvider<bool>((ref) async {
  final consent = ref.watch(mapsConsentProvider);
  if (consent != MapsConsent.accepted) return false;
  return ref.read(mapsSdkInitializerProvider).ensureInitialized();
});
```

And add these imports at the top of the same file, below the existing
`package:flutter/services.dart` import:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'maps_consent_providers.dart';
import 'maps_consent_store.dart';
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/unit/maps_sdk_ready_provider_test.dart`
Expected: PASS — 4 tests.

- [ ] **Step 5: Wire the real initialiser in main**

In `lib/main.dart`, find the `ProviderScope(overrides: [...])` list that already
contains `mapsConsentSnapshotProvider.overrideWithValue(...)` (around line 105)
and add one entry to it:

```dart
        mapsSdkInitializerProvider.overrideWithValue(PlatformMapsSdkInitializer()),
```

Add the import to `lib/main.dart`:

```dart
import 'package:aon2026/services/maps_sdk_initializer.dart';
```

- [ ] **Step 6: Run the full gate and commit**

```bash
./scripts/check.sh > /tmp/gate.log 2>&1 && {
  git add lib/services/maps_sdk_initializer.dart \
          test/unit/maps_sdk_ready_provider_test.dart \
          lib/main.dart
  git commit -m "feat(maps): gate SDK readiness on accepted consent"
} || { echo "GATE FAILED"; tail -30 /tmp/gate.log; }
```

---

### Task 3: A second, truthful disclosure for map-only surfaces

`showMapsNavDisclosure` says *"your current location is sent to Google Maps"*.
That is true on the nav screen and **false** on wayfinding, which reads no
location at all (`wayfinding_screen.dart` has zero location references; its routes
are hand-authored per `walking_route.dart:22-29`). Reusing it would assert a
privacy harm that does not occur — a 2.3 accuracy failure with the sign reversed.

One `MapsConsent` value still covers both surfaces, so the map-only text must also
state what the same grant covers *elsewhere*. Otherwise accepting on wayfinding
would silently authorise sending location on the nav screen.

**Files:**
- Modify: `lib/widgets/maps_nav_disclosure.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_fa.arb`
- Create: `test/widget/maps_disclosure_kind_test.dart`

**Interfaces:**
- Produces: `enum MapsDisclosureKind { navigation, mapDisplay }`,
  `MapsNavDisclosure({MapsDisclosureKind kind})`, and
  `showMapsNavDisclosure(BuildContext, {MapsDisclosureKind kind})` — defaulting to
  `navigation` so the existing `google_nav_screen.dart:125` call site is unchanged.
  Task 4 calls it with `MapsDisclosureKind.mapDisplay`.

- [ ] **Step 1: Add the EN strings**

In `lib/l10n/app_en.arb`, directly after the `"mapNavDisclosureDecline"` block
(around line 577), add:

```json
  "mapDisplayDisclosureTitle": "Load the Google map here?",
  "@mapDisplayDisclosureTitle": {
    "description": "Title of the map-only disclosure shown before wayfinding renders a Google basemap."
  },
  "mapDisplayDisclosureBody": "This screen draws your walking route on a Google map. Google receives the map request and the technical request and device information it needs to serve it. This screen does not use your location.\n\nThe same choice also covers walking directions elsewhere in the app — if you ask for those, your location is sent to Google.",
  "@mapDisplayDisclosureBody": {
    "description": "Body of the map-only disclosure. States what THIS screen does, then what the same consent grant covers elsewhere, so accepting is informed for both."
  },
```

- [ ] **Step 2: Add the FA strings**

In `lib/l10n/app_fa.arb`, after the `"mapNavDisclosureDecline"` entry, add:

```json
  "mapDisplayDisclosureTitle": "نقشهٔ گوگل در اینجا بارگذاری شود؟",
  "mapDisplayDisclosureBody": "این صفحه مسیر پیاده‌روی شما را روی نقشهٔ گوگل رسم می‌کند. گوگل درخواست نقشه و اطلاعات فنی درخواست و دستگاه لازم برای ارائهٔ آن را دریافت می‌کند. این صفحه از موقعیت مکانی شما استفاده نمی‌کند.\n\nهمین انتخاب، مسیریابی پیاده در بخش‌های دیگر برنامه را هم در بر می‌گیرد — اگر آن را بخواهید، موقعیت شما به گوگل ارسال می‌شود.",
```

- [ ] **Step 3: Regenerate localisations**

Run: `flutter gen-l10n`
Expected: succeeds; `.dart_tool/untranslated_messages.json` is `{}` or empty.

- [ ] **Step 4: Write the failing test**

Create `test/widget/maps_disclosure_kind_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/widgets/maps_nav_disclosure.dart';

Widget _host(MapsDisclosureKind kind) => MaterialApp(
      localizationsDelegates: AonL10n.localizationsDelegates,
      supportedLocales: AonL10n.supportedLocales,
      home: Scaffold(body: MapsNavDisclosure(kind: kind)),
    );

void main() {
  testWidgets('the navigation disclosure states that location is sent',
      (t) async {
    await t.pumpWidget(_host(MapsDisclosureKind.navigation));
    final l = await AonL10n.delegate.load(const Locale('en'));
    expect(find.text(l.mapNavDisclosureTitle), findsOneWidget);
    expect(find.text(l.mapNavDisclosureBody), findsOneWidget);
  });

  testWidgets('the map-only disclosure does NOT claim this screen uses location',
      (t) async {
    await t.pumpWidget(_host(MapsDisclosureKind.mapDisplay));
    final l = await AonL10n.delegate.load(const Locale('en'));
    expect(find.text(l.mapDisplayDisclosureTitle), findsOneWidget);
    expect(
      find.textContaining('does not use your location'),
      findsOneWidget,
      reason: 'wayfinding reads no location; the copy must not say otherwise',
    );
  });

  testWidgets('the map-only disclosure still discloses the wider grant',
      (t) async {
    await t.pumpWidget(_host(MapsDisclosureKind.mapDisplay));
    expect(
      find.textContaining('your location is sent to Google'),
      findsOneWidget,
      reason: 'one MapsConsent covers both surfaces, so accepting here must be '
          'informed about the nav surface too',
    );
  });
}
```

- [ ] **Step 5: Run the test to verify it fails**

Run: `flutter test test/widget/maps_disclosure_kind_test.dart`
Expected: FAIL — `No named parameter with the name 'kind'` / `Undefined name 'MapsDisclosureKind'`.

- [ ] **Step 6: Write the minimal implementation**

In `lib/widgets/maps_nav_disclosure.dart`, replace the `MapsNavDisclosure` class
and the `showMapsNavDisclosure` function with:

```dart
/// Which truth this disclosure is telling.
///
/// [navigation] — the surface captures a location snapshot and sends it to the
/// Routes API. [mapDisplay] — the surface renders a Google basemap but reads no
/// location (wayfinding). One [MapsConsent] covers both, so [mapDisplay]'s copy
/// also discloses what the grant permits on the navigation surface.
enum MapsDisclosureKind { navigation, mapDisplay }

class MapsNavDisclosure extends StatelessWidget {
  const MapsNavDisclosure({
    super.key,
    this.kind = MapsDisclosureKind.navigation,
  });

  final MapsDisclosureKind kind;

  @override
  Widget build(BuildContext context) {
    final l = AonL10n.of(context);
    final theme = Theme.of(context);
    final (title, body) = switch (kind) {
      MapsDisclosureKind.navigation => (l.mapNavDisclosureTitle, l.mapNavDisclosureBody),
      MapsDisclosureKind.mapDisplay => (
          l.mapDisplayDisclosureTitle,
          l.mapDisplayDisclosureBody
        ),
    };
    return AlertDialog(
      // scrollable so title + body + actions scroll together rather than
      // overflowing at small screens / large text scale (320×568 @ 2.0).
      scrollable: true,
      backgroundColor: context.aon.surface,
      title: Text(title),
      content: Text(
        body,
        style: theme.textTheme.bodyMedium?.copyWith(color: context.aon.contentSecondary),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
          AonSpacing.space2, 0, AonSpacing.space2, AonSpacing.space2),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.mapNavDisclosureDecline),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l.mapNavDisclosureAccept),
        ),
      ],
    );
  }
}

/// Shows [MapsNavDisclosure] and resolves to whether the user accepted.
/// A barrier dismiss counts as decline (`false`).
Future<bool> showMapsNavDisclosure(
  BuildContext context, {
  MapsDisclosureKind kind = MapsDisclosureKind.navigation,
}) async {
  final accepted = await showDialog<bool>(
    context: context,
    builder: (_) => MapsNavDisclosure(kind: kind),
  );
  return accepted ?? false;
}
```

- [ ] **Step 7: Run the test to verify it passes**

Run: `flutter test test/widget/maps_disclosure_kind_test.dart`
Expected: PASS — 3 tests.

- [ ] **Step 8: Run the full gate and commit**

```bash
./scripts/check.sh > /tmp/gate.log 2>&1 && {
  git add lib/widgets/maps_nav_disclosure.dart lib/l10n/ \
          test/widget/maps_disclosure_kind_test.dart
  git commit -m "feat(consent): add a truthful map-only disclosure variant"
} || { echo "GATE FAILED"; tail -30 /tmp/gate.log; }
```

---

### Task 4: Wayfinding renders a Google basemap behind consent

Replaces `_RouteMap`'s `FlutterMap` + `DarkTileLayer` with `EmbeddedMap`.
`_RouteMap` draws a hand-authored polyline and two endpoints — `EmbeddedMap`
already takes exactly `origin` / `destination` / `route`, so this is a
substitution inside one private widget, not a rewrite.

**Accepted cost (spec §5c):** this screen was designed to work with no network.
The written steps remain the primary output and still render when the map cannot.

**Files:**
- Modify: `lib/screens/wayfinding_screen.dart:348-440`
- Create: `test/widget/wayfinding_google_map_test.dart`

**Interfaces:**
- Consumes: `mapsSdkReadyProvider` (Task 2), `showMapsNavDisclosure` +
  `MapsDisclosureKind` (Task 3), `EmbeddedMap` / `EmbeddedMapSurface` from
  `lib/widgets/embedded_map.dart`.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Write the failing test**

Create `test/widget/wayfinding_google_map_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/models/data_confidence.dart';
import 'package:aon2026/models/walking_route.dart';
import 'package:aon2026/services/maps_consent_providers.dart';
import 'package:aon2026/services/maps_consent_store.dart';
import 'package:aon2026/services/maps_sdk_initializer.dart';
import 'package:aon2026/widgets/embedded_map.dart';
import 'package:aon2026/screens/wayfinding_screen.dart';

/// A surface that records that it was asked to render, without a platform view.
class _RecordingSurface implements EmbeddedMapSurface {
  int builds = 0;
  @override
  Widget build({
    required GeoBounds bounds,
    required (double lat, double lng) origin,
    required (double lat, double lng) destination,
    required List<(double lat, double lng)> route,
  }) {
    builds++;
    return const SizedBox(key: Key('fake-google-surface'));
  }
}

class _ReadyInitializer implements MapsSdkInitializer {
  @override
  Future<bool> ensureInitialized() async => true;
}

final _route = WalkingRoute(
  id: 'r1',
  fromId: 'p1',
  toId: 'v1',
  fromLabel: 'Car park',
  toLabel: 'Observatory',
  steps: const [RouteStep(instruction: 'Walk toward the lit path.')],
  points: const [LatLng(-33.7738, 151.1126), LatLng(-33.7745, 151.1133)],
  pathConfidence: DataConfidence.confirmed,
);

Widget _host(ProviderContainer c, Widget child) => UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: Scaffold(body: child),
      ),
    );

ProviderContainer _container(MapsConsent seed) {
  final c = ProviderContainer(overrides: [
    mapsConsentSnapshotProvider.overrideWithValue(seed),
    mapsSdkInitializerProvider.overrideWithValue(_ReadyInitializer()),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  testWidgets('without consent no Google surface is built', (t) async {
    final surface = _RecordingSurface();
    final c = _container(MapsConsent.unknown);

    await t.pumpWidget(_host(c, RouteMapForTest(route: _route, surface: surface)));
    await t.pumpAndSettle();

    expect(surface.builds, 0,
        reason: 'spec §2b: no Google surface may initialise before consent');
    expect(find.byKey(const Key('fake-google-surface')), findsNothing);
  });

  testWidgets('with accepted consent the Google surface is built', (t) async {
    final surface = _RecordingSurface();
    final c = _container(MapsConsent.accepted);

    await t.pumpWidget(_host(c, RouteMapForTest(route: _route, surface: surface)));
    await t.pumpAndSettle();

    expect(surface.builds, greaterThan(0));
    expect(find.byKey(const Key('fake-google-surface')), findsOneWidget);
  });

  testWidgets('declined consent leaves the written steps reachable', (t) async {
    final surface = _RecordingSurface();
    final c = _container(MapsConsent.declined);

    await t.pumpWidget(_host(c, RouteMapForTest(route: _route, surface: surface)));
    await t.pumpAndSettle();

    expect(surface.builds, 0);
    // The map is a supporting visual; declining must not remove the primary
    // output. A placeholder stands in its place rather than a blank gap.
    expect(find.byKey(const Key('wayfinding-map-declined')), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/widget/wayfinding_google_map_test.dart`
Expected: FAIL — `Undefined name 'RouteMapForTest'`.

- [ ] **Step 3: Write the minimal implementation**

In `lib/screens/wayfinding_screen.dart`, replace the entire `_RouteMap` class
(lines 348-440, through the closing brace after `_endpoint`) with:

```dart
/// Test seam: `_RouteMap` is private, so widget tests construct this instead.
/// It takes the same arguments plus an injectable [EmbeddedMapSurface].
@visibleForTesting
class RouteMapForTest extends ConsumerWidget {
  const RouteMapForTest({required this.route, required this.surface, super.key});

  final WalkingRoute route;
  final EmbeddedMapSurface surface;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      _RouteMap(route: route, surface: surface);
}

class _RouteMap extends ConsumerStatefulWidget {
  const _RouteMap({required this.route, this.surface});

  final WalkingRoute route;

  /// Null in production → the real Google surface. Injected in tests.
  final EmbeddedMapSurface? surface;

  @override
  ConsumerState<_RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends ConsumerState<_RouteMap> {
  bool _disclosureRequested = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final route = widget.route;
    final isDraftGeometry = route.pathConfidence == DataConfidence.placeholder;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AonSpacing.radiusMd),
          child: SizedBox(height: 220, child: _surface(context)),
        ),
        if (isDraftGeometry) ...[
          const SizedBox(height: AonSpacing.space2),
          Text(
            'Straight line shown — this is the general direction, not the '
            'exact path. Follow the written directions below.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.aon.contentTertiary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _surface(BuildContext context) {
    final consent = ref.watch(mapsConsentProvider);

    // Spec §2b — nothing Google-shaped is constructed before consent resolves
    // positively. The written steps below remain the primary output either way.
    if (consentNeedsDisclosure(consent)) {
      _ensureDisclosure();
      return _placeholder(context);
    }

    final ready = ref.watch(mapsSdkReadyProvider);
    if (ready.asData?.value != true) return _placeholder(context);

    final pts = widget.route.points
        .map<(double, double)>((p) => (p.latitude, p.longitude))
        .toList();
    return EmbeddedMap(
      origin: pts.first,
      destination: pts.last,
      route: pts,
      surface: widget.surface ?? const GoogleEmbeddedMapSurface(),
    );
  }

  /// Stands in for the map so the layout does not jump. Deliberately NOT an
  /// animating spinner: a pending disclosure dialog would never let tests settle.
  ///
  /// A blank rectangle would read as a bug, so it says what it is. The written
  /// steps below are the primary output and are unaffected.
  Widget _placeholder(BuildContext context) => ColoredBox(
        key: const Key('wayfinding-map-declined'),
        color: context.aon.surfaceBase,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AonSpacing.space3),
            child: Text(
              AonL10n.of(context).wayfindingMapUnavailable,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: context.aon.contentTertiary),
            ),
          ),
        ),
      );

  void _ensureDisclosure() {
    if (_disclosureRequested) return;
    _disclosureRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final accepted = await showMapsNavDisclosure(
        context,
        kind: MapsDisclosureKind.mapDisplay,
      );
      if (!mounted) return;
      final notifier = ref.read(mapsConsentProvider.notifier);
      accepted ? notifier.accept() : notifier.decline();
      // Re-arm so a later revoke (via Settings) re-asks instead of leaving a
      // permanent placeholder — same fix as google_nav_screen (map audit P2).
      if (mounted) _disclosureRequested = false;
    });
  }
}
```

Add the strings — `lib/l10n/app_en.arb`:

```json
  "wayfindingMapUnavailable": "Map not shown. The written directions below are complete on their own.",
  "@wayfindingMapUnavailable": { "description": "Placeholder where the Google map would be, when consent was declined or the SDK is unkeyed." },
```

`lib/l10n/app_fa.arb`:

```json
  "wayfindingMapUnavailable": "نقشه نمایش داده نمی‌شود. راهنمای نوشتاری زیر به‌تنهایی کامل است.",
```

Then update the imports at the top of `lib/screens/wayfinding_screen.dart`:
remove `import 'package:aon2026/widgets/dark_tile_layer.dart';`,
remove `import 'package:flutter_map/flutter_map.dart';`,
remove `import 'package:aon2026/widgets/map_config.dart';`,
remove `import 'package:latlong2/latlong.dart';` **only if** `flutter analyze`
reports it unused after the edit, and add:

```dart
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:aon2026/services/maps_consent_providers.dart';
import 'package:aon2026/services/maps_consent_store.dart';
import 'package:aon2026/services/maps_sdk_initializer.dart';
import 'package:aon2026/widgets/embedded_map.dart';
import 'package:aon2026/widgets/maps_nav_disclosure.dart';
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/widget/wayfinding_google_map_test.dart`
Expected: PASS — 3 tests.

- [ ] **Step 5: Gate the OTHER Google surface too — regression from Task 1**

> **Gauntlet finding (P0).** Task 1 removed `provideAPIKey` from app launch, but
> `google_nav_screen.dart:147` renders `EmbeddedMap` gated only on
> `googleNavEnabledProvider` + consent — never on SDK readiness. On iOS that
> means a `GoogleMap` constructed against an **unkeyed** SDK: a blank or broken
> map. Task 1 introduces this regression; nothing else in the plan caught it.

In `lib/screens/google_nav_screen.dart`, in the `data: (result)` branch that
builds `_resultBody`, wrap the `EmbeddedMap` at line 147 so it only renders once
the SDK is ready. Immediately before the `EmbeddedMap(` call, read:

```dart
              // Task 1 deferred provideAPIKey off launch, so a Google map may
              // not be constructed until the SDK has actually been keyed.
              if (ref.watch(mapsSdkReadyProvider).asData?.value != true)
                const SizedBox.shrink()
              else
```

and add the import:

```dart
import 'package:aon2026/services/maps_sdk_initializer.dart';
```

- [ ] **Step 6: Prove it on the screen the regression is actually in**

> **Review round 2 (P0).** The first version of this step asserted on
> `RouteMapForTest` — the *wayfinding* seam — while the regression it claims to
> cover lives in `google_nav_screen.dart:147`. A test named "no Google surface
> anywhere" that never constructs `GoogleNavScreen` is the same
> passes-for-the-wrong-reason defect this plan keeps finding. Both screens get a
> direct test.

`GoogleNavScreen` already accepts an injectable surface
(`google_nav_screen.dart:27`), so no new seam is needed. Create
`test/widget/google_nav_sdk_gate_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/screens/google_nav_screen.dart';
import 'package:aon2026/services/maps_consent_providers.dart';
import 'package:aon2026/services/maps_consent_store.dart';
import 'package:aon2026/services/maps_nav_providers.dart';
import 'package:aon2026/services/maps_sdk_initializer.dart';
import 'package:aon2026/widgets/embedded_map.dart';

class _RecordingSurface implements EmbeddedMapSurface {
  int builds = 0;
  @override
  Widget build({
    required GeoBounds bounds,
    required (double lat, double lng) origin,
    required (double lat, double lng) destination,
    required List<(double lat, double lng)> route,
  }) {
    builds++;
    return const SizedBox(key: Key('nav-google-surface'));
  }
}

class _Initializer implements MapsSdkInitializer {
  _Initializer(this.ready);
  final bool ready;
  @override
  Future<bool> ensureInitialized() async => ready;
  @override
  Future<String?> openSourceLicenseInfo() async => null;
}

void main() {
  testWidgets('GoogleNavScreen builds no map while the SDK is unkeyed',
      (t) async {
    final surface = _RecordingSurface();
    final c = ProviderContainer(overrides: [
      mapsConsentSnapshotProvider.overrideWithValue(MapsConsent.accepted),
      mapsSdkInitializerProvider.overrideWithValue(_Initializer(false)),
      embeddedMapConfiguredProvider.overrideWithValue(true),
      androidRoutesKeyProvider.overrideWithValue('test-key'),
      iosRoutesKeyProvider.overrideWithValue('test-key'),
    ]);
    addTearDown(c.dispose);

    await t.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: GoogleNavScreen(placeKey: 'venue:observatory', surface: surface),
      ),
    ));
    await t.pumpAndSettle();

    expect(surface.builds, 0,
        reason: 'Task 1 deferred provideAPIKey off launch; consent alone must '
            'not be enough to construct a GoogleMap');
    expect(find.byKey(const Key('nav-google-surface')), findsNothing);
  });
}
```

If `GoogleNavScreen` does not already accept a `surface` parameter, add one with
the same default as `EmbeddedMap` (`const GoogleEmbeddedMapSurface()`) and thread
it through — never weaken the `builds, 0` assertion to reach green. If route
resolution needs more overrides, take them from
`test/widget/map_platform_wiring_test.dart`.

- [ ] **Step 6b: And the wayfinding seam**

Append to `test/widget/wayfinding_google_map_test.dart`:

```dart
  testWidgets('an unkeyed SDK yields no wayfinding Google surface', (t) async {
    final surface = _RecordingSurface();
    final c = ProviderContainer(overrides: [
      mapsConsentSnapshotProvider.overrideWithValue(MapsConsent.accepted),
      // Consent given, but the platform refuses to key the SDK (no secret file).
      mapsSdkInitializerProvider.overrideWithValue(_UnkeyedInitializer()),
    ]);
    addTearDown(c.dispose);

    await t.pumpWidget(_host(c, RouteMapForTest(route: _route, surface: surface)));
    await t.pumpAndSettle();

    expect(surface.builds, 0,
        reason: 'consent alone is not enough — the SDK must be keyed');
  });
```

and add the fake next to `_ReadyInitializer`:

```dart
class _UnkeyedInitializer implements MapsSdkInitializer {
  @override
  Future<bool> ensureInitialized() async => false;
}
```

- [ ] **Step 7: Run the tests, the gate, and commit**

```bash
flutter test test/widget/wayfinding_google_map_test.dart
./scripts/check.sh > /tmp/gate.log 2>&1 && {
  git add lib/screens/wayfinding_screen.dart lib/screens/google_nav_screen.dart \
          test/widget/wayfinding_google_map_test.dart
  git commit -m "feat(wayfinding): render the route on a consented Google basemap"
} || { echo "GATE FAILED"; tail -30 /tmp/gate.log; }
```

---

### Task 5: Truth-up every map attribution

Three OSM strings live in the ARB, which is why `grep OpenStreetMap lib/**/*.dart`
finds nothing and this finding looks stale when it is not. After Task 4 the app
renders no OSM tiles at all, so all three become false.

`_MapAttribution` must get a **new** key. It must not reuse the orphaned
`mapAttribution`, whose content is `"© OpenStreetMap contributors"` — that would
replace one false claim with another.

**Files:**
- Delete: `lib/widgets/dark_tile_layer.dart`, `test/widget/dark_tile_layer_test.dart` (if present)
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_fa.arb`, `lib/screens/map_screen.dart:576-595`, `lib/widgets/map_config.dart`
- Create: `test/widget/map_attribution_test.dart`

**Interfaces:**
- Produces: l10n keys `mapAttributionCampus`, `settingsMapDataAttribution`
  (replacing `settingsOsmAttribution`), rewritten `creditsMapDataBody`.

- [ ] **Step 1: Write the failing test**

Create `test/widget/map_attribution_test.dart`:

```dart
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';

void main() {
  test('no shipped string claims OpenStreetMap attribution', () async {
    for (final locale in AonL10n.supportedLocales) {
      final l = await AonL10n.delegate.load(locale);
      final claims = <String>[
        l.settingsMapDataAttribution,
        l.creditsMapDataBody,
        l.mapAttributionCampus,
      ];
      for (final c in claims) {
        expect(
          c.toLowerCase(),
          isNot(contains('openstreetmap')),
          reason: 'the app renders no OSM tiles after the Google swap; '
              'locale ${locale.languageCode} still attributes OSM',
        );
      }
    }
  });

  test('the campus attribution names Macquarie University', () async {
    final en = await AonL10n.delegate.load(const Locale('en'));
    expect(en.mapAttributionCampus, contains('Macquarie University'));
    expect(en.mapAttributionCampus, isNot(contains('\u00a9')),
        reason: "we do not assert copyright on MQ's behalf before §8.6 lands");
  });

  test('NO shipped ARB string mentions OpenStreetMap', () async {
    // The getters above are the ones we know about. This scans everything
    // shipped, so a string added later cannot quietly reintroduce the claim.
    for (final path in ['lib/l10n/app_en.arb', 'lib/l10n/app_fa.arb']) {
      final text = await File(path).readAsString();
      expect(text.toLowerCase(), isNot(contains('openstreetmap')),
          reason: '$path still attributes OSM after the tiles were removed');
      expect(text, isNot(contains('tile.openstreetmap.org')));
    }
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/widget/map_attribution_test.dart`
Expected: FAIL — `The getter 'settingsMapDataAttribution' isn't defined` / `'mapAttributionCampus' isn't defined`.

- [ ] **Step 3: Rewrite the EN strings**

In `lib/l10n/app_en.arb`:

1. **Delete** the `"mapAttribution"` line (line 228) — orphaned OSM text.
2. **Replace** `"settingsOsmAttribution"` (line 632) with:

```json
  "settingsMapDataAttribution": "Campus map: Macquarie University. Walking directions and the map they appear on are provided by Google.",
  "@settingsMapDataAttribution": {
    "description": "Settings credits: who the map data actually comes from now that OSM tiles are gone."
  },
```

3. **Replace** the value of `"creditsMapDataBody"` (line 763) with:

```json
  "creditsMapDataBody": "Campus map: Macquarie University. Walking directions and the map they appear on are provided by Google.",
```

4. **Add**, next to `"mapRecentre"`:

```json
  "mapAttributionCampus": "Campus map: Macquarie University",
  "@mapAttributionCampus": {
    "description": "Attribution overlaid on the AON campus basemap. Names the SOURCE, not a copyright holder — MQ's ownership of the cartographic master is not confirmed, and asserting © on their behalf is a claim we cannot back. Switch to '© Macquarie University' only once §8.6's written sign-off states MQ owns it."
  },
```

- [ ] **Step 4: Rewrite the FA strings**

In `lib/l10n/app_fa.arb`: delete `"mapAttribution"` (line 79); replace
`"settingsOsmAttribution"` (line 244) and the value of `"creditsMapDataBody"`
(line 287); add `"mapAttributionCampus"`:

```json
  "mapAttributionCampus": "نقشهٔ پردیس: دانشگاه مکواری",
  "settingsMapDataAttribution": "نقشهٔ پردیس: دانشگاه مکواری. مسیریابی پیاده و نقشه‌ای که روی آن نمایش داده می‌شود توسط گوگل ارائه می‌گردد.",
  "creditsMapDataBody": "نقشهٔ پردیس: دانشگاه مکواری. مسیریابی پیاده و نقشه‌ای که روی آن نمایش داده می‌شود توسط گوگل ارائه می‌گردد.",
```

- [ ] **Step 5: Update the two render sites and the map screen**

In `lib/screens/settings_screen.dart:420`, change `l.settingsOsmAttribution` to
`l.settingsMapDataAttribution`.

In `lib/screens/map_screen.dart:588`, replace the hardcoded literal:

```dart
        'Campus map © Macquarie University',
```

with:

```dart
        AonL10n.of(context).mapAttributionCampus,
```

(`info_screen.dart:253` already renders `l.creditsMapDataBody`, whose *value*
changed — no code edit needed there.)

- [ ] **Step 6: Delete the dead tile layer**

```bash
git rm lib/widgets/dark_tile_layer.dart
git rm --ignore-unmatch test/widget/dark_tile_layer_test.dart
```

Then in `lib/widgets/map_config.dart`, delete the now-unused `tileUrlTemplate`
constant (line 111-112) and its doc comment (line 101). Leave
`userAgentPackageName` if `flutter analyze` shows another consumer; delete it if
not.

- [ ] **Step 7: Regenerate, run the test, verify it passes**

```bash
flutter gen-l10n
flutter test test/widget/map_attribution_test.dart
```
Expected: PASS — 2 tests. If `flutter analyze` reports unused imports of
`dark_tile_layer.dart` anywhere, remove them.

- [ ] **Step 8: Run the full gate and commit**

```bash
./scripts/check.sh > /tmp/gate.log 2>&1 && {
  git add -A lib/ test/widget/map_attribution_test.dart
  git commit -m "fix(attribution): remove OSM claims the app no longer earns"
} || { echo "GATE FAILED"; tail -30 /tmp/gate.log; }
```

---

### Task 6: Delete local data

Spec §2c. Not an Apple requirement — 5.1.1(i) governs what the *policy* must
explain, and 5.1.1(v)'s in-app deletion rule is conditional on account creation,
which this app has none of. It is in scope as good engineering: the data is local,
so the control is cheap and testable. It must **not** claim to erase anything
already transmitted to a third party.

**Files:**
- Create: `lib/services/local_data_eraser.dart`, `test/unit/local_data_eraser_test.dart`
- Modify: `lib/screens/settings_screen.dart`, `lib/l10n/app_en.arb`, `lib/l10n/app_fa.arb`

**Interfaces:**
- Produces: `LocalDataEraser.eraseAll()` and `localDataEraserProvider`.

> **Gauntlet correction (P0).** The first draft of this task invented four
> storage keys. Three were wrong, one of the real keys is **dynamic**, and the
> test seeded the same invented keys it asserted on — so it would have gone
> green while the shipped eraser deleted nothing. That is a test passing for the
> wrong reason, and it is why the key list below is *derived from the stores*
> rather than retyped.
>
> The real keys, read off the tree:
>
> | Key | Type | Owner |
> |---|---|---|
> | `passport.collectedVenueIds` | String | `passport_store.dart:22` |
> | `map_favorites.buildings.v1` | StringList | `favorites_store.dart:17` |
> | `map_favorites.venues.$eventId` | StringList | `favorites_store.dart:18` — **per-event, not a constant** |
> | `map_google_consent.v1` | String | `maps_consent_store.dart:24` |
>
> `settings.themeMode` / `settings.reduceMotion` / `settings.locale` are
> deliberately **not** erased: they are preferences, not user data, and wiping
> someone's language on a "delete my data" tap would be a surprise. Say so in
> the code comment so a later reader does not "fix" it.

- [ ] **Step 1: Publish the keys from the stores that own them**

Drift between this list and the stores is the whole defect, so the names come
from one place. In `lib/services/passport_store.dart`, change line 22 (inside the **concrete**
`SharedPrefsPassportStore`, not the `PassportStore` interface) from
`static const String _key = ...` to a public constant and update its uses:

```dart
  /// Public so `LocalDataEraser` can never drift from the real key.
  static const String storageKey = 'passport.collectedVenueIds';
```

In `lib/services/favorites_store.dart`, inside `SharedPrefsFavoritesStore`, replace the two private key members with:

```dart
  static const String buildingsKey = 'map_favorites.buildings.v1';

  /// Per-event, so it cannot be a constant — this is exactly what a hand-typed
  /// key list gets wrong.
  static String venuesKeyFor(String eventId) => 'map_favorites.venues.$eventId';

  String get _venuesKey => venuesKeyFor(eventId);
```

In `lib/services/maps_consent_store.dart`, inside `SharedPrefsMapsConsentStore`, change line 24 to:

```dart
  static const String storageKey = 'map_google_consent.v1';
```

and update its internal uses from `_key` to `storageKey`.

- [ ] **Step 2: Write the failing test**

Create `test/unit/local_data_eraser_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:aon2026/services/favorites_store.dart';
import 'package:aon2026/services/local_data_eraser.dart';
import 'package:aon2026/services/maps_consent_store.dart';
import 'package:aon2026/services/passport_store.dart';

const _eventId = 'aon2026';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('eraseAll clears every key the real stores actually write', () async {
    // `SharedPreferencesAsync` is NOT mocked with setMockInitialValues — the
    // repo's own pattern (passport_store_test.dart:44, favorites_test.dart:77)
    // swaps the platform instance. Seeded from the STORES' own constants, not
    // from retyped literals: if eraser and store ever disagree, this test fails
    // instead of lying.
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({
      SharedPrefsPassportStore.storageKey: 'v1|obs,lab',
      SharedPrefsFavoritesStore.buildingsKey: <String>['building:E7A'],
      SharedPrefsFavoritesStore.venuesKeyFor(_eventId): <String>['venue:obs'],
      SharedPrefsMapsConsentStore.storageKey: 'accepted',
    });
    final prefs = SharedPreferencesAsync();
    final eraser = SharedPrefsLocalDataEraser(prefs: prefs, eventId: _eventId);

    expect(await eraser.eraseAll(), isTrue);

    expect(await prefs.getString(SharedPrefsPassportStore.storageKey), isNull);
    expect(await prefs.getStringList(SharedPrefsFavoritesStore.buildingsKey), isNull);
    expect(await prefs.getStringList(SharedPrefsFavoritesStore.venuesKeyFor(_eventId)), isNull);
    expect(await prefs.getString(SharedPrefsMapsConsentStore.storageKey), isNull);
  });

  test('preferences survive — they are settings, not user data', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({
      'settings.locale': 'fa',
      'settings.themeMode': 'dark',
      SharedPrefsPassportStore.storageKey: 'v1|obs',
    });
    final prefs = SharedPreferencesAsync();
    await SharedPrefsLocalDataEraser(prefs: prefs, eventId: _eventId).eraseAll();

    expect(await prefs.getString('settings.locale'), 'fa',
        reason: 'wiping someone\'s language on "delete my data" is a surprise');
    expect(await prefs.getString('settings.themeMode'), 'dark');
  });

  test('the venues key follows the event id it was constructed with', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({
      SharedPrefsFavoritesStore.venuesKeyFor('other-event'): <String>['venue:x'],
      SharedPrefsFavoritesStore.venuesKeyFor(_eventId): <String>['venue:obs'],
    });
    final prefs = SharedPreferencesAsync();
    await SharedPrefsLocalDataEraser(prefs: prefs, eventId: _eventId).eraseAll();

    expect(await prefs.getStringList(SharedPrefsFavoritesStore.venuesKeyFor(_eventId)), isNull);
    expect(await prefs.getStringList(SharedPrefsFavoritesStore.venuesKeyFor('other-event')),
        isNull,
        reason: 'the control says "delete my data", not "delete this event\'s '
            'data" — a stale event\'s favourites are still the user\'s data');
  });

  test('the no-op eraser fails closed', () async {
    // A forgotten production override must surface as a visible failure, never
    // as a cheerful success over data that is still on the device.
    expect(await const NoopLocalDataEraser().eraseAll(), isFalse);
  });

  testWidgets('the real Settings control clears the SESSION, not just storage',
      (t) async {
    // FavoritesController and PassportNotifier hold live state seeded at
    // startup. A storage-only wipe leaves the session showing deleted data, and
    // the next save writes it straight back. This drives the shipped widget.
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({
      SharedPrefsPassportStore.storageKey: 'v1|obs',
      SharedPrefsFavoritesStore.buildingsKey: <String>['building:E7A'],
    });
    final container = ProviderContainer(overrides: [
      localDataEraserProvider.overrideWithValue(SharedPrefsLocalDataEraser(
        prefs: SharedPreferencesAsync(),
        eventId: _eventId,
      )),
      mapsConsentSnapshotProvider.overrideWithValue(MapsConsent.accepted),
    ]);
    addTearDown(container.dispose);

    await t.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: SettingsScreen(),
      ),
    ));
    await t.pumpAndSettle();

    await t.tap(find.byKey(const Key('settings-erase-button')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('settings-erase-confirm')));
    await t.pumpAndSettle();

    final l = await AonL10n.delegate.load(const Locale('en'));
    expect(find.text(l.settingsEraseDone), findsOneWidget);
    expect(container.read(mapsConsentProvider), MapsConsent.unknown,
        reason: 'consent must be revoked in memory, not only in storage');
    expect(container.read(favoritesProvider).keys, isEmpty,
        reason: 'the live favourites notifier must be reset too');
  });

  testWidgets('a failed erase reports failure, never success', (t) async {
    final container = ProviderContainer(overrides: [
      // The fail-closed default: a forgotten override must be visible.
      localDataEraserProvider.overrideWithValue(const NoopLocalDataEraser()),
    ]);
    addTearDown(container.dispose);

    await t.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: SettingsScreen(),
      ),
    ));
    await t.pumpAndSettle();

    await t.tap(find.byKey(const Key('settings-erase-button')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('settings-erase-confirm')));
    await t.pumpAndSettle();

    final l = await AonL10n.delegate.load(const Locale('en'));
    expect(find.text(l.settingsEraseFailed), findsOneWidget);
    expect(find.text(l.settingsEraseDone), findsNothing);
  });

  test('eraseAll never throws when the platform store fails', () async {
    final eraser =
        SharedPrefsLocalDataEraser(prefs: _ThrowingPrefs(), eventId: _eventId);
    expect(await eraser.eraseAll(), isFalse);
  });
}

class _ThrowingPrefs implements SharedPreferencesAsync {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Future<void>.error(StateError('platform store unavailable'));
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `flutter test test/unit/local_data_eraser_test.dart`
Expected: FAIL — `Couldn't resolve ... local_data_eraser.dart`.

- [ ] **Step 4: Write the minimal implementation**

Create `lib/services/local_data_eraser.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aon2026/services/favorites_store.dart';
import 'package:aon2026/services/maps_consent_store.dart';
import 'package:aon2026/services/passport_store.dart';

/// Erases everything this app stores on this device.
///
/// Scope is deliberately narrow and stated: local storage only. It does NOT and
/// must not claim to erase anything already transmitted to a third party
/// (spec §2c) — the Settings copy says so in both languages.
abstract interface class LocalDataEraser {
  /// Never throws. Returns false when the platform store refused.
  Future<bool> eraseAll();
}

class SharedPrefsLocalDataEraser implements LocalDataEraser {
  SharedPrefsLocalDataEraser({required this.prefs, required this.eventId});

  final SharedPreferencesAsync prefs;

  /// Needed because the favourites venue key is per-event. A constant list
  /// cannot express it, which is precisely how the first draft of this class
  /// erased nothing.
  final String eventId;

  /// Sourced from each store's own constant so the two can never drift.
  /// `settings.*` is excluded on purpose: theme, motion and locale are
  /// preferences, not user data, and clearing them here would be a surprise.
  List<String> get ownedKeys => <String>[
        SharedPrefsPassportStore.storageKey,
        SharedPrefsFavoritesStore.buildingsKey,
        SharedPrefsFavoritesStore.venuesKeyFor(eventId),
        SharedPrefsMapsConsentStore.storageKey,
      ];

  /// The control says "delete my data", not "delete this event's data", so any
  /// favourites left behind by a previous event id go too. `getKeys` is
  /// available on `SharedPreferencesAsync` (shared_preferences 2.5.4).
  static const String _venuesKeyPrefix = 'map_favorites.venues.';

  @override
  Future<bool> eraseAll() async {
    try {
      for (final key in ownedKeys) {
        await prefs.remove(key);
      }
      for (final key in await prefs.getKeys()) {
        if (key.startsWith(_venuesKeyPrefix)) await prefs.remove(key);
      }
      return true;
    } catch (_) {
      return false; // persistence failure is never fatal (passport idiom)
    }
  }
}

/// The default. Fails CLOSED: a forgotten production override must surface as a
/// visible failure, not as a cheerful "Deleted." over data that is still there.
class NoopLocalDataEraser implements LocalDataEraser {
  const NoopLocalDataEraser();
  @override
  Future<bool> eraseAll() async => false;
}

/// Overridden in `main.dart` with the SharedPreferences-backed eraser.
final localDataEraserProvider =
    Provider<LocalDataEraser>((_) => const NoopLocalDataEraser());
```

Verified against the tree: the interfaces are `PassportStore` /
`FavoritesStore` / `MapsConsentStore` (`passport_store.dart:9`,
`favorites_store.dart:6`, `maps_consent_store.dart:15`) and the concrete
implementations that own the keys are `SharedPrefsPassportStore` (`:18`),
`SharedPrefsFavoritesStore` (`:11`) and `SharedPrefsMapsConsentStore` (`:20`).

- [ ] **Step 5: Add the EN + FA strings**

`lib/l10n/app_en.arb`:

```json
  "settingsEraseTitle": "Delete my data",
  "@settingsEraseTitle": { "description": "Settings control that clears all locally stored app data." },
  "settingsEraseBody": "Clears your passport stamps, favourites and your Google Maps choice. Your language and theme settings are kept.",
  "@settingsEraseBody": { "description": "Explains the scope of the erase control." },
  "settingsEraseConfirmTitle": "Delete data stored on this device?",
  "@settingsEraseConfirmTitle": { "description": "Destructive confirmation dialog title." },
  "settingsEraseConfirmBody": "This permanently deletes data stored by this app on this device. It cannot undo anything already sent to Google.",
  "@settingsEraseConfirmBody": { "description": "Destructive confirmation body. States the scope limit honestly." },
  "settingsEraseConfirmAction": "Delete",
  "@settingsEraseConfirmAction": { "description": "Destructive confirm button." },
  "settingsEraseCancel": "Cancel",
  "@settingsEraseCancel": { "description": "Dismisses the destructive confirmation." },
  "settingsEraseDone": "Deleted.",
  "@settingsEraseDone": { "description": "Snackbar shown after a successful erase." },
  "settingsEraseFailed": "Couldn't delete your data. Please try again.",
  "@settingsEraseFailed": { "description": "Shown when eraseAll returned false. Never claim a deletion that did not happen." },
```

`lib/l10n/app_fa.arb`:

```json
  "settingsEraseTitle": "حذف داده‌های من",
  "settingsEraseBody": "مهرهای پاسپورت، علاقه‌مندی‌ها و انتخاب شما دربارهٔ نقشهٔ گوگل را پاک می‌کند. تنظیمات زبان و پوستهٔ شما حفظ می‌شود.",
  "settingsEraseConfirmTitle": "داده‌های ذخیره‌شده روی این دستگاه حذف شوند؟",
  "settingsEraseConfirmBody": "این کار داده‌هایی را که این برنامه روی این دستگاه ذخیره کرده برای همیشه حذف می‌کند. آنچه پیش‌تر به گوگل ارسال شده قابل بازگرداندن نیست.",
  "settingsEraseConfirmAction": "حذف",
  "settingsEraseCancel": "انصراف",
  "settingsEraseDone": "حذف شد.",
  "settingsEraseFailed": "حذف داده‌های شما ممکن نشد. لطفاً دوباره تلاش کنید.",
```

- [ ] **Step 6: Wire the control into Settings**

In `lib/screens/settings_screen.dart`, immediately after the existing maps-consent
revoke section (the block ending near line 330), add:

```dart
            const SizedBox(height: AonSpacing.space4),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.settingsEraseTitle),
              subtitle: Text(l.settingsEraseBody),
              trailing: TextButton(
                key: const Key('settings-erase-button'),
                onPressed: () => _confirmErase(context, ref, l),
                child: Text(l.settingsEraseConfirmAction),
              ),
            ),
```

And add this method to the same widget's class:

```dart
  Future<void> _confirmErase(
      BuildContext context, WidgetRef ref, AonL10n l) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        backgroundColor: context.aon.surface,
        title: Text(l.settingsEraseConfirmTitle),
        content: Text(l.settingsEraseConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.settingsEraseCancel),
          ),
          FilledButton(
            key: const Key('settings-erase-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.settingsEraseConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    // Erasing storage is not enough: FavoritesController and PassportNotifier
    // hold live in-memory state seeded at startup, so a wipe that only touches
    // SharedPreferences leaves the current session showing deleted data — and
    // the next save writes it straight back. Reset the session first, then the
    // storage behind it.
    final ok = await ref.read(localDataEraserProvider).eraseAll();
    if (!context.mounted) return;

    if (ok) {
      ref.invalidate(passportProvider);
      ref.invalidate(favoritesProvider);
      ref.read(mapsConsentProvider.notifier).revoke();
    }

    // Never claim success we did not verify.
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? l.settingsEraseDone : l.settingsEraseFailed),
    ));
  }
```

Add to `lib/main.dart`'s override list:

```dart
        localDataEraserProvider.overrideWithValue(SharedPrefsLocalDataEraser(
          prefs: SharedPreferencesAsync(),
          eventId: eventConfig.id, // the same id FavoritesStore is built with
        )),
```

- [ ] **Step 7: Regenerate and run the full gate, then commit**

```bash
flutter gen-l10n
./scripts/check.sh > /tmp/gate.log 2>&1 && {
  git add lib/ test/unit/local_data_eraser_test.dart
  git commit -m "feat(settings): add a scoped delete-my-data control"
} || { echo "GATE FAILED"; tail -30 /tmp/gate.log; }
```

---

### Task 7: Make the privacy copy true again

`app_en.arb:308` and `app_fa.arb:128` assert "collects no analytics and **tracks
no location**" and "the only thing it fetches from the internet is **map
imagery**". Both become false with this release, in both languages. Spec §2a.

**Files:**
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_fa.arb`
- Create: `test/unit/privacy_copy_truth_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/unit/privacy_copy_truth_test.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';

void main() {
  test('the English privacy copy does not deny what the app now does', () async {
    final en = await AonL10n.delegate.load(const Locale('en'));
    final body = en.settingsPrivacyBody.toLowerCase();

    expect(body, isNot(contains('tracks no location')),
        reason: 'the app sends location to Google for directions');
    expect(body, isNot(contains('only thing it fetches')),
        reason: 'the app also fetches Google map imagery and routes');
    expect(body, contains('google'),
        reason: 'third-party sharing needs disclosure and explicit permission '
            'under 5.1.2(i) — 5.1.1(i) governs the privacy POLICY, which is a '
            'different obligation');
  });

  test('both locales define the privacy body and mention Google', () async {
    for (final locale in AonL10n.supportedLocales) {
      final l = await AonL10n.delegate.load(locale);
      expect(l.settingsPrivacyBody.trim(), isNotEmpty);
      expect(l.settingsPrivacyBody.toLowerCase(),
          anyOf(contains('google'), contains('گوگل')),
          reason: '${locale.languageCode} must disclose the Google surface too');
    }
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/unit/privacy_copy_truth_test.dart`
Expected: FAIL — the first test fails on `tracks no location`.

- [ ] **Step 3: Rewrite the EN copy**

Replace `"settingsPrivacyBody"` (line 308) in `lib/l10n/app_en.arb`:

```json
  "settingsPrivacyBody": "There is no account and no sign-in. Your passport stamps, favourites and saved plan stay on this device. The app collects no analytics.\n\nThe camera is used only to read a QR code, and the image is never stored or sent anywhere.\n\nYour location is used on this device to show where you are on the campus map. It is sent to Google only when you ask for walking directions — and only after you agree.\n\nWayfinding draws its route on a Google map. Loading any Google map sends Google the map request plus the technical request and device information it needs to serve it — but not your location.",
```

Replace `"settingsPrivacyCardTitle"` (line 631) and `"settingsPrivacyTitle"`
(line 307) — both currently read "Nothing leaves your phone", which is no longer
true — with:

```json
  "settingsPrivacyTitle": "What this app shares",
  "settingsPrivacyCardTitle": "What this app shares",
```

- [ ] **Step 4: Rewrite the FA copy**

Replace `"settingsPrivacyBody"` (line 128) in `lib/l10n/app_fa.arb`, and the
matching title keys:

```json
  "settingsPrivacyTitle": "این برنامه چه چیزی را به اشتراک می‌گذارد",
  "settingsPrivacyCardTitle": "این برنامه چه چیزی را به اشتراک می‌گذارد",
  "settingsPrivacyBody": "نه حسابی وجود دارد و نه ورودی. مهرهای پاسپورت، علاقه‌مندی‌ها و برنامهٔ ذخیره‌شدهٔ شما روی همین دستگاه می‌مانند. این برنامه هیچ دادهٔ تحلیلی جمع نمی‌کند.\n\nدوربین فقط برای خواندن کد QR استفاده می‌شود و تصویر آن هرگز ذخیره یا ارسال نمی‌شود.\n\nموقعیت مکانی شما روی همین دستگاه برای نمایش جایگاه شما روی نقشهٔ پردیس به کار می‌رود. تنها زمانی به گوگل ارسال می‌شود که خودتان مسیریابی پیاده بخواهید — و تنها پس از موافقت شما.\n\nمسیریاب، مسیر را روی نقشهٔ گوگل رسم می‌کند. بارگذاری هر نقشهٔ گوگل، درخواست نقشه به‌همراه اطلاعات فنی درخواست و دستگاه لازم برای ارائهٔ آن را به گوگل می‌فرستد — اما موقعیت مکانی شما را نه.",
```

- [ ] **Step 5: Regenerate, run the test, verify it passes**

```bash
flutter gen-l10n
flutter test test/unit/privacy_copy_truth_test.dart
```
Expected: PASS — 2 tests.

- [ ] **Step 6: Run the full gate and commit**

```bash
./scripts/check.sh > /tmp/gate.log 2>&1 && {
  git add lib/l10n/ test/unit/privacy_copy_truth_test.dart
  git commit -m "fix(privacy): tell the truth about Google in EN and FA"
} || { echo "GATE FAILED"; tail -30 /tmp/gate.log; }
```

---

### Task 8: Say so when the user is off campus

`map_screen.dart:77` projects the fix once and gets null off the illustrated
footprint. Today the dot simply vanishes with no explanation — which to App
Review, sitting in Cupertino, reads as broken rather than as designed.

**Files:**
- Modify: `lib/screens/map_screen.dart`, `lib/l10n/app_en.arb`, `lib/l10n/app_fa.arb`
- Create: `test/widget/map_off_campus_banner_test.dart`

- [ ] **Step 1: Add the EN + FA strings**

`lib/l10n/app_en.arb`:

```json
  "mapOffCampusNotice": "You're not on campus — showing the full map.",
  "@mapOffCampusNotice": {
    "description": "Shown when a valid GPS fix falls outside the campus artwork, so the position dot cannot be drawn."
  },
```

`lib/l10n/app_fa.arb`:

```json
  "mapOffCampusNotice": "شما در پردیس نیستید — کل نقشه نمایش داده می‌شود.",
```

Then run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing test**

Create `test/widget/map_off_campus_banner_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/models/campus_geometry.dart';
import 'package:aon2026/services/campus_projection.dart';
import 'package:aon2026/widgets/map_off_campus_notice.dart';

void main() {
  final proj = CampusProjection();

  test('a Cupertino fix does not project onto the campus artwork', () {
    // App Review's actual latitude/longitude. The non-clamping projector must
    // return null rather than pinning them to the edge of Macquarie.
    expect(proj.project(const GpsPoint(LatLng(37.3349, -122.0090))), isNull);
  });

  testWidgets('the notice renders the off-campus explanation', (t) async {
    await t.pumpWidget(const MaterialApp(
      localizationsDelegates: AonL10n.localizationsDelegates,
      supportedLocales: AonL10n.supportedLocales,
      home: Scaffold(body: MapOffCampusNotice()),
    ));
    // Assert on the l10n value, not a copy of it: a literal here breaks on any
    // wording change and silently stops testing the thing it names.
    final l = await AonL10n.delegate.load(const Locale('en'));
    expect(find.text(l.mapOffCampusNotice), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `flutter test test/widget/map_off_campus_banner_test.dart`
Expected: FAIL — `Couldn't resolve ... map_off_campus_notice.dart`.

- [ ] **Step 4: Write the minimal implementation**

Create `lib/widgets/map_off_campus_notice.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';

/// Shown when there IS a valid fix but it falls outside the campus artwork.
///
/// This is a statement of fact, not an error: the projector is deliberately
/// non-clamping, so a position off the illustrated footprint has nowhere
/// truthful to be drawn. Saying so is what separates "designed" from "broken"
/// for anyone using the app away from Macquarie — App Review included.
class MapOffCampusNotice extends StatelessWidget {
  const MapOffCampusNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AonSpacing.space3,
        vertical: AonSpacing.space2,
      ),
      decoration: BoxDecoration(
        color: context.aon.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AonSpacing.radiusSm),
      ),
      child: Text(
        AonL10n.of(context).mapOffCampusNotice,
        style: theme.textTheme.bodySmall
            ?.copyWith(color: context.aon.contentSecondary),
      ),
    );
  }
}
```

- [ ] **Step 5: Render it on the map**

In `lib/screens/map_screen.dart`, just after line 77's `projected` assignment, add:

```dart
    // A fix we HAVE but cannot draw. Distinct from "no fix yet", which is
    // already covered by the locate control's own states.
    final offCampus = fix != null && projected == null;
```

Then, in the same `Stack` that already positions `_MapAttribution`, add a sibling
positioned above it:

```dart
          if (offCampus)
            Positioned(
              left: AonSpacing.space3,
              right: AonSpacing.space3,
              bottom: AonSpacing.space8,
              child: const MapOffCampusNotice(),
            ),
```

Add the import:

```dart
import 'package:aon2026/widgets/map_off_campus_notice.dart';
```

- [ ] **Step 6: Prove MapScreen actually chooses to render it**

The two tests above check the projection and the notice widget separately;
neither proves the map wires them together. Append to
`test/widget/map_off_campus_banner_test.dart`, using the harness from
`test/widget/map_platform_wiring_test.dart`:

```dart
  testWidgets('MapScreen shows the notice for an off-campus fix', (t) async {
    // FakeLocationService seeded with App Review's coordinates.
    final container = mapHarness(
      fix: UserLocationFix(
        position: const LatLng(37.3349, -122.0090),
        accuracyMeters: 10,
      ),
    );
    addTearDown(container.dispose);

    await t.runAsync(() async {
      await t.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AonL10n.localizationsDelegates,
          supportedLocales: AonL10n.supportedLocales,
          home: MapScreen(),
        ),
      ));
      await t.pumpAndSettle();
    });

    expect(find.byType(MapOffCampusNotice), findsOneWidget);
  });

  testWidgets('MapScreen shows no notice for an on-campus fix', (t) async {
    final container = mapHarness(
      fix: UserLocationFix(
        position: MapConfig.campusCentre,
        accuracyMeters: 10,
      ),
    );
    addTearDown(container.dispose);

    await t.runAsync(() async {
      await t.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AonL10n.localizationsDelegates,
          supportedLocales: AonL10n.supportedLocales,
          home: MapScreen(),
        ),
      ));
      await t.pumpAndSettle();
    });

    expect(find.byType(MapOffCampusNotice), findsNothing);
  });
```

`mapHarness` comes from Task 0's `test/support/map_harness.dart`; import it
rather than rebuilding a container here. `runAsync` is required: `MapScreen`
loads the basemap asset, and `rootBundle` does real I/O that hangs a fake-async
zone to a 10-minute timeout.

- [ ] **Step 7: Run the test, then the full gate, then commit**

```bash
flutter test test/widget/map_off_campus_banner_test.dart
./scripts/check.sh > /tmp/gate.log 2>&1 && {
  git add lib/ test/widget/map_off_campus_banner_test.dart
  git commit -m "feat(map): explain an off-campus fix instead of hiding the dot"
} || { echo "GATE FAILED"; tail -30 /tmp/gate.log; }
```

---

### Task 9: Stop the compass pointing across the Pacific

`nearestTargets` (`nearby_targets.dart:88`) sorts by distance and takes N, with no
ceiling. From Cupertino it happily lists Macquarie venues 12,000 km away with
arrows pointing over the ocean. `MapConfig.locationCampusRadiusMeters` (2500)
already exists and is the right bound — do not invent a new constant.

**Files:**
- Modify: `lib/services/nearby_targets.dart`
- Create: `test/unit/nearby_targets_radius_test.dart`

**Interfaces:**
- Produces: `nearestTargets(..., {double maxDistanceMeters})`, defaulting to
  `MapConfig.locationCampusRadiusMeters`.

- [ ] **Step 1: Write the failing test**

Create `test/unit/nearby_targets_radius_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:aon2026/models/building.dart';
import 'package:aon2026/models/search_entry.dart';
import 'package:aon2026/services/nearby_targets.dart';
import 'package:aon2026/widgets/map_config.dart';

List<SearchEntry> _index() => [
      BuildingEntry(
        // BuildingEntry(this.building) is POSITIONAL — search_entry.dart:32.
        const Building(
          id: 'E7A',
          // `code` is REQUIRED (building.dart:18) — omitting it will not compile.
          code: 'E7A',
          name: 'Observatory',
          latitude: -33.7738,
          longitude: 151.1126,
        ),
      ),
    ];

void main() {
  test('an on-campus fix still sees campus targets', () {
    final targets = nearestTargets(const LatLng(-33.7737, 151.1134), _index());
    expect(targets, isNotEmpty);
  });

  test('a Cupertino fix sees nothing rather than a 12,000 km bearing', () {
    final targets = nearestTargets(const LatLng(37.3349, -122.0090), _index());
    expect(targets, isEmpty,
        reason: 'targets beyond the campus radius are not "nearby" in any '
            'sense a compass arrow can express honestly');
  });

  test('the ceiling defaults to the existing campus radius', () {
    // Just outside the radius on the same meridian.
    const far = LatLng(-33.7737 + 0.03, 151.1134);
    expect(nearestTargets(far, _index()), isEmpty);
    expect(
      nearestTargets(far, _index(),
          maxDistanceMeters: MapConfig.locationCampusRadiusMeters * 100),
      isNotEmpty,
      reason: 'the bound must be a parameter, not a hard-coded rule',
    );
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/unit/nearby_targets_radius_test.dart`
Expected: FAIL — the Cupertino test finds one target; `maxDistanceMeters` is not a named parameter.

Verified against `lib/models/building.dart:16-32`: `id`, `code` and `name` are
required; `latitude` / `longitude` are optional. `BuildingEntry(this.building)`
takes its argument positionally (`search_entry.dart:32`).

- [ ] **Step 3: Write the minimal implementation**

In `lib/services/nearby_targets.dart`, change the `nearestTargets` signature and
add the filter:

```dart
List<NearbyTarget> nearestTargets(
  LatLng fix,
  List<SearchEntry> index, {
  String filter = '',
  int maxBuildings = MapConfig.compassMaxBuildingTargets,
  double maxDistanceMeters = MapConfig.locationCampusRadiusMeters,
}) {
  final q = normalizeMapSearch(filter);
  final located = <NearbyTarget>[];
  for (final e in index) {
    final ll = routingLatLngOf(e);
    if (ll == null) continue;
    if (q.isNotEmpty && scoreEntry(e, q) <= 0) continue; // M3 vocabulary (§0R-3)
    final t = _target(e, fix, ll.$1, ll.$2);
    // A target past the campus radius is not "nearby" in any sense an arrow can
    // express honestly — off campus the list is empty and says so, rather than
    // pointing across an ocean.
    if (t.distanceMeters > maxDistanceMeters) continue;
    located.add(t);
  }
  located.sort(_byDistance);
  if (q.isNotEmpty) {
    return located.take(maxBuildings).toList(); // filtered: nearest-N of matches
  }
  final venues = located.where((t) => t.kind == PlaceKind.venue);
  final buildings = located.where((t) => t.kind == PlaceKind.building).take(maxBuildings);
  return [...venues, ...buildings]..sort(_byDistance);
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/unit/nearby_targets_radius_test.dart`
Expected: PASS — 3 tests.

Then run the existing compass suites, which may assume unbounded targets:
`flutter test test/unit/nearby_targets_test.dart test/widget/compass_radar_view_test.dart`
If one fails because its fixture sits outside 2500 m, move the fixture onto
campus. Do **not** raise the ceiling to make an old fixture pass.

- [ ] **Step 5: Say why the list is empty**

Bounding the list without explaining it just moves the confusion. Add —
`lib/l10n/app_en.arb`:

```json
  "nearbyOffCampus": "Nearby places appear when you're on or near campus.",
  "@nearbyOffCampus": { "description": "Empty state for the compass nearby list when every target is beyond the campus radius." },
```

`lib/l10n/app_fa.arb`:

```json
  "nearbyOffCampus": "مکان‌های نزدیک زمانی نمایش داده می‌شوند که در پردیس یا نزدیک آن باشید.",
```

In `lib/widgets/nearby_list.dart`, render `l.nearbyOffCampus` when the target list
is empty *and* there is a fix (an empty list with no fix is already covered by the
existing no-location state). Prove it with a widget test that drives the real
`NearbyList` from a Cupertino fix and expects the string.

- [ ] **Step 6: Run the full gate and commit**

```bash
flutter gen-l10n
./scripts/check.sh > /tmp/gate.log 2>&1 && {
  git add lib/ test/
  git commit -m "fix(compass): bound targets to the campus radius"
} || { echo "GATE FAILED"; tail -30 /tmp/gate.log; }
```

---

### Task 10: Explain the empty "Happening now" before the event

`home_screen.dart:76` passes `emptyMessage: phase.isLive ? l.homeNothingRunningNow : null`.
Before 19 September `phase.isLive` is false, so the message is null and the
section renders empty with no explanation — which is precisely what App Review
will see, since review happens before the event.

**Files:**
- Modify: `lib/screens/home_screen.dart:76`, `lib/l10n/app_en.arb`, `lib/l10n/app_fa.arb`
- Create: `test/widget/home_pre_event_message_test.dart`

- [ ] **Step 1: Add the EN + FA strings**

`lib/l10n/app_en.arb`:

```json
  "homeNothingRunningYet": "Nothing yet — the night begins at {startTime}.",
  "@homeNothingRunningYet": {
    "description": "Empty state for 'Happening now' before the event has started. The date comes from event configuration, never from the translation.",
    "placeholders": { "startTime": { "type": "String" } }
  },
```

`lib/l10n/app_fa.arb`:

```json
  "homeNothingRunningYet": "هنوز چیزی شروع نشده — برنامه در {startTime} آغاز می‌شود.",
```

Run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing test**

Create `test/widget/home_pre_event_message_test.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';

void main() {
  test('a pre-event empty message exists in both locales', () async {
    for (final locale in AonL10n.supportedLocales) {
      final l = await AonL10n.delegate.load(locale);
      expect(l.homeNothingRunningYet.trim(), isNotEmpty,
          reason: 'App Review sees the app before the event; an unexplained '
              'empty section reads as broken');
    }
  });

  test('the date comes from configuration, not from the translation', () async {
    final en = await AonL10n.delegate.load(const Locale('en'));
    // Baking "19 September" into the string makes next year's edition a
    // translation change in two languages. The placeholder is the point.
    expect(en.homeNothingRunningYet('4:00 pm, Saturday 19 September'),
        contains('4:00 pm, Saturday 19 September'));
    expect(en.homeNothingRunningYet('X'), isNot(contains('September')));
  });

  testWidgets('HomeScreen renders the pre-event message', (t) async {
    // The getter tests above pass even if home_screen.dart was never touched.
    final container = ProviderContainer(overrides: [
      // A time before the event, so EventPhase.isLive is false.
      currentTimeProvider.overrideWithValue(DateTime(2026, 9, 1, 12)),
    ]);
    addTearDown(container.dispose);

    await t.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: HomeScreen(),
      ),
    ));
    await t.pumpAndSettle();

    expect(find.textContaining('the night begins at'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `flutter test test/widget/home_pre_event_message_test.dart`
Expected: FAIL — `The getter 'homeNothingRunningYet' isn't defined`.

- [ ] **Step 4: Write the minimal implementation**

In `lib/screens/home_screen.dart:76`, replace:

```dart
                  emptyMessage: phase.isLive ? l.homeNothingRunningNow : null,
```

`EventConfig` has `startsAt` (`event_config.dart:69`) but **no** label getter, so
add one first. In `lib/config/event_config.dart`, beside the existing
`Duration get duration` (line 89):

```dart
  /// A localised "4:00 pm, Saturday 19 September" for copy that must name the
  /// start. Lives here, not in a translation, so next year's edition is a config
  /// change rather than an edit to two ARB files.
  String startTimeLabel(String localeName) =>
      DateFormat("h:mm a, EEEE d MMMM", localeName).format(startsAt);
```

with `import 'package:intl/intl.dart';` at the top of the file. Then replace
line 76 of `home_screen.dart`:

```dart
                  // Before the night, an empty section with no message reads as
                  // a bug — to attendees planning ahead and to App Review alike.
                  emptyMessage: phase.isLive
                      ? l.homeNothingRunningNow
                      : l.homeNothingRunningYet(ref
                          .watch(eventConfigProvider)
                          .startTimeLabel(Localizations.localeOf(context).toString())),
```

- [ ] **Step 5: Run the test, the gate, and commit**

```bash
flutter test test/widget/home_pre_event_message_test.dart
./scripts/check.sh > /tmp/gate.log 2>&1 && {
  git add lib/ test/widget/home_pre_event_message_test.dart
  git commit -m "feat(home): explain the empty programme before the event"
} || { echo "GATE FAILED"; tail -30 /tmp/gate.log; }
```

---

### Task 11: Preview from anywhere

Spec §3c, decision D7. A **visible**, clearly-labelled Settings toggle that seeds
a simulated campus position so the map dot, compass and nearby list come alive
off campus. Visible and documented, therefore not a 2.3.1(a) hidden feature.
Session-only — it resets to off on every launch, so it can never silently mislead
a returning user.

**Files:**
- Create: `lib/services/preview_location.dart`, `test/unit/preview_location_test.dart`
- Modify: `lib/services/location_providers.dart`, `lib/screens/settings_screen.dart`, both ARB files

**Interfaces:**
- Consumes: `LocationService`, `locationServiceProvider`.
- Produces: `PreviewLocationService`, `previewLocationProvider`
  (`NotifierProvider<PreviewLocationNotifier, bool>` with a `set(bool)` method),
  `effectiveLocationServiceProvider`.

- [ ] **Step 1: Write the failing test**

Create `test/unit/preview_location_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/models/user_location_fix.dart';
import 'package:aon2026/services/location_providers.dart';
import 'package:aon2026/services/location_service.dart';
import 'package:aon2026/services/preview_location.dart';
import 'package:aon2026/widgets/map_config.dart';

class _RealService implements LocationService {
  @override
  Future<LocationStatus> status() async => LocationStatus.denied;
  @override
  Future<LocationStatus> request() async => LocationStatus.denied;
  @override
  Stream<UserLocationFix> watch() => const Stream<UserLocationFix>.empty();
  @override
  Stream<bool> serviceEnabledChanges() => const Stream<bool>.empty();
  @override
  Future<void> openAppSettings() async {}
  @override
  Future<void> openLocationSettings() async {}
}

void main() {
  ProviderContainer container() {
    final c = ProviderContainer(overrides: [
      locationServiceProvider.overrideWithValue(_RealService()),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('preview is off by default', () {
    expect(container().read(previewLocationProvider), isFalse);
  });

  test('off, the effective service is the real one', () {
    final c = container();
    expect(c.read(effectiveLocationServiceProvider), isA<_RealService>());
  });

  test('on, the effective service is the preview one', () {
    final c = container();
    c.read(previewLocationProvider.notifier).set(true);
    expect(c.read(effectiveLocationServiceProvider), isA<PreviewLocationService>());
  });

  test('the preview fix sits on campus and is granted', () async {
    const svc = PreviewLocationService();
    expect(await svc.status(), LocationStatus.granted);
    final fix = await svc.watch().first;
    expect(fix.position, MapConfig.campusCentre);
    expect(fix.isLowAccuracy, isFalse,
        reason: 'a simulated fix must not also simulate poor accuracy');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/unit/preview_location_test.dart`
Expected: FAIL — `Couldn't resolve ... preview_location.dart`.

- [ ] **Step 3: Write the minimal implementation**

Create `lib/services/preview_location.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/models/user_location_fix.dart';
import 'package:aon2026/services/location_service.dart';
import 'package:aon2026/widgets/map_config.dart';

/// A simulated on-campus position, for people using the app before they arrive.
///
/// Spec §3c / D7. Deliberately a first-class, user-visible feature rather than a
/// hidden review switch: guideline 2.3.1(a) forbids hidden or dormant
/// functionality, and this is genuinely useful to an attendee planning a
/// one-night event from home.
class PreviewLocationService implements LocationService {
  const PreviewLocationService();

  @override
  Future<LocationStatus> status() async => LocationStatus.granted;

  @override
  Future<LocationStatus> request() async => LocationStatus.granted;

  /// One fix at the campus centre. The stream then closes; `LocationController`
  /// has no `onDone` handler, so a closed stream simply means "no further
  /// updates" — which is exactly true of a fixed simulated point.
  @override
  Stream<UserLocationFix> watch() => Stream<UserLocationFix>.value(
        UserLocationFix(
          position: MapConfig.campusCentre,
          accuracyMeters: 8,
        ),
      );

  @override
  Stream<bool> serviceEnabledChanges() => const Stream<bool>.empty();

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<void> openLocationSettings() async {}
}

/// Session-only: resets to off every launch, so it can never silently mislead a
/// returning user into thinking a simulated dot is their real position.
/// Riverpod 3 has no `StateProvider`, so this is a Notifier with a method.
class PreviewLocationNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool enabled) {
    if (state != enabled) state = enabled;
  }
}

final previewLocationProvider =
    NotifierProvider<PreviewLocationNotifier, bool>(PreviewLocationNotifier.new);
```

- [ ] **Step 4: Route the controller through the effective service**

In `lib/services/location_providers.dart`, add below `locationServiceProvider`:

```dart
/// The service the app actually reads. Preview mode substitutes a simulated
/// on-campus fix; everything downstream is unchanged and unaware.
final effectiveLocationServiceProvider = Provider<LocationService>((ref) {
  return ref.watch(previewLocationProvider)
      ? const PreviewLocationService()
      : ref.watch(locationServiceProvider);
});
```

> **Gauntlet finding (P1).** `location_providers.dart:153` computes
> `wantStream = state.active && (...)`, and `state.active` only becomes true
> after a granted `request()`. Toggling preview on a device where location was
> never granted would therefore do **nothing** — defeating the entire purpose,
> since the feature exists for people who are not on campus and may have
> declined location. Enabling preview must also activate.

Change `LocationController`'s accessor from:

```dart
  LocationService get _svc => ref.read(locationServiceProvider);
```

to:

```dart
  LocationService get _svc => ref.read(effectiveLocationServiceProvider);
```

And inside `LocationController.build()`, next to the existing `ref.listen` calls,
add one so a mid-session toggle re-subscribes:

```dart
    ref.listen(previewLocationProvider, (previous, next) {
      _cancel();
      if (next) {
        // The preview service always grants, so this activates immediately and
        // without an OS prompt. Without it, preview is inert for exactly the
        // users it exists to serve.
        unawaited(ensureLocationActive());
      } else {
        _sync();
      }
    });
```

`unawaited` comes from `dart:async`, which `location_providers.dart` already
imports.

Add a test for it in `test/unit/preview_location_test.dart`:

```dart
  test('enabling preview activates location without a prior grant', () async {
    final c = container();
    expect(c.read(locationControllerProvider).active, isFalse);

    c.read(previewLocationProvider.notifier).set(true);
    await Future<void>.delayed(Duration.zero);

    expect(c.read(locationControllerProvider).active, isTrue,
        reason: 'preview exists for users who never granted location');
  });
```

Add the import to `location_providers.dart`:

```dart
import 'package:aon2026/services/preview_location.dart';
```

- [ ] **Step 5: Add the Settings toggle and its strings**

`lib/l10n/app_en.arb`:

```json
  "settingsPreviewTitle": "Preview from anywhere",
  "@settingsPreviewTitle": { "description": "Settings toggle that simulates an on-campus position." },
  "settingsPreviewBody": "Not on campus yet? Turn this on to see the map, compass and nearby list as they'll look on the night. The position shown is simulated, not your real location.",
  "@settingsPreviewBody": { "description": "Explains that the previewed position is simulated." },
```

`lib/l10n/app_fa.arb`:

```json
  "settingsPreviewTitle": "پیش‌نمایش از هر جایی",
  "settingsPreviewBody": "هنوز در پردیس نیستید؟ این را روشن کنید تا نقشه، قطب‌نما و فهرست نزدیک را همان‌گونه که در شب برنامه خواهند بود ببینید. موقعیت نمایش‌داده‌شده شبیه‌سازی‌شده است، نه مکان واقعی شما.",
```

In `lib/screens/settings_screen.dart`, add:

```dart
            SwitchListTile(
              key: const Key('settings-preview-toggle'),
              contentPadding: EdgeInsets.zero,
              value: ref.watch(previewLocationProvider),
              onChanged: (v) => ref.read(previewLocationProvider.notifier).set(v),
              title: Text(l.settingsPreviewTitle),
              subtitle: Text(l.settingsPreviewBody),
            ),
```

- [ ] **Step 6: Make the simulation visible wherever location is**

> **Review round 2 (P0).** The label lived only on the Settings toggle, while
> map, compass and nearby-list consumers were deliberately "unaware" their fix is
> simulated. Spec §3c says a simulated fix must never be presented as a real one
> — a label on a screen the user is not looking at does not satisfy that.

Add the strings — `lib/l10n/app_en.arb`:

```json
  "previewLocationBadge": "Simulated location",
  "@previewLocationBadge": { "description": "Persistent badge shown wherever a previewed (fake) position is visualised." },
```

`lib/l10n/app_fa.arb`:

```json
  "previewLocationBadge": "موقعیت شبیه‌سازی‌شده",
```

Create `lib/widgets/preview_location_badge.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/services/preview_location.dart';

/// Renders nothing unless preview is on. Spec §3c: a simulated fix must never be
/// presented as a real one, and the Settings toggle is not on screen when the
/// user is looking at the map.
class PreviewLocationBadge extends ConsumerWidget {
  const PreviewLocationBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(previewLocationProvider)) return const SizedBox.shrink();
    return Container(
      key: const Key('preview-location-badge'),
      padding: const EdgeInsets.symmetric(
          horizontal: AonSpacing.space2, vertical: 2),
      decoration: BoxDecoration(
        color: context.aon.info.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AonSpacing.radiusSm),
      ),
      child: Text(
        AonL10n.of(context).previewLocationBadge,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: context.aon.info),
      ),
    );
  }
}
```

Render it in all three places a position is visualised: `map_screen.dart` (in the
same `Stack` at line 191, above `_MapAttribution`), `compass_mode_view.dart`, and
`nearby_list.dart`.

Add a test to `test/unit/preview_location_test.dart` proving the badge is absent
by default and present when previewing, driving the real widget:

```dart
  testWidgets('the badge appears only while previewing', (t) async {
    final c = container();
    await t.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: Scaffold(body: PreviewLocationBadge()),
      ),
    ));
    expect(find.byKey(const Key('preview-location-badge')), findsNothing);

    c.read(previewLocationProvider.notifier).set(true);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('preview-location-badge')), findsOneWidget);
  });
```

- [ ] **Step 7: Prove turning it OFF restores real semantics**

Add to `test/unit/preview_location_test.dart`:

```dart
  test('disabling preview returns to the real, ungranted service', () async {
    final c = container();
    c.read(previewLocationProvider.notifier).set(true);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(locationControllerProvider).active, isTrue);

    c.read(previewLocationProvider.notifier).set(false);
    await Future<void>.delayed(Duration.zero);

    expect(c.read(effectiveLocationServiceProvider), isA<_RealService>());
    expect(c.read(locationControllerProvider).fix, isNull,
        reason: 'the simulated fix must not survive the toggle');
  });
```

If this fails because `_sync()` leaves `active` true against a denied real
service, fix `LocationController` — not the test.

- [ ] **Step 8: Say which location the disclosure means**

While preview is on, `navOriginProvider` reads the effective service and sends the
**simulated** coordinate to Google, yet `mapNavDisclosureBody` says "your current
location". Rather than disabling navigation under preview — which would defeat
§3c's whole purpose of letting App Review exercise the app — make the copy
conditional. Add:

`lib/l10n/app_en.arb`:

```json
  "mapNavDisclosureBodyPreview": "To show a walking route, the simulated preview location — not your real position — is sent to Google Maps.",
  "@mapNavDisclosureBodyPreview": { "description": "Disclosure body while preview mode is active, so the copy names what is actually transmitted." },
```

`lib/l10n/app_fa.arb`:

```json
  "mapNavDisclosureBodyPreview": "برای نمایش مسیر پیاده، موقعیت شبیه‌سازی‌شدهٔ پیش‌نمایش — نه مکان واقعی شما — به نقشهٔ گوگل ارسال می‌شود.",
```

In `MapsNavDisclosure.build`, select `mapNavDisclosureBodyPreview` instead of
`mapNavDisclosureBody` when `ref.watch(previewLocationProvider)` is true. This
makes `MapsNavDisclosure` a `ConsumerWidget`.

- [ ] **Step 9: Regenerate, test, gate, commit**

```bash
flutter gen-l10n
flutter test test/unit/preview_location_test.dart
./scripts/check.sh > /tmp/gate.log 2>&1 && {
  git add lib/ test/unit/preview_location_test.dart
  git commit -m "feat(location): add a visible preview-from-anywhere mode"
} || { echo "GATE FAILED"; tail -30 /tmp/gate.log; }
```

---

### Task 12: Make iPad real

`ios/Runner.xcodeproj/project.pbxproj` sets **`TARGETED_DEVICE_FAMILY = "1,2"`**
at three configurations — *that* is what makes this an iPad app and triggers the
13" screenshot requirement, not the orientation keys. (Revision 1 of this plan and
spec §5g both gave the wrong cause; correct the spec as part of this task.)
Orientation support is a separate requirement, tested separately below.

No milestone has ever verified an iPad layout (decision D6).

**Files:**
- Create: `test/widget/ipad_layout_test.dart`
- Modify: whichever screens overflow (unknown until the test runs — that is the
  point of the task)

- [ ] **Step 1: Write the failing test**

Create `test/widget/ipad_layout_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/screens/home_screen.dart';
import 'package:aon2026/screens/info_screen.dart';
import 'package:aon2026/screens/map_screen.dart';
import 'package:aon2026/screens/my_night_screen.dart';
import 'package:aon2026/screens/passport_screen.dart';
import 'package:aon2026/screens/point_me_screen.dart';
import 'package:aon2026/screens/program_screen.dart';
import 'package:aon2026/screens/settings_screen.dart';
import 'package:aon2026/screens/wayfinding_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 13-inch iPad, portrait and landscape, in logical pixels.
const _portrait = Size(1032, 1376);
const _landscape = Size(1376, 1032);

/// Both shipped locales. RTL is exactly where a "looks fine on iPad" test
/// betrays you: mirrored padding, clipped trailing widgets, overflowing rows
/// that were comfortable LTR.
const _locales = <Locale>[Locale('en'), Locale('fa')];

Widget _host(Widget child, Locale locale) => ProviderScope(
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: child,
      ),
    );

Future<void> _expectNoOverflow(
  WidgetTester t,
  Widget screen,
  Size size,
  double textScale,
  Locale locale,
) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);

  await t.pumpWidget(_host(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: screen,
    ),
    locale,
  ));
  await t.pumpAndSettle();

  // A RenderFlex overflow is reported as a framework exception, so an empty
  // exception queue IS the assertion.
  expect(t.takeException(), isNull);
}

void main() {
  // EVERY public route, not a comfortable subset. Derive this list from
  // AppRoutes in lib/app/router/app_router.dart and fail the task if any public
  // route is missing — a screen absent from this map is a screen nobody checked.
  final screens = <String, Widget>{
    'home': const HomeScreen(),
    'program': const ProgramScreen(),
    'map': const MapScreen(),
    'passport': const PassportScreen(),
    'myNight': const MyNightScreen(),
    'info': const InfoScreen(),
    'settings': const SettingsScreen(),
    'wayfinding': const WayfindingScreen(),
    // point_me_screen.dart:18 — venueId is REQUIRED.
    'pointMe': const PointMeScreen(venueId: 'observatory'),
  };

  for (final entry in screens.entries) {
    for (final locale in _locales) {
      for (final scale in <double>[1.0, 2.0]) {
        final tag = '${entry.key} ${locale.languageCode} @${scale}x';

        testWidgets('$tag does not overflow on iPad portrait', (t) async {
          await _expectNoOverflow(t, entry.value, _portrait, scale, locale);
        });

        testWidgets('$tag does not overflow on iPad landscape', (t) async {
          await _expectNoOverflow(t, entry.value, _landscape, scale, locale);
        });
      }
    }
  }
}
```

- [ ] **Step 2: Run the test and record what actually breaks**

Run: `flutter test test/widget/ipad_layout_test.dart`

Expected: some subset FAILS with `A RenderFlex overflowed by N pixels`. **Write
down which screens and which sizes** before changing anything — that list is the
task's real scope, and guessing it in advance would be exactly the speculation
this plan forbids.

If a screen fails to construct because it needs provider overrides (MapScreen
and PointMeScreen will), copy the harness from
`test/widget/map_platform_wiring_test.dart` — `FakeLocationService` plus
`mapVisibleProvider` — rather than weakening the assertion or dropping the screen
from the matrix. **Dropping a screen is the failure mode this task exists to
prevent.**

- [ ] **Step 3: Fix each overflow at its source**

For each failure, constrain the offending subtree rather than clamping text:
wrap over-wide `Row`s in `Flexible`/`Expanded`, give unbounded `Column`s a
`SingleChildScrollView`, and cap reading-width content with
`ConstrainedBox(constraints: BoxConstraints(maxWidth: 720))` centred in the
available space — a full-bleed 1376 px text column is unreadable regardless of
whether it overflows.

Never lower the text scale to pass. The 2.0 bar is a project constraint.

- [ ] **Step 4: Re-run until green**

Run: `flutter test test/widget/ipad_layout_test.dart`
Expected: PASS — 9 screens x 2 locales x 2 scales x 2 orientations = 72 tests.

- [ ] **Step 5: Prove the last actionable row is reachable**

For any screen you scrolled in step 3, add a `scrollUntilVisible` + `tap`
assertion on its final actionable row. "No overflow" is not the project's bar —
"the last actionable row is reachable *and* tappable" is.

- [ ] **Step 6: Run the full gate and commit**

```bash
./scripts/check.sh > /tmp/gate.log 2>&1 && {
  git add lib/ test/widget/ipad_layout_test.dart
  git commit -m "fix(ipad): make every screen usable at 13-inch sizes"
} || { echo "GATE FAILED"; tail -30 /tmp/gate.log; }
```

---

---

### Task 13: Refuse Routes requests without consent

**Gap found in self-review.** Tasks 2 and 4 stop a *surface* being built, but
`navRouteProvider` would still issue a Routes call, because nothing between it and
`GoogleRoutesService` reads consent.

**Contract, stated honestly (review round 2).** Spec §2c said "cancel or block
in-flight". A request already on the wire cannot be recalled, and a guard
claiming to would be exactly the overclaim this project refuses. The enforceable
contract is:

> **No new Routes request starts after revocation. A request already transmitted
> cannot be recalled; its response is discarded and never reaches the UI or any
> cache.**

Update spec §2c to this wording as part of this task.

**Files:**
- Modify: `lib/services/maps_nav_providers.dart`
- Create: `test/unit/routes_consent_guard_test.dart`

**Interfaces:**
- Consumes: `mapsConsentProvider`, `MapsConsent`, `RoutesService`, `RouteResult`.
- Produces: `ConsentGuardedRoutesService`, wrapping whatever
  `routesServiceProvider` resolves.

- [ ] **Step 1: Write the failing test**

Create `test/unit/routes_consent_guard_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/services/maps_consent_store.dart';
import 'package:aon2026/services/maps_nav_providers.dart';
import 'package:aon2026/services/routes_service.dart';

/// Flips consent while the "request" is in flight.
class _SlowRoutes implements RoutesService {
  _SlowRoutes({required this.onCall});
  final void Function() onCall;
  int calls = 0;
  @override
  Future<RouteResult> walkingRoute({
    required (double lat, double lng) origin,
    required (double lat, double lng) destination,
  }) async {
    calls++;
    onCall(); // user revokes in Settings while we await
    await Future<void>.delayed(Duration.zero);
    return const RouteNetworkFailure();
  }
}

class _SpyRoutes implements RoutesService {
  int calls = 0;
  @override
  Future<RouteResult> walkingRoute({
    required (double lat, double lng) origin,
    required (double lat, double lng) destination,
  }) async {
    calls++;
    return const RouteNetworkFailure();
  }
}

void main() {
  const origin = (-33.7737, 151.1134);
  const dest = (-33.7738, 151.1126);

  test('an unknown-consent request never reaches the network', () async {
    final spy = _SpyRoutes();
    final guarded = ConsentGuardedRoutesService(
      inner: spy,
      consent: () => MapsConsent.unknown,
    );

    final result = await guarded.walkingRoute(origin: origin, destination: dest);

    expect(spy.calls, 0, reason: 'spec §2c: blocked, not merely hidden');
    expect(result, isA<RouteConsentRefused>());
  });

  test('a declined-consent request never reaches the network', () async {
    final spy = _SpyRoutes();
    final guarded = ConsentGuardedRoutesService(
      inner: spy,
      consent: () => MapsConsent.declined,
    );

    await guarded.walkingRoute(origin: origin, destination: dest);
    expect(spy.calls, 0);
  });

  test('an accepted-consent request passes through', () async {
    final spy = _SpyRoutes();
    final guarded = ConsentGuardedRoutesService(
      inner: spy,
      consent: () => MapsConsent.accepted,
    );

    await guarded.walkingRoute(origin: origin, destination: dest);
    expect(spy.calls, 1);
  });

  test('a response arriving after revocation is discarded', () async {
    var consent = MapsConsent.accepted;
    final slow = _SlowRoutes(onCall: () => consent = MapsConsent.unknown);
    final guarded =
        ConsentGuardedRoutesService(inner: slow, consent: () => consent);

    final result = await guarded.walkingRoute(origin: origin, destination: dest);

    expect(slow.calls, 1, reason: 'the request did go out — we do not pretend');
    expect(result, isA<RouteConsentRefused>(),
        reason: 'but its response must never reach the UI after a revoke');
  });

  test('production routesServiceProvider returns a GUARDED service', () async {
    // Every wrapper test above passes even if the provider forgot to wrap.
    final c = ProviderContainer(overrides: [
      mapsConsentSnapshotProvider.overrideWithValue(MapsConsent.unknown),
      androidRoutesKeyProvider.overrideWithValue('k'),
      iosRoutesKeyProvider.overrideWithValue('k'),
    ]);
    addTearDown(c.dispose);

    final svc = await c.read(routesServiceProvider.future);
    expect(svc, isA<ConsentGuardedRoutesService>());
    expect(await svc.walkingRoute(origin: origin, destination: dest),
        isA<RouteConsentRefused>());
  });

  test('consent is read per call, so revoking mid-session takes effect',
      () async {
    final spy = _SpyRoutes();
    var consent = MapsConsent.accepted;
    final guarded =
        ConsentGuardedRoutesService(inner: spy, consent: () => consent);

    await guarded.walkingRoute(origin: origin, destination: dest);
    expect(spy.calls, 1);

    consent = MapsConsent.unknown; // user revoked in Settings
    await guarded.walkingRoute(origin: origin, destination: dest);
    expect(spy.calls, 1, reason: 'a cached accepted value would leak a request');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/unit/routes_consent_guard_test.dart`
Expected: FAIL — `Undefined name 'ConsentGuardedRoutesService'` and `'RouteConsentRefused'`.

- [ ] **Step 3: Add the refusal result**

In `lib/services/routes_service.dart`, alongside the existing `RouteNetworkFailure`
/ `RouteApiFailure` / `RouteMalformed` result types, add:

`RouteResult` is **`sealed`** (`routes_service.dart:25`), so the new type must
`extend` it and must live in that same file — `implements` will not compile:

```dart
/// The request was refused locally because maps consent is not `accepted`.
/// Distinct from every network and parse outcome: nothing left the device.
class RouteConsentRefused extends RouteResult {
  const RouteConsentRefused();
}
```

Sealing also means the blast radius is known, not guessed. There is exactly one
exhaustive switch over `RouteResult`, at `google_nav_screen.dart:144-171`. Add an
arm beside `RouteNoRoute()`:

```dart
      // Consent was revoked between opening the screen and the request. Send the
      // user back through the disclosure rather than showing a network error for
      // a request that never left the device.
      RouteConsentRefused() => _panel(
          context,
          icon: Icons.privacy_tip_outlined,
          message: l.mapNavDisclosureBody,
          actions: [
            // The comment used to say "send the user back through the
            // disclosure" while the panel only showed text. Make it true:
            // re-arming _disclosureRequested makes the next build re-ask.
            FilledButton(
              key: const Key('nav-reopen-disclosure'),
              onPressed: () {
                _disclosureRequested = false;
                ref.read(mapsConsentProvider.notifier).revoke();
              },
              child: Text(l.mapNavDisclosureAccept),
            ),
            if (dest != null) _externalButton(context, l, dest),
          ],
        ),
```

- [ ] **Step 4: Write the guard**

In `lib/services/maps_nav_providers.dart`, add:

```dart
/// Wraps a [RoutesService] so no request leaves the device unless maps consent
/// is `accepted` at the moment of the call.
///
/// Consent is read through a callback rather than captured at construction:
/// caching it would let a request slip out after the user revoked in Settings,
/// which is precisely the leak spec §2c exists to close.
class ConsentGuardedRoutesService implements RoutesService {
  ConsentGuardedRoutesService({required this.inner, required this.consent});

  final RoutesService inner;
  final MapsConsent Function() consent;

  @override
  Future<RouteResult> walkingRoute({
    required (double lat, double lng) origin,
    required (double lat, double lng) destination,
  }) async {
    if (consent() != MapsConsent.accepted) return const RouteConsentRefused();

    final result =
        await inner.walkingRoute(origin: origin, destination: destination);

    // Re-check AFTER the await. An HTTP request already on the wire cannot be
    // recalled — claiming otherwise would be a lie — but its response must not
    // reach the UI or any cache once the user has revoked. This is the honest
    // half of "cancel or block in-flight requests".
    if (consent() != MapsConsent.accepted) return const RouteConsentRefused();
    return result;
  }
}
```

Then wrap the production service — change the `return` at the end of
`routesServiceProvider` from:

```dart
  return GoogleRoutesService(
    client: client,
    apiKey: key,
    platformHeaders: identity.headers,
  );
```

to:

```dart
  return ConsentGuardedRoutesService(
    inner: GoogleRoutesService(
      client: client,
      apiKey: key,
      platformHeaders: identity.headers,
    ),
    consent: () => ref.read(mapsConsentProvider),
  );
```

Add the imports to `maps_nav_providers.dart`:

```dart
import 'maps_consent_providers.dart';
import 'maps_consent_store.dart';
```

- [ ] **Step 5: Run the test, the gate, and commit**

```bash
flutter test test/unit/routes_consent_guard_test.dart
./scripts/check.sh > /tmp/gate.log 2>&1 && {
  git add lib/services/ test/unit/routes_consent_guard_test.dart
  git commit -m "fix(consent): block Routes requests unless consent is accepted"
} || { echo "GATE FAILED"; tail -30 /tmp/gate.log; }
```

---

### Task 14: Show the Google SDK legal notices

**Gap found in self-review.** Spec §5d point 3 requires the Maps SDK licence text
from `GMSServices.openSourceLicenseInfo` to be reachable in Legal/About. Task 5
handled attribution copy but not this.

**Files:**
- Modify: `lib/services/maps_sdk_initializer.dart`, `ios/Runner/AppDelegate.swift`,
  `lib/screens/info_screen.dart`, both ARB files
- Create: `test/unit/maps_legal_notices_test.dart`

**Interfaces:**
- Produces: `MapsSdkInitializer.openSourceLicenseInfo()` returning `Future<String?>`
  (null where the platform has none), added to the interface from Task 1.

- [ ] **Step 1: Write the failing test**

Create `test/unit/maps_legal_notices_test.dart`:

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/services/maps_sdk_initializer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('aon2026/maps_sdk');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('licence text is fetched over the channel', () async {
    messenger.setMockMethodCallHandler(channel, (call) async =>
        call.method == 'openSourceLicenseInfo' ? 'Apache 2.0 …' : null);

    final init = PlatformMapsSdkInitializer();
    expect(await init.openSourceLicenseInfo(), startsWith('Apache 2.0'));
  });

  test('a platform without licence text yields null, not a crash', () async {
    // No handler registered → MissingPluginException.
    final init = PlatformMapsSdkInitializer();
    expect(await init.openSourceLicenseInfo(), isNull);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/unit/maps_legal_notices_test.dart`
Expected: FAIL — `The method 'openSourceLicenseInfo' isn't defined`.

- [ ] **Step 3: Extend the Dart side**

In `lib/services/maps_sdk_initializer.dart`, add to the `MapsSdkInitializer`
interface:

```dart
  /// The Maps SDK's open-source licence text, for Legal/About. Null where the
  /// platform supplies none.
  Future<String?> openSourceLicenseInfo();
```

Implement it on `PlatformMapsSdkInitializer`:

```dart
  @override
  Future<String?> openSourceLicenseInfo() async {
    try {
      return await _channel.invokeMethod<String>('openSourceLicenseInfo');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
```

And on `NoopMapsSdkInitializer`:

```dart
  @override
  Future<String?> openSourceLicenseInfo() async => null;
```

- [ ] **Step 4: Extend the iOS handler**

In `ios/Runner/AppDelegate.swift`, replace the method-call handler body from
Task 1 with:

```swift
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "initialize":
        result(self?.initializeMapsSdk() ?? false)
      case "openSourceLicenseInfo":
        // Available without keying the SDK — it is static bundled text, not a
        // network call, so exposing it never contacts Google.
        result(GMSServices.openSourceLicenseInfo())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
```

**Android: do not mirror this.** `GoogleApiAvailability.getOpenSourceSoftwareLicenseInfo`
has been deprecated since Google Play services v11.0, and Google states there is
no longer a requirement to call it — Play services licences are surfaced by the
OS at *Settings → Google → Open Source Licenses*. There is nothing for the app to
render. Return `null` from the Android
branch and let the Credits button hide itself:

```kotlin
                "openSourceLicenseInfo" -> result(null)
```

Re-check the current Android requirement in the release-mechanics plan rather
than forcing API symmetry that Google itself has retired.

- [ ] **Step 5: Surface it in Credits**

Add strings — `lib/l10n/app_en.arb`:

```json
  "creditsMapsLicences": "Google Maps licences",
  "@creditsMapsLicences": { "description": "Credits entry opening the Maps SDK open-source licence text." },
```

`lib/l10n/app_fa.arb`:

```json
  "creditsMapsLicences": "مجوزهای نقشهٔ گوگل",
```

In `lib/screens/info_screen.dart`, after the `l.creditsMapDataBody` Text (around
line 253), add:

```dart
          FutureBuilder<String?>(
            future: ref.read(mapsSdkInitializerProvider).openSourceLicenseInfo(),
            builder: (context, snapshot) {
              final text = snapshot.data;
              // Hide entirely when there is nothing to show — an empty legal
              // page is worse than no button.
              if (text == null || text.isEmpty) return const SizedBox.shrink();
              return TextButton(
                key: const Key('credits-maps-licences'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: Text(l.creditsMapsLicences)),
                      body: SingleChildScrollView(
                        padding: const EdgeInsets.all(AonSpacing.space4),
                        child: SelectableText(
                          text,
                          key: const Key('maps-licence-text'),
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                      ),
                    ),
                  ),
                ),
                child: Text(l.creditsMapsLicences),
              );
            },
          ),
```

- [ ] **Step 5b: Prove Credits actually exposes it**

The channel test above passes even if `info_screen.dart` was never touched. Add to
`test/unit/maps_legal_notices_test.dart`:

```dart
  testWidgets('Credits shows the licence button and opens the text', (t) async {
    final c = ProviderContainer(overrides: [
      mapsSdkInitializerProvider.overrideWithValue(_LicenceInitializer()),
    ]);
    addTearDown(c.dispose);

    await t.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: InfoScreen(),
      ),
    ));
    await t.pumpAndSettle();

    // scrollUntilVisible stops as soon as the target enters the viewport, which
    // can leave it under an edge — quick_access_test.dart:63 hit exactly this.
    await t.scrollUntilVisible(
        find.byKey(const Key('credits-maps-licences')), 200);
    await t.ensureVisible(find.byKey(const Key('credits-maps-licences')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('credits-maps-licences')));
    await t.pumpAndSettle();

    expect(find.byKey(const Key('maps-licence-text')), findsOneWidget);
  });

  testWidgets('no licence text means no button', (t) async {
    final c = ProviderContainer(overrides: [
      mapsSdkInitializerProvider.overrideWithValue(const NoopMapsSdkInitializer()),
    ]);
    addTearDown(c.dispose);

    await t.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: InfoScreen(),
      ),
    ));
    await t.pumpAndSettle();

    expect(find.byKey(const Key('credits-maps-licences')), findsNothing);
  });
```

with the fake:

```dart
class _LicenceInitializer implements MapsSdkInitializer {
  @override
  Future<bool> ensureInitialized() async => true;
  @override
  Future<String?> openSourceLicenseInfo() async => 'Apache 2.0 …';
}
```

- [ ] **Step 6: Regenerate, test, gate, commit**

```bash
flutter gen-l10n
flutter test test/unit/maps_legal_notices_test.dart
./scripts/check.sh > /tmp/gate.log 2>&1 && {
  git add lib/ ios/ android/ test/unit/maps_legal_notices_test.dart
  git commit -m "feat(credits): expose the Google Maps SDK licence notices"
} || { echo "GATE FAILED"; tail -30 /tmp/gate.log; }
```


---

### Task 15: Lock the invariant with an architecture test

Task 2's provider is the single enforcement point, but nothing stops a future
call site reading `mapsSdkInitializerProvider` and calling `ensureInitialized()`
directly. A grep test is cheap and makes the boundary real rather than asserted.

**Files:**
- Create: `test/unit/maps_sdk_boundary_test.dart`

- [ ] **Step 1: Write the test**

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Future<List<String>> _filesContaining(String needle) async {
  final hits = <String>[];
  await for (final entity in Directory('lib').list(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    if ((await entity.readAsString()).contains(needle)) hits.add(entity.path);
  }
  return hits;
}

void main() {
  test('only maps_sdk_initializer.dart may call ensureInitialized', () async {
    final offenders = (await _filesContaining('ensureInitialized()'))
        .where((p) => !p.endsWith('maps_sdk_initializer.dart'))
        .toList();

    expect(offenders, isEmpty,
        reason: 'spec §2b is enforced by mapsSdkReadyProvider. Calling the '
            'initialiser directly bypasses the consent check — watch the '
            'provider instead.');
  });

  test('only embedded_map.dart may construct a GoogleMap', () async {
    // The consent gate protects the paths we know about. This makes a NEW
    // Google surface impossible to add without tripping a test — which is the
    // failure mode that produced the google_nav_screen regression.
    final offenders = (await _filesContaining('GoogleMap('))
        .where((p) => !p.endsWith('embedded_map.dart'))
        .toList();

    expect(offenders, isEmpty,
        reason: 'route every Google surface through EmbeddedMap so it inherits '
            'the mapsSdkReadyProvider gate');
  });

  test('flutter_map is still in use — do NOT drop the dependency', () async {
    // Task 5 deletes DarkTileLayer, which invites "flutter_map is dead now".
    // It is not: map_screen.dart renders the CrsSimple AON basemap with it.
    final consumers = await _filesContaining('package:flutter_map/');
    expect(consumers, contains('lib/screens/map_screen.dart'));
  });
}
```

- [ ] **Step 2: Run it**

Run: `flutter test test/unit/maps_sdk_boundary_test.dart`
Expected: PASS once Tasks 1-4 are done. **If the first test fails it has found a
real bypass — fix the call site, never the test.**

- [ ] **Step 3: Run the full gate and commit**

```bash
./scripts/check.sh > /tmp/gate.log 2>&1 && {
  git add test/unit/maps_sdk_boundary_test.dart
  git commit -m "test(maps): lock the consent boundary with an architecture test"
} || { echo "GATE FAILED"; tail -30 /tmp/gate.log; }
```

## Done means

- `./scripts/check.sh` green, exit-gated.
- No shipped string claims OpenStreetMap attribution, and none denies the Google
  surface (Tasks 5, 7 — both locked by tests).
- **No Google surface can be constructed** before consent is `accepted` — proved
  directly on *both* surfaces, `GoogleNavScreen` (Task 4 step 6) and wayfinding
  (step 6b), and locked against bypass by Task 15.
- **No Routes request starts after revocation**, and a response from a request
  already on the wire is discarded rather than reaching the UI (Task 13) — proved
  on the production `routesServiceProvider`, not only on the wrapper.
- **Deletion is honest**: it clears the running session as well as storage,
  reports failure truthfully, and the no-op default fails closed (Task 6).
- **Preview mode is visibly simulated everywhere** a position is drawn, disabling
  it restores real-location semantics, and the nav disclosure names the simulated
  location when preview is active (Task 11).
- **Every public route survives iPad** in EN and FA, portrait and landscape, at
  textScale 1.0 and 2.0 (Task 12).
- **Legal notices are reachable from Credits**, proved by driving `InfoScreen`
  (Task 14).
- App Review can exercise the app from Cupertino: off-campus notice, bounded
  compass with an explanation, pre-event programme message, preview mode, and —
  from the companion release-mechanics plan — sample stamp codes in the Notes for
  Review.

**One acceptance criterion this plan cannot satisfy.** Unit tests prove the
architecture; only a packet capture proves reality. The release-mechanics plan
owns a physical-device network test: **zero Google traffic on a cold launch
before consent, traffic permitted after accepting, no new Google traffic after
revoking.** Until that runs, §2b is verified in the suite and *unverified on a
device* — say so rather than implying otherwise.

## Out of scope for this plan

Release mechanics: Android upload keystore and the Play App Signing fingerprint
chain, iOS production signing, `ITSAppUsesNonExemptEncryption`, version and build
numbers, `PrivacyInfo.xcprivacy` and the archive privacy audit, GCP key creation
and restriction-rejection proof, store metadata, screenshots, Notes for Review,
privacy labels, Data Safety, age rating, and the hosted MQ URLs. Those are spec
§4, §5a, §6 and §2d–g, and they get a checklist-shaped plan rather than TDD.
