import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/data/events_data.dart';
import 'package:aon2026/data/venues_data.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/l10n/generated/app_localizations_en.dart';
import 'package:aon2026/l10n/generated/app_localizations_fa.dart';
import 'package:aon2026/models/event.dart';
import 'package:aon2026/services/event_filter.dart';
import 'package:aon2026/utils/time_format.dart';

/// Liz's 2026-08-31 programme update, as the source of truth. Each group pins
/// one item she confirmed, so a later data edit that regresses it fails loudly.
void main() {
  DateTime at(int h, int m) => EventInfo.at(h, m);
  final AonL10n en = AonL10nEn();
  final AonL10n fa = AonL10nFa();

  AonEvent byId(String id) => EventsData.byId(id)!;

  List<AonEvent> search(String q) =>
      EventFilterService.apply(EventsData.all, EventFilter(query: q));

  group('A/B — Capture the Cosmos (aka the astrophotography display)', () {
    test('is open all night in the 17 Wally\'s Walk foyer', () {
      final e = byId('capture-the-cosmos');
      final s = e.sessions.single;
      expect(s.timing, TimingConfidence.fullEventConfirmed);
      expect(s.isFullEvent, isTrue);
      expect(e.venueId, '17-wallys-walk');
      expect(e.room, 'Foyer');
      expect(TimeFormat.allSessionsLabel(en, e), en.timingOpenAllEvening);
    });

    test('there is no SEPARATE fabricated "Astrophotography Display" activity', () {
      // Liz\'s "astrophotography display" IS Capture the Cosmos. No invented
      // duplicate entry.
      final displays = EventsData.all.where((e) =>
          e.id != 'capture-the-cosmos' &&
          e.title.toLowerCase().contains('astrophotography') &&
          e.category == EventCategory.activity);
      expect(displays, isEmpty);
    });
  });

  group('C — Featured astro talk (17 WW G25, 5.00–5.45pm)', () {
    test('exists with the exact confirmed time, location and room', () {
      final e = byId('featured-astrophotography');
      final s = e.sessions.single;
      expect(s.timing, TimingConfidence.exactTime);
      expect(s.start, at(17, 0));
      expect(s.end, at(17, 45));
      expect(e.venueId, '17-wallys-walk');
      expect(e.room, 'G25 Theatre');
    });
  });

  group('D — Exhibition/Exhibitor Hall (14 SCO)', () {
    test('is an exact 4.15pm–10pm session at 14 Sir Christopher Ondaatje Ave', () {
      final e = byId('exhibition-hall');
      final s = e.sessions.single;
      expect(s.timing, TimingConfidence.exactTime);
      expect(s.start, at(16, 15));
      expect(s.end, at(22, 0));
      expect(e.venueId, '14-sir-christopher-ondaatje-avenue');
      expect(TimeFormat.allSessionsLabel(en, e), contains('4.15pm'));
      expect(TimeFormat.allSessionsLabel(en, e), contains('10pm'));
    });
  });

  group('E — Solar System Walk (Gymnasium Road)', () {
    test('is open all night but NEVER a published start/finish', () {
      final e = byId('solar-system-walk');
      final s = e.sessions.single;
      expect(s.timing, TimingConfidence.openAllNight);
      expect(s.isFullEvent, isTrue);
      expect(s.hasPublishedStart, isFalse);
      expect(s.hasPublishedEnd, isFalse);
      expect(e.venueId, 'gymnasium-road');
      expect(TimeFormat.allSessionsLabel(en, e), en.timingOpenAllEvening);
      // Not a "Time not published" contradiction, not a fabricated range.
      expect(TimeFormat.allSessionsLabel(en, e),
          isNot(equals(en.timingTimeNotPublished)));
      expect(TimeFormat.allSessionsLabel(en, e), isNot(contains('–')));
    });
  });

  group('Kids\' space → Room 109 (was 106)', () {
    test('room is 109, venue is 1 Central Courtyard (1CC / Liz\'s "ICC")', () {
      final e = byId('kids-space');
      expect(e.room, 'Room 109');
      expect(e.venueId, '1-central-courtyard');
      expect(VenuesData.byId('1-central-courtyard')!.buildingId, '1CC');
    });
  });

  group('Persian timing label', () {
    test('a full-event activity reads "open all night" in Persian, not a range',
        () {
      final e = byId('capture-the-cosmos');
      final label = TimeFormat.allSessionsLabel(fa, e);
      expect(label, fa.timingOpenAllEvening);
      expect(label, isNot(contains('–')));
    });
  });

  group('search finds the updated content', () {
    void findsEvent(String query, String id) {
      expect(search(query).map((e) => e.id), contains(id),
          reason: '"$query" should find $id');
    }

    test('the updated activities are searchable', () {
      findsEvent('Kids', 'kids-space');
      findsEvent('109', 'kids-space'); // the NEW room
      findsEvent('Capture the Cosmos', 'capture-the-cosmos');
      findsEvent('Exhibitor', 'exhibition-hall'); // Liz\'s wording via tag
      findsEvent('Exhibition', 'exhibition-hall');
      findsEvent('Solar System Walk', 'solar-system-walk');
      findsEvent('Astrophotography', 'capture-the-cosmos');
      findsEvent('G25', 'featured-astrophotography');
    });

    test('searching "Huntsman" returns NOTHING (cancelled)', () {
      expect(search('Huntsman'), isEmpty);
      expect(search('Exploratorium'), isEmpty);
    });

    test('the venues behind the updates resolve correctly', () {
      // Show-on-Map / Directions resolve to the parent building; room/foyer is a
      // text detail, never invented room-level GPS.
      expect(VenuesData.byId('17-wallys-walk'), isNotNull);
      expect(VenuesData.byId('14-sir-christopher-ondaatje-avenue'), isNotNull);
      expect(VenuesData.byId('gymnasium-road'), isNotNull);
      expect(VenuesData.byId('1-central-courtyard'), isNotNull);
    });
  });
}
