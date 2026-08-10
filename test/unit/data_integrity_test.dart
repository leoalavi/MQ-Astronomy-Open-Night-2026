import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/data/events_data.dart';
import 'package:aon2026/data/parking_data.dart';
import 'package:aon2026/data/passport_facts_data.dart';
import 'package:aon2026/data/routes_data.dart';
import 'package:aon2026/data/stamp_stations_data.dart';
import 'package:aon2026/data/venues_data.dart';
import 'package:aon2026/models/data_confidence.dart';
import 'package:aon2026/models/venue.dart';

/// Structural checks over the bundled data.
///
/// These are the tests that catch a typo in a hand-edited data file before it
/// reaches someone standing in a dark car park.
void main() {
  group('referential integrity', () {
    test('every event points at a venue that exists', () {
      for (final event in EventsData.all) {
        expect(
          VenuesData.byId(event.venueId),
          isNotNull,
          reason:
              'Event "${event.id}" references unknown venue '
              '"${event.venueId}"',
        );
      }
    });

    test('every route endpoint resolves to a venue or car park', () {
      for (final route in RoutesData.all) {
        final fromExists =
            VenuesData.byId(route.fromId) != null ||
            ParkingData.byId(route.fromId) != null;
        final toExists = VenuesData.byId(route.toId) != null;

        expect(fromExists, isTrue, reason: 'Route "${route.id}" from');
        expect(toExists, isTrue, reason: 'Route "${route.id}" to');
      }
    });

    test('ids are unique', () {
      void expectUnique(Iterable<String> ids, String label) {
        final seen = <String>{};
        final dupes = <String>[];
        for (final id in ids) {
          if (!seen.add(id)) dupes.add(id);
        }
        expect(dupes, isEmpty, reason: 'duplicate $label ids: $dupes');
      }

      expectUnique(EventsData.all.map((e) => e.id), 'event');
      expectUnique(VenuesData.all.map((v) => v.id), 'venue');
      expectUnique(ParkingData.all.map((p) => p.id), 'parking');
      expectUnique(RoutesData.all.map((r) => r.id), 'route');
    });
  });

  group('event data sanity', () {
    test('every event has at least one session', () {
      for (final event in EventsData.all) {
        expect(event.sessions, isNotEmpty, reason: event.id);
      }
    });

    test('every session ends after it starts', () {
      for (final event in EventsData.all) {
        for (final s in event.sessions) {
          expect(
            s.end.isAfter(s.start),
            isTrue,
            reason: '${event.id}: ${s.start} -> ${s.end}',
          );
        }
      }
    });

    test('every session falls inside the published event window', () {
      for (final event in EventsData.all) {
        for (final s in event.sessions) {
          expect(
            s.start.isBefore(EventInfo.startsAt),
            isFalse,
            reason: '${event.id} starts before the event opens',
          );
          expect(
            s.end.isAfter(EventInfo.endsAt),
            isFalse,
            reason: '${event.id} ends after the event closes',
          );
        }
      }
    });

    test('every event is on the event date', () {
      for (final event in EventsData.all) {
        for (final s in event.sessions) {
          expect(s.start.year, EventInfo.eventYear);
          expect(s.start.month, EventInfo.eventMonth);
          expect(s.start.day, EventInfo.eventDay);
        }
      }
    });

    test('titles and descriptions are non-empty', () {
      for (final event in EventsData.all) {
        expect(event.title.trim(), isNotEmpty, reason: event.id);
        expect(event.description.trim(), isNotEmpty, reason: event.id);
      }
    });

    test('the programme contains the four official sections', () {
      final categories = EventsData.all.map((e) => e.category).toSet();
      expect(categories, hasLength(4));
    });

    test('there are 12 short talks, 6 in each theatre', () {
      final talks = EventsData.all
          .where((e) => e.room == 'Theatre 3' || e.room == 'Theatre 4')
          .toList();
      expect(talks, hasLength(12));
      expect(talks.where((t) => t.room == 'Theatre 3'), hasLength(6));
      expect(talks.where((t) => t.room == 'Theatre 4'), hasLength(6));
    });
  });

  group('placeholder discipline', () {
    test('placeholder times always carry an explanatory note', () {
      for (final event in EventsData.all) {
        for (final s in event.sessions) {
          if (s.timeConfidence == DataConfidence.placeholder) {
            expect(
              s.note,
              isNotNull,
              reason:
                  '${event.id} has a placeholder time with no note '
                  'explaining why — the UI needs something to show.',
            );
          }
        }
      }
    });

    test('a venue with no coordinates is never marked confirmed', () {
      for (final v in VenuesData.all) {
        if (!v.hasCoordinates) {
          expect(
            v.coordinateConfidence,
            isNot(DataConfidence.confirmed),
            reason: '${v.id} claims confirmed coordinates but has none',
          );
        }
      }
    });

    test('West 6 has no invented coordinate', () {
      // Explicitly pinned: the event map labels West 6 in two places, so a
      // guessed pin here would be actively harmful. If someone adds a
      // coordinate, they must also change this test — and think about it.
      final west6 = ParkingData.byId('west-6')!;
      expect(west6.hasCoordinates, isFalse);
      expect(west6.coordinateConfidence, DataConfidence.placeholder);
      expect(west6.notes, isNotNull);
    });

    test('coordinates that do exist are inside the campus bounding box', () {
      // Catches a transposed lat/lng or a dropped minus sign, which would
      // otherwise put a marker in the Mediterranean.
      const north = -33.768;
      const south = -33.782;
      const west = 151.100;
      const east = 151.125;

      for (final v in VenuesData.all) {
        if (!v.hasCoordinates) continue;
        expect(v.latitude, lessThan(north), reason: v.id);
        expect(v.latitude, greaterThan(south), reason: v.id);
        expect(v.longitude, greaterThan(west), reason: v.id);
        expect(v.longitude, lessThan(east), reason: v.id);
      }

      for (final p in ParkingData.all) {
        if (!p.hasCoordinates) continue;
        expect(p.latitude, lessThan(north), reason: p.id);
        expect(p.latitude, greaterThan(south), reason: p.id);
        expect(p.longitude, greaterThan(west), reason: p.id);
        expect(p.longitude, lessThan(east), reason: p.id);
      }
    });
  });

  group('required venues from the brief', () {
    // The MVP brief lists specific places the map must support.
    const required = [
      'central-courtyard',
      'macquarie-theatre',
      'mason-theatre',
      '14-sir-christopher-ondaatje-avenue',
      '17-wallys-walk',
      '11-wallys-walk',
      'sport-and-aquatic-centre',
      'astronomical-observatory',
      'metro-station',
      'shuttle-stop',
      'first-aid',
    ];

    for (final id in required) {
      test('"$id" exists', () {
        expect(VenuesData.byId(id), isNotNull);
      });
    }

    test('all three car parks are present', () {
      expect(
        ParkingData.all.map((p) => p.name),
        containsAll(['West 5', 'West 6', 'South 2']),
      );
    });

    test('toilets, first aid and information points are all mapped', () {
      final categories = VenuesData.all.map((v) => v.category).toSet();
      expect(categories, contains(VenueCategory.toilets));
      expect(categories, contains(VenueCategory.firstAid));
      expect(categories, contains(VenueCategory.informationPoint));
    });
  });

  group('passport stations', () {
    const stations = StampStationsData.all;

    test('there are exactly 9 stations', () {
      expect(stations.length, 9);
      expect(StampStationsData.count, 9);
    });

    test('the station set EQUALS the event-venue set (both directions)', () {
      final eventVenueIds = VenuesData.eventVenues.map((v) => v.id).toSet();
      // Not just subset: adding a 10th event venue must force a passport
      // decision rather than silently leaving it off the trail.
      expect(StampStationsData.stationVenueIds, eventVenueIds);
    });

    test('venueIds and codes are each unique', () {
      expect(stations.map((s) => s.venueId).toSet().length, 9);
      expect(stations.map((s) => s.code.toUpperCase()).toSet().length, 9);
    });
  });

  group('passport facts', () {
    const facts = PassportFactsData.all;

    test('exactly 9 facts, unique venueIds', () {
      expect(facts.length, 9);
      expect(facts.map((f) => f.venueId).toSet().length, 9);
    });

    test('fact venueIds == station venueIds == event-venue ids', () {
      final eventVenueIds = VenuesData.eventVenues.map((v) => v.id).toSet();
      expect(PassportFactsData.venueIds, StampStationsData.stationVenueIds);
      expect(PassportFactsData.venueIds, eventVenueIds);
    });

    test('titles, activity labels and fact bodies are non-empty', () {
      for (final f in facts) {
        expect(f.title.trim(), isNotEmpty, reason: f.venueId);
        expect(f.activityLabel.trim(), isNotEmpty, reason: f.venueId);
        expect(f.fact.trim(), isNotEmpty, reason: f.venueId);
      }
    });

    test('every sourceRef used is registered; every derived fact has one', () {
      for (final f in facts) {
        if (f.sourceRef != null) {
          expect(PassportFactsData.sourceRegistry, contains(f.sourceRef),
              reason: '${f.venueId} uses unregistered sourceRef ${f.sourceRef}');
        }
        if (f.confidence == DataConfidence.derived) {
          expect(f.sourceRef, isNotNull,
              reason: '${f.venueId} derived w/o source');
        }
      }
    });

    test('the Markdown registry documents every registered source (C1)', () {
      final md = File('docs/passport-fact-sources.md').readAsStringSync();
      for (final ref in PassportFactsData.sourceRegistry) {
        expect(md, contains(ref),
            reason: '$ref not documented in docs/passport-fact-sources.md');
      }
    });
  });
}
