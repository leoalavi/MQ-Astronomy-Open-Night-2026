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
}
