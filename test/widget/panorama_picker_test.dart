import 'package:flutter/material.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/widgets/panorama_building_picker.dart';

void main() {
  testWidgets(
    'tour venue tappable + demo flag; others coming soon; no auto-select',
    (tester) async {
      String? opened;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AonL10n.localizationsDelegates,
            supportedLocales: AonL10n.supportedLocales,
            theme: AonTheme.build(),
            home: Scaffold(
              body: PanoramaBuildingPicker(onOpen: (id) => opened = id),
            ),
          ),
        ),
      );
      await tester.pump();
      // The demo flag appears for the one tour venue; coming-soon for others.
      expect(find.text(kPanoramaDemoFlag), findsOneWidget);
      expect(find.text('Coming soon'), findsWidgets);
      // Picker is shown, nothing auto-opened.
      expect(opened, isNull);
      // Tapping the demo flag's card opens that venue.
      await tester.tap(find.text(kPanoramaDemoFlag));
      expect(opened, 'macquarie-theatre');
    },
  );

  testWidgets(
    'lists only the map legend A-I venues, each prefixed with its letter',
    (tester) async {
      // Tall surface: the picker is a lazy ListView, so a short viewport
      // would make "venue X is absent" pass for the wrong reason.
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AonL10n.localizationsDelegates,
            supportedLocales: AonL10n.supportedLocales,
            theme: AonTheme.build(),
            home: Scaffold(
              body: PanoramaBuildingPicker(onOpen: (_) {}),
            ),
          ),
        ),
      );
      await tester.pump();

      // Every card reads as the paper map letters it.
      const lettered = [
        'A \u00b7 Macquarie Theatre',
        'B \u00b7 Mason Theatre',
        'C \u00b7 Food and drink',
        'D \u00b7 14 Sir Christopher Ondaatje Avenue',
        'E \u00b7 1 Central Courtyard',
        'F \u00b7 Macquarie University Sport and Aquatic Centre',
        'G \u00b7 Macquarie University Astronomical Observatory',
        'H \u00b7 11 Wally\u2019s Walk',
        'I \u00b7 17 Wally\u2019s Walk',
      ];
      for (final label in lettered) {
        expect(find.text(label), findsOneWidget, reason: 'missing $label');
      }
      // Nine cards, no more: one tourable + eight coming soon.
      expect(find.byIcon(Icons.panorama_photosphere), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline_rounded), findsNWidgets(8));

      // Unlettered service points are gone, not merely scrolled away.
      for (final gone in [
        'Toilets \u2014 Macquarie Theatre',
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
