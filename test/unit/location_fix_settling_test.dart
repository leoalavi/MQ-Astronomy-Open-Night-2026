import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:aon2026/models/user_location_fix.dart';
import 'package:aon2026/services/location_providers.dart';
import '../support/fake_location_service.dart';

// Field report (Pouya, 2026-08-28): on opening the map the location dot first
// appeared far off (top of the map, by the Sir Christopher intersection), then
// hopped three or four times — down, left, down — before settling on the real
// position. Cause: `_onFix` adopted EVERY raw fix, so coarse early cell/Wi-Fi
// fixes and same-accuracy GPS scatter each moved the dot. The settling policy
// keeps the sharpest fix seen and only moves the dot for a sharper fix or a
// genuine move beyond the fix's own uncertainty.

const _base = LatLng(-33.7737, 151.1134);
UserLocationFix _fix(LatLng p, double acc) =>
    UserLocationFix(position: p, accuracyMeters: acc);

ProviderContainer _c(FakeLocationService svc) {
  final c = ProviderContainer(overrides: [
    locationServiceProvider.overrideWithValue(svc),
  ]);
  addTearDown(c.dispose);
  c.read(mapVisibleProvider.notifier).set(true);
  return c;
}

void main() {
  group('shouldAdoptFix (pure policy)', () {
    test('first fix is always adopted (dot appears right away)', () {
      expect(shouldAdoptFix(null, _fix(_base, 500)), isTrue);
    });

    test('a strictly sharper fix is adopted (settling toward the truth)', () {
      final current = _fix(_base, 120);
      final sharper = _fix(const Distance().offset(_base, 80, 90), 8);
      expect(shouldAdoptFix(current, sharper), isTrue);
    });

    test('a coarser straggler within its own uncertainty is REJECTED', () {
      // current is a sharp 8 m fix; a 120 m-accuracy fix 40 m away cannot be
      // told apart from "same place, worse fix" — adopting it is the jump.
      final current = _fix(_base, 8);
      final straggler = _fix(const Distance().offset(_base, 40, 0), 120);
      expect(shouldAdoptFix(current, straggler), isFalse);
    });

    test('same-accuracy scatter within uncertainty is REJECTED (no jitter)', () {
      final current = _fix(_base, 8);
      final jitter = _fix(const Distance().offset(_base, 3, 270), 8);
      expect(shouldAdoptFix(current, jitter), isFalse);
    });

    test('genuine movement beyond uncertainty is adopted (tracks walking)', () {
      final current = _fix(_base, 8);
      final walked = _fix(const Distance().offset(_base, 40, 45), 8);
      expect(shouldAdoptFix(current, walked), isTrue);
    });
  });

  group('shouldAdoptFix — timed outlier rejection', () {
    // Field report (Pouya, 2026-08-28, around parking): the dot jumped ~150 m
    // between one-second samples. A move beyond the fix's own uncertainty alone
    // cannot tell a genuine step from a wild outlier — but the speed can, when
    // the platform stamps each fix with a time.
    UserLocationFix timed(LatLng p, double acc, DateTime t) =>
        UserLocationFix(position: p, accuracyMeters: acc, timestamp: t);
    final t0 = DateTime(2026, 9, 19, 18, 0, 0);

    test('a wild ~150 m jump one second later is REJECTED as an outlier', () {
      final current = timed(_base, 8, t0);
      final outlier = timed(const Distance().offset(_base, 150, 0), 8,
          t0.add(const Duration(seconds: 1)));
      expect(shouldAdoptFix(current, outlier), isFalse,
          reason: '150 m/s is not a person walking — do not teleport the dot');
    });

    test('a plausible walking step at the same cadence is still adopted', () {
      final current = timed(_base, 6, t0);
      // ~10 m in 5 s ≈ 2 m/s — an ordinary walking pace.
      final step = timed(const Distance().offset(_base, 10, 30), 6,
          t0.add(const Duration(seconds: 5)));
      expect(shouldAdoptFix(current, step), isTrue);
    });

    test('after an outlier is rejected, the next honest fix settles the dot',
        () {
      final current = timed(_base, 8, t0);
      final outlier = timed(const Distance().offset(_base, 150, 0), 8,
          t0.add(const Duration(seconds: 1)));
      expect(shouldAdoptFix(current, outlier), isFalse);
      // Dot stayed at _base; a fresh honest fix a short walk away is adopted.
      final recover = timed(const Distance().offset(_base, 12, 200), 8,
          t0.add(const Duration(seconds: 6)));
      expect(shouldAdoptFix(current, recover), isTrue);
    });

    test('a sharper outlier is still trusted (accuracy beats the speed gate)',
        () {
      // A much sharper fix is evidence in its own right; the gate only guards
      // the coarse-or-equal branch.
      final current = timed(_base, 30, t0);
      final sharpFar = timed(const Distance().offset(_base, 150, 0), 4,
          t0.add(const Duration(seconds: 1)));
      expect(shouldAdoptFix(current, sharpFar), isTrue);
    });

    test('without timestamps the distance-only rule is unchanged', () {
      final current = _fix(_base, 8);
      final far = _fix(const Distance().offset(_base, 150, 0), 8);
      expect(shouldAdoptFix(current, far), isTrue,
          reason: 'no time basis → keep the original move-adopt behaviour');
    });
  });

  test('controller: dot settles once and does not re-jump on stragglers',
      () async {
    final svc = FakeLocationService();
    final c = _c(svc);
    final n = c.read(locationControllerProvider.notifier);
    await n.onLocateTapped();

    // 1) A coarse first fix, far from the truth — shown immediately.
    final far = const Distance().offset(_base, 150, 0);
    svc.emit(_fix(far, 120));
    await Future<void>.delayed(Duration.zero);
    expect(c.read(locationControllerProvider).fix!.position, far);

    // 2) A sharp fix arrives — the ONE legitimate settle to the real position.
    svc.emit(_fix(_base, 8));
    await Future<void>.delayed(Duration.zero);
    expect(c.read(locationControllerProvider).fix!.position, _base);

    // 3) A coarse straggler 30 m away must NOT yank the settled dot.
    final straggler = const Distance().offset(_base, 30, 90);
    svc.emit(_fix(straggler, 150));
    await Future<void>.delayed(Duration.zero);
    expect(c.read(locationControllerProvider).fix!.position, _base,
        reason: 'settled dot should ignore a coarse straggler');
  });
}
