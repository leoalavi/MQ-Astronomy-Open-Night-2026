import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/models/building.dart';
import 'package:aon2026/screens/map_screen.dart' show VenueSheet;
import 'package:aon2026/services/building_providers.dart';
import 'package:aon2026/services/maps_nav_providers.dart';
import 'package:aon2026/widgets/building_sheet.dart';

const _building = Building(
  id: 'TEST', code: 'T1', name: 'Test Hall', category: BuildingCategory.academic,
  latitude: -33.78, longitude: 151.12, campusX: 100, campusY: 100,
);

Widget _harness(ProviderContainer c, Widget sheet) {
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              // Present the sheet the way the app does — a modal bottom sheet —
              // so its Navigator.pop() has a route to pop.
              onPressed: () => showModalBottomSheet<void>(context: context, builder: (_) => sheet),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
    GoRoute(
      path: '/google-nav/:placeKey',
      builder: (_, s) => Scaffold(body: Text('NAV:${s.pathParameters['placeKey']}')),
    ),
    GoRoute(path: '/wayfinding', builder: (_, _) => const Scaffold(body: Text('CURATED'))),
    GoRoute(path: '/point-me/:id', builder: (_, _) => const Scaffold(body: Text('POINTME'))),
  ]);
  return UncontrolledProviderScope(
    container: c,
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AonL10n.localizationsDelegates,
      supportedLocales: AonL10n.supportedLocales,
    ),
  );
}

Future<void> _openSheet(WidgetTester t) async {
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
}

/// Venue sheet harness: renders the sheet directly (it fills the body via its
/// DraggableScrollableSheet) so its CTAs lay out; no pop needed for these
/// presence checks. GoRouter present so context.push resolves if tapped.
Widget _venueHarness(ProviderContainer c, Widget sheet) {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, _) => Scaffold(body: sheet)),
  ]);
  return UncontrolledProviderScope(
    container: c,
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AonL10n.localizationsDelegates,
      supportedLocales: AonL10n.supportedLocales,
    ),
  );
}

Future<void> _scrollTo(WidgetTester t, Finder f) async {
  await t.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
  await t.pumpAndSettle();
}

ProviderContainer _c({required bool enabled}) {
  final c = ProviderContainer(overrides: [
    googleNavEnabledProvider.overrideWithValue(enabled),
    buildingsProvider.overrideWith((ref) async => const [_building]),
  ]);
  addTearDown(c.dispose);
  return c;
}

Future<AonL10n> _en() => AonL10n.delegate.load(const Locale('en'));

void main() {
  testWidgets('building CTA, flag ON → pushes google-nav for building', (t) async {
    await t.pumpWidget(_harness(_c(enabled: true), const BuildingSheet(buildingId: 'TEST')));
    await t.pumpAndSettle();
    await _openSheet(t);
    final l = await _en();
    expect(find.text(l.mapWalkingDirections), findsOneWidget);
    expect(find.byIcon(Icons.open_in_new_rounded), findsNothing);
    await t.tap(find.text(l.mapWalkingDirections));
    await t.pumpAndSettle();
    expect(find.text('NAV:building:TEST'), findsOneWidget); // embedded google nav, not curated
  });

  testWidgets('building CTA, flag OFF → NO directions button (never an external hand-off)', (t) async {
    // MAP #9: when in-app Google nav is unavailable we show no directions button
    // at all, rather than bouncing the visitor out to the Google Maps app.
    await t.pumpWidget(_harness(_c(enabled: false), const BuildingSheet(buildingId: 'TEST')));
    await t.pumpAndSettle();
    await _openSheet(t);
    final l = await _en();
    expect(find.text(l.mapWalkingDirections), findsNothing);
    expect(find.byIcon(Icons.open_in_new_rounded), findsNothing,
        reason: 'no external Google Maps hand-off may exist');
  });

  testWidgets('venue sheet: one Google Directions action, flag ON', (t) async {
    await t.pumpWidget(_venueHarness(_c(enabled: true), const VenueSheet(venueId: 'astronomical-observatory')));
    await t.pumpAndSettle();
    final l = await _en();
    await _scrollTo(t, find.text(l.mapDirections));
    // Google-only: a single Directions action, no curated/draft option.
    expect(find.text(l.mapDirections), findsOneWidget);
    expect(find.text(l.mapWalkingDirections), findsNothing);
  });

  testWidgets('venue sheet: still one Google Directions action, flag OFF', (t) async {
    // Even without the key the Directions button is present — it routes to the
    // Google nav screen, which shows a "not configured yet" message. Never a
    // curated/draft screen, never a dead-end.
    await t.pumpWidget(_venueHarness(_c(enabled: false), const VenueSheet(venueId: 'astronomical-observatory')));
    await t.pumpAndSettle();
    final l = await _en();
    await _scrollTo(t, find.text(l.mapDirections));
    expect(find.text(l.mapDirections), findsOneWidget);
    expect(find.text(l.mapWalkingDirections), findsNothing);
  });
}
