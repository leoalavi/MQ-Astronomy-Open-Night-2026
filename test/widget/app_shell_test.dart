import 'dart:async';

import 'package:flutter/material.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/widgets/liquid_tab_bar.dart';

late GoRouter _router;

/// Finds an icon **inside the tab bar only**.
///
/// Necessary because tab glyphs are no longer unique on screen: the save
/// button uses the same star as the My Night tab, and Home's quick access
/// reuses several others. An unscoped `find.byIcon` matches those too.
Finder _tabIcon(IconData icon) =>
    find.descendant(of: find.byType(LiquidTabBar), matching: find.byIcon(icon));

Widget _app({Locale? locale}) {
  _router = buildRouter();
  return ProviderScope(
    child: MaterialApp.router(
      localizationsDelegates: AonL10n.localizationsDelegates,
      supportedLocales: AonL10n.supportedLocales,
      locale: locale,
      theme: AonTheme.build(),
      routerConfig: _router,
    ),
  );
}

void main() {
  testWidgets('shell shows the 6 primary tabs via LiquidTabBar', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.byType(LiquidTabBar), findsOneWidget);
    // NOTE: a tab renders its label Text ONLY when selected (unselected tabs
    // collapse the label to SizedBox.shrink), so assert the always-present
    // icons, not find.text on every label. Initial state = Home selected.
    expect(_tabIcon(Icons.home_rounded), findsOneWidget); // Home active
    expect(_tabIcon(Icons.list_alt_outlined), findsOneWidget); // Program
    expect(_tabIcon(Icons.star_outline_rounded), findsOneWidget); // My Night
    expect(_tabIcon(Icons.map_outlined), findsOneWidget); // Map
    expect(_tabIcon(Icons.info_outline_rounded), findsOneWidget); // Info
    // Settings is now a PRIMARY destination, not a gear icon in a header.
    expect(_tabIcon(Icons.settings_outlined), findsOneWidget); // Settings
    expect(find.text('Home'), findsWidgets); // the one selected label is shown
  });

  testWidgets('Settings is reachable as a tab and shows no back button', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(_tabIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    // The Settings screen is up…
    expect(find.text('Settings'), findsWidgets);
    // …as a branch root, so there is no back arrow (it is a place, not a task).
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('Info no longer hides a Settings gear in its header', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(_tabIcon(Icons.info_outline_rounded));
    await tester.pumpAndSettle();

    // The old top-right gear is gone; Settings has its own tab instead.
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.settings_outlined),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'the third tab is labelled from the event config, not hardcoded',
    (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      // Astronomy Open Night is an evening event, so the saved-plan tab must
      // read "My Night" — the Open Day "Your Day" vocabulary would be wrong.
      await tester.tap(
        _tabIcon(Icons.star_outline_rounded),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      // The tab uses the short form; the screen title uses the full one.
      expect(
        find.descendant(
          of: find.byType(LiquidTabBar),
          matching: find.text('Night'),
        ),
        findsOneWidget,
      );
      expect(find.text('My Night'), findsWidgets); // screen title
      expect(find.textContaining('Your Day'), findsNothing);
    },
  );

  testWidgets(
    'tapping a tab actually navigates its branch + updates selection',
    (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(_tabIcon(Icons.list_alt_outlined), warnIfMissed: false);
      await tester.pumpAndSettle();
      // Assert a widget UNIQUE to the Program page - NOT the tab's own 'Program'
      // label (which would false-pass even if routing were broken). The Program
      // screen shows a count like 'N items in the program'.
      expect(find.textContaining('items in the program'), findsOneWidget);
      // Selected-state moved: Program active icon in, Home no longer active.
      expect(_tabIcon(Icons.list_alt_rounded), findsOneWidget);
      expect(_tabIcon(Icons.home_rounded), findsNothing);
    },
  );

  testWidgets('reselecting the active tab stays on its root without error', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(_tabIcon(Icons.list_alt_outlined), warnIfMissed: false);
    await tester.pumpAndSettle();
    // Tap the now-active Program tab again (reselect -> goBranch initialLocation).
    await tester.tap(_tabIcon(Icons.list_alt_rounded), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('items in the program'), findsOneWidget);
  });

  testWidgets(
    'back navigation: a pushed full-screen route pops back to the shell',
    (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      // Wayfinding is pushed above the shell (hides the tab bar). push() returns
      // a Future that completes on pop; unawaited to satisfy `unawaited_futures`.
      unawaited(_router.push('/wayfinding'));
      await tester.pumpAndSettle();
      expect(find.text('Walking directions'), findsWidgets);
      expect(find.byType(LiquidTabBar), findsNothing);
      // Pop -> the shell (and its tab bar) return.
      _router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(LiquidTabBar), findsOneWidget);
    },
  );

  group('the 6-tab bar survives narrow phones, large text and Persian', () {
    // Adding Settings took the bar from five tabs to six. On a 320pt phone at
    // 200% text — and again mirrored in Persian — the labels must ellipsize
    // rather than overflow, and the bar must still render.
    for (final locale in const [Locale('en'), Locale('fa')]) {
      for (final scale in const [1.0, 1.5, 2.0]) {
        testWidgets('${locale.languageCode} @ ${(scale * 100).round()}% '
            'text, 320 wide', (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: _app(locale: locale),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(LiquidTabBar), findsOneWidget);
          expect(tester.takeException(), isNull,
              reason: 'tab bar overflowed at '
                  '${locale.languageCode}/${(scale * 100).round()}%');
        });
      }
    }
  });
}
