import 'package:flutter/material.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/widgets/passport_grid.dart';

Widget _host(Set<String> collected, {void Function(String)? onTap}) =>
    MaterialApp(
      localizationsDelegates: AonL10n.localizationsDelegates,
      supportedLocales: AonL10n.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: PassportGrid(
            collectedVenueIds: collected,
            onTapCollected: onTap,
          ),
        ),
      ),
    );

void main() {
  testWidgets('a collected cell is a button and calls back on tap', (t) async {
    final handle = t
        .ensureSemantics(); // repo pattern (map_category_filter_bar_test:77)
    String? tapped;
    await t.pumpWidget(
      _host({'macquarie-theatre'}, onTap: (id) => tapped = id),
    );
    final cell = find.bySemanticsLabel(RegExp(r', stamp collected$'));
    expect(cell, findsOneWidget);
    // Button role via the repo's 3.44 API (aon_tactile_button_test:165).
    expect(
      t.getSemantics(cell).getSemanticsData().flagsCollection.isButton,
      isTrue,
    );
    await t.tap(cell);
    await t.pumpAndSettle();
    expect(tapped, 'macquarie-theatre');
    handle.dispose(); // dispose before the body ends, not in teardown
  });

  testWidgets('an uncollected cell has no button role and does nothing', (
    t,
  ) async {
    final handle = t.ensureSemantics();
    String? tapped;
    await t.pumpWidget(_host(<String>{}, onTap: (id) => tapped = id));
    final cell = find.bySemanticsLabel(RegExp(r', not yet collected$')).first;
    expect(
      t.getSemantics(cell).getSemanticsData().flagsCollection.isButton,
      isFalse,
    );
    await t.tap(cell);
    await t.pumpAndSettle();
    expect(tapped, isNull);
    handle.dispose();
  });

  testWidgets('a collected cell with no callback is not a button', (t) async {
    final handle = t.ensureSemantics();
    await t.pumpWidget(_host({'macquarie-theatre'})); // no onTapCollected
    final cell = find.bySemanticsLabel(RegExp(r', stamp collected$'));
    expect(
      t.getSemantics(cell).getSemanticsData().flagsCollection.isButton,
      isFalse,
    );
    handle.dispose();
  });
}
