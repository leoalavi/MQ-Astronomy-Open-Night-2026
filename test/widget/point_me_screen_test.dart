import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/models/user_location_fix.dart';
import 'package:aon2026/services/heading_service.dart';
import 'package:aon2026/services/location_providers.dart';
import 'package:aon2026/services/point_me_controller.dart';
import 'package:aon2026/widgets/map_config.dart';
import 'package:aon2026/screens/point_me_screen.dart';
import '../support/fake_heading_service.dart';
import '../support/fake_location_service.dart';

ProviderContainer _c(FakeHeadingService h, FakeLocationService loc) {
  final c = ProviderContainer(overrides: [
    headingServiceProvider.overrideWithValue(h),
    locationServiceProvider.overrideWithValue(loc),
  ]);
  addTearDown(c.dispose);
  return c;
}

Widget _app(ProviderContainer c, String venueId,
        {Locale? locale, bool reduceMotion = false}) =>
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        // Preserve ambient MediaQuery (size, textScaler) and only flip the flag.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: PointMeScreen(venueId: venueId),
      ),
    );

const _venueId = 'macquarie-theatre'; // a real venue id with coordinates

// In testWidgets the fake clock only advances on pump — a bare
// `await Future.delayed()` on a Timer would hang, so pump instead.
Future<void> _fix(WidgetTester t, ProviderContainer c, FakeLocationService loc,
    {double acc = 8}) async {
  await c.read(locationControllerProvider.notifier).onLocateTapped();
  loc.emit(UserLocationFix(position: MapConfig.campusCentre, accuracyMeters: acc));
  await t.pump();
}

Future<void> _heading(WidgetTester t, FakeHeadingService h, double deg) async {
  h.emit(HeadingSample(
      availability: HeadingAvailability.available, magneticHeadingDegrees: deg));
  await t.pump();
  await t.pump();
}

void main() {
  testWidgets('unknown venue → safe message, no target claimed, no crash',
      (t) async {
    final c = _c(FakeHeadingService(), FakeLocationService());
    await t.pumpWidget(_app(c, 'does-not-exist'));
    await t.pump();
    expect(find.textContaining("can't find"), findsOneWidget);
    expect(c.read(pointMeActiveProvider), isFalse); // no lifecycle claim
    expect(t.takeException(), isNull);
  });

  testWidgets('opening the screen claims pointMeActive; leaving clears it',
      (t) async {
    final c = _c(FakeHeadingService(), FakeLocationService());
    await t.pumpWidget(_app(c, _venueId));
    await t.pump();
    expect(c.read(pointMeActiveProvider), isTrue);
    await t.pumpWidget(const SizedBox()); // dispose the screen
    await t.pump();
    expect(c.read(pointMeActiveProvider), isFalse);
  });

  testWidgets('no fix → needs-location message + Enable button that activates',
      (t) async {
    final c = _c(FakeHeadingService(), FakeLocationService());
    await t.pumpWidget(_app(c, _venueId));
    await t.pump();
    expect(find.textContaining('Turn on location'), findsOneWidget);
    await t.tap(find.byKey(const Key('point-me-enable')));
    await t.pump();
    expect(c.read(locationControllerProvider).active, isTrue); // onLocateTapped
  });

  testWidgets('heading available → arrow shown with a non-liveRegion a11y label',
      (t) async {
    final handle = t.ensureSemantics();
    final h = FakeHeadingService();
    final loc = FakeLocationService();
    final c = _c(h, loc);
    await t.pumpWidget(_app(c, _venueId));
    await _fix(t, c, loc);
    await _heading(t, h, 0);
    expect(find.byKey(const Key('point-me-arrow')), findsOneWidget);
    final node = t.getSemantics(find.byKey(const Key('point-me-arrow')));
    final data = node.getSemanticsData();
    expect(data.flagsCollection.isLiveRegion, isFalse); // no announce spam
    expect(data.label, contains('Macquarie Theatre'));
    expect(data.label, contains('m')); // distance present
    handle.dispose();
  });

  testWidgets('turning the phone updates the a11y label (side follows heading)',
      (t) async {
    final handle = t.ensureSemantics();
    final h = FakeHeadingService();
    final loc = FakeLocationService();
    final c = _c(h, loc);
    await t.pumpWidget(_app(c, _venueId));
    await _fix(t, c, loc);
    await _heading(t, h, 0);
    final a = t.getSemantics(find.byKey(const Key('point-me-arrow'))).label;
    await _heading(t, h, 180); // turn around
    final b = t.getSemantics(find.byKey(const Key('point-me-arrow'))).label;
    expect(a, isNot(equals(b))); // side/label tracks the sensor
    handle.dispose();
  });

  testWidgets('reduced motion: arrow does NOT use an implicit rotation tween',
      (t) async {
    final h = FakeHeadingService();
    final loc = FakeLocationService();
    final c = _c(h, loc);
    await t.pumpWidget(_app(c, _venueId, reduceMotion: true));
    await _fix(t, c, loc);
    await _heading(t, h, 30);
    expect(find.byKey(const Key('point-me-arrow')), findsOneWidget); // still reorients
    expect(find.byType(AnimatedRotation), findsNothing); // snap, not tween
  });

  testWidgets('motion on: arrow uses AnimatedRotation', (t) async {
    final h = FakeHeadingService();
    final loc = FakeLocationService();
    final c = _c(h, loc);
    await t.pumpWidget(_app(c, _venueId));
    await _fix(t, c, loc);
    await _heading(t, h, 30);
    expect(find.byType(AnimatedRotation), findsOneWidget);
  });

  testWidgets('low-accuracy fix → improving-accuracy note, no arrow', (t) async {
    final h = FakeHeadingService();
    final loc = FakeLocationService();
    final c = _c(h, loc);
    await t.pumpWidget(_app(c, _venueId));
    await _fix(t, c, loc, acc: 250); // > 200 m ⇒ unreliable
    await _heading(t, h, 0);
    expect(find.byKey(const Key('point-me-arrow')), findsNothing);
    expect(find.textContaining('rough'), findsOneWidget); // improving-accuracy copy
  });

  testWidgets('unsupported → bearing fallback card, no arrow', (t) async {
    final h = FakeHeadingService();
    final loc = FakeLocationService();
    final c = _c(h, loc);
    await t.pumpWidget(_app(c, _venueId));
    await _fix(t, c, loc);
    h.emit(const HeadingSample(availability: HeadingAvailability.unsupported));
    await t.pump();
    await t.pump();
    expect(find.byKey(const Key('point-me-arrow')), findsNothing);
    expect(find.textContaining('compass sensor'), findsOneWidget);
  });

  testWidgets('no overflow at 320x568 / 2.0', (t) async {
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1.0;
    t.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    final h = FakeHeadingService();
    final loc = FakeLocationService();
    final c = _c(h, loc);
    await t.pumpWidget(_app(c, _venueId));
    await _fix(t, c, loc);
    await _heading(t, h, 30);
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  testWidgets('renders under FA locale', (t) async {
    final c = _c(FakeHeadingService(), FakeLocationService());
    await t.pumpWidget(_app(c, _venueId, locale: const Locale('fa')));
    await t.pump();
    expect(t.takeException(), isNull);
  });
}
