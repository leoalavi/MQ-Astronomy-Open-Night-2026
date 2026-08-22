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
}
