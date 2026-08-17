import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/services/clock.dart';
import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/services/whats_on_service.dart';
import 'package:aon2026/widgets/activity_rail_card.dart';
import 'package:aon2026/widgets/timing_badge.dart';

/// A clipped number must never reach the screen.
///
/// ## The bug this file exists to prevent
///
/// Found on an iPhone 17 Pro at 7pm on event night. The Home rail card is a
/// fixed 268pt with 56pt reserved for the save button, leaving the badge ~196pt
/// — not enough for "Happening now · in 15 min". `TextOverflow.ellipsis`
/// rendered it as "Happening now · in 1…".
///
/// That is qualitatively worse than clipping prose. "in 1…" still parses as a
/// duration, so nothing signals to the reader that anything was lost: someone
/// checking whether they can reach the Observatory sees "in 1" and believes they
/// have one minute rather than fifteen. The badge now measures its text and
/// drops the countdown wholesale when it will not fit, because a missing
/// countdown is recoverable (the card shows the session's time range anyway)
/// and a wrong one is not.
void main() {
  /// Renders a badge inside a hard [width], mirroring the rail card's box.
  Future<void> pumpAt(
    WidgetTester tester, {
    required double width,
    required EventTiming timing,
    String? trailing,
    double textScale = 1.0,
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // The badge reads the event phase to decide whether "not started yet"
          // may say "tonight". Pinned to event night so these width tests do not
          // change meaning depending on the day they are run.
          baseClockProvider.overrideWithValue(FixedClock(EventInfo.at(19, 0))),
        ],
        child: MaterialApp(
          localizationsDelegates: AonL10n.localizationsDelegates,
          supportedLocales: AonL10n.supportedLocales,
          locale: locale,
          theme: AonTheme.build(),
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: width,
                  // Align, exactly as ActivityRailCard does: the badge gets loose
                  // constraints capped at the card's content width.
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TimingBadge(
                      timing: timing,
                      trailingText: trailing,
                      // The caller declares its own box, exactly as
                      // ActivityRailCard does with its contentWidth constant.
                      maxWidth: width,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The single Text inside the badge.
  String renderedLabel(WidgetTester tester) {
    final text = tester.widget<Text>(
      find.descendant(
        of: find.byType(TimingBadge),
        matching: find.byType(Text),
      ),
    );
    return text.data!;
  }

  // ## Why nothing here asserts a pixel width
  //
  // flutter_test substitutes a fixed-width fallback font in which every glyph is
  // the same box, so "Happening now" measures 174pt where SF Pro on device
  // measures ~80pt. Any "does it fit in 155pt?" assertion would therefore be
  // measuring the test harness rather than the app — which is precisely why this
  // bug survived 905 passing tests and only surfaced on a simulator.
  //
  // What these tests pin instead is the font-independent invariant: whatever the
  // metrics, the label is either the complete string or the bare status label,
  // and never a prefix of the countdown. That property is what makes a wrong
  // number impossible, and it holds in any font.

  group('the countdown is dropped, never cut', () {
    testWidgets('at the rail card width the countdown is omitted rather than '
        'truncated', (tester) async {
      // 196pt = 268 (card) - 16 (left pad) - 56 (save button gutter), which is
      // ActivityRailCard.contentWidth.
      await pumpAt(
        tester,
        width: ActivityRailCard.contentWidth,
        timing: EventTiming.happeningNow,
        trailing: 'in 15 min',
      );

      expect(
        renderedLabel(tester),
        'Happening now',
        reason: 'the countdown should be gone entirely, not shortened',
      );
    });

    testWidgets('a wide badge keeps the countdown', (tester) async {
      // The Program list is full-width, where the countdown fits and is useful.
      // Generously wide so the result is the same in any font.
      await pumpAt(
        tester,
        width: 900,
        timing: EventTiming.happeningNow,
        trailing: 'in 15 min',
      );
      expect(renderedLabel(tester), 'Happening now · in 15 min');
    });

    testWidgets('no digit is ever left dangling, at any width', (tester) async {
      // Sweeps the whole plausible range. Either the countdown is fully present
      // or fully absent — never a prefix of it.
      for (var width = 90.0; width <= 420.0; width += 10) {
        await pumpAt(
          tester,
          width: width,
          timing: EventTiming.startingSoon,
          trailing: 'in 30 min',
        );
        final label = renderedLabel(tester);
        expect(
          label == 'Starting soon' || label == 'Starting soon · in 30 min',
          isTrue,
          reason: 'at ${width}pt the badge rendered a partial label: "$label"',
        );
      }
    });

    testWidgets('the decision is monotonic — once the countdown is dropped it '
        'stays dropped as the box narrows', (tester) async {
      // Guards against a measurement bug that reinstates the countdown at some
      // narrower width, which is where a partial render would come back.
      var droppedAt = double.infinity;
      for (var width = 900.0; width >= 80.0; width -= 20) {
        await pumpAt(
          tester,
          width: width,
          timing: EventTiming.startingSoon,
          trailing: 'in 30 min',
        );
        final hasCountdown = renderedLabel(tester).contains('30 min');
        if (!hasCountdown) {
          droppedAt = width;
        } else if (droppedAt.isFinite) {
          // Widths only ever shrink in this loop, so seeing the countdown again
          // after it was dropped means the measurement is not monotonic.
          fail(
            'countdown reappeared at ${width}pt after being dropped at '
            '${droppedAt}pt',
          );
        }
      }
      expect(
        droppedAt.isFinite,
        isTrue,
        reason: 'the countdown was never dropped, even in an 80pt box',
      );
    });

    testWidgets('large text also degrades by dropping, not cutting', (
      tester,
    ) async {
      // At 200% the label alone barely fits; the countdown must be gone.
      await pumpAt(
        tester,
        width: 196,
        timing: EventTiming.happeningNow,
        trailing: 'in 15 min',
        textScale: 2.0,
      );
      expect(renderedLabel(tester), isNot(contains('15')));
      expect(renderedLabel(tester), isNot(contains('in 1')));
    });

    testWidgets('Persian degrades the same way', (tester) async {
      await pumpAt(
        tester,
        width: 196,
        timing: EventTiming.happeningNow,
        trailing: 'در ۱۵ دقیقه',
        locale: const Locale('fa'),
      );
      final label = renderedLabel(tester);
      // Either the whole countdown or none of it — no partial Persian numeral.
      expect(
        label.contains('۱۵ دقیقه') || !label.contains('۱'),
        isTrue,
        reason: 'partial Persian countdown rendered: "$label"',
      );
    });

    testWidgets('a badge with no countdown is unaffected', (tester) async {
      await pumpAt(tester, width: 196, timing: EventTiming.finished);
      expect(renderedLabel(tester), 'Finished');
    });

    testWidgets('an unbounded badge keeps the countdown', (tester) async {
      // No LayoutBuilder width to measure against — must not silently drop it.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            baseClockProvider.overrideWithValue(
              FixedClock(EventInfo.at(19, 0)),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AonL10n.localizationsDelegates,
            supportedLocales: AonL10n.supportedLocales,
            theme: AonTheme.build(),
            home: const Scaffold(
              body: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: TimingBadge(
                  timing: EventTiming.happeningNow,
                  trailingText: 'in 15 min',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(renderedLabel(tester), 'Happening now · in 15 min');
    });
  });
}
