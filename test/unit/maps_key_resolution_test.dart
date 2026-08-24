import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/services/maps_nav_providers.dart';
import 'package:aon2026/services/maps_sdk_initializer.dart';

/// How the Google Maps key is found at runtime.
///
/// ## The bug this file exists to prevent
///
/// The key was read ONLY from `String.fromEnvironment('MAPS_API_KEY')`, which is
/// resolved at COMPILE time. An app launched from Xcode, or with a plain
/// `flutter run` — anything without `--dart-define-from-file=.env` — therefore
/// saw an empty key and told the user "Google Maps is not configured yet", on a
/// device whose Info.plist / manifest was perfectly well keyed. That is exactly
/// what the on-device screenshot showed.
///
/// The fix resolves the key at runtime: the Dart define first, then the
/// platform's own configuration. These tests pin both halves.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('aon2026/maps_sdk');

  /// Installs a fake native side that reports [key] for `getMapsKey`.
  void nativeKey(String? key, {List<String>? log}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      log?.add(call.method);
      if (call.method == 'getMapsKey') return key;
      if (call.method == 'initialize') return true;
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
  }

  group('key resolution', () {
    test('a Dart-defined key is used, and native is never consulted', () async {
      final log = <String>[];
      nativeKey('native-key', log: log);
      final init = PlatformMapsSdkInitializer(apiKey: 'dart-key');
      expect(await init.resolveKey(), 'dart-key');
      expect(log, isEmpty, reason: 'the define already answered the question');
    });

    test('with NO Dart define, the platform key is used (the reported bug)', () async {
      nativeKey('native-key');
      final init = PlatformMapsSdkInitializer(); // no --dart-define
      expect(await init.resolveKey(), 'native-key');
    });

    test('no key anywhere resolves empty, not an exception', () async {
      nativeKey(null);
      expect(await PlatformMapsSdkInitializer().resolveKey(), '');
    });

    test('a platform with no handler at all resolves empty', () async {
      // MissingPluginException path (web/desktop/test host) — must not throw.
      expect(await PlatformMapsSdkInitializer().resolveKey(), '');
    });
  });

  group('the resolved key drives the capability gate', () {
    ProviderContainer containerWith(String key, MapsNavPlatform platform) {
      final c = ProviderContainer(overrides: [
        nativeMapsApiKeyProvider.overrideWithValue(key),
        mapsNavPlatformProvider.overrideWithValue(platform),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('a resolved key enables the embedded map', () {
      final c = containerWith('k', MapsNavPlatform.ios);
      expect(c.read(embeddedMapConfiguredProvider), isTrue);
      expect(c.read(googleNavEnabledProvider), isTrue,
          reason: 'one key should light the whole Directions flow');
    });

    test('an empty resolved key keeps the flow dark', () {
      final c = containerWith('', MapsNavPlatform.ios);
      expect(c.read(embeddedMapConfiguredProvider), isFalse);
      expect(c.read(googleNavEnabledProvider), isFalse);
    });

    test('the resolved key also backs the Routes call when no Routes define exists',
        () {
      // The Routes keys are compile-time too, so the same keyless launch left
      // routing disabled even once the map was keyed.
      final c = containerWith('k', MapsNavPlatform.ios);
      expect(c.read(activeRoutesKeyProvider), 'k');
      expect(c.read(routesConfiguredProvider), isTrue);
    });

    test('an explicit platform Routes key still WINS over the fallback', () {
      final c = ProviderContainer(overrides: [
        nativeMapsApiKeyProvider.overrideWithValue('maps-key'),
        iosRoutesKeyProvider.overrideWithValue('routes-key'),
        mapsNavPlatformProvider.overrideWithValue(MapsNavPlatform.ios),
      ]);
      addTearDown(c.dispose);
      expect(c.read(activeRoutesKeyProvider), 'routes-key',
          reason: 'a restricted production build must keep its dedicated key');
    });

    test('web/desktop never gets a Routes key, even with a maps key', () {
      final c = containerWith('k', MapsNavPlatform.unsupported);
      expect(c.read(activeRoutesKeyProvider), '');
      expect(c.read(googleNavEnabledProvider), isFalse);
    });
  });
}
