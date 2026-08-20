import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/models/building.dart';
import 'package:aon2026/services/building_providers.dart';
import 'package:aon2026/services/favorites_store.dart';
import 'package:aon2026/services/favorites_providers.dart';
import 'package:aon2026/services/location_providers.dart';
import 'package:aon2026/services/search_providers.dart';
import 'package:aon2026/widgets/building_sheet.dart';
import 'package:aon2026/widgets/campus_search_sheet.dart';
import 'package:aon2026/widgets/favorites_sheet.dart';
import 'package:aon2026/screens/map_screen.dart';
import '../support/fake_location_service.dart';

const _eng = Building(
    id: 'E7B', code: 'E7B', name: 'Engineering', category: BuildingCategory.academic,
    campusX: 2000, campusY: 1000, gridRef: 'K18');

ProviderContainer _container() {
  final c = ProviderContainer(overrides: [
    locationServiceProvider.overrideWithValue(FakeLocationService()),
    buildingsProvider.overrideWith((ref) async => const [_eng]),
    favoritesStoreProvider.overrideWithValue(const NoopFavoritesStore()),
  ]);
  addTearDown(c.dispose);
  c.read(mapVisibleProvider.notifier).set(true);
  return c;
}

Widget _app(ProviderContainer c) => UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: MapScreen(),
      ),
    );

int _markerCount(WidgetTester t) => t
    .widgetList<MarkerLayer>(find.byType(MarkerLayer))
    .fold(0, (s, l) => s + l.markers.length);

void main() {
  testWidgets('control column: Search/Favorites buttons coexist + open their sheets',
      (t) async {
    final c = _container();
    await t.pumpWidget(_app(c));
    await t.pumpAndSettle();
    // both tooltips present (coexist, no collision)
    expect(find.byTooltip('Search'), findsOneWidget);
    expect(find.byTooltip('Favourites'), findsOneWidget);

    await t.tap(find.byTooltip('Search'));
    await t.pumpAndSettle();
    expect(find.byType(CampusSearchSheet), findsOneWidget);
    Navigator.of(t.element(find.byType(CampusSearchSheet))).pop();
    await t.pumpAndSettle();

    await t.tap(find.byTooltip('Favourites'));
    await t.pumpAndSettle();
    expect(find.byType(FavoritesSheet), findsOneWidget);
    Navigator.of(t.element(find.byType(FavoritesSheet))).pop();
    await t.pumpAndSettle();

    // The M2 'Map layers' button is gone: the official AON artwork is the only
    // basemap, so there is nothing to switch between.
    expect(find.byTooltip('Map layers'), findsNothing);
  });

  testWidgets('select a building via search → transient marker + BuildingSheet; '
      'closing clears selection (G15)', (t) async {
    final c = _container();
    await t.pumpWidget(_app(c));
    await t.pumpAndSettle();
    final before = _markerCount(t);

    await t.tap(find.byTooltip('Search'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'eng');
    await t.pumpAndSettle();
    await t.tap(find.text('Engineering'));
    await t.pumpAndSettle();

    // selection set + transient marker added + BuildingSheet open
    expect(c.read(selectedPlaceKeyProvider), 'building:E7B');
    expect(find.byType(BuildingSheet), findsOneWidget);
    expect(_markerCount(t), greaterThan(before)); // transient marker

    // close the detail sheet → selection clears (G15) → transient marker gone
    Navigator.of(t.element(find.byType(BuildingSheet))).pop();
    await t.pumpAndSettle();
    expect(c.read(selectedPlaceKeyProvider), isNull);
    expect(_markerCount(t), before);
  });

  testWidgets('selecting a venue adds NO extra pin (decorates existing, G8)', (t) async {
    final c = _container();
    await t.pumpWidget(_app(c));
    await t.pumpAndSettle();
    final before = _markerCount(t);
    c.read(selectedPlaceKeyProvider.notifier).select('venue:astronomical-observatory');
    await t.pumpAndSettle();
    expect(_markerCount(t), before); // same count — decoration, not a new pin
  });

  testWidgets('M1 intact: venues render over the official basemap', (t) async {
    final c = _container();
    await t.pumpWidget(_app(c));
    await t.pumpAndSettle();
    expect(_markerCount(t), greaterThan(0)); // the 21 venues (+parking)
    // The M2 variant picker is retired — one official basemap, nothing to swap.
    expect(find.byTooltip('Map layers'), findsNothing);
    expect(t.takeException(), isNull);
  });
}
