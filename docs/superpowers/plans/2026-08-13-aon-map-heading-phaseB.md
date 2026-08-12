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
- **Explicit sampling rate:** subscribe with `samplingPeriod: const Duration(milliseconds: 50)` (~20 Hz) on both streams — an arrow UX must not silently run at max sensor speed (battery).
- **Deterministic failure:** the heading stream has an **acquisition + staleness timeout** — if no valid heading arrives within a bounded window, or updates stop, it emits `unavailable` (so a no-magnetometer sim/device reaches the fallback rather than "finding north…" forever). A sensor **error is terminal for that session**: cancel BOTH streams, clear cached samples, emit `unavailable`, stop — never resurrect the arrow from stale data. The smoother is created **inside `watch()`** (fresh per session).
- **Orientation policy (MVP):** `heading_math` computes azimuth in the device's **natural-orientation** frame (Android/iOS sensor convention). The app is **portrait-locked on phones** (`SystemChrome` + Info.plist), so natural == display there. **`PointMeScreen` locks portrait** on entry to hold that contract on devices whose Info.plist otherwise allows landscape (iPad). Remapping the sensor axes for landscape-natural / rotated displays is **IOU-B4** — until then, on a landscape-natural tablet the arrow is not trusted (documented, not silent).
- **Location demand:** `PointMeScreen` is its own route, so Phase A's `active && mapVisible` GPS gate is widened to `active && (mapVisible || pointMeActive)` via a new `pointMeActiveProvider` — so a PointMe screen (even deep-linked) keeps GPS alive.
- **Location quality respected:** a low-accuracy fix (`UserLocationFix.isLowAccuracy`, >200 m — Phase A) must NOT produce a `nearTarget` claim; the screen shows an "improving accuracy" note instead of false precision.
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

## Task 1: Add `sensors_plus` + platform config + all-three build gate

**Files:** Modify `pubspec.yaml`, `android/settings.gradle.kts` (AGP bump), `ios/Runner/Info.plist` (motion key).

**Why the toolchain step:** `sensors_plus` 7.x **requires AGP ≥ 8.12.1 / Gradle ≥ 8.13 / Kotlin ≥ 2.2.0 / Java 17** (verified against its changelog). The repo has **Gradle 9.1.0 ✓, Kotlin 2.3.20 ✓, Java 17 ✓, but AGP 8.11.1 ✗** — AGP must be bumped, and all three native builds must run the moment the dep lands (discover a toolchain break before any feature code exists).

- [ ] **Step 1: Add the dependency, pinned** — Run: `flutter pub add sensors_plus:^7.1.0` — Expected: resolves 7.1.0; `pub get` OK.

- [ ] **Step 2: Bump AGP to satisfy `sensors_plus`** — in `android/settings.gradle.kts`, change the Android Gradle Plugin version:
```kotlin
    id("com.android.application") version "8.12.1" apply false   // was 8.11.1 (sensors_plus 7.x needs >=8.12.1)
```
(Gradle 9.1.0, Kotlin 2.3.20, Java 17 already meet the floor — do not touch those.)

- [ ] **Step 3: iOS — motion usage description (required since sensors_plus 6.0.0; omission CRASHES on motion access).** In `ios/Runner/Info.plist` `<dict>` add:
```xml
	<key>NSMotionUsageDescription</key>
	<string>Used to sense which way you're facing so the map can point you toward the venues. This never leaves your device.</string>
```

- [ ] **Step 4: Build ALL THREE platforms now** — Run:
```bash
flutter build web            # sensors_plus web support (the reason flutter_compass was cut)
flutter build apk --debug    # exercises the AGP bump — the real toolchain risk
flutter build ios --simulator --debug
```
Expected: all three SUCCEED. **If web fails, STOP** (web support is a hard requirement). **If the APK fails on AGP/Gradle/Kotlin, resolve the toolchain here** (bump AGP further or, as a last resort, pin an older `sensors_plus` that supports AGP 8.11) — before any feature code.

- [ ] **Step 5: Analyze + commit**
```bash
flutter analyze
git add pubspec.yaml pubspec.lock android/settings.gradle.kts ios/Runner/Info.plist
git commit -m "feat(map): add sensors_plus 7.1.0 + AGP 8.12.1 + iOS motion key (all builds green) (Phase B)"
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
    test('rejects an out-of-range alpha', () {
      expect(() => CircularSmoother(0), throwsA(anything));
      expect(() => CircularSmoother(1.5), throwsA(anything));
    });
    test('a hard wrap sequence stays near 0, never ~180', () {
      final s = CircularSmoother(0.5);
      double out = 0;
      for (final v in [358.0, 359.0, 0.0, 1.0, 2.0]) {
        out = s.add(v);
      }
      expect(out < 20 || out > 340, isTrue);
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
/// Computed in the device's NATURAL-orientation frame (sensor convention). This
/// is correct only when natural == display orientation — true on a portrait-
/// locked phone (which this app is). Landscape-natural/rotated displays (iPad)
/// need axis remapping first — IOU-B4; `PointMeScreen` locks portrait meanwhile.
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
/// A fresh instance is created per heading session (see `SensorsHeadingService`).
class CircularSmoother {
  CircularSmoother(this.alpha) : assert(alpha > 0 && alpha <= 1);
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
/// [tiltCompensatedHeadingDegrees], smooths (fresh smoother per session), and is
/// deterministic on failure. Web has no Magnetometer API in any browser, so it
/// short-circuits to a single `unsupported` WITHOUT subscribing.
class SensorsHeadingService implements HeadingService {
  static const _period = Duration(milliseconds: 50); // ~20 Hz
  static const _acquireTimeout = Duration(seconds: 4);
  static const _staleTimeout = Duration(seconds: 2);

  @override
  Stream<HeadingSample> watch() {
    if (kIsWeb) {
      return Stream<HeadingSample>.value(
          const HeadingSample(availability: HeadingAvailability.unsupported));
    }
    final controller = StreamController<HeadingSample>();
    final smoother = CircularSmoother(0.2); // fresh per session
    Vector3? latestAccel;
    StreamSubscription? magSub, accSub;
    Timer? acquireTimer, staleTimer;
    var closed = false;

    // Any required-sensor failure OR a timeout is TERMINAL for this session:
    // cancel both streams, clear state, emit unavailable, stop. Never resurrect
    // the arrow from stale data.
    void fail() {
      acquireTimer?.cancel();
      staleTimer?.cancel();
      magSub?.cancel();
      accSub?.cancel();
      magSub = null;
      accSub = null;
      latestAccel = null;
      if (!closed) {
        controller.add(
            const HeadingSample(availability: HeadingAvailability.unavailable));
      }
    }

    controller.onListen = () {
      controller.add(
          const HeadingSample(availability: HeadingAvailability.acquiring));
      // No valid heading within the window → deterministic fallback (this is
      // what a no-magnetometer simulator/device hits instead of "finding north…").
      acquireTimer = Timer(_acquireTimeout, fail);
      accSub = accelerometerEventStream(samplingPeriod: _period)
          .listen((e) => latestAccel = Vector3(e.x, e.y, e.z), onError: (_) => fail());
      magSub = magnetometerEventStream(samplingPeriod: _period).listen(
        (e) {
          final a = latestAccel;
          if (a == null) return; // wait for first accel sample
          final mag = tiltCompensatedHeadingDegrees(Vector3(e.x, e.y, e.z), a);
          if (mag == null) return; // degenerate reading; keep waiting
          acquireTimer?.cancel();
          staleTimer?.cancel();
          staleTimer = Timer(_staleTimeout, fail); // sensor stalled → unavailable
          controller.add(HeadingSample(
            availability: HeadingAvailability.available,
            magneticHeadingDegrees: smoother.add(mag),
          ));
        },
        onError: (_) => fail(),
      );
    };
    controller.onCancel = () async {
      closed = true;
      acquireTimer?.cancel();
      staleTimer?.cancel();
      await magSub?.cancel();
      await accSub?.cancel();
    };
    return controller.stream;
  }
}
```
(Confirm the installed API exports `magnetometerEventStream({Duration samplingPeriod})` / `accelerometerEventStream(...)` — the non-deprecated 7.x form: `grep -rn "magnetometerEventStream\|accelerometerEventStream\|samplingPeriod" ~/.pub-cache/hosted/pub.dev/sensors_plus-*/lib`. If the arg name differs, use the installed signature.)

- [ ] **Step 4: Run to verify it passes** — Run: `flutter test test/unit/heading_service_fake_test.dart && flutter analyze` — Expected: PASS; clean.

- [ ] **Step 5: Commit**
```bash
git add lib/services/heading_service.dart test/support/fake_heading_service.dart test/unit/heading_service_fake_test.dart
git commit -m "feat(map): HeadingService seam over sensors_plus + web-unsupported + shared fake (Phase B)"
```

---

## Task 5: `PointMeController` + providers

**Files:** Create `lib/services/point_me_controller.dart`, `test/unit/point_me_controller_test.dart`. **Modify** `lib/services/location_providers.dart` (Phase A) to add `pointMeActiveProvider` and widen the GPS gate.

**Interfaces:**
- `class PointMeState { HeadingAvailability availability; double? relativeAngleDegrees; double? trueBearingDegrees; double? distanceMeters; bool nearTarget; bool hasFix; bool locationReliable; }` — `locationReliable` is false when the fix `isLowAccuracy`; `nearTarget` can only be true when `locationReliable`.
- Providers (using ONLY the plain-`Notifier` patterns Phase A already compiled on Riverpod 3.4.2 — **no `.family`, no `.autoDispose` chain**):
  - `headingServiceProvider` (`Provider<HeadingService>`).
  - `pointMeTargetProvider` (`NotifierProvider<PointMeTargetNotifier, LatLng?>`, default null) — set by `PointMeScreen` on open, cleared (null) on dispose/background. This IS the heading-stream lifecycle.
  - `pointMeActiveProvider` (`NotifierProvider<PointMeActiveNotifier, bool>`, default false) — set true while `PointMeScreen` is open so GPS stays alive off the Map tab. **Added in `location_providers.dart`** and OR'd into Phase A's gate: `wantStream = state.active && (mapVisible || pointMeActive)`.
  - `pointMeControllerProvider` (`NotifierProvider<PointMeController, PointMeState>`).

**Consumes:** Phase A's `locationControllerProvider` (for `fix.position` + `fix.isLowAccuracy`), `pointMeTargetProvider`, `MapConfig.campusMagneticDeclinationDegrees` / `pointMeNearTargetMeters`.

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

  test('near target flips nearTarget true (and short-circuits bearing)',
      () async {
    final loc = FakeLocationService();
    final c = _c(FakeHeadingService(), loc, target: MapConfig.campusCentre);
    await _activate(c, loc); // user also at campus centre
    final s = _state(c);
    expect(s.nearTarget, isTrue);
    expect(s.trueBearingDegrees, isNull); // no ill-defined bearing at ~0 range
  });

  test('low-accuracy fix → not reliable, no near-target claim', () async {
    final loc = FakeLocationService();
    final c = _c(FakeHeadingService(), loc, target: MapConfig.campusCentre);
    await c.read(locationControllerProvider.notifier).onLocateTapped();
    loc.emit(
        UserLocationFix(position: MapConfig.campusCentre, accuracyMeters: 250));
    await Future<void>.delayed(Duration.zero);
    final s = _state(c);
    expect(s.locationReliable, isFalse);
    expect(s.nearTarget, isFalse); // never "you're here" on a ±250 m fix
  });

  test('PointMe keeps GPS alive when the Map tab is not visible', () async {
    final loc = FakeLocationService();
    final c = ProviderContainer(overrides: [
      headingServiceProvider.overrideWithValue(FakeHeadingService()),
      locationServiceProvider.overrideWithValue(loc),
    ]);
    addTearDown(c.dispose);
    c.read(mapVisibleProvider.notifier).set(false); // Map not the active tab
    c.read(pointMeActiveProvider.notifier).set(true); // PointMe screen open
    c.read(pointMeControllerProvider);
    c.read(pointMeTargetProvider.notifier).set(_target);
    await c.read(locationControllerProvider.notifier).onLocateTapped();
    loc.emit(
        UserLocationFix(position: MapConfig.campusCentre, accuracyMeters: 8));
    await Future<void>.delayed(Duration.zero);
    expect(c.read(pointMeControllerProvider).hasFix, isTrue); // GPS not paused
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

- [ ] **Step 3a: Widen the Phase A GPS gate** — in `lib/services/location_providers.dart` add, next to `mapVisibleProvider`:
```dart
/// True while a PointMeScreen is open. GPS must stay alive off the Map tab, so
/// this is OR'd into the location gate below. Same tiny-notifier shape.
final pointMeActiveProvider =
    NotifierProvider<PointMeActiveNotifier, bool>(PointMeActiveNotifier.new);

class PointMeActiveNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool active) {
    if (state != active) state = active;
  }
}
```
In `LocationController.build()` add `ref.listen(pointMeActiveProvider, (_, _) => _sync());`, and in `_sync()` widen the gate:
```dart
    final wantStream = state.active &&
        (ref.read(mapVisibleProvider) || ref.read(pointMeActiveProvider));
```
(The existing "hidden map drops follow" branch is unchanged; Phase A's `hidden map pauses` test still passes because `pointMeActive` defaults false.)

- [ ] **Step 3b: Implement** — `lib/services/point_me_controller.dart`:
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
    this.locationReliable = false,
  });
  final HeadingAvailability availability;
  final double? relativeAngleDegrees;
  final double? trueBearingDegrees;
  final double? distanceMeters;
  final bool nearTarget;
  final bool hasFix;
  final bool locationReliable;
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
  int _generation = 0; // discards late callbacks from a replaced/cancelled stream
  HeadingAvailability _availability = HeadingAvailability.acquiring;
  double? _magneticHeading;

  @override
  PointMeState build() {
    ref.onDispose(() => unawaited(_sub?.cancel()));
    ref.listen(pointMeTargetProvider, (_, target) => _onTargetChanged(target));
    ref.listen(locationControllerProvider, (_, _) => _recompute());
    _subscribe(ref.read(pointMeTargetProvider)); // subscribe ONLY — no state write
    return _compute(); // build RETURNS the initial state, never assigns `state`
  }

  void _onTargetChanged(LatLng? target) {
    _subscribe(target);
    _recompute(); // listener path may assign state (build is done)
  }

  /// (Re)subscribe to heading for [target]; a generation token makes any late
  /// event from the previous (cancelled) stream a no-op, avoiding a race.
  void _subscribe(LatLng? target) {
    unawaited(_sub?.cancel());
    _sub = null;
    final gen = ++_generation;
    _availability = HeadingAvailability.acquiring;
    _magneticHeading = null;
    if (target != null) {
      _sub = ref.read(headingServiceProvider).watch().listen((s) {
        if (gen != _generation) return; // stale session
        _availability = s.availability;
        _magneticHeading = s.magneticHeadingDegrees;
        _recompute();
      }, onError: (_) {
        if (gen != _generation) return;
        _availability = HeadingAvailability.unavailable;
        _magneticHeading = null;
        _recompute();
      });
    }
  }

  void _recompute() => state = _compute();

  PointMeState _compute() {
    final target = ref.read(pointMeTargetProvider);
    final fix = ref.read(locationControllerProvider).fix;
    if (target == null || fix == null) {
      return PointMeState(availability: _availability, hasFix: fix != null);
    }
    final reliable = !fix.isLowAccuracy; // Phase A: >200 m ⇒ unreliable
    final distance = distanceBetweenMeters(fix.position, target);
    // Near-target short-circuits direction: bearing is ill-defined at ~0 range,
    // and a low-accuracy fix must never claim "you're here".
    if (reliable && distance <= MapConfig.pointMeNearTargetMeters) {
      return PointMeState(
        availability: _availability,
        distanceMeters: distance,
        nearTarget: true,
        hasFix: true,
        locationReliable: true,
      );
    }
    final bearing = trueBearingDegrees(fix.position, target);
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
      nearTarget: false,
      hasFix: true,
      locationReliable: reliable,
    );
  }
}
```
`unawaited` + `StreamSubscription` come from `dart:async`; `LatLng`/`normalizeBearing` from `latlong2`. The test overrides `headingServiceProvider`/`locationServiceProvider` with fakes; `main` overrides `headingServiceProvider` with `SensorsHeadingService()` (Task 8). `PointMeScreen` (Task 7) sets `pointMeTargetProvider`+`pointMeActiveProvider` on open and clears both on dispose/`paused`.

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
  "pointMeImprovingAccuracy": "Your location is a bit rough right now — here's the rough direction. It'll sharpen as GPS settles.",
  "@pointMeImprovingAccuracy": { "description": "Shown when the fix is low-accuracy (>200 m)" },
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
  "pointMeImprovingAccuracy": "موقعیت شما اکنون کمی نادقیق است — جهت تقریبی این است و با تثبیت GPS دقیق‌تر می‌شود.",
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

**Interfaces:** `PointMeScreen({required String venueId})` (`ConsumerStatefulWidget`). Resolves target from `VenuesData.byId`/`ParkingData.byId`; unknown → safe message. Sets `pointMeTargetProvider`+`pointMeActiveProvider` on open, clears on dispose/background, locks portrait. Renders unknown / no-fix(+Enable) / near / low-accuracy / arrow / acquiring / fallback states. Motion-aware, non-liveRegion a11y label.

- [ ] **Step 1: Write the failing test** — `test/widget/point_me_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  return c;
}

Widget _app(ProviderContainer c, String venueId,
        {Locale? locale, bool reduceMotion = false}) =>
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        // Preserve ambient MediaQuery (size, textScaler) and only flip the flag.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: PointMeScreen(venueId: venueId),
      ),
    );

const _venueId = 'macquarie-theatre'; // a real venue id with coordinates

Future<void> _fix(ProviderContainer c, FakeLocationService loc,
    {double acc = 8}) async {
  await c.read(locationControllerProvider.notifier).onLocateTapped();
  loc.emit(UserLocationFix(position: MapConfig.campusCentre, accuracyMeters: acc));
  await Future<void>.delayed(Duration.zero);
}

Future<void> _heading(WidgetTester t, FakeHeadingService h, double deg) async {
  h.emit(HeadingSample(
      availability: HeadingAvailability.available, magneticHeadingDegrees: deg));
  await t.pump();
  await t.pump();
}

void main() {
  testWidgets('unknown venue → safe message, no target claimed, no crash',
      (t) async {
    final c = _c(FakeHeadingService(), FakeLocationService());
    await t.pumpWidget(_app(c, 'does-not-exist'));
    await t.pump();
    expect(find.textContaining("can't find"), findsOneWidget);
    expect(c.read(pointMeActiveProvider), isFalse); // no lifecycle claim
    expect(t.takeException(), isNull);
  });

  testWidgets('opening the screen claims pointMeActive; leaving clears it',
      (t) async {
    final c = _c(FakeHeadingService(), FakeLocationService());
    await t.pumpWidget(_app(c, _venueId));
    await t.pump();
    expect(c.read(pointMeActiveProvider), isTrue);
    await t.pumpWidget(const SizedBox()); // dispose the screen
    await t.pump();
    expect(c.read(pointMeActiveProvider), isFalse);
  });

  testWidgets('no fix → needs-location message + Enable button that activates',
      (t) async {
    final c = _c(FakeHeadingService(), FakeLocationService());
    await t.pumpWidget(_app(c, _venueId));
    await t.pump();
    expect(find.textContaining('Turn on location'), findsOneWidget);
    await t.tap(find.byKey(const Key('point-me-enable')));
    await t.pump();
    expect(c.read(locationControllerProvider).active, isTrue); // onLocateTapped
  });

  testWidgets('heading available → arrow shown with a non-liveRegion a11y label',
      (t) async {
    final handle = t.ensureSemantics();
    final h = FakeHeadingService();
    final loc = FakeLocationService();
    final c = _c(h, loc);
    await t.pumpWidget(_app(c, _venueId));
    await _fix(c, loc);
    await _heading(t, h, 0);
    expect(find.byKey(const Key('point-me-arrow')), findsOneWidget);
    final node = t.getSemantics(find.byKey(const Key('point-me-arrow')));
    final data = node.getSemanticsData();
    expect(data.hasFlag(SemanticsFlag.isLiveRegion), isFalse); // no announce spam
    expect(data.label, contains('Macquarie Theatre'));
    expect(data.label, contains('m')); // distance present
    handle.dispose();
  });

  testWidgets('turning the phone updates the a11y label (side follows heading)',
      (t) async {
    final handle = t.ensureSemantics();
    final h = FakeHeadingService();
    final loc = FakeLocationService();
    final c = _c(h, loc);
    await t.pumpWidget(_app(c, _venueId));
    await _fix(c, loc);
    await _heading(t, h, 0);
    final a = t.getSemantics(find.byKey(const Key('point-me-arrow'))).label;
    await _heading(t, h, 180); // turn around
    final b = t.getSemantics(find.byKey(const Key('point-me-arrow'))).label;
    expect(a, isNot(equals(b))); // side/label tracks the sensor
    handle.dispose();
  });

  testWidgets('reduced motion: arrow does NOT use an implicit rotation tween',
      (t) async {
    final h = FakeHeadingService();
    final loc = FakeLocationService();
    final c = _c(h, loc);
    await t.pumpWidget(_app(c, _venueId, reduceMotion: true));
    await _fix(c, loc);
    await _heading(t, h, 30);
    expect(find.byKey(const Key('point-me-arrow')), findsOneWidget); // still reorients
    expect(find.byType(AnimatedRotation), findsNothing); // snap, not tween
  });

  testWidgets('motion on: arrow uses AnimatedRotation', (t) async {
    final h = FakeHeadingService();
    final loc = FakeLocationService();
    final c = _c(h, loc);
    await t.pumpWidget(_app(c, _venueId));
    await _fix(c, loc);
    await _heading(t, h, 30);
    expect(find.byType(AnimatedRotation), findsOneWidget);
  });

  testWidgets('low-accuracy fix → improving-accuracy note, no arrow', (t) async {
    final h = FakeHeadingService();
    final loc = FakeLocationService();
    final c = _c(h, loc);
    await t.pumpWidget(_app(c, _venueId));
    await _fix(c, loc, acc: 250); // > 200 m ⇒ unreliable
    await _heading(t, h, 0);
    expect(find.byKey(const Key('point-me-arrow')), findsNothing);
    expect(find.textContaining('accuracy'), findsOneWidget);
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
    await _heading(t, h, 30);
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

- [ ] **Step 3: Implement** — `lib/screens/point_me_screen.dart`:
```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/data/parking_data.dart';
import 'package:aon2026/data/venues_data.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/services/heading_service.dart';
import 'package:aon2026/services/location_providers.dart';
import 'package:aon2026/services/point_me_controller.dart';
import 'package:aon2026/widgets/bearing_math.dart';

class PointMeScreen extends ConsumerStatefulWidget {
  const PointMeScreen({required this.venueId, super.key});
  final String venueId;
  @override
  ConsumerState<PointMeScreen> createState() => _PointMeScreenState();
}

class _PointMeScreenState extends ConsumerState<PointMeScreen> {
  LatLng? _target;
  String? _placeName;
  AppLifecycleListener? _lifecycle;
  // Captured up front so lifecycle callbacks (incl. dispose) never touch `ref`
  // after the element is deactivated. The providers outlive this widget.
  PointMeTargetNotifier? _targetNotifier;
  PointMeActiveNotifier? _activeNotifier;

  @override
  void initState() {
    super.initState();
    final v = VenuesData.byId(widget.venueId);
    if (v != null && v.hasCoordinates) {
      _target = LatLng(v.latitude!, v.longitude!);
      _placeName = v.name;
    } else {
      final p = ParkingData.byId(widget.venueId);
      if (p != null && p.hasCoordinates) {
        _target = LatLng(p.latitude!, p.longitude!);
        _placeName = p.name;
      }
    }
    if (_target != null) {
      _targetNotifier = ref.read(pointMeTargetProvider.notifier);
      _activeNotifier = ref.read(pointMeActiveProvider.notifier);
      // Heading math assumes portrait (natural == display); hold it here.
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      WidgetsBinding.instance.addPostFrameCallback((_) => _claim());
      _lifecycle = AppLifecycleListener(onStateChange: (s) {
        if (s == AppLifecycleState.resumed) {
          _claim();
        } else if (s == AppLifecycleState.paused ||
            s == AppLifecycleState.inactive) {
          _release();
        }
      });
    }
  }

  void _claim() {
    if (!mounted || _target == null) return;
    _targetNotifier!.set(_target);
    _activeNotifier!.set(true);
  }

  void _release() {
    _targetNotifier?.set(null);
    _activeNotifier?.set(false);
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    _release(); // uses captured notifiers, not ref
    SystemChrome.setPreferredOrientations(
        const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    super.dispose();
  }

  String _distance(AonL10n l, double m) => m < 1000
      ? l.pointMeDistanceMeters(m.round())
      : l.pointMeDistanceKm((m / 1000).toStringAsFixed(1));

  String _cardinal(AonL10n l, double trueBearing) =>
      switch (cardinalFor(trueBearing)) {
        Cardinal.n => l.cardinalN,
        Cardinal.ne => l.cardinalNE,
        Cardinal.e => l.cardinalE,
        Cardinal.se => l.cardinalSE,
        Cardinal.s => l.cardinalS,
        Cardinal.sw => l.cardinalSW,
        Cardinal.w => l.cardinalW,
        Cardinal.nw => l.cardinalNW,
      };

  String _side(AonL10n l, double rel) {
    final a = rel.abs();
    if (a < 20) return l.sideAhead;
    if (a > 160) return l.sideBehind;
    return rel > 0 ? l.sideRight : l.sideLeft;
  }

  @override
  Widget build(BuildContext context) {
    final l = AonL10n.of(context);
    if (_target == null) {
      return _scaffold(l, _message(context, l.pointMeUnknownPlace));
    }
    final s = ref.watch(pointMeControllerProvider);
    final name = _placeName ?? widget.venueId;
    final reduce = MediaQuery.disableAnimationsOf(context);

    final Widget body;
    if (!s.hasFix) {
      body = Column(mainAxisSize: MainAxisSize.min, children: [
        Text(l.pointMeNeedsLocation,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AonSpacing.space4),
        FilledButton.icon(
          key: const Key('point-me-enable'),
          onPressed: () =>
              ref.read(locationControllerProvider.notifier).onLocateTapped(),
          icon: const Icon(Icons.my_location_rounded),
          label: Text(l.locateShow),
        ),
      ]);
    } else if (s.nearTarget) {
      body = _message(context, l.pointMeNearby, icon: Icons.place_rounded);
    } else if (!s.locationReliable) {
      // Fuzzy fix: cardinal + distance, honest note, no precise arrow.
      body = _bearingCard(context, l,
          sentence: l.pointMeBearingSentence(
              name, _distance(l, s.distanceMeters!), _cardinal(l, s.trueBearingDegrees!)),
          note: l.pointMeImprovingAccuracy);
    } else if (s.availability == HeadingAvailability.available &&
        s.relativeAngleDegrees != null) {
      body = _Arrow(
        semanticLabel: l.pointMeA11yDirection(
            name, _side(l, s.relativeAngleDegrees!), _distance(l, s.distanceMeters!)),
        angleDegrees: s.relativeAngleDegrees!,
        distance: _distance(l, s.distanceMeters!),
        cardinal: _cardinal(l, s.trueBearingDegrees!),
        reduceMotion: reduce,
      );
    } else if (s.availability == HeadingAvailability.acquiring) {
      body = _message(context, l.pointMeFindingNorth,
          icon: Icons.explore_rounded, dim: true);
    } else {
      // unsupported / unavailable → bearing fallback card
      body = _bearingCard(context, l,
          sentence: l.pointMeBearingSentence(
              name, _distance(l, s.distanceMeters!), _cardinal(l, s.trueBearingDegrees!)),
          note: l.pointMeNoCompass);
    }
    return _scaffold(l, body);
  }

  Widget _scaffold(AonL10n l, Widget child) => Scaffold(
        appBar: AppBar(title: Text(l.pointMeTitle)),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AonSpacing.space5),
            child: Center(child: child),
          ),
        ),
      );

  Widget _message(BuildContext context, String text,
          {IconData icon = Icons.info_outline_rounded, bool dim = false}) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon,
            size: 48,
            color: dim ? context.aon.contentTertiary : context.aon.accent),
        const SizedBox(height: AonSpacing.space4),
        Text(text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium),
      ]);

  Widget _bearingCard(BuildContext context, AonL10n l,
          {required String sentence, required String note}) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.explore_outlined, size: 48, color: context.aon.accent),
        const SizedBox(height: AonSpacing.space4),
        Text(sentence,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AonSpacing.space3),
        Text(note,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: context.aon.contentSecondary)),
      ]);
}

/// The live arrow. The rotation IS essential state, so under reduced motion it
/// snaps (plain Transform.rotate) rather than easing (AnimatedRotation) — but it
/// still reorients. One non-liveRegion Semantics node carries the spoken label.
class _Arrow extends StatelessWidget {
  const _Arrow({
    required this.semanticLabel,
    required this.angleDegrees,
    required this.distance,
    required this.cardinal,
    required this.reduceMotion,
  });
  final String semanticLabel;
  final double angleDegrees;
  final String distance;
  final String cardinal;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final turns = angleDegrees / 360.0;
    final icon = Icon(Icons.navigation_rounded,
        size: 140, color: context.aon.accent);
    final rotated = reduceMotion
        ? Transform.rotate(angle: angleDegrees * math.pi / 180, child: icon)
        : AnimatedRotation(
            turns: turns,
            duration: const Duration(milliseconds: 220),
            child: icon);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      // liveRegion:false (default) — do NOT announce on every sensor tick.
      Semantics(
        key: const Key('point-me-arrow'),
        label: semanticLabel,
        excludeSemantics: true,
        child: rotated,
      ),
      const SizedBox(height: AonSpacing.space5),
      Text(distance, style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: AonSpacing.space2),
      Text(cardinal,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: context.aon.contentSecondary)),
    ]);
  }
}
```
(`Uri.encodeComponent` on the route id is Task 8. The `_Arrow` keys the Semantics node — `getSemantics(byKey('point-me-arrow'))` reads the label; `excludeSemantics` keeps it a single node; `liveRegion` stays false so screen readers aren't flooded.)

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

- [ ] **Step 2: Add the route** — in `lib/app/router/app_router.dart`, mirror the existing `panoramaFor` registration. The helper **encodes the id** (the helper owns that boundary, even though today's ids are URL-safe):
```dart
static String pointMeTo(String id) => '/point-me/${Uri.encodeComponent(id)}';
```
and a `GoRoute(path: '/point-me/:id', builder: (_, state) => PointMeScreen(venueId: state.pathParameters['id']!))`.

- [ ] **Step 3: Write the failing entry test** — `test/widget/point_me_entry_test.dart` (mirror the repo's venue-sheet test harness). Three cases: (a) `VenueSheet(venueId: 'macquarie-theatre')` shows "Point me there" and tapping it pushes the point-me route; (b) `ParkingSheet(parkingId: <a parking id with coords>)` also shows it and navigates; (c) a subject **without** coordinates does **NOT** show the button (`find.text(l.pointMeTitle)` → `findsNothing`).

- [ ] **Step 4: Wire the button** — in `VenueSheet` add a button peer to "Walking directions", shown only when `venue.hasCoordinates`:
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
And the same in `ParkingSheet`, gated on `parking.hasCoordinates`, using `Routes.pointMeTo(parking.id)` (PointMeScreen resolves either id via VenuesData→ParkingData).

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
- [ ] **Step 4: Closeout** — append: resolved `sensors_plus` version, the WMM2025 declination receipt (Task 0), all three build results, the on-device checklist result, and a **split status**:
  - **IMPLEMENTATION COMPLETE** — analyze/tests green, all three builds green, on-device compass verified (iOS/Android).
  - **WEB RELEASE READY — NOT claimed.** The web *build* is green, but the web bearing/distance *fallback* is **not runtime-verified**: the app's pre-existing web black-screen (Phase A closeout) means `PointMeScreen` is not reachable on web today. A green `flutter build web` proves compilation, not the web fallback path. This stays blocked on the separate web-black-screen triage.
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

**2. Placeholder scan** — clean. **One** intentional fill: `MapConfig.campusMagneticDeclinationDegrees = <VALUE FROM TASK 0>`, replaced with the WMM2025 number Task 0 computes (Task 2 Step 5 says so). Task 7's screen is now written in full (all states: unknown / no-fix+Enable / near / low-accuracy / arrow / acquiring / fallback), plus its `_Arrow`. No described-not-written steps remain.

**3. Type consistency** — `Vector3`, `tiltCompensatedHeadingDegrees`, `CircularSmoother`, `HeadingAvailability{acquiring,available,unavailable,unsupported}`, `HeadingSample{availability,magneticHeadingDegrees}`, `HeadingService.watch()`, `headingServiceProvider`, `PointMeState{availability,relativeAngleDegrees,trueBearingDegrees,distanceMeters,nearTarget,hasFix,locationReliable}`, `pointMeTargetProvider` (`.set(LatLng?)`), `pointMeActiveProvider` (`.set(bool)`, in `location_providers.dart`), `pointMeControllerProvider` (plain `NotifierProvider` — no family/autoDispose, verified vs Riverpod 3.4.2), `trueBearingDegrees`/`relativeAngleDegrees`/`distanceBetweenMeters`/`cardinalFor`/`Cardinal`, `MapConfig.{campusMagneticDeclinationDegrees,pointMeNearTargetMeters}`, `Routes.pointMeTo`, `l.pointMe*`/`l.cardinal*`/`l.side*`/`l.pointMeImprovingAccuracy` — consistent across tasks. Shared fakes: `test/support/fake_heading_service.dart` + Phase A's `fake_location_service.dart`.

---

## Notes for the executor

- **All three builds are the hard gate at Task 1** — `sensors_plus` requires AGP ≥8.12.1 (repo was 8.11.1 → bumped) and its web support is the `flutter_compass` risk; prove web + APK + iOS the moment the dep + AGP bump land, before any feature code.
- **iOS `NSMotionUsageDescription` is mandatory** (sensors_plus ≥6.0.0) — omission crashes on motion access. It's in Task 1.
- **The heading math mirrors Android `getRotationMatrix`/`getOrientation`.** The Task 3 test values are hand-verified (north/east/tilt/degenerate); if one fails, the impl deviated from the cross-product order — fix the impl, don't loosen the test.
- **Orientation:** heading is computed in the device's natural frame; `PointMeScreen` **locks portrait** so natural==display on phones. Landscape-natural/rotated (iPad) axis remap is **IOU-B4** — the arrow isn't trusted there yet.
- **Location demand:** PointMe is its own route, so the Phase A GPS gate is widened to `active && (mapVisible || pointMeActive)`. Don't skip Task 5 Step 3a or a deep-linked PointMe has frozen distance.
- **Sensor failure is terminal for the session** (cancel both streams, clear, emit `unavailable`) with acquisition + staleness timeouts — never resurrect the arrow from stale accel. Smoother is per-`watch()`.
- **`sensors_plus` 7.x stream names:** prefer `magnetometerEventStream({samplingPeriod})`/`accelerometerEventStream(...)` (non-deprecated). Confirm against the installed package before Task 4's impl.
- **Never invent coordinates** — unknown venue id is a safe state, never a campus-centre fallback. **Never claim `nearTarget` on a low-accuracy fix.**
- **Reduced motion** drops the arrow's easing tween (snap) but the arrow still reorients — it is essential live state, not decoration.
- **Web runtime is NOT release-ready** — the pre-existing web black-screen (Phase A closeout) means the web fallback path is unverified at runtime; the web *build* gate still applies. Keep IMPLEMENTATION COMPLETE and WEB RELEASE READY split in the closeout.
- Never weaken an existing test to make Phase B pass.
