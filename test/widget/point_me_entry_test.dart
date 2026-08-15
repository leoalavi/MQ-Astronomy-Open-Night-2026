import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/screens/map_screen.dart';

Widget _host(Widget child) => ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: Scaffold(body: child),
      ),
    );

void main() {
  testWidgets('VenueSheet with coords shows a Point-me-there button',
      (t) async {
    await t.pumpWidget(_host(const VenueSheet(venueId: 'macquarie-theatre')));
    await t.pumpAndSettle();
    expect(
        find.widgetWithText(OutlinedButton, 'Point me there'), findsOneWidget);
  });

  testWidgets('ParkingSheet with coords shows a Point-me-there button',
      (t) async {
    await t.pumpWidget(_host(const ParkingSheet(parkingId: 'west-5')));
    await t.pumpAndSettle();
    expect(
        find.widgetWithText(OutlinedButton, 'Point me there'), findsOneWidget);
  });

  testWidgets('a no-coordinate venue hides the Point-me-there button',
      (t) async {
    await t.pumpWidget(_host(const VenueSheet(venueId: 'first-aid')));
    await t.pumpAndSettle();
    expect(find.text('Point me there'), findsNothing);
  });

  testWidgets('tapping Point me there navigates to the point-me route',
      (t) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const _Opener()),
        GoRoute(
          path: '/point-me/:id',
          builder: (_, s) => Scaffold(
              appBar: AppBar(title: Text('PM ${s.pathParameters['id']}'))),
        ),
      ],
    );
    await t.pumpWidget(ProviderScope(
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
      ),
    ));
    await t.pumpAndSettle();
    await t.tap(find.text('open sheet'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(OutlinedButton, 'Point me there'));
    await t.pumpAndSettle();
    expect(find.text('PM macquarie-theatre'), findsOneWidget);
  });
}

class _Opener extends StatelessWidget {
  const _Opener();
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => const VenueSheet(venueId: 'macquarie-theatre'),
            ),
            child: const Text('open sheet'),
          ),
        ),
      );
}
