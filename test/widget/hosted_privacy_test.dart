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
      expect(find.textContaining('Cloudflare'), findsOneWidget);
      expect(find.textContaining('ML Kit'), findsOneWidget);
      final l = await AonL10n.delegate.load(locale);
      await tester.scrollUntilVisible(find.text(l.infoOfficialWebsite), 400,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.infoOfficialWebsite));
      await tester.pumpAndSettle();
      expect(opened.single.toString(), 'https://event.mq.edu.au/astronomy-open-night/');
      await tester.ensureVisible(find.text(l.webPrivacyPublishedLinkLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.webPrivacyPublishedLinkLabel));
      await tester.pumpAndSettle();
      expect(opened.last.toString(), 'https://aon.syllabus-sync.app/privacy');
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
