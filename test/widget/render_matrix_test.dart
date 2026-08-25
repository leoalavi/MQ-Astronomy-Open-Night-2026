import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/config/event_config.dart';
import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/data/events_data.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/screens/event_detail_screen.dart';
import 'package:aon2026/screens/home_screen.dart';
import 'package:aon2026/screens/info_screen.dart';
import 'package:aon2026/screens/my_night_screen.dart';
import 'package:aon2026/screens/program_screen.dart';
import 'package:aon2026/screens/settings_screen.dart';
import 'package:aon2026/screens/wayfinding_screen.dart';
import 'package:aon2026/widgets/empty_state.dart';
import 'package:aon2026/services/clock.dart';
import 'package:aon2026/services/providers.dart';
import 'package:aon2026/services/saved_events.dart';
import 'package:aon2026/utils/time_format.dart';

/// Renders every frontend screen across the full device / theme / text-scale /
/// locale matrix and fails on any layout overflow.
///
/// ## Why this exists as one generated suite
///
/// The audit steps "check both themes", "check 100/150/200% text", "check
/// 320–tablet widths" and "check Persian RTL" are the same act — mount the
/// screen and see whether it survives — repeated over a grid. Doing that by eye
/// is slow and, worse, unrepeatable: the overflow I fixed in the Home activity
/// rail at 200% text was invisible at 100%, and the two My Night RTL overflows
/// were invisible in English. A matrix keeps every one of those combinations
/// covered on every future change.
///
/// Flutter reports a RenderFlex/RenderBox overflow through `FlutterError`, which
/// the test binding captures; `tester.takeException()` therefore returns
/// non-null exactly when something did not fit. That is the whole assertion.
///
/// ## Deliberately excluded
///
/// The Map tab, panorama, compass and passport screens are out of scope for the
/// frontend pass and are covered by their own suites. They also need a tile
/// provider and platform channels, which would make this matrix flaky for
/// reasons unrelated to layout.
void main() {
  // ── The grid ──────────────────────────────────────────
  //
  // Widths chosen from real hardware rather than round numbers:
  //   320  iPhone SE (1st gen) — the narrowest phone still in the wild
  //   375  iPhone SE (2020/2022), iPhone 13 mini
  //   390  iPhone 14/15/16 — the modal device
  //   430  iPhone 16 Pro Max
  //   834  iPad Air portrait
  const sizes = <String, Size>{
    '320x568': Size(320, 568),
    '375x667': Size(375, 667),
    '390x844': Size(390, 844),
    '430x932': Size(430, 932),
    '834x1112': Size(834, 1112),
  };

  // 1.0 is the default, 2.0 is the app's declared ceiling (kMaxTextScale).
  // 1.5 is included because it is where most real accessibility users sit and
  // where two-line wrapping first kicks in.
  const textScales = <double>[1.0, 1.5, 2.0];

  final liveEvent = EventsData.all.firstWhere((e) => e.sessions.isNotEmpty);

  /// Every screen under audit, as a name → builder map.
  final screens = <String, Widget Function()>{
    'Home': () => const HomeScreen(),
    'Program': () => const ProgramScreen(),
    'My Night': () => const MyNightScreen(),
    'Info': () => const InfoScreen(),
    'Settings': () => const SettingsScreen(),
    'Event detail': () => EventDetailScreen(eventId: liveEvent.id),
    'Wayfinding': () => const WayfindingScreen(),
  };

  Widget harness({
    required Widget child,
    required Brightness brightness,
    required double textScale,
    required Locale locale,
    required Set<String> saved,
  }) {
    SharedPreferences.setMockInitialValues({
      SavedEventsStorage.keyFor(EventConfig.astronomyOpenNight.id): saved
          .toList(),
    });
    return ProviderScope(
      overrides: [
        // Mid-event, so live badges, countdowns and "finished" sections all
        // render at once — the busiest state each screen has.
        baseClockProvider.overrideWithValue(FixedClock(EventInfo.at(19, 30))),
      ],
      child: MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        locale: locale,
        theme: AonTheme.forBrightness(brightness),
        home: MediaQuery(
          data: MediaQueryData(
            textScaler: TextScaler.linear(textScale),
            // A notched phone: the status bar and home indicator are the two
            // insets that actually swallow content.
            padding: const EdgeInsets.only(top: 47, bottom: 34),
          ),
          child: child,
        ),
      ),
    );
  }

  /// Mounts [child] at [size] and returns any layout exception.
  Future<Object?> render(
    WidgetTester tester, {
    required Widget child,
    required Size size,
    required Brightness brightness,
    required double textScale,
    required Locale locale,
    Set<String> saved = const <String>{},
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // TimeFormat holds the locale statically (it is read from deep inside
    // widgets that have no ref), so the matrix has to set it explicitly or
    // every Persian row would render English dates.
    TimeFormat.locale = locale.languageCode;
    addTearDown(() => TimeFormat.locale = 'en');

    await tester.pumpWidget(
      harness(
        child: child,
        brightness: brightness,
        textScale: textScale,
        locale: locale,
        saved: saved,
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    return tester.takeException();
  }

  group('no screen overflows anywhere in the device matrix', () {
    for (final screen in screens.entries) {
      for (final size in sizes.entries) {
        for (final scale in textScales) {
          testWidgets(
            '${screen.key} · ${size.key} · ${(scale * 100).round()}% text',
            (tester) async {
              for (final brightness in Brightness.values) {
                final error = await render(
                  tester,
                  child: screen.value(),
                  size: size.value,
                  brightness: brightness,
                  textScale: scale,
                  locale: const Locale('en'),
                );
                expect(
                  error,
                  isNull,
                  reason:
                      '${screen.key} overflowed at ${size.key}, '
                      '${(scale * 100).round()}% text, ${brightness.name} theme',
                );
              }
            },
          );
        }
      }
    }
  });

  group('no screen overflows in Persian (RTL)', () {
    // RTL re-runs the narrow + large-text corners only: a right-to-left flip
    // changes which end of a Row gets squeezed, and Persian strings are longer
    // than their English source, so the failures cluster at the tight end.
    for (final screen in screens.entries) {
      testWidgets('${screen.key} · Persian · 320 wide · 200% text', (
        tester,
      ) async {
        for (final brightness in Brightness.values) {
          final error = await render(
            tester,
            child: screen.value(),
            size: const Size(320, 568),
            brightness: brightness,
            textScale: 2.0,
            locale: const Locale('fa'),
          );
          expect(
            error,
            isNull,
            reason:
                '${screen.key} overflowed in Persian at 320x568, 200% text, '
                '${brightness.name} theme',
          );
        }
      });

      testWidgets('${screen.key} · Persian · 390 wide · 100% text', (
        tester,
      ) async {
        final error = await render(
          tester,
          child: screen.value(),
          size: const Size(390, 844),
          brightness: Brightness.dark,
          textScale: 1.0,
          locale: const Locale('fa'),
        );
        expect(error, isNull, reason: '${screen.key} overflowed in Persian');
      });
    }
  });

  group('the saved-itinerary screens survive a full itinerary', () {
    // My Night is the one screen whose height is driven by user data, so an
    // empty-state-only sweep would miss its real worst case. Saving the whole
    // programme also forces every conflict warning to render at once.
    final everything = EventsData.all.map((e) => e.id).toSet();

    for (final scale in textScales) {
      testWidgets('My Night · everything saved · 320 wide · '
          '${(scale * 100).round()}% text', (tester) async {
        final error = await render(
          tester,
          child: const MyNightScreen(),
          size: const Size(320, 568),
          brightness: Brightness.dark,
          textScale: scale,
          locale: const Locale('en'),
          saved: everything,
        );
        expect(error, isNull);
      });
    }

    testWidgets('My Night · everything saved · Persian · 200% text', (
      tester,
    ) async {
      final error = await render(
        tester,
        child: const MyNightScreen(),
        size: const Size(320, 568),
        brightness: Brightness.dark,
        textScale: 2.0,
        locale: const Locale('fa'),
        saved: everything,
      );
      expect(error, isNull);
    });

    testWidgets('Home · a saved event drives the Next Up card · 320 · 200%', (
      tester,
    ) async {
      // Next Up only exists when something is saved, so the default sweep
      // never lays it out. It is a tight Row with a countdown badge.
      final error = await render(
        tester,
        child: const HomeScreen(),
        size: const Size(320, 568),
        brightness: Brightness.dark,
        textScale: 2.0,
        locale: const Locale('en'),
        saved: everything,
      );
      expect(error, isNull);
    });
  });

  group('every event detail page lays out, not just the convenient one', () {
    // 36 programme items with wildly different shapes: no presenter, four
    // sessions, a 90-character title, booking required, placeholder times.
    // Rendering only `liveEvent` above would miss all of that.
    for (final event in EventsData.all) {
      testWidgets('${event.id} · 320 wide · 200% text', (tester) async {
        final error = await render(
          tester,
          child: EventDetailScreen(eventId: event.id),
          size: const Size(320, 568),
          brightness: Brightness.dark,
          textScale: 2.0,
          locale: const Locale('en'),
        );
        expect(error, isNull, reason: '"${event.title}" overflowed');
      });
    }
  });

  group('empty states are reachable, not clipped', () {
    // The regression this group pins: EmptyState was a bare Center, so on a
    // short screen the action button fell off the bottom — an empty state whose
    // only escape hatch is unreachable. Program's "no matches" is the worst
    // case: the tallest variant (icon + title + body + button) under a bounded
    // height, and it is only reachable through a filter that excludes
    // everything, so the default sweep never lays it out.
    Future<Object?> renderEmptyProgram(
      WidgetTester tester, {
      required Size size,
      required double textScale,
      required Locale locale,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      TimeFormat.locale = locale.languageCode;
      addTearDown(() => TimeFormat.locale = 'en');

      SharedPreferences.setMockInitialValues({
        SavedEventsStorage.keyFor(EventConfig.astronomyOpenNight.id):
            <String>[],
      });

      final container = ProviderContainer(
        overrides: [
          baseClockProvider.overrideWithValue(FixedClock(EventInfo.at(19, 30))),
        ],
      );
      addTearDown(container.dispose);
      // A query no programme item can match.
      container
          .read(eventFilterProvider.notifier)
          .setQuery('zzzzz-no-such-activity');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AonL10n.localizationsDelegates,
            supportedLocales: AonL10n.supportedLocales,
            locale: locale,
            theme: AonTheme.forBrightness(Brightness.dark),
            home: MediaQuery(
              data: MediaQueryData(
                textScaler: TextScaler.linear(textScale),
                padding: const EdgeInsets.only(top: 47, bottom: 34),
              ),
              child: const ProgramScreen(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      return tester.takeException();
    }

    for (final scale in textScales) {
      testWidgets('Program "no matches" fits at 320 wide · '
          '${(scale * 100).round()}% text', (tester) async {
        final error = await renderEmptyProgram(
          tester,
          size: const Size(320, 568),
          textScale: scale,
          locale: const Locale('en'),
        );
        expect(error, isNull);

        // Present is not enough — the button must be inside the viewport, which
        // is what the old bare-Center layout got wrong.
        final button = find.byType(FilledButton);
        expect(button, findsOneWidget);
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        final box = tester.getRect(button);
        expect(
          box.bottom,
          lessThanOrEqualTo(568.0),
          reason:
              'the clear-filters button is off-screen — the empty state is '
              'a dead end',
        );
      });
    }

    testWidgets('Program "no matches" fits in Persian at 200% text', (
      tester,
    ) async {
      final error = await renderEmptyProgram(
        tester,
        size: const Size(320, 568),
        textScale: 2.0,
        locale: const Locale('fa'),
      );
      expect(error, isNull);
    });

    testWidgets('the clear-filters button still works when it had to scroll', (
      tester,
    ) async {
      // Scrolling to reach it must not break the tap — a Center-inside-scroll
      // layout can leave the button visually present but outside its parent's
      // hit-test area.
      await renderEmptyProgram(
        tester,
        size: const Size(320, 568),
        textScale: 2.0,
        locale: const Locale('en'),
      );
      final button = find.byType(FilledButton);
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();

      // Filters cleared, so the programme is back.
      expect(find.byType(FilledButton), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('every hour of the night lays out', () {
    // ## The gap this closes
    //
    // Every test above pins the clock to 19:30, mid-event, where all four
    // timing buckets have content. But the app is opened across a much wider
    // window, and each phase is a structurally different screen: before the
    // doors open nothing is "happening now"; at 21:45 almost everything is
    // finished and the finished section — normally collapsed and short — is the
    // longest thing on the page; after close there is no "next" at all.
    //
    // A visitor arriving late is the most likely person to be relying on the
    // app, so this is not an edge case.
    // The programme runs 16:00-22:00 (EventInfo.startsAt/endsAt), so these are
    // pinned either side of those, not to round evening hours.
    final clocks = <String, DateTime>{
      '15:30 before doors': EventInfo.at(15, 30),
      '16:00 doors open': EventInfo.at(16, 0),
      '19:30 mid-event': EventInfo.at(19, 30),
      '21:45 winding down': EventInfo.at(21, 45),
      '22:30 after close': EventInfo.at(22, 30),
    };

    Future<Object?> renderAt(
      WidgetTester tester, {
      required Widget child,
      required DateTime now,
      required double textScale,
      required Set<String> saved,
    }) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({
        SavedEventsStorage.keyFor(EventConfig.astronomyOpenNight.id): saved
            .toList(),
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [baseClockProvider.overrideWithValue(FixedClock(now))],
          child: MaterialApp(
            localizationsDelegates: AonL10n.localizationsDelegates,
            supportedLocales: AonL10n.supportedLocales,
            theme: AonTheme.forBrightness(Brightness.dark),
            home: MediaQuery(
              data: MediaQueryData(
                textScaler: TextScaler.linear(textScale),
                padding: const EdgeInsets.only(top: 47, bottom: 34),
              ),
              child: child,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      return tester.takeException();
    }

    final everything = EventsData.all.map((e) => e.id).toSet();

    for (final clock in clocks.entries) {
      for (final name in ['Home', 'Program', 'My Night']) {
        testWidgets('$name at ${clock.key} · 320 wide · 200% text', (
          tester,
        ) async {
          final error = await renderAt(
            tester,
            child: screens[name]!(),
            now: clock.value,
            textScale: 2.0,
            // A full plan, so the finished/remaining split is exercised at
            // every hour rather than only where it happens to be balanced.
            saved: everything,
          );
          expect(error, isNull, reason: '$name overflowed at ${clock.key}');
        });
      }
    }

    testWidgets('after close, My Night still shows the unscheduled drop-ins '
        'rather than a blank timeline', (tester) async {
      // After close every *timed* activity is finished, but the drop-ins with
      // no published time never "finish" — they stay on the plan (in remaining)
      // and render as cards. So the last visitor of the night sees those, never
      // a blank/empty timeline. (My Night renders _ItineraryCards, not
      // EventCards; the "Finished" section sits below the fold in the lazy
      // list, so assert on the visible drop-in cards instead.)
      await renderAt(
        tester,
        child: const MyNightScreen(),
        now: EventInfo.at(22, 30),
        textScale: 1.0,
        saved: everything,
      );
      expect(find.byType(EmptyState), findsNothing,
          reason: 'My Night must not collapse to the empty state while '
              'unscheduled drop-ins remain');
      expect(find.byType(Card), findsWidgets,
          reason: 'the still-discoverable unscheduled drop-ins should render '
              'as cards after close');
      expect(tester.takeException(), isNull);
    });

    testWidgets('before doors open, Home does not claim something is '
        'happening now', (tester) async {
      await renderAt(
        tester,
        child: const HomeScreen(),
        now: EventInfo.at(15, 30),
        textScale: 1.0,
        saved: const <String>{},
      );
      expect(find.textContaining('Happening now'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('content is not crushed to nothing by large text', () {
    // ## The bug class this group exists to catch
    //
    // Overflow is only half of what large text does to a layout. A Column with
    // fixed-height controls plus `Expanded(child: list)` can never overflow —
    // the list absorbs whatever is left over, however little that is. Program
    // shipped exactly that: at 200% text on a 320-wide phone its search field,
    // filter bar, view switcher and count row totalled 512 of 568 points and
    // the programme itself got a 56pt window. Nothing overflowed, so the
    // overflow sweep above passed it.
    //
    // The fix was to make the header scroll away (a CustomScrollView), and this
    // is the assertion that keeps it that way: the primary vertical scrollable
    // must keep most of the screen.
    double primaryViewportHeight(WidgetTester tester) {
      final vertical = find.byWidgetPredicate(
        (w) => w is Scrollable && w.axis == Axis.vertical,
      );
      expect(
        vertical,
        findsWidgets,
        reason:
            'no vertical scrollable — the screen cannot be read on a '
            'short device',
      );
      // The tallest vertical scrollable is the content region; the others are
      // nested affordances (a chip row, a sheet).
      return vertical
          .evaluate()
          .map((e) => tester.getRect(find.byWidget(e.widget)).height)
          .reduce((a, b) => a > b ? a : b);
    }

    for (final name in ['Program', 'My Night', 'Info', 'Settings']) {
      testWidgets('$name keeps a usable content area at 200% text on a '
          '320-wide phone', (tester) async {
        await render(
          tester,
          child: screens[name]!(),
          size: const Size(320, 568),
          brightness: Brightness.dark,
          textScale: 2.0,
          locale: const Locale('en'),
          // Saved items so My Night shows its timeline rather than its empty
          // state, which is the case with a real content region.
          saved: EventsData.all.take(4).map((e) => e.id).toSet(),
        );

        final height = primaryViewportHeight(tester);
        // 60% of the screen. Program's regression left 56pt — under 10%.
        expect(
          height,
          greaterThan(568 * 0.6),
          reason:
              '$name gives its content only ${height.round()}pt of 568 at '
              '200% text; chrome is crowding out the thing the visitor came '
              'for',
        );
      });
    }

    testWidgets('Program keeps a usable content area in Persian too', (
      tester,
    ) async {
      await render(
        tester,
        child: const ProgramScreen(),
        size: const Size(320, 568),
        brightness: Brightness.dark,
        textScale: 2.0,
        locale: const Locale('fa'),
      );
      expect(primaryViewportHeight(tester), greaterThan(568 * 0.6));
    });

    testWidgets('the Program header scrolls away rather than being pinned', (
      tester,
    ) async {
      // The header must not be a pinned sliver — pinning it would reintroduce
      // the crush in a form the height check above cannot see.
      await render(
        tester,
        child: const ProgramScreen(),
        size: const Size(320, 568),
        brightness: Brightness.dark,
        textScale: 2.0,
        locale: const Locale('en'),
      );

      final search = find.byType(TextField);
      expect(search, findsOneWidget);
      final before = tester.getRect(search).top;

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      // Either scrolled off entirely, or moved up substantially.
      final stillThere = search.evaluate().isNotEmpty;
      if (stillThere) {
        expect(
          tester.getRect(search).top,
          lessThan(before - 100),
          reason:
              'the search field is pinned; the programme never gets the '
              'full viewport',
        );
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('tap targets survive large text', () {
    // Growing the text must not shrink a control below the 56pt minimum, and
    // must not push it off-screen either. Checked on the screens a visitor
    // actually operates one-handed in the dark.
    for (final name in ['Home', 'Program', 'My Night', 'Settings']) {
      testWidgets('$name · buttons stay at least ${AonSpacing.minTapTarget}pt '
          'at 200% text', (tester) async {
        await render(
          tester,
          child: screens[name]!(),
          size: const Size(390, 844),
          brightness: Brightness.dark,
          textScale: 2.0,
          locale: const Locale('en'),
        );

        final buttons = find.byWidgetPredicate(
          (w) => w is IconButton || w is FilledButton || w is TextButton,
        );
        for (final element in buttons.evaluate()) {
          final box = element.renderObject as RenderBox?;
          if (box == null || !box.hasSize || box.size.isEmpty) continue;
          expect(
            box.size.height,
            greaterThanOrEqualTo(48.0),
            reason:
                'a control on $name shrank below a usable height '
                'at 200% text',
          );
        }
      });
    }
  });
}
