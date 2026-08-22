import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/services/maps_sdk_initializer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('aon2026/maps_sdk');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('ensureInitialized invokes initialize exactly once', () async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return true;
    });

    final init = PlatformMapsSdkInitializer();
    expect(await init.ensureInitialized(), isTrue);
    expect(await init.ensureInitialized(), isTrue);
    expect(calls, ['initialize'], reason: 'second call must be a no-op');
  });

  test('a PlatformException returns false and does not latch as done', () async {
    var attempts = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      attempts++;
      if (attempts == 1) throw PlatformException(code: 'NO_KEY');
      return true;
    });

    final init = PlatformMapsSdkInitializer();
    expect(await init.ensureInitialized(), isFalse);
    expect(await init.ensureInitialized(), isTrue,
        reason: 'a failed attempt must be retryable, not cached as failure');
    expect(attempts, 2);
  });

  test('a missing platform handler returns false rather than throwing', () async {
    // No mock handler registered at all.
    final init = PlatformMapsSdkInitializer();
    expect(await init.ensureInitialized(), isFalse);
  });

  test('a null result from the platform is treated as not initialised', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => null);
    final init = PlatformMapsSdkInitializer();
    expect(await init.ensureInitialized(), isFalse);
  });

  test('licence text is fetched over the channel', () async {
    messenger.setMockMethodCallHandler(
        channel,
        (call) async =>
            call.method == 'openSourceLicenseInfo' ? 'Apache 2.0 …' : null);

    final init = PlatformMapsSdkInitializer();
    expect(await init.openSourceLicenseInfo(), startsWith('Apache 2.0'));
  });

  test('a platform without licence text yields null, not a crash', () async {
    // No handler registered → MissingPluginException.
    final init = PlatformMapsSdkInitializer();
    expect(await init.openSourceLicenseInfo(), isNull);
  });
}
