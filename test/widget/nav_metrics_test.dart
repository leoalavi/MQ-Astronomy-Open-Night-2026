import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/widgets/nav_metrics.dart';

void main() {
  testWidgets('clearance = bar height + padding + gap + safe-area bottom', (tester) async {
    late double clearance;
    late double barH;
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(padding: EdgeInsets.only(bottom: 34)),
        child: Builder(builder: (context) {
          barH = AonNavMetrics.resolvedBarHeight(context);
          clearance = AonNavMetrics.clearance(context);
          return const SizedBox();
        }),
      ),
    ));
    // >= (not ==): if measure-first later makes the height scale-aware, this
    // test must not force it back to the constant.
    expect(barH, greaterThanOrEqualTo(AonNavMetrics.barHeight));
    // Clearance is computed from the RESOLVED height, so it survives adaptation:
    // barH + 12 outer + 12 gap + 34 safe-area.
    expect(clearance, closeTo(barH + 12 + 12 + 34, 0.01));
  });
}
