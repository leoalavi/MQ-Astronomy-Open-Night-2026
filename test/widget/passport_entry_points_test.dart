import 'package:flutter/material.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/services/passport_providers.dart';
import 'package:aon2026/widgets/passport_home_card.dart';

Widget _app() => ProviderScope(
  overrides: [
    passportSnapshotProvider.overrideWithValue({'macquarie-theatre'}),
  ],
  child: MaterialApp.router(
    localizationsDelegates: AonL10n.localizationsDelegates,
    supportedLocales: AonL10n.supportedLocales,
    routerConfig: buildRouter(),
  ),
);

void main() {
  testWidgets('Home shows the passport card with progress and it navigates', (
    t,
  ) async {
    // A tall viewport so the lazy Home sliver builds the whole page and the
    // card sits clear of the floating glass nav bar (a short viewport hides it
    // behind the bar and the tap misses).
    t.view.physicalSize = const Size(500, 2000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await t.pumpWidget(_app());
    await t.pumpAndSettle();
    final card = find.byType(PassportHomeCard);
    expect(card, findsOneWidget);
    // The Home card shows localised progress: "1 of 9 stamps" (EN).
    expect(find.textContaining('1 of 9'), findsWidgets);
    await t.ensureVisible(card);
    await t.tap(card);
    await t.pumpAndSettle();
    // Reached the passport screen (its AppBar title).
    expect(find.text('Astronomy Passport'), findsWidgets);
  });

  testWidgets('Info menu has a passport entry that navigates', (t) async {
    await t.pumpWidget(_app());
    await t.pumpAndSettle();
    await t.tap(find.byIcon(Icons.info_outline_rounded));
    await t.pumpAndSettle();
    final infoEntry = find.widgetWithText(FilledButton, 'Astronomy Passport');
    expect(infoEntry, findsOneWidget);
    await t.tap(infoEntry);
    await t.pumpAndSettle();
    expect(find.textContaining('/ 9'), findsWidgets); // reached the screen
  });
}
