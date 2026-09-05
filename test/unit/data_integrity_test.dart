import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/data/events_data.dart';
import 'package:aon2026/models/event.dart';
import 'package:aon2026/data/parking_data.dart';
import 'package:aon2026/data/passport_facts_data.dart';
import 'package:aon2026/data/routes_data.dart';
import 'package:aon2026/data/stamp_stations_data.dart';
import 'package:aon2026/data/venues_data.dart';
import 'package:aon2026/config/event_config.dart';
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

    test('West 6 is pinned to its verified Link Road car park', () {
      // History: West 6 deliberately had NO coordinate, because the official
      // event artwork prints the "West 6" label twice. It is now pinned to the
      // public map record for the real "West 6 (Macquarie University)" car park
      // on Link Road (~160 m west of West 5), so it behaves like West 5 and
      // South 2 — a pin, directions and a map focus. If that decision is ever
      // reversed, change this test too — and think about which "West 6" the
      // organisers actually mean.
      final west6 = ParkingData.byId('west-6')!;
      expect(west6.hasCoordinates, isTrue);
      expect(west6.coordinateConfidence, DataConfidence.derived);
      // Immediately west of West 5, at a similar latitude.
      final west5 = ParkingData.byId('west-5')!;
      expect(west6.longitude, lessThan(west5.longitude!),
          reason: 'West 6 sits west of West 5');
      expect((west6.latitude! - west5.latitude!).abs(), lessThan(0.001),
          reason: 'West 6 is at roughly the same latitude as West 5');
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

    test('toilets and information points are mapped', () {
      final categories = VenuesData.all.map((v) => v.category).toSet();
      expect(categories, contains(VenueCategory.toilets));
      expect(categories, contains(VenueCategory.informationPoint));
    });

    test('unverified First Aid is not exposed as an interactive venue', () {
      expect(VenuesData.byId('first-aid'), isNull);
      expect(
        EventConfig.astronomyOpenNight.quickAccess.map((q) => q.id),
        isNot(contains('first-aid')),
      );
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
          expect(
            PassportFactsData.sourceRegistry,
            contains(f.sourceRef),
            reason: '${f.venueId} uses unregistered sourceRef ${f.sourceRef}',
          );
        }
        if (f.confidence == DataConfidence.derived) {
          expect(
            f.sourceRef,
            isNotNull,
            reason: '${f.venueId} derived w/o source',
          );
        }
      }
    });

    test('the Markdown registry documents every registered source (C1)', () {
      final md = File('docs/passport-fact-sources.md').readAsStringSync();
      for (final ref in PassportFactsData.sourceRegistry) {
        expect(
          md,
          contains(ref),
          reason: '$ref not documented in docs/passport-fact-sources.md',
        );
      }
    });
  });

  group('programme size and provenance (PDF golden)', () {
    test('the programme has exactly 36 entries, in the expected shape', () {
      // Transcribed verbatim from the official A3 programme PDF. If this count
      // changes, it must be a deliberate re-transcription, not a silent drift.
      expect(EventsData.all.length, 36);

      final byCategory = <EventCategory, int>{};
      for (final e in EventsData.all) {
        byCategory[e.category] = (byCategory[e.category] ?? 0) + 1;
      }
      expect(byCategory[EventCategory.activity], 20);
      expect(byCategory[EventCategory.keynote], 1);
      expect(byCategory[EventCategory.featuredPresentation], 3);
      expect(byCategory[EventCategory.shortTalk], 12);
    });

    test('every entry records where it came from', () {
      // sourceNote is the provenance link back to the PDF/email — no entry may
      // exist without one, which is the guard against invented event facts.
      final orphans = EventsData.all
          .where((e) => e.sourceNote == null || e.sourceNote!.trim().isEmpty)
          .map((e) => e.id)
          .toList();
      expect(
        orphans,
        isEmpty,
        reason: 'these entries have no source provenance: $orphans',
      );
    });
  });

  group('venue assignments match the official PDF/email list', () {
    // Liz's email + the A3 programme fix each activity to a building. Pinned so
    // a data edit can never quietly move an activity to the wrong venue.
    test('the enumerated activities sit at their official venues', () {
      const expected = <String, String>{
        'Physics magic show': 'macquarie-theatre',
        'Chemistry magic show': 'mason-theatre',
        'Exhibition Hall': '14-sir-christopher-ondaatje-avenue',
        'Kids\u2019 space': '1-central-courtyard',
        'Planetariums': 'sport-and-aquatic-centre',
        'Telescope Park': 'astronomical-observatory',
        'Laser Challenge': '11-wallys-walk',
        'Capture the cosmos': '17-wallys-walk',
      };
      for (final entry in expected.entries) {
        final matches = EventsData.all
            .where((e) => e.title == entry.key)
            .toList();
        expect(matches, isNotEmpty, reason: 'missing activity "${entry.key}"');
        for (final e in matches) {
          expect(
            e.venueId,
            entry.value,
            reason: '"${entry.key}" must be at ${entry.value}',
          );
        }
      }
    });

    test('the keynote is Professor Fred Watson AM at Macquarie Theatre', () {
      final keynote = EventsData.all.firstWhere(
        (e) => e.category == EventCategory.keynote,
      );
      expect(keynote.presenter, 'Professor Fred Watson AM');
      expect(keynote.venueId, 'macquarie-theatre');
    });
  });

  group('shuttle bus and bus stop are removed', () {
    // Removed at the organisers' request: the supplied material gave neither a
    // stop location, route nor timetable, so both only ever showed as an
    // "unknown location" row. Gone entirely — data and category alike — so no
    // empty map filter chip or Info row is left behind.
    test('the shuttle-stop and bus-stop venues no longer exist', () {
      expect(VenuesData.byId('shuttle-stop'), isNull);
      expect(VenuesData.byId('bus-stop'), isNull);
    });

    test('no venue uses a removed transport category', () {
      final names = VenueCategory.values.map((c) => c.name).toSet();
      expect(names, isNot(contains('shuttleStop')));
      expect(names, isNot(contains('busStop')));
    });
  });

  group('West 6 routing', () {
    test('the West 6 → Central Courtyard route is now a real polyline', () {
      final route = RoutesData.between('west-6', 'central-courtyard')!;
      // Two endpoints = a "that way" direction indicator, same as West 5 and
      // South 2. Before it was pinned, this route had no points at all.
      expect(route.points, hasLength(2));
      final west6 = ParkingData.byId('west-6')!;
      expect(route.points.first.latitude, west6.latitude);
      expect(route.points.first.longitude, west6.longitude);
    });
  });
}
