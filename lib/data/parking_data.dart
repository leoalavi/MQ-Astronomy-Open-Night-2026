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
/// **West 6** does not exist in the MQ Journey dataset, and the official event
/// map prints the "West 6" label twice, in two different places. It now carries
/// two coordinates that agree on the same real car park:
///   * a real GPS (`latitude`/`longitude`) from the public map record for the
///     "West 6 (Macquarie University)" car park on Link Rd — a named, verified
///     location, name-matched to the event's West 6 — which drives real-world
///     Google directions; and
///   * an `artworkX`/`artworkY` pin at the LOWER of the two printed "West 6"
///     labels (the one beside Link Rd, matching that GPS), because the real GPS
///     sits ~50 m off the western crop of the AON artwork and so cannot be
///     projected onto the bundled map image.
/// Marked [DataConfidence.derived], the same class as West 5 and South 2, so it
/// renders with directions and a map pin like the others. Source: public maps
/// lookup, Sep 2026 (Link Rd car park, ~160 m west of West 5).
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
      // Real GPS (public map record for the "West 6 (Macquarie University)"
      // car park on Link Rd) drives real-world directions. It sits just off
      // the western crop of the official AON artwork, so the in-app map pin is
      // placed instead by the artwork's OWN printed "West 6" marker — the lower
      // of the two "West 6" labels, the one beside Link Road, which matches
      // this GPS (south-west of West 5). See ParkingData class doc.
      latitude: -33.773681,
      longitude: 151.107524,
      artworkX: 957,
      artworkY: 1826,
      coordinateConfidence: DataConfidence.derived,
      notes:
          'Western side of campus, on Link Road just past West 5 — close to '
          'the Sport and Aquatic Centre (planetariums) and the Observatory.',
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
