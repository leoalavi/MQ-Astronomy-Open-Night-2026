import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/widgets/place_action_buttons.dart';

Widget _app() => ProviderScope(
  child: MaterialApp.router(
    localizationsDelegates: AonL10n.localizationsDelegates,
    supportedLocales: AonL10n.supportedLocales,
    routerConfig: buildRouter(),
  ),
);

Future<void> _openInfo(WidgetTester tester) async {
  tester.view.physicalSize = const Size(600, 6000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_app());
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.info_outline_rounded));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Info removes large parking CTA, Passport, and unverified aid', (
    tester,
  ) async {
    await _openInfo(tester);
    expect(find.text('Walking directions from parking'), findsNothing);
    expect(find.text('Astronomy Passport'), findsNothing);
    expect(find.text('First aid'), findsNothing);
  });

  testWidgets('every parking card exposes map + directions actions', (
    tester,
  ) async {
    await _openInfo(tester);
    // All three official car parks are now pinned (West 6 included), so each
    // card carries both actions.
    for (final id in ['west-5', 'west-6', 'south-2']) {
      expect(find.byKey(Key('parking-card-$id')), findsOneWidget);
      expect(find.byKey(Key('show-map-parking:$id')), findsOneWidget);
      expect(find.byKey(Key('directions-parking:$id')), findsOneWidget);
    }
  });

  testWidgets('Show on Map and Directions preserve the exact place key', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(
            body: PlaceActionButtons(placeKey: 'parking:west-5'),
          ),
        ),
        GoRoute(
          path: '/map',
          builder: (_, state) =>
              Text('map:${state.uri.queryParameters['focus']}'),
        ),
        GoRoute(
          path: '/google-nav/:placeKey',
          builder: (_, state) =>
              Text('nav:${state.pathParameters['placeKey']}'),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();

    tester
        .widget<OutlinedButton>(
          find.byKey(const Key('show-map-parking:west-5')),
        )
        .onPressed!();
    await tester.pumpAndSettle();
    expect(find.text('map:parking:west-5'), findsOneWidget);

    router.go('/');
    await tester.pumpAndSettle();
    tester
        .widget<OutlinedButton>(
          find.byKey(const Key('directions-parking:west-5')),
        )
        .onPressed!();
    await tester.pumpAndSettle();
    expect(find.text('nav:parking:west-5'), findsOneWidget);
  });

  testWidgets('verified registration exposes paired contextual actions', (
    tester,
  ) async {
    await _openInfo(tester);
    expect(
      find.byKey(const Key('show-map-venue:registration-point')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('directions-venue:registration-point')),
      findsOneWidget,
    );
  });

  testWidgets('closing a modal before navigation keeps its destination', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                useRootNavigator: true,
                builder: (sheetContext) => PlaceActionButtons(
                  placeKey: 'parking:west-5',
                  beforeNavigate: () => Navigator.of(sheetContext).pop(),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
        GoRoute(
          path: '/map',
          builder: (_, state) =>
              Text('map:${state.uri.queryParameters['focus']}'),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('show-map-parking:west-5')));
    await tester.pumpAndSettle();

    expect(find.text('map:parking:west-5'), findsOneWidget);
  });
}
