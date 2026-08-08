import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/app/theme/aon_colors.dart';
import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/models/venue.dart';
import 'package:aon2026/widgets/glass_surface.dart';
import 'package:aon2026/widgets/map_category_filter_bar.dart';

void main() {
  Widget harness({
    required Set<VenueCategory> selected,
    ValueChanged<VenueCategory>? onToggle,
    double scale = 1.0,
  }) {
    return MaterialApp(
      theme: AonTheme.build(),
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Align(
            alignment: Alignment.topCenter,
            child: MapCategoryFilterBar(
              selected: selected,
              onToggle: onToggle ?? (_) {},
            ),
          ),
        ),
      ),
    );
  }

  // The first chips in the bar — always built by the lazy horizontal ListView
  // (later chips are offscreen and not instantiated). eventVenue is first,
  // informationPoint second; neither is `other`.
  const parking = 'Event venue';
  const toilets = 'Information point';
  const parkingCat = VenueCategory.eventVenue;

  testWidgets('unselected chip is glass', (tester) async {
    await tester.pumpWidget(harness(selected: const {}));
    final glass = find.ancestor(
      of: find.text(parking),
      matching: find.byType(GlassSurface),
    );
    expect(glass, findsOneWidget);
  });

  testWidgets('selected chip is solid amber (no glass)', (tester) async {
    await tester.pumpWidget(harness(selected: {parkingCat}));
    final glass = find.ancestor(
      of: find.text(parking),
      matching: find.byType(GlassSurface),
    );
    expect(glass, findsNothing); // solid, not glass
    final label = tester.widget<Text>(find.text(parking));
    expect(label.style?.color, AonColors.onAccent); // brand-on-amber
  });

  testWidgets('tapping a chip fires onToggle with its category', (tester) async {
    VenueCategory? toggled;
    await tester.pumpWidget(harness(selected: const {}, onToggle: (c) => toggled = c));
    await tester.tap(find.text(parking));
    expect(toggled, parkingCat);
  });

  testWidgets('chip hit target >= 56 at 1.0 and 2.0', (tester) async {
    for (final scale in [1.0, 2.0]) {
      await tester.pumpWidget(harness(selected: const {}, scale: scale));
      final ink = find.ancestor(of: find.text(parking), matching: find.byType(InkWell));
      expect(tester.getSize(ink).height, greaterThanOrEqualTo(56.0), reason: 'scale $scale');
    }
  });

  testWidgets('one coherent semantics node per chip; selected flag tracks state',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(harness(selected: {parkingCat}));

    // Single node carries the label (no duplicate read from the inner Text).
    expect(find.bySemanticsLabel(parking), findsOneWidget);

    final selectedSem = tester.getSemantics(find.bySemanticsLabel(parking));
    final unselectedSem = tester.getSemantics(find.bySemanticsLabel(toilets));
    expect(selectedSem.flagsCollection.isButton, isTrue);
    // Avoid Tristate literals / deprecated APIs: selected differs from unselected.
    expect(selectedSem.flagsCollection.isSelected,
        isNot(unselectedSem.flagsCollection.isSelected));
    handle.dispose();
  });
}
