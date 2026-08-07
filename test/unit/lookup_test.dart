import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/data/events_data.dart';
import 'package:aon2026/data/parking_data.dart';
import 'package:aon2026/data/routes_data.dart';
import 'package:aon2026/data/venues_data.dart';
import 'package:aon2026/services/providers.dart';

/// Location and route lookup, including the missing-data paths.
///
/// The negative cases matter more than the positive ones here: a lookup that
/// throws on an unknown id would turn a stale shared link into a crash.
void main() {
  group('venue lookup', () {
    test('finds a known venue', () {
      final venue = VenuesData.byId('macquarie-theatre');
      expect(venue, isNotNull);
      expect(venue!.name, 'Macquarie Theatre');
      expect(venue.mapReference, 'A');
    });

    test('returns null for an unknown id rather than throwing', () {
      expect(VenuesData.byId('no-such-venue'), isNull);
    });

    test('matches on an alias, not just the official name', () {
      // Attendees search for what is printed on the map, not our ids.
      final sco = VenuesData.byId('14-sir-christopher-ondaatje-avenue')!;
      expect(sco.matches('Mason Theatre'), isTrue);
      expect(sco.matches('Exhibition Hall'), isTrue);
      expect(sco.matches('14 SCO'), isTrue);
    });

    test('matches on the printed map legend letter', () {
      final observatory = VenuesData.byId('astronomical-observatory')!;
      expect(observatory.matches('G'), isTrue);
      expect(observatory.matches('Z'), isFalse);
    });

    test('an empty query matches everything', () {
      final venue = VenuesData.byId('central-courtyard')!;
      expect(venue.matches(''), isTrue);
      expect(venue.matches('   '), isTrue);
    });

    test('routing coordinates prefer the entrance when one is set', () {
      for (final v in VenuesData.all) {
        if (v.entranceLatitude != null) {
          expect(v.routingLatitude, v.entranceLatitude);
        } else if (v.latitude != null) {
          expect(v.routingLatitude, v.latitude);
        }
      }
    });
  });

  group('parking lookup', () {
    test('finds a known car park', () {
      expect(ParkingData.byId('west-5')?.name, 'West 5');
    });

    test('returns null for an unknown id', () {
      expect(ParkingData.byId('west-99'), isNull);
    });
  });

  group('route lookup', () {
    test('finds a defined route between two points', () {
      final route =
          RoutesData.between('west-6', 'central-courtyard');
      expect(route, isNotNull);
      expect(route!.steps, isNotEmpty);
    });

    test('returns null when no route is defined for a pair', () {
      // The UI must distinguish this from "nothing selected yet".
      expect(
        RoutesData.between('west-5', '11-wallys-walk'),
        isNull,
      );
    });

    test('routes are directional — A→B does not imply B→A', () {
      expect(
        RoutesData.between('west-5', 'central-courtyard'),
        isNotNull,
      );
      expect(
        RoutesData.between('central-courtyard', 'west-5'),
        isNull,
        reason:
            'Return routes are not auto-generated. If we want them, they '
            'should be authored — walking directions do not simply reverse.',
      );
    });

    test('from() returns every route leaving a point', () {
      final fromWest5 = RoutesData.from('west-5');
      expect(fromWest5, isNotEmpty);
      expect(fromWest5.every((r) => r.fromId == 'west-5'), isTrue);
    });

    test('from() returns empty for a point with no routes', () {
      expect(RoutesData.from('nowhere'), isEmpty);
    });

    test('every route has written instructions', () {
      // The polyline is optional; the words are not. This is the whole
      // premise of the wayfinding design.
      for (final route in RoutesData.all) {
        expect(
          route.steps,
          isNotEmpty,
          reason: '${route.id} has no written directions',
        );
        for (final step in route.steps) {
          expect(step.instruction.trim(), isNotEmpty);
        }
      }
    });

    test('a route without geometry is not claimed to have a polyline', () {
      final west6 = RoutesData.between('west-6', 'central-courtyard')!;
      expect(west6.hasPolyline, isFalse);
      expect(west6.steps, isNotEmpty);
    });

    test('accessibility is null (unknown), never silently false', () {
      // `null` renders as "not confirmed"; `false` renders as "not step-free".
      // Asserting the current state so that flipping one is a deliberate act.
      for (final route in RoutesData.all) {
        expect(
          route.isAccessible,
          isNull,
          reason: '${route.id}: if this route has been surveyed, update the '
              'test along with the data.',
        );
      }
    });
  });

  group('providers degrade gracefully', () {
    late ProviderContainer container;

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    test('venueByIdProvider returns null for a missing venue', () {
      expect(container.read(venueByIdProvider('nope')), isNull);
    });

    test('eventByIdProvider returns null for a removed event', () {
      // The cancelled Huntsman session is the real-world case: an old shared
      // link must land on a friendly "not found", not an exception.
      expect(
        container.read(eventByIdProvider('huntsman-exploratorium')),
        isNull,
      );
    });

    test('eventsAtVenueProvider returns empty for a venue with nothing on', () {
      expect(container.read(eventsAtVenueProvider('first-aid')), isEmpty);
    });

    test('eventsAtVenueProvider finds events and sorts them by start', () {
      final events = container.read(
        eventsAtVenueProvider('1-central-courtyard'),
      );
      expect(events, isNotEmpty);
      for (var i = 1; i < events.length; i++) {
        expect(
          events[i].firstStart.isBefore(events[i - 1].firstStart),
          isFalse,
        );
      }
    });

    test('venuesWithEventsProvider excludes facility-only venues', () {
      final venues = container.read(venuesWithEventsProvider);
      final ids = venues.map((v) => v.id);

      expect(ids, contains('macquarie-theatre'));
      expect(ids, isNot(contains('first-aid')));
      expect(ids, isNot(contains('toilets-mason-theatre')));
    });

    test('selectedRouteProvider is null until both ends are chosen', () {
      expect(container.read(selectedRouteProvider), isNull);

      container
          .read(selectedRouteStartProvider.notifier)
          .select('west-5');
      expect(container.read(selectedRouteProvider), isNull);

      container
          .read(selectedRouteDestinationProvider.notifier)
          .select('central-courtyard');
      expect(container.read(selectedRouteProvider), isNotNull);
    });

    test('toggling a selected id clears it', () {
      final notifier = container.read(selectedRouteStartProvider.notifier);
      notifier.toggle('west-5');
      expect(container.read(selectedRouteStartProvider), 'west-5');
      notifier.toggle('west-5');
      expect(container.read(selectedRouteStartProvider), isNull);
    });
  });

  group('event lookup', () {
    test('finds a known event', () {
      expect(EventsData.byId('keynote-artemis')?.presenter,
          'Professor Fred Watson AM');
    });

    test('returns null for an unknown id', () {
      expect(EventsData.byId('nope'), isNull);
    });
  });
}
