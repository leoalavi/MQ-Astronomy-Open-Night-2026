import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/screens/google_nav_screen.dart';
import 'package:aon2026/services/maps_consent_providers.dart';
import 'package:aon2026/services/maps_consent_store.dart';
import 'package:aon2026/services/maps_nav_providers.dart';
import 'package:aon2026/services/maps_sdk_initializer.dart';
import 'package:aon2026/widgets/embedded_map.dart';

class _RecordingSurface implements EmbeddedMapSurface {
  int builds = 0;

  @override
  Widget build({
    required GeoBounds bounds,
    required (double lat, double lng) origin,
    required (double lat, double lng) destination,
    required List<(double lat, double lng)> route,
  }) {
    builds++;
    return const SizedBox(key: Key('nav-google-surface'));
  }
}

class _Initializer implements MapsSdkInitializer {
  _Initializer(this.ready);
  final bool ready;

  @override
  Future<bool> ensureInitialized() async => ready;

  @override
  Future<String?> openSourceLicenseInfo() async => null;

  @override
  Future<String> resolveKey() async => '';
}

ProviderContainer _container({required bool sdkReady}) {
  final c = ProviderContainer(overrides: [
    mapsConsentSnapshotProvider.overrideWithValue(MapsConsent.accepted),
    mapsSdkInitializerProvider.overrideWithValue(_Initializer(sdkReady)),
    embeddedMapConfiguredProvider.overrideWithValue(true),
    androidRoutesKeyProvider.overrideWithValue('test-key'),
    iosRoutesKeyProvider.overrideWithValue('test-key'),
  ]);
  addTearDown(c.dispose);
  return c;
}

Future<void> _pump(
    WidgetTester t, ProviderContainer c, _RecordingSurface s) async {
  await t.pumpWidget(UncontrolledProviderScope(
    container: c,
    child: MaterialApp(
      localizationsDelegates: AonL10n.localizationsDelegates,
      supportedLocales: AonL10n.supportedLocales,
      home: GoogleNavScreen(placeKey: 'venue:observatory', surface: s),
    ),
  ));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('GoogleNavScreen builds no map while the SDK is unkeyed',
      (t) async {
    final surface = _RecordingSurface();
    await _pump(t, _container(sdkReady: false), surface);

    expect(surface.builds, 0,
        reason: 'Task 1 deferred provideAPIKey off launch; consent alone must '
            'not be enough to construct a GoogleMap');
    expect(find.byKey(const Key('nav-google-surface')), findsNothing);
  });
}
