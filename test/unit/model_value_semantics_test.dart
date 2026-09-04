import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/data/routes_data.dart';
import 'package:aon2026/data/stamp_stations_data.dart';
import 'package:aon2026/models/data_confidence.dart';
import 'package:aon2026/models/event.dart';
import 'package:aon2026/models/parking_area.dart';
import 'package:aon2026/models/venue.dart';
import 'package:aon2026/models/walking_route.dart';
import 'package:aon2026/services/clock.dart';

/// Value semantics and small lookups the app leans on everywhere.
///
/// These are the seams that make `Set<Venue>`, `contains`, and de-duplication
/// behave: identity is the **id**, so two records describing the same place
/// collapse to one even when a later revision changes a label or a coordinate.
void main() {
  group('identity is the id, not the payload', () {
    const a = Venue(
      id: 'macquarie-theatre',
      name: 'Macquarie Theatre',
      category: VenueCategory.eventVenue,
    );
    const renamed = Venue(
      id: 'macquarie-theatre',
      name: 'MQ Theatre (renamed in a later revision)',
      category: VenueCategory.foodAndDrink,
      latitude: -33.77,
      longitude: 151.11,
    );
    const other = Venue(
      id: 'mason-theatre',
      name: 'Mason Theatre',
      category: VenueCategory.eventVenue,
    );

    test('two records for the same venue are one entry in a Set', () {
      expect(a, renamed);
      expect(a.hashCode, renamed.hashCode);
      expect({a, renamed, other}, hasLength(2));
    });

    test('different venues stay distinct', () {
      expect(a, isNot(other));
    });

    test('toString names the record without dumping it', () {
      expect(a.toString(), 'Venue(macquarie-theatre, Macquarie Theatre)');
    });

    test('parking areas compare by id', () {
      const west = ParkingArea(id: 'west-6', name: 'West 6');
      const westMoved = ParkingArea(
        id: 'west-6',
        name: 'West 6',
        latitude: -33.77,
        longitude: 151.11,
      );
      const north = ParkingArea(id: 'north-1', name: 'North 1');
      expect(west, westMoved);
      expect(west.hashCode, westMoved.hashCode);
      expect(west, isNot(north));
      expect(west.toString(), 'ParkingArea(west-6, West 6)');
    });

    test('walking routes compare by id', () {
      const route = WalkingRoute(
        id: 'west6-to-mqth',
        fromId: 'west-6',
        toId: 'macquarie-theatre',
        fromLabel: 'West 6',
        toLabel: 'Macquarie Theatre',
        steps: [RouteStep(instruction: 'Walk east')],
      );
      const sameIdDifferentSteps = WalkingRoute(
        id: 'west6-to-mqth',
        fromId: 'west-6',
        toId: 'macquarie-theatre',
        fromLabel: 'West 6',
        toLabel: 'Macquarie Theatre',
        steps: [RouteStep(instruction: 'Walk east, then north')],
      );
      const different = WalkingRoute(
        id: 'north1-to-mqth',
        fromId: 'north-1',
        toId: 'macquarie-theatre',
        fromLabel: 'North 1',
        toLabel: 'Macquarie Theatre',
        steps: [RouteStep(instruction: 'Walk south')],
      );
      expect(route, sameIdDifferentSteps);
      expect(route.hashCode, sameIdDifferentSteps.hashCode);
      expect(route, isNot(different));
      expect(
        route.toString(),
        'WalkingRoute(west6-to-mqth, West 6 -> Macquarie Theatre)',
      );
    });
  });

  group('Venue.hasCampusCoordinates', () {
    Venue at(double? x, double? y) =>
        Venue(id: 'v', name: 'V', category: VenueCategory.eventVenue,
            campusX: x, campusY: y);

    test('true only when both pixel coordinates are present', () {
      expect(at(2140, 1954).hasCampusCoordinates, isTrue);
      expect(at(null, 1954).hasCampusCoordinates, isFalse);
      expect(at(2140, null).hasCampusCoordinates, isFalse);
      expect(at(null, null).hasCampusCoordinates, isFalse);
    });

    test('(0,0) is treated as unset, not as the map corner', () {
      // A default-initialised pair would otherwise pin the venue to the
      // top-left of the artwork, which looks like real data.
      expect(at(0, 0).hasCampusCoordinates, isFalse);
      // Only the pair is rejected — a genuine zero on one axis survives.
      expect(at(0, 1954).hasCampusCoordinates, isTrue);
    });
  });

  group('AonEvent schedule', () {
    AonEvent multi(List<(int, int)> hours) => AonEvent(
      id: 'e',
      title: 'Talk',
      description: '',
      category: EventCategory.shortTalk,
      venueId: 'macquarie-theatre',
      sessions: [
        for (final (s, e) in hours)
          EventSession(start: EventInfo.at(s), end: EventInfo.at(e)),
      ],
    );

    test('lastEnd is the latest end, not the last listed', () {
      // Sessions are deliberately out of order: the late one is listed first.
      expect(multi([(20, 21), (16, 17)]).lastEnd, EventInfo.at(21));
    });

    test('a single-session event ends when it ends', () {
      expect(multi([(16, 17)]).lastEnd, EventInfo.at(17));
      expect(multi([(16, 17)]).hasMultipleSessions, isFalse);
    });

    test('isRunningAt is true inside any session, false in the gap', () {
      final e = multi([(16, 17), (20, 21)]);
      expect(e.isRunningAt(EventInfo.at(16, 30)), isTrue);
      expect(e.isRunningAt(EventInfo.at(20, 30)), isTrue);
      expect(e.isRunningAt(EventInfo.at(18, 30)), isFalse, reason: 'the gap');
      expect(e.isRunningAt(EventInfo.at(23)), isFalse, reason: 'after close');
    });

    test('events compare by id', () {
      expect(multi([(16, 17)]), multi([(20, 21)]));
      expect(multi([(16, 17)]).hashCode, multi([(20, 21)]).hashCode);
      expect(multi([(16, 17)]).toString(), 'AonEvent(e, Talk)');
    });
  });

  group('DataConfidence.label', () {
    test('every level reads as provenance, never as certainty', () {
      expect(DataConfidence.confirmed.label, 'Confirmed');
      expect(DataConfidence.derived.label, 'Derived from campus data');
      expect(DataConfidence.placeholder.label, 'Approximate — to be confirmed');
      // No level is left without a label — a blank would read as "confirmed".
      for (final c in DataConfidence.values) {
        expect(c.label, isNotEmpty, reason: c.name);
      }
    });
  });

  group('exact-lookup helpers reject what they do not know', () {
    test('StampStationsData.byVenueId', () {
      expect(StampStationsData.byVenueId('macquarie-theatre')?.code,
          'AON-A-FL3R');
      expect(StampStationsData.byVenueId('first-aid'), isNull);
      expect(StampStationsData.byVenueId(''), isNull);
    });

    test('RoutesData.byId', () {
      final known = RoutesData.all.first;
      expect(RoutesData.byId(known.id), same(known));
      expect(RoutesData.byId('no-such-route'), isNull);
    });
  });

  test('EventInfo.previewInstant is 7pm on the event date', () {
    // Chosen because several activities overlap then — a preview at 4pm would
    // show an almost-empty programme and read as a bug.
    expect(EventInfo.previewInstant, EventInfo.at(19, 0));
    expect(
      EventInfo.previewInstant.isAfter(EventInfo.startsAt),
      isTrue,
    );
    expect(EventInfo.previewInstant.isBefore(EventInfo.endsAt), isTrue);
  });

  group('OffsetClock', () {
    test('runs at real speed, shifted by the offset', () {
      const offset = Duration(hours: 5);
      final clock = OffsetClock(offset);
      final before = DateTime.now().add(offset);
      final reading = clock.now();
      final after = DateTime.now().add(offset);
      expect(reading.isBefore(before), isFalse);
      expect(reading.isAfter(after), isFalse);
    });

    test('a zero offset is just the wall clock', () {
      final drift = OffsetClock(Duration.zero)
          .now()
          .difference(DateTime.now())
          .abs();
      expect(drift, lessThan(const Duration(seconds: 1)));
    });
  });
}
