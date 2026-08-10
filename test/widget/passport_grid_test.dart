import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/widgets/passport_grid.dart';

Widget _host(Set<String> collected) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PassportGrid(collectedVenueIds: collected),
        ),
      ),
    );

void main() {
  testWidgets('renders all 9 cells, all uncollected when empty', (tester) async {
    await tester.pumpWidget(_host(<String>{}));
    expect(
      find.bySemanticsLabel(RegExp(r', not yet collected$')),
      findsNWidgets(9),
    );
  });

  testWidgets('exactly one cell reads "stamp collected"', (tester) async {
    await tester.pumpWidget(_host({'macquarie-theatre'}));
    expect(
      find.bySemanticsLabel(RegExp(r', stamp collected$')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp(r', not yet collected$')),
      findsNWidgets(8),
    );
  });

  testWidgets('no overflow at 320x568 / 2.0', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(_host(<String>{}));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
