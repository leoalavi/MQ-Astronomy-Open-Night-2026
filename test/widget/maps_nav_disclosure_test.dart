import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/widgets/maps_nav_disclosure.dart';

Widget _host({required Locale locale, required void Function(bool) onResult}) => MaterialApp(
      locale: locale,
      localizationsDelegates: AonL10n.localizationsDelegates,
      supportedLocales: AonL10n.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async => onResult(await showMapsNavDisclosure(context)),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('EN: renders title/body/accept/decline; Accept → true', (t) async {
    bool? result;
    await t.pumpWidget(_host(locale: const Locale('en'), onResult: (r) => result = r));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    final l = await AonL10n.delegate.load(const Locale('en'));
    expect(find.text(l.mapNavDisclosureTitle), findsOneWidget);
    expect(find.text(l.mapNavDisclosureBody), findsOneWidget);
    expect(find.text(l.mapNavDisclosureAccept), findsOneWidget);
    expect(find.text(l.mapNavDisclosureDecline), findsOneWidget);

    await t.tap(find.text(l.mapNavDisclosureAccept));
    await t.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('Decline → false', (t) async {
    bool? result;
    await t.pumpWidget(_host(locale: const Locale('en'), onResult: (r) => result = r));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    final l = await AonL10n.delegate.load(const Locale('en'));
    await t.tap(find.text(l.mapNavDisclosureDecline));
    await t.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('FA: renders Persian strings', (t) async {
    await t.pumpWidget(_host(locale: const Locale('fa'), onResult: (_) {}));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    final fa = await AonL10n.delegate.load(const Locale('fa'));
    expect(find.text(fa.mapNavDisclosureTitle), findsOneWidget);
    expect(find.text(fa.mapNavDisclosureAccept), findsOneWidget);
  });

  testWidgets('320×568 @ textScale 2.0: no overflow, actions reachable', (t) async {
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    bool? result;
    await t.pumpWidget(MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
      child: _host(locale: const Locale('en'), onResult: (r) => result = r),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    final l = await AonL10n.delegate.load(const Locale('en'));
    await t.tap(find.text(l.mapNavDisclosureAccept));
    await t.pumpAndSettle();
    expect(result, isTrue);
  });
}
