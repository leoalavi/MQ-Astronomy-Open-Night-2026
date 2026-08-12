import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/models/user_location_fix.dart';
import 'package:aon2026/services/location_service.dart';
import 'package:aon2026/services/location_providers.dart';
import 'package:aon2026/widgets/locate_button.dart';

class _StubController extends LocationController {
  _StubController(this._snap);
  final LocationSnapshot _snap;
  int taps = 0;
  @override
  LocationSnapshot build() => _snap;
  @override
  Future<void> onLocateTapped() async => taps++; // spy, no service needed
}

ProviderContainer _c(LocationSnapshot snap) {
  final c = ProviderContainer(overrides: [
    locationControllerProvider.overrideWith(() => _StubController(snap)),
  ]);
  addTearDown(c.dispose);
  return c;
}

Widget _host(ProviderContainer c, {Locale? locale}) => UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: const Scaffold(body: LocateButton()),
      ),
    );

UserLocationFix _lowAcc() =>
    UserLocationFix(position: const LatLng(-33.7737, 151.1134), accuracyMeters: 500);

void main() {
  testWidgets('inactive -> "Show my location"', (t) async {
    await t.pumpWidget(_host(_c(const LocationSnapshot())));
    expect(find.bySemanticsLabel('Show my location'), findsOneWidget);
  });
  testWidgets('following -> "Stop following my location"', (t) async {
    await t.pumpWidget(
        _host(_c(const LocationSnapshot(active: true, following: true))));
    expect(find.bySemanticsLabel('Stop following my location'), findsOneWidget);
  });
  testWidgets('low-accuracy fix -> "Location accuracy is low"', (t) async {
    await t.pumpWidget(_host(
        _c(LocationSnapshot(active: true, following: true, fix: _lowAcc()))));
    expect(find.bySemanticsLabel('Location accuracy is low'), findsOneWidget);
  });
  testWidgets('denied -> "Location unavailable"', (t) async {
    await t.pumpWidget(_host(_c(const LocationSnapshot(status: LocationStatus.denied))));
    expect(find.bySemanticsLabel('Location unavailable'), findsOneWidget);
  });

  testWidgets('semantic node has a tap action that fires onLocateTapped',
      (t) async {
    final handle = t.ensureSemantics();
    final c = _c(const LocationSnapshot());
    await t.pumpWidget(_host(c));
    final node = t.getSemantics(find.bySemanticsLabel('Show my location'));
    // The node exposes a tap action to assistive tech (the crux of review #7:
    // excludeSemantics must not strip activation).
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    // And activating it fires the handler exactly once.
    await t.tap(find.bySemanticsLabel('Show my location'));
    await t.pump();
    final spy = c.read(locationControllerProvider.notifier) as _StubController;
    expect(spy.taps, 1);
    handle.dispose();
  });

  testWidgets('no overflow at 320x568 / 2.0', (t) async {
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1.0;
    t.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(
        _host(_c(const LocationSnapshot(active: true, following: true))));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  testWidgets('renders under the FA locale', (t) async {
    await t.pumpWidget(
        _host(_c(const LocationSnapshot()), locale: const Locale('fa')));
    await t.pumpAndSettle();
    expect(find.bySemanticsLabel('موقعیت من'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
