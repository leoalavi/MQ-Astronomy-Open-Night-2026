import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/data/venues_data.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/l10n/generated/app_localizations_en.dart';
import 'package:aon2026/l10n/generated/app_localizations_fa.dart';
import 'package:aon2026/models/venue.dart';
import 'package:aon2026/widgets/venue_info_sheet.dart';

Widget _host(String venueId, {Locale locale = const Locale('en')}) =>
    ProviderScope(
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: Scaffold(body: VenueInfoSheet(venueId: venueId)),
      ),
    );

Future<void> _pump(WidgetTester t, String id,
    {Locale locale = const Locale('en')}) async {
  t.view.physicalSize = const Size(800, 2000);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(_host(id, locale: locale));
  await t.pumpAndSettle();
}

void main() {
  final en = AonL10nEn();
  final fa = AonL10nFa();

  testWidgets('an unknown venue id falls back to translated copy, not a blank '
      'sheet', (t) async {
    await _pump(t, 'no-such-venue');
    expect(find.text(en.infoLocationToBeConfirmed), findsOneWidget);
  });

  testWidgets('the fallback is translated in Persian too', (t) async {
    await _pump(t, 'no-such-venue', locale: const Locale('fa'));
    expect(find.text(fa.infoLocationToBeConfirmed), findsOneWidget);
    expect(find.text(en.infoLocationToBeConfirmed), findsNothing);
  });

  testWidgets('a venue with nothing scheduled says so in the visitor\'s '
      'language', (t) async {
    // A facility venue: on the map, but with no programme entries.
    final quiet = VenuesData.all.firstWhere(
      (v) => v.category == VenueCategory.toilets,
      orElse: () => VenuesData.all.first,
    );
    await _pump(t, quiet.id, locale: const Locale('fa'));
    expect(find.text(fa.mapOnHereTonight), findsOneWidget);
    expect(find.text(fa.venueNothingScheduled), findsOneWidget);
  });
}
