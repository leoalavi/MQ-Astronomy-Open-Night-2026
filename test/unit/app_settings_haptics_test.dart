import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aon2026/services/app_settings.dart';

/// The Haptics setting must (a) default ON, (b) reflect a toggle immediately,
/// and (c) survive a restart. `hapticsEnabledProvider` is what the app root
/// mirrors into `AonHaptics.globalEnabled`, so this is the persistence half of
/// "the Haptics switch actually works"; `haptics_test.dart` covers the gate.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults ON when nothing is stored', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(appSettingsProvider.future);
    expect(container.read(hapticsEnabledProvider), isTrue);
  });

  test('a toggle is reflected by hapticsEnabledProvider at once', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(appSettingsProvider.future);
    await container.read(appSettingsProvider.notifier).setHapticsEnabled(false);

    expect(container.read(hapticsEnabledProvider), isFalse);
  });

  test('the choice persists across a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final first = ProviderContainer();
    await first.read(appSettingsProvider.future);
    await first.read(appSettingsProvider.notifier).setHapticsEnabled(false);
    first.dispose();

    // A fresh container reads the same SharedPreferences the first one wrote.
    final second = ProviderContainer();
    addTearDown(second.dispose);
    await second.read(appSettingsProvider.future);
    expect(second.read(hapticsEnabledProvider), isFalse);
  });
}
