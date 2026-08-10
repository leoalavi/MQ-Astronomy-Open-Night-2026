import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/widgets/liquid_tab_bar.dart';

void main() {
  testWidgets('Home last item clears the floating island after scrolling', (tester) async {
    tester.view.physicalSize = const Size(390, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp.router(theme: AonTheme.build(), routerConfig: buildRouter()),
    ));
    await tester.pumpAndSettle();

    // Jump to the TRUE maximum scroll extent (a fling can under-scroll and
    // false-pass). This pins the content bottom to the viewport bottom.
    //
    // Home's bottom lives in a lazily-built sliver, so maxScrollExtent grows as
    // those children are realised on scroll-in — a single jump can under-shoot.
    // Loop until the reported max stops changing so we land on the real bottom.
    final state = tester.state<ScrollableState>(find.byType(Scrollable).first);
    var previousMax = -1.0;
    while (state.position.maxScrollExtent != previousMax) {
      previousMax = state.position.maxScrollExtent;
      state.position.jumpTo(state.position.maxScrollExtent);
      await tester.pumpAndSettle();
    }

    // The CRICOS line is the LAST text in Home's attribution card (its true
    // bottom edge), so it is the right occlusion anchor.
    final last = find.textContaining('CRICOS');
    expect(last, findsOneWidget);
    final lastBottom = tester.getRect(last).bottom;
    final barTop = tester.getRect(find.byType(LiquidTabBar)).top;
    expect(lastBottom, lessThanOrEqualTo(barTop),
        reason: 'last item must sit above the floating glass island');
  });
}
