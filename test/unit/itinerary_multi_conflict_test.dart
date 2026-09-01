import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/models/event.dart';
import 'package:aon2026/services/itinerary_service.dart';

/// §10 adversarial conflict presentation: existing tests only pair TWO events.
/// These pin the multi-conflict case — three saved activities overlapping the
/// same window must each name the OTHER two (de-duped, no self-reference), and a
/// genuinely-separate activity in the same plan must stay unflagged.
void main() {
  DateTime at(int h, int m) => DateTime(2026, 9, 19, h, m);

  AonEvent ev(String id, String title, DateTime s, DateTime e) => AonEvent(
        id: id,
        title: title,
        description: '',
        category: EventCategory.activity,
        venueId: '1-central-courtyard',
        sessions: [EventSession(start: s, end: e)],
      );

  Map<String, List<String>> conflictsByTitle(List<ItineraryEntry> entries) => {
        for (final e in entries) e.event.title: e.conflictsWith,
      };

  test('three overlapping activities each list the OTHER two as conflicts', () {
    final a = ev('a', 'Alpha', at(17, 0), at(18, 0)); // 5.00–6.00
    final b = ev('b', 'Bravo', at(17, 30), at(18, 30)); // 5.30–6.30
    final c = ev('c', 'Charlie', at(17, 15), at(17, 45)); // 5.15–5.45 (inside)

    final entries = ItineraryService.build(
      allEvents: [a, b, c],
      savedIds: {'a', 'b', 'c'},
      now: at(12, 0),
    );

    final byTitle = conflictsByTitle(entries);
    expect(byTitle['Alpha']!.toSet(), {'Bravo', 'Charlie'});
    expect(byTitle['Bravo']!.toSet(), {'Alpha', 'Charlie'});
    expect(byTitle['Charlie']!.toSet(), {'Alpha', 'Bravo'});
    // No entry ever names itself, and all three are flagged.
    for (final e in entries) {
      expect(e.conflictsWith, isNot(contains(e.event.title)));
      expect(e.hasConflict, isTrue);
    }
  });

  test('a separate activity in the same plan stays unflagged', () {
    final a = ev('a', 'Alpha', at(17, 0), at(18, 0));
    final b = ev('b', 'Bravo', at(17, 30), at(18, 30));
    final d = ev('d', 'Delta', at(19, 0), at(19, 30)); // no overlap

    final entries = ItineraryService.build(
      allEvents: [a, b, d],
      savedIds: {'a', 'b', 'd'},
      now: at(12, 0),
    );

    final delta = entries.firstWhere((e) => e.event.title == 'Delta');
    expect(delta.hasConflict, isFalse);
    expect(delta.conflictsWith, isEmpty);
    // The two that DO overlap still clash — the separate one didn't suppress it.
    expect(conflictsByTitle(entries)['Alpha'], ['Bravo']);
  });

  test('conflict titles are de-duplicated when a multi-session event overlaps',
      () {
    // A 3-session event, all sessions overlapping one long activity, must be
    // named ONCE in that activity's conflict list, not three times.
    final longActivity = ev('long', 'Long', at(17, 0), at(20, 0));
    final repeated = AonEvent(
      id: 'rep',
      title: 'Repeated',
      description: '',
      category: EventCategory.activity,
      venueId: '1-central-courtyard',
      sessions: [
        EventSession(start: at(17, 15), end: at(17, 45)),
        EventSession(start: at(18, 15), end: at(18, 45)),
        EventSession(start: at(19, 15), end: at(19, 45)),
      ],
    );

    final entries = ItineraryService.build(
      allEvents: [longActivity, repeated],
      savedIds: {'long', 'rep'},
      now: at(12, 0),
    );

    final long = entries.firstWhere((e) => e.event.id == 'long');
    expect(long.conflictsWith, ['Repeated']); // once, not three times
  });
}
