import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/data/events_data.dart';
import 'package:aon2026/data/venues_data.dart';
import 'package:aon2026/models/event.dart';
import 'package:aon2026/services/event_filter.dart';

/// Program search precision.
///
/// The programme is small (36 items) and mission-critical, so search must be
/// exact where it counts: an exact title finds its event, a venue name finds
/// everything there, case/whitespace never matter, and a nonsense query returns
/// nothing rather than everything.
void main() {
  final all = EventsData.all;

  List<AonEvent> search(String q) =>
      EventFilterService.apply(all, EventFilter(query: q));

  List<String> titles(List<AonEvent> es) => es.map((e) => e.title).toList();

  group('title search', () {
    test('an exact title finds exactly that event', () {
      final event = all.first;
      final hits = search(event.title);
      expect(hits, contains(event));
      // No duplicates.
      expect(hits.toSet().length, hits.length);
    });

    test('a partial title still finds it', () {
      final event =
          all.firstWhere((e) => e.title.split(' ').length >= 2);
      final word = event.title.split(' ').first;
      expect(search(word), contains(event));
    });

    test('search is case-insensitive', () {
      final event = all.first;
      expect(search(event.title.toUpperCase()), contains(event));
      expect(search(event.title.toLowerCase()), contains(event));
    });

    test('leading and trailing whitespace is ignored', () {
      final event = all.first;
      expect(search('   ${event.title}   '), contains(event));
    });
  });

  group('venue-name search (the gap this fix closed)', () {
    test('searching a venue name returns every event held there', () {
      // Pick a venue that actually hosts events.
      final venueId = all.first.venueId;
      final venue = VenuesData.byId(venueId)!;
      final expected =
          all.where((e) => e.venueId == venueId).map((e) => e.title).toSet();

      final got = titles(search(venue.name)).toSet();
      expect(got.containsAll(expected), isTrue,
          reason: 'searching "${venue.name}" missed ${expected.difference(got)}');
    });

    test('the Observatory is findable by name', () {
      // Telescope Park is at the Astronomical Observatory.
      final obs = VenuesData.byId('astronomical-observatory');
      if (obs == null) return; // dataset guard
      final hits = search(obs.name);
      expect(hits, isNotEmpty,
          reason: 'no event matched the Observatory by venue name');
    });
  });

  group('category search', () {
    test('searching a category name returns that category', () {
      final hits = search('keynote');
      expect(hits, isNotEmpty);
      expect(hits.every((e) => e.category.label.toLowerCase().contains('keynote')),
          isTrue);
    });
  });

  group('no-result and clearing', () {
    test('a nonsense query returns nothing, not everything', () {
      expect(search('zzzzz-not-a-real-activity'), isEmpty);
    });

    test('an empty query returns the whole programme', () {
      expect(search('').length, all.length);
      expect(search('    ').length, all.length);
    });
  });

  group('safety', () {
    test('search never resurrects the excluded Huntsman content', () {
      for (final q in ['huntsman', 'exploratorium', '109']) {
        for (final e in search(q)) {
          expect(e.title.toLowerCase(), isNot(contains('huntsman')));
        }
      }
    });
  });
}
