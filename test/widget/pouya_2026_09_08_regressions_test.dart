import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/screens/program_screen.dart';
import 'package:aon2026/services/clock.dart';
import 'package:aon2026/services/event_phase.dart';
import 'package:aon2026/utils/timing_labels.dart';
import 'package:aon2026/widgets/sheet_drag_handle.dart';
import 'package:aon2026/widgets/venue_info_sheet.dart';
import 'package:aon2026/config/qa_mode.dart';
import 'package:aon2026/screens/event_detail_screen.dart';

/// Regressions from Pouya's device pass on 2026-09-08.
///
/// Each group states the reported symptom in his words, then pins the behaviour
/// that answers it. See docs/reviews/2026-09-08-pouya-bug-batch.md for the full
/// triage, including the two items that turned out NOT to be defects.
void main() {
  Widget host(Widget child, {Locale? locale}) {
    SharedPreferences.setMockInitialValues({});
    return ProviderScope(
      overrides: [
        baseClockProvider.overrideWithValue(FixedClock(EventInfo.at(19, 0))),
      ],
      child: MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        locale: locale,
        theme: AonTheme.build(),
        home: child,
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  group('the Program search keyboard can be dismissed', () {
    // "وقتی که تو پروگرام سرچ می‌کنی، کیبورد میاد بالا، هرچی رو صفحه می‌زنی
    //  کیبورد نمیره" — the keyboard came up and nothing put it away.
    //
    // Flutter's default tap-outside action deliberately does NOT unfocus for
    // *touch* pointers on iOS and Android (EditableTextTapOutsideAction in
    // editable_text.dart), so on a phone the keyboard covered the results
    // permanently. The field has to opt in; these assert that it did.

    testWidgets('tapping outside the field releases focus', (tester) async {
      await tester.pumpWidget(host(const ProgramScreen()));
      await tester.pumpAndSettle();

      final field = find.byType(TextField);
      await tester.tap(field);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field).focusNode?.hasFocus ??
            FocusScope.of(tester.element(field)).hasFocus,
        isTrue,
        reason: 'precondition: the field takes focus when tapped',
      );

      // Tap the screen title — anywhere that is not the field.
      await tester.tapAt(const Offset(20, 40));
      await tester.pumpAndSettle();

      final focus = FocusScope.of(tester.element(find.byType(ProgramScreen)));
      expect(focus.hasFocus, isFalse,
          reason: 'the keyboard stays over the programme with nothing to '
              'dismiss it but the system back gesture');
    });

    testWidgets('the field declares an onTapOutside handler', (tester) async {
      // The behavioural test above passes trivially in a test host that never
      // shows a real keyboard, so pin the wiring itself too.
      await tester.pumpWidget(host(const ProgramScreen()));
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(find.byType(TextField)).onTapOutside,
          isNotNull);
    });

    testWidgets('scrolling the programme dismisses the keyboard too',
        (tester) async {
      await tester.pumpWidget(host(const ProgramScreen()));
      await tester.pumpAndSettle();

      final view = tester.widget<CustomScrollView>(
        find.byType(CustomScrollView).first,
      );
      expect(view.keyboardDismissBehavior,
          ScrollViewKeyboardDismissBehavior.onDrag);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  group('"Happening now" is said once, not twice', () {
    // "دوبار Happening Now تکرار شده، اولی اون بالایه اضافه هست".
    //
    // `phaseHappeningNow` and `timingHappeningNow` were the same words, and the
    // hero pill sat directly above the rail that used the other one — with the
    // same badge again on each card inside it.

    testWidgets('the running phase contributes no hero pill', (tester) async {
      await tester.pumpWidget(host(const SizedBox.shrink()));
      final l = AonL10n.of(tester.element(find.byType(SizedBox)));

      expect(EventPhase.running.labelOf(l), isNull,
          reason: 'the hero pill repeats the section header beneath it');
    });

    testWidgets('every other phase still speaks — this is not a mute switch',
        (tester) async {
      await tester.pumpWidget(host(const SizedBox.shrink()));
      final l = AonL10n.of(tester.element(find.byType(SizedBox)));

      // These each say something the "Happening now" rail cannot.
      expect(EventPhase.startingSoon.labelOf(l), isNotNull);
      expect(EventPhase.endingSoon.labelOf(l), isNotNull);
      expect(EventPhase.ended.labelOf(l), isNotNull);
      expect(EventPhase.today.labelOf(l), isNotNull);
      // `future` was always null: "the event is in 3 weeks" on every launch.
      expect(EventPhase.future.labelOf(l), isNull);
    });

    test('no phase label duplicates a timing label', () {
      // The structural version of the same claim: if someone reintroduces a
      // hero phase string that reads identically to a section header, this
      // fails before it reaches a screenshot.
      final arb = File('lib/l10n/app_en.arb').readAsStringSync();
      expect(arb.contains('"phaseHappeningNow"'), isFalse,
          reason: 'a phase label identical to timingHappeningNow is back');
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  group('a sheet covers the tab bar instead of hiding behind it', () {
    // "روی منو قرار می‌گیره... از UI ایراد داره" — the island was drawn over
    // the sheet's Directions button.
    //
    // The layering, not the padding, was the bug: the sheet was pushed on the
    // BRANCH navigator, inside the shell's Scaffold, so the floating island
    // painted over it AND stayed hit-testable through the modal barrier. On
    // the 6.9" simulator a tap aimed at "Show on map" switched tabs. Fixed by
    // opening these sheets on the root navigator, matching the choosers that
    // already did. The file-level guard lives in bottom_nav_clearance_test.

    testWidgets('the shell\'s bottom bar cannot be tapped through the sheet',
        (tester) async {
      // A miniature of the real shell: a Scaffold with `extendBody: true`, a
      // bottom bar, and a NESTED navigator for the branch — the arrangement
      // StatefulShellRoute produces. Opening the sheet from the nested
      // navigator is what used to leave the bar on top.
      var tabTapped = false;
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(ProviderScope(
        overrides: [
          baseClockProvider.overrideWithValue(FixedClock(EventInfo.at(19, 0))),
        ],
        child: MaterialApp(
          localizationsDelegates: AonL10n.localizationsDelegates,
          supportedLocales: AonL10n.supportedLocales,
          theme: AonTheme.build(),
          home: Scaffold(
            extendBody: true,
            body: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (branchContext) => Center(
                  child: ElevatedButton(
                    onPressed: () =>
                        VenueInfoSheet.show(branchContext, 'central-courtyard'),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
            bottomNavigationBar: SizedBox(
              height: 66,
              child: ElevatedButton(
                onPressed: () => tabTapped = true,
                child: const Text('TAB'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(SheetDragHandle), findsOneWidget,
          reason: 'precondition: the sheet is open');

      // Aim squarely at the tab bar. With the sheet on the root navigator its
      // barrier covers the bar, so this lands on the barrier (which dismisses
      // the sheet) and never reaches the tab.
      await tester.tap(find.text('TAB'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(
        tabTapped,
        isFalse,
        reason: 'the floating tab bar is still live through the modal barrier '
            '— on device a tap aimed at "Show on map" switched tabs instead',
      );
    });
  });

  group('a sheet can be dragged by its handle', () {
    // "باید این سفیده رو بکشی بالا اون بیاد بالا... این اتفاق نمی‌افته، باید
    //  داخل رو بکشی بالا" — dragging the white grab handle did nothing; only
    //  dragging the sheet's contents resized it.
    //
    // Cause: a DraggableScrollableSheet nested inside showModalBottomSheet.
    // Material's handle belongs to the OUTER modal (it drives dismissal); the
    // inner sheet's extent is driven only by its own scrollable. The handle has
    // to live inside that scrollable — see SheetDragHandle.

    test('the nested sheets turn off Material\'s handle and supply their own',
        () {
      // Every file that builds a DraggableScrollableSheet must also opt out of
      // the theme's `showDragHandle` and render a SheetDragHandle instead.
      const nested = [
        'lib/widgets/venue_info_sheet.dart',
        'lib/screens/map_screen.dart',
      ];
      for (final path in nested) {
        final src = File(path).readAsStringSync();
        expect(src.contains('DraggableScrollableSheet'), isTrue,
            reason: '$path no longer nests a sheet — update this list');
        expect(src.contains('showDragHandle: false'), isTrue,
            reason: "$path keeps Material's handle, which cannot resize the "
                'inner sheet');
        expect(src.contains('SheetDragHandle'), isTrue,
            reason: '$path has no handle the visitor can actually drag');
      }
    });

    testWidgets('the handle is inside the sheet\'s own scroll view',
        (tester) async {
      await tester.pumpWidget(host(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () =>
                    VenueInfoSheet.show(context, 'central-courtyard'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final handle = find.byType(SheetDragHandle);
      expect(handle, findsOneWidget);

      // The load-bearing assertion: the handle is a DESCENDANT of the
      // DraggableScrollableSheet's scroll view, so a drag on it reaches the
      // controller that owns the sheet's extent. A handle supplied by the
      // modal would sit outside this subtree.
      expect(
        find.descendant(
          of: find.byType(DraggableScrollableSheet),
          matching: handle,
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(Scrollable), matching: handle),
        findsWidgets,
      );
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  group('internal provenance does not ship to attendees', () {
    // Found on device 2026-09-08 while re-checking Pouya's Solar system walk
    // report — he had not named this one, and the first pass missed it.
    //
    // `AonEvent.sourceNote` is a data-integrity artefact: data_integrity_test
    // requires one on EVERY event so each published time traces back to the
    // programme PDF or to Liz's email, and docs/data-sources.md calls it "the
    // provenance link back to the PDF/email". The detail screen's own comment
    // says "for the team rather than attendees" — and then rendered it
    // unconditionally. On Solar system walk a visitor read:
    //
    //   Source: Liz 2026-08-31 — "Will go up on Gymnasium Road a few days
    //   before the event…" … so classified openAllNight (not an exact session).
    //
    // An organiser named, an internal email quoted, an internal enum exposed.

    testWidgets('a release build shows no "Source:" line', (tester) async {
      await tester.pumpWidget(host(
        const EventDetailScreen(eventId: 'solar-system-walk'),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Source:'), findsNothing);
      expect(find.textContaining('openAllNight'), findsNothing,
          reason: 'the internal timing enum reached the public screen');
      expect(find.textContaining('Liz'), findsNothing,
          reason: 'an organiser is named to attendees');
    });

    testWidgets('the QA define brings it back for the team', (tester) async {
      // The provenance still has to be reachable — it is how a data claim gets
      // audited. It just needs the define, like every other QA-only surface.
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(ProviderScope(
        overrides: [
          baseClockProvider.overrideWithValue(FixedClock(EventInfo.at(19, 0))),
          showSourceNotesProvider.overrideWithValue(true),
        ],
        child: MaterialApp(
          localizationsDelegates: AonL10n.localizationsDelegates,
          supportedLocales: AonL10n.supportedLocales,
          theme: AonTheme.build(),
          home: const EventDetailScreen(eventId: 'solar-system-walk'),
        ),
      ));
      await tester.pumpAndSettle();

      // It is the last item on a long screen, so scroll to it rather than
      // asserting on what happens to be built.
      await tester.scrollUntilVisible(
        find.textContaining('Source:'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Source:'), findsWidgets);
    });

    testWidgets('the amber detail-screen confidence notes are hidden',
        (tester) async {
      // Owner decision 2026-09-11 (Pouya): the two amber ConfidenceNote lines on
      // the activity detail screen — "these times are not published…" and "the
      // exact position… is still being confirmed" — are no longer shown to
      // attendees. The screen reads cleaner without them.
      //
      // The DATA-honesty invariant is untouched: timing stays openAllNight, so
      // hasPublishedStart/hasPublishedEnd still refuse to render the 4pm
      // stand-in as a published start (ARCHITECTURE §14 #2/#3, and the
      // unpublished_time / open_all_night_start_time tests). The internal
      // provenance stays hidden too (the "Source:" case above). Only the
      // visitor-facing caveat copy on this screen is suppressed.
      await tester.pumpWidget(host(
        const EventDetailScreen(eventId: 'solar-system-walk'),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('not published'), findsNothing,
          reason: 'the unpublished-time caveat is intentionally removed');
      expect(find.textContaining('still being confirmed'), findsNothing,
          reason: 'the unconfirmed-position caveat is intentionally removed');
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  group('haptics reach ordinary buttons', () {
    // "این هپتیکس باز کار نمی‌کنه... هرچی تست کردم کار نکرد."
    //
    // The plumbing was never broken. Only five widget types called into
    // AonHaptics, so every plain Material button, switch, radio and filter in
    // the app was silent — while Settings promised "a gentle vibration when you
    // tap buttons". This pins the shared surfaces that now feed back.

    test('the shared action and control widgets call AonHaptics', () {
      const surfaces = {
        // Directions / Show on map, embedded across Info and the detail screens.
        'lib/widgets/place_action_buttons.dart': 'AonHaptics',
        // Every settings switch and both radio groups.
        'lib/screens/settings_screen.dart': 'AonHaptics',
        // Map / 360° segmented control and the category chips.
        'lib/widgets/map_mode_toggle.dart': 'AonHaptics',
        'lib/widgets/map_category_filter_bar.dart': 'AonHaptics',
        // Programme view switcher and the filter option sheets.
        'lib/screens/program_screen.dart': 'AonHaptics',
        // The sheets' own Directions / Show on map / 360° buttons.
        'lib/widgets/venue_info_sheet.dart': 'AonHaptics',
        'lib/widgets/building_sheet.dart': 'AonHaptics',
        'lib/screens/map_screen.dart': 'AonHaptics',
        // "Walk there" on an activity.
        'lib/screens/event_detail_screen.dart': 'AonHaptics',
      };
      final silent = <String>[];
      surfaces.forEach((path, token) {
        if (!File(path).readAsStringSync().contains(token)) silent.add(path);
      });
      expect(silent, isEmpty,
          reason: 'these controls give no tactile feedback, while Settings '
              'promises it:\n${silent.join('\n')}');
    });

    test('the haptics setting applies to the master switch immediately', () {
      // Ordering matters: the switch fires its own confirming tick in the same
      // turn it flips the preference. If the static were only mirrored on the
      // next AonApp build, turning haptics ON would be silent and turning them
      // OFF would still buzz — the exact inversion that reads as "broken".
      final src = File('lib/services/app_settings.dart').readAsStringSync();
      expect(src.contains('AonHaptics.globalEnabled = value'), isTrue);
    });
  });
}
