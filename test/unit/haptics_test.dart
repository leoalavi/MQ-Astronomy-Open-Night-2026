import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/utils/haptics.dart';

/// The haptics wrapper exists for one reason: the user's "Haptic Feedback"
/// preference must actually silence the device. A wrapper that buzzes anyway
/// turns a setting into a lie, so every level is checked in both states.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> fired;

  setUp(() {
    fired = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        fired.add(call.arguments as String? ?? 'default');
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test('enabled: each level reaches the platform once', () async {
    await AonHaptics.light(true);
    await AonHaptics.medium(true);
    await AonHaptics.heavy(true);
    await AonHaptics.selection(true);

    expect(fired, [
      'HapticFeedbackType.lightImpact',
      'HapticFeedbackType.mediumImpact',
      'HapticFeedbackType.heavyImpact',
      'HapticFeedbackType.selectionClick',
    ]);
  });

  test('disabled: nothing reaches the platform at all', () async {
    await AonHaptics.light(false);
    await AonHaptics.medium(false);
    await AonHaptics.heavy(false);
    await AonHaptics.selection(false);

    expect(fired, isEmpty);
  });

  // The "Haptics" setting acts through `globalEnabled` (synced from
  // `hapticsEnabledProvider` in the app root). Most call sites pass a literal
  // `true` — the tab bar, save button and passport scan — so the master switch
  // is the ONLY thing that can silence them. These pin exactly that seam.
  group('master switch (the Haptics setting)', () {
    tearDown(() => AonHaptics.globalEnabled = true); // never leak OFF state

    test('OFF silences even a call site that asks for haptics', () async {
      AonHaptics.globalEnabled = false;
      await AonHaptics.selection(true);
      await AonHaptics.light(true);
      await AonHaptics.medium(true);
      await AonHaptics.heavy(true);
      expect(fired, isEmpty);
    });

    test('ON lets an asking call site through', () async {
      AonHaptics.globalEnabled = true;
      await AonHaptics.selection(true);
      expect(fired, ['HapticFeedbackType.selectionClick']);
    });

    test('a per-call opt-out still wins while the switch is ON', () async {
      AonHaptics.globalEnabled = true;
      await AonHaptics.light(false);
      expect(fired, isEmpty);
    });
  });
}
