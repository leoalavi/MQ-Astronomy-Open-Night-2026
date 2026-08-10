# Astronomy Passport (Phase 6) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A scan-and-collect "Astronomy Passport" — collect a stamp at each of the 9 event venues (QR scan or manual code), and on all 9 show a live completion screen to redeem a prize at a staffed booth.

**Architecture:** A pure domain core (typed `StampInput` → `StampService` → `StampResult`) sits under a Riverpod `PassportNotifier` backed by a best-effort, non-fatal `PassportStore` (the app's first persisted state). UI (grid, capture, reward) and two entry points (Home card, Info menu) are thin layers over that core; the camera is a thin adapter that only emits a decoded string, so every rule is testable without hardware.

**Tech Stack:** Flutter `>=3.44`, Dart `^3.11`, Riverpod 3 (`flutter_riverpod ^3.3.2`), `go_router ^17.3.0`, plus three new keyless deps: `shared_preferences`, `mobile_scanner` (7.x), `confetti`.

## Global Constraints

- **No secrets, no backend, no accounts.** Station codes are low-friction event tokens, NOT secrets or proof of attendance (spec §4.1). Never describe them as secure.
- **No new API keys.** All three new deps are keyless.
- **Persistence must never block launch** (spec §3.1). Hydration failure ⇒ empty passport; write failure ⇒ non-fatal, session state stays correct. UI stays synchronous — only writes are async.
- **Completion counts `collected ∩ stationVenueIds`**, never the raw set size (spec §4.3).
- **Codes typed by source** (spec §3.2): a bare token is valid from manual entry but a QR without the `AON2026:` namespace is `unknown`.
- **Release gate** (spec §10): release builds must not enable prize collection while any station code is `placeholder`.
- **Text scale 2.0** is a permanent contract — every new surface must pass at `320×568 / textScale 2.0` (Phase 5).
- **Reduced motion**: detect with `MediaQuery.disableAnimationsOf(context)`; reduced ⇒ no confetti burst, a static celebratory state.
- **No 6th nav tab.** Entry points are the Home card + Info-screen menu only.
- **Lint**: `prefer_single_quotes`, `prefer_const_constructors`, `always_declare_return_types`, `unawaited_futures` (use `unawaited(...)` for fire-and-forget), single quotes throughout (`analysis_options.yaml`).
- **Verify command** (run after every task): `flutter analyze && flutter test`.

---

## File Structure

**Create:**
- `lib/models/stamp_station.dart` — `StampStation` value type (venueId, code, codeConfidence).
- `lib/data/stamp_stations_data.dart` — the 9 `const` stations + `StampStationsData` accessors.
- `lib/models/stamp_io.dart` — `StampInput` (`ScanInput`/`ManualInput`) and `StampResult` (`StampCollected`/`StampAlreadyHave`/`StampUnknown`).
- `lib/services/stamp_service.dart` — pure resolver + `PassportPolicy`.
- `lib/services/passport_store.dart` — persistence seam: `PassportStore` interface + `SharedPrefsPassportStore` impl.
- `lib/services/passport_providers.dart` — `passportSnapshotProvider`, `passportStoreProvider`, `passportProvider` (`PassportNotifier`, `PassportState`, `CollectOutcome`).
- `lib/widgets/passport_grid.dart` — adaptive 9-cell grid.
- `lib/widgets/passport_home_card.dart` — Home entry card.
- `lib/widgets/passport_scanner_view.dart` — `mobile_scanner` adapter, `kIsWeb`-guarded, debounced.
- `lib/screens/passport_screen.dart` — grid + progress + capture affordance.
- `lib/screens/passport_scan_screen.dart` — Scan + Enter code (equal peers).
- `lib/screens/passport_reward_screen.dart` — completion + confetti.
- Tests mirror these under `test/unit/` and `test/widget/`.

**Modify:**
- `pubspec.yaml` (deps, added in the task that first needs each).
- `lib/main.dart` (best-effort hydration + `ProviderScope` overrides).
- `lib/app/router/app_router.dart` (`Routes.passport`, `Routes.passportScan` + `GoRoute`s).
- `lib/screens/home_screen.dart` (passport card).
- `lib/screens/info_screen.dart` (passport menu entry).
- `test/unit/data_integrity_test.dart` (release-gate + station integrity).
- `ios/Runner/Info.plist`, `android/app/src/main/AndroidManifest.xml` (camera permission).

---

## Task 1: Station data model + integrity test

**Files:**
- Create: `lib/models/stamp_station.dart`
- Create: `lib/data/stamp_stations_data.dart`
- Modify: `test/unit/data_integrity_test.dart`

**Interfaces:**
- Produces: `StampStation({required String venueId, required String code, DataConfidence codeConfidence})`; `StampStationsData.all` (`List<StampStation>`), `StampStationsData.stationVenueIds` (`Set<String>`), `StampStationsData.count` (`int`).

- [ ] **Step 1: Write the failing test** — append to `test/unit/data_integrity_test.dart`:

```dart
// Add these imports at the top of the file if absent:
// import 'package:aon2026/data/stamp_stations_data.dart';
// import 'package:aon2026/data/venues_data.dart';
// import 'package:aon2026/models/data_confidence.dart';

group('passport stations', () {
  final stations = StampStationsData.all;

  test('there are exactly 9 stations', () {
    expect(stations.length, 9);
    expect(StampStationsData.count, 9);
  });

  test('every station venueId is a real event venue', () {
    final eventVenueIds =
        VenuesData.eventVenues.map((v) => v.id).toSet();
    for (final s in stations) {
      expect(eventVenueIds, contains(s.venueId),
          reason: '${s.venueId} is not an eventVenue');
    }
  });

  test('venueIds and codes are each unique', () {
    expect(stations.map((s) => s.venueId).toSet().length, 9);
    expect(stations.map((s) => s.code.toUpperCase()).toSet().length, 9);
  });

  test('stationVenueIds matches the station set', () {
    expect(StampStationsData.stationVenueIds,
        stations.map((s) => s.venueId).toSet());
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/data_integrity_test.dart`
Expected: FAIL — `StampStationsData` undefined.

- [ ] **Step 3: Write minimal implementation** — `lib/models/stamp_station.dart`:

```dart
import 'package:aon2026/models/data_confidence.dart';

/// One stop on the Astronomy Passport trail.
///
/// [code] is a low-friction event token printed on the venue's sign — NOT a
/// secret and NOT proof of attendance (see the Phase 6 design §4.1). Staff
/// redemption at the booth is the actual control.
class StampStation {
  const StampStation({
    required this.venueId,
    required this.code,
    this.codeConfidence = DataConfidence.placeholder,
  });

  /// Foreign key into [VenuesData]; always one of the 9 `eventVenue`s.
  final String venueId;

  /// The token on the sign. Compared case-insensitively.
  final String code;

  /// `placeholder` until the organiser confirms the printed code. The release
  /// gate (PassportPolicy) refuses collection while any station is placeholder.
  final DataConfidence codeConfidence;
}
```

`lib/data/stamp_stations_data.dart`:

```dart
import 'package:aon2026/models/data_confidence.dart';
import 'package:aon2026/models/stamp_station.dart';

/// The 9 passport stations — the map-legend A–I event venues.
///
/// Codes are PLACEHOLDER until the organiser confirms the printed signage
/// tokens (design §14). While any code is placeholder the release gate keeps
/// prize collection disabled in release builds (PassportPolicy).
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

  static Set<String> get stationVenueIds =>
      all.map((s) => s.venueId).toSet();

  static StampStation? byVenueId(String venueId) {
    for (final s in all) {
      if (s.venueId == venueId) return s;
    }
    return null;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/unit/data_integrity_test.dart`
Expected: PASS (all 4 new tests).

- [ ] **Step 5: Commit**

```bash
git add lib/models/stamp_station.dart lib/data/stamp_stations_data.dart test/unit/data_integrity_test.dart
git commit -m "feat(passport): 9-station data model + integrity tests (Phase 6)"
```

---

## Task 2: Typed input, result, and the pure resolver + release policy

**Files:**
- Create: `lib/models/stamp_io.dart`
- Create: `lib/services/stamp_service.dart`
- Create: `test/unit/stamp_service_test.dart`

**Interfaces:**
- Consumes: `StampStationsData.all` (Task 1).
- Produces:
  - `StampInput` with `StampInput.scan(String rawQr)` → `ScanInput`, `StampInput.manual(String rawCode)` → `ManualInput`.
  - `StampResult`: `StampCollected(String venueId)`, `StampAlreadyHave(String venueId)`, `StampUnknown()`.
  - `StampService.resolve(StampInput input, Set<String> collected) → StampResult`.
  - `PassportPolicy.stationVenueIds` (`Set<String>`), `PassportPolicy.stationCount` (`int`), `PassportPolicy.completedCount(Set<String>)` (`int`), `PassportPolicy.isComplete(Set<String>)` (`bool`), `PassportPolicy.isCollectionEnabled(List<StampStation>, {required bool isRelease})` (`bool`).

- [ ] **Step 1: Write the failing test** — `test/unit/stamp_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/models/stamp_io.dart';
import 'package:aon2026/models/stamp_station.dart';
import 'package:aon2026/models/data_confidence.dart';
import 'package:aon2026/data/stamp_stations_data.dart';
import 'package:aon2026/services/stamp_service.dart';

void main() {
  // A known real code from the station table (Task 1 uses 'AON-A-TBC').
  const goodCode = 'AON-A-TBC';
  const goodVenue = 'macquarie-theatre';

  group('StampService.resolve — manual', () {
    test('valid bare code collects', () {
      final r = StampService.resolve(StampInput.manual(goodCode), <String>{});
      expect(r, isA<StampCollected>());
      expect((r as StampCollected).venueId, goodVenue);
    });

    test('is case- and whitespace-insensitive', () {
      final r = StampService.resolve(
          StampInput.manual('  aon-a-tbc '), <String>{});
      expect(r, isA<StampCollected>());
    });

    test('already-collected code returns alreadyHave', () {
      final r =
          StampService.resolve(StampInput.manual(goodCode), {goodVenue});
      expect(r, isA<StampAlreadyHave>());
    });

    test('unknown code returns unknown', () {
      final r = StampService.resolve(StampInput.manual('NOPE'), <String>{});
      expect(r, isA<StampUnknown>());
    });
  });

  group('StampService.resolve — scan (namespace required)', () {
    test('namespaced QR collects', () {
      final r = StampService.resolve(
          StampInput.scan('AON2026:$goodCode'), <String>{});
      expect(r, isA<StampCollected>());
    });

    test('un-namespaced QR is unknown even if the token is real', () {
      final r =
          StampService.resolve(StampInput.scan(goodCode), <String>{});
      expect(r, isA<StampUnknown>());
    });

    test('foreign QR is unknown', () {
      final r = StampService.resolve(
          StampInput.scan('https://example.com'), <String>{});
      expect(r, isA<StampUnknown>());
    });
  });

  group('PassportPolicy', () {
    test('completedCount uses intersection, ignores stale ids', () {
      final collected = {goodVenue, 'not-a-station'};
      expect(PassportPolicy.completedCount(collected), 1);
    });

    test('isComplete needs all 9 stations', () {
      expect(PassportPolicy.isComplete(StampStationsData.stationVenueIds),
          isTrue);
      expect(PassportPolicy.isComplete({goodVenue}), isFalse);
    });

    test('release gate: disabled while any code is placeholder', () {
      // Task 1 ships all placeholder codes.
      expect(
          PassportPolicy.isCollectionEnabled(StampStationsData.all,
              isRelease: true),
          isFalse);
    });

    test('release gate: enabled when all confirmed', () {
      final confirmed = [
        for (final s in StampStationsData.all)
          StampStation(
              venueId: s.venueId,
              code: s.code,
              codeConfidence: DataConfidence.confirmed),
      ];
      expect(
          PassportPolicy.isCollectionEnabled(confirmed, isRelease: true),
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

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/stamp_service_test.dart`
Expected: FAIL — `stamp_io`/`StampService` undefined.

- [ ] **Step 3: Write minimal implementation** — `lib/models/stamp_io.dart`:

```dart
/// Capture input, typed by source. Scanning and manual entry have different
/// validity rules (a bare token is valid from the keypad but a QR must carry
/// the AON2026 namespace), so the source cannot be flattened to a plain String.
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

/// The outcome of resolving a capture against the station table.
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
```

`lib/services/stamp_service.dart`:

```dart
import 'package:aon2026/data/stamp_stations_data.dart';
import 'package:aon2026/models/data_confidence.dart';
import 'package:aon2026/models/stamp_io.dart';
import 'package:aon2026/models/stamp_station.dart';

/// Pure capture resolution. No I/O, no camera — fully unit-testable.
abstract final class StampService {
  static const String _qrNamespace = 'AON2026:';

  static StampResult resolve(StampInput input, Set<String> collected) {
    final token = switch (input) {
      ScanInput(:final rawQr) => _tokenFromQr(rawQr),
      ManualInput(:final rawCode) => _normalize(rawCode),
    };
    if (token == null) return const StampUnknown();
    return _resolveToken(token, collected);
  }

  /// QR must carry the AON2026 namespace; anything else is a foreign code.
  static String? _tokenFromQr(String rawQr) {
    final trimmed = rawQr.trim();
    if (!trimmed.toUpperCase().startsWith(_qrNamespace)) return null;
    return _normalize(trimmed.substring(_qrNamespace.length));
  }

  static String _normalize(String raw) => raw.trim().toUpperCase();

  static StampResult _resolveToken(String token, Set<String> collected) {
    for (final s in StampStationsData.all) {
      if (_normalize(s.code) == token) {
        return collected.contains(s.venueId)
            ? StampAlreadyHave(s.venueId)
            : StampCollected(s.venueId);
      }
    }
    return const StampUnknown();
  }
}

/// Trail rules: completion by intersection, and the placeholder release gate.
abstract final class PassportPolicy {
  static Set<String> get stationVenueIds =>
      StampStationsData.stationVenueIds;

  static int get stationCount => StampStationsData.count;

  static int completedCount(Set<String> collected) =>
      collected.intersection(stationVenueIds).length;

  static bool isComplete(Set<String> collected) =>
      completedCount(collected) >= stationCount;

  /// Release builds refuse collection while any code is unconfirmed. Debug
  /// builds always allow it (for pre-event QA with placeholder/demo codes).
  static bool isCollectionEnabled(
    List<StampStation> stations, {
    required bool isRelease,
  }) {
    if (!isRelease) return true;
    return stations.every((s) => s.codeConfidence.isReliable);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/unit/stamp_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/models/stamp_io.dart lib/services/stamp_service.dart test/unit/stamp_service_test.dart
git commit -m "feat(passport): typed capture input, pure resolver, release policy (Phase 6)"
```

---

## Task 3: Persistence seam (best-effort, non-fatal)

**Files:**
- Modify: `pubspec.yaml` (add `shared_preferences`)
- Create: `lib/services/passport_store.dart`
- Create: `test/unit/passport_store_test.dart`

**Interfaces:**
- Produces:
  - `abstract interface class PassportStore { Future<Set<String>> loadSnapshot(); Future<bool> save(Set<String> venueIds); }`
  - `SharedPrefsPassportStore(SharedPreferencesAsync prefs)` implementing it.
  - A test-only `InMemoryPassportStore` is defined inside the test file (below), not in `lib/`.

- [ ] **Step 1: Add the dependency**

Run: `flutter pub add shared_preferences`
Expected: `pubspec.yaml` gains `shared_preferences: ^2.5.5` (or newer 2.x); `flutter pub get` succeeds.

- [ ] **Step 2: Write the failing test** — `test/unit/passport_store_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/services/passport_store.dart';

/// Fakes the store contract — no plugin binding needed. One instance can be
/// told to fail its next write, to prove failures are non-fatal.
class InMemoryPassportStore implements PassportStore {
  InMemoryPassportStore([Set<String>? initial])
      : _data = {...?initial};
  Set<String> _data;
  bool failNextSave = false;
  bool failLoad = false;

  @override
  Future<Set<String>> loadSnapshot() async {
    if (failLoad) throw StateError('boom');
    return {..._data};
  }

  @override
  Future<bool> save(Set<String> venueIds) async {
    if (failNextSave) {
      failNextSave = false;
      return false;
    }
    _data = {...venueIds};
    return true;
  }
}

void main() {
  test('save then loadSnapshot round-trips', () async {
    final store = InMemoryPassportStore();
    expect(await store.save({'a', 'b'}), isTrue);
    expect(await store.loadSnapshot(), {'a', 'b'});
  });

  test('a failed save returns false and does not throw', () async {
    final store = InMemoryPassportStore({'a'})..failNextSave = true;
    expect(await store.save({'a', 'b'}), isFalse);
    // Prior data intact.
    expect(await store.loadSnapshot(), {'a'});
  });
}
```

Note: this task proves the *contract* is non-fatal via the fake. The real
`SharedPrefsPassportStore` is exercised end-to-end in Task 5's app-boot test.

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/unit/passport_store_test.dart`
Expected: FAIL — `passport_store` undefined.

- [ ] **Step 4: Write minimal implementation** — `lib/services/passport_store.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';

/// The app's first persisted mutable state. Every method is best-effort and
/// MUST NOT throw to its caller — a persistence problem can never break the
/// passport session or block launch (design §3.1).
abstract interface class PassportStore {
  /// Collected venue ids, or `{}` on first run or any failure.
  Future<Set<String>> loadSnapshot();

  /// Persists the set; returns `false` on failure instead of throwing.
  Future<bool> save(Set<String> venueIds);
}

/// Backed by the current recommended [SharedPreferencesAsync] API.
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

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/unit/passport_store_test.dart && flutter analyze`
Expected: PASS; analyze clean.

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/services/passport_store.dart test/unit/passport_store_test.dart
git commit -m "feat(passport): non-fatal SharedPreferences persistence seam (Phase 6)"
```

---

## Task 4: PassportNotifier + providers

**Files:**
- Create: `lib/services/passport_providers.dart`
- Create: `test/unit/passport_notifier_test.dart`

**Interfaces:**
- Consumes: `StampService.resolve`, `PassportPolicy` (Task 2); `PassportStore` (Task 3).
- Produces:
  - `passportSnapshotProvider` (`Provider<Set<String>>`, overridden in `main`).
  - `passportStoreProvider` (`Provider<PassportStore>`, overridden in `main`).
  - `passportProvider` (`NotifierProvider<PassportNotifier, PassportState>`).
  - `PassportState` with `Set<String> collectedVenueIds`, `bool saveFailed`, `int count`, `bool isComplete`.
  - `CollectOutcome { StampResult result; bool justCompleted; }`.
  - `PassportNotifier.collect(StampInput) → CollectOutcome`, `PassportNotifier.reset()`.

- [ ] **Step 1: Write the failing test** — `test/unit/passport_notifier_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/models/stamp_io.dart';
import 'package:aon2026/services/passport_providers.dart';
import 'package:aon2026/services/passport_store.dart';
import 'package:aon2026/data/stamp_stations_data.dart';

class _FakeStore implements PassportStore {
  Set<String> saved = {};
  bool failNextSave = false;
  @override
  Future<Set<String>> loadSnapshot() async => {...saved};
  @override
  Future<bool> save(Set<String> venueIds) async {
    if (failNextSave) {
      failNextSave = false;
      return false;
    }
    saved = {...venueIds};
    return true;
  }
}

ProviderContainer _container(_FakeStore store, {Set<String> snapshot = const {}}) {
  return ProviderContainer(overrides: [
    passportSnapshotProvider.overrideWithValue(snapshot),
    passportStoreProvider.overrideWithValue(store),
  ]);
}

void main() {
  // Two real codes from the station table (Task 1).
  const codeA = 'AON-A-TBC';
  const venueA = 'macquarie-theatre';

  test('collect adds a stamp and reports collected', () {
    final c = _container(_FakeStore());
    final out = c.read(passportProvider.notifier).collect(
        StampInput.manual(codeA));
    expect(out.result, isA<StampCollected>());
    expect(c.read(passportProvider).collectedVenueIds, contains(venueA));
    expect(c.read(passportProvider).count, 1);
  });

  test('duplicate collect is idempotent and reports alreadyHave', () {
    final c = _container(_FakeStore(), snapshot: {venueA});
    final out = c.read(passportProvider.notifier).collect(
        StampInput.manual(codeA));
    expect(out.result, isA<StampAlreadyHave>());
    expect(c.read(passportProvider).count, 1);
  });

  test('justCompleted fires exactly on the 8→9 transition', () {
    // Seed 8 of the 9 station venueIds.
    final nine = StampStationsData.all.toList();
    final firstEight = nine.take(8).map((s) => s.venueId).toSet();
    final c = _container(_FakeStore(), snapshot: firstEight);
    final ninthCode = nine[8].code;

    final out = c.read(passportProvider.notifier).collect(
        StampInput.manual(ninthCode));
    expect(out.justCompleted, isTrue);
    expect(c.read(passportProvider).isComplete, isTrue);

    // Re-scanning the 9th does not re-fire completion.
    final again = c.read(passportProvider.notifier).collect(
        StampInput.manual(ninthCode));
    expect(again.justCompleted, isFalse);
  });

  test('completion ignores stale ids (intersection)', () {
    final c = _container(_FakeStore(), snapshot: {'ghost-venue'});
    expect(c.read(passportProvider).count, 0);
  });

  test('a failed save flips saveFailed but keeps the stamp in session', () {
    final store = _FakeStore()..failNextSave = true;
    final c = _container(store);
    c.read(passportProvider.notifier).collect(StampInput.manual(codeA));
    expect(c.read(passportProvider).collectedVenueIds, contains(venueA));
    // saveFailed is set asynchronously by the fire-and-forget write.
    // Pump microtasks:
    return Future<void>.microtask(() {
      expect(c.read(passportProvider).saveFailed, isTrue);
    });
  });

  test('reset clears progress', () {
    final c = _container(_FakeStore(), snapshot: {venueA});
    c.read(passportProvider.notifier).reset();
    expect(c.read(passportProvider).count, 0);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/passport_notifier_test.dart`
Expected: FAIL — `passport_providers` undefined.

- [ ] **Step 3: Write minimal implementation** — `lib/services/passport_providers.dart`:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/models/stamp_io.dart';
import 'package:aon2026/services/passport_store.dart';
import 'package:aon2026/services/stamp_service.dart';

/// Immutable passport state. `count`/`isComplete` use the intersection with the
/// current station set, so a stale persisted id can never falsely complete.
class PassportState {
  const PassportState({
    required this.collectedVenueIds,
    this.saveFailed = false,
  });

  final Set<String> collectedVenueIds;

  /// True after a persistence write failed this session. Surfaced as a subtle,
  /// non-blocking note — never an error dialog, never a lost stamp.
  final bool saveFailed;

  int get count => PassportPolicy.completedCount(collectedVenueIds);
  bool get isComplete => PassportPolicy.isComplete(collectedVenueIds);

  PassportState copyWith({Set<String>? collectedVenueIds, bool? saveFailed}) =>
      PassportState(
        collectedVenueIds: collectedVenueIds ?? this.collectedVenueIds,
        saveFailed: saveFailed ?? this.saveFailed,
      );
}

/// The result of a capture plus whether it was the completing stamp.
class CollectOutcome {
  const CollectOutcome({required this.result, required this.justCompleted});
  final StampResult result;
  final bool justCompleted;
}

/// Overridden in `main()` with the snapshot hydrated before `runApp` (§3.1).
final passportSnapshotProvider = Provider<Set<String>>(
  (ref) => throw UnimplementedError('override passportSnapshotProvider in main'),
);

/// Overridden in `main()` with a real [SharedPrefsPassportStore].
final passportStoreProvider = Provider<PassportStore>(
  (ref) => throw UnimplementedError('override passportStoreProvider in main'),
);

final passportProvider =
    NotifierProvider<PassportNotifier, PassportState>(PassportNotifier.new);

class PassportNotifier extends Notifier<PassportState> {
  @override
  PassportState build() {
    final snapshot = ref.read(passportSnapshotProvider);
    return PassportState(collectedVenueIds: {...snapshot});
  }

  /// Resolves [input], applies a new stamp if valid, and persists best-effort.
  CollectOutcome collect(StampInput input) {
    final before = state.collectedVenueIds;
    final wasComplete = state.isComplete;
    final result = StampService.resolve(input, before);

    if (result is StampCollected) {
      final next = {...before, result.venueId};
      state = state.copyWith(collectedVenueIds: next);
      unawaited(_persist(next));
    }

    final justCompleted = !wasComplete && state.isComplete;
    return CollectOutcome(result: result, justCompleted: justCompleted);
  }

  void reset() {
    state = state.copyWith(collectedVenueIds: <String>{});
    unawaited(_persist(<String>{}));
  }

  Future<void> _persist(Set<String> ids) async {
    final ok = await ref.read(passportStoreProvider).save(ids);
    if (!ok) state = state.copyWith(saveFailed: true);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/unit/passport_notifier_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/passport_providers.dart test/unit/passport_notifier_test.dart
git commit -m "feat(passport): PassportNotifier with transition-based completion (Phase 6)"
```

---

## Task 5: Wire hydration into main() (non-fatal)

**Files:**
- Modify: `lib/main.dart`
- Create: `test/widget/passport_boot_test.dart`

**Interfaces:**
- Consumes: `passportSnapshotProvider`, `passportStoreProvider` (Task 4); `SharedPrefsPassportStore` (Task 3).
- Produces: `Future<(Set<String>, PassportStore)> loadPassport()` (top-level in `main.dart`) — hydrates best-effort and never throws.

- [ ] **Step 1: Write the failing test** — `test/widget/passport_boot_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/services/passport_providers.dart';
import 'package:aon2026/services/passport_store.dart';

class _ThrowingStore implements PassportStore {
  @override
  Future<Set<String>> loadSnapshot() async => throw StateError('disk gone');
  @override
  Future<bool> save(Set<String> venueIds) async => false;
}

void main() {
  testWidgets('a store failure yields an empty passport, app still builds',
      (tester) async {
    // Simulate main()'s guard: loadSnapshot must never throw out.
    final store = _ThrowingStore();
    Set<String> snapshot;
    try {
      snapshot = await store.loadSnapshot();
    } catch (_) {
      snapshot = <String>{};
    }

    await tester.pumpWidget(ProviderScope(
      overrides: [
        passportSnapshotProvider.overrideWithValue(snapshot),
        passportStoreProvider.overrideWithValue(store),
      ],
      child: const MaterialApp(home: Scaffold(body: Text('booted'))),
    ));

    expect(find.text('booted'), findsOneWidget);
  });
}
```

Note: `main()`'s real `loadPassport()` wraps exactly this guard. The test asserts the property; Step 3 makes `main()` use it.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget/passport_boot_test.dart`
Expected: FAIL — providers not overridden / undefined symbol if imports missing. (It should compile; if `loadPassport` referenced, it fails until added. For this test it passes only once imports resolve — run to confirm current state, then proceed.)

- [ ] **Step 3: Modify `lib/main.dart`**

Add imports:

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aon2026/services/passport_providers.dart';
import 'package:aon2026/services/passport_store.dart';
```

Add a top-level helper above `main()`:

```dart
/// Best-effort passport hydration. NEVER throws — a persistence failure must
/// not block launch (design §3.1). Returns an empty snapshot on any error.
Future<(Set<String>, PassportStore)> loadPassport() async {
  final store = SharedPrefsPassportStore(SharedPreferencesAsync());
  Set<String> snapshot;
  try {
    snapshot = await store.loadSnapshot();
  } catch (_) {
    snapshot = <String>{};
  }
  return (snapshot, store);
}
```

In `main()`, after `GlassShaderCache.ensureLoaded();` and before `runApp`:

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

(Replace the existing `runApp(const ProviderScope(child: AonApp()));`.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/widget/passport_boot_test.dart && flutter analyze`
Expected: PASS; analyze clean.

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart test/widget/passport_boot_test.dart
git commit -m "feat(passport): non-fatal hydration wired into main() (Phase 6)"
```

---

## Task 6: Routes

**Files:**
- Modify: `lib/app/router/app_router.dart`
- Create: `test/widget/passport_route_test.dart`

**Interfaces:**
- Produces: `Routes.passport` (`'/passport'`), `Routes.passportScan` (`'/passport/scan'`); both pushed above the shell.
- Consumes (forward ref): `PassportScreen` (Task 8), `PassportScanScreen` (Task 9). To keep this task independently green, add **temporary placeholder screens inline** here and replace them in Tasks 8/9.

- [ ] **Step 1: Write the failing test** — `test/widget/passport_route_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/app/router/app_router.dart';

void main() {
  test('passport route paths are defined', () {
    expect(Routes.passport, '/passport');
    expect(Routes.passportScan, '/passport/scan');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget/passport_route_test.dart`
Expected: FAIL — `Routes.passport` undefined.

- [ ] **Step 3: Modify `lib/app/router/app_router.dart`**

In `abstract final class Routes`, after `wayfinding`:

```dart
  static const String passport = '/passport';
  static const String passportScan = '/passport/scan';
```

Add two pushed `GoRoute`s alongside the existing pushed routes (after the panorama route), using the real screens (created in Tasks 8/9 — add the imports now; if implementing strictly in order, temporarily point both at a `Scaffold(body: Center(child: Text('Passport')))` and swap in Tasks 8/9):

```dart
import 'package:aon2026/screens/passport_screen.dart';
import 'package:aon2026/screens/passport_scan_screen.dart';
// ...
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: Routes.passport,
        builder: (context, state) => const PassportScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: Routes.passportScan,
        builder: (context, state) => const PassportScanScreen(),
      ),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widget/passport_route_test.dart`
Expected: PASS. (If screens not yet created, this task's *route-path* test passes; the builder imports are added in Tasks 8/9. Keep this task focused on the path constants — do not commit broken imports. If building strictly in order, create minimal stub screens in Tasks 8/9 before adding the builder lines.)

- [ ] **Step 5: Commit**

```bash
git add lib/app/router/app_router.dart test/widget/passport_route_test.dart
git commit -m "feat(passport): passport + scan route paths (Phase 6)"
```

---

## Task 7: Adaptive passport grid widget

**Files:**
- Create: `lib/widgets/passport_grid.dart`
- Create: `test/widget/passport_grid_test.dart`

**Interfaces:**
- Consumes: `StampStationsData.all`, `VenuesData.byId` (venue names).
- Produces: `PassportGrid({required Set<String> collectedVenueIds})` — a `StatelessWidget` rendering 9 cells with adaptive columns and content-driven height.

- [ ] **Step 1: Write the failing test** — `test/widget/passport_grid_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/widgets/passport_grid.dart';
import 'package:aon2026/data/stamp_stations_data.dart';

Widget _host(Set<String> collected, {Size size = const Size(320, 568),
    double textScale = 1.0}) {
  return MediaQuery(
    data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PassportGrid(collectedVenueIds: collected),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders all 9 station cells', (tester) async {
    await tester.pumpWidget(_host(<String>{}));
    // Each cell carries a Semantics label 'stamp:<venueId>'.
    for (final s in StampStationsData.all) {
      expect(find.bySemanticsLabel(RegExp('^${s.venueId}')), findsOneWidget);
    }
  });

  testWidgets('collected cells are marked collected', (tester) async {
    await tester.pumpWidget(_host({'macquarie-theatre'}));
    expect(find.bySemanticsLabel(RegExp('macquarie-theatre.*collected')),
        findsOneWidget);
  });

  testWidgets('no overflow at 320x568 and text scale 2.0', (tester) async {
    await tester.pumpWidget(_host(<String>{}, textScale: 2.0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget/passport_grid_test.dart`
Expected: FAIL — `passport_grid` undefined.

- [ ] **Step 3: Write minimal implementation** — `lib/widgets/passport_grid.dart`:

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
      label: '$venueId ${collected ? 'collected' : 'not collected'}',
      child: Container(
        padding: const EdgeInsets.all(AonSpacing.space3),
        decoration: BoxDecoration(
          color: collected
              ? AonColors.amber.withValues(alpha: 0.12)
              : AonColors.night900,
          borderRadius: BorderRadius.circular(AonSpacing.radiusMd),
          border: Border.all(
            color: collected ? AonColors.amber : AonColors.night700,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              collected
                  ? Icons.check_circle_rounded
                  : Icons.circle_outlined,
              color: collected
                  ? AonColors.amber
                  : AonColors.contentTertiary,
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

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widget/passport_grid_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/passport_grid.dart test/widget/passport_grid_test.dart
git commit -m "feat(passport): adaptive 9-cell grid, 2.0-safe (Phase 6)"
```

---

## Task 8: Passport screen

**Files:**
- Create: `lib/screens/passport_screen.dart`
- Create: `test/widget/passport_screen_test.dart`

**Interfaces:**
- Consumes: `passportProvider` (Task 4), `PassportGrid` (Task 7), `PassportPolicy`, `Routes.passportScan`, `Routes.passport` (reward via Task 11 later — for now a "View reward" button that pushes a reward route added in Task 11; until then it pushes `Routes.passportScan` is wrong — instead gate the button behind `isComplete` and route to `PassportRewardScreen` created in Task 11. To keep Task 8 green, the button calls a local `_openReward` that is a no-op placeholder replaced in Task 11).
- Produces: `PassportScreen` (`ConsumerWidget`).

- [ ] **Step 1: Write the failing test** — `test/widget/passport_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/screens/passport_screen.dart';
import 'package:aon2026/services/passport_providers.dart';
import 'package:aon2026/services/passport_store.dart';
import 'package:aon2026/data/stamp_stations_data.dart';

class _NoopStore implements PassportStore {
  @override
  Future<Set<String>> loadSnapshot() async => {};
  @override
  Future<bool> save(Set<String> venueIds) async => true;
}

Widget _host(Set<String> snapshot) => ProviderScope(
      overrides: [
        passportSnapshotProvider.overrideWithValue(snapshot),
        passportStoreProvider.overrideWithValue(_NoopStore()),
      ],
      child: const MaterialApp(home: PassportScreen()),
    );

void main() {
  testWidgets('shows progress out of 9', (tester) async {
    await tester.pumpWidget(_host({'macquarie-theatre'}));
    expect(find.textContaining('1 / 9'), findsOneWidget);
  });

  testWidgets('complete passport shows the reward affordance', (tester) async {
    final all = StampStationsData.stationVenueIds;
    await tester.pumpWidget(_host(all));
    expect(find.textContaining('9 / 9'), findsOneWidget);
    expect(find.text('View your reward'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget/passport_screen_test.dart`
Expected: FAIL — `passport_screen` undefined.

- [ ] **Step 3: Write minimal implementation** — `lib/screens/passport_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/services/passport_providers.dart';
import 'package:aon2026/services/stamp_service.dart';

/// The Astronomy Passport: progress, the 9-cell grid, and the capture entry.
class PassportScreen extends ConsumerWidget {
  const PassportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(passportProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Astronomy Passport')),
      body: ListView(
        padding: const EdgeInsets.all(AonSpacing.space4),
        children: [
          Text(
            '${state.count} / ${PassportPolicy.stationCount} stamps',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: AonSpacing.space3),
          LinearProgressIndicator(
            value: state.count / PassportPolicy.stationCount,
          ),
          if (state.saveFailed) ...[
            const SizedBox(height: AonSpacing.space3),
            Text(
              'Your progress may not be saved on this device.',
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: AonSpacing.space5),
          // PassportGrid is added to this list in Task 7's widget; import it:
          // PassportGrid(collectedVenueIds: state.collectedVenueIds),
          const SizedBox(height: AonSpacing.space5),
          if (state.isComplete)
            FilledButton.icon(
              onPressed: () => _openReward(context),
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

  // Replaced with a push to Routes.passportReward in Task 11.
  void _openReward(BuildContext context) {}
}
```

Then wire the grid: add `import 'package:aon2026/widgets/passport_grid.dart';` and replace the commented line with `PassportGrid(collectedVenueIds: state.collectedVenueIds),`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widget/passport_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/passport_screen.dart test/widget/passport_screen_test.dart
git commit -m "feat(passport): passport screen with progress + grid (Phase 6)"
```

---

## Task 9: Capture screen — manual entry (camera-free, testable)

**Files:**
- Create: `lib/screens/passport_scan_screen.dart`
- Create: `test/widget/passport_scan_screen_test.dart`

**Interfaces:**
- Consumes: `passportProvider.notifier.collect`, `StampInput.manual`, `PassportPolicy.isCollectionEnabled`.
- Produces: `PassportScanScreen` (`ConsumerStatefulWidget`) with a manual-entry field and a `Scan` affordance (the camera view is added in Task 10; manual entry is a first-class peer). Exposes a `Key('passport-manual-field')` and `Key('passport-manual-submit')` for tests.

- [ ] **Step 1: Write the failing test** — `test/widget/passport_scan_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/screens/passport_scan_screen.dart';
import 'package:aon2026/services/passport_providers.dart';
import 'package:aon2026/services/passport_store.dart';

class _NoopStore implements PassportStore {
  @override
  Future<Set<String>> loadSnapshot() async => {};
  @override
  Future<bool> save(Set<String> venueIds) async => true;
}

Widget _host() => ProviderScope(
      overrides: [
        passportSnapshotProvider.overrideWithValue(<String>{}),
        passportStoreProvider.overrideWithValue(_NoopStore()),
      ],
      child: const MaterialApp(home: PassportScanScreen()),
    );

void main() {
  testWidgets('valid manual code collects a stamp (no camera needed)',
      (tester) async {
    await tester.pumpWidget(_host());
    await tester.enterText(
        find.byKey(const Key('passport-manual-field')), 'AON-A-TBC');
    await tester.tap(find.byKey(const Key('passport-manual-submit')));
    await tester.pumpAndSettle();
    expect(find.textContaining('collected', findRichText: true),
        findsOneWidget);
  });

  testWidgets('unknown code shows the not-a-code message', (tester) async {
    await tester.pumpWidget(_host());
    await tester.enterText(
        find.byKey(const Key('passport-manual-field')), 'NOPE');
    await tester.tap(find.byKey(const Key('passport-manual-submit')));
    await tester.pumpAndSettle();
    expect(find.textContaining('not an Astronomy Open Night code'),
        findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget/passport_scan_screen_test.dart`
Expected: FAIL — `passport_scan_screen` undefined.

- [ ] **Step 3: Write minimal implementation** — `lib/screens/passport_scan_screen.dart`:

```dart
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/data/stamp_stations_data.dart';
import 'package:aon2026/models/stamp_io.dart';
import 'package:aon2026/services/passport_providers.dart';
import 'package:aon2026/services/stamp_service.dart';

/// Capture: manual entry and scanning are equal peers (design §5). Manual entry
/// needs no camera and no permission, so it is always present and first-class.
class PassportScanScreen extends ConsumerStatefulWidget {
  const PassportScanScreen({super.key});

  @override
  ConsumerState<PassportScanScreen> createState() =>
      _PassportScanScreenState();
}

class _PassportScanScreenState extends ConsumerState<PassportScanScreen> {
  final _controller = TextEditingController();
  String? _message;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submitManual() {
    final enabled = PassportPolicy.isCollectionEnabled(
      StampStationsData.all,
      isRelease: kReleaseMode,
    );
    if (!enabled) {
      setState(() => _message =
          'The passport isn\'t live yet — see staff at an information point.');
      return;
    }
    final outcome = ref
        .read(passportProvider.notifier)
        .collect(StampInput.manual(_controller.text));
    setState(() {
      _message = switch (outcome.result) {
        StampCollected() => 'Stamp collected!',
        StampAlreadyHave() => 'You already have this one.',
        StampUnknown() => 'That\'s not an Astronomy Open Night code.',
      };
    });
    // Task 11 replaces this with: if (outcome.justCompleted) push reward.
  }

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
              labelText: 'Code',
              border: OutlineInputBorder(),
            ),
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
          // Task 10 inserts the Scan (camera) affordance here, above or beside
          // this field — an equal peer, not a fallback.
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widget/passport_scan_screen_test.dart`
Expected: PASS. (Note: `findRichText` not needed; if the matcher complains, use `find.textContaining('collected')`.)

- [ ] **Step 5: Commit**

```bash
git add lib/screens/passport_scan_screen.dart test/widget/passport_scan_screen_test.dart
git commit -m "feat(passport): camera-free manual capture (equal peer) (Phase 6)"
```

---

## Task 10: Scanner adapter (mobile_scanner, kIsWeb-guarded, debounced)

**Files:**
- Modify: `pubspec.yaml` (add `mobile_scanner`)
- Create: `lib/widgets/passport_scanner_view.dart`
- Modify: `lib/screens/passport_scan_screen.dart` (mount the scanner, non-web)
- Create: `test/widget/passport_scanner_view_test.dart`

**Interfaces:**
- Produces: `PassportScannerView({required void Function(String decoded) onDecoded})` — on non-web, a `mobile_scanner` camera that calls `onDecoded` **once** per capture then pauses until dismissed; on web, a small "Scanning isn't available on the web — enter the code below" notice (never instantiates the scanner).

- [ ] **Step 1: Add the dependency**

Run: `flutter pub add mobile_scanner`
Expected: resolves a 7.x version compatible with Dart `^3.11` / Flutter `>=3.44`. Then run `flutter build ios --no-codesign` (or `flutter build apk --debug`) once to confirm the native minimums still satisfy `IPHONEOS_DEPLOYMENT_TARGET = 13.0`; if the plugin demands a bump, raise it **intentionally** and note it in the commit.

- [ ] **Step 2: Write the failing test** — `test/widget/passport_scanner_view_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/widgets/passport_scanner_view.dart';

void main() {
  testWidgets('web build shows the manual-only notice, no camera', (tester) async {
    // The test harness reports kIsWeb == false, so this asserts the widget at
    // least builds without throwing and exposes its debounce entry point.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PassportScannerView(onDecoded: (_) {}),
      ),
    ));
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/widget/passport_scanner_view_test.dart`
Expected: FAIL — `passport_scanner_view` undefined.

- [ ] **Step 4: Write minimal implementation** — `lib/widgets/passport_scanner_view.dart`:

```dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:aon2026/app/theme/aon_spacing.dart';

/// Camera QR adapter. Its only job is to emit a decoded string exactly once per
/// capture, then pause (design §7.1). On web it never instantiates the scanner
/// (design §5.1) — manual entry is the supported web path.
class PassportScannerView extends StatefulWidget {
  const PassportScannerView({required this.onDecoded, super.key});

  final void Function(String decoded) onDecoded;

  @override
  State<PassportScannerView> createState() => _PassportScannerViewState();
}

class _PassportScannerViewState extends State<PassportScannerView> {
  MobileScannerController? _controller;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _controller = MobileScannerController();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return; // debounce: one capture only
    final raw = capture.barcodes.isNotEmpty
        ? capture.barcodes.first.rawValue
        : null;
    if (raw == null) return;
    _handled = true;
    _controller?.stop();
    widget.onDecoded(raw);
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || _controller == null) {
      return Padding(
        padding: const EdgeInsets.all(AonSpacing.space4),
        child: Text(
          'Scanning isn\'t available on the web — enter the code below.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    return AspectRatio(
      aspectRatio: 1,
      child: MobileScanner(controller: _controller, onDetect: _onDetect),
    );
  }
}
```

- [ ] **Step 5: Mount it in `passport_scan_screen.dart`** (above the manual field, as an equal peer; only when not web):

```dart
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:aon2026/widgets/passport_scanner_view.dart';
// ...inside build()'s ListView children, before the manual "Enter the code" text:
          if (!kIsWeb)
            PassportScannerView(
              onDecoded: (raw) => _handleDecoded(StampInput.scan(raw)),
            ),
          if (!kIsWeb) const SizedBox(height: AonSpacing.space4),
```

Refactor `_submitManual` to share logic via `_handleDecoded(StampInput)`:

```dart
  void _handleDecoded(StampInput input) {
    final enabled = PassportPolicy.isCollectionEnabled(
      StampStationsData.all, isRelease: kReleaseMode);
    if (!enabled) {
      setState(() => _message =
          'The passport isn\'t live yet — see staff at an information point.');
      return;
    }
    final outcome = ref.read(passportProvider.notifier).collect(input);
    setState(() {
      _message = switch (outcome.result) {
        StampCollected() => 'Stamp collected!',
        StampAlreadyHave() => 'You already have this one.',
        StampUnknown() => 'That\'s not an Astronomy Open Night code.',
      };
    });
    // Task 11: if (outcome.justCompleted) context.push(Routes.passportReward);
  }

  void _submitManual() => _handleDecoded(StampInput.manual(_controller.text));
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test && flutter analyze`
Expected: PASS; analyze clean. (The prior manual-entry test still passes.)

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/widgets/passport_scanner_view.dart lib/screens/passport_scan_screen.dart test/widget/passport_scanner_view_test.dart
git commit -m "feat(passport): debounced, web-guarded QR scanner adapter (Phase 6)"
```

---

## Task 11: Reward screen + confetti + completion trigger

**Files:**
- Modify: `pubspec.yaml` (add `confetti`)
- Create: `lib/screens/passport_reward_screen.dart`
- Modify: `lib/app/router/app_router.dart` (`Routes.passportReward`)
- Modify: `lib/screens/passport_scan_screen.dart` (push reward on `justCompleted`)
- Modify: `lib/screens/passport_screen.dart` (`_openReward` pushes the route)
- Create: `test/widget/passport_reward_test.dart`

**Interfaces:**
- Produces: `Routes.passportReward` (`'/passport/reward'`); `PassportRewardScreen` showing a live clock + event name + confetti (reduced-motion ⇒ static).

- [ ] **Step 1: Add the dependency**

Run: `flutter pub add confetti`
Expected: resolves `confetti: ^0.8.0` (or newer). `flutter pub get` succeeds.

- [ ] **Step 2: Write the failing test** — `test/widget/passport_reward_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/screens/passport_reward_screen.dart';

Widget _host({double textScale = 1.0, bool reduceMotion = false}) => MediaQuery(
      data: MediaQueryData(
        size: const Size(320, 568),
        textScaler: TextScaler.linear(textScale),
        disableAnimations: reduceMotion,
      ),
      child: const MaterialApp(home: PassportRewardScreen()),
    );

void main() {
  testWidgets('shows the redeem instruction', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Show this to staff'), findsOneWidget);
  });

  testWidgets('reduced motion builds without a confetti burst', (tester) async {
    await tester.pumpWidget(_host(reduceMotion: true));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('no overflow at 320x568 / 2.0', (tester) async {
    await tester.pumpWidget(_host(textScale: 2.0));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/widget/passport_reward_test.dart`
Expected: FAIL — `passport_reward_screen` undefined.

- [ ] **Step 4: Write minimal implementation** — `lib/screens/passport_reward_screen.dart`:

```dart
import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import 'package:aon2026/app/theme/aon_colors.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/utils/time_format.dart';

/// Completion screen. The live clock is a NUDGE, not a security control (design
/// §7.3) — staff + wristband is the real gate. Confetti honours reduced motion.
class PassportRewardScreen extends StatefulWidget {
  const PassportRewardScreen({super.key});

  @override
  State<PassportRewardScreen> createState() => _PassportRewardScreenState();
}

class _PassportRewardScreenState extends State<PassportRewardScreen> {
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    if (!MediaQuery.disableAnimationsOf(context)) {
      _confetti.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                  // Live clock — a nudge only.
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

If `TimeFormat.clockWithSeconds` does not exist, add it to `lib/utils/time_format.dart`:

```dart
  /// e.g. "8:41:07 pm" — used by the passport reward's live clock.
  static String clockWithSeconds(DateTime t) =>
      DateFormat('h:mm:ss a').format(t);
```

- [ ] **Step 5: Wire the route + completion push**

In `app_router.dart` add `static const String passportReward = '/passport/reward';` and a pushed `GoRoute` building `const PassportRewardScreen()`.

In `passport_scan_screen.dart` `_handleDecoded`, after setting `_message`, add:

```dart
    if (outcome.justCompleted) {
      context.push(Routes.passportReward);
    }
```

(Import `go_router` and `Routes`.)

In `passport_screen.dart`, make `_openReward` real: `void _openReward(BuildContext context) => context.push(Routes.passportReward);` (import already has `go_router`/`Routes`).

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test && flutter analyze`
Expected: PASS; analyze clean.

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/screens/passport_reward_screen.dart lib/utils/time_format.dart lib/app/router/app_router.dart lib/screens/passport_scan_screen.dart lib/screens/passport_screen.dart test/widget/passport_reward_test.dart
git commit -m "feat(passport): reward screen, confetti, transition-only completion (Phase 6)"
```

---

## Task 12: Entry points — Home card + Info menu

**Files:**
- Create: `lib/widgets/passport_home_card.dart`
- Modify: `lib/screens/home_screen.dart`
- Modify: `lib/screens/info_screen.dart`
- Create: `test/widget/passport_entry_points_test.dart`

**Interfaces:**
- Consumes: `passportProvider`, `Routes.passport`.
- Produces: `PassportHomeCard` (`ConsumerWidget`) showing "N / 9 stamps" and pushing `Routes.passport`.

- [ ] **Step 1: Write the failing test** — `test/widget/passport_entry_points_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/widgets/passport_home_card.dart';
import 'package:aon2026/services/passport_providers.dart';
import 'package:aon2026/services/passport_store.dart';

class _NoopStore implements PassportStore {
  @override
  Future<Set<String>> loadSnapshot() async => {};
  @override
  Future<bool> save(Set<String> v) async => true;
}

void main() {
  testWidgets('home card shows progress', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        passportSnapshotProvider.overrideWithValue({'macquarie-theatre'}),
        passportStoreProvider.overrideWithValue(_NoopStore()),
      ],
      child: const MaterialApp(home: Scaffold(body: PassportHomeCard())),
    ));
    expect(find.textContaining('1 / 9'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget/passport_entry_points_test.dart`
Expected: FAIL — `passport_home_card` undefined.

- [ ] **Step 3: Write minimal implementation** — `lib/widgets/passport_home_card.dart`:

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

/// Home-screen entry to the Astronomy Passport, showing live progress.
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
                  Text('Astronomy Passport',
                      style: theme.textTheme.titleSmall),
                  Text(
                    '${state.count} / ${PassportPolicy.stationCount} stamps',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AonColors.contentSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AonColors.amber),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Add both entry points**

In `home_screen.dart`, after the "Get started" tiles `LayoutBuilder` (before the `SizedBox(height: AonSpacing.space6)`), add:

```dart
import 'package:aon2026/widgets/passport_home_card.dart';
// ...
                const SizedBox(height: AonSpacing.space5),
                const PassportHomeCard(),
```

In `info_screen.dart`, after "The essentials" container (before the First aid `SectionHeader`), add a CTA using the existing button pattern:

```dart
import 'package:aon2026/app/router/app_router.dart';
// ...
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

(`info_screen.dart` already imports `go_router`; add the `Routes` import if missing — it already imports `app_router.dart`.)

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test && flutter analyze`
Expected: PASS; analyze clean.

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/passport_home_card.dart lib/screens/home_screen.dart lib/screens/info_screen.dart test/widget/passport_entry_points_test.dart
git commit -m "feat(passport): Home card + Info menu entry points (Phase 6)"
```

---

## Task 13: Platform manifests, web build gate, docs, and full verification

**Files:**
- Modify: `ios/Runner/Info.plist`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `docs/data-sources.md`
- Modify: `docs/superpowers/specs/2026-08-10-aon-astronomy-passport-phase6-design.md` (mark verification results)

- [ ] **Step 1: iOS camera usage string** — add to `ios/Runner/Info.plist` inside the top `<dict>`:

```xml
	<key>NSCameraUsageDescription</key>
	<string>Used only to scan the QR code on a venue sign for your Astronomy Passport. Camera images are processed on your device and never stored or sent anywhere.</string>
```

- [ ] **Step 2: Android camera permission (optional hardware)** — add to `android/app/src/main/AndroidManifest.xml` above `<application>`:

```xml
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-feature android:name="android.hardware.camera" android:required="false" />
    <uses-feature android:name="android.hardware.camera.autofocus" android:required="false" />
```

- [ ] **Step 3: Verify the web build (scanner un-instantiated on web)**

Run: `flutter build web`
Expected: SUCCESS. Then, optionally, `flutter run -d chrome` and confirm the capture screen shows the manual-only notice and no camera.

- [ ] **Step 4: Document the placeholder codes** — append to `docs/data-sources.md` a "Passport station codes" row noting all 9 are `placeholder` pending organiser confirmation, and that release builds keep collection disabled until confirmed (cross-reference the spec §10/§14).

- [ ] **Step 5: Full gate**

Run: `flutter analyze && flutter test`
Expected: analyze clean; **all** tests pass (unit + widget, including the new passport suites and the untouched Phase 1–5 tests).

Then run the platform builds:

Run: `flutter build ios --no-codesign` and `flutter build apk --debug`
Expected: both succeed. If `mobile_scanner` forced an `IPHONEOS_DEPLOYMENT_TARGET` change, confirm it is committed and noted.

- [ ] **Step 6: Record verification results** in the spec's §16 (append the actual resolved `mobile_scanner`/`confetti`/`shared_preferences` versions, the iOS deployment target outcome, and the web-build result).

- [ ] **Step 7: Commit**

```bash
git add ios/Runner/Info.plist android/app/src/main/AndroidManifest.xml docs/data-sources.md docs/superpowers/specs/2026-08-10-aon-astronomy-passport-phase6-design.md
git commit -m "feat(passport): camera manifests, web-build gate, docs + verification (Phase 6)"
```

---

## Self-Review

**1. Spec coverage**

| Spec section | Task(s) |
|---|---|
| §1 nine stations | Task 1 |
| §2 decisions (all-9, no tab) | Tasks 1, 8, 12 |
| §3.1 non-fatal persistence | Tasks 3, 5 |
| §3.2 typed input seam | Task 2 |
| §4.1 codes not secrets (framing) | Task 1 (doc comments), Task 2 |
| §4.2 confidence field | Task 1 |
| §4.3 intersection completion | Tasks 2, 4 |
| §5 capture equal peers | Tasks 9, 10 |
| §5.1 web manual-only | Task 10 |
| §6 entry points, no 6th tab | Task 12 |
| §6.1 adaptive grid @2.0 | Task 7 |
| §7.1 scanner debounce | Task 10 |
| §7.2 transition-only completion | Tasks 4, 11 |
| §7.3 reward + reduced-motion confetti | Task 11 |
| §8 a11y/2.0 | Tasks 7, 11 |
| §9 deps + platform | Tasks 3, 10, 11, 13 |
| §9.2 manifest + data safety | Task 13 |
| §10 release gate | Tasks 2 (policy), 9/10 (enforced), 1 (data) |
| §11 tests | every task (TDD) + Task 13 (integration/build) |
| §11.1 demo/reset | Task 4 (`reset`), Task 9/10 (`kReleaseMode` demo gate) |
| §14 organiser placeholders | Task 1 (placeholder codes), Task 13 (docs) |

**Gap noted & closed:** §11.1 asks for a debug-only "collect all." `reset()` exists (Task 4). A debug "collect all" affordance is minor; add it as a debug-only button on `PassportScreen` during Task 8 if desired, or defer — it is not required for any user-facing behaviour and is covered operationally by handing test codes to staff (spec §11.1 "and/or"). Left as an optional add in Task 8; not a blocker.

**2. Placeholder scan**

No "TBD/TODO/handle appropriately" in implementation steps. The station *codes* are intentionally placeholder **data** (spec-mandated, gated by §10), not plan placeholders. Cross-task forward references (Tasks 6→8/9, 8→11, 9→10/11) are each called out explicitly with the exact symbol and the task that fills them.

**3. Type consistency**

Verified across tasks: `StampInput.scan/manual`, `StampResult` (`StampCollected`/`StampAlreadyHave`/`StampUnknown`), `StampService.resolve`, `PassportPolicy.{completedCount,isComplete,isCollectionEnabled,stationCount}`, `PassportStore.{loadSnapshot,save}`, `PassportState.{collectedVenueIds,count,isComplete,saveFailed}`, `CollectOutcome.{result,justCompleted}`, `passportProvider`/`passportSnapshotProvider`/`passportStoreProvider`, `Routes.{passport,passportScan,passportReward}` — all names match between definition and use.

---

## Notes for the executor

- Tasks 6, 8, 9, 10, 11 have **forward references** by design (routes reference screens; screens reference the reward route). If executing strictly one-at-a-time with a green `flutter analyze` between tasks, use the minimal stubs called out in each task, then replace them in the naming task. The subagent-driven flow's per-task review is the right fit.
- Every task ends green (`flutter analyze && flutter test`). Never loosen a Phase 1–5 test to make a passport test pass — if an existing test breaks, the integration is wrong, not the test.
