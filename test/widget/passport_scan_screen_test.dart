import 'package:flutter/material.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/screens/passport_scan_screen.dart';
import 'package:aon2026/services/passport_providers.dart';

// Scanning is the default mode now, so inject a fake scanner: these tests
// exercise the manual path and must never construct the real camera.
Widget _host({bool enabled = true}) => ProviderScope(
  overrides: [
    passportSnapshotProvider.overrideWithValue(<String>{}),
    passportCollectionEnabledProvider.overrideWithValue(enabled),
  ],
  child: MaterialApp(
    localizationsDelegates: AonL10n.localizationsDelegates,
    supportedLocales: AonL10n.supportedLocales,
    home: PassportScanScreen(
      scannerBuilder: (onDecoded) => const SizedBox(key: Key('fake-scanner')),
    ),
  ),
);

Future<void> _enter(WidgetTester t, String code) async {
  // The manual field lives behind the "Enter a code" peer choice.
  await t.tap(find.text('Enter a code'));
  await t.pumpAndSettle();
  await t.enterText(find.byKey(const Key('passport-manual-field')), code);
  await t.tap(find.byKey(const Key('passport-manual-submit')));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('opens directly in scan mode — no second tap to start', (t) async {
    await t.pumpWidget(_host());
    await t.pumpAndSettle();
    // The scanner is shown on the first frame (Scan is the default mode)…
    expect(find.byKey(const Key('fake-scanner')), findsOneWidget);
    // …and manual entry only appears once the visitor chooses "Enter a code".
    expect(find.byKey(const Key('passport-manual-field')), findsNothing);
  });

  testWidgets('valid manual code collects (no camera)', (t) async {
    await t.pumpWidget(_host());
    await _enter(t, 'AON-A-FL3R');
    // "collected" appears in the screen message AND the success fact sheet.
    expect(find.textContaining('collected'), findsWidgets);
  });

  testWidgets('unknown code shows the not-a-code message', (t) async {
    await t.pumpWidget(_host());
    await _enter(t, 'NOPE');
    expect(
      find.textContaining('not an Astronomy Open Night code'),
      findsOneWidget,
    );
  });

  testWidgets('disabled (release + placeholder) shows the not-live message', (
    t,
  ) async {
    await t.pumpWidget(_host(enabled: false));
    await _enter(t, 'AON-A-FL3R');
    expect(find.textContaining('live yet'), findsOneWidget);
  });

  testWidgets('no overflow at 320x568 / 2.0', (t) async {
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1.0;
    t.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(_host());
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}
