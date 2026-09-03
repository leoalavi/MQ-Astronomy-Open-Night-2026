import 'package:aon2026/models/data_confidence.dart';
import 'package:aon2026/models/parking_area.dart';

/// Event parking areas.
///
/// Source: the official event map marks free parking at **West 5**, **West 6**
/// and **South 2**.
///
/// Coordinates for West 5 and South 2 are taken from the MQ Journey campus
/// dataset (`Carpark P West 5`, `Carpark P South 2`) and marked
/// [DataConfidence.derived].
///
/// **West 6 has no coordinate.** It does not exist in the MQ Journey dataset,
/// and the event map shows the "West 6" label twice, in two different places —
/// so even reading it off the map would be a coin flip. It is listed with a
/// null coordinate and an explicit warning rather than a plausible-looking pin,
/// because sending a family to the wrong car park at 10pm is the single worst
/// failure this app could have.
abstract final class ParkingData {
  static const List<ParkingArea> all = [
    ParkingArea(
      id: 'west-5',
      name: 'West 5',
      latitude: -33.773501,
      longitude: 151.109232,
      coordinateConfidence: DataConfidence.derived,
      notes:
          'Western side of campus, closest to the Sport and Aquatic Centre '
          '(planetariums) and the Observatory.',
    ),
    ParkingArea(
      id: 'west-6',
      name: 'West 6',
      // PLACEHOLDER — see class doc. Do not fill this in from the map without
      // confirming with the organisers which of the two "West 6" labels is
      // the event car park.
      coordinateConfidence: DataConfidence.placeholder,
      // No note: the exact West 6 position is unconfirmed, so an
      // "to be confirmed" placeholder line is omitted rather than shown.
    ),
    ParkingArea(
      id: 'south-2',
      name: 'South 2',
      latitude: -33.776533,
      longitude: 151.114171,
      coordinateConfidence: DataConfidence.derived,
      notes:
          'Southern side of campus, closest to 17 Wally’s Walk and the '
          'Library end of the Central Courtyard.',
    ),
  ];

  static ParkingArea? byId(String id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }
}
