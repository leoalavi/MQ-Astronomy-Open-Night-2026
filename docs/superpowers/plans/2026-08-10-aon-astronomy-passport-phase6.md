# Astronomy Passport (Phase 6) Implementation Plan — v2

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A scan-and-collect "Astronomy Passport" — collect a stamp at each of the 9 event venues (QR scan or manual code), and on all 9 show a live, completion-guarded reward screen to redeem a prize at a staffed booth.

**Architecture:** A pure domain core (typed `StampInput` → `StampService` → `StampResult`) under a Riverpod `PassportNotifier` that owns the release gate and serialized, non-fatal persistence. UI (grid, capture, reward, entry points) is thin. The camera is lazy (created only when the user taps Scan), debounced, resumable, and fully decoupled behind an `onDecoded` seam so the whole flow is testable without hardware.

**Tech Stack:** Flutter `>=3.44`, Dart `^3.11`, Riverpod 3 (`flutter_riverpod ^3.3.2`), `go_router ^17.3.0`, plus three keyless deps: `shared_preferences`, `mobile_scanner` (7.x), `confetti`.

## Global Constraints

- **No secrets, no backend, no accounts.** Station codes are low-friction event tokens, NOT secrets or proof of attendance (spec §4.1). Never describe them as secure.
- **Lazy camera (spec §5):** the camera is created ONLY after the user taps "Scan". Opening the capture screen must NOT start the camera or trigger a permission prompt. Manual entry must be usable without ever constructing the scanner.
- **Persistence never blocks launch** (spec §3.1): hydration failure ⇒ empty passport; writes are **serialized** and non-fatal; UI stays synchronous.
- **Completion counts `collected ∩ stationVenueIds`** (spec §4.3), never raw set size.
- **Typed input** (spec §3.2): a bare token is valid from manual entry; a QR without the `AON2026:` namespace is `unknown`.
- **Release gate is a DOMAIN invariant** (spec §10): `PassportNotifier.collect` itself refuses collection while any station code is `placeholder` in a release build — not just the UI.
- **The reward screen enforces completion** (spec §7.2): it must read `passportProvider` and refuse to show redemption unless `isComplete`.
- **Text scale 2.0** is permanent: EVERY new Flutter surface has a `320×568 / 2.0` regression (grid, manual entry, scan chrome, passport, reward, home card).
- **Reduced motion**: `MediaQuery.disableAnimationsOf(context)`; reduced ⇒ no confetti widget at all.
- **No 6th nav tab.** Entry points are the Home card + Info-screen menu.
- **Lint** (`analysis_options.yaml`): `prefer_single_quotes`, `prefer_const_constructors`, `always_declare_return_types`, `unawaited_futures` (wrap fire-and-forget in `unawaited(...)`).
- **Widget-test harness:** to apply a viewport or OS text scale use `tester.view.physicalSize` + `tester.platformDispatcher.textScaleFactorTestValue` (with teardowns), or inject via `MaterialApp(builder:)`. An outer `MediaQuery` around `MaterialApp` is reset and tests nothing (see `text_scale_policy_test.dart:27`, `responsive_layout_test.dart:31`).
- **Timers in tests:** for any screen with a `Timer`/confetti, use `pump(Duration)` (never `pumpAndSettle`) and dispose the tree before the test ends (`pumpWidget(const SizedBox.shrink())`).
- **Per-task gate:** `flutter analyze && flutter test` — clean and green. Never loosen a Phase 1–5 test.

---

## File Structure

**Create:** `lib/models/stamp_station.dart`, `lib/data/stamp_stations_data.dart`, `lib/models/stamp_io.dart`, `lib/services/stamp_service.dart`, `lib/services/passport_store.dart`, `lib/services/passport_providers.dart`, `lib/services/scan_gate.dart`, `lib/widgets/passport_grid.dart`, `lib/widgets/passport_home_card.dart`, `lib/widgets/passport_scanner_view.dart`, `lib/screens/passport_screen.dart`, `lib/screens/passport_scan_screen.dart`, `lib/screens/passport_reward_screen.dart`, and mirrored tests.

**Modify:** `pubspec.yaml`, `lib/main.dart`, `lib/app/router/app_router.dart`, `lib/screens/home_screen.dart`, `lib/screens/info_screen.dart`, `test/unit/data_integrity_test.dart`, `ios/Runner/Info.plist`, `android/app/src/main/AndroidManifest.xml`, `docs/data-sources.md`.

**Task order (dead-intermediate-free):** 0 preflight → 1 data → 2 domain → 3 store → 4 notifier → 5 main → 6 route constants → 7 grid → 8 capture (manual) → 9 reward (guarded) → 10 passport screen (links to 8 & 9) → 11 lazy scanner peer → 12 entry points → 13 platform + runtime + verify. Reward and capture exist **before** the passport screen links to them; the scanner is added last so no commit ships a dead camera.

---

## Task 0: Preflight & baseline

**Files:** none (records state only).

- [ ] **Step 1: Confirm branch + clean tree**

Run:
```bash
git branch --show-current   # expect feature/astronomy-passport-phase6
git status --short          # expect empty
git rev-parse HEAD          # record base SHA
```
If not on the feature branch: `git checkout feature/astronomy-passport-phase6` (it already exists with the spec + plan commits).

- [ ] **Step 2: Record baseline analyze + test counts**

Run: `flutter analyze && flutter test`
Expected: analyze clean; all existing tests pass. **Write the exact test count down** (e.g. "239 passing") — Task 13 asserts the suite only grew.

- [ ] **Step 3: Baseline builds (pre-dependency)**

Run: `flutter build web && flutter build apk --debug`
Expected: both succeed on the current tree, before any new dependency. This isolates any later build breakage to a Phase 6 change.

- [ ] **Step 4: No commit** — Task 0 records state only.

---

## Task 1: Station data model + integrity (exact event-venue equality)

**Files:** Create `lib/models/stamp_station.dart`, `lib/data/stamp_stations_data.dart`; Modify `test/unit/data_integrity_test.dart`.

**Interfaces:**
- Produces: `StampStation({required String venueId, required String code, DataConfidence codeConfidence})`; `StampStationsData.all`, `.count`, `.stationVenueIds`, `.byVenueId(String)`.

- [ ] **Step 1: Write the failing test** — add imports at the **top** of `test/unit/data_integrity_test.dart`, then insert the `group` **inside** `void main()`:

```dart
// Top-of-file imports:
import 'package:aon2026/data/stamp_stations_data.dart';
import 'package:aon2026/data/venues_data.dart';
import 'package:aon2026/models/data_confidence.dart';
```

```dart
// Inside main():
group('passport stations', () {
  final stations = StampStationsData.all;

  test('there are exactly 9 stations', () {
    expect(stations.length, 9);
    expect(StampStationsData.count, 9);
  });

  test('the station set EQUALS the event-venue set (both directions)', () {
    final eventVenueIds = VenuesData.eventVenues.map((v) => v.id).toSet();
    // Not just subset: adding a 10th event venue must force a passport decision.
    expect(StampStationsData.stationVenueIds, eventVenueIds);
  });

  test('venueIds and codes are each unique', () {
    expect(stations.map((s) => s.venueId).toSet().length, 9);
    expect(stations.map((s) => s.code.toUpperCase()).toSet().length, 9);
  });
});
```

- [ ] **Step 2: Run test to verify it fails** — Run: `flutter test test/unit/data_integrity_test.dart` — Expected: FAIL (`StampStationsData` undefined).

- [ ] **Step 3: Implement** — `lib/models/stamp_station.dart`:

```dart
import 'package:aon2026/models/data_confidence.dart';

/// One stop on the Astronomy Passport trail. [code] is a low-friction event
/// token printed on the venue sign — NOT a secret and NOT proof of attendance
/// (design §4.1). Staff redemption at the booth is the actual control.
class StampStation {
  const StampStation({
    required this.venueId,
    required this.code,
    this.codeConfidence = DataConfidence.placeholder,
  });

  final String venueId;
  final String code;
  final DataConfidence codeConfidence;
}
```

`lib/data/stamp_stations_data.dart`:

```dart
import 'package:aon2026/models/stamp_station.dart';

/// The 9 passport stations — the map-legend A–I event venues. Codes are
/// PLACEHOLDER until the organiser confirms the signage tokens (design §14);
/// while any is placeholder the domain release gate keeps collection disabled
/// in release builds (PassportPolicy / passportCollectionEnabledProvider).
abstract final class StampStationsData {
  static const List<StampStation> all = [
    StampStation(venueId: 'macquarie-theatre', code: 'AON-A-TBC'),
    StampStation(venueId: 'mason-theatre', code: 'AON-B-TBC'),
    StampStation(venueId: 'central-courtyard', code: 'AON-C-TBC'),
    StampStation(
        venueId: '14-sir-christopher-ondaatje-avenue', code: 'AON-D-TBC'),
    StampStation(venueId: '1-central-courtyard', code: 'AON-E-TBC'),
    StampStation(venueId: 'sport-and-aquatic-centre', code: 'AON-F-TBC'),
    StampStation(venueId: 'astronomical-observatory', code: 'AON-G-TBC'),
    StampStation(venueId: '11-wallys-walk', code: 'AON-H-TBC'),
    StampStation(venueId: '17-wallys-walk', code: 'AON-I-TBC'),
  ];

  static int get count => all.length;
  static Set<String> get stationVenueIds => all.map((s) => s.venueId).toSet();
  static StampStation? byVenueId(String venueId) {
    for (final s in all) {
      if (s.venueId == venueId) return s;
    }
    return null;
  }
}
```

- [ ] **Step 4: Run test to verify it passes** — Run: `flutter test test/unit/data_integrity_test.dart` — Expected: PASS.

- [ ] **Step 5: Commit**
```bash
git add lib/models/stamp_station.dart lib/data/stamp_stations_data.dart test/unit/data_integrity_test.dart
git commit -m "feat(passport): 9-station data model + exact event-venue integrity (Phase 6)"
```

---

## Task 2: Typed input/result (+disabled) + pure resolver + policy

**Files:** Create `lib/models/stamp_io.dart`, `lib/services/stamp_service.dart`, `test/unit/stamp_service_test.dart`.

**Interfaces:**
- `StampInput.scan(String rawQr)` → `ScanInput`; `StampInput.manual(String rawCode)` → `ManualInput`.
- `StampResult`: `StampCollected(String venueId)`, `StampAlreadyHave(String venueId)`, `StampUnknown()`, `StampDisabled()`.
- `StampService.resolve(StampInput, Set<String>) → StampResult`.
- `PassportPolicy.{stationVenueIds, stationCount, completedCount(Set<String>), isComplete(Set<String>), isCollectionEnabled(List<StampStation>, {required bool isRelease})}`.

- [ ] **Step 1: Write the failing test** — `test/unit/stamp_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/models/stamp_io.dart';
import 'package:aon2026/models/stamp_station.dart';
import 'package:aon2026/models/data_confidence.dart';
import 'package:aon2026/data/stamp_stations_data.dart';
import 'package:aon2026/services/stamp_service.dart';

void main() {
  const goodCode = 'AON-A-TBC';
  const goodVenue = 'macquarie-theatre';

  group('resolve — manual', () {
    test('valid bare code collects', () {
      final r = StampService.resolve(StampInput.manual(goodCode), <String>{});
      expect(r, isA<StampCollected>());
      expect((r as StampCollected).venueId, goodVenue);
    });
    test('case/space-insensitive', () {
      expect(StampService.resolve(StampInput.manual('  aon-a-tbc '), <String>{}),
          isA<StampCollected>());
    });
    test('already collected ⇒ alreadyHave', () {
      expect(StampService.resolve(StampInput.manual(goodCode), {goodVenue}),
          isA<StampAlreadyHave>());
    });
    test('unknown ⇒ unknown', () {
      expect(StampService.resolve(StampInput.manual('NOPE'), <String>{}),
          isA<StampUnknown>());
    });
  });

  group('resolve — scan (namespace required)', () {
    test('namespaced QR collects', () {
      expect(
          StampService.resolve(StampInput.scan('AON2026:$goodCode'), <String>{}),
          isA<StampCollected>());
    });
    test('un-namespaced QR ⇒ unknown even if token is real', () {
      expect(StampService.resolve(StampInput.scan(goodCode), <String>{}),
          isA<StampUnknown>());
    });
    test('foreign QR ⇒ unknown', () {
      expect(
          StampService.resolve(
              StampInput.scan('https://example.com'), <String>{}),
          isA<StampUnknown>());
    });
  });

  group('PassportPolicy', () {
    test('completedCount uses intersection', () {
      expect(PassportPolicy.completedCount({goodVenue, 'stale'}), 1);
    });
    test('isComplete needs all 9', () {
      expect(PassportPolicy.isComplete(StampStationsData.stationVenueIds), isTrue);
      expect(PassportPolicy.isComplete({goodVenue}), isFalse);
    });
    test('release gate disabled while any placeholder', () {
      expect(
          PassportPolicy.isCollectionEnabled(StampStationsData.all,
              isRelease: true),
          isFalse);
    });
    test('release gate enabled when all confirmed', () {
      final confirmed = [
        for (final s in StampStationsData.all)
          StampStation(
              venueId: s.venueId,
              code: s.code,
              codeConfidence: DataConfidence.confirmed),
      ];
      expect(PassportPolicy.isCollectionEnabled(confirmed, isRelease: true),
          isTrue);
    });
    test('debug always enabled', () {
      expect(
          PassportPolicy.isCollectionEnabled(StampStationsData.all,
              isRelease: false),
          isTrue);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails** — Run: `flutter test test/unit/stamp_service_test.dart` — Expected: FAIL.

- [ ] **Step 3: Implement** — `lib/models/stamp_io.dart`:

```dart
sealed class StampInput {
  const StampInput();
  const factory StampInput.scan(String rawQr) = ScanInput;
  const factory StampInput.manual(String rawCode) = ManualInput;
}

class ScanInput extends StampInput {
  const ScanInput(this.rawQr);
  final String rawQr;
}

class ManualInput extends StampInput {
  const ManualInput(this.rawCode);
  final String rawCode;
}

sealed class StampResult {
  const StampResult();
}

class StampCollected extends StampResult {
  const StampCollected(this.venueId);
  final String venueId;
}

class StampAlreadyHave extends StampResult {
  const StampAlreadyHave(this.venueId);
  final String venueId;
}

class StampUnknown extends StampResult {
  const StampUnknown();
}

/// Collection is currently disabled (release build with unconfirmed codes).
class StampDisabled extends StampResult {
  const StampDisabled();
}
```

`lib/services/stamp_service.dart`:

```dart
import 'package:aon2026/data/stamp_stations_data.dart';
import 'package:aon2026/models/stamp_io.dart';
import 'package:aon2026/models/stamp_station.dart';

abstract final class StampService {
  static const String _qrNamespace = 'AON2026:';

  static StampResult resolve(StampInput input, Set<String> collected) {
    final token = switch (input) {
      ScanInput(:final rawQr) => _tokenFromQr(rawQr),
      ManualInput(:final rawCode) => _normalize(rawCode),
    };
    if (token == null) return const StampUnknown();
    for (final s in StampStationsData.all) {
      if (_normalize(s.code) == token) {
        return collected.contains(s.venueId)
            ? StampAlreadyHave(s.venueId)
            : StampCollected(s.venueId);
      }
    }
    return const StampUnknown();
  }

  static String? _tokenFromQr(String rawQr) {
    final t = rawQr.trim();
    if (!t.toUpperCase().startsWith(_qrNamespace)) return null;
    return _normalize(t.substring(_qrNamespace.length));
  }

  static String _normalize(String raw) => raw.trim().toUpperCase();
}

abstract final class PassportPolicy {
  static Set<String> get stationVenueIds => StampStationsData.stationVenueIds;
  static int get stationCount => StampStationsData.count;
  static int completedCount(Set<String> collected) =>
      collected.intersection(stationVenueIds).length;
  static bool isComplete(Set<String> collected) =>
      completedCount(collected) >= stationCount;

  /// Release builds refuse collection while any code is unconfirmed; debug
  /// always allows it (pre-event QA with placeholder/demo codes).
  static bool isCollectionEnabled(List<StampStation> stations,
      {required bool isRelease}) {
    if (!isRelease) return true;
    return stations.every((s) => s.codeConfidence.isReliable);
  }
}
```

- [ ] **Step 4: Run test to verify it passes** — Run: `flutter test test/unit/stamp_service_test.dart` — Expected: PASS.

- [ ] **Step 5: Commit**
```bash
git add lib/models/stamp_io.dart lib/services/stamp_service.dart test/unit/stamp_service_test.dart
git commit -m "feat(passport): typed input (+disabled), pure resolver, policy (Phase 6)"
```

---

## Task 3: Persistence seam + real adapter test

**Files:** Modify `pubspec.yaml`; Create `lib/services/passport_store.dart`, `test/unit/passport_store_test.dart`.

**Interfaces:** `abstract interface class PassportStore { Future<Set<String>> loadSnapshot(); Future<bool> save(Set<String>); }`; `SharedPrefsPassportStore(SharedPreferencesAsync)`.

- [ ] **Step 1: Add dependency** — Run: `flutter pub add shared_preferences` — Expected: `shared_preferences: ^2.5.5` (or newer 2.x); `pub get` OK.

- [ ] **Step 2: Write the failing test** — `test/unit/passport_store_test.dart`. This tests BOTH the contract (via a fake) AND the real `SharedPrefsPassportStore` round-trip (via the in-memory async platform — confirmed present at `shared_preferences_platform_interface/lib/in_memory_shared_preferences_async.dart`):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:aon2026/services/passport_store.dart';

class InMemoryPassportStore implements PassportStore {
  InMemoryPassportStore([Set<String>? initial]) : _data = {...?initial};
  Set<String> _data;
  bool failNextSave = false;
  @override
  Future<Set<String>> loadSnapshot() async => {..._data};
  @override
  Future<bool> save(Set<String> v) async {
    if (failNextSave) {
      failNextSave = false;
      return false;
    }
    _data = {...v};
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fake contract: save/load round-trips; failed save is non-fatal',
      () async {
    final s = InMemoryPassportStore();
    expect(await s.save({'a', 'b'}), isTrue);
    expect(await s.loadSnapshot(), {'a', 'b'});
    s.failNextSave = true;
    expect(await s.save({'a', 'b', 'c'}), isFalse);
    expect(await s.loadSnapshot(), {'a', 'b'}); // prior data intact
  });

  test('real SharedPrefsPassportStore round-trips via in-memory platform',
      () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final store = SharedPrefsPassportStore(SharedPreferencesAsync());
    expect(await store.loadSnapshot(), isEmpty);
    expect(await store.save({'macquarie-theatre', 'mason-theatre'}), isTrue);
    expect(await store.loadSnapshot(),
        {'macquarie-theatre', 'mason-theatre'});
  });
}
```

(If the exact platform-interface import path differs for the resolved version, adjust it — the class name `InMemorySharedPreferencesAsync` is stable. If unavailable, delete this second test and mark persistence restoration as a mandatory item in the Task 13 iOS runtime pass, and weaken the Task 3 doc comment accordingly.)

- [ ] **Step 3: Run test to verify it fails** — Run: `flutter test test/unit/passport_store_test.dart` — Expected: FAIL (`passport_store` undefined).

- [ ] **Step 4: Implement** — `lib/services/passport_store.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';

/// The app's first persisted mutable state. Every method is best-effort and
/// MUST NOT throw to its caller (design §3.1). Round-trip is unit-tested in
/// passport_store_test.dart via the in-memory async platform.
abstract interface class PassportStore {
  Future<Set<String>> loadSnapshot();
  Future<bool> save(Set<String> venueIds);
}

class SharedPrefsPassportStore implements PassportStore {
  SharedPrefsPassportStore(this._prefs);
  final SharedPreferencesAsync _prefs;
  static const String _key = 'passport.collectedVenueIds';

  @override
  Future<Set<String>> loadSnapshot() async {
    try {
      final list = await _prefs.getStringList(_key);
      return list?.toSet() ?? <String>{};
    } catch (_) {
      return <String>{};
    }
  }

  @override
  Future<bool> save(Set<String> venueIds) async {
    try {
      await _prefs.setStringList(_key, venueIds.toList());
      return true;
    } catch (_) {
      return false;
    }
  }
}
```

- [ ] **Step 5: Run tests** — Run: `flutter test test/unit/passport_store_test.dart && flutter analyze` — Expected: PASS; clean.

- [ ] **Step 6: Commit**
```bash
git add pubspec.yaml pubspec.lock lib/services/passport_store.dart test/unit/passport_store_test.dart
git commit -m "feat(passport): non-fatal persistence seam + real-adapter round-trip test (Phase 6)"
```

---

## Task 4: Notifier + providers (harmless defaults, domain gate, serialized writes)

**Files:** Create `lib/services/passport_providers.dart`, `test/unit/passport_notifier_test.dart`.

**Interfaces:**
- `passportSnapshotProvider` (`Provider<Set<String>>`, default `{}`), `passportStoreProvider` (`Provider<PassportStore>`, default no-op), `passportCollectionEnabledProvider` (`Provider<bool>`, default from `kReleaseMode`) — all overridable.
- `passportProvider` (`NotifierProvider<PassportNotifier, PassportState>`); `PassportState{collectedVenueIds, saveFailed, count, isComplete}`; `CollectOutcome{result, justCompleted}`; `PassportNotifier.collect(StampInput) → CollectOutcome`, `.reset()`.

- [ ] **Step 1: Write the failing test** — `test/unit/passport_notifier_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/models/stamp_io.dart';
import 'package:aon2026/services/passport_providers.dart';
import 'package:aon2026/services/passport_store.dart';
import 'package:aon2026/data/stamp_stations_data.dart';

/// Records write ORDER + concurrency so we can prove writes are serialized.
class _RecordingStore implements PassportStore {
  final List<Set<String>> writes = [];
  int _inFlight = 0;
  int maxConcurrent = 0;
  @override
  Future<Set<String>> loadSnapshot() async => {};
  @override
  Future<bool> save(Set<String> v) async {
    _inFlight++;
    maxConcurrent = maxConcurrent < _inFlight ? _inFlight : maxConcurrent;
    await Future<void>.delayed(Duration.zero);
    writes.add({...v});
    _inFlight--;
    return true;
  }
}

ProviderContainer _c(PassportStore store,
    {Set<String> snapshot = const {}, bool enabled = true}) {
  return ProviderContainer(overrides: [
    passportSnapshotProvider.overrideWithValue(snapshot),
    passportStoreProvider.overrideWithValue(store),
    passportCollectionEnabledProvider.overrideWithValue(enabled),
  ]);
}

void main() {
  const codeA = 'AON-A-TBC';
  const venueA = 'macquarie-theatre';

  test('collect adds a stamp', () {
    final c = _c(_RecordingStore());
    final out =
        c.read(passportProvider.notifier).collect(StampInput.manual(codeA));
    expect(out.result, isA<StampCollected>());
    expect(c.read(passportProvider).count, 1);
  });

  test('disabled ⇒ StampDisabled and no mutation', () {
    final c = _c(_RecordingStore(), enabled: false);
    final out =
        c.read(passportProvider.notifier).collect(StampInput.manual(codeA));
    expect(out.result, isA<StampDisabled>());
    expect(c.read(passportProvider).count, 0);
  });

  test('justCompleted fires only on the 8→9 transition', () {
    final nine = StampStationsData.all;
    final eight = nine.take(8).map((s) => s.venueId).toSet();
    final c = _c(_RecordingStore(), snapshot: eight);
    final out = c
        .read(passportProvider.notifier)
        .collect(StampInput.manual(nine[8].code));
    expect(out.justCompleted, isTrue);
    final again = c
        .read(passportProvider.notifier)
        .collect(StampInput.manual(nine[8].code));
    expect(again.justCompleted, isFalse);
  });

  test('writes are serialized and last-write-wins (no reorder)', () async {
    final store = _RecordingStore();
    final c = _c(store);
    final n = c.read(passportProvider.notifier);
    n.collect(StampInput.manual('AON-A-TBC'));
    n.collect(StampInput.manual('AON-B-TBC'));
    await pumpEventQueue();
    expect(store.maxConcurrent, 1); // never two writes at once
    expect(store.writes.last, {'macquarie-theatre', 'mason-theatre'});
  });

  test('a failed save flips saveFailed, keeps the stamp in session', () async {
    final failing = _FailingStore();
    final c = _c(failing);
    c.read(passportProvider.notifier).collect(StampInput.manual(codeA));
    expect(c.read(passportProvider).collectedVenueIds, contains(venueA));
    await pumpEventQueue();
    expect(c.read(passportProvider).saveFailed, isTrue);
  });

  test('reset clears progress', () {
    final c = _c(_RecordingStore(), snapshot: {venueA});
    c.read(passportProvider.notifier).reset();
    expect(c.read(passportProvider).count, 0);
  });
}

class _FailingStore implements PassportStore {
  @override
  Future<Set<String>> loadSnapshot() async => {};
  @override
  Future<bool> save(Set<String> v) async => false;
}
```

- [ ] **Step 2: Run test to verify it fails** — Run: `flutter test test/unit/passport_notifier_test.dart` — Expected: FAIL.

- [ ] **Step 3: Implement** — `lib/services/passport_providers.dart`:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/data/stamp_stations_data.dart';
import 'package:aon2026/models/stamp_io.dart';
import 'package:aon2026/services/passport_store.dart';
import 'package:aon2026/services/stamp_service.dart';

class PassportState {
  const PassportState({required this.collectedVenueIds, this.saveFailed = false});
  final Set<String> collectedVenueIds;
  final bool saveFailed;
  int get count => PassportPolicy.completedCount(collectedVenueIds);
  bool get isComplete => PassportPolicy.isComplete(collectedVenueIds);
  PassportState copyWith({Set<String>? collectedVenueIds, bool? saveFailed}) =>
      PassportState(
        collectedVenueIds: collectedVenueIds ?? this.collectedVenueIds,
        saveFailed: saveFailed ?? this.saveFailed,
      );
}

class CollectOutcome {
  const CollectOutcome({required this.result, required this.justCompleted});
  final StampResult result;
  final bool justCompleted;
}

/// Harmless defaults so any Phase 1–5 test that pumps the app WITHOUT overrides
/// still works (empty passport, no-op save). Production main() overrides the
/// snapshot + store with real persistence.
final passportSnapshotProvider =
    Provider<Set<String>>((ref) => const <String>{});

final passportStoreProvider =
    Provider<PassportStore>((ref) => const _NoopPassportStore());

/// The DOMAIN release gate. Default: disabled in release while any code is a
/// placeholder; always enabled in debug. Overridable for tests.
final passportCollectionEnabledProvider = Provider<bool>((ref) =>
    PassportPolicy.isCollectionEnabled(StampStationsData.all,
        isRelease: kReleaseMode));

final passportProvider =
    NotifierProvider<PassportNotifier, PassportState>(PassportNotifier.new);

class PassportNotifier extends Notifier<PassportState> {
  Future<void> _writes = Future<void>.value();

  @override
  PassportState build() =>
      PassportState(collectedVenueIds: {...ref.read(passportSnapshotProvider)});

  CollectOutcome collect(StampInput input) {
    if (!ref.read(passportCollectionEnabledProvider)) {
      return const CollectOutcome(
          result: StampDisabled(), justCompleted: false);
    }
    final wasComplete = state.isComplete;
    final result = StampService.resolve(input, state.collectedVenueIds);
    if (result is StampCollected) {
      state = state
          .copyWith(collectedVenueIds: {...state.collectedVenueIds, result.venueId});
      _scheduleSave();
    }
    return CollectOutcome(
        result: result, justCompleted: !wasComplete && state.isComplete);
  }

  void reset() {
    state = state.copyWith(collectedVenueIds: <String>{});
    _scheduleSave();
  }

  /// Serializes writes so two saves can never complete out of order; each write
  /// persists the CURRENT set, so the last write always reflects final state.
  void _scheduleSave() {
    _writes = _writes.then((_) async {
      final ok = await ref.read(passportStoreProvider).save(
            state.collectedVenueIds,
          );
      if (!ok) state = state.copyWith(saveFailed: true);
    });
    unawaited(_writes);
  }
}

class _NoopPassportStore implements PassportStore {
  const _NoopPassportStore();
  @override
  Future<Set<String>> loadSnapshot() async => <String>{};
  @override
  Future<bool> save(Set<String> venueIds) async => true;
}
```

- [ ] **Step 4: Run test to verify it passes** — Run: `flutter test test/unit/passport_notifier_test.dart` — Expected: PASS.

- [ ] **Step 5: Commit**
```bash
git add lib/services/passport_providers.dart test/unit/passport_notifier_test.dart
git commit -m "feat(passport): notifier — domain gate, serialized writes, safe defaults (Phase 6)"
```

---

## Task 5: main() hydration (injectable, non-fatal)

**Files:** Modify `lib/main.dart`; Create `test/widget/passport_boot_test.dart`.

**Interfaces:** `Future<(Set<String>, PassportStore)> loadPassport({PassportStore? store})` — best-effort, never throws.

- [ ] **Step 1: Write the failing test** — `test/widget/passport_boot_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/main.dart';
import 'package:aon2026/services/passport_store.dart';

class _ThrowingStore implements PassportStore {
  @override
  Future<Set<String>> loadSnapshot() async => throw StateError('disk gone');
  @override
  Future<bool> save(Set<String> v) async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('loadPassport swallows a store failure ⇒ empty snapshot, never throws',
      () async {
    final (snapshot, store) = await loadPassport(store: _ThrowingStore());
    expect(snapshot, isEmpty);
    expect(store, isA<PassportStore>());
  });
}
```

- [ ] **Step 2: Run test to verify it fails** — Run: `flutter test test/widget/passport_boot_test.dart` — Expected: FAIL (`loadPassport` undefined).

- [ ] **Step 3: Modify `lib/main.dart`** — add imports:

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aon2026/services/passport_providers.dart';
import 'package:aon2026/services/passport_store.dart';
```

Add above `main()`:

```dart
/// Best-effort passport hydration. NEVER throws (design §3.1). [store] is
/// injectable for tests only; production passes nothing.
Future<(Set<String>, PassportStore)> loadPassport({PassportStore? store}) async {
  final s = store ?? SharedPrefsPassportStore(SharedPreferencesAsync());
  Set<String> snapshot;
  try {
    snapshot = await s.loadSnapshot();
  } catch (_) {
    snapshot = <String>{};
  }
  return (snapshot, s);
}
```

In `main()`, after `GlassShaderCache.ensureLoaded();`, replace `runApp(const ProviderScope(child: AonApp()));` with:

```dart
  final (passportSnapshot, passportStore) = await loadPassport();
  runApp(
    ProviderScope(
      overrides: [
        passportSnapshotProvider.overrideWithValue(passportSnapshot),
        passportStoreProvider.overrideWithValue(passportStore),
      ],
      child: const AonApp(),
    ),
  );
```

- [ ] **Step 4: Run tests** — Run: `flutter test test/widget/passport_boot_test.dart && flutter analyze` — Expected: PASS; clean.

- [ ] **Step 5: Commit**
```bash
git add lib/main.dart test/widget/passport_boot_test.dart
git commit -m "feat(passport): non-fatal injectable hydration in main() (Phase 6)"
```

---

## Task 6: Route constants (no builders yet)

**Files:** Modify `lib/app/router/app_router.dart`; Create `test/widget/passport_route_test.dart`.

- [ ] **Step 1: Write the failing test**:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/app/router/app_router.dart';

void main() {
  test('passport route paths are defined', () {
    expect(Routes.passport, '/passport');
    expect(Routes.passportScan, '/passport/scan');
    expect(Routes.passportReward, '/passport/reward');
  });
}
```

- [ ] **Step 2: Run test to verify it fails** — Expected: FAIL.

- [ ] **Step 3: Add constants only** (no imports, no `GoRoute`) after `wayfinding` in `abstract final class Routes`:

```dart
  static const String passport = '/passport';
  static const String passportScan = '/passport/scan';
  static const String passportReward = '/passport/reward';
```

Builders are registered in the tasks that create each screen: `passportScan` in Task 8, `passportReward` in Task 9, `passport` in Task 10.

- [ ] **Step 4: Run tests** — Run: `flutter test test/widget/passport_route_test.dart && flutter analyze` — Expected: PASS; clean.

- [ ] **Step 5: Commit**
```bash
git add lib/app/router/app_router.dart test/widget/passport_route_test.dart
git commit -m "feat(passport): route path constants (Phase 6)"
```

---

## Task 7: Adaptive grid (2.0-safe)

**Files:** Create `lib/widgets/passport_grid.dart`, `test/widget/passport_grid_test.dart`.

**Interfaces:** `PassportGrid({required Set<String> collectedVenueIds})`.

- [ ] **Step 1: Write the failing test**:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/widgets/passport_grid.dart';
import 'package:aon2026/data/stamp_stations_data.dart';

Widget _host(Set<String> collected) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PassportGrid(collectedVenueIds: collected),
        ),
      ),
    );

void main() {
  testWidgets('renders all 9 station cells', (tester) async {
    await tester.pumpWidget(_host(<String>{}));
    for (final s in StampStationsData.all) {
      expect(find.bySemanticsLabel(RegExp('^${s.venueId},')), findsOneWidget);
    }
  });

  testWidgets('exactly one cell reads "stamp collected"', (tester) async {
    await tester.pumpWidget(_host({'macquarie-theatre'}));
    expect(find.bySemanticsLabel('macquarie-theatre, stamp collected'),
        findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r', stamp collected$')), findsOneWidget);
  });

  testWidgets('no overflow at 320x568 / 2.0', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(_host(<String>{}));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails** — Expected: FAIL.

- [ ] **Step 3: Implement** — `lib/widgets/passport_grid.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:aon2026/app/theme/aon_colors.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/data/stamp_stations_data.dart';
import 'package:aon2026/data/venues_data.dart';

/// The 9-cell passport. Adaptive columns + content-driven height so long venue
/// names never clip, including at text scale 2.0 (design §6.1).
class PassportGrid extends StatelessWidget {
  const PassportGrid({required this.collectedVenueIds, super.key});
  final Set<String> collectedVenueIds;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = AonSpacing.space3;
        final columns = (constraints.maxWidth / 150).floor().clamp(1, 3);
        final cellWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final s in StampStationsData.all)
              SizedBox(
                width: cellWidth,
                child: _Cell(
                  venueId: s.venueId,
                  collected: collectedVenueIds.contains(s.venueId),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.venueId, required this.collected});
  final String venueId;
  final bool collected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final venue = VenuesData.byId(venueId);
    final name = venue?.shortName ?? venue?.name ?? venueId;
    return Semantics(
      label: '$venueId, ${collected ? 'stamp collected' : 'not yet collected'}',
      child: Container(
        padding: const EdgeInsets.all(AonSpacing.space3),
        decoration: BoxDecoration(
          color: collected
              ? AonColors.amber.withValues(alpha: 0.12)
              : AonColors.night900,
          borderRadius: BorderRadius.circular(AonSpacing.radiusMd),
          border: Border.all(
              color: collected ? AonColors.amber : AonColors.night700),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              collected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: collected ? AonColors.amber : AonColors.contentTertiary,
              size: AonSpacing.iconMd,
            ),
            const SizedBox(height: AonSpacing.space2),
            Text(name, style: theme.textTheme.titleSmall),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes** — Expected: PASS.

- [ ] **Step 5: Commit**
```bash
git add lib/widgets/passport_grid.dart test/widget/passport_grid_test.dart
git commit -m "feat(passport): adaptive 9-cell grid, 2.0-safe (Phase 6)"
```

---

## Task 8: Capture screen — manual entry (camera-free), scan route builder

Camera-free manual capture is a complete, first-class path on its own (design §5 / §8). The Scan peer + camera are added lazily in Task 11; nothing here constructs a camera.

**Files:** Create `lib/screens/passport_scan_screen.dart`, `test/widget/passport_scan_screen_test.dart`; Modify `lib/app/router/app_router.dart`.

**Interfaces:** `PassportScanScreen()` — a `ConsumerStatefulWidget`; keys `passport-manual-field`, `passport-manual-submit`.

- [ ] **Step 1: Write the failing test**:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/screens/passport_scan_screen.dart';
import 'package:aon2026/services/passport_providers.dart';

Widget _host({bool enabled = true}) => ProviderScope(
      overrides: [
        passportSnapshotProvider.overrideWithValue(<String>{}),
        passportCollectionEnabledProvider.overrideWithValue(enabled),
      ],
      child: const MaterialApp(home: PassportScanScreen()),
    );

Future<void> _enter(WidgetTester t, String code) async {
  await t.enterText(find.byKey(const Key('passport-manual-field')), code);
  await t.tap(find.byKey(const Key('passport-manual-submit')));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('valid manual code collects (no camera)', (t) async {
    await t.pumpWidget(_host());
    await _enter(t, 'AON-A-TBC');
    expect(find.textContaining('collected'), findsOneWidget);
  });

  testWidgets('unknown code shows the not-a-code message', (t) async {
    await t.pumpWidget(_host());
    await _enter(t, 'NOPE');
    expect(find.textContaining('not an Astronomy Open Night code'),
        findsOneWidget);
  });

  testWidgets('disabled (release + placeholder) shows the not-live message',
      (t) async {
    await t.pumpWidget(_host(enabled: false));
    await _enter(t, 'AON-A-TBC');
    expect(find.textContaining('not live yet'), findsOneWidget);
  });

  testWidgets('no overflow at 320x568 / 2.0', (t) async {
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1.0;
    t.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(_host());
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails** — Expected: FAIL.

- [ ] **Step 3: Implement** — `lib/screens/passport_scan_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/models/stamp_io.dart';
import 'package:aon2026/services/passport_providers.dart';

/// Capture. Task 8 ships the camera-free manual path; Task 11 adds the "Scan"
/// peer + lazy camera. Manual entry never constructs a scanner.
class PassportScanScreen extends ConsumerStatefulWidget {
  const PassportScanScreen({super.key});
  @override
  ConsumerState<PassportScanScreen> createState() => PassportScanScreenState();
}

class PassportScanScreenState extends ConsumerState<PassportScanScreen> {
  final _controller = TextEditingController();
  String? _message;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Shared by manual entry (here) and the scanner (Task 11).
  void handleInput(StampInput input) {
    final outcome = ref.read(passportProvider.notifier).collect(input);
    setState(() {
      _message = switch (outcome.result) {
        StampCollected() => 'Stamp collected!',
        StampAlreadyHave() => 'You already have this one.',
        StampUnknown() => 'That\'s not an Astronomy Open Night code.',
        StampDisabled() =>
          'The passport isn\'t live yet — see staff at an information point.',
      };
    });
    // Task 11 adds: if (outcome.justCompleted) push Routes.passportReward.
  }

  void _submitManual() => handleInput(StampInput.manual(_controller.text));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Collect a stamp')),
      body: ListView(
        padding: const EdgeInsets.all(AonSpacing.space4),
        children: [
          Text('Enter the code from the venue sign',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: AonSpacing.space3),
          TextField(
            key: const Key('passport-manual-field'),
            controller: _controller,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
                labelText: 'Code', border: OutlineInputBorder()),
          ),
          const SizedBox(height: AonSpacing.space3),
          FilledButton(
            key: const Key('passport-manual-submit'),
            onPressed: _submitManual,
            child: const Text('Add stamp'),
          ),
          if (_message != null) ...[
            const SizedBox(height: AonSpacing.space4),
            Text(_message!, style: theme.textTheme.bodyLarge),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 3b: Register the `passportScan` builder** in `app_router.dart`:

```dart
import 'package:aon2026/screens/passport_scan_screen.dart';
// ...
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: Routes.passportScan,
        builder: (context, state) => const PassportScanScreen(),
      ),
```

- [ ] **Step 4: Run tests** — Run: `flutter test test/widget/passport_scan_screen_test.dart && flutter analyze` — Expected: PASS; clean.

- [ ] **Step 5: Commit**
```bash
git add lib/screens/passport_scan_screen.dart lib/app/router/app_router.dart test/widget/passport_scan_screen_test.dart
git commit -m "feat(passport): camera-free manual capture + scan route (Phase 6)"
```

---

## Task 9: Reward screen (completion-guarded), reward route builder

**Files:** Modify `pubspec.yaml` (`confetti`), `lib/app/router/app_router.dart`, `lib/utils/time_format.dart`; Create `lib/screens/passport_reward_screen.dart`, `test/widget/passport_reward_test.dart`.

**Interfaces:** `PassportRewardScreen()` — `ConsumerStatefulWidget`; shows redemption ONLY when `passportProvider.isComplete`, else a "not complete yet" state.

- [ ] **Step 1: Add dependency** — Run: `flutter pub add confetti` — Expected: `confetti: ^0.8.0`; `pub get` OK.

- [ ] **Step 2: Write the failing test**:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:confetti/confetti.dart';
import 'package:aon2026/screens/passport_reward_screen.dart';
import 'package:aon2026/services/passport_providers.dart';
import 'package:aon2026/data/stamp_stations_data.dart';

Widget _host(Set<String> snapshot, {bool reduceMotion = false}) => ProviderScope(
      overrides: [passportSnapshotProvider.overrideWithValue(snapshot)],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data:
              MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: const PassportRewardScreen(),
      ),
    );

Future<void> _teardown(WidgetTester t) => t.pumpWidget(const SizedBox.shrink());

void main() {
  final all = StampStationsData.stationVenueIds;

  testWidgets('complete ⇒ shows the redeem instruction', (t) async {
    await t.pumpWidget(_host(all));
    await t.pump(const Duration(seconds: 1));
    expect(find.textContaining('Show this to staff'), findsOneWidget);
    await _teardown(t);
  });

  testWidgets('INCOMPLETE ⇒ refuses to show redemption', (t) async {
    await t.pumpWidget(_host(<String>{'macquarie-theatre'})); // 1/9
    await t.pump(const Duration(seconds: 1));
    expect(find.textContaining('Show this to staff'), findsNothing);
    expect(find.textContaining('not complete'), findsOneWidget);
    await _teardown(t);
  });

  testWidgets('reduced motion omits the confetti widget', (t) async {
    await t.pumpWidget(_host(all, reduceMotion: true));
    await t.pump(const Duration(seconds: 1));
    expect(find.byType(ConfettiWidget), findsNothing);
    await _teardown(t);
  });

  testWidgets('complete: no overflow at 320x568 / 2.0', (t) async {
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1.0;
    t.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(_host(all));
    await t.pump(const Duration(seconds: 1));
    expect(t.takeException(), isNull);
    await _teardown(t);
  });
}
```

- [ ] **Step 3: Run test to verify it fails** — Expected: FAIL.

- [ ] **Step 4: Implement** — `lib/screens/passport_reward_screen.dart`:

```dart
import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/app/theme/aon_colors.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/services/passport_providers.dart';
import 'package:aon2026/utils/time_format.dart';

/// Completion screen — GUARDED: redemption shows only when the passport is
/// actually complete (design §7.2). The live clock is a nudge, not security
/// (§7.3); staff + wristband is the real gate. Confetti honours reduced motion.
class PassportRewardScreen extends ConsumerStatefulWidget {
  const PassportRewardScreen({super.key});
  @override
  ConsumerState<PassportRewardScreen> createState() => _RewardState();
}

class _RewardState extends ConsumerState<PassportRewardScreen> {
  late final ConfettiController _confetti =
      ConfettiController(duration: const Duration(seconds: 3));
  Timer? _ticker;
  DateTime _now = DateTime.now();
  bool _started = false;

  @override
  void dispose() {
    _confetti.dispose();
    _ticker?.cancel();
    super.dispose();
  }

  void _startOnce() {
    if (_started) return;
    _started = true;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    if (!MediaQuery.disableAnimationsOf(context)) _confetti.play();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final complete = ref.watch(passportProvider).isComplete;

    if (!complete) {
      return Scaffold(
        appBar: AppBar(title: const Text('Astronomy Passport')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AonSpacing.space5),
            child: Text(
              'Your passport is not complete yet — keep collecting stamps.',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    // Complete: start the celebration once, after this frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _startOnce());
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Passport complete')),
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AonSpacing.space5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.workspace_premium_rounded,
                      size: 72, color: AonColors.amber),
                  const SizedBox(height: AonSpacing.space4),
                  Text('All 9 stamps collected!',
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center),
                  const SizedBox(height: AonSpacing.space3),
                  Text(EventInfo.fullName,
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center),
                  const SizedBox(height: AonSpacing.space3),
                  Text(TimeFormat.clockWithSeconds(_now),
                      style: theme.textTheme.displaySmall),
                  const SizedBox(height: AonSpacing.space4),
                  Text('Show this to staff at the prize booth.',
                      style: theme.textTheme.bodyLarge,
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
          if (!reduceMotion)
            ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
            ),
        ],
      ),
    );
  }
}
```

Add to `lib/utils/time_format.dart` (if absent):

```dart
  /// e.g. "8:41:07 pm" — the passport reward's live clock.
  static String clockWithSeconds(DateTime t) =>
      DateFormat('h:mm:ss a').format(t);
```

- [ ] **Step 4b: Register the `passportReward` builder** in `app_router.dart`:

```dart
import 'package:aon2026/screens/passport_reward_screen.dart';
// ...
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: Routes.passportReward,
        builder: (context, state) => const PassportRewardScreen(),
      ),
```

- [ ] **Step 5: Run tests** — Run: `flutter test test/widget/passport_reward_test.dart && flutter analyze` — Expected: PASS; clean. (The INCOMPLETE test proves the direct-route guard.)

- [ ] **Step 6: Commit**
```bash
git add pubspec.yaml pubspec.lock lib/screens/passport_reward_screen.dart lib/utils/time_format.dart lib/app/router/app_router.dart test/widget/passport_reward_test.dart
git commit -m "feat(passport): completion-guarded reward + confetti + route (Phase 6)"
```

---

## Task 10: Passport screen (progress, grid, links, debug reset), passport route builder

**Files:** Create `lib/screens/passport_screen.dart`, `test/widget/passport_screen_test.dart`; Modify `lib/app/router/app_router.dart`.

**Interfaces:** `PassportScreen()` — `ConsumerWidget`. Links to `Routes.passportScan` and (when complete) `Routes.passportReward`, both of which now exist. Debug-only "Reset passport" with confirmation.

- [ ] **Step 1: Write the failing test**:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/screens/passport_screen.dart';
import 'package:aon2026/services/passport_providers.dart';
import 'package:aon2026/data/stamp_stations_data.dart';

Widget _host(Set<String> snapshot) => ProviderScope(
      overrides: [passportSnapshotProvider.overrideWithValue(snapshot)],
      child: const MaterialApp(home: PassportScreen()),
    );

void main() {
  testWidgets('shows progress out of 9', (t) async {
    await t.pumpWidget(_host({'macquarie-theatre'}));
    expect(find.textContaining('1 / 9'), findsOneWidget);
  });

  testWidgets('complete shows the reward affordance', (t) async {
    await t.pumpWidget(_host(StampStationsData.stationVenueIds));
    expect(find.textContaining('9 / 9'), findsOneWidget);
    expect(find.text('View your reward'), findsOneWidget);
  });

  testWidgets('no overflow at 320x568 / 2.0', (t) async {
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1.0;
    t.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(_host({'macquarie-theatre'}));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails** — Expected: FAIL.

- [ ] **Step 3: Implement** — `lib/screens/passport_screen.dart`:

```dart
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/services/passport_providers.dart';
import 'package:aon2026/services/stamp_service.dart';
import 'package:aon2026/widgets/passport_grid.dart';

class PassportScreen extends ConsumerWidget {
  const PassportScreen({super.key});

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset passport?'),
        content: const Text('This clears all collected stamps on this device.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Reset')),
        ],
      ),
    );
    if (yes ?? false) ref.read(passportProvider.notifier).reset();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(passportProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Astronomy Passport'),
        actions: [
          // Reset is a demo/QA control, compiled out of release builds.
          if (kDebugMode)
            IconButton(
              tooltip: 'Reset passport (debug)',
              icon: const Icon(Icons.restart_alt_rounded),
              onPressed: () => _confirmReset(context, ref),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AonSpacing.space4),
        children: [
          Text('${state.count} / ${PassportPolicy.stationCount} stamps',
              style: theme.textTheme.headlineSmall),
          const SizedBox(height: AonSpacing.space3),
          LinearProgressIndicator(
              value: state.count / PassportPolicy.stationCount),
          if (state.saveFailed) ...[
            const SizedBox(height: AonSpacing.space3),
            Text('Your progress may not be saved on this device.',
                style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: AonSpacing.space5),
          PassportGrid(collectedVenueIds: state.collectedVenueIds),
          const SizedBox(height: AonSpacing.space5),
          if (state.isComplete)
            FilledButton.icon(
              onPressed: () => context.push(Routes.passportReward),
              icon: const Icon(Icons.celebration_rounded),
              label: const Text('View your reward'),
            )
          else
            FilledButton.icon(
              onPressed: () => context.push(Routes.passportScan),
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Scan or enter a code'),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3b: Register the `passport` builder** in `app_router.dart`:

```dart
import 'package:aon2026/screens/passport_screen.dart';
// ...
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: Routes.passport,
        builder: (context, state) => const PassportScreen(),
      ),
```

- [ ] **Step 4: Run tests** — Run: `flutter test test/widget/passport_screen_test.dart && flutter analyze` — Expected: PASS; clean.

- [ ] **Step 5: Commit**
```bash
git add lib/screens/passport_screen.dart lib/app/router/app_router.dart test/widget/passport_screen_test.dart
git commit -m "feat(passport): passport screen — progress, grid, links, debug reset (Phase 6)"
```

---

## Task 11: Lazy scanner peer (torch, permission, retry) + QR integration test

Adds the "Scan" peer to the capture screen. The camera is created ONLY after the user taps Scan (design §5), handles one decode then offers "Scan another" (§7.1), exposes a torch, and degrades to manual on permission-denied/no-camera (§5). A fake-scanner seam makes the scan→collect path testable without hardware.

**Files:** Modify `pubspec.yaml` (`mobile_scanner`), `lib/screens/passport_scan_screen.dart`; Create `lib/services/scan_gate.dart`, `lib/widgets/passport_scanner_view.dart`, `test/unit/scan_gate_test.dart`, `test/widget/passport_scan_integration_test.dart`.

**Interfaces:**
- `ScanGate` — `bool accept()` true once then false until `reset()`.
- `PassportScannerView({required void Function(String) onDecoded, VoidCallback? onError})` — non-web camera (lazy start via controller), torch button, `errorBuilder` → `onError`; web ⇒ a manual-only notice, never constructs the scanner.
- `PassportScanScreen` gains an optional `@visibleForTesting Widget Function(void Function(String) onDecoded)? scannerBuilder` so tests inject a fake scanner that emits a decoded string.

- [ ] **Step 1: Add dependency** — Run: `flutter pub add mobile_scanner` — Expected: a 7.x version. Confirm it builds for the current iOS min: `flutter build ios --no-codesign`. If it demands raising `IPHONEOS_DEPLOYMENT_TARGET`, do so intentionally and note it in the commit.

- [ ] **Step 2a: Write the ScanGate unit test** — `test/unit/scan_gate_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/services/scan_gate.dart';

void main() {
  test('accepts first decode only, resumes after reset', () {
    final g = ScanGate();
    expect(g.accept(), isTrue);
    expect(g.accept(), isFalse);
    g.reset();
    expect(g.accept(), isTrue);
  });
}
```

- [ ] **Step 2b: Write the QR integration test** (scan → collect, no hardware) — `test/widget/passport_scan_integration_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/screens/passport_scan_screen.dart';
import 'package:aon2026/services/passport_providers.dart';

void main() {
  testWidgets('a decoded namespaced QR collects a stamp via the shared path',
      (t) async {
    await t.pumpWidget(ProviderScope(
      overrides: [passportSnapshotProvider.overrideWithValue(<String>{})],
      child: MaterialApp(
        home: PassportScanScreen(
          // Fake scanner: a button that emits a decoded QR string on tap.
          scannerBuilder: (onDecoded) => ElevatedButton(
            key: const Key('fake-decode'),
            onPressed: () => onDecoded('AON2026:AON-A-TBC'),
            child: const Text('emit'),
          ),
        ),
      ),
    ));
    // Reveal the scanner peer, then emit a decode.
    await t.tap(find.text('Scan QR code'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('fake-decode')));
    await t.pumpAndSettle();
    expect(find.textContaining('collected'), findsOneWidget);
    expect(find.text('Scan another'), findsOneWidget); // resume affordance
  });
}
```

- [ ] **Step 3: Run tests to verify they fail** — Expected: FAIL (`scan_gate` undefined; `scannerBuilder`/`Scan QR code` absent).

- [ ] **Step 4a: `lib/services/scan_gate.dart`**:

```dart
/// One-capture debounce (design §7.1): [accept] true once, then false until
/// [reset]. Pure — unit-testable without a camera.
class ScanGate {
  bool _open = true;
  bool accept() {
    if (!_open) return false;
    _open = false;
    return true;
  }
  void reset() => _open = true;
}
```

- [ ] **Step 4b: `lib/widgets/passport_scanner_view.dart`** (torch + permission errorBuilder; lazy — only built when the screen enters scan mode):

```dart
import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/services/scan_gate.dart';

/// Camera QR adapter. Constructed only when the user chooses Scan, so the
/// permission prompt is lazy (design §5). Emits one decode per capture (§7.1),
/// offers a torch, and routes camera/permission errors to [onError]. On web it
/// never constructs the scanner (design §5.1) — manual entry is the web path.
class PassportScannerView extends StatefulWidget {
  const PassportScannerView({required this.onDecoded, this.onError, super.key});
  final void Function(String decoded) onDecoded;
  final VoidCallback? onError;

  @override
  State<PassportScannerView> createState() => _PassportScannerViewState();
}

class _PassportScannerViewState extends State<PassportScannerView> {
  MobileScannerController? _controller;
  final ScanGate _gate = ScanGate();

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _controller = MobileScannerController();
  }

  @override
  void dispose() {
    final c = _controller;
    if (c != null) unawaited(c.dispose());
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_gate.accept()) return; // debounce: one per capture
    final raw =
        capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
    if (raw == null) {
      _gate.reset();
      return;
    }
    final c = _controller;
    if (c != null) unawaited(c.stop());
    widget.onDecoded(raw);
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (kIsWeb || c == null) {
      return Padding(
        padding: const EdgeInsets.all(AonSpacing.space4),
        child: Text('Scanning isn\'t available on the web — enter the code below.',
            style: Theme.of(context).textTheme.bodyMedium),
      );
    }
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: MobileScanner(
            controller: c,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              // Permission denied / no camera: hand back to manual entry.
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => widget.onError?.call());
              return Padding(
                padding: const EdgeInsets.all(AonSpacing.space4),
                child: Text(
                  'Camera unavailable — enter the code from the sign instead.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              );
            },
          ),
        ),
        TextButton.icon(
          onPressed: () => unawaited(c.toggleTorch()),
          icon: const Icon(Icons.flashlight_on_rounded),
          label: const Text('Torch'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4c: Rework `passport_scan_screen.dart`** into peer choice + scan mode with resume. Replace the class with:

```dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/models/stamp_io.dart';
import 'package:aon2026/services/passport_providers.dart';
import 'package:aon2026/widgets/passport_scanner_view.dart';

enum _Mode { choosing, manual, scanning }

class PassportScanScreen extends ConsumerStatefulWidget {
  const PassportScanScreen({this.scannerBuilder, super.key});

  /// Test seam: inject a fake scanner that emits a decoded string.
  final Widget Function(void Function(String) onDecoded)? scannerBuilder;

  @override
  ConsumerState<PassportScanScreen> createState() => PassportScanScreenState();
}

class PassportScanScreenState extends ConsumerState<PassportScanScreen> {
  final _controller = TextEditingController();
  _Mode _mode = _Mode.choosing;
  String? _message;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void handleInput(StampInput input) {
    final outcome = ref.read(passportProvider.notifier).collect(input);
    setState(() {
      _message = switch (outcome.result) {
        StampCollected() => 'Stamp collected!',
        StampAlreadyHave() => 'You already have this one.',
        StampUnknown() => 'That\'s not an Astronomy Open Night code.',
        StampDisabled() =>
          'The passport isn\'t live yet — see staff at an information point.',
      };
    });
    if (outcome.justCompleted) context.push(Routes.passportReward);
  }

  void _submitManual() => handleInput(StampInput.manual(_controller.text));

  Widget _scanner() {
    final Widget Function(void Function(String)) builder =
        widget.scannerBuilder ??
            (cb) => PassportScannerView(
                  onDecoded: cb,
                  onError: () => setState(() => _mode = _Mode.manual),
                );
    return builder((raw) => handleInput(StampInput.scan(raw)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Collect a stamp')),
      body: ListView(
        padding: const EdgeInsets.all(AonSpacing.space4),
        children: [
          // Two equal peers.
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: kIsWeb
                      ? null
                      : () => setState(() {
                            _message = null;
                            _mode = _Mode.scanning;
                          }),
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Scan QR code'),
                ),
              ),
              const SizedBox(width: AonSpacing.space3),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _mode = _Mode.manual),
                  icon: const Icon(Icons.keyboard_rounded),
                  label: const Text('Enter a code'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AonSpacing.space4),

          if (_mode == _Mode.scanning) _scanner(),

          if (_mode == _Mode.manual) ...[
            Text('Enter the code from the venue sign',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: AonSpacing.space3),
            TextField(
              key: const Key('passport-manual-field'),
              controller: _controller,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                  labelText: 'Code', border: OutlineInputBorder()),
            ),
            const SizedBox(height: AonSpacing.space3),
            FilledButton(
              key: const Key('passport-manual-submit'),
              onPressed: _submitManual,
              child: const Text('Add stamp'),
            ),
          ],

          if (_message != null) ...[
            const SizedBox(height: AonSpacing.space4),
            Text(_message!, style: theme.textTheme.bodyLarge),
            const SizedBox(height: AonSpacing.space3),
            // Resume affordance after any scan result (design §7.1).
            OutlinedButton(
              onPressed: () => setState(() {
                _message = null;
                _mode = _Mode.scanning;
              }),
              child: const Text('Scan another'),
            ),
          ],
        ],
      ),
    );
  }
}
```

Note: Task 8's manual-entry test taps "Enter a code" first. **Update `test/widget/passport_scan_screen_test.dart`'s `_enter` helper** to tap `find.text('Enter a code')` before entering text (the field now lives behind the peer choice):

```dart
Future<void> _enter(WidgetTester t, String code) async {
  await t.tap(find.text('Enter a code'));
  await t.pumpAndSettle();
  await t.enterText(find.byKey(const Key('passport-manual-field')), code);
  await t.tap(find.byKey(const Key('passport-manual-submit')));
  await t.pumpAndSettle();
}
```

- [ ] **Step 5: Run tests** — Run: `flutter test && flutter analyze` — Expected: PASS (unit ScanGate, integration scan→collect+resume, updated manual tests); clean.

- [ ] **Step 6: Commit**
```bash
git add pubspec.yaml pubspec.lock lib/services/scan_gate.dart lib/widgets/passport_scanner_view.dart lib/screens/passport_scan_screen.dart test/unit/scan_gate_test.dart test/widget/passport_scan_integration_test.dart test/widget/passport_scan_screen_test.dart
git commit -m "feat(passport): lazy scan peer — torch, permission fallback, resume, QR integration test (Phase 6)"
```

---

## Task 12: Entry points — Home card + Info menu (with real navigation tests)

**Files:** Create `lib/widgets/passport_home_card.dart`, `test/widget/passport_entry_points_test.dart`; Modify `lib/screens/home_screen.dart`, `lib/screens/info_screen.dart`.

**Interfaces:** `PassportHomeCard()` — `ConsumerWidget`; shows "N / 9 stamps"; pushes `Routes.passport`.

- [ ] **Step 1: Write the failing test** (proves the cards exist, show progress, AND navigate; and that Home/Info actually contain them via the real router):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/services/passport_providers.dart';
import 'package:aon2026/widgets/passport_home_card.dart';

Widget _app() => ProviderScope(
      overrides: [
        passportSnapshotProvider.overrideWithValue({'macquarie-theatre'}),
      ],
      child: MaterialApp.router(routerConfig: buildRouter()),
    );

void main() {
  testWidgets('Home shows the passport card with progress and it navigates',
      (t) async {
    await t.pumpWidget(_app());
    await t.pumpAndSettle();
    expect(find.byType(PassportHomeCard), findsOneWidget);
    expect(find.textContaining('1 / 9'), findsOneWidget);
    await t.tap(find.byType(PassportHomeCard));
    await t.pumpAndSettle();
    expect(find.text('Astronomy Passport'), findsWidgets); // on the screen
  });

  testWidgets('Info menu has a passport entry that navigates', (t) async {
    await t.pumpWidget(_app());
    await t.pumpAndSettle();
    // Navigate to the Info tab.
    await t.tap(find.byIcon(Icons.info_outline_rounded));
    await t.pumpAndSettle();
    final infoEntry = find.widgetWithText(FilledButton, 'Astronomy Passport');
    expect(infoEntry, findsOneWidget);
    await t.tap(infoEntry);
    await t.pumpAndSettle();
    expect(find.textContaining('/ 9'), findsOneWidget); // reached the screen
  });
}
```

- [ ] **Step 2: Run test to verify it fails** — Expected: FAIL.

- [ ] **Step 3: Implement** — `lib/widgets/passport_home_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/theme/aon_colors.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/services/passport_providers.dart';
import 'package:aon2026/services/stamp_service.dart';
import 'package:aon2026/widgets/aon_tactile_button.dart';

class PassportHomeCard extends ConsumerWidget {
  const PassportHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(passportProvider);
    return AonTactileButton(
      onTap: () => context.push(Routes.passport),
      borderRadius: AonSpacing.radiusMd,
      child: Container(
        padding: const EdgeInsets.all(AonSpacing.space4),
        decoration: BoxDecoration(
          color: AonColors.night900,
          borderRadius: BorderRadius.circular(AonSpacing.radiusMd),
          border: Border.all(color: AonColors.amber.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.workspace_premium_rounded,
                color: AonColors.amber, size: AonSpacing.iconMd),
            const SizedBox(width: AonSpacing.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Astronomy Passport', style: theme.textTheme.titleSmall),
                  Text('${state.count} / ${PassportPolicy.stationCount} stamps',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AonColors.contentSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AonColors.amber),
          ],
        ),
      ),
    );
  }
}
```

`home_screen.dart` — add `import 'package:aon2026/widgets/passport_home_card.dart';` and insert after the "Get started" `LayoutBuilder` (before `SizedBox(height: AonSpacing.space6)`):

```dart
                const SizedBox(height: AonSpacing.space5),
                const PassportHomeCard(),
```

`info_screen.dart` — after "The essentials" container, before the First aid `SectionHeader` (the file already imports `go_router` and `app_router.dart`):

```dart
          const SizedBox(height: AonSpacing.space4),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.push(Routes.passport),
              icon: const Icon(Icons.workspace_premium_rounded),
              label: const Text('Astronomy Passport'),
            ),
          ),
```

- [ ] **Step 4: Run tests** — Run: `flutter test && flutter analyze` — Expected: PASS; clean. **This is the point the throwing-provider landmine would have detonated** — with the harmless defaults from Task 4, existing whole-app tests keep passing. If any existing test DID assume no passport, fix it by adding the overrides, never by weakening.

- [ ] **Step 5: Commit**
```bash
git add lib/widgets/passport_home_card.dart lib/screens/home_screen.dart lib/screens/info_screen.dart test/widget/passport_entry_points_test.dart
git commit -m "feat(passport): Home card + Info entry with navigation tests (Phase 6)"
```

---

## Task 13: Platform manifests, web gate, iOS runtime camera pass, docs, full verification

**Files:** Modify `ios/Runner/Info.plist`, `android/app/src/main/AndroidManifest.xml`, `docs/data-sources.md`, `docs/superpowers/specs/2026-08-10-aon-astronomy-passport-phase6-design.md`.

- [ ] **Step 1: iOS usage string** — in `ios/Runner/Info.plist` `<dict>`:
```xml
	<key>NSCameraUsageDescription</key>
	<string>Used only to scan the QR code on a venue sign for your Astronomy Passport. Camera images are processed on your device and never stored or sent anywhere.</string>
```

- [ ] **Step 2: Android permission (optional hardware)** — above `<application>`:
```xml
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-feature android:name="android.hardware.camera" android:required="false" />
    <uses-feature android:name="android.hardware.camera.autofocus" android:required="false" />
```

- [ ] **Step 3: Static analysis + full test suite**

Run: `flutter analyze && flutter test`
Expected: clean; suite = baseline (Task 0) + the new passport tests, **all** green, no Phase 1–5 regressions.

- [ ] **Step 4: Web build gate** — Run: `flutter build web` — Expected: SUCCESS (scanner never instantiated on web). Optionally `flutter run -d chrome` and confirm the capture screen's "Scan QR code" is disabled and manual entry works.

- [ ] **Step 5: Platform builds** — Run: `flutter build ios --no-codesign` and `flutter build apk --debug` — Expected: both succeed. If `mobile_scanner` forced an `IPHONEOS_DEPLOYMENT_TARGET` bump, confirm it is committed and noted.

- [ ] **Step 6: iOS RUNTIME camera pass (mandatory — the one thing tests can't prove)**

On a booted iOS simulator/device, walk the capture flow and record PASS/FAIL for each:
```text
[ ] open Passport → capture screen: NO permission prompt yet (lazy)
[ ] tap "Scan QR code" → permission requested
[ ] allow → camera preview appears
[ ] torch toggles
[ ] scan a real test QR "AON2026:AON-A-TBC" → one stamp, no double-fire
[ ] scan the same again → "already have", no duplicate
[ ] scan an invalid QR → message + "Scan another" resumes the camera
[ ] deny permission (reset + retry) → manual entry still usable
[ ] collect the 9th → reward opens once
[ ] open /passport with <9 (debug reset) → reward route refuses redemption
[ ] app restart → progress persists (proves SharedPrefs round-trip on device)
```
Android runtime may be recorded NOT AVAILABLE if no device is on hand; **iOS runtime is required** for completion.

- [ ] **Step 7: Docs** — append to `docs/data-sources.md` a "Passport station codes" entry: all 9 `placeholder` pending organiser confirmation; release builds keep collection disabled until confirmed (spec §10/§14). Record the resolved dep versions, the iOS deployment-target outcome, the web-build result, and the iOS runtime checklist result in the spec's §16.

- [ ] **Step 8: Commit**
```bash
git add ios/Runner/Info.plist android/app/src/main/AndroidManifest.xml docs/data-sources.md docs/superpowers/specs/2026-08-10-aon-astronomy-passport-phase6-design.md
git commit -m "feat(passport): camera manifests, web gate, iOS runtime pass, docs + verification (Phase 6)"
```

---

## Self-Review

**1. Spec + review coverage**

| Item | Task |
|---|---|
| Baseline/branch preflight (review #17) | 0 |
| 9 stations = event venues exactly (review #14) | 1 |
| Typed input + `StampDisabled` (spec §3.2) | 2 |
| Persistence + REAL adapter test (review #9) | 3 |
| Domain release gate (review #6) | 2 (policy) + 4 (gate provider + `collect`) |
| Serialized non-fatal writes (review #4) | 4 |
| Harmless provider defaults (review #10) | 4 |
| Non-fatal hydration | 5 |
| Route constants (cycle-free) | 6 |
| Adaptive grid @2.0 | 7 |
| Camera-free manual capture | 8 |
| Reward completion guard (review #5) | 9 |
| Passport screen + debug reset UI (review #15) | 10 |
| Lazy camera (review #1) | 11 |
| Scanner resume/retry (review #2) | 11 |
| Torch + permission fallback (review #3) | 11 |
| QR scan→collect integration test (review #13) | 11 |
| No-op button removed (review #11) | 8/10 (button only appears in 10, wired to the real route) |
| Entry-point navigation tests (review #12) | 12 |
| 2.0 on EVERY new surface (review #7) | 7,8,9,10,11(chrome),12 |
| iOS runtime camera gate (review #8) | 13 |
| Web "never instantiated" wording (review #16) | 11 §5.1 comment + Global Constraints |

**2. 2.0 coverage** — grid (7), manual entry (8), reward (9), passport (10), scan chrome (11 renders inside the scan screen tested at 10/8 sizes; the scanner camera preview itself is native and out of scope — its Flutter chrome/messages are covered), home card (12 via the app test). No new user-facing Flutter surface lacks a 2.0 assertion.

**3. Type consistency** — `StampInput`/`StampResult`(+`StampDisabled`), `StampService.resolve`, `PassportPolicy.*`, `PassportStore.*`, `passport{Snapshot,Store,CollectionEnabled}Provider`, `passportProvider`, `PassportState{count,isComplete,saveFailed}`, `CollectOutcome{result,justCompleted}`, `PassportScanScreenState.handleInput`, `ScanGate.{accept,reset}`, `Routes.{passport,passportScan,passportReward}` — all names consistent between definition and use.

---

## Notes for the executor

- **Dead-intermediate-free ordering:** every commit compiles and every rendered control works. Reward (9) and capture (8) exist before the passport screen (10) links to them; the camera arrives last (11).
- **Test harness discipline** (Global Constraints): `tester.view` + `platformDispatcher.textScaleFactorTestValue` for scale; dispose timer-bearing screens with `pumpWidget(SizedBox.shrink())`; `pump(Duration)` not `pumpAndSettle` for the reward.
- **`unawaited_futures`**: wrap `controller.stop/dispose/toggleTorch` and persistence writes.
- **Never loosen a Phase 1–5 test.** If the full-suite run in Task 12/13 surfaces a break, the integration is wrong.
- **The camera is the one thing tests can't fully prove** — Task 13's iOS runtime checklist is a required completion gate, not optional.
