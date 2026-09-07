import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aon2026/app/theme/aon_theme.dart';
import 'package:aon2026/config/event_config.dart';
import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/data/events_data.dart';
import 'package:aon2026/data/panorama_data.dart';
import 'package:aon2026/data/venues_data.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/screens/event_detail_screen.dart';
import 'package:aon2026/screens/program_screen.dart';
import 'package:aon2026/services/clock.dart';
import 'package:aon2026/services/providers.dart';
import 'package:aon2026/services/saved_events.dart';
import 'package:aon2026/widgets/section_header.dart';

/// The frontend↔backend boundary, and the Program view switcher.
///
/// These are the seams Raouf plugs into. They are tested from the frontend
/// side only — nothing here reimplements or asserts the internals of his
/// panorama stack.
/// The titles of the currently-rendered [SectionHeader]s.
///
/// Card category labels ("Activities", "Short talks") appear in both programme
/// views, so a plain text finder cannot tell them apart. The section headers
/// can.
List<String> sectionTitles(WidgetTester tester) => tester
    .widgetList<SectionHeader>(find.byType(SectionHeader))
    .map((h) => h.title)
    .toList();

void main() {
  Widget app(Widget home) {
    SharedPreferences.setMockInitialValues({
      SavedEventsStorage.keyFor(EventConfig.astronomyOpenNight.id): <String>[],
    });
    return ProviderScope(
      overrides: [
        baseClockProvider.overrideWithValue(FixedClock(EventInfo.at(19, 0))),
      ],
      child: MaterialApp(
        localizationsDelegates: AonL10n.localizationsDelegates,
        supportedLocales: AonL10n.supportedLocales,
        theme: AonTheme.build(),
        home: home,
      ),
    );
  }

  group('360° availability comes from the backend contract', () {
    test('availability is derived from PanoramaData, never guessed', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(venuesWithPanoramaProvider),
        PanoramaData.tours.map((t) => t.venueId).toSet(),
        reason: 'the frontend must not maintain its own tour list',
      );
    });

    test('every tour id resolves to a real venue', () {
      // A near-miss id would silently render "not available" forever, which is
      // the worst kind of bug: no error, just a missing feature.
      for (final tour in PanoramaData.tours) {
        expect(VenuesData.byId(tour.venueId), isNotNull,
            reason: 'PanoramaData references unknown venue "${tour.venueId}"');
      }
    });

    testWidgets('a venue WITH a tour offers the 360° entry', (tester) async {
      final venueId = PanoramaData.tours.first.venueId;
      final event =
          EventsData.all.firstWhere((e) => e.venueId == venueId);

      await tester.pumpWidget(app(EventDetailScreen(eventId: event.id)));
      await tester.pumpAndSettle();

      // The control lives in the Location block, below the fold.
      await tester.scrollUntilVisible(
        find.text('360° view'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('360° view'), findsOneWidget);
    });

    testWidgets('a venue WITHOUT a tour shows no 360° control at all',
        (tester) async {
      // Absent, not disabled: a greyed-out button invites a tap and then
      // explains nothing.
      final event = EventsData.all.firstWhere(
        (e) => !PanoramaData.hasTour(e.venueId),
      );

      await tester.pumpWidget(app(EventDetailScreen(eventId: event.id)));
      await tester.pumpAndSettle();

      expect(find.text('360° view'), findsNothing);
    });

    testWidgets('the feature flag can hide 360° entirely', (tester) async {
      // Proves the entry point is genuinely config-gated, so an event without
      // panoramas ships no dead UI.
      final venueId = PanoramaData.tours.first.venueId;
      final event = EventsData.all.firstWhere((e) => e.venueId == venueId);

      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(ProviderScope(
        overrides: [
          baseClockProvider.overrideWithValue(FixedClock(EventInfo.at(19, 0))),
          featuresProvider.overrideWithValue(
            const EventFeatures(
              panorama: false,
              wayfinding: true,
              myPlan: true,
              scan: false,
              stamps: false,
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AonL10n.localizationsDelegates,
          supportedLocales: AonL10n.supportedLocales,
          theme: AonTheme.build(),
          home: EventDetailScreen(eventId: event.id),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('360° view'), findsNothing);
    });
  });

  group('Program view switcher', () {
    testWidgets('defaults to the time-sliced Tonight view', (tester) async {
      await tester.pumpWidget(app(const ProgramScreen()));
      await tester.pumpAndSettle();

      // Category words appear on every card in both views, so compare the
      // SECTION HEADERS — that is what the switcher actually changes.
      expect(sectionTitles(tester), contains('Happening now'));
      expect(sectionTitles(tester), isNot(contains('Activities')));
    });

    testWidgets('switching to Sections regroups by the printed programme',
        (tester) async {
      await tester.pumpWidget(app(const ProgramScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sections'));
      await tester.pumpAndSettle();

      expect(sectionTitles(tester), contains('Activities'));
      expect(sectionTitles(tester), isNot(contains('Happening now')));
    });

    testWidgets('switching back returns to Tonight', (tester) async {
      await tester.pumpWidget(app(const ProgramScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sections'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tonight'));
      await tester.pumpAndSettle();

      expect(sectionTitles(tester), contains('Happening now'));
    });

    testWidgets('filters apply in both views', (tester) async {
      await tester.pumpWidget(app(const ProgramScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'zzz-no-match');
      await tester.pumpAndSettle();
      expect(find.text('Nothing matches'), findsOneWidget);

      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing matches'), findsNothing);
    });
  });

  group('fixture boundaries', () {
    test('screens and widgets never import fixture data directly', () {
      // Every fixture must be reached through a provider, so swapping it for
      // Raouf's Supabase source is a one-file change.
      const fixtures = [
        'data/events_data.dart',
        'data/venues_data.dart',
        'data/parking_data.dart',
        'data/routes_data.dart',
      ];

      // Raouf owns the passport widgets; `passport_grid.dart` currently reads
      // VenuesData directly. Flagged to him in docs/backend-integration.md
      // rather than edited here — it is his file and his call.
      bool backendOwned(String path) => path.contains('passport') ||
          path.contains('panorama');

      final offenders = <String>[];
      for (final dir in ['lib/screens', 'lib/widgets']) {
        for (final f in Directory(dir)
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .where((f) => !backendOwned(f.path))) {
          final src = f.readAsStringSync();
          for (final fixture in fixtures) {
            if (src.contains(fixture)) offenders.add('${f.path} -> $fixture');
          }
        }
      }

      expect(offenders, isEmpty,
          reason: 'read fixtures through a provider, not directly:\n'
              '${offenders.join('\n')}');
    });

    test('every event references a venue that exists', () {
      // The join key Raouf's map/AR layers rely on.
      for (final e in EventsData.all) {
        expect(VenuesData.byId(e.venueId), isNotNull,
            reason: '${e.id} -> unknown venue ${e.venueId}');
      }
    });
  });

  group('PDF / email fidelity', () {
    test('the cancelled Huntsman session appears nowhere in lib/', () {
      // Liz Hennebry: "The only thing to not include is the Huntsman room
      // 1CC 109 as this is no longer going ahead."
      // Scoped to presentation: `lib/data/events_data.dart` deliberately
      // carries a comment explaining the omission, and
      // `huntsman_exclusion_test.dart` guards the data itself.
      final offenders = <String>[];
      for (final dir in ['lib/screens', 'lib/widgets', 'lib/config']) {
        for (final f in Directory(dir)
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
          final src = f.readAsStringSync().toLowerCase();
          if (src.contains('room 109') || src.contains('exploratorium')) {
            offenders.add(f.path);
          }
        }
      }
      expect(offenders, isEmpty);
    });

    test('event date and time match the official programme', () {
      // Front page: "19 SEPTEMBER 2026 / 4PM – 10PM".
      final c = EventConfig.astronomyOpenNight;
      expect(c.startsAt, DateTime(2026, 9, 19, 16));
      expect(c.endsAt, DateTime(2026, 9, 19, 22));
    });

    test('official venue names are preserved verbatim', () {
      for (final (id, name) in [
        ('macquarie-theatre', 'Macquarie Theatre'),
        ('mason-theatre', 'Mason Theatre'),
        ('central-courtyard', 'Central Courtyard'),
        ('1-central-courtyard', '1 Central Courtyard'),
        (
          '14-sir-christopher-ondaatje-avenue',
          '14 Sir Christopher Ondaatje Avenue'
        ),
        ('sport-and-aquatic-centre',
            'Macquarie University Sport and Aquatic Centre'),
        ('astronomical-observatory',
            'Macquarie University Astronomical Observatory'),
        ('11-wallys-walk', '11 Wally’s Walk'),
        ('17-wallys-walk', '17 Wally’s Walk'),
      ]) {
        expect(VenuesData.byId(id)?.name, name);
      }
    });

    test('the hero credit matches Liz Hennebry’s email exactly', () {
      expect(
        EventConfig.astronomyOpenNight.heroCredit,
        'A Deep Triangulum Galaxy — Aleix Roig, 2026',
      );
    });

    test('carpark guidance is reachable from the config', () {
      // Liz: "What would be awesome would be to include a guide of how to get
      // to and from the carparks."
      expect(EventConfig.astronomyOpenNight.features.wayfinding, isTrue);
      expect(
        EventConfig.astronomyOpenNight.quickAccess
            .any((q) => q.id == 'parking'),
        isTrue,
      );
    });
  });
}
