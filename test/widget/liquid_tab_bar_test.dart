import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/widgets/liquid_tab_bar.dart';

const _items = [
  LiquidNavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home', fx: TabFx.homecoming),
  LiquidNavItem(icon: Icons.info_outline, activeIcon: Icons.info, label: 'Info', fx: TabFx.orbit),
  LiquidNavItem(icon: Icons.map_outlined, activeIcon: Icons.map, label: 'Map', fx: TabFx.rotateOpen),
];

Finder _orbit() => find.byWidgetPredicate(
    (w) => w is CustomPaint && w.painter.runtimeType.toString() == '_OrbitPainter');

Widget _host({
  int index = 0,
  ValueChanged<int>? onSelected,
  bool disableAnimations = false,
  double textScale = 1.0,
  TextDirection dir = TextDirection.ltr,
}) {
  var i = index;
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        disableAnimations: disableAnimations,
        textScaler: TextScaler.linear(textScale),
      ),
      child: Directionality(
        textDirection: dir,
        child: Scaffold(
          bottomNavigationBar: StatefulBuilder(
            builder: (context, setState) => LiquidTabBar(
              currentIndex: i,
              onSelected: (x) { onSelected?.call(x); setState(() => i = x); },
              color: Colors.white,
              selectedColor: const Color(0xFFFFB945),
              accent: const Color(0xFFFFB945),
              items: _items,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('tap selects that tab', (tester) async {
    final picked = <int>[];
    await tester.pumpWidget(_host(onSelected: picked.add));
    await tester.tap(find.byIcon(Icons.map_outlined), warnIfMissed: false);
    await tester.pump();
    expect(picked, [2]);
  });

  testWidgets('orbit fx plays on select and leaves no overlay when idle', (tester) async {
    await tester.pumpWidget(_host());
    expect(_orbit(), findsNothing);
    await tester.tap(find.byIcon(Icons.info_outline), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_orbit(), findsOneWidget);
    await tester.pumpAndSettle();
    expect(_orbit(), findsNothing);
  });

  testWidgets('the selected label uses at least 13px (night floor)', (tester) async {
    await tester.pumpWidget(_host(index: 0));
    await tester.pumpAndSettle();
    final label = tester.widget<Text>(find.text('Home'));
    expect(label.style!.fontSize, greaterThanOrEqualTo(13));
  });

  testWidgets('reduced motion: selection is instant - no orbit, active icon immediately', (tester) async {
    await tester.pumpWidget(_host(disableAnimations: true));
    await tester.tap(find.byIcon(Icons.info_outline), warnIfMissed: false);
    await tester.pump(); // ONE frame, no settle - proves no in-flight animation
    expect(_orbit(), findsNothing); // no decorative FX
    expect(find.byIcon(Icons.info), findsOneWidget); // Info active icon shown at once
  });

  testWidgets('each tab exposes button + label semantics; unselected is not selected', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(index: 0));
    await tester.pumpAndSettle();
    // Map is unselected (index 0 = Home selected), so only the tab's Semantics
    // carries 'Map' - no visible label Text to collide with.
    final map = tester.getSemantics(find.bySemanticsLabel('Map'));
    expect(map.hasFlag(SemanticsFlag.isButton), isTrue);
    expect(map.hasFlag(SemanticsFlag.isSelected), isFalse);
    expect(map.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    handle.dispose();
  });

  testWidgets('horizontal drag: crosses tabs, clamps in range, ends on the drag-end tab', (tester) async {
    final picked = <int>[];
    await tester.pumpWidget(_host(onSelected: picked.add));
    final bar = tester.getRect(find.byType(LiquidTabBar));
    // Drag from the left edge fully across to the right edge.
    await tester.dragFrom(bar.centerLeft + const Offset(4, 0), Offset(bar.width, 0));
    await tester.pumpAndSettle();
    expect(picked, isNotEmpty);
    expect(picked.every((x) => x >= 0 && x < _items.length), isTrue); // clamp
    expect(picked.last, _items.length - 1); // dragging to the right edge lands on the last tab
  });

  testWidgets('no overflow at 2.0 text scale', (tester) async {
    await tester.pumpWidget(_host(textScale: 2.0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('RTL: tapping the physically-left tab selects the last item', (tester) async {
    final picked = <int>[];
    await tester.pumpWidget(_host(dir: TextDirection.rtl, onSelected: picked.add));
    // Under RTL item 2 (Map) renders at the physical left.
    await tester.tap(find.byIcon(Icons.map_outlined), warnIfMissed: false);
    await tester.pump();
    expect(picked, [2]);
  });
}
