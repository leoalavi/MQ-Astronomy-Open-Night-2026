import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/screens/home_screen.dart';
import 'package:aon2026/screens/passport_screen.dart';
import 'package:aon2026/services/clock.dart';
import 'package:aon2026/services/passport_providers.dart';
import 'package:aon2026/widgets/liquid_tab_bar.dart';
import 'package:aon2026/widgets/passport_home_card.dart';

/// First launch goes STRAIGHT into the app. This is a decision, not an
/// omission — see docs/onboarding-decision.md.
///
/// An event-companion app is opened by people already walking across a dark
/// campus. Every second between tap and "what's on / where is it" is a cost,
/// so there is no welcome carousel, no permission pre-prompt and no gate of
/// any kind. The screens explain themselves in place instead (the passport
/// hint below is the one contextual hint that decision added).
///
/// If someone later adds onboarding, this test is the tripwire that forces the
/// decision to be re-made in the open rather than slipped in.
void main() {
  Widget app() {
    SharedPreferences.setMockInitialValues({}); // a fresh install
    return ProviderScope(
      overrides: [
        baseClockProvider.overrideWithValue(FixedClock(EventInfo.at(19, 0))),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        theme: AonTheme.build(),
        routerConfig: buildRouter(),
      ),
    );
  }

  testWidgets(
      'a fresh install opens directly on Home — no onboarding, no dialog, '
      'no permission prompt, every tab already there', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // Straight to the real first screen.
    expect(find.byType(HomeScreen), findsOneWidget);
    // Nothing modal stands between the visitor and the app.
    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
    // The first frame already answers "what is this?" and "what can I do?".
    expect(find.text(EventInfo.name), findsWidgets);
    expect(find.byType(LiquidTabBar), findsOneWidget);
    // The passport card sits under the hero; one short scroll on a small
    // viewport (Home is a lazy sliver list, so it builds as it comes in).
    await tester.dragUntilVisible(
      find.byType(PassportHomeCard),
      find.byType(CustomScrollView),
      const Offset(0, -200),
    );
    expect(find.byType(PassportHomeCard), findsOneWidget);
    // Program, My Night, Map, Info and Settings are one tap away.
    for (final icon in const [
      Icons.list_alt_outlined,
      Icons.star_outline_rounded,
      Icons.map_outlined,
      Icons.info_outline_rounded,
      Icons.settings_outlined,
    ]) {
      expect(
        find.descendant(
            of: find.byType(LiquidTabBar), matching: find.byIcon(icon)),
        findsOneWidget,
      );
    }
  });

  testWidgets(
      'the passport explains itself the first time it is opened, and stops '
      'once the first stamp is in', (tester) async {
    SharedPreferences.setMockInitialValues({});
    Widget passport(Set<String> snapshot) => ProviderScope(
          overrides: [
            passportSnapshotProvider.overrideWithValue(snapshot),
            passportCollectionEnabledProvider.overrideWithValue(true),
          ],
          child: MaterialApp(
            localizationsDelegates: AonL10n.localizationsDelegates,
            supportedLocales: AonL10n.supportedLocales,
            theme: AonTheme.build(),
            home: const PassportScreen(),
          ),
        );

    await tester.pumpWidget(passport(const {}));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('passport-how-it-works')), findsOneWidget);
    expect(find.textContaining('QR sign'), findsOneWidget);

    // Tear the scope down first: the passport notifier seeds from its snapshot
    // once, in build(), so a new snapshot needs a new container.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(passport(const {'macquarie-theatre'}));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('passport-how-it-works')), findsNothing);
  });

  testWidgets('the passport hint is real Persian, not English fallback',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ProviderScope(
      overrides: [
        passportCollectionEnabledProvider.overrideWithValue(true),
      ],
      child: MaterialApp(
        locale: const Locale('fa'),
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        theme: AonTheme.build(),
        home: const PassportScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    final text = tester.widget<Text>(
      find.byKey(const Key('passport-how-it-works')),
    );
    expect(text.data, contains('QR'));
    expect(text.data, isNot(contains('venues')));
    expect(text.data, contains('نجومی'));
  });
}
