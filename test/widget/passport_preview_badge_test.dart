import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/l10n/generated/app_localizations_en.dart';
import 'package:aon2026/services/passport_preview.dart';
import 'package:aon2026/widgets/passport_preview_badge.dart';

/// The badge exists so a practice stamp is never mistaken for one earned at a
/// venue. Same rule the simulated-location badge follows: the label travels
/// with the thing it qualifies, not with the switch that turned it on.
Widget _host({MediaQueryData? mq}) {
  const badge = Scaffold(body: PassportPreviewBadge());
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AonL10n.localizationsDelegates,
      supportedLocales: AonL10n.supportedLocales,
      home: mq == null ? badge : MediaQuery(data: mq, child: badge),
    ),
  );
}

ProviderContainer _containerOf(WidgetTester t) =>
    ProviderScope.containerOf(t.element(find.byType(PassportPreviewBadge)));

void main() {
  final badge = find.byKey(const Key('passport-preview-badge'));

  testWidgets('renders nothing while preview is off', (t) async {
    await t.pumpWidget(_host());

    expect(badge, findsNothing);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('appears, with its label, once preview is engaged', (t) async {
    await t.pumpWidget(_host());

    _containerOf(t).read(passportPreviewProvider.notifier).set(true);
    await t.pump();

    expect(badge, findsOneWidget);
    expect(find.text(AonL10nEn().passportPreviewBadge), findsOneWidget);
  });

  testWidgets('disappears again when preview is turned off', (t) async {
    await t.pumpWidget(_host());
    final notifier = _containerOf(t).read(passportPreviewProvider.notifier);

    notifier.set(true);
    await t.pump();
    expect(badge, findsOneWidget);

    notifier.set(false);
    await t.pump();
    expect(badge, findsNothing);
  });

  // 320×568 at textScale 2.0 is the repo's accessibility floor. A RenderFlex
  // overflow raises a FlutterError, which fails the test on its own — the
  // assertion below is that the badge is still THERE and still legible, which
  // an overflow-avoiding `SizedBox.shrink()` would not satisfy.
  testWidgets('stays rendered at 320x568 with textScale 2.0', (t) async {
    await t.pumpWidget(
      _host(
        mq: const MediaQueryData(
          size: Size(320, 568),
          textScaler: TextScaler.linear(2.0),
        ),
      ),
    );

    _containerOf(t).read(passportPreviewProvider.notifier).set(true);
    await t.pump();

    expect(badge, findsOneWidget);
    expect(find.text(AonL10nEn().passportPreviewBadge), findsOneWidget);
  });
}
