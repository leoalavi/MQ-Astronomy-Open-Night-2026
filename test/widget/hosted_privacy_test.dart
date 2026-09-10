import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/url_strategy_noop.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/models/indoor_manifest.dart';
import 'package:aon2026/screens/privacy_screen.dart';
import 'package:aon2026/services/url_opener.dart';
import 'package:aon2026/widgets/app_shell.dart';
import 'package:aon2026/widgets/panorama_web_view.dart';
import 'package:aon2026/widgets/panorama_web_viewer_stub.dart';

void main() {
  for (final locale in const [Locale('en'), Locale('fa')]) {
    testWidgets('privacy route renders the shared policy in ${locale.languageCode}', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final opened = <Uri>[];
      final router = buildRouter();
      addTearDown(router.dispose);
      router.go(Routes.privacy);
      await tester.pumpWidget(ProviderScope(
        overrides: [urlOpenerProvider.overrideWithValue((uri) async { opened.add(uri); return true; })],
        child: MaterialApp.router(
          routerConfig: router, locale: locale,
          localizationsDelegates: AonL10n.localizationsDelegates,
          supportedLocales: AonL10n.supportedLocales,
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(PrivacyScreen), findsOneWidget);
      final l = await AonL10n.delegate.load(locale);
      // The web policy screen renders the webPrivacy* strings as a lazy list, so
      // only what is on screen is built. Assert the scope statement near the top
      // in the locale under test, then scroll to the ML Kit disclosure rather
      // than asserting against a widget that has not been built yet.
      // The scope statement renders at the top in the locale under test. The
      // rest of the policy is a lazy list, so its content is asserted against
      // the strings in privacy_copy_truth_test rather than by scrolling here —
      // scrolling past the buttons below unbuilds them.
      expect(find.text(l.webPrivacyScope), findsOneWidget);
      // This page IS the canonical policy at /privacy, so it does not link to
      // itself; the only outbound link is the official event site. The policy is
      // a long lazy ListView, so give the test a tall surface to lay it all out
      // rather than scrolling, which unbuilds what it scrolls past.
      await tester.binding.setSurfaceSize(const Size(1000, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text(l.infoOfficialWebsite));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.infoOfficialWebsite));
      await tester.pumpAndSettle();
      expect(opened.single.toString(), 'https://event.mq.edu.au/astronomy-open-night/');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('wide web navigation selects Settings and preserves all six tabs', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(initialLocation: '/home', routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(navigationShell: shell),
        branches: [for (final route in ['/home','/program','/night','/map','/info','/settings'])
          StatefulShellBranch(routes: [GoRoute(path: route, builder: (_, _) => Text('Destination $route'))])],
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [webNavigationProvider.overrideWithValue(true)],
      child: MaterialApp.router(routerConfig: router,
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Destination /settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('native web-only seams degrade to the unavailable viewer', (tester) async {
    configureUrlStrategy();
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AonL10n.localizationsDelegates,
      supportedLocales: AonL10n.supportedLocales,
      home: buildPanoramaWebViewer(manifest: const IndoorManifest(nodes: []),
        sceneId: null, onSceneChanged: (_) {}, reduceMotion: true),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(PanoramaUnavailable), findsOneWidget);
  });
}
