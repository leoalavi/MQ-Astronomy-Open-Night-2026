import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/screens/map_screen.dart' show VenueSheet;
import 'package:aon2026/widgets/map_config.dart';
import 'package:aon2026/widgets/venue_info_sheet.dart';

/// The place sheet must open COMPACT, leaving the map visible.
///
/// ## The bug this file exists to prevent
///
/// Tapping "Show on map" opened the venue sheet at `initialChildSize: 0.55`
/// (`VenueInfoSheet` at 0.6), covering most of the screen — so the visitor
/// could barely see the map they had just asked to see. The sheet stays fully
/// draggable up to its detail; it just no longer ambushes the map on open.
///
/// Asserted against the shared [MapConfig] extent constants and the sheet
/// CONFIG (not pixels) so it can't rot when device dimensions change.
void main() {
  Widget host(Widget child) => ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AonL10n.localizationsDelegates,
          supportedLocales: AonL10n.supportedLocales,
          home: Scaffold(body: child),
        ),
      );

  DraggableScrollableSheet sheetOf(WidgetTester t) =>
      t.widget<DraggableScrollableSheet>(find.byType(DraggableScrollableSheet));

  test('the shared initial extent is compact and above its floor', () {
    // A one-line guard against someone bumping the sheet back up to 0.5+.
    expect(MapConfig.venueSheetInitialExtent, lessThanOrEqualTo(0.4));
    expect(MapConfig.venueSheetMinExtent,
        lessThanOrEqualTo(MapConfig.venueSheetInitialExtent));
    expect(MapConfig.venueSheetMaxExtent,
        greaterThan(MapConfig.venueSheetInitialExtent));
  });

  testWidgets('VenueSheet opens compact with a min floor', (t) async {
    await t.pumpWidget(host(const VenueSheet(venueId: 'macquarie-theatre')));
    await t.pumpAndSettle();
    final s = sheetOf(t);
    expect(s.initialChildSize, MapConfig.venueSheetInitialExtent);
    expect(s.minChildSize, MapConfig.venueSheetMinExtent);
    expect(s.maxChildSize, MapConfig.venueSheetMaxExtent);
  });

  testWidgets('VenueInfoSheet opens compact with a min floor', (t) async {
    await t.pumpWidget(host(const VenueInfoSheet(venueId: 'macquarie-theatre')));
    await t.pumpAndSettle();
    final s = sheetOf(t);
    expect(s.initialChildSize, MapConfig.venueSheetInitialExtent);
    expect(s.minChildSize, MapConfig.venueSheetMinExtent);
    expect(s.maxChildSize, MapConfig.venueSheetMaxExtent);
  });
}
