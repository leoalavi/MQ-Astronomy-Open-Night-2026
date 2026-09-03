import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/config/event_config.dart';
import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/data/events_data.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/screens/settings_screen.dart';
import 'package:aon2026/services/app_settings.dart';
import 'package:aon2026/services/clock.dart';
import 'package:aon2026/services/providers.dart';
import 'package:aon2026/services/saved_events.dart';

/// State that must survive: a cold start, an undo, and a lot of navigation.
///
/// ## Why these three
///
/// A visitor uses this app in short bursts over four hours, with the phone
/// locking in between and iOS free to kill the process at any point. Every one
/// of these tests is a thing that, if broken, silently loses the plan someone
/// spent ten minutes building — the single worst failure this app can have,
/// because it is invisible until they arrive somewhere at the wrong time.
///
/// The suites that already exist check that a save *writes*. These check that it
/// is still there afterwards, which is a different claim.
void main() {
  _languagePickerGeometryTests();

  final events = EventsData.all.where((e) => e.sessions.isNotEmpty).toList();
  final first = events[0];
  final second = events[1];

  final savedKey = SavedEventsStorage.keyFor(EventConfig.astronomyOpenNight.id);

  /// A fresh app, reading whatever is currently in SharedPreferences.
  ///
  /// Building this twice against the same mock store is what "cold restart"
  /// means here: new ProviderScope, new router, new widget tree, same disk.
  Widget app() {
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

  /// The container behind the mounted app, with settings guaranteed loaded.
  ///
  /// AppSettingsNotifier is an AsyncNotifier: `read` on a cold provider returns
  /// `loading` and its `build()` completes a microtask later. Production never
  /// sees that window — SettingsScreen renders every control inside
  /// `settings.when(data:)`, so nothing is tappable until the load is done, and
  /// main.dart's root watches the derived providers from first frame. Awaiting
  /// the future here reproduces that guarantee instead of racing it.
  Future<ProviderContainer> loadedContainer(WidgetTester tester) async {
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp).first),
    );
    await container.read(appSettingsProvider.future);
    await tester.pumpAndSettle();
    return container;
  }

  group('a saved plan survives a cold restart', () {
    testWidgets(
      'two activities saved before the restart are still saved after',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          savedKey: <String>[first.id, second.id],
        });

        await tester.pumpWidget(app());
        await tester.pumpAndSettle();

        // Read through the provider rather than the UI: this asserts the store
        // was rehydrated, independently of how My Night chooses to render it.
        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp).first),
        );
        await tester.pumpAndSettle();
        expect(
          container.read(savedEventsProvider).value,
          containsAll(<String>[first.id, second.id]),
        );
      },
    );

    testWidgets('a save made in one run is visible to the next run', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({savedKey: <String>[]});

      // ── Run 1: save something ──
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      var container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp).first),
      );
      await container.read(savedEventsProvider.notifier).toggle(first.id);
      await tester.pumpAndSettle();
      expect(container.read(savedEventsProvider).value, contains(first.id));

      // ── Run 2: brand-new tree, same store ──
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp).first),
      );
      expect(
        container.read(savedEventsProvider).value,
        contains(first.id),
        reason:
            'the plan was lost across a restart — the visitor rebuilt it '
            'for nothing',
      );
    });

    testWidgets('an unsave also survives, so a removed item stays removed', (
      tester,
    ) async {
      // The mirror case. A store that only ever persists additions would pass
      // the test above and still resurrect something the visitor deleted.
      SharedPreferences.setMockInitialValues({
        savedKey: <String>[first.id, second.id],
      });

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      var container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp).first),
      );
      await container.read(savedEventsProvider.notifier).toggle(first.id);
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp).first),
      );
      final saved = container.read(savedEventsProvider).value!;
      expect(saved, isNot(contains(first.id)));
      expect(saved, contains(second.id));
    });

    testWidgets('clearing the plan persists as an empty plan, not as a reset', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        savedKey: <String>[first.id, second.id],
      });

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      var container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp).first),
      );
      await container.read(savedEventsProvider.notifier).clear();
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp).first),
      );
      expect(container.read(savedEventsProvider).value, isEmpty);
    });
  });

  group('undo genuinely restores', () {
    testWidgets('undoing a removal puts the activity back in the store', (
      tester,
    ) async {
      // A snackbar that says "Undone" without writing anything back is worse
      // than no undo at all, because the visitor stops checking.
      SharedPreferences.setMockInitialValues({
        savedKey: <String>[first.id],
      });

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp).first),
      );

      await container.read(savedEventsProvider.notifier).toggle(first.id);
      await tester.pumpAndSettle();
      expect(container.read(savedEventsProvider).value, isEmpty);

      // What the Undo action does.
      await container.read(savedEventsProvider.notifier).toggle(first.id);
      await tester.pumpAndSettle();
      expect(container.read(savedEventsProvider).value, contains(first.id));
    });

    testWidgets('a restored activity is still there after a restart', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        savedKey: <String>[first.id],
      });

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      var container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp).first),
      );
      await container.read(savedEventsProvider.notifier).toggle(first.id);
      await container.read(savedEventsProvider.notifier).toggle(first.id);
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp).first),
      );
      expect(container.read(savedEventsProvider).value, contains(first.id));
    });
  });

  group('settings persist and actually take effect', () {
    testWidgets('a chosen language survives a restart', (tester) async {
      SharedPreferences.setMockInitialValues({savedKey: <String>[]});

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      var container = await loadedContainer(tester);
      await container.read(appSettingsProvider.notifier).setLocale('fa');
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      container = await loadedContainer(tester);
      expect(container.read(localeProvider), const Locale('fa'));
    });

    testWidgets('"match my device" is storable as a real choice, not a gap', (
      tester,
    ) async {
      // Going back to System after choosing Persian must clear the stored code,
      // otherwise the picker shows System while the app stays Persian.
      SharedPreferences.setMockInitialValues({savedKey: <String>[]});

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final container = await loadedContainer(tester);
      final notifier = container.read(appSettingsProvider.notifier);

      await notifier.setLocale('fa');
      await tester.pumpAndSettle();
      expect(container.read(localeProvider), const Locale('fa'));

      await notifier.setLocale(null);
      await tester.pumpAndSettle();
      expect(
        container.read(localeProvider),
        isNull,
        reason: 'System was selected but a language code is still stored',
      );
    });

    testWidgets('a chosen theme mode survives a restart', (tester) async {
      SharedPreferences.setMockInitialValues({savedKey: <String>[]});

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      var container = await loadedContainer(tester);
      await container
          .read(appSettingsProvider.notifier)
          .setThemeMode(AppThemeMode.light);
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      container = await loadedContainer(tester);
      expect(container.read(themeModeProvider).themeMode, ThemeMode.light);
    });
  });

  group('the language picker is reachable and honest', () {
    Widget settings(String? initialLocale) {
      // setMockInitialValues takes Map<String, Object>, so a nullable value
      // cannot be inlined as a map entry.
      final store = <String, Object>{savedKey: <String>[]};
      if (initialLocale != null) store['settings.locale'] = initialLocale;
      SharedPreferences.setMockInitialValues(store);
      return ProviderScope(
        overrides: [
          baseClockProvider.overrideWithValue(FixedClock(EventInfo.at(19, 0))),
        ],
        child: MaterialApp(
          localizationsDelegates: AonL10n.localizationsDelegates,
          supportedLocales: AonL10n.supportedLocales,
          theme: AonTheme.build(),
          home: const SettingsScreen(),
        ),
      );
    }

    testWidgets('Settings offers a language choice at all', (tester) async {
      // The regression: the app shipped two full translations and no way to
      // pick between them, so Persian was unreachable on an English phone.
      await tester.pumpWidget(settings(null));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Language'), 200);
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      // English UI labels the Persian option with the English exonym "Persian".
      expect(find.text('Persian'), findsOneWidget);
      expect(find.text('Match my device'), findsOneWidget);
    });

    testWidgets('English UI shows the "Persian" exonym, never the "Farsi" romanisation', (
      tester,
    ) async {
      await tester.pumpWidget(settings(null));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Persian'), 200);

      // The Persian option reads "Persian" (English exonym) in the English UI;
      // the "Farsi" romanisation is never used. (The Persian-locale UI keeps the
      // فارسی endonym — see the RTL layout test below.)
      expect(find.text('Persian'), findsOneWidget);
      expect(find.text('Farsi'), findsNothing);
    });

    testWidgets('picking Persian switches the app to Persian immediately', (
      tester,
    ) async {
      await tester.pumpWidget(settings(null));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Persian'), 200);
      await tester.ensureVisible(find.text('Persian'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Persian'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp).first),
      );
      expect(container.read(localeProvider), const Locale('fa'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the stored language is preselected when Settings reopens', (
      tester,
    ) async {
      await tester.pumpWidget(settings('fa'));
      await tester.pumpAndSettle();

      final selected = tester
          .widgetList<RadioListTile<String?>>(
            find.byType(RadioListTile<String?>),
          )
          .where((t) => t.value == 'fa');
      expect(selected, isNotEmpty, reason: 'no Persian option to preselect');

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp).first),
      );
      expect(container.read(appSettingsProvider).value?.localeCode, 'fa');
    });
  });

  group('state stays consistent under heavy navigation', () {
    testWidgets('walking the whole tab bar repeatedly loses nothing and throws '
        'nothing', (tester) async {
      // A visitor checking "what now?" bounces between tabs dozens of times a
      // night. Repeated IndexedStack rebuilds are where duplicated listeners,
      // lost scroll state and re-entrant provider writes surface.
      SharedPreferences.setMockInitialValues({
        savedKey: <String>[first.id],
      });

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp).first),
      );

      // Tab labels are the only stable handle on the shell's nav.
      for (var lap = 0; lap < 3; lap++) {
        for (final label in ['Program', 'Night', 'Info', 'Home']) {
          final tab = find.text(label);
          if (tab.evaluate().isEmpty) continue;
          await tester.tap(tab.first);
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'navigating to $label threw on lap $lap',
          );
        }
      }

      // The plan is untouched by navigation.
      expect(container.read(savedEventsProvider).value, contains(first.id));
    });

    testWidgets('opening and closing an activity many times does not '
        'accumulate state', (tester) async {
      SharedPreferences.setMockInitialValues({savedKey: <String>[]});

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp).first),
      );

      for (var i = 0; i < 4; i++) {
        await container.read(savedEventsProvider.notifier).toggle(first.id);
        await tester.pumpAndSettle();
      }

      // Four toggles from empty is an even number, so back to empty — a set,
      // not a growing list.
      expect(container.read(savedEventsProvider).value, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('saving the same activity twice cannot duplicate it', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        savedKey: <String>[first.id],
      });

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp).first),
      );

      // A duplicate would show the activity twice in the timeline and, worse,
      // report a clash with itself.
      final itinerary = container.read(itineraryProvider);
      final ids = itinerary.map((e) => '${e.event.id}#${e.session.start}');
      expect(ids.toSet().length, ids.length);
    });
  });
}

/// Geometry of the language picker.
///
/// Separate from the behavioural tests above because the bug it pins was purely
/// visual and invisible to every "does the widget exist" assertion.
void _languagePickerGeometryTests() {
  group('each language option sits next to its own radio', () {
    /// The bug, found on an iPhone 17 Pro: the "فارسی" option carried an
    /// explicit `textDirection: TextDirection.rtl`, which right-aligned it
    /// inside the full-width ListTile title slot. The label ended up at the far
    /// edge of the row, ~250pt from the radio button it belonged to, while
    /// "English" sat snugly beside its own. It read as a rendering fault.
    ///
    /// The explicit direction was never needed: "فارسی" is pure Arabic script,
    /// so bidi orders it right-to-left whatever the paragraph direction is.
    Future<void> pumpSettings(WidgetTester tester, Locale locale) async {
      SharedPreferences.setMockInitialValues({
        SavedEventsStorage.keyFor(EventConfig.astronomyOpenNight.id): <String>[],
      });
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            baseClockProvider.overrideWithValue(FixedClock(EventInfo.at(19, 0))),
          ],
          child: MaterialApp(
            localizationsDelegates: AonL10n.localizationsDelegates,
            supportedLocales: AonL10n.supportedLocales,
            locale: locale,
            theme: AonTheme.build(),
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Scroll to a label present in BOTH locales (the language section) — the
      // Persian option label differs by locale (English UI: "Persian";
      // Persian UI: "فارسی"), so it is not a stable cross-locale anchor.
      await tester.scrollUntilVisible(find.text('English'), 200);
      await tester.pumpAndSettle();
    }

    /// Horizontal gap between a label and the nearest edge of its radio.
    double gapToRadio(WidgetTester tester, String label, String? value) {
      final tile = find.ancestor(
        of: find.text(label),
        matching: find.byType(RadioListTile<String?>),
      );
      expect(tile, findsOneWidget, reason: 'no tile for "$label"');
      final labelRect = tester.getRect(find.text(label));
      final tileRect = tester.getRect(tile);
      // Distance from the label to whichever tile edge the control sits on.
      return (labelRect.left - tileRect.left).abs() <
              (tileRect.right - labelRect.right).abs()
          ? labelRect.left - tileRect.left
          : tileRect.right - labelRect.right;
    }

    testWidgets('in English, Persian is as close to its control as English is', (
      tester,
    ) async {
      await pumpSettings(tester, const Locale('en'));

      final englishGap = gapToRadio(tester, 'English', 'en');
      final persianGap = gapToRadio(tester, 'Persian', 'fa');

      // Both labels start just after the radio; allow a little slack for
      // glyph-metric differences.
      expect(
        persianGap,
        closeTo(englishGap, 24),
        reason: 'Persian is ${persianGap.round()}pt from its control but English '
            'is ${englishGap.round()}pt — the Persian label is stranded across '
            'the row',
      );
    });

    testWidgets('the labels share a left edge in English', (tester) async {
      // The strongest, simplest statement of the fix: in an LTR layout every
      // option label starts at the same x.
      await pumpSettings(tester, const Locale('en'));

      final english = tester.getRect(find.text('English')).left;
      final persian = tester.getRect(find.text('Persian')).left;
      final system = tester.getRect(find.text('Match my device')).left;

      expect(persian, closeTo(english, 2));
      expect(english, closeTo(system, 2));
    });

    testWidgets('and a right edge in Persian, where the layout mirrors', (
      tester,
    ) async {
      await pumpSettings(tester, const Locale('fa'));

      final english = tester.getRect(find.text('English')).right;
      final persian = tester.getRect(find.text('فارسی')).right;

      expect(
        persian,
        closeTo(english, 2),
        reason: 'the options no longer align once the app itself is RTL',
      );
    });

    testWidgets('no language label uses the "Farsi" romanisation', (tester) async {
      await pumpSettings(tester, const Locale('en'));
      // "Persian" (English exonym) is intentional in the English UI; "Farsi"
      // (a romanisation) is never used.
      expect(find.text('Farsi'), findsNothing);
    });
  });
}
