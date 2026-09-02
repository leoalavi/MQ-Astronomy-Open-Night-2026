import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/widgets/map_mode_toggle.dart';

Widget _app(MapMode v, ValueChanged<MapMode> onCh, {Locale locale = const Locale('en')}) =>
    MaterialApp(
      locale: locale,
      localizationsDelegates: AonL10n.localizationsDelegates,
      supportedLocales: AonL10n.supportedLocales,
      home: Scaffold(body: Center(child: MapModeToggle(value: v, onChanged: onCh))),
    );

void main() {
  testWidgets('renders 2 segments (Map, 360°); no Compass; panorama selectable via a single Semantics node', (t) async {
    MapMode? picked;
    await t.pumpWidget(_app(MapMode.campusMap, (m) => picked = m));
    final l = await AonL10n.delegate.load(const Locale('en'));
    // §0-E: one labeled node each (container + excludeSemantics), so findsOneWidget.
    expect(find.bySemanticsLabel(l.mapModeMap), findsOneWidget);
    expect(find.bySemanticsLabel(l.mapModePanorama), findsOneWidget);
    // Compass sub-tab removed — its segment must be gone.
    expect(find.bySemanticsLabel(l.mapModeCompass), findsNothing);
    await t.tap(find.bySemanticsLabel(l.mapModePanorama));
    expect(picked, MapMode.panorama);
  });

  for (final locale in const [Locale('en'), Locale('fa')]) {
    testWidgets('2 segments @ 320x568 / textScale 2.0 — no overflow (${locale.languageCode}) [§0-D]',
        (t) async {
      t.view.physicalSize = const Size(320, 568);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
        child: _app(MapMode.panorama, (_) {}, locale: locale),
      ));
      await t.pump();
      expect(t.takeException(), isNull); // FittedBox(scaleDown) prevents RenderFlex overflow
    });
  }
}
