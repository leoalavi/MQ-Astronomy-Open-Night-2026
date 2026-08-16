import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/models/building.dart';
import 'package:aon2026/screens/map_screen.dart' show VenueSheet;
import 'package:aon2026/services/building_providers.dart';
import 'package:aon2026/services/external_maps_launcher.dart';
import 'package:aon2026/services/maps_nav_providers.dart';
import 'package:aon2026/widgets/building_sheet.dart';

const _building = Building(
  id: 'TEST', code: 'T1', name: 'Test Hall', category: BuildingCategory.academic,
  latitude: -33.78, longitude: 151.12, campusX: 100, campusY: 100,
);

class _FakeLauncher implements ExternalMapsLauncher {
  Uri? opened;
  @override
  Future<bool> open(Uri uri) async {
    opened = uri;
    return true;
  }
}

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

ProviderContainer _c({required bool enabled, _FakeLauncher? launcher}) {
  final c = ProviderContainer(overrides: [
    googleNavEnabledProvider.overrideWithValue(enabled),
    buildingsProvider.overrideWith((ref) async => const [_building]),
    externalMapsLauncherProvider.overrideWithValue(launcher ?? _FakeLauncher()),
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
    expect(find.text(l.mapNavOpenExternal), findsNothing);
    await t.tap(find.text(l.mapWalkingDirections));
    await t.pumpAndSettle();
    expect(find.text('NAV:building:TEST'), findsOneWidget); // embedded google nav, not curated
  });

  testWidgets('building CTA, flag OFF → launches keyless external Maps URL (never curated screen)', (t) async {
    final launcher = _FakeLauncher();
    await t.pumpWidget(_harness(_c(enabled: false, launcher: launcher), const BuildingSheet(buildingId: 'TEST')));
    await t.pumpAndSettle();
    await _openSheet(t);
    final l = await _en();
    expect(find.text(l.mapNavOpenExternal), findsOneWidget);
    expect(find.text(l.mapWalkingDirections), findsNothing);
    await t.tap(find.text(l.mapNavOpenExternal));
    await t.pumpAndSettle();
    expect(launcher.opened.toString(),
        'https://www.google.com/maps/dir/?api=1&destination=-33.78%2C151.12&travelmode=walking');
    expect(find.text('CURATED'), findsNothing); // must NOT route to the curated wayfinding screen
  });

  testWidgets('venue sheet: flag ON → curated Walking directions AND Google nav', (t) async {
    await t.pumpWidget(_venueHarness(_c(enabled: true), const VenueSheet(venueId: 'astronomical-observatory')));
    await t.pumpAndSettle();
    final l = await _en();
    await _scrollTo(t, find.text(l.mapNavGoogle));
    expect(find.text(l.mapWalkingDirections), findsOneWidget); // curated kept
    expect(find.text(l.mapNavGoogle), findsOneWidget); // google added
  });

  testWidgets('venue sheet: flag OFF → curated only, no Google nav button', (t) async {
    await t.pumpWidget(_venueHarness(_c(enabled: false), const VenueSheet(venueId: 'astronomical-observatory')));
    await t.pumpAndSettle();
    final l = await _en();
    await _scrollTo(t, find.text(l.mapWalkingDirections));
    expect(find.text(l.mapWalkingDirections), findsOneWidget);
    expect(find.text(l.mapNavGoogle), findsNothing); // not in tree when flag off
  });
}
