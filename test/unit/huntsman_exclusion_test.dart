import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/data/events_data.dart';
import 'package:aon2026/data/venues_data.dart';

/// Guards the deliberate omission of the cancelled Huntsman Telescope
/// Exploratorium.
///
/// ## Why this test exists
///
/// The Huntsman Telescope Exploratorium (Room 109, 1 Central Courtyard) is
/// printed in the official programme PDF and marked on the official map, but
/// the event organisers confirmed it is **not going ahead**.
///
/// That makes it uniquely dangerous. Every other data error in this repo would
/// be caught by comparing the app against the source material — but here, the
/// source material is the *wrong* answer. A future maintainer reconciling
/// `events_data.dart` against the PDF will find Room 109 missing and be
/// tempted to add it back as a fix.
///
/// This test is the tripwire. If it fails, do not "fix" the data — re-read
/// this comment.
void main() {
  group('Huntsman Telescope Exploratorium is excluded', () {
    test('no event mentions Huntsman', () {
      final offenders = EventsData.all.where((e) {
        final haystack = '${e.title} ${e.description} ${e.tags.join(' ')}'
            .toLowerCase();
        return haystack.contains('huntsman');
      }).toList();

      expect(
        offenders,
        isEmpty,
        reason:
            'The Huntsman Telescope Exploratorium was cancelled by the event '
            'organisers. It appears in the official PDF programme, but must '
            'NOT appear in the app. Found: '
            '${offenders.map((e) => e.id).join(', ')}',
      );
    });

    test('no event is scheduled in Room 109', () {
      final offenders = EventsData.all
          .where((e) => (e.room ?? '').toLowerCase().contains('109'))
          .toList();

      expect(
        offenders,
        isEmpty,
        reason:
            'Room 109 at 1 Central Courtyard hosted only the cancelled '
            'Huntsman Telescope Exploratorium. Nothing should be scheduled '
            'there. Found: ${offenders.map((e) => e.id).join(', ')}',
      );
    });

    test('no venue is named after the Exploratorium', () {
      final offenders = VenuesData.all.where((v) {
        final haystack =
            '${v.name} ${v.building ?? ''} ${v.aliases.join(' ')}'
                .toLowerCase();
        return haystack.contains('huntsman') ||
            haystack.contains('exploratorium');
      }).toList();

      expect(offenders, isEmpty, reason: 'Cancelled — see file header.');
    });

    test(
      'the other 1 Central Courtyard rooms ARE still present',
      () {
        // A blunt "remove anything mentioning Central Courtyard" fix would
        // also pass the tests above. This asserts we removed exactly one
        // thing, not the whole venue.
        final roomsAt1CC = EventsData.all
            .where((e) => e.venueId == '1-central-courtyard')
            .map((e) => e.room)
            .whereType<String>()
            .toList();

        expect(roomsAt1CC, contains('Room 108'));
        expect(roomsAt1CC, contains('Room 112'));
        expect(
          roomsAt1CC.length,
          greaterThanOrEqualTo(7),
          reason: 'Room 109 aside, 1 Central Courtyard hosts many rooms.',
        );
      },
    );
  });
}
