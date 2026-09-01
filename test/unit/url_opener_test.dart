import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:aon2026/services/url_opener.dart';

/// Exercises the REAL `urlOpenerProvider` closure (not an override) against a
/// mocked `UrlLauncherPlatform`, so the one place that touches `url_launcher` is
/// proven end-to-end: it forwards to `launchUrl`, and — the point of the seam —
/// a launch that throws is swallowed into a `false` return, never an exception
/// into the UI (spec: a failed link must be reported honestly, not crash).
class _MockUrlLauncher extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  _MockUrlLauncher({this.throwOnLaunch = false});

  final bool throwOnLaunch;
  final List<String> launched = [];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> supportsMode(PreferredLaunchMode mode) async => true;

  @override
  Future<bool> supportsCloseForMode(PreferredLaunchMode mode) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    if (throwOnLaunch) throw Exception('platform refused to launch');
    launched.add(url);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('forwards to launchUrl and returns its result', () async {
    final mock = _MockUrlLauncher();
    UrlLauncherPlatform.instance = mock;

    final opener = ProviderContainer().read(urlOpenerProvider);
    final ok = await opener(Uri.parse('https://policy.example.test/privacy'));

    expect(ok, isTrue);
    expect(mock.launched, ['https://policy.example.test/privacy']);
  });

  test('a launch that throws is swallowed into false, never rethrown', () async {
    UrlLauncherPlatform.instance = _MockUrlLauncher(throwOnLaunch: true);

    final opener = ProviderContainer().read(urlOpenerProvider);
    final ok = await opener(Uri.parse('https://policy.example.test/privacy'));

    expect(ok, isFalse);
  });
}
