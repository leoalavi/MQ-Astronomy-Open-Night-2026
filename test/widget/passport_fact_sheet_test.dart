import 'package:flutter/material.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aon2026/models/data_confidence.dart';
import 'package:aon2026/models/passport_fact.dart';
import 'package:aon2026/widgets/confidence_note.dart';
import 'package:aon2026/widgets/passport_fact_sheet.dart';

PassportFact _fact(DataConfidence c) => PassportFact(
  venueId: 'v',
  activityLabel: 'Telescope Park',
  title: 'A telescope is also a time machine',
  fact: 'Light takes time to travel.',
  confidence: c,
);

// No scroll view here — the sheet must scroll itself (design §8.3), so the
// 2.0 test exercises the real internal scrolling, not the host's.
Widget _host(Widget child) => MaterialApp(
  localizationsDelegates: AonL10n.localizationsDelegates,
  supportedLocales: AonL10n.supportedLocales,
  home: Scaffold(body: child),
);

void _bigViewport(WidgetTester t) {
  t.view.physicalSize = const Size(320, 568);
  t.view.devicePixelRatio = 1.0;
  t.platformDispatcher.textScaleFactorTestValue = 2.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
}

void main() {
  testWidgets('reliable fact shows title + body, no draft note', (t) async {
    await t.pumpWidget(
      _host(
        PassportFactSheet(
          fact: _fact(DataConfidence.confirmed),
          reason: FactRevealReason.revisit,
          isRelease: true,
        ),
      ),
    );
    expect(find.text('A telescope is also a time machine'), findsOneWidget);
    expect(find.textContaining('Light takes time'), findsOneWidget);
    expect(find.byType(ConfidenceNote), findsNothing);
  });

  testWidgets('collected: shows a Stamp collected success + the real fact, '
      'never a draft/awaiting-review note (even release + placeholder)', (
    t,
  ) async {
    await t.pumpWidget(
      _host(
        PassportFactSheet(
          fact: _fact(DataConfidence.placeholder),
          reason: FactRevealReason.collected,
          isRelease: true,
        ),
      ),
    );
    // Visitor-facing success, no internal wording.
    expect(find.textContaining('Stamp collected'), findsOneWidget);
    expect(find.textContaining('awaiting review'), findsNothing);
    expect(find.byType(ConfidenceNote), findsNothing);
    // The real fact is the reward — shown, not hidden behind a fallback.
    expect(find.text('A telescope is also a time machine'), findsOneWidget);
    expect(find.textContaining('Light takes time'), findsOneWidget);
  });

  testWidgets('placeholder in DEBUG also shows the real body, no draft note', (
    t,
  ) async {
    await t.pumpWidget(
      _host(
        PassportFactSheet(
          fact: _fact(DataConfidence.placeholder),
          reason: FactRevealReason.revisit,
          isRelease: false,
        ),
      ),
    );
    expect(find.textContaining('Light takes time'), findsOneWidget);
    expect(find.byType(ConfidenceNote), findsNothing);
    expect(find.textContaining('awaiting review'), findsNothing);
  });

  testWidgets('direct: no overflow at 320x568 / 2.0 (self-scrolls)', (t) async {
    _bigViewport(t);
    await t.pumpWidget(
      _host(
        PassportFactSheet(
          fact: _fact(DataConfidence.confirmed),
          reason: FactRevealReason.collected,
          isRelease: true,
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  // §8.3: a real-modal test that PROVES scrolling works (C2), with the long
  // Central Courtyard draft in a constrained 320×568 / 2.0 modal.
  testWidgets('real modal: content is genuinely scrollable at 320x568 / 2.0', (
    t,
  ) async {
    _bigViewport(t);
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showPassportFactSheet(
                  context,
                  'central-courtyard',
                  reason: FactRevealReason.revisit,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.byType(PassportFactSheet), findsOneWidget);
    expect(t.takeException(), isNull);

    final scrollable = find.descendant(
      of: find.byType(PassportFactSheet),
      matching: find.byType(Scrollable),
    );
    final pos = t.state<ScrollableState>(scrollable.first).position;
    expect(
      pos.maxScrollExtent,
      greaterThan(0),
      reason: 'long fact at 2.0 must overflow into a real scroll',
    );
    await t.drag(scrollable.first, const Offset(0, -120));
    await t.pumpAndSettle();
    expect(pos.pixels, greaterThan(0));
  });

  // C3: placeholder + release + 320×568 + 2.0, all at once — the real fact
  // scrolls without overflow and shows no draft wording.
  testWidgets('release + placeholder collect: no overflow at 320x568 / 2.0', (
    t,
  ) async {
    _bigViewport(t);
    await t.pumpWidget(
      _host(
        PassportFactSheet(
          fact: _fact(DataConfidence.placeholder),
          reason: FactRevealReason.collected,
          isRelease: true,
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.textContaining('awaiting review'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('shows the venue name, not just the activity', (t) async {
    await t.pumpWidget(
      _host(
        const PassportFactSheet(
          fact: PassportFact(
            venueId: 'macquarie-theatre',
            activityLabel: 'Physics Magic Show',
            title: 'Gravity can bend light',
            fact: 'A massive object deflects light.',
          ),
          reason: FactRevealReason.revisit,
          isRelease: false,
        ),
      ),
    );
    expect(find.text('Macquarie Theatre'), findsOneWidget); // from VenuesData
    expect(find.text('PHYSICS MAGIC SHOW'), findsOneWidget);
  });

  testWidgets('reduced motion: collect reveal has no scale animation', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: PassportFactSheet(
            fact: _fact(DataConfidence.confirmed),
            reason: FactRevealReason.collected,
            isRelease: true,
          ),
        ),
      ),
    );
    await t.pump();
    expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget); // static
  });

  testWidgets('motion enabled: collect reveal animates the stamp', (t) async {
    await t.pumpWidget(
      _host(
        PassportFactSheet(
          fact: _fact(DataConfidence.confirmed),
          reason: FactRevealReason.collected,
          isRelease: true,
        ),
      ),
    );
    expect(find.byType(TweenAnimationBuilder<double>), findsOneWidget);
    await t.pumpAndSettle();
  });

  testWidgets('structured semantics: venue is a header, Close is a button', (
    t,
  ) async {
    final handle = t.ensureSemantics();
    await t.pumpWidget(
      _host(
        const PassportFactSheet(
          fact: PassportFact(
            venueId: 'macquarie-theatre',
            activityLabel: 'Physics Magic Show',
            title: 'Gravity can bend light',
            fact: 'A massive object.',
          ),
          reason: FactRevealReason.revisit,
          isRelease: false,
        ),
      ),
    );
    final venue = t.getSemantics(find.text('Macquarie Theatre'));
    expect(venue.getSemanticsData().flagsCollection.isHeader, isTrue);
    final close = t.getSemantics(find.text('Close'));
    expect(close.getSemanticsData().flagsCollection.isButton, isTrue);
    handle.dispose(); // must dispose before the test body ends, not in teardown
  });

  testWidgets('showPassportFactSheet no-ops for an unknown venue', (t) async {
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showPassportFactSheet(
                context,
                'no-such-venue',
                reason: FactRevealReason.revisit,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.byType(PassportFactSheet), findsNothing);
    expect(t.takeException(), isNull);
  });
}
