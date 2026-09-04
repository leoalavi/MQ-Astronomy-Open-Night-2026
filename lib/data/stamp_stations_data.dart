import 'package:aon2026/models/data_confidence.dart';
import 'package:aon2026/models/stamp_station.dart';

/// The 9 passport stations — the map-legend A–I event venues.
///
/// These are the LIVE production codes. They are minted here, in the app, and
/// `tools/passport/build_station_qr.py` generates the printed venue signs from
/// this same list — so the sign and the app cannot disagree. The contract that
/// makes that true runs one way only: **the signs that go to the printer must
/// be the ones this file generates.** Change a code here and the existing
/// printed signs stop working; re-run the generator and re-print.
///
/// Every station is [DataConfidence.confirmed], which opens the domain release
/// gate (PassportPolicy.isCollectionEnabled / passportCollectionEnabledProvider)
/// so the stamp rally works in release builds on the night.
///
/// The code alphabet deliberately excludes characters that are confusable in
/// print or when typed by hand — no `0`/`O`, `1`/`I`, `2`/`Z`, `5`/`S`, `6`/`G`,
/// `8`/`B` — because manual entry is the accessibility fallback for anyone
/// whose camera will not focus in the dark.
///
/// The codes are NOT secrets and are not proof of attendance — see the doc
/// comment on [StampStation]. They are per-station rather than guessable from
/// one another only so that reading one sign does not hand someone the whole
/// trail; staff redemption at the prize booth remains the actual control.
abstract final class StampStationsData {
  static const List<StampStation> all = [
    StampStation(
      venueId: 'macquarie-theatre',
      code: 'AON-A-FL3R',
      codeConfidence: DataConfidence.confirmed,
    ),
    StampStation(
      venueId: 'mason-theatre',
      code: 'AON-B-HFUM',
      codeConfidence: DataConfidence.confirmed,
    ),
    StampStation(
      venueId: 'central-courtyard',
      code: 'AON-C-MU4T',
      codeConfidence: DataConfidence.confirmed,
    ),
    StampStation(
      venueId: '14-sir-christopher-ondaatje-avenue',
      code: 'AON-D-H3HA',
      codeConfidence: DataConfidence.confirmed,
    ),
    StampStation(
      venueId: '1-central-courtyard',
      code: 'AON-E-CJQX',
      codeConfidence: DataConfidence.confirmed,
    ),
    StampStation(
      venueId: 'sport-and-aquatic-centre',
      code: 'AON-F-UF37',
      codeConfidence: DataConfidence.confirmed,
    ),
    StampStation(
      venueId: 'astronomical-observatory',
      code: 'AON-G-YHVN',
      codeConfidence: DataConfidence.confirmed,
    ),
    StampStation(
      venueId: '11-wallys-walk',
      code: 'AON-H-3WNQ',
      codeConfidence: DataConfidence.confirmed,
    ),
    StampStation(
      venueId: '17-wallys-walk',
      code: 'AON-I-JRYL',
      codeConfidence: DataConfidence.confirmed,
    ),
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
