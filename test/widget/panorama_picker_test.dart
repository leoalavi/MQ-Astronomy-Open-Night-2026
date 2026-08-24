import 'package:flutter/material.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/data/panorama_data.dart';
import 'package:aon2026/services/providers.dart';
import 'package:aon2026/widgets/panorama_building_picker.dart';

const String _explore = 'Tap to explore in 360°';
// The demo disclosure now lives in the ARB (`panoramaDemoFlag`); tests run in
// English, so assert the English string the same way _explore does.
const String _demoFlag = 'Demo 360° — sample imagery, not this venue';

void main() {
  // `tours` swaps the shipped tour table — the only way to exercise the
  // placeholder branch now that nothing shipped is a placeholder.
  Widget picker({
    void Function(String)? onOpen,
    Map<String, PanoramaTour>? tours,
  }) => ProviderScope(
    overrides: [
      if (tours != null) panoramaToursProvider.overrideWithValue(tours),
    ],
    child: MaterialApp(
      localizationsDelegates: AonL10n.localizationsDelegates,
      supportedLocales: AonL10n.supportedLocales,
      theme: AonTheme.build(),
      home: Scaffold(
        body: PanoramaBuildingPicker(onOpen: onOpen ?? (_) {}),
      ),
    ),
  );

  // A tall surface: the picker is a lazy ListView, so a short viewport would
  // let "card X is absent" pass for the wrong reason.
  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('real tours invite exploring; the demo disclosure is gone', (
    tester,
  ) async {
    tall(tester);
    String? opened;
    await tester.pumpWidget(picker(onOpen: (id) => opened = id));
    await tester.pump();

    // Six legend venues have photography; three do not.
    expect(find.text(_explore), findsNWidgets(6));
    expect(find.text('Coming soon'), findsNWidgets(3));
    // Nothing shipped is sample imagery any more.
    expect(find.text(_demoFlag), findsNothing);

    // Nothing auto-opens; tapping a tour card opens that venue.
    expect(opened, isNull);
    await tester.tap(find.text('A · Macquarie Theatre'));
    expect(opened, 'macquarie-theatre');
  });

  testWidgets('a placeholder tour still discloses itself as demo content', (
    tester,
  ) async {
    tall(tester);
    await tester.pumpWidget(
      picker(
        tours: {
          'mason-theatre': const PanoramaTour(
            venueId: 'mason-theatre',
            manifestAsset: 'assets/data/indoor/mason-theatre.json',
            placeholder: true,
          ),
        },
      ),
    );
    await tester.pump();

    expect(find.text(_demoFlag), findsOneWidget);
    expect(find.text(_explore), findsNothing);
  });

  testWidgets(
    'lists only the map legend A-I venues, each prefixed with its letter',
    (tester) async {
      tall(tester);
      await tester.pumpWidget(picker());
      await tester.pump();

      // Every card reads as the paper map letters it.
      const lettered = [
        'A · Macquarie Theatre',
        'B · Mason Theatre',
        'C · Food and drink',
        'D · 14 Sir Christopher Ondaatje Avenue',
        'E · 1 Central Courtyard',
        'F · Macquarie University Sport and Aquatic Centre',
        'G · Macquarie University Astronomical Observatory',
        'H · 11 Wally’s Walk',
        'I · 17 Wally’s Walk',
      ];
      for (final label in lettered) {
        expect(find.text(label), findsOneWidget, reason: 'missing $label');
      }
      // Nine cards, no more: six tourable + three coming soon.
      expect(find.byIcon(Icons.panorama_photosphere), findsNWidgets(6));
      expect(find.byIcon(Icons.lock_outline_rounded), findsNWidgets(3));

      // Unlettered service points are gone, not merely scrolled away.
      for (final gone in [
        'Toilets — Macquarie Theatre',
        'First aid',
        'Registration point',
        'Macquarie University Metro Station',
        'Transport NSW bus stop',
        'Central Courtyard',
      ]) {
        expect(
          find.text(gone),
          findsNothing,
          reason: '$gone should not be offered a 360',
        );
      }
    },
  );
}
