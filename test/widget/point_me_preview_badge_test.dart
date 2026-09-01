import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/services/location_providers.dart';
import 'package:aon2026/services/point_me_controller.dart';
import 'package:aon2026/services/preview_location.dart';
import 'package:aon2026/screens/point_me_screen.dart';
import '../support/fake_heading_service.dart';
import '../support/fake_location_service.dart';

/// §12 location honesty: Point Me computes a distance and a direction from the
/// user's position (`PointMeController` reads `locationControllerProvider.fix`,
/// which is fed by the PREVIEW-aware `effectiveLocationServiceProvider`). When
/// preview mode is on that position is a SIMULATED campus-centre fix — so the
/// screen must carry the "Simulated location" badge, exactly as the map and the
/// compass do. Without it, a visitor at home reading "120 m · NE" has no signal
/// that the reading is simulated.
void main() {
  const venueId = 'macquarie-theatre'; // a real venue with coordinates

  ProviderContainer container() {
    final c = ProviderContainer(overrides: [
      headingServiceProvider.overrideWithValue(FakeHeadingService()),
      locationServiceProvider.overrideWithValue(FakeLocationService()),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  Widget app(ProviderContainer c) => UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(
          localizationsDelegates: AonL10n.localizationsDelegates,
          supportedLocales: AonL10n.supportedLocales,
          home: PointMeScreen(venueId: venueId),
        ),
      );

  testWidgets('shows the Simulated location badge when preview is on', (t) async {
    final c = container();
    c.read(previewLocationProvider.notifier).set(true);
    await t.pumpWidget(app(c));
    await t.pump();

    expect(
      find.byKey(const Key('preview-location-badge')),
      findsOneWidget,
      reason: 'Point Me draws a simulated-position distance/direction — it must '
          'declare preview mode like the map and compass do (§12)',
    );
    expect(find.text('Simulated location'), findsOneWidget);
  });

  testWidgets('shows NO badge when preview is off (real location)', (t) async {
    final c = container(); // preview defaults off
    await t.pumpWidget(app(c));
    await t.pump();

    expect(find.byKey(const Key('preview-location-badge')), findsNothing);
  });
}
