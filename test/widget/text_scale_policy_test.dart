import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/app/text_scale.dart';
import 'package:aon2026/main.dart';
import 'package:aon2026/widgets/liquid_tab_bar.dart';

void main() {
  // Compare scalers by the number they produce, not by TextScaler identity.
  double resolved(double os) =>
      resolveAppTextScaler(TextScaler.linear(os)).scale(100);

  test('policy function: floor 1.0, ceiling 2.0', () {
    expect(kMaxTextScale, 2.0);
    expect(resolved(0.5), 100); // below floor -> 1.0
    expect(resolved(1.0), 100);
    expect(resolved(1.6), 160); // passes through (exactly 160.0 — verified)
    expect(resolved(2.0), 200); // ceiling reached, not clipped
    expect(resolved(3.0), 200); // ceiling ENFORCED (would be 300 uncapped / 160 if reverted to 1.6)
  });

  // The steering-wheel test: proves the PRODUCTION app caps the effective scale
  // at 2.0, not just that the pure function is correct. Catches a revert of the
  // main.dart wiring (which the function test alone cannot see).
  testWidgets('app root caps effective text scale at 2.0', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 3.0; // OS asks for 3.0
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(const ProviderScope(child: AonApp()));
    await tester.pump(const Duration(milliseconds: 400));

    // Read the effective scale at a STABLE descendant of the app root — the
    // always-present LiquidTabBar — not an arbitrary "first Text" whose order
    // can change without changing the policy.
    final ctx = tester.element(find.byType(LiquidTabBar));
    expect(MediaQuery.textScalerOf(ctx).scale(100), 200);
  });
}
