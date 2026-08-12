# Map Parity Phase B — "Point me there" heading Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A "Point me there" screen, launched from a venue/parking sheet, showing a large arrow that points toward that place and rotates live as the visitor turns, with live distance — tilt-compensated, declination-corrected, and honestly mobile-only with a bearing+distance fallback where there's no compass.

**Architecture:** Four decoupled units mirroring Phase A's seams — a pure `heading_math` (tilt-compensation + circular smoothing), a pure `bearing_math` (geo via `latlong2`), a fakeable `HeadingService` over `sensors_plus`, and a `PointMeController` that fuses Phase A's live location + heading + a fixed campus declination + the target venue into a `PointMeState`. The `PointMeScreen` renders the arrow / near-target / fallback / no-fix states.

**Tech Stack:** Flutter 3.44.7, Riverpod 3.4.2 (plain `Notifier` + `NotifierProvider` only — the manual `autoDispose.family` API is avoided as unverified for 3.4), `latlong2` 0.9.1, **one new dep `sensors_plus` (7.x)**. l10n (EN+FA), Palette (`context.aon`).

## Global Constraints

- **One new dependency only: `sensors_plus`.** No `flutter_compass`.
- **Web build is a hard gate, checked the instant the dep lands** — `flutter build web` runs immediately after `flutter pub add sensors_plus` (Task 1) and STOPS on failure. Magnetometer is classified `unsupported` at the platform edge (`kIsWeb`); a live compass is inherently mobile-only (no browser Magnetometer API).
- **Tilt-compensated heading is in-scope** (accelerometer + magnetometer, Android rotation-matrix method) — raw `atan2(x,y)` alone is not shipped.
- **Pure math takes plain value types** (`Vector3`), never `sensors_plus` event types — so `heading_math`/`bearing_math` run in VM-only unit tests.
- **Stream fusion is combine-latest** (emit on the magnetometer tick using the latest accelerometer sample), never a 1:1 `zip`.
- **Declination is preflight-verified** (WMM2025 @ campus centre @ 2026-09-19) and stored as `MapConfig.campusMagneticDeclinationDegrees`; `true = magnetic + east-positive declination`.
- **`context.aon` colours only** (the arrow is a themed accent shape, no hex).
- **All new strings** go in **both** `lib/l10n/app_en.arb` and `lib/l10n/app_fa.arb` (build fails if FA misses a key); cardinal + side words are l10n, not literals.
- **Every new surface passes 320×568 / 2.0**; **reduced-motion-safe** (the arrow reorients as essential info; only decorative easing/pulse is dropped).
- **No invented coordinates** — an unknown/deleted `venueId` shows a safe "can't find that place" + Back, never a fall-back to campus centre.
- **Sensor lifecycle:** motion streams run only while `PointMeScreen` is visible AND the app is foregrounded.
- **a11y:** the arrow's label is not a spammy `liveRegion`; it updates silently and any announcement is throttled to a meaningful side change.
- **Per-task gate:** `flutter analyze && flutter test`; web build re-verified where the dep is touched. Never weaken an existing test.

---

## File Structure

**Create:** `lib/widgets/bearing_math.dart`, `lib/services/heading_math.dart`, `lib/services/heading_service.dart`, `lib/services/point_me_controller.dart`, `lib/screens/point_me_screen.dart`, `test/support/fake_heading_service.dart`, and mirrored tests.
**Modify:** `pubspec.yaml`, `lib/widgets/map_config.dart` (declination + near-target constants), `lib/app/router/app_router.dart` (route), `lib/screens/map_screen.dart` (`VenueSheet`/`ParkingSheet` "Point me there" entry), `lib/l10n/app_en.arb`, `lib/l10n/app_fa.arb`.

**Task order:** 0 preflight + WMM declination → 1 dep + web gate → 2 bearing_math + MapConfig constants → 3 heading_math → 4 HeadingService + fake → 5 PointMeController → **6 l10n → 7 PointMeScreen** (screen needs the l10n keys) → 8 sheet entry + route → 9 verification.

---

## Task 0: Preflight & baseline + WMM2025 declination receipt

- [ ] **Step 1: Branch + clean tree** — Run:
```bash
git status --short          # expect empty
git rev-parse HEAD          # record base SHA
git branch --show-current   # expect feature/map-heading-phaseB
```

- [ ] **Step 2: Baseline** — Run: `flutter analyze && flutter test` — Expected: clean; **record the passing count** (Phase A left it at 491).

- [ ] **Step 3: Baseline builds** — Run: `flutter build web && flutter build apk --debug` — Expected: both succeed (isolates any later web break to `sensors_plus`).

- [ ] **Step 4: Compute the campus magnetic declination (WMM2025).** Query NOAA NCEI for campus centre on event day. Run:
```bash
curl -s "https://www.ngdc.noaa.gov/geomag-web/calculators/calculateDeclination?lat1=-33.7737&lon1=151.1134&resultFormat=json&model=WMM2025&startYear=2026&startMonth=9&startDay=19" | python3 -m json.tool
```
Read the `declination` field (degrees; **east-positive**). If the endpoint requires an API key or returns an error, use the interactive calculator at `https://www.ngdc.noaa.gov/geomag/calculators/magcalc.shtml` (same lat/lon/date, model WMM2025) and read the declination there. **Record the receipt** verbatim for Task 2 and the closeout:
```text
model:        WMM2025
coordinate:   -33.7737, 151.1134
date:         2026-09-19
declination:  <value>° E     ← the number to hardcode in Task 2
source:       <exact URL> (retrieved <date>)
```
(No commit yet — the value lands in `MapConfig` in Task 2.)

- [ ] **Step 5: No commit.**

---

## Task 1: Add `sensors_plus` + web-build isolation gate

**Files:** Modify `pubspec.yaml`.

- [ ] **Step 1: Add the dependency, pinned** — Run: `flutter pub add sensors_plus` — Expected: resolves 7.x; `pub get` OK. (No native permission config — motion sensors need none on iOS/Android.)

- [ ] **Step 2: Verify the web build STILL compiles** (the whole reason we did not use `flutter_compass`) — Run: `flutter build web` — Expected: SUCCESS. **If it fails, STOP** — `sensors_plus` web support is a hard requirement; do not proceed. This isolates any web break to the dependency before any feature code exists.

- [ ] **Step 3: Analyze + commit**
```bash
flutter analyze
git add pubspec.yaml pubspec.lock
git commit -m "feat(map): add sensors_plus for heading (web build verified) (Phase B)"
```

---

## Task 2: `bearing_math` (pure geo) + `MapConfig` constants

**Files:** Create `lib/widgets/bearing_math.dart`, `test/unit/bearing_math_test.dart`. Modify `lib/widgets/map_config.dart`.

**Interfaces:** Produces `enum Cardinal { n, ne, e, se, s, sw, w, nw }`; `trueBearingDegrees(LatLng,LatLng)→double [0,360)`; `relativeAngleDegrees(double bearing,double heading)→double [-180,180]`; `distanceBetweenMeters(LatLng,LatLng)→double`; `cardinalFor(double trueBearing)→Cardinal`. And `MapConfig.campusMagneticDeclinationDegrees` (double, from Task 0) + `MapConfig.pointMeNearTargetMeters` (double, 20).

- [ ] **Step 1: Write the failing test** — `test/unit/bearing_math_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:aon2026/widgets/bearing_math.dart';

void main() {
  const origin = LatLng(0, 0);

  test('true bearing is normalized to [0,360)', () {
    // Due north and due south are unambiguous references.
    expect(trueBearingDegrees(origin, const LatLng(1, 0)), closeTo(0, 0.5));
    expect(trueBearingDegrees(origin, const LatLng(-1, 0)), closeTo(180, 0.5));
    // Due east is ~90; must be positive (not -270 or negative).
    final east = trueBearingDegrees(origin, const LatLng(0, 1));
    expect(east, closeTo(90, 0.5));
    expect(east, greaterThanOrEqualTo(0));
  });

  test('relative angle is the signed shortest delta, wrap-safe', () {
    expect(relativeAngleDegrees(10, 350), closeTo(20, 1e-9)); // 359->1 style wrap
    expect(relativeAngleDegrees(350, 10), closeTo(-20, 1e-9));
    expect(relativeAngleDegrees(90, 0), closeTo(90, 1e-9)); // target to the right
    expect(relativeAngleDegrees(0, 0), 0);
    expect(relativeAngleDegrees(180, 0).abs(), closeTo(180, 1e-9));
  });

  test('distance between two points in metres', () {
    final d = distanceBetweenMeters(origin, const LatLng(0, 0.001));
    expect(d, closeTo(111, 3)); // ~111 m per 0.001 deg lon at equator
  });

  test('cardinal buckets', () {
    expect(cardinalFor(0), Cardinal.n);
    expect(cardinalFor(45), Cardinal.ne);
    expect(cardinalFor(90), Cardinal.e);
    expect(cardinalFor(359), Cardinal.n); // wraps back to N
  });
}
```

- [ ] **Step 2: Run to verify it fails** — `flutter test test/unit/bearing_math_test.dart` → FAIL (undefined).

- [ ] **Step 3: Implement** — `lib/widgets/bearing_math.dart`:
```dart
import 'package:latlong2/latlong.dart';

/// 8-point compass bucket. The UI localizes it (EN/FA) — this stays pure.
enum Cardinal { n, ne, e, se, s, sw, w, nw }

const Distance _distance = Distance();

/// True-north bearing from [from] to [to], normalized to [0,360).
/// `Distance.bearing` returns atan2 in [-180,180]; the normalize wrap is required.
double trueBearingDegrees(LatLng from, LatLng to) =>
    normalizeBearing(_distance.bearing(from, to));

/// Signed shortest delta `bearing - heading`, in [-180,180]. Positive = target
/// is clockwise (to the right) of where the device points. Wrap-safe (359↔1).
double relativeAngleDegrees(double bearing, double heading) =>
    ((bearing - heading + 540) % 360) - 180;

double distanceBetweenMeters(LatLng from, LatLng to) =>
    _distance.as(LengthUnit.Meter, from, to);

/// Nearest 8-point compass bucket for a true bearing in [0,360).
Cardinal cardinalFor(double trueBearing) {
  final i = ((normalizeBearing(trueBearing) + 22.5) ~/ 45) % 8;
  return Cardinal.values[i];
}
```

- [ ] **Step 4: Run to verify it passes** — PASS.

- [ ] **Step 5: Add MapConfig constants** — in `lib/widgets/map_config.dart`, after the Phase A location block:
```dart
  /// Magnetic declination at campus (east-positive), so magnetic heading + this
  /// = true heading. Preflight-verified (see Task 0 receipt):
  ///   WMM2025 @ -33.7737,151.1134 @ 2026-09-19.
  static const double campusMagneticDeclinationDegrees = <VALUE FROM TASK 0>;

  /// Below this range the arrow twitches (accuracy > remaining distance) and a
  /// bearing is less useful — show the "you're basically there" state instead.
  static const double pointMeNearTargetMeters = 20;
```
Replace `<VALUE FROM TASK 0>` with the recorded declination number (e.g. `12.5`). Add a `test/unit/map_config_heading_test.dart` asserting the constant is finite and `pointMeNearTargetMeters == 20`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/widgets/map_config.dart';
void main() {
  test('heading constants present', () {
    expect(MapConfig.campusMagneticDeclinationDegrees.isFinite, isTrue);
    expect(MapConfig.pointMeNearTargetMeters, 20);
  });
}
```

- [ ] **Step 6: Run + commit**
```bash
flutter test test/unit/bearing_math_test.dart test/unit/map_config_heading_test.dart && flutter analyze
git add lib/widgets/bearing_math.dart lib/widgets/map_config.dart test/unit/bearing_math_test.dart test/unit/map_config_heading_test.dart
git commit -m "feat(map): pure bearing math + campus declination/near-target config (Phase B)"
```

---

## Task 3: `heading_math` (pure tilt-compensation + circular smoothing)

**Files:** Create `lib/services/heading_math.dart`, `test/unit/heading_math_test.dart`.

**Interfaces:** Produces `class Vector3 { final double x,y,z; }`; `double? tiltCompensatedHeadingDegrees(Vector3 mag, Vector3 accel)` (null if degenerate); `class CircularSmoother { CircularSmoother(double alpha); double add(double deg); }`.

- [ ] **Step 1: Write the failing test** — `test/unit/heading_math_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/services/heading_math.dart';

void main() {
  group('tiltCompensatedHeadingDegrees', () {
    // These absolute values are hand-derived from the Android algorithm below
    // (A=up, H=mag×A [east], M=A×H [north], azimuth=atan2(H.y,M.y)) for a flat
    // phone (accel=(0,0,9.8)). Verified: mag=(0,20,-40)→0°, mag=(-20,0,-40)→90°.
    test('flat phone, north field → ~0°', () {
      final h = tiltCompensatedHeadingDegrees(
          const Vector3(0, 20, -40), const Vector3(0, 0, 9.8))!;
      expect(h, closeTo(0, 5));
    });

    test('flat phone, east field → ~90°', () {
      final h = tiltCompensatedHeadingDegrees(
          const Vector3(-20, 0, -40), const Vector3(0, 0, 9.8))!;
      expect(h, closeTo(90, 5));
    });

    // Tilt-compensation is the whole point: rotate BOTH gravity and field by the
    // same 30° forward pitch (R_x(30°)) and the azimuth must stay ~0°.
    // R_x(30°)·(0,20,-40)=(0, 37.32, -24.64); R_x(30°)·(0,0,9.8)=(0, -4.9, 8.49).
    test('tilted phone reports the same azimuth as flat (~0°)', () {
      final tilted = tiltCompensatedHeadingDegrees(
          const Vector3(0, 37.32, -24.64), const Vector3(0, -4.9, 8.49))!;
      expect(tilted, closeTo(0, 6));
    });

    test('degenerate input (zero gravity) → null', () {
      expect(
          tiltCompensatedHeadingDegrees(
              const Vector3(1, 1, 1), const Vector3(0, 0, 0)),
          isNull);
    });
  });

  group('CircularSmoother', () {
    test('averages across the 359/1 wrap near 0, not 180', () {
      final s = CircularSmoother(0.5);
      s.add(359);
      final out = s.add(1);
      expect(out < 20 || out > 340, isTrue); // near 0, never ~180
    });
    test('converges to a steady input', () {
      final s = CircularSmoother(0.5);
      double out = 0;
      for (var i = 0; i < 20; i++) {
        out = s.add(123);
      }
      expect(out, closeTo(123, 1));
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails** — FAIL.

- [ ] **Step 3: Implement** — `lib/services/heading_math.dart`:
```dart
import 'dart:math' as math;

import 'package:latlong2/latlong.dart' show normalizeBearing;

/// A plain 3-axis sample. NOT `sensors_plus`'s event type — keeping this pure
/// lets the math run in VM-only unit tests. The service adapter maps events → this.
class Vector3 {
  const Vector3(this.x, this.y, this.z);
  final double x, y, z;
}

/// Tilt-compensated MAGNETIC heading in [0,360), or null if the inputs are
/// degenerate (free-fall, device at a magnetic pole, parallel vectors).
///
/// Implements Android `SensorManager.getRotationMatrix` + `getOrientation`:
/// A = normalize(gravity) [up]; H = mag × A [east]; if ‖H‖≈0 → null; normalize H;
/// M = A × H [north]; azimuth = atan2(H.y, M.y)  (== getOrientation's atan2(R[1],R[4])).
double? tiltCompensatedHeadingDegrees(Vector3 mag, Vector3 accel) {
  final ax = accel.x, ay = accel.y, az = accel.z;
  final normA = math.sqrt(ax * ax + ay * ay + az * az);
  if (normA < 1e-6) return null;
  final aX = ax / normA, aY = ay / normA, aZ = az / normA;

  // H = mag × A  (east)
  var hX = mag.y * aZ - mag.z * aY;
  var hY = mag.z * aX - mag.x * aZ;
  var hZ = mag.x * aY - mag.y * aX;
  final normH = math.sqrt(hX * hX + hY * hY + hZ * hZ);
  if (normH < 1e-6) return null; // degenerate: mag ∥ gravity
  hX /= normH;
  hY /= normH;
  hZ /= normH;

  // M = A × H  (north)
  final mY = aZ * hX - aX * hZ;

  final azimuthRad = math.atan2(hY, mY);
  return normalizeBearing(azimuthRad * 180 / math.pi);
}

/// Exponential low-pass over the unit circle, so 359° and 1° average near 0°.
class CircularSmoother {
  CircularSmoother(this.alpha);
  final double alpha;
  double _sin = 0, _cos = 0;
  bool _seeded = false;

  double add(double deg) {
    final r = deg * math.pi / 180;
    final s = math.sin(r), c = math.cos(r);
    if (!_seeded) {
      _sin = s;
      _cos = c;
      _seeded = true;
    } else {
      _sin = _sin + alpha * (s - _sin);
      _cos = _cos + alpha * (c - _cos);
    }
    return normalizeBearing(math.atan2(_sin, _cos) * 180 / math.pi);
  }
}
```

- [ ] **Step 4: Run to verify it passes** — PASS. The four expected values are hand-derived from the algorithm (verified in the gauntlet); if one is off it means the impl deviated from the Android cross-product order below — fix the algorithm to match, don't loosen the test.

- [ ] **Step 5: Commit**
```bash
git add lib/services/heading_math.dart test/unit/heading_math_test.dart
git commit -m "feat(map): pure tilt-compensated heading + circular smoother (Phase B)"
```

---

## Task 4: `HeadingService` seam + `SensorsHeadingService` + shared fake

**Files:** Create `lib/services/heading_service.dart`, `test/support/fake_heading_service.dart`, `test/unit/heading_service_fake_test.dart`.

**Interfaces:** `enum HeadingAvailability { acquiring, available, unavailable, unsupported }`; `class HeadingSample { HeadingAvailability availability; double? magneticHeadingDegrees; }`; `abstract interface class HeadingService { Stream<HeadingSample> watch(); }`; `SensorsHeadingService` (real); shared `FakeHeadingService`.

- [ ] **Step 1: Write the shared fake + a failing contract test.** `test/support/fake_heading_service.dart` (class only, no `main()`):
```dart
import 'dart:async';
import 'package:aon2026/services/heading_service.dart';

class FakeHeadingService implements HeadingService {
  final _c = StreamController<HeadingSample>.broadcast();
  void emit(HeadingSample s) => _c.add(s);
  void emitError(Object e) => _c.addError(e);
  @override
  Stream<HeadingSample> watch() => _c.stream;
}
```
`test/unit/heading_service_fake_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/services/heading_service.dart';
import '../support/fake_heading_service.dart';

void main() {
  test('fake streams samples', () async {
    final f = FakeHeadingService();
    final got = <HeadingSample>[];
    final sub = f.watch().listen(got.add);
    f.emit(const HeadingSample(
        availability: HeadingAvailability.available, magneticHeadingDegrees: 42));
    await Future<void>.delayed(Duration.zero);
    expect(got.single.availability, HeadingAvailability.available);
    expect(got.single.magneticHeadingDegrees, 42);
    await sub.cancel();
  });
}
```

- [ ] **Step 2: Run to verify it fails** — FAIL (`heading_service` undefined).

- [ ] **Step 3: Implement** — `lib/services/heading_service.dart`:
```dart
import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sensors_plus/sensors_plus.dart';

import 'package:aon2026/services/heading_math.dart';

enum HeadingAvailability { acquiring, available, unavailable, unsupported }

class HeadingSample {
  const HeadingSample({required this.availability, this.magneticHeadingDegrees});
  final HeadingAvailability availability;
  final double? magneticHeadingDegrees; // tilt-compensated magnetic, [0,360)
}

/// The sensor seam. Everything above is tested with a fake.
abstract interface class HeadingService {
  Stream<HeadingSample> watch();
}

/// Real adapter over sensors_plus. Fuses magnetometer + accelerometer with
/// combine-latest (emit on each magnetometer tick using the latest accel), applies
/// [tiltCompensatedHeadingDegrees], and smooths. Web has no Magnetometer API in
/// any browser, so it short-circuits to a single `unsupported` WITHOUT subscribing.
class SensorsHeadingService implements HeadingService {
  final _smoother = CircularSmoother(0.2);

  @override
  Stream<HeadingSample> watch() {
    if (kIsWeb) {
      return Stream<HeadingSample>.value(
          const HeadingSample(availability: HeadingAvailability.unsupported));
    }
    final controller = StreamController<HeadingSample>();
    Vector3? latestAccel;
    StreamSubscription? magSub, accSub;

    void startError(Object _) {
      controller.add(
          const HeadingSample(availability: HeadingAvailability.unavailable));
    }

    controller.onListen = () {
      controller.add(
          const HeadingSample(availability: HeadingAvailability.acquiring));
      accSub = accelerometerEventStream().listen(
        (e) => latestAccel = Vector3(e.x, e.y, e.z),
        onError: startError,
      );
      magSub = magnetometerEventStream().listen(
        (e) {
          final a = latestAccel;
          if (a == null) return; // wait for first accel sample
          final mag = tiltCompensatedHeadingDegrees(Vector3(e.x, e.y, e.z), a);
          if (mag == null) return; // degenerate; stay in current state
          controller.add(HeadingSample(
            availability: HeadingAvailability.available,
            magneticHeadingDegrees: _smoother.add(mag),
          ));
        },
        onError: startError,
      );
    };
    controller.onCancel = () async {
      await magSub?.cancel();
      await accSub?.cancel();
    };
    return controller.stream;
  }
}
```
(If `sensors_plus` 7.x names the streams `magnetometerEvents`/`accelerometerEvents` instead of the `…EventStream()` functions, use whichever the installed version exports — `…EventStream()` is the non-deprecated form; confirm with `grep -r "magnetometerEventStream\|accelerometerEventStream" ~/.pub-cache/hosted/pub.dev/sensors_plus-*/lib`.)

- [ ] **Step 4: Run to verify it passes** — Run: `flutter test test/unit/heading_service_fake_test.dart && flutter analyze` — Expected: PASS; clean.

- [ ] **Step 5: Commit**
```bash
git add lib/services/heading_service.dart test/support/fake_heading_service.dart test/unit/heading_service_fake_test.dart
git commit -m "feat(map): HeadingService seam over sensors_plus + web-unsupported + shared fake (Phase B)"
```

---

## Task 5: `PointMeController` + providers

**Files:** Create `lib/services/point_me_controller.dart`, `test/unit/point_me_controller_test.dart`.

**Interfaces:**
- `class PointMeState { HeadingAvailability availability; double? relativeAngleDegrees; double? trueBearingDegrees; double? distanceMeters; bool nearTarget; bool hasFix; }`.
- Providers (using ONLY the plain-`Notifier` patterns Phase A already compiled on Riverpod 3.4.2 — **no `.family`, no `.autoDispose` chain**, which are not the verified 3.4 manual API):
  - `headingServiceProvider` (`Provider<HeadingService>`).
  - `pointMeTargetProvider` (`NotifierProvider<PointMeTargetNotifier, LatLng?>`, default null) — a tiny setter notifier, exactly the shape of Phase A's `MapVisibleNotifier`. `PointMeScreen` sets it on open and clears it (null) on dispose/background — this IS the sensor lifecycle without needing `autoDispose`.
  - `pointMeControllerProvider` (`NotifierProvider<PointMeController, PointMeState>`).

**Consumes:** Phase A's `locationControllerProvider` (for `fix.position`), `pointMeTargetProvider`, and `MapConfig.campusMagneticDeclinationDegrees` / `pointMeNearTargetMeters`. When the target is null the controller cancels the heading stream (lifecycle); when set, it subscribes.

- [ ] **Step 1: Write the failing test** — `test/unit/point_me_controller_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:aon2026/models/user_location_fix.dart';
import 'package:aon2026/services/heading_service.dart';
import 'package:aon2026/services/location_service.dart';
import 'package:aon2026/services/location_providers.dart';
import 'package:aon2026/services/point_me_controller.dart';
import 'package:aon2026/widgets/map_config.dart';
import '../support/fake_heading_service.dart';
import '../support/fake_location_service.dart';

const _target = LatLng(-33.7727, 151.1134); // ~111 m north of campus centre

ProviderContainer _c(FakeHeadingService h, FakeLocationService loc,
    {LatLng? target = _target}) {
  final c = ProviderContainer(overrides: [
    headingServiceProvider.overrideWithValue(h),
    locationServiceProvider.overrideWithValue(loc),
  ]);
  addTearDown(c.dispose);
  c.read(mapVisibleProvider.notifier).set(true);
  c.read(pointMeControllerProvider); // instantiate (subscribes)
  if (target != null) c.read(pointMeTargetProvider.notifier).set(target);
  return c;
}

PointMeState _state(ProviderContainer c) => c.read(pointMeControllerProvider);

Future<void> _activate(ProviderContainer c, FakeLocationService loc) async {
  await c.read(locationControllerProvider.notifier).onLocateTapped();
  loc.emit(UserLocationFix(
      position: MapConfig.campusCentre, accuracyMeters: 8)); // user at centre
  await Future<void>.delayed(Duration.zero);
}

void main() {
  test('no fix yet → no bearing, hasFix false', () {
    final c = _c(FakeHeadingService(), FakeLocationService());
    final s = _state(c);
    expect(s.hasFix, isFalse);
    expect(s.trueBearingDegrees, isNull);
  });

  test('with a fix, bearing+distance computed even before heading', () async {
    final loc = FakeLocationService();
    final c = _c(FakeHeadingService(), loc);
    await _activate(c, loc);
    final s = _state(c);
    expect(s.hasFix, isTrue);
    expect(s.trueBearingDegrees, closeTo(0, 2)); // target due north
    expect(s.distanceMeters, closeTo(111, 5));
  });

  test('heading available → relativeAngle applies declination', () async {
    final h = FakeHeadingService();
    final loc = FakeLocationService();
    final c = _c(h, loc);
    await _activate(c, loc);
    // device points at magnetic north (0). true heading = 0 + declination.
    h.emit(const HeadingSample(
        availability: HeadingAvailability.available, magneticHeadingDegrees: 0));
    await Future<void>.delayed(Duration.zero);
    final s = _state(c);
    expect(s.availability, HeadingAvailability.available);
    // bearing ~0 (north), trueHeading = declination → relative ≈ -declination
    expect(s.relativeAngleDegrees!,
        closeTo(-MapConfig.campusMagneticDeclinationDegrees, 2));
  });

  test('web/unsupported heading → availability unsupported, bearing still set',
      () async {
    final h = FakeHeadingService();
    final loc = FakeLocationService();
    final c = _c(h, loc);
    await _activate(c, loc);
    h.emit(const HeadingSample(availability: HeadingAvailability.unsupported));
    await Future<void>.delayed(Duration.zero);
    final s = _state(c);
    expect(s.availability, HeadingAvailability.unsupported);
    expect(s.trueBearingDegrees, isNotNull); // fallback card still works
  });

  test('near target flips nearTarget true', () async {
    final loc = FakeLocationService();
    final c = _c(FakeHeadingService(), loc, target: MapConfig.campusCentre);
    await _activate(c, loc); // user also at campus centre
    expect(_state(c).nearTarget, isTrue);
  });

  test('clearing the target (screen left) cancels heading & drops to no-target',
      () async {
    final h = FakeHeadingService();
    final loc = FakeLocationService();
    final c = _c(h, loc);
    await _activate(c, loc);
    c.read(pointMeTargetProvider.notifier).set(null); // screen disposed
    await Future<void>.delayed(Duration.zero);
    // A heading emitted after the screen left is ignored (stream cancelled).
    h.emit(const HeadingSample(
        availability: HeadingAvailability.available, magneticHeadingDegrees: 0));
    await Future<void>.delayed(Duration.zero);
    expect(_state(c).relativeAngleDegrees, isNull);
  });
}
```

- [ ] **Step 2: Run to verify it fails** — FAIL.

- [ ] **Step 3: Implement** — `lib/services/point_me_controller.dart`:
```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:aon2026/services/heading_service.dart';
import 'package:aon2026/services/location_providers.dart';
import 'package:aon2026/widgets/bearing_math.dart';
import 'package:aon2026/widgets/map_config.dart';

class PointMeState {
  const PointMeState({
    this.availability = HeadingAvailability.acquiring,
    this.relativeAngleDegrees,
    this.trueBearingDegrees,
    this.distanceMeters,
    this.nearTarget = false,
    this.hasFix = false,
  });
  final HeadingAvailability availability;
  final double? relativeAngleDegrees;
  final double? trueBearingDegrees;
  final double? distanceMeters;
  final bool nearTarget;
  final bool hasFix;
}

final headingServiceProvider = Provider<HeadingService>(
    (ref) => throw UnimplementedError('override in main / a fake in tests'));

/// The current "point me there" target, or null when no such screen is open.
/// Set by `PointMeScreen` on open, cleared (null) on dispose/background — this
/// is the sensor lifecycle. Same tiny-notifier shape as Phase A's MapVisible.
final pointMeTargetProvider =
    NotifierProvider<PointMeTargetNotifier, LatLng?>(PointMeTargetNotifier.new);

class PointMeTargetNotifier extends Notifier<LatLng?> {
  @override
  LatLng? build() => null;
  void set(LatLng? target) => state = target;
}

final pointMeControllerProvider =
    NotifierProvider<PointMeController, PointMeState>(PointMeController.new);

class PointMeController extends Notifier<PointMeState> {
  StreamSubscription<HeadingSample>? _sub;
  HeadingAvailability _availability = HeadingAvailability.acquiring;
  double? _magneticHeading;

  @override
  PointMeState build() {
    ref.onDispose(() => _sub?.cancel());
    ref.listen(pointMeTargetProvider, (_, target) => _onTarget(target));
    ref.listen(locationControllerProvider, (_, _) => _recompute());
    _onTarget(ref.read(pointMeTargetProvider)); // apply the initial target
    return _compute();
  }

  /// Subscribe to heading only while a target is set; cancel when it clears.
  void _onTarget(LatLng? target) {
    _sub?.cancel();
    _sub = null;
    _availability = HeadingAvailability.acquiring;
    _magneticHeading = null;
    if (target != null) {
      _sub = ref.read(headingServiceProvider).watch().listen((s) {
        _availability = s.availability;
        _magneticHeading = s.magneticHeadingDegrees;
        _recompute();
      }, onError: (_) {
        _availability = HeadingAvailability.unavailable;
        _magneticHeading = null;
        _recompute();
      });
    }
    _recompute();
  }

  void _recompute() => state = _compute();

  PointMeState _compute() {
    final target = ref.read(pointMeTargetProvider);
    final fix = ref.read(locationControllerProvider).fix;
    if (target == null) {
      return PointMeState(availability: _availability, hasFix: fix != null);
    }
    if (fix == null) {
      return PointMeState(availability: _availability, hasFix: false);
    }
    final bearing = trueBearingDegrees(fix.position, target);
    final distance = distanceBetweenMeters(fix.position, target);
    final near = distance <= MapConfig.pointMeNearTargetMeters;
    double? relative;
    if (_magneticHeading != null) {
      final trueHeading = normalizeBearing(
          _magneticHeading! + MapConfig.campusMagneticDeclinationDegrees);
      relative = relativeAngleDegrees(bearing, trueHeading);
    }
    return PointMeState(
      availability: _availability,
      trueBearingDegrees: bearing,
      distanceMeters: distance,
      relativeAngleDegrees: relative,
      nearTarget: near,
      hasFix: true,
    );
  }
}
```
Needs `import 'package:latlong2/latlong.dart';` (for `LatLng`, `normalizeBearing`). The test overrides `headingServiceProvider`/`locationServiceProvider` with fakes; `main` overrides `headingServiceProvider` with `SensorsHeadingService()` (Task 8). `PointMeScreen` (Task 7) calls `pointMeTargetProvider.notifier).set(target)` in `initState` and `.set(null)` in `dispose` (and on `AppLifecycleState.paused`).

- [ ] **Step 4: Run to verify it passes** — Run: `flutter test test/unit/point_me_controller_test.dart && flutter analyze` — Expected: PASS; clean.

- [ ] **Step 5: Commit**
```bash
git add lib/services/point_me_controller.dart test/unit/point_me_controller_test.dart
git commit -m "feat(map): PointMeController fuses location+heading+declination+target (Phase B)"
```

---

## Task 6: Localised strings (EN + FA)

**Files:** Modify `lib/l10n/app_en.arb`, `lib/l10n/app_fa.arb`; regenerate. **Do this before `PointMeScreen` (Task 7) so it references real `l.*` getters.**

- [ ] **Step 1: Add keys to `app_en.arb`** (each with a `@`-description):
```json
  "pointMeTitle": "Point me there",
  "@pointMeTitle": { "description": "Heading screen title + venue-sheet button" },
  "pointMeDistanceMeters": "{meters} m",
  "@pointMeDistanceMeters": { "placeholders": { "meters": { "type": "int" } } },
  "pointMeDistanceKm": "{km} km",
  "@pointMeDistanceKm": { "placeholders": { "km": { "type": "String" } } },
  "pointMeFindingNorth": "Finding north…",
  "@pointMeFindingNorth": { "description": "Heading acquiring state" },
  "pointMeNearby": "You're basically there",
  "@pointMeNearby": { "description": "Shown within the near-target radius" },
  "pointMeNoCompass": "The live arrow needs a phone with a compass sensor. Here's the direction and distance.",
  "@pointMeNoCompass": { "description": "Fallback when heading is unsupported/unavailable" },
  "pointMeNeedsLocation": "Turn on location to point the way",
  "@pointMeNeedsLocation": { "description": "Shown when there is no location fix" },
  "pointMeUnknownPlace": "We can't find that place",
  "@pointMeUnknownPlace": { "description": "Unknown/removed venue id" },
  "pointMeBearingSentence": "{venue} is about {distance} {cardinal} of you",
  "@pointMeBearingSentence": { "description": "Fallback bearing card", "placeholders": { "venue": {"type":"String"}, "distance": {"type":"String"}, "cardinal": {"type":"String"} } },
  "pointMeA11yDirection": "{venue} is {side}, {distance} away",
  "@pointMeA11yDirection": { "description": "Live arrow semantic label", "placeholders": { "venue": {"type":"String"}, "side": {"type":"String"}, "distance": {"type":"String"} } },
  "sideAhead": "ahead of you",
  "sideBehind": "behind you",
  "sideLeft": "to your left",
  "sideRight": "to your right",
  "cardinalN": "north", "cardinalNE": "north-east", "cardinalE": "east", "cardinalSE": "south-east",
  "cardinalS": "south", "cardinalSW": "south-west", "cardinalW": "west", "cardinalNW": "north-west",
```

- [ ] **Step 2: Add the same keys to `app_fa.arb`** (Persian; present so the build doesn't fail):
```json
  "pointMeTitle": "مسیر را نشانم بده",
  "pointMeDistanceMeters": "{meters} متر",
  "pointMeDistanceKm": "{km} کیلومتر",
  "pointMeFindingNorth": "در حال یافتن شمال…",
  "pointMeNearby": "تقریباً رسیدی",
  "pointMeNoCompass": "فلش زنده به گوشی با حسگر قطب‌نما نیاز دارد. جهت و فاصله در اینجاست.",
  "pointMeNeedsLocation": "برای نشان‌دادن مسیر، موقعیت مکانی را روشن کنید",
  "pointMeUnknownPlace": "آن مکان را پیدا نمی‌کنیم",
  "pointMeBearingSentence": "{venue} حدوداً {distance} در {cardinal} شماست",
  "pointMeA11yDirection": "{venue} {side}، در فاصلهٔ {distance}",
  "sideAhead": "پیش روی شما",
  "sideBehind": "پشت سر شما",
  "sideLeft": "سمت چپ شما",
  "sideRight": "سمت راست شما",
  "cardinalN": "شمال", "cardinalNE": "شمال‌شرق", "cardinalE": "شرق", "cardinalSE": "جنوب‌شرق",
  "cardinalS": "جنوب", "cardinalSW": "جنوب‌غرب", "cardinalW": "غرب", "cardinalNW": "شمال‌غرب",
```

- [ ] **Step 3: Regenerate + verify** — Run: `flutter gen-l10n && flutter analyze` — Expected: getters exist; no untranslated-key failure; clean.

- [ ] **Step 4: Commit**
```bash
git add lib/l10n/app_en.arb lib/l10n/app_fa.arb lib/l10n/generated/
git commit -m "feat(map): l10n for Point-me-there (screen, cardinals, sides) (EN/FA) (Phase B)"
```

---

## Task 7: `PointMeScreen`

**Files:** Create `lib/screens/point_me_screen.dart`, `test/widget/point_me_screen_test.dart`.

**Interfaces:** `PointMeScreen({required String venueId})` (`ConsumerStatefulWidget`). Looks up `VenuesData.byId(venueId)` (and `ParkingData` if needed); unknown → safe unavailable + Back. Reads `pointMeControllerProvider(target)`. Renders arrow / near / fallback / no-fix states. Motion-aware, a11y-labelled.

- [ ] **Step 1: Write the failing test** — `test/widget/point_me_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/models/user_location_fix.dart';
import 'package:aon2026/services/heading_service.dart';
import 'package:aon2026/services/location_service.dart';
import 'package:aon2026/services/location_providers.dart';
import 'package:aon2026/services/point_me_controller.dart';
import 'package:aon2026/widgets/map_config.dart';
import 'package:aon2026/screens/point_me_screen.dart';
import '../support/fake_heading_service.dart';
import '../support/fake_location_service.dart';

ProviderContainer _c(FakeHeadingService h, FakeLocationService loc) {
  final c = ProviderContainer(overrides: [
    headingServiceProvider.overrideWithValue(h),
    locationServiceProvider.overrideWithValue(loc),
  ]);
  addTearDown(c.dispose);
  c.read(mapVisibleProvider.notifier).set(true);
  return c;
}

Widget _app(ProviderContainer c, String venueId, {Locale? locale}) =>
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: PointMeScreen(venueId: venueId),
      ),
    );

// Pick a real venue id with coordinates from the app's own data.
const _venueId = 'macquarie-theatre';

Future<void> _fix(ProviderContainer c, FakeLocationService loc) async {
  await c.read(locationControllerProvider.notifier).onLocateTapped();
  loc.emit(UserLocationFix(position: MapConfig.campusCentre, accuracyMeters: 8));
  await Future<void>.delayed(Duration.zero);
}

void main() {
  testWidgets('unknown venue → safe message + Back, no crash', (t) async {
    final c = _c(FakeHeadingService(), FakeLocationService());
    await t.pumpWidget(_app(c, 'does-not-exist'));
    await t.pump();
    expect(find.textContaining("can't find"), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('no fix → needs-location message', (t) async {
    final c = _c(FakeHeadingService(), FakeLocationService());
    await t.pumpWidget(_app(c, _venueId));
    await t.pump();
    expect(find.textContaining('Turn on location'), findsOneWidget);
  });

  testWidgets('heading available → an arrow is shown', (t) async {
    final h = FakeHeadingService();
    final loc = FakeLocationService();
    final c = _c(h, loc);
    await t.pumpWidget(_app(c, _venueId));
    await _fix(c, loc);
    h.emit(const HeadingSample(
        availability: HeadingAvailability.available, magneticHeadingDegrees: 0));
    await t.pump();
    await t.pump();
    expect(find.byKey(const Key('point-me-arrow')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('unsupported → bearing fallback card, no arrow', (t) async {
    final h = FakeHeadingService();
    final loc = FakeLocationService();
    final c = _c(h, loc);
    await t.pumpWidget(_app(c, _venueId));
    await _fix(c, loc);
    h.emit(const HeadingSample(availability: HeadingAvailability.unsupported));
    await t.pump();
    await t.pump();
    expect(find.byKey(const Key('point-me-arrow')), findsNothing);
    expect(find.textContaining('compass sensor'), findsOneWidget);
  });

  testWidgets('no overflow at 320x568 / 2.0', (t) async {
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1.0;
    t.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    final h = FakeHeadingService();
    final loc = FakeLocationService();
    final c = _c(h, loc);
    await t.pumpWidget(_app(c, _venueId));
    await _fix(c, loc);
    h.emit(const HeadingSample(
        availability: HeadingAvailability.available, magneticHeadingDegrees: 30));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  testWidgets('renders under FA locale', (t) async {
    final c = _c(FakeHeadingService(), FakeLocationService());
    await t.pumpWidget(_app(c, _venueId, locale: const Locale('fa')));
    await t.pump();
    expect(t.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run to verify it fails** — FAIL.

- [ ] **Step 3: Implement** — `lib/screens/point_me_screen.dart` (`ConsumerStatefulWidget`). Resolve the target from `VenuesData.byId(venueId)` (fall back to `ParkingData.byId`); **if none → the safe "can't find that place" + Back screen, and do NOT set a target.** Otherwise, **lifecycle:** in `initState` (post-frame) call `ref.read(pointMeTargetProvider.notifier).set(targetLatLng)`; in `dispose` call `.set(null)`; add an `AppLifecycleListener` that `.set(null)` on `paused`/`inactive` and re-sets the target on `resumed` while mounted. Body: `ref.watch(pointMeControllerProvider)` and render per state. Key the arrow `const Key('point-me-arrow')`. Use `context.aon` colours, `AonL10n.of(context)`, `MediaQuery.disableAnimationsOf` for reduced motion (snap vs tween), a `Transform.rotate` by `relativeAngleDegrees * pi/180`, and a non-liveRegion `Semantics` label built from the side bucket. Distance formatting: `<1000 → l.pointMeDistanceMeters(round)`, else `l.pointMeDistanceKm((m/1000).toStringAsFixed(1))`. Side bucket from `relativeAngleDegrees`: `|a|<20 → ahead; >160 → behind; a>0 → right; else left`. Cardinal via `cardinalFor(trueBearing)` mapped to the `l.cardinal*` getter. Full widget body follows the states table in the spec (§6); every branch returns a themed, scroll-safe layout.

- [ ] **Step 4: Run to verify it passes** — PASS.

- [ ] **Step 5: Commit**
```bash
git add lib/screens/point_me_screen.dart test/widget/point_me_screen_test.dart
git commit -m "feat(map): Point-me-there screen — arrow/near/fallback/no-fix, a11y, 2.0, FA (Phase B)"
```

---

## Task 8: Sheet entry + route + main override

**Files:** Modify `lib/main.dart` (override `headingServiceProvider`), `lib/app/router/app_router.dart` (route), `lib/screens/map_screen.dart` (`VenueSheet`/`ParkingSheet` button); Create `test/widget/point_me_entry_test.dart`.

- [ ] **Step 1: Override the service in `main.dart`** — add to the root `ProviderScope` overrides:
```dart
import 'package:aon2026/services/heading_service.dart';
import 'package:aon2026/services/point_me_controller.dart';
// ...
    headingServiceProvider.overrideWithValue(SensorsHeadingService()),
```

- [ ] **Step 2: Add the route** — in `lib/app/router/app_router.dart`, add `Routes.pointMeTo(String venueId)` → a `GoRoute` (path e.g. `/point-me/:venueId`) building `PointMeScreen(venueId: id)`. Mirror the existing `panoramaFor` route's registration exactly.

- [ ] **Step 3: Write the failing entry test** — `test/widget/point_me_entry_test.dart`: pump `VenueSheet(venueId: 'macquarie-theatre')` inside a `MaterialApp` with a router that records navigation; assert a "Point me there" button is present and tapping it navigates to the point-me route. (Mirror the existing venue-sheet test harness in the repo.)

- [ ] **Step 4: Wire the button** — in `VenueSheet` (and `ParkingSheet`), add a button peer to "Walking directions", shown only when the subject `hasCoordinates`:
```dart
OutlinedButton.icon(
  onPressed: () {
    Navigator.of(context).pop();
    context.push(Routes.pointMeTo(venue.id));
  },
  icon: const Icon(Icons.navigation_rounded),
  label: Text(l.pointMeTitle),
),
```

- [ ] **Step 5: Run tests + web build** — Run: `flutter test test/widget/point_me_entry_test.dart && flutter analyze && flutter build web` — Expected: PASS; clean; web green.

- [ ] **Step 6: Commit**
```bash
git add lib/main.dart lib/app/router/app_router.dart lib/screens/map_screen.dart test/widget/point_me_entry_test.dart
git commit -m "feat(map): 'Point me there' entry from venue/parking sheets + route (Phase B)"
```

---

## Task 9: Verification gate + on-device compass run

**Files:** Append a closeout to `docs/superpowers/specs/2026-08-13-aon-map-heading-phaseB-design.md`.

- [ ] **Step 1: Full static + test** — Run: `flutter analyze && flutter test` — Expected: clean; suite = Task 0 baseline + new; no regressions.
- [ ] **Step 2: Builds** — Run: `flutter build web`, `flutter build ios --simulator --debug`, `flutter build apk --debug` — Expected: all succeed. **Web is the load-bearing gate.**
- [ ] **Step 3: On-device compass pass** (real device or a sim that reports a magnetometer; the iOS simulator has no magnetometer → it must show the `unsupported`/`unavailable` fallback, which is itself a valid check). Record PASS/FAIL:
```text
[ ] open a venue sheet → "Point me there" is present → tap → screen opens
[ ] with a compass device: arrow points toward the venue; rotating the phone rotates the arrow toward the true bearing
[ ] walk closer → distance decreases; within ~20 m → "you're basically there"
[ ] no-compass device/sim → bearing+distance fallback card, no frozen arrow
[ ] deny/disable location → "turn on location" message; screen still safe
[ ] deep-link an unknown venue id → "can't find that place" + Back (no crash, no campus-centre guess)
[ ] leave the screen → magnetometer/accelerometer streams stop (no battery drain)
[ ] VoiceOver: focus the arrow → hears side + distance; not spammed on every tick
```
- [ ] **Step 4: Closeout** — append: resolved `sensors_plus` version, the WMM2025 declination receipt (Task 0), all three build results, and the on-device checklist result.
- [ ] **Step 5: Final re-gate** — Run: `flutter analyze && flutter test && git diff --check && git status --short`, then a hostile read of `git diff main...HEAD`.
- [ ] **Step 6: Commit**
```bash
git add docs/superpowers/specs/2026-08-13-aon-map-heading-phaseB-design.md
git commit -m "docs(map): Phase B verification + compass runtime closeout"
```

---

## Self-Review

**1. Spec coverage**

| Spec § | Task |
|---|---|
| §2 sensors_plus, web-safe, one dep | 1 |
| §3 four decoupled units | 2–5, 7 |
| §4 heading pipeline (tilt-comp, azimuth) | 3 |
| §4 stream fusion (combine-latest) | 4 |
| §5 availability state machine | 4, 5 |
| §6 PointMeScreen states + a11y + reduced-motion | 7 |
| §7 bearing/relative/distance/cardinal | 2 |
| §8 circular smoothing | 3 |
| §9 sensor lifecycle (target-provider set/clear + onDispose) | 5, 7 |
| §10 declination preflight-verified | 0, 2 |
| §11 constraints (web gate, l10n, 2.0, no invented coords) | 1, 6, 7 |
| l10n EN/FA (incl. cardinals/sides) | 6 |
| §12 tests | every task + 9 |

**2. Placeholder scan** — one intentional fill: `MapConfig.campusMagneticDeclinationDegrees = <VALUE FROM TASK 0>` is replaced with the WMM2025 number Task 0 computes (Task 2 Step 5 says so explicitly). Task 7 Step 3 describes the widget body against the spec's state table rather than pasting the full tree — flag: **when executing Task 7, write every state branch in full before running; the test asserts arrow-key / fallback-text / unknown / no-fix, so each branch is pinned.** Everything else is complete code.

**3. Type consistency** — `Vector3`, `tiltCompensatedHeadingDegrees`, `CircularSmoother`, `HeadingAvailability{acquiring,available,unavailable,unsupported}`, `HeadingSample{availability,magneticHeadingDegrees}`, `HeadingService.watch()`, `headingServiceProvider`, `PointMeState{availability,relativeAngleDegrees,trueBearingDegrees,distanceMeters,nearTarget,hasFix}`, `pointMeTargetProvider` (`NotifierProvider<PointMeTargetNotifier, LatLng?>`, `.set(LatLng?)`), `pointMeControllerProvider` (plain `NotifierProvider<PointMeController, PointMeState>` — **no family/autoDispose**, verified against Riverpod 3.4.2), `trueBearingDegrees`/`relativeAngleDegrees`/`distanceBetweenMeters`/`cardinalFor`/`Cardinal`, `MapConfig.{campusMagneticDeclinationDegrees,pointMeNearTargetMeters}`, `Routes.pointMeTo`, `l.pointMe*`/`l.cardinal*`/`l.side*` — consistent across tasks. Shared fakes: `test/support/fake_heading_service.dart` + Phase A's `fake_location_service.dart`.

---

## Notes for the executor

- **Web build is a hard gate at Task 1 Step 2 and Task 9 Step 2** — `sensors_plus` claiming web support is exactly the kind of claim that broke `flutter_compass`; prove it the moment the dep lands.
- **The heading math mirrors Android `getRotationMatrix`/`getOrientation`.** If the flat-phone test's azimuth sign is off for the test's chosen axis convention, fix the *test vectors*, not the algorithm — keep the flat==tilted invariant and the degenerate→null case.
- **`sensors_plus` 7.x stream names:** prefer `magnetometerEventStream()`/`accelerometerEventStream()` (non-deprecated). Confirm against the installed package before writing Task 4's impl.
- **Never invent coordinates** — unknown venue id is a safe state, never a campus-centre fallback.
- **Reduced motion** drops the arrow's easing tween (snap) but the arrow still reorients — it is essential live state, not decoration.
- **The pre-existing web runtime black-screen** (Phase A closeout) means `PointMeScreen` is not runtime-reachable on web until that's triaged; Phase B's web *build* gate still applies.
- Never weaken an existing test to make Phase B pass.
