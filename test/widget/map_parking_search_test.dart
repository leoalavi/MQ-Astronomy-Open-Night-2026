import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/services/search_providers.dart';
import 'package:aon2026/widgets/campus_search_sheet.dart';

/// Parking discoverability from the campus-map search box.
///
/// Carparks are not in the map's search index — they sit at the campus edges,
/// so a parking-shaped query surfaces an **action card** that hands off to the
/// Wayfinding planner (every car park + its walking route to the Central
/// Courtyard) rather than a lone map pin. This test pins that a parent typing
/// "parking" / "West 5" / "West 6" / "South 2" always finds it.
void main() {
  group('looksLikeParkingQuery', () {
    for (final q in const [
      'parking', 'Parking', 'car park', 'carpark',
      'West 5', 'west 6', 'South 2', 'south2',
      // Persian — the app is bilingual, so parking terms must match in fa too.
      'پارکینگ', 'پارک', 'وست ۵', 'ساوث ۲',
    ]) {
      test('"\$q" is recognised as a parking search', () {
        expect(looksLikeParkingQuery(q), isTrue);
      });
    }

    for (final q in const ['', 'observatory', 'telescope', 'planetarium']) {
      test('"$q" is NOT a parking search', () {
        expect(looksLikeParkingQuery(q), isFalse);
      });
    }
  });

  /// Mounts the search sheet, typed with [query], and returns the value it pops.
  Future<String?> tapParkingCard(WidgetTester tester, String query) async {
    String? popped;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapSearchQueryProvider.overrideWith(() {
            final n = MapSearchQuery();
            return n;
          }),
        ],
        child: MaterialApp(
          localizationsDelegates: AonL10n.localizationsDelegates,
          supportedLocales: AonL10n.supportedLocales,
          theme: AonTheme.build(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  popped = await showModalBottomSheet<String>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => const CampusSearchSheet(),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Type the query into the search field.
    await tester.enterText(find.byType(TextField), query);
    await tester.pumpAndSettle();
    return popped;
  }

  testWidgets('searching "West 5" shows the parking action card', (
    tester,
  ) async {
    await tapParkingCard(tester, 'West 5');
    expect(find.byKey(const Key('search-parking-action')), findsOneWidget);
    expect(find.text('Parking & walking routes'), findsOneWidget);
  });

  testWidgets('searching "parking" shows the card; tapping it pops the parking '
      'action sentinel', (tester) async {
    String? popped;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AonL10n.localizationsDelegates,
          supportedLocales: AonL10n.supportedLocales,
          theme: AonTheme.build(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  popped = await showModalBottomSheet<String>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => const CampusSearchSheet(),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'parking');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('search-parking-action')));
    await tester.pumpAndSettle();

    // The sheet handed back the parking sentinel — MapScreen routes it to the
    // Wayfinding planner (never a false map pin).
    expect(popped, kParkingSearchAction);
  });

  testWidgets('a non-parking search shows no parking card', (tester) async {
    await tapParkingCard(tester, 'observatory');
    expect(find.byKey(const Key('search-parking-action')), findsNothing);
  });

  testWidgets('West 6 surfaces the parking action from search', (
    tester,
  ) async {
    // Every car park is reachable from search, because the action opens the
    // list-based planner rather than a lone illustrated-map pin.
    await tapParkingCard(tester, 'West 6');
    expect(find.byKey(const Key('search-parking-action')), findsOneWidget);
  });
}
