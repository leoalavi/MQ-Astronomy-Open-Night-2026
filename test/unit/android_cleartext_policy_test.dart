import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The panorama viewer is served from an in-process HTTP server on loopback and
/// loaded into a WebView as `http://localhost:8459/...`. Android denies cleartext
/// for every domain by default at `targetSdk >= 28` and WebView honours that
/// policy, so the app needs an explicit exception.
///
/// The danger is not that the exception exists — it is how someone will widen it
/// the next time a network problem appears. `usesCleartextTraffic="true"`
/// re-permits plaintext to every host on the internet to solve a loopback
/// problem, and it is a one-line change that no other test would notice.
void main() {
  final manifest =
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
  final config =
      File('android/app/src/main/res/xml/network_security_config.xml');

  test('the manifest points at a network security config', () {
    expect(manifest, contains('android:networkSecurityConfig='),
        reason: 'without it the loopback panorama load has no permission to '
            'succeed on targetSdk 36');
    expect(config.existsSync(), isTrue);
  });

  test('cleartext is NOT permitted globally', () {
    expect(manifest, isNot(contains('usesCleartextTraffic="true"')),
        reason: 'a loopback problem must never be solved by re-permitting '
            'plaintext to every host on the internet');

    final xml = config.readAsStringSync();
    expect(xml, contains('<base-config cleartextTrafficPermitted="false"'),
        reason: 'everything except the named loopback domains stays denied');
  });

  test('the exception covers loopback and nothing else', () {
    final xml = config.readAsStringSync();
    final domains = RegExp(r'<domain[^>]*>([^<]+)</domain>')
        .allMatches(xml)
        .map((m) => m.group(1)!.trim())
        .toList();

    expect(domains, isNotEmpty);
    expect(domains.toSet(), {'localhost', '127.0.0.1'},
        reason: 'only loopback is exempt; any other host here is a widening '
            'that needs its own justification and its own test');
    expect(xml, isNot(contains('includeSubdomains="true"')),
        reason: 'subdomain inclusion on a loopback exception is meaningless '
            'and only broadens the surface');
  });
}
