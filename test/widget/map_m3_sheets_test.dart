import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aon2026/config/event_config.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/models/building.dart';
import 'package:aon2026/models/search_entry.dart';
import 'package:aon2026/models/venue.dart';
import 'package:aon2026/services/building_providers.dart';
import 'package:aon2026/services/favorites_providers.dart';
import 'package:aon2026/services/favorites_store.dart';
import 'package:aon2026/services/saved_events.dart';
import 'package:aon2026/services/search_providers.dart';
import 'package:aon2026/widgets/building_sheet.dart';
import 'package:aon2026/widgets/campus_search_sheet.dart';
import 'package:aon2026/widgets/favorites_sheet.dart';
import 'package:aon2026/widgets/favorite_toggle.dart';
import 'package:aon2026/utils/bidi.dart';

const _eng = Building(
    id: 'E7B', code: 'E7B', name: 'Engineering', category: BuildingCategory.academic,
    campusX: 2000, campusY: 1000, gridRef: 'K18');

Widget _host(Widget child, {List<Building> buildings = const [_eng]}) => ProviderScope(
      overrides: [
        buildingsProvider.overrideWith((ref) async => buildings),
        favoritesStoreProvider.overrideWithValue(const NoopFavoritesStore()),
      ],
      child: MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: Scaffold(body: child),
      ),
    );

void main() {
  // Each test starts from an empty saved-activities store — SharedPreferences
  // mock state is process-global and would otherwise leak between tests.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('search filters + ranks; typing shows matching building', (t) async {
    await t.pumpWidget(_host(const CampusSearchSheet()));
    await t.pumpAndSettle(); // buildings future resolves
    await t.enterText(find.byType(TextField), 'eng');
    await t.pumpAndSettle();
    expect(find.text(Bidi.isolate('Engineering')), findsOneWidget);
  });

  testWidgets('search empty state (EN)', (t) async {
    await t.pumpWidget(_host(const CampusSearchSheet()));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'zzznomatchxyz');
    await t.pumpAndSettle();
    expect(find.textContaining('No results'), findsOneWidget);
  });

  testWidgets('row tap pops the sheet with the placeKey (pop contract)', (t) async {
    String? popped;
    await t.pumpWidget(_host(Builder(builder: (ctx) {
      return TextButton(
        onPressed: () async {
          popped = await showModalBottomSheet<String>(
              context: ctx, builder: (_) => const CampusSearchSheet());
        },
        child: const Text('open'),
      );
    })));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'eng');
    await t.pumpAndSettle();
    await t.tap(find.text(Bidi.isolate('Engineering')));
    await t.pumpAndSettle();
    expect(popped, 'building:E7B');
  });

  testWidgets('320x568 / 2.0: last result reachable + tappable', (t) async {
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1.0;
    t.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(_host(const CampusSearchSheet())); // 21 venues + Engineering
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), ''); // idle: 15 rows
    await t.pumpAndSettle();
    final list = find.byType(Scrollable).first;
    await t.scrollUntilVisible(find.byType(ListTile).last, 200, scrollable: list);
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  testWidgets('unplaceable place shows the list-only hint, not a normal pin (map audit P2)', (t) async {
    const ghost = Venue(id: 'ghost', name: 'First Aid', category: VenueCategory.other); // no coords
    await t.pumpWidget(ProviderScope(
      overrides: [
        buildingsProvider.overrideWith((ref) async => const <Building>[]),
        favoritesStoreProvider.overrideWithValue(const NoopFavoritesStore()),
        mapSearchResultsProvider.overrideWithValue([VenueEntry(ghost)]),
      ],
      child: const MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: Scaffold(body: CampusSearchSheet()),
      ),
    ));
    await t.pumpAndSettle();
    final l = await AonL10n.delegate.load(const Locale('en'));
    expect(find.text(Bidi.isolate('First Aid')), findsOneWidget);
    expect(find.text(l.mapPlaceListOnly), findsOneWidget);
    expect(find.byIcon(Icons.location_off_rounded), findsOneWidget);
  });

  testWidgets('building sheet renders name/code/category/gridRef + favorite toggle', (t) async {
    await t.pumpWidget(_host(const BuildingSheet(buildingId: 'E7B')));
    await t.pumpAndSettle();
    expect(find.text(Bidi.isolate('Engineering')), findsOneWidget);
    expect(find.textContaining('E7B'), findsWidgets); // code · category
    expect(find.textContaining('Grid'), findsOneWidget); // gridRef
    expect(find.byType(FavoriteToggle), findsOneWidget);
  });

  testWidgets('favorite toggle is state-aware (accessible name flips)', (t) async {
    // Flutter exposes an icon-button's tooltip as the accessible name (M2 lesson);
    // it lives on the Tooltip, not as a semantics `label`.
    await t.pumpWidget(_host(const FavoriteToggle(placeKey: 'building:E7B')));
    await t.pumpAndSettle();
    expect(find.byTooltip('Add to favourites'), findsOneWidget);
    await t.tap(find.byType(FavoriteToggle));
    await t.pumpAndSettle();
    expect(find.byTooltip('Remove from favourites'), findsOneWidget);
  });

  testWidgets('favorites sheet: empty state, then a resolved row', (t) async {
    await t.pumpWidget(_host(Consumer(builder: (ctx, ref, _) {
      return Column(children: [
        TextButton(
            onPressed: () =>
                ref.read(favoritesProvider.notifier).toggle('building:E7B'),
            child: const Text('fav')),
        const Expanded(child: FavoritesSheet()),
      ]);
    })));
    await t.pumpAndSettle();
    expect(find.textContaining('No favourites'), findsOneWidget);
    await t.tap(find.text('fav'));
    await t.pumpAndSettle();
    expect(find.text(Bidi.isolate('Engineering')), findsOneWidget); // resolved row
  });

  testWidgets('favorites sheet: a saved activity shows with paired map actions',
      (t) async {
    // A saved night appears here too (single source of truth), and because its
    // venue (the Observatory) is located, the card offers Show on Map +
    // Directions keyed to the same `venue:<id>` its detail sheet uses.
    SharedPreferences.setMockInitialValues({
      SavedEventsStorage.keyFor(EventConfig.astronomyOpenNight.id): [
        'telescope-park',
      ],
    });
    await t.pumpWidget(_host(const FavoritesSheet()));
    await t.pumpAndSettle();

    expect(
      find.byKey(const Key('favorite-event-telescope-park')),
      findsOneWidget,
    );
    expect(find.text('Telescope Park'), findsOneWidget);
    expect(
      find.byKey(const Key('show-map-venue:astronomical-observatory')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('directions-venue:astronomical-observatory')),
      findsOneWidget,
    );
    // The empty state is gone once anything is saved.
    expect(find.textContaining('No favourites'), findsNothing);
  });

  testWidgets('favorites sheet: tapping the heart removes a favourited place',
      (t) async {
    await t.pumpWidget(_host(Consumer(builder: (ctx, ref, _) {
      return Column(children: [
        TextButton(
            onPressed: () =>
                ref.read(favoritesProvider.notifier).toggle('building:E7B'),
            child: const Text('fav')),
        const Expanded(child: FavoritesSheet()),
      ]);
    })));
    await t.pumpAndSettle();
    await t.tap(find.text('fav'));
    await t.pumpAndSettle();
    expect(find.text(Bidi.isolate('Engineering')), findsOneWidget);

    // The heart on the row toggles the place back off → the list is empty again.
    await t.tap(find.byTooltip('Remove from favourites'));
    await t.pumpAndSettle();
    expect(find.text(Bidi.isolate('Engineering')), findsNothing);
    expect(find.textContaining('No favourites'), findsOneWidget);
  });
}
