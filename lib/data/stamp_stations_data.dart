import 'package:aon2026/models/stamp_station.dart';

/// The 9 passport stations — the map-legend A–I event venues.
///
/// Codes are PLACEHOLDER until the organiser confirms the signage tokens
/// (design §14). While any code is placeholder the domain release gate keeps
/// prize collection disabled in release builds (PassportPolicy /
/// passportCollectionEnabledProvider); debug builds allow it for pre-event QA.
abstract final class StampStationsData {
  static const List<StampStation> all = [
    StampStation(venueId: 'macquarie-theatre', code: 'AON-A-TBC'),
    StampStation(venueId: 'mason-theatre', code: 'AON-B-TBC'),
    StampStation(venueId: 'central-courtyard', code: 'AON-C-TBC'),
    StampStation(
      venueId: '14-sir-christopher-ondaatje-avenue',
      code: 'AON-D-TBC',
    ),
    StampStation(venueId: '1-central-courtyard', code: 'AON-E-TBC'),
    StampStation(venueId: 'sport-and-aquatic-centre', code: 'AON-F-TBC'),
    StampStation(venueId: 'astronomical-observatory', code: 'AON-G-TBC'),
    StampStation(venueId: '11-wallys-walk', code: 'AON-H-TBC'),
    StampStation(venueId: '17-wallys-walk', code: 'AON-I-TBC'),
  ];

  static int get count => all.length;

  static Set<String> get stationVenueIds =>
      all.map((s) => s.venueId).toSet();

  static StampStation? byVenueId(String venueId) {
    for (final s in all) {
      if (s.venueId == venueId) return s;
    }
    return null;
  }
}
