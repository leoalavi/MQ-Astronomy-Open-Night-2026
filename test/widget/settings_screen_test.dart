import 'package:flutter/material.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aon2026/screens/settings_screen.dart';
import 'package:aon2026/services/app_settings.dart';

/// Settings.
///
/// The governing rule from the brief is "do not expose dead settings", so the
/// tests are as much about what is *absent* as what is present.
void main() {
  Widget harness() {
    SharedPreferences.setMockInitialValues({});
    return const ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: SettingsScreen(),
      ),
    );
  }

  testWidgets('shows the event details', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.textContaining('Saturday 19 September 2026'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('About Astronomy Open Night'), findsOneWidget);
    expect(find.textContaining('Saturday 19 September 2026'), findsOneWidget);
  });

  testWidgets('developer attribution lives in the Credits section', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    // Credits is the last section; scroll to the developer line at the bottom.
    await tester.scrollUntilVisible(
      find.textContaining('Leo Alavi'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Leo Alavi'), findsOneWidget);
    expect(find.textContaining('Mohammad Raouf Abedini'), findsOneWidget);
  });

  testWidgets('reduce motion is a real, persisted switch', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    // Settings is a lazy ListView with two switches now (Reduce motion +
    // Haptics); target the Reduce-motion one by its title.
    final toggle = find.ancestor(
      of: find.text('Reduce motion'),
      matching: find.byType(SwitchListTile),
    );
    await tester.scrollUntilVisible(toggle, 200);
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    expect(toggle, findsOneWidget);

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('settings.reduceMotion'), isTrue);
  });

  testWidgets('haptics is a real, persisted switch (default on)', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    final toggle = find.ancestor(
      of: find.text('Haptics'),
      matching: find.byType(SwitchListTile),
    );
    await tester.scrollUntilVisible(toggle, 200);
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    expect(toggle, findsOneWidget);
    // Defaults on, so it starts true.
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('settings.hapticsEnabled'), isFalse);
  });

  testWidgets('reduceMotionProvider reflects the stored value', (tester) async {
    SharedPreferences.setMockInitialValues({'settings.reduceMotion': true});

    late WidgetRef captured;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AonL10n.localizationsDelegates,
          supportedLocales: AonL10n.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) {
              captured = ref;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // appSettingsProvider is an AsyncNotifier — await its first resolution
    // before asserting on the derived provider, or we read the pre-load
    // default rather than the stored value.
    await captured.read(appSettingsProvider.future);
    await tester.pumpAndSettle();

    expect(captured.read(reduceMotionProvider), isTrue);
  });

  testWidgets('offers a real three-way appearance choice', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Follow my phone'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    // Dark is recommended, not forced.
    expect(find.textContaining('Recommended'), findsOneWidget);
  });

  testWidgets('choosing Light persists the preference', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('settings.themeMode'), 'light');
  });

  testWidgets('states the privacy position in plain terms', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('What this app shares'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    // Pin the four things the card must *state* — not one phrasing of them.
    // `46dc81e` rewrote this copy (Android ML Kit diagnostics, backup limits)
    // and the assertions below were left behind, which is how they came to
    // demand wording the app no longer ships.
    expect(find.textContaining('No account or advertising'), findsOneWidget);
    expect(find.textContaining('stored locally'), findsOneWidget);
    expect(find.textContaining('ML Kit'), findsOneWidget);
    expect(
        find.textContaining('send the route origin and destination to Google'),
        findsOneWidget);
    // Task 7: the card must never again promise that nothing leaves the phone —
    // location does, once the visitor asks for walking directions. And it may
    // not claim the app collects no analytics: ML Kit reports diagnostics on
    // Android. `privacy_copy_truth_test.dart` asserts the same of the string
    // itself; these two must never disagree.
    expect(find.textContaining('Nothing leaves your phone'), findsNothing);
    expect(find.textContaining('collects no analytics'), findsNothing);
  });

  testWidgets('credits the hero image and the real map sources', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('A Deep Triangulum Galaxy — Aleix Roig, 2026'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('A Deep Triangulum Galaxy — Aleix Roig, 2026'),
      findsOneWidget,
    );
    // Task 5: the app makes no OSM tile requests, so it no longer credits OSM.
    expect(find.textContaining('OpenStreetMap'), findsNothing);
    expect(
      find.text('Campus map: Astronomy Open Night 2026 programme. Walking '
          'directions and the map they appear on are provided by Google.'),
      findsOneWidget,
    );
  });

  testWidgets('reduce motion actually reaches the widget tree', (tester) async {
    // The setting must change behaviour, not just persist a bool. AonApp folds
    // it into MediaQuery.disableAnimations, which is what the tactile and
    // glass surfaces read.
    SharedPreferences.setMockInitialValues({'settings.reduceMotion': true});

    late bool disabled;
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            final reduce = ref.watch(reduceMotionProvider);
            return MaterialApp(
              localizationsDelegates: AonL10n.localizationsDelegates,
              supportedLocales: AonL10n.supportedLocales,
              home: Builder(
                builder: (context) {
                  final media = MediaQuery.of(context);
                  return MediaQuery(
                    data: media.copyWith(
                      disableAnimations: media.disableAnimations || reduce,
                    ),
                    child: Builder(
                      builder: (context) {
                        disabled = MediaQuery.disableAnimationsOf(context);
                        return const SizedBox.shrink();
                      },
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(disabled, isTrue);
  });

  group('no dead Open Day settings', () {
    testWidgets('carries none of MQ Journey Open-Day-only preferences', (
      tester,
    ) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      // This app has no account, no push, no stamp trail and no timetable, so
      // none of those settings may appear.
      for (final absent in [
        'Account',
        'Sign in',
        'Notifications',
        'Stamps',
        'Timetable',
        'Favourites',
        'Open Day',
      ]) {
        expect(
          find.textContaining(absent),
          findsNothing,
          reason: '"$absent" is an Open Day concept with no behaviour here',
        );
      }
    });
  });
}
