import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/data/panorama_data.dart';
import 'package:aon2026/data/venues_data.dart';
import 'package:aon2026/services/providers.dart';

/// The 360° picker is deliberately narrower than the event-location registry.
/// Only D–I are part of this catalogue; C (Food and drink) will never receive
/// a panorama and must not be advertised as "Coming soon".
void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  test('lists exactly the planned D–I 360 venues, in letter order', () {
    final venues = container.read(panoramaPickerVenuesProvider);

    expect(venues.map((v) => v.mapReference).toList(), [
      'D',
      'E',
      'F',
      'G',
      'H',
      'I',
    ]);
    expect(venues.map((v) => v.id).toList(), [
      '14-sir-christopher-ondaatje-avenue',
      '1-central-courtyard',
      'sport-and-aquatic-centre',
      'astronomical-observatory',
      '11-wallys-walk',
      '17-wallys-walk',
    ]);
  });

  test('Food and drink remains shared app data but has no 360 contract', () {
    expect(VenuesData.byId('food-and-drink'), isNotNull);
    expect(PanoramaData.tourFor('food-and-drink'), isNull);
    expect(
      container.read(panoramaPickerVenuesProvider).map((venue) => venue.id),
      isNot(contains('food-and-drink')),
    );
  });

  test('venues outside the planned D-I catalogue are excluded', () {
    final ids = container
        .read(panoramaPickerVenuesProvider)
        .map((v) => v.id)
        .toSet();

    const excludedFromPicker = [
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
      // Unlettered on the sheet — see venues_data.dart for why. gymnasium-road
      // (the Solar system walk) DOES have a 360° tour, but it is a route, not a
      // lettered venue: the picker pins it as a top card of its own rather than
      // in this D–I letter provider. So it must stay OUT of this list.
      'gymnasium-road',
      'central-courtyard',
      // Valid event venues with direct tours, but not part of the current
      // top-level D–I 360 catalogue.
      'macquarie-theatre',
      'mason-theatre',
      // Lettered C, but explicitly not planned for 360 content.
      'food-and-drink',
    ];
    for (final id in excludedFromPicker) {
      expect(
        ids,
        isNot(contains(id)),
        reason: '$id is not part of the planned D-I 360 catalogue',
      );
    }
  });
}
