import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/services/providers.dart';

/// The 360° picker offers a walk-through of the *event's* locations. Its list
/// is derived from the official AON program map's A–I legend — the same
/// lettering printed on the sheet people carry — so the picker can never
/// drift from the paper map, and so a service point nobody wants a panorama
/// of (a toilet, a bus stop) cannot appear just because it is a venue.
void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  test('lists exactly the official map A–I event venues, in letter order', () {
    final venues = container.read(panoramaPickerVenuesProvider);

    expect(
      venues.map((v) => v.mapReference).toList(),
      ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I'],
    );
    expect(venues.map((v) => v.id).toList(), [
      'macquarie-theatre',
      'mason-theatre',
      'food-and-drink',
      '14-sir-christopher-ondaatje-avenue',
      '1-central-courtyard',
      'sport-and-aquatic-centre',
      'astronomical-observatory',
      '11-wallys-walk',
      '17-wallys-walk',
    ]);
  });

  test('venues the printed legend does not letter A–I are excluded', () {
    final ids = container
        .read(panoramaPickerVenuesProvider)
        .map((v) => v.id)
        .toSet();

    const notOnTheEventLegend = [
      // Registration and information carry 1/2/3, not a letter.
      'registration-point',
      'information-point-2',
      'information-point-3',
      // Service points: no letter, and no reason to offer a 360° of one.
      'toilets-macquarie-theatre',
      'toilets-1-central-courtyard',
      'toilets-mason-theatre',
      'first-aid',
      // Transport: off-site arrival, not an event location.
      'metro-station',
      'shuttle-stop',
      'bus-stop',
      // Unlettered on the sheet — see venues_data.dart for why.
      'gymnasium-road',
      'central-courtyard',
    ];
    for (final id in notOnTheEventLegend) {
      expect(
        ids,
        isNot(contains(id)),
        reason: '$id carries no A–I letter on the official map',
      );
    }
  });
}
