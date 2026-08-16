import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/data/campus_variants_data.dart';
import 'package:aon2026/services/campus_variant_providers.dart';
import 'package:aon2026/widgets/campus_variant_picker.dart';

Widget _host(ProviderContainer c, {Locale? locale}) =>
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: const Scaffold(body: CampusVariantPicker()),
      ),
    );

void main() {
  testWidgets('lists Campus map + 3 public variants, NOT Permit areas',
      (t) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await t.pumpWidget(_host(c));
    await t.pumpAndSettle();
    expect(find.text('Campus map'), findsOneWidget);
    expect(find.text('Parking'), findsOneWidget);
    expect(find.text('Accessible routes'), findsOneWidget);
    expect(find.text('Drinking water'), findsOneWidget);
    // exactly the four rows (base + 3), permits absent
    expect(find.byType(RadioListTile<CampusMapVariant>), findsNWidgets(4));
  });

  testWidgets('selecting Parking updates the controller', (t) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await t.pumpWidget(_host(c));
    await t.pumpAndSettle();
    await t.tap(find.text('Parking'));
    await t.pump();
    expect(c.read(campusVariantProvider), CampusMapVariant.parking);
  });

  testWidgets('one RadioGroup owns the selection semantics', (t) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await t.pumpWidget(_host(c));
    await t.pumpAndSettle();
    expect(find.byType(RadioGroup<CampusMapVariant>), findsOneWidget);
  });

  testWidgets('320x568 / 2.0: last row scrolls into view AND is tappable',
      (t) async {
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1.0;
    t.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await t.pumpWidget(_host(c));
    await t.pumpAndSettle();
    // find.text alone matches an OFF-SCREEN widget inside a SingleChildScrollView
    // (and a scroll view never RenderFlex-overflows, so takeException is vacuous
    // here). Scroll the last row in, then TAP it — that proves hit-testability.
    final target = find.text('Drinking water');
    await t.scrollUntilVisible(target, 100,
        scrollable: find.byType(Scrollable).first);
    await t.pumpAndSettle();
    await t.tap(target);
    await t.pump();
    expect(c.read(campusVariantProvider), CampusMapVariant.water);
    expect(t.takeException(), isNull);
  });

  testWidgets('renders under FA without exception', (t) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await t.pumpWidget(_host(c, locale: const Locale('fa')));
    await t.pumpAndSettle();
    expect(find.text('پارکینگ'), findsOneWidget); // FA "Parking"
    expect(t.takeException(), isNull);
  });
}
