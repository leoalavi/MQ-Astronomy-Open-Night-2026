import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/screens/map_screen.dart';

Widget _host(Widget child) => ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: Scaffold(body: child),
      ),
    );

void main() {
  // The "Point me there" entry has been removed from the Campus Map entirely:
  // no venue card and no parking card offers it any more (Directions and the
  // 360° tour remain the map actions).
  testWidgets('VenueSheet shows no Point-me-there button', (t) async {
    await t.pumpWidget(_host(const VenueSheet(venueId: 'macquarie-theatre')));
    await t.pumpAndSettle();
    expect(find.text('Point me there'), findsNothing);
  });

  testWidgets('ParkingSheet shows no Point-me-there button either', (t) async {
    // A coordinate-bearing car park used to show it; it must not any more.
    await t.pumpWidget(_host(const ParkingSheet(parkingId: 'west-5')));
    await t.pumpAndSettle();
    expect(find.text('Point me there'), findsNothing);
    expect(find.byIcon(Icons.navigation_rounded), findsNothing);
  });
}
