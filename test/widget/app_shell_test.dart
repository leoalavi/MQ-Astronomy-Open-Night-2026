import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/widgets/liquid_tab_bar.dart';

late GoRouter _router;

Widget _app() {
  _router = buildRouter();
  return ProviderScope(
    child: MaterialApp.router(
      theme: AonTheme.build(),
      routerConfig: _router,
    ),
  );
}

void main() {
  testWidgets('shell shows the 5 tabs via LiquidTabBar', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.byType(LiquidTabBar), findsOneWidget);
    // NOTE: a tab renders its label Text ONLY when selected (unselected tabs
    // collapse the label to SizedBox.shrink), so assert the always-present
    // icons, not find.text on every label. Initial state = Home selected.
    expect(find.byIcon(Icons.home_rounded), findsOneWidget); // Home active
    expect(find.byIcon(Icons.list_alt_outlined), findsOneWidget); // Program
    expect(find.byIcon(Icons.schedule_outlined), findsOneWidget); // Now
    expect(find.byIcon(Icons.map_outlined), findsOneWidget); // Map
    expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget); // Info
    expect(find.text('Home'), findsWidgets); // the one selected label is shown
  });

  testWidgets('tapping a tab actually navigates its branch + updates selection', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.list_alt_outlined), warnIfMissed: false);
    await tester.pumpAndSettle();
    // Assert a widget UNIQUE to the Program page - NOT the tab's own 'Program'
    // label (which would false-pass even if routing were broken). The Program
    // screen shows a count like 'N items in the program'.
    expect(find.textContaining('items in the program'), findsOneWidget);
    // Selected-state moved: Program active icon in, Home no longer active.
    expect(find.byIcon(Icons.list_alt_rounded), findsOneWidget);
    expect(find.byIcon(Icons.home_rounded), findsNothing);
  });

  testWidgets('reselecting the active tab stays on its root without error', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.list_alt_outlined), warnIfMissed: false);
    await tester.pumpAndSettle();
    // Tap the now-active Program tab again (reselect -> goBranch initialLocation).
    await tester.tap(find.byIcon(Icons.list_alt_rounded), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('items in the program'), findsOneWidget);
  });

  testWidgets('back navigation: a pushed full-screen route pops back to the shell', (tester) async {
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
  });
}
