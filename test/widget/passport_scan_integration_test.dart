import 'package:flutter/material.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/screens/passport_scan_screen.dart';
import 'package:aon2026/services/passport_providers.dart';
import 'package:aon2026/widgets/passport_fact_sheet.dart';

void main() {
  testWidgets('a decoded namespaced QR collects a stamp via the shared path', (
    t,
  ) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: [passportSnapshotProvider.overrideWithValue(<String>{})],
        child: MaterialApp(
          localizationsDelegates: AonL10n.localizationsDelegates,
          supportedLocales: AonL10n.supportedLocales,
          home: PassportScanScreen(
            // Fake scanner: a button that emits a decoded QR string on tap.
            scannerBuilder: (onDecoded) => ElevatedButton(
              key: const Key('fake-decode'),
              onPressed: () => onDecoded('AON2026:AON-A-FL3R'),
              child: const Text('emit'),
            ),
          ),
        ),
      ),
    );
    // Reveal the scanner peer, then emit a decode.
    await t.tap(find.text('Scan QR code'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('fake-decode')));
    await t.pumpAndSettle();
    // "collected" now appears in the screen message AND the success fact sheet.
    expect(find.textContaining('collected'), findsWidgets);
    expect(find.byType(PassportFactSheet), findsOneWidget); // the success UI
    expect(find.text('Scan another'), findsOneWidget); // resume affordance
  });
}
