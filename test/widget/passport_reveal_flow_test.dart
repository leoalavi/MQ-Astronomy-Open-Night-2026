import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/screens/passport_scan_screen.dart';
import 'package:aon2026/services/passport_providers.dart';
import 'package:aon2026/data/stamp_stations_data.dart';

// Records HapticFeedback platform calls (method + argument) so we can assert
// EXACTLY one light-impact, ignoring any other haptic that might fire.
final List<MethodCall> _haptics = [];
void _installHapticSpy() {
  _haptics.clear();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'HapticFeedback.vibrate') _haptics.add(call);
    return null;
  });
  addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
}

int get _lightImpacts => _haptics
    .where((c) => c.arguments == 'HapticFeedbackType.lightImpact')
    .length;

Widget _app(Widget screen, {Set<String> snapshot = const {}}) => ProviderScope(
      overrides: [passportSnapshotProvider.overrideWithValue(snapshot)],
      child: MaterialApp.router(
        routerConfig: GoRouter(routes: [
          GoRoute(path: '/', builder: (_, _) => screen),
          GoRoute(
              path: Routes.passportReward,
              builder: (_, _) => const Scaffold(body: Text('REWARD'))),
        ]),
      ),
    );

// A scan screen whose scanner button emits a chosen decoded code.
Widget _scan(String decoded) => PassportScanScreen(
      scannerBuilder: (onDecoded) => ElevatedButton(
        key: const Key('emit'),
        onPressed: () => onDecoded(decoded),
        child: const Text('emit'),
      ),
    );

// Reveals the scanner and emits the decoded code, clearing any haptics from the
// scanner-selection phase FIRST so the assertion measures only the collect.
Future<void> _scanOnce(WidgetTester t) async {
  await t.tap(find.text('Scan QR code'));
  await t.pumpAndSettle();
  _haptics.clear();
  await t.tap(find.byKey(const Key('emit')));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('a 1st collect opens the fact sheet and fires one light impact',
      (t) async {
    _installHapticSpy();
    await t.pumpWidget(_app(_scan('AON2026:AON-A-TBC')));
    await _scanOnce(t);
    // Macquarie Theatre fact title (debug build shows the draft).
    expect(find.textContaining('Gravity can bend light'), findsOneWidget);
    expect(_lightImpacts, 1);
  });

  testWidgets('the 9th collect goes to reward, not the fact sheet', (t) async {
    _installHapticSpy();
    final firstEight =
        StampStationsData.all.take(8).map((s) => s.venueId).toSet();
    final ninthCode = StampStationsData.all[8].code;
    await t.pumpWidget(_app(_scan('AON2026:$ninthCode'), snapshot: firstEight));
    await _scanOnce(t);
    expect(find.text('REWARD'), findsOneWidget);
    expect(_lightImpacts, 1); // haptic still fires once on the 9th
  });

  testWidgets('a duplicate fires no haptic and opens no sheet', (t) async {
    _installHapticSpy();
    await t.pumpWidget(
        _app(_scan('AON2026:AON-A-TBC'), snapshot: {'macquarie-theatre'}));
    await _scanOnce(t);
    expect(_lightImpacts, 0);
    expect(find.textContaining('Gravity can bend light'), findsNothing);
  });

  testWidgets('an unknown code fires no haptic and opens no sheet', (t) async {
    _installHapticSpy();
    await t.pumpWidget(_app(_scan('AON2026:NOT-A-CODE')));
    await _scanOnce(t);
    expect(_lightImpacts, 0);
    expect(find.byType(PassportScanScreen), findsOneWidget); // still on capture
    expect(find.text('REWARD'), findsNothing);
  });

  testWidgets('disabled collection fires no haptic and opens no sheet',
      (t) async {
    _installHapticSpy();
    await t.pumpWidget(ProviderScope(
      overrides: [
        passportSnapshotProvider.overrideWithValue(<String>{}),
        passportCollectionEnabledProvider.overrideWithValue(false),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(routes: [
          GoRoute(path: '/', builder: (_, _) => _scan('AON2026:AON-A-TBC')),
          GoRoute(
              path: Routes.passportReward,
              builder: (_, _) => const Scaffold(body: Text('REWARD'))),
        ]),
      ),
    ));
    await _scanOnce(t);
    expect(_lightImpacts, 0);
    expect(find.text('REWARD'), findsNothing);
  });
}
