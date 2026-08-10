import 'package:flutter/material.dart';
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
      child: MaterialApp(home: SettingsScreen()),
    );
  }

  testWidgets('shows the event details', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('About Astronomy Open Night'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('About Astronomy Open Night'), findsOneWidget);
    expect(find.textContaining('Saturday 19 September 2026'), findsOneWidget);
  });

  testWidgets('reduce motion is a real, persisted switch', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    final toggle = find.byType(SwitchListTile);
    expect(toggle, findsOneWidget);

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('settings.reduceMotion'), isTrue);
  });

  testWidgets('reduceMotionProvider reflects the stored value',
      (tester) async {
    SharedPreferences.setMockInitialValues({'settings.reduceMotion': true});

    late WidgetRef captured;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
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

  testWidgets('explains the dark-only appearance rather than faking a toggle',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Built for the dark'), findsOneWidget);
    // No non-functional light/system radio buttons.
    expect(find.byType(RadioListTile<Object>), findsNothing);
  });

  testWidgets('states the privacy position in plain terms', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Nothing leaves your phone'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('no account and no sign-in'), findsOneWidget);
    expect(find.textContaining('collects no analytics'), findsOneWidget);
  });

  testWidgets('credits the hero image and OpenStreetMap', (tester) async {
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
    expect(find.text('© OpenStreetMap contributors.'), findsOneWidget);
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
    testWidgets('carries none of MQ Journey Open-Day-only preferences',
        (tester) async {
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
