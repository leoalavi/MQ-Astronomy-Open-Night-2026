import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/services/location_providers.dart';
import 'package:aon2026/widgets/app_shell.dart';

GoRouter _router() => GoRouter(
      initialLocation: '/home',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => AppShell(navigationShell: shell),
          branches: [
            for (final p in const ['/home', '/program', '/plan', '/map', '/info'])
              StatefulShellBranch(routes: [
                GoRoute(path: p, builder: (_, _) => Text('screen $p')),
              ]),
          ],
        ),
      ],
    );

void main() {
  testWidgets('mapVisible tracks the active branch', (t) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final router = _router();
    addTearDown(router.dispose);
    await t.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
      ),
    ));
    await t.pumpAndSettle();
    expect(c.read(mapVisibleProvider), isFalse); // on /home

    router.go('/map');
    await t.pumpAndSettle();
    expect(c.read(mapVisibleProvider), isTrue); // Map tab on-screen

    router.go('/info');
    await t.pumpAndSettle();
    expect(c.read(mapVisibleProvider), isFalse); // switched away
  });
}
