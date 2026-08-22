import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/widgets/maps_nav_disclosure.dart';

Widget _host(MapsDisclosureKind kind) => MaterialApp(
      localizationsDelegates: AonL10n.localizationsDelegates,
      supportedLocales: AonL10n.supportedLocales,
      home: Scaffold(body: MapsNavDisclosure(kind: kind)),
    );

void main() {
  testWidgets('the navigation disclosure states that location is sent',
      (t) async {
    await t.pumpWidget(_host(MapsDisclosureKind.navigation));
    final l = await AonL10n.delegate.load(const Locale('en'));

    expect(find.text(l.mapNavDisclosureTitle), findsOneWidget);
    expect(find.text(l.mapNavDisclosureBody), findsOneWidget);
  });

  testWidgets('the map-only disclosure does NOT claim this screen uses location',
      (t) async {
    await t.pumpWidget(_host(MapsDisclosureKind.mapDisplay));
    final l = await AonL10n.delegate.load(const Locale('en'));

    expect(find.text(l.mapDisplayDisclosureTitle), findsOneWidget);
    expect(
      find.textContaining('does not use your location'),
      findsOneWidget,
      reason: 'wayfinding reads no location; the copy must not say otherwise',
    );
  });

  testWidgets('the map-only disclosure still discloses the wider grant',
      (t) async {
    await t.pumpWidget(_host(MapsDisclosureKind.mapDisplay));

    expect(
      find.textContaining('your location is sent to Google'),
      findsOneWidget,
      reason: 'one MapsConsent covers both surfaces, so accepting here must be '
          'informed about the nav surface too',
    );
  });

  testWidgets('the map-only disclosure names the request metadata Google gets',
      (t) async {
    await t.pumpWidget(_host(MapsDisclosureKind.mapDisplay));

    expect(
      find.textContaining('request and device information'),
      findsOneWidget,
      reason: 'loading any Google map sends request/device metadata, not only '
          'map imagery — the copy must not understate it',
    );
  });
}
