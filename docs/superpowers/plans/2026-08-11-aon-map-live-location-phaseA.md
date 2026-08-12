# Map Parity Phase A — Live Location Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A live "you are here" dot + accuracy circle on the campus map, a follow-me camera that recenters as you walk, and a stateful locate control — lazily permissioned, fully degradable, and battery-scoped.

**Architecture:** Three decoupled Riverpod responsibilities — `active` (GPS/dot on), `following` (camera follows), and `mapVisible` (lifecycle) — orchestrated by a `LocationController` over a faked `LocationService` seam (`geolocator`). A user map-pan exits follow but keeps the dot; runtime GPS failures transition to a recovery state; the GPS stream runs only while `active && mapVisible`.

**Tech Stack:** Flutter 3.44.7, Riverpod 3, `flutter_map` 8.3.1, `latlong2`, **one new dep `geolocator` (14.x)**. l10n (EN+FA), Palette (`context.aon`).

## Global Constraints

- **One new dependency only: `geolocator`.** No `permission_handler`, no `flutter_compass` (spec §4).
- **Heading cone + map rotation are OUT** (IOU-A2/A3). Phase A = dot + accuracy circle + follow-me.
- **Three decoupled providers** (spec §5.3): `active` ≠ `following` ≠ `mapVisible`. GPS runs iff `active && mapVisible`. Camera moves iff `following && isNearCampus(fix)`.
- **Live dot survives follow-off; a user pan (`onPositionChanged` `hasGesture==true`) exits follow but keeps the dot** (spec §5.7).
- **Lazy permission** — request only on first locate tap, never on Map-tab open (spec §D2).
- **Instant recenter** (`MapController.move`, no animation) (spec §D5).
- **Web attempt-first** — never treat web `checkPermission()==denied` as authoritative; guard `openAppSettings`/`openLocationSettings`/`getServiceStatusStream` with `kIsWeb` (throw `UnsupportedError` on web) (spec §5.2.1, §7).
- **Runtime-failure transition** — stream error / mid-session serviceOff → cancel, `active=false`, `following=false`, drop dot, recovery state (spec §5.7).
- **iOS foreground/When-In-Use only** — only `NSLocationWhenInUseUsageDescription`; no Always key, no `UIBackgroundModes: location` (spec §D8).
- **Layer order**: TileLayer → accuracy CircleLayer → venue MarkerLayer → user-dot MarkerLayer → controls (spec §5.5).
- **Low-accuracy policy**: `accuracyMeters > 200` ⇒ dot shown, circle omitted, "low accuracy" state (spec §5.1).
- **Campus radius** `MapConfig.locationCampusRadiusMeters = 2500`; one canonical `distanceFromCampusMeters` used by guard + banner (spec §5.4).
- **All new user strings** go in **both** `lib/l10n/app_en.arb` and `lib/l10n/app_fa.arb` (build fails if FA misses a key), via `context.aon` colours; every new surface passes `320×568 / 2.0`.
- **Per-task gate:** `flutter analyze && flutter test`; **web build re-verified** where the dep is touched. Never weaken an existing test.

---

## File Structure

**Create:** `lib/models/user_location_fix.dart`, `lib/services/location_service.dart`, `lib/services/location_providers.dart`, `lib/widgets/user_location_layer.dart`, `lib/widgets/locate_button.dart`, and mirrored tests.
**Modify:** `pubspec.yaml`, `lib/widgets/map_config.dart` (campus distance + radius), `lib/widgets/map_control_island.dart` (host the locate button), `lib/screens/map_screen.dart` (layer + button + pan + mapVisible + banner), `ios/Runner/Info.plist`, `android/app/src/main/AndroidManifest.xml`, `lib/l10n/app_en.arb`, `lib/l10n/app_fa.arb`.

**Task order:** 0 preflight → 1 dep+platform config → 2 model → 3 campus distance → 4 service (interface+impl) + shared fake → 5 controller+providers → 6 location layer (StatelessWidgets) → **7 l10n strings → 8 locate button** (button needs the l10n keys) → 9 map wiring → 10 verification.

---

## Task 0: Preflight & baseline

- [ ] **Step 1: Branch + clean tree** — Run:
```bash
git status --short          # expect empty
git rev-parse HEAD          # record base SHA
git checkout feature/map-live-location-phaseA 2>/dev/null \
  || git checkout -b feature/map-live-location-phaseA
git branch --show-current   # must be feature/map-live-location-phaseA
```
- [ ] **Step 2: Baseline** — Run: `flutter analyze && flutter test` — Expected: clean; **record the passing count**.
- [ ] **Step 3: Baseline builds** — Run: `flutter build web && flutter build apk --debug` — Expected: both succeed (isolates any later web-build break to the new dep).
- [ ] **Step 4: No commit.**

---

## Task 1: Add `geolocator` + platform config (web build must stay green)

**Files:** Modify `pubspec.yaml`, `ios/Runner/Info.plist`, `android/app/src/main/AndroidManifest.xml`.

- [ ] **Step 1: Add the dependency** — Run: `flutter pub add geolocator` — Expected: resolves 14.x; `pub get` OK.

- [ ] **Step 2: Verify the web build still compiles** (the whole reason we dropped flutter_compass) — Run: `flutter build web` — Expected: SUCCESS. If it fails, STOP — geolocator's web support is a hard requirement; do not proceed.

- [ ] **Step 3: iOS — When-In-Use only** — in `ios/Runner/Info.plist` `<dict>` add ONLY:
```xml
	<key>NSLocationWhenInUseUsageDescription</key>
	<string>Shows where you are on the campus map so you can find your way between venues at night. Your location stays on your device and is never sent anywhere.</string>
```
Do NOT add `NSLocationAlwaysAndWhenInUseUsageDescription` or a `location` entry under `UIBackgroundModes` — foreground only (spec §D8).

- [ ] **Step 4: Android — location permissions** — in `android/app/src/main/AndroidManifest.xml` above `<application>`:
```xml
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

- [ ] **Step 5: Analyze + commit**
```bash
flutter analyze
git add pubspec.yaml pubspec.lock ios/Runner/Info.plist android/app/src/main/AndroidManifest.xml
git commit -m "feat(map): add geolocator + When-In-Use location config (Phase A)"
```

---

## Task 2: `UserLocationFix` model (validated)

**Files:** Create `lib/models/user_location_fix.dart`, `test/unit/user_location_fix_test.dart`.

**Interfaces:** Produces `UserLocationFix({required LatLng position, required double accuracyMeters})` with `isLowAccuracy` and `static const poorAccuracyMeters`.

- [ ] **Step 1: Write the failing test** — `test/unit/user_location_fix_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:aon2026/models/user_location_fix.dart';

void main() {
  test('accepts a valid fix; low-accuracy threshold at 200m', () {
    final ok = UserLocationFix(
        position: const LatLng(-33.7737, 151.1134), accuracyMeters: 12);
    expect(ok.isLowAccuracy, isFalse);
    expect(
        UserLocationFix(position: const LatLng(-33.77, 151.11), accuracyMeters: 250)
            .isLowAccuracy,
        isTrue);
  });

  test('rejects impossible coordinates and non-positive accuracy', () {
    expect(
        () => UserLocationFix(
            position: const LatLng(200, 0), accuracyMeters: 5),
        throwsA(isA<AssertionError>()));
    expect(
        () => UserLocationFix(
            position: const LatLng(-33.77, 151.11), accuracyMeters: 0),
        throwsA(isA<AssertionError>()));
  });
}
```

- [ ] **Step 2: Run to verify it fails** — `flutter test test/unit/user_location_fix_test.dart` → FAIL (undefined).

- [ ] **Step 3: Implement** — `lib/models/user_location_fix.dart`:

```dart
import 'package:latlong2/latlong.dart';

/// A validated device-position fix (no heading — Phase A, spec §5.1).
class UserLocationFix {
  UserLocationFix({required this.position, required this.accuracyMeters})
      : assert(position.latitude.abs() <= 90 &&
            position.longitude.abs() <= 180),
        assert(accuracyMeters.isFinite && accuracyMeters > 0);

  final LatLng position;
  final double accuracyMeters;

  /// Above this, the accuracy circle would be a misleading blob — the layer
  /// omits it and the control shows a "low accuracy" state (spec §5.1).
  static const double poorAccuracyMeters = 200;
  bool get isLowAccuracy => accuracyMeters > poorAccuracyMeters;
}
```

- [ ] **Step 4: Run to verify it passes** — PASS.
- [ ] **Step 5: Commit**
```bash
git add lib/models/user_location_fix.dart test/unit/user_location_fix_test.dart
git commit -m "feat(map): validated UserLocationFix model (Phase A)"
```

---

## Task 3: Campus distance in `MapConfig`

**Files:** Modify `lib/widgets/map_config.dart`; Create `test/unit/campus_distance_test.dart`.

**Interfaces:** Produces `MapConfig.locationCampusRadiusMeters` (`double`), `MapConfig.distanceFromCampusMeters(LatLng)` (`double`), `MapConfig.isNearCampus(LatLng, {double radiusMeters})` (`bool`).

- [ ] **Step 1: Write the failing test** — `test/unit/campus_distance_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:aon2026/widgets/map_config.dart';

void main() {
  test('campus centre is ~0 m away and near', () {
    expect(MapConfig.distanceFromCampusMeters(MapConfig.campusCentre),
        lessThan(1));
    expect(MapConfig.isNearCampus(MapConfig.campusCentre), isTrue);
  });

  test('a point ~5 km away is far', () {
    // ~0.045 deg latitude ≈ 5 km.
    final far = LatLng(MapConfig.campusCentre.latitude + 0.045,
        MapConfig.campusCentre.longitude);
    expect(MapConfig.distanceFromCampusMeters(far), greaterThan(4000));
    expect(MapConfig.isNearCampus(far), isFalse);
  });

  test('radius default is the config constant (2500 m)', () {
    expect(MapConfig.locationCampusRadiusMeters, 2500);
  });
}
```

- [ ] **Step 2: Run to verify it fails** — FAIL.

- [ ] **Step 3: Implement** — add to `map_config.dart` (it already imports `latlong2` and defines `campusCentre`):

```dart
  /// Follow-me only recenters within this radius of campus; beyond it the map
  /// stays framed on campus and shows an "off campus" note (spec §5.4).
  static const double locationCampusRadiusMeters = 2500;

  static final Distance _distance = const Distance();

  /// One canonical calculation, consumed by BOTH the guard and the banner.
  static double distanceFromCampusMeters(LatLng p) =>
      _distance.as(LengthUnit.Meter, campusCentre, p);

  static bool isNearCampus(LatLng p,
          {double radiusMeters = locationCampusRadiusMeters}) =>
      distanceFromCampusMeters(p) <= radiusMeters;
```

(Add `import 'package:latlong2/latlong.dart';` if not present — it is, since `campusCentre` is a `LatLng`.)

- [ ] **Step 4: Run to verify it passes** — PASS.
- [ ] **Step 5: Commit**
```bash
git add lib/widgets/map_config.dart test/unit/campus_distance_test.dart
git commit -m "feat(map): canonical campus-distance + radius config (Phase A)"
```

---

## Task 4: `LocationService` seam (interface + real impl + fake)

**Files:** Create `lib/services/location_service.dart`, `test/support/fake_location_service.dart` (shared — imported by Tasks 4, 5, 9), `test/unit/location_service_fake_test.dart`.

**Interfaces:** Produces `enum LocationStatus`, `abstract interface class LocationService` (`status`, `request`, `watch`, `serviceEnabledChanges`, `openAppSettings`, `openLocationSettings`), `GeolocatorLocationService` (real), and a shared `FakeLocationService` in `test/support/`.

- [ ] **Step 1: Write the shared fake + a failing contract test.** Put the fake in `test/support/fake_location_service.dart` (not a `_test.dart` file — so other tests import it cleanly) and the test in `test/unit/location_service_fake_test.dart`.

`test/support/fake_location_service.dart` (the fake ONLY — no `main()`, so the runner ignores it and other tests import it cleanly):
```dart
import 'dart:async';
import 'package:aon2026/models/user_location_fix.dart';
import 'package:aon2026/services/location_service.dart';

/// Fake used across all Phase A state/wiring tests.
class FakeLocationService implements LocationService {
  FakeLocationService({this.grant = LocationStatus.granted});
  LocationStatus grant;
  final _fixes = StreamController<UserLocationFix>.broadcast();
  final _service = StreamController<bool>.broadcast();
  int appSettingsOpened = 0;
  int locationSettingsOpened = 0;

  void emit(UserLocationFix f) => _fixes.add(f);
  void emitError(Object e) => _fixes.addError(e);
  void emitServiceEnabled(bool v) => _service.add(v);

  @override
  Future<LocationStatus> status() async => grant;
  @override
  Future<LocationStatus> request() async => grant;
  @override
  Stream<UserLocationFix> watch() => _fixes.stream;
  @override
  Stream<bool> serviceEnabledChanges() => _service.stream;
  @override
  Future<void> openAppSettings() async => appSettingsOpened++;
  @override
  Future<void> openLocationSettings() async => locationSettingsOpened++;
}
```

`test/unit/location_service_fake_test.dart` (the contract test — imports the fake, carries `main()`):
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:aon2026/models/user_location_fix.dart';
import '../support/fake_location_service.dart';

void main() {
  test('fake streams a fix', () async {
    final f = FakeLocationService();
    final got = <UserLocationFix>[];
    final sub = f.watch().listen(got.add);
    f.emit(UserLocationFix(
        position: const LatLng(-33.7737, 151.1134), accuracyMeters: 8));
    await Future<void>.delayed(Duration.zero);
    expect(got, hasLength(1));
    await sub.cancel();
  });
}
```

- [ ] **Step 2: Run to verify it fails** — FAIL (`location_service` undefined).

- [ ] **Step 3: Implement** — `lib/services/location_service.dart`:

```dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:aon2026/models/user_location_fix.dart';

enum LocationStatus { unknown, granted, denied, deniedForever, serviceOff }

/// The hardware seam. Everything above this is tested with a fake (spec §5.2).
abstract interface class LocationService {
  Future<LocationStatus> status();
  Future<LocationStatus> request();
  Stream<UserLocationFix> watch();
  Stream<bool> serviceEnabledChanges();
  Future<void> openAppSettings();
  Future<void> openLocationSettings();
}

class GeolocatorLocationService implements LocationService {
  @override
  Future<LocationStatus> status() async {
    // Web: checkPermission can falsely say denied — do not gate on it here;
    // request()/watch() attempt acquisition and the browser prompts (§5.2.1).
    if (kIsWeb) return LocationStatus.unknown;
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationStatus.serviceOff;
    }
    return _map(await Geolocator.checkPermission());
  }

  @override
  Future<LocationStatus> request() async {
    if (!kIsWeb && !await Geolocator.isLocationServiceEnabled()) {
      return LocationStatus.serviceOff;
    }
    return _map(await Geolocator.requestPermission());
  }

  @override
  Stream<UserLocationFix> watch() => Geolocator.getPositionStream(
        locationSettings: const LocationSettings(distanceFilter: 5),
      ).where((p) => p.latitude.abs() <= 90 && p.longitude.abs() <= 180 &&
          p.accuracy.isFinite && p.accuracy > 0)
       .map((p) => UserLocationFix(
            position: LatLng(p.latitude, p.longitude),
            accuracyMeters: p.accuracy,
          ));

  @override
  Stream<bool> serviceEnabledChanges() {
    if (kIsWeb) return const Stream<bool>.empty(); // unsupported on web
    return Geolocator.getServiceStatusStream()
        .map((s) => s == ServiceStatus.enabled);
  }

  @override
  Future<void> openAppSettings() async {
    if (kIsWeb) return; // UnsupportedError on web
    await Geolocator.openAppSettings();
  }

  @override
  Future<void> openLocationSettings() async {
    if (kIsWeb) return; // UnsupportedError on web
    await Geolocator.openLocationSettings();
  }

  LocationStatus _map(LocationPermission p) => switch (p) {
        LocationPermission.always ||
        LocationPermission.whileInUse =>
          LocationStatus.granted,
        LocationPermission.denied => LocationStatus.denied,
        LocationPermission.deniedForever => LocationStatus.deniedForever,
        LocationPermission.unableToDetermine => LocationStatus.unknown,
      };
}
```

- [ ] **Step 4: Run to verify it passes** — Run: `flutter test test/unit/location_service_fake_test.dart && flutter analyze` — Expected: PASS; clean.
- [ ] **Step 5: Commit**
```bash
git add lib/services/location_service.dart test/support/fake_location_service.dart test/unit/location_service_fake_test.dart
git commit -m "feat(map): LocationService seam over geolocator + web guards + shared fake (Phase A)"
```

---

## Task 5: `LocationController` + providers (the decoupled state machine)

**Files:** Create `lib/services/location_providers.dart`, `test/unit/location_controller_test.dart`.

**Interfaces:**
- `LocationSnapshot({LocationStatus status, UserLocationFix? fix, bool active, bool following})`.
- Providers: `locationServiceProvider` (`Provider<LocationService>`), `mapVisibleProvider` (`StateProvider<bool>`, default false), `locationControllerProvider` (`NotifierProvider<LocationController, LocationSnapshot>`).
- `LocationController.onLocateTapped()`, `.onUserPan()`.

- [ ] **Step 1: Write the failing test** — `test/unit/location_controller_test.dart` (imports the shared `FakeLocationService` from `test/support/`):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:aon2026/models/user_location_fix.dart';
import 'package:aon2026/services/location_service.dart';
import 'package:aon2026/services/location_providers.dart';
import '../support/fake_location_service.dart';

ProviderContainer _c(FakeLocationService svc, {bool visible = true}) {
  final c = ProviderContainer(overrides: [
    locationServiceProvider.overrideWithValue(svc),
  ]);
  c.read(mapVisibleProvider.notifier).state = visible;
  return c;
}

UserLocationFix _fix([double acc = 8]) => UserLocationFix(
    position: const LatLng(-33.7737, 151.1134), accuracyMeters: acc);

void main() {
  test('locate grants -> active + following; dot updates', () async {
    final svc = FakeLocationService();
    final c = _c(svc);
    await c.read(locationControllerProvider.notifier).onLocateTapped();
    expect(c.read(locationControllerProvider).active, isTrue);
    expect(c.read(locationControllerProvider).following, isTrue);
    svc.emit(_fix());
    await Future<void>.delayed(Duration.zero);
    expect(c.read(locationControllerProvider).fix, isNotNull);
  });

  test('user pan exits follow but keeps the live dot', () async {
    final svc = FakeLocationService();
    final c = _c(svc);
    await c.read(locationControllerProvider.notifier).onLocateTapped();
    c.read(locationControllerProvider.notifier).onUserPan();
    final s = c.read(locationControllerProvider);
    expect(s.following, isFalse);
    expect(s.active, isTrue); // dot still live (decoupling, §P1-1/§P1-2)
    svc.emit(_fix());
    await Future<void>.delayed(Duration.zero);
    expect(c.read(locationControllerProvider).fix, isNotNull);
  });

  test('tap while active-not-following re-enables follow', () async {
    final svc = FakeLocationService();
    final c = _c(svc);
    final n = c.read(locationControllerProvider.notifier);
    await n.onLocateTapped();
    n.onUserPan(); // follow off
    await n.onLocateTapped(); // re-follow (already active)
    expect(c.read(locationControllerProvider).following, isTrue);
  });

  test('deniedForever opens app settings; serviceOff opens location settings',
      () async {
    final denied = FakeLocationService(grant: LocationStatus.deniedForever);
    final c1 = _c(denied);
    await c1.read(locationControllerProvider.notifier).onLocateTapped();
    expect(denied.appSettingsOpened, 1);
    expect(c1.read(locationControllerProvider).active, isFalse);

    final off = FakeLocationService(grant: LocationStatus.serviceOff);
    final c2 = _c(off);
    await c2.read(locationControllerProvider.notifier).onLocateTapped();
    expect(off.locationSettingsOpened, 1);
  });

  test('runtime stream error resets to a recovery state', () async {
    final svc = FakeLocationService();
    final c = _c(svc);
    await c.read(locationControllerProvider.notifier).onLocateTapped();
    svc.emitError(StateError('gps lost'));
    await Future<void>.delayed(Duration.zero);
    final s = c.read(locationControllerProvider);
    expect(s.active, isFalse);
    expect(s.following, isFalse);
    expect(s.fix, isNull);
  });

  test('hidden map pauses the stream and drops follow', () async {
    final svc = FakeLocationService();
    final c = _c(svc);
    await c.read(locationControllerProvider.notifier).onLocateTapped();
    c.read(mapVisibleProvider.notifier).state = false; // tab hidden
    await Future<void>.delayed(Duration.zero);
    expect(c.read(locationControllerProvider).following, isFalse);
    // A fix emitted while hidden is ignored (stream cancelled).
    svc.emit(_fix());
    await Future<void>.delayed(Duration.zero);
    // active intent retained for resume:
    expect(c.read(locationControllerProvider).active, isTrue);
  });
}
```

- [ ] **Step 2: Run to verify it fails** — FAIL.

- [ ] **Step 3: Implement** — `lib/services/location_providers.dart`:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/models/user_location_fix.dart';
import 'package:aon2026/services/location_service.dart';

class LocationSnapshot {
  const LocationSnapshot({
    this.status = LocationStatus.unknown,
    this.fix,
    this.active = false,
    this.following = false,
  });
  final LocationStatus status;
  final UserLocationFix? fix;
  final bool active;
  final bool following;

  LocationSnapshot copyWith({
    LocationStatus? status,
    bool clearFix = false,
    UserLocationFix? fix,
    bool? active,
    bool? following,
  }) =>
      LocationSnapshot(
        status: status ?? this.status,
        fix: clearFix ? null : (fix ?? this.fix),
        active: active ?? this.active,
        following: following ?? this.following,
      );
}

final locationServiceProvider =
    Provider<LocationService>((ref) => throw UnimplementedError(
        'override with GeolocatorLocationService in main / a fake in tests'));

/// Whether the Map shell branch is on-screen (driven by the map screen via
/// TickerMode). GPS runs only when this is true AND location is active.
final mapVisibleProvider = StateProvider<bool>((ref) => false);

final locationControllerProvider =
    NotifierProvider<LocationController, LocationSnapshot>(
        LocationController.new);

class LocationController extends Notifier<LocationSnapshot> {
  StreamSubscription<UserLocationFix>? _sub;
  StreamSubscription<bool>? _serviceSub;

  LocationService get _svc => ref.read(locationServiceProvider);

  @override
  LocationSnapshot build() {
    ref.onDispose(_cancel);
    ref.listen(mapVisibleProvider, (_, __) => _sync());
    return const LocationSnapshot();
  }

  /// The locate button's single action.
  Future<void> onLocateTapped() async {
    if (!state.active) {
      final s = await _svc.request();
      state = state.copyWith(status: s);
      switch (s) {
        case LocationStatus.granted:
          state = state.copyWith(active: true, following: true);
          _sync();
        case LocationStatus.deniedForever:
          await _svc.openAppSettings();
        case LocationStatus.serviceOff:
          await _svc.openLocationSettings();
        case LocationStatus.denied:
        case LocationStatus.unknown:
          break; // stay inactive; tap again re-prompts
      }
      return;
    }
    state = state.copyWith(following: !state.following); // toggle follow only
  }

  /// A deliberate user map-pan exits follow but keeps the dot (§P1-2).
  void onUserPan() {
    if (state.following) state = state.copyWith(following: false);
  }

  void _sync() {
    final wantStream = state.active && ref.read(mapVisibleProvider);
    if (wantStream && _sub == null) {
      _sub = _svc.watch().listen(_onFix, onError: _onFailure);
      _serviceSub = _svc.serviceEnabledChanges().listen((enabled) {
        if (!enabled) _onFailure('service off');
      });
    } else if (!wantStream) {
      _cancel();
      if (!ref.read(mapVisibleProvider) && state.following) {
        state = state.copyWith(following: false); // hidden ⇒ drop follow
      }
    }
  }

  void _onFix(UserLocationFix fix) => state = state.copyWith(fix: fix);

  void _onFailure(Object _) {
    _cancel();
    state = state.copyWith(
        active: false,
        following: false,
        clearFix: true,
        status: LocationStatus.serviceOff);
  }

  void _cancel() {
    _sub?.cancel();
    _sub = null;
    _serviceSub?.cancel();
    _serviceSub = null;
  }
}
```

The test overrides `locationServiceProvider` with the fake, so the `throw` default never fires in tests; `main` overrides it with `GeolocatorLocationService` (Task 9).

- [ ] **Step 4: Run to verify it passes** — Run: `flutter test test/unit/location_controller_test.dart && flutter analyze` — Expected: PASS; clean.
- [ ] **Step 5: Commit**
```bash
git add lib/services/location_providers.dart test/unit/location_controller_test.dart
git commit -m "feat(map): LocationController — decoupled active/follow/visible state (Phase A)"
```

---

## Task 6: `UserLocationCircle` + `UserLocationDot` (StatelessWidget layers, correct order, low-accuracy)

**Files:** Create `lib/widgets/user_location_layer.dart`, `test/widget/user_location_layer_test.dart`.

**Interfaces:** two `StatelessWidget`s — `UserLocationCircle({required UserLocationFix fix})` (renders a `CircleLayer`, or an empty `SizedBox` when `fix.isLowAccuracy`) and `UserLocationDot({required UserLocationFix fix})` (renders a `MarkerLayer`). The map screen places the circle below venue pins and the dot above (spec §5.5). Both are flutter_map children — the same pattern as the app's existing `DarkTileLayer` (a `StatelessWidget` returning a `TileLayer`), so they read theme colour from `context.aon` in `build` — **no hardcoded hex, no nullable-context hack** (global constraint: `context.aon` colours only).

- [ ] **Step 1: Write the failing test** — the widgets go straight into `FlutterMap.children` (flutter_map spreads children into a `Stack`, so a `StatelessWidget` that returns a layer works — exactly how `DarkTileLayer` is used today). No `AonTheme` is installed in the harness on purpose: `context.aon` falls back to `AonPalette.dark`, proving the widgets need no theme wiring to render:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/models/user_location_fix.dart';
import 'package:aon2026/widgets/map_config.dart';
import 'package:aon2026/widgets/user_location_layer.dart';

Widget _map(List<Widget> layers) => MaterialApp(
      home: Scaffold(
        body: FlutterMap(
          options: const MapOptions(initialCenter: MapConfig.campusCentre),
          children: [const _EmptyTiles(), ...layers],
        ),
      ),
    );

class _EmptyTiles extends StatelessWidget {
  const _EmptyTiles();
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void main() {
  testWidgets('normal fix renders a CircleLayer + a MarkerLayer', (t) async {
    final fix = UserLocationFix(
        position: MapConfig.campusCentre, accuracyMeters: 10);
    await t.pumpWidget(_map([
      UserLocationCircle(fix: fix),
      UserLocationDot(fix: fix),
    ]));
    expect(find.byType(CircleLayer), findsOneWidget);
    expect(find.byType(MarkerLayer), findsOneWidget);
    expect(t.takeException(), isNull); // context.aon fell back cleanly
  });

  testWidgets('low-accuracy fix omits the CircleLayer', (t) async {
    final fix = UserLocationFix(
        position: MapConfig.campusCentre, accuracyMeters: 500);
    await t.pumpWidget(_map([
      UserLocationCircle(fix: fix),
      UserLocationDot(fix: fix),
    ]));
    expect(find.byType(CircleLayer), findsNothing);
    expect(find.byType(MarkerLayer), findsOneWidget); // dot still shows
  });
}
```

- [ ] **Step 2: Run to verify it fails** — FAIL (undefined).

- [ ] **Step 3: Implement** — `lib/widgets/user_location_layer.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/models/user_location_fix.dart';

/// Accuracy circle (metre radius) that sits UNDER the venue pins (spec §5.5).
/// Renders nothing for a low-accuracy fix so it never paints a suburb-sized
/// blob (spec §5.1). A StatelessWidget wrapping a flutter_map layer — the same
/// pattern as [DarkTileLayer] — so colour comes from `context.aon`, not a hex.
class UserLocationCircle extends StatelessWidget {
  const UserLocationCircle({required this.fix, super.key});
  final UserLocationFix fix;

  @override
  Widget build(BuildContext context) {
    if (fix.isLowAccuracy) return const SizedBox.shrink();
    final accent = context.aon.accent;
    return CircleLayer(circles: [
      CircleMarker(
        point: fix.position,
        radius: fix.accuracyMeters,
        useRadiusInMeter: true,
        color: accent.withValues(alpha: 0.12),
        borderColor: accent.withValues(alpha: 0.4),
        borderStrokeWidth: 1,
      ),
    ]);
  }
}

/// The "you are here" dot — an accent dot on a white ring — ON TOP of the pins.
class UserLocationDot extends StatelessWidget {
  const UserLocationDot({required this.fix, super.key});
  final UserLocationFix fix;

  @override
  Widget build(BuildContext context) => MarkerLayer(markers: [
        Marker(
          point: fix.position,
          width: 22,
          height: 22,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(blurRadius: 3, color: Colors.black26)],
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: DecoratedBox(
                decoration: BoxDecoration(
                    color: context.aon.accent, shape: BoxShape.circle),
              ),
            ),
          ),
        ),
      ]);
}
```

- [ ] **Step 4: Run to verify it passes** — PASS.
- [ ] **Step 5: Commit**
```bash
git add lib/widgets/user_location_layer.dart test/widget/user_location_layer_test.dart
git commit -m "feat(map): user-location layers (circle + dot) as themed StatelessWidgets (Phase A)"
```

---

## Task 7: Localised strings (EN + FA)

**Files:** Modify `lib/l10n/app_en.arb`, `lib/l10n/app_fa.arb`; regenerate. **Do this before the LocateButton (Task 8) so the button references real `l.locate*` getters — never a hardcoded string to swap later.**

- [ ] **Step 1: Add keys to `app_en.arb`** (each with a `@`-description, matching the file's style):
```json
  "locateShow": "Show my location",
  "@locateShow": { "description": "Map locate button, inactive state" },
  "locateFollow": "Follow my location",
  "@locateFollow": { "description": "Map locate button, active but not following" },
  "locateStopFollowing": "Stop following my location",
  "@locateStopFollowing": { "description": "Map locate button, following" },
  "locateUnavailable": "Location unavailable",
  "@locateUnavailable": { "description": "Map locate button, permission denied" },
  "locateServiceOff": "Turn on Location Services",
  "@locateServiceOff": { "description": "Map locate button, device location services off" },
  "mapOffCampus": "You're about {km} km from campus",
  "@mapOffCampus": { "description": "Banner when the user is outside the campus radius", "placeholders": { "km": { "type": "String" } } },
```

- [ ] **Step 2: Add the same keys to `app_fa.arb`** (Persian; flagged for a translator, but present so the build doesn't fail):
```json
  "locateShow": "موقعیت من",
  "locateFollow": "دنبال‌کردن موقعیت من",
  "locateStopFollowing": "توقف دنبال‌کردن موقعیت",
  "locateUnavailable": "موقعیت در دسترس نیست",
  "locateServiceOff": "روشن‌کردن سرویس موقعیت",
  "mapOffCampus": "حدود {km} کیلومتر با پردیس فاصله دارید",
```

- [ ] **Step 3: Regenerate + verify** — Run: `flutter gen-l10n && flutter analyze` — Expected: `AonL10n.of(context).locateShow` etc. exist; no untranslated-key failure; analyze clean. (If `.locate*` getters are missing, the arb edit or gen-l10n failed — fix before proceeding.)

- [ ] **Step 4: Commit**
```bash
git add lib/l10n/app_en.arb lib/l10n/app_fa.arb lib/l10n/generated/
git commit -m "feat(map): l10n strings for locate control + off-campus banner (EN/FA) (Phase A)"
```

---

## Task 8: `LocateButton` (state-driven, per-state semantics)

**Files:** Create `lib/widgets/locate_button.dart`, `test/widget/locate_button_test.dart`. Modify `lib/widgets/map_control_island.dart` to host it.

**Interfaces:** `LocateButton` (`ConsumerWidget`) reads `locationControllerProvider`, renders an `IconButton` with per-state icon, wrapped in an explicit `Semantics(button: true, label: …, excludeSemantics: true)` so **exactly one** node carries the l10n label (Task 7) — a `tooltip`-as-label is unreliable for `find.bySemanticsLabel`. Calls `onLocateTapped`. `MapControlIsland` gains a `Widget locateButton` slot replacing `onRecenter`.

- [ ] **Step 1: Write the failing test** — `test/widget/locate_button_test.dart` (one findable labelled node per state; the l10n keys already exist from Task 7):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/services/location_service.dart';
import 'package:aon2026/services/location_providers.dart';
import 'package:aon2026/widgets/locate_button.dart';

Widget _host(LocationSnapshot snap) => ProviderScope(
      overrides: [
        locationControllerProvider.overrideWith(() => _StubController(snap)),
      ],
      child: MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: const Scaffold(body: LocateButton()),
      ),
    );

class _StubController extends LocationController {
  _StubController(this._snap);
  final LocationSnapshot _snap;
  @override
  LocationSnapshot build() => _snap;
}

void main() {
  testWidgets('inactive -> "Show my location"', (t) async {
    await t.pumpWidget(_host(const LocationSnapshot()));
    expect(find.bySemanticsLabel('Show my location'), findsOneWidget);
  });
  testWidgets('following -> "Stop following my location"', (t) async {
    await t.pumpWidget(
        _host(const LocationSnapshot(active: true, following: true)));
    expect(find.bySemanticsLabel('Stop following my location'), findsOneWidget);
  });
  testWidgets('denied -> "Location unavailable"', (t) async {
    await t.pumpWidget(_host(const LocationSnapshot(status: LocationStatus.denied)));
    expect(find.bySemanticsLabel('Location unavailable'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify it fails** — FAIL.

- [ ] **Step 3: Implement** — `lib/widgets/locate_button.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/services/location_service.dart';
import 'package:aon2026/services/location_providers.dart';

class LocateButton extends ConsumerWidget {
  const LocateButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AonL10n.of(context);
    final s = ref.watch(locationControllerProvider);

    final (IconData icon, String label, Color color) = switch (s) {
      LocationSnapshot(status: LocationStatus.serviceOff) => (
          Icons.location_disabled_rounded, l.locateServiceOff, context.aon.contentTertiary),
      LocationSnapshot(status: LocationStatus.denied) ||
      LocationSnapshot(status: LocationStatus.deniedForever) => (
          Icons.location_disabled_rounded, l.locateUnavailable, context.aon.contentTertiary),
      LocationSnapshot(active: true, following: true) => (
          Icons.near_me_rounded, l.locateStopFollowing, context.aon.accent),
      LocationSnapshot(active: true) => (
          Icons.near_me_outlined, l.locateFollow, context.aon.accent),
      _ => (Icons.my_location_rounded, l.locateShow, context.aon.contentSecondary),
    };

    // One explicit semantics node with the label — excludeSemantics drops the
    // IconButton's own (tooltip-derived) node so bySemanticsLabel finds exactly
    // one. onPressed stays wired in every state (denied/serviceOff re-prompt or
    // open settings via onLocateTapped).
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: IconButton(
        icon: Icon(icon, color: color),
        onPressed: () =>
            ref.read(locationControllerProvider.notifier).onLocateTapped(),
      ),
    );
  }
}
```

Modify `map_control_island.dart`: replace the `onRecenter` field + its `_button(... Icons.my_location_rounded ... onRecenter)` with a `final Widget locateButton;` field rendered in that slot. (Keep zoom in/out unchanged.)

- [ ] **Step 4: Run to verify it passes** — Run: `flutter test test/widget/locate_button_test.dart` — Expected: PASS.
- [ ] **Step 5: Commit**
```bash
git add lib/widgets/locate_button.dart lib/widgets/map_control_island.dart test/widget/locate_button_test.dart
git commit -m "feat(map): state-driven locate button with explicit per-state semantics (Phase A)"
```

---

## Task 9: Wire into the map screen

**Files:** Modify `lib/main.dart` (override `locationServiceProvider`), `lib/screens/map_screen.dart`; Create `test/widget/map_location_wiring_test.dart`.

- [ ] **Step 1: Override the service in `main.dart`** — add to the root `ProviderScope` overrides:
```dart
import 'package:aon2026/services/location_providers.dart';
import 'package:aon2026/services/location_service.dart';
// ...
  overrides: [
    // ...existing (passportSnapshot, passportStore)...
    locationServiceProvider.overrideWithValue(GeolocatorLocationService()),
  ],
```

- [ ] **Step 2: Write the failing wiring test** — `test/widget/map_location_wiring_test.dart`. Four cases: near fix ⇒ circle+dot, no banner; far fix ⇒ off-campus banner; user pan ⇒ follow cleared; **offstage (TickerMode off) ⇒ `mapVisible` false** (the battery-pause proof, so it isn't only runtime-verified). Uses the shared fake and an `UncontrolledProviderScope` for direct container access:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/models/user_location_fix.dart';
import 'package:aon2026/services/location_service.dart';
import 'package:aon2026/services/location_providers.dart';
import 'package:aon2026/widgets/map_config.dart';
import 'package:aon2026/screens/map_screen.dart';
import '../support/fake_location_service.dart';

ProviderContainer _container(FakeLocationService svc, {bool visible = true}) {
  final c = ProviderContainer(
      overrides: [locationServiceProvider.overrideWithValue(svc)]);
  addTearDown(c.dispose);
  c.read(mapVisibleProvider.notifier).state = visible;
  return c;
}

Widget _app(ProviderContainer c, {Widget home = const MapScreen()}) =>
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: home,
      ),
    );

UserLocationFix _near() =>
    UserLocationFix(position: MapConfig.campusCentre, accuracyMeters: 10);
UserLocationFix _far() => UserLocationFix(
    position: LatLng(MapConfig.campusCentre.latitude + 0.05,
        MapConfig.campusCentre.longitude),
    accuracyMeters: 10);

void main() {
  testWidgets('near fix -> circle + dot, no off-campus banner', (t) async {
    final svc = FakeLocationService();
    final c = _container(svc);
    await t.pumpWidget(_app(c));
    await c.read(locationControllerProvider.notifier).onLocateTapped();
    svc.emit(_near());
    await t.pump(); // deliver stream event
    await t.pump(); // rebuild
    expect(find.byType(CircleLayer), findsOneWidget);
    expect(find.byType(MarkerLayer), findsWidgets); // venue pins + user dot
    expect(find.textContaining('from campus'), findsNothing);
  });

  testWidgets('far fix -> off-campus banner', (t) async {
    final svc = FakeLocationService();
    final c = _container(svc);
    await t.pumpWidget(_app(c));
    await c.read(locationControllerProvider.notifier).onLocateTapped();
    svc.emit(_far());
    await t.pump();
    await t.pump();
    expect(find.textContaining('from campus'), findsOneWidget);
  });

  testWidgets('user pan clears follow', (t) async {
    final svc = FakeLocationService();
    final c = _container(svc);
    await t.pumpWidget(_app(c));
    await c.read(locationControllerProvider.notifier).onLocateTapped();
    expect(c.read(locationControllerProvider).following, isTrue);
    await t.drag(find.byType(FlutterMap), const Offset(-60, 0));
    await t.pump();
    expect(c.read(locationControllerProvider).following, isFalse);
  });

  // The battery-pause mechanism, proven pre-runtime: an offstage IndexedStack
  // child has TickerMode disabled — the same primitive StatefulShellRoute.
  // indexedStack uses — so MapScreen must push mapVisible=false. If this fails,
  // TickerMode is the wrong signal and Task 10's fallback (navigationShell
  // index) is required.
  testWidgets('offstage (TickerMode off) -> mapVisible false', (t) async {
    final svc = FakeLocationService();
    final c = _container(svc, visible: true);
    await t.pumpWidget(_app(c,
        home: const IndexedStack(
          index: 1, // MapScreen (index 0) is offstage
          children: [MapScreen(), SizedBox.shrink()],
        )));
    await t.pump(); // run didChangeDependencies' post-frame callback
    await t.pump();
    expect(c.read(mapVisibleProvider), isFalse);
  });
}
```

(If flutter_map's gesture arena doesn't fire `onPositionChanged(hasGesture:true)` under `t.drag` in the headless harness, the pan→follow wiring is a reviewed one-liner and the Task 5 unit test already proves `onUserPan`; keep the drag test but the executor may mark it a known-harness-limitation with a receipt rather than weakening it.)

- [ ] **Step 3: Run to verify it fails** — FAIL (no layer/banner/pan wiring yet).

- [ ] **Step 4: Wire `map_screen.dart`:**
  1. **Import** the model, providers, layer, locate button.
  2. **mapVisible via TickerMode** — in `_MapScreenState`, override `didChangeDependencies` to push visibility:
     ```dart
     @override
     void didChangeDependencies() {
       super.didChangeDependencies();
       // Offstage branches of the IndexedStack shell have TickerMode disabled.
       final visible = TickerMode.of(context) && _mode == MapMode.campusMap;
       WidgetsBinding.instance.addPostFrameCallback((_) {
         if (mounted) ref.read(mapVisibleProvider.notifier).state = visible;
       });
     }
     ```
     Also set it in `build` when `_mode` changes (panorama hides the map). **If a widget test proves TickerMode does not toggle for the go_router shell, fall back to reading `navigationShell` — but verify first (Task 10 records which mechanism holds).**
  3. **onPositionChanged** on `MapOptions`:
     ```dart
     onPositionChanged: (camera, hasGesture) {
       if (hasGesture) ref.read(locationControllerProvider.notifier).onUserPan();
     },
     ```
  4. **Layers in order** — watch the snapshot and insert the location layers at the right depths (the new `UserLocationCircle`/`UserLocationDot` StatelessWidgets read their own colour from `context.aon`, so no context is threaded):
     ```dart
     final loc = ref.watch(locationControllerProvider);
     // children:
     const DarkTileLayer(),
     if (loc.active && loc.fix != null) UserLocationCircle(fix: loc.fix!),
     MarkerLayer(markers: markers),
     if (loc.active && loc.fix != null) UserLocationDot(fix: loc.fix!),
     ```
  5. **Follow recenter** — a `ref.listen` that moves the camera when following near-campus. **Call it unconditionally at the very top of `build` (before any early return or `_mode` branch)** — Riverpod requires `ref.listen` to run on every build, so it must not sit inside an `if`/mode branch:
     ```dart
     ref.listen(locationControllerProvider, (_, s) {
       if (s.following && s.fix != null && MapConfig.isNearCampus(s.fix!.position)) {
         _controller.move(s.fix!.position, _controller.camera.zoom);
       }
     });
     ```
     (Programmatic `move` fires `onPositionChanged` with `hasGesture: false`, so it does not self-cancel follow.)
  6. **Locate button** — pass `locateButton: const LocateButton()` to `MapControlIsland` (replacing `onRecenter`).
  7. **Off-campus banner** — a `Positioned` localized note shown when `loc.active && loc.fix != null && !MapConfig.isNearCampus(loc.fix!.position)`:
     ```dart
     if (loc.active && loc.fix != null && !MapConfig.isNearCampus(loc.fix!.position))
       Positioned(top: ..., left: ..., right: ..., child: _OffCampusBanner(
         km: (MapConfig.distanceFromCampusMeters(loc.fix!.position) / 1000).toStringAsFixed(1)));
     ```
     where `_OffCampusBanner` renders `l.mapOffCampus(km)` in a `context.aon.surface` pill.

- [ ] **Step 5: Run tests + web build** — Run: `flutter test test/widget/map_location_wiring_test.dart && flutter analyze && flutter build web` — Expected: PASS; clean; web green.

- [ ] **Step 6: Commit**
```bash
git add lib/main.dart lib/screens/map_screen.dart test/widget/map_location_wiring_test.dart
git commit -m "feat(map): wire live location + follow + off-campus banner into the map (Phase A)"
```

---

## Task 10: Verification gate + on-device run

**Files:** Create `docs/superpowers/specs/2026-08-11-aon-map-live-location-phaseA-design.md` closeout section (append).

- [ ] **Step 1: Full static + test** — Run: `flutter analyze && flutter test` — Expected: clean; suite = Task 0 baseline + new; no regressions.
- [ ] **Step 2: Builds** — Run: `flutter build web`, `flutter build ios --simulator --debug`, `flutter build apk --debug` — Expected: all succeed. **Web is the load-bearing one** (the reason flutter_compass was cut).
- [ ] **Step 3: iOS runtime location pass** (simulator: Features ▸ Location ▸ Custom/Apple ⇒ can feed a fix). Record PASS/FAIL:
```text
[ ] open Map → NO permission prompt (lazy)
[ ] tap locate → permission prompt appears
[ ] grant → dot + accuracy circle appear; map recenters (following)
[ ] pan the map → follow stops, dot stays live (updates as sim location moves)
[ ] tap locate again → follows again
[ ] set the sim location far from campus → off-campus banner; map does NOT fly away
[ ] switch to another tab and back → GPS paused while away; dot resumes on return
[ ] deny permission (reset) → locate shows "unavailable"; map still fully usable
[ ] confirm which visibility mechanism held (TickerMode vs shell index) — record it
```
- [ ] **Step 4: Closeout** — append to the spec: resolved geolocator version, web-build result, the visibility mechanism that held, and the runtime checklist result.
- [ ] **Step 5: Final re-gate** — Run: `flutter analyze && flutter test && git diff --check && git status --short`, then a hostile read of `git diff main...HEAD`.
- [ ] **Step 6: Commit**
```bash
git add docs/superpowers/specs/2026-08-11-aon-map-live-location-phaseA-design.md
git commit -m "docs(map): Phase A verification + runtime closeout"
```

---

## Self-Review

**1. Spec coverage**

| Spec § | Task |
|---|---|
| §4 geolocator only + platform config | 1 |
| §5.1 validated model + low-accuracy | 2, 6 |
| §5.4 canonical campus distance + radius | 3 |
| §5.2 service seam + web guards | 4 |
| §5.2.1 web attempt-first | 4 (status/request), 10 (runtime) |
| §5.3 three decoupled providers | 5 |
| §5.6 locate control states + semantics | 8 |
| §5.5 layer order + low-accuracy omit | 6, 9 |
| §5.7 pan-exits-follow, off-campus, runtime failure | 5, 9 |
| §6 lifecycle (`active && mapVisible`) | 5, 9 |
| §8 iOS foreground-only / Android perms | 1 |
| §D2 lazy permission | 5, 9, 10 |
| §D5 instant recenter | 9 |
| l10n EN/FA | 7 |
| §9 tests | every task + 10 |

**2. Placeholder scan** — clean. Task 9 Step 2's wiring test is now written in full (four cases incl. the TickerMode/mapVisible proof). Every other step carries complete code; no TBD/TODO/"add error handling"/described-not-written steps remain.

**3. Type consistency** — `LocationStatus`, `LocationService` (`status`/`request`/`watch`/`serviceEnabledChanges`/`openAppSettings`/`openLocationSettings`), `UserLocationFix`(`position`/`accuracyMeters`/`isLowAccuracy`), `LocationSnapshot`(`status`/`fix`/`active`/`following`), `locationServiceProvider`/`mapVisibleProvider`/`locationControllerProvider`, `MapConfig.{distanceFromCampusMeters,isNearCampus,locationCampusRadiusMeters}`, `UserLocationCircle`/`UserLocationDot` (both `StatelessWidget`, `fix:` arg), `LocateButton`, `l.locate*`/`l.mapOffCampus` — consistent across tasks. Shared fake lives at `test/support/fake_location_service.dart` (imported by Tasks 4, 5, 9).

---

## Notes for the executor

- **The `mapVisible` mechanism is the one real unknown.** The plan uses `TickerMode.of(context)` (idiomatic for offstage IndexedStack children). **Verify it toggles under `StatefulShellRoute.indexedStack` with a widget test before relying on it**; if it doesn't, drive `mapVisibleProvider` from the `AppShell`'s `navigationShell.currentIndex` instead (spec §6's stated approach). Record which held (Task 10).
- **Never treat web `checkPermission()==denied` as authoritative** (§5.2.1) — the web path attempts acquisition.
- **Web build is a hard gate** (Task 1 Step 2, Task 10 Step 2) — the entire reason heading was cut.
- Programmatic `MapController.move` fires `onPositionChanged` with `hasGesture:false`; only `hasGesture:true` exits follow — do not cancel follow on a follow-driven move.
- **Off-campus, the dot is off-screen by design.** The existing `MapOptions.cameraConstraint: CameraConstraint.contain(bounds: MapConfig.campusBounds)` keeps the camera framed on campus, so an off-campus fix never scrolls into view — the localized banner is the *sole* off-campus feedback. This is intended (spec §5.4); don't "fix" it by loosening the camera constraint.
- Never weaken an existing test to make Phase A pass.
```
