import 'package:flutter/material.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/widgets/liquid_tab_bar.dart';

const _items = [
  LiquidNavItem(
    icon: Icons.home_outlined,
    activeIcon: Icons.home,
    label: 'Home',
    fx: TabFx.homecoming,
  ),
  LiquidNavItem(
    icon: Icons.info_outline,
    activeIcon: Icons.info,
    label: 'Info',
    fx: TabFx.orbit,
  ),
  LiquidNavItem(
    icon: Icons.map_outlined,
    activeIcon: Icons.map,
    label: 'Map',
    fx: TabFx.rotateOpen,
  ),
];

// The real six-tab shell, with the long labels that overran the pill.
const _sixItems = [
  LiquidNavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home', fx: TabFx.homecoming),
  LiquidNavItem(icon: Icons.list_alt_outlined, activeIcon: Icons.list_alt, label: 'Program', fx: TabFx.bounce),
  LiquidNavItem(icon: Icons.star_outline_rounded, activeIcon: Icons.star_rounded, label: 'My Night', fx: TabFx.spin),
  LiquidNavItem(icon: Icons.map_outlined, activeIcon: Icons.map, label: 'Map', fx: TabFx.rotateOpen),
  LiquidNavItem(icon: Icons.info_outline_rounded, activeIcon: Icons.info_rounded, label: 'Info', fx: TabFx.orbit),
  LiquidNavItem(icon: Icons.settings_outlined, activeIcon: Icons.settings_rounded, label: 'Settings', fx: TabFx.rotateOpen),
];

Widget _host6({
  required int index,
  double textScale = 1.0,
  TextDirection dir = TextDirection.ltr,
  List<LiquidNavItem> items = _sixItems,
  double width = 390, // an iPhone-ish width where the pill is tightest
}) =>
    MaterialApp(
      localizationsDelegates: AonL10n.localizationsDelegates,
      supportedLocales: AonL10n.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Directionality(
          textDirection: dir,
          child: Scaffold(
            bottomNavigationBar: SizedBox(
              width: width,
              child: LiquidTabBar(
                currentIndex: index,
                onSelected: (_) {},
                color: Colors.white,
                selectedColor: const Color(0xFFFFB945),
                accent: const Color(0xFFFFB945),
                items: items,
              ),
            ),
          ),
        ),
      ),
    );

/// The active halo must horizontally CONTAIN the selected label — no protruding
/// text (MAP #8). Compares the painted rects with a 0.5px tolerance.
void _expectLabelInsideHalo(WidgetTester t, String label) {
  final lens = t.getRect(find.byKey(const ValueKey('tab-active-lens')));
  final text = t.getRect(find.text(label));
  expect(text.left, greaterThanOrEqualTo(lens.left - 0.5),
      reason: '"$label" left edge pokes out of the halo');
  expect(text.right, lessThanOrEqualTo(lens.right + 0.5),
      reason: '"$label" right edge pokes out of the halo');
}

Finder _orbit() => find.byWidgetPredicate(
  (w) =>
      w is CustomPaint && w.painter.runtimeType.toString() == '_OrbitPainter',
);

Widget _host({
  int index = 0,
  ValueChanged<int>? onSelected,
  bool disableAnimations = false,
  double textScale = 1.0,
  TextDirection dir = TextDirection.ltr,
}) {
  var i = index;
  return MaterialApp(
    localizationsDelegates: AonL10n.localizationsDelegates,
    supportedLocales: AonL10n.supportedLocales,
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
              onSelected: (x) {
                onSelected?.call(x);
                setState(() => i = x);
              },
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

  testWidgets('orbit fx plays on select and leaves no overlay when idle', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    expect(_orbit(), findsNothing);
    await tester.tap(find.byIcon(Icons.info_outline), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_orbit(), findsOneWidget);
    await tester.pumpAndSettle();
    expect(_orbit(), findsNothing);
  });

  testWidgets('the selected label uses at least 13px (night floor)', (
    tester,
  ) async {
    await tester.pumpWidget(_host(index: 0));
    await tester.pumpAndSettle();
    final label = tester.widget<Text>(find.text('Home'));
    expect(label.style!.fontSize, greaterThanOrEqualTo(13));
  });

  testWidgets(
    'reduced motion: selection is instant - no orbit, active icon immediately',
    (tester) async {
      await tester.pumpWidget(_host(disableAnimations: true));
      await tester.tap(find.byIcon(Icons.info_outline), warnIfMissed: false);
      await tester
          .pump(); // ONE frame, no settle - proves no in-flight animation
      expect(_orbit(), findsNothing); // no decorative FX
      expect(
        find.byIcon(Icons.info),
        findsOneWidget,
      ); // Info active icon shown at once
    },
  );

  testWidgets('every tab is an accessible labelled button', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(index: 0));
    await tester.pumpAndSettle();
    // Unselected tabs (Info, Map at index 0) expose a clean accessible label
    // to VoiceOver/TalkBack and are announced as buttons. (The selected tab
    // merges its label with its visible Text; its selected-state is covered by
    // the label-visibility + shell active-icon tests.)
    for (final label in ['Info', 'Map']) {
      expect(find.bySemanticsLabel(label), findsWidgets);
    }
    final map = tester.getSemantics(find.bySemanticsLabel('Map'));
    expect(map.flagsCollection.isButton, isTrue);
    handle.dispose();
  });

  testWidgets(
    'horizontal drag: crosses tabs, clamps in range, ends on the drag-end tab',
    (tester) async {
      final picked = <int>[];
      await tester.pumpWidget(_host(onSelected: picked.add));
      final bar = tester.getRect(find.byType(LiquidTabBar));
      // Drag from the left edge fully across to the right edge.
      await tester.dragFrom(
        bar.centerLeft + const Offset(4, 0),
        Offset(bar.width, 0),
      );
      await tester.pumpAndSettle();
      expect(picked, isNotEmpty);
      expect(picked.every((x) => x >= 0 && x < _items.length), isTrue); // clamp
      expect(
        picked.last,
        _items.length - 1,
      ); // dragging to the right edge lands on the last tab
    },
  );

  testWidgets('no overflow at 2.0 text scale', (tester) async {
    await tester.pumpWidget(_host(textScale: 2.0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('MAP #8: the long "Settings" label is fully enclosed by the halo (EN)',
      (tester) async {
    await tester.pumpWidget(_host6(index: 5)); // Settings selected
    await tester.pumpAndSettle();
    _expectLabelInsideHalo(tester, 'Settings');
  });

  testWidgets('MAP #8: "My Night" is fully enclosed by the halo', (tester) async {
    await tester.pumpWidget(_host6(index: 2));
    await tester.pumpAndSettle();
    _expectLabelInsideHalo(tester, 'My Night');
  });

  testWidgets('MAP #8: a long Persian-style label is enclosed under RTL', (tester) async {
    const fa = [
      LiquidNavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'خانه', fx: TabFx.homecoming),
      LiquidNavItem(icon: Icons.list_alt_outlined, activeIcon: Icons.list_alt, label: 'برنامه', fx: TabFx.bounce),
      LiquidNavItem(icon: Icons.star_outline_rounded, activeIcon: Icons.star_rounded, label: 'شب من', fx: TabFx.spin),
      LiquidNavItem(icon: Icons.map_outlined, activeIcon: Icons.map, label: 'نقشه', fx: TabFx.rotateOpen),
      LiquidNavItem(icon: Icons.info_outline_rounded, activeIcon: Icons.info_rounded, label: 'اطلاعات', fx: TabFx.orbit),
      LiquidNavItem(icon: Icons.settings_outlined, activeIcon: Icons.settings_rounded, label: 'تنظیمات', fx: TabFx.rotateOpen),
    ];
    await tester.pumpWidget(_host6(index: 5, items: fa, dir: TextDirection.rtl));
    await tester.pumpAndSettle();
    _expectLabelInsideHalo(tester, 'تنظیمات');
  });

  testWidgets('MAP #8: still enclosed at 1.6 text scale', (tester) async {
    await tester.pumpWidget(_host6(index: 5, textScale: 1.6));
    await tester.pumpAndSettle();
    _expectLabelInsideHalo(tester, 'Settings');
    expect(tester.takeException(), isNull);
  });

  testWidgets('RTL: tapping the physically-left tab selects the last item', (
    tester,
  ) async {
    final picked = <int>[];
    await tester.pumpWidget(
      _host(dir: TextDirection.rtl, onSelected: picked.add),
    );
    // Under RTL item 2 (Map) renders at the physical left.
    await tester.tap(find.byIcon(Icons.map_outlined), warnIfMissed: false);
    await tester.pump();
    expect(picked, [2]);
  });
}
