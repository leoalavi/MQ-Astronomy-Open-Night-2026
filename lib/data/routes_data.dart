import 'package:latlong2/latlong.dart';

import 'package:aon2026/models/data_confidence.dart';
import 'package:aon2026/models/walking_route.dart';

/// Predefined campus walking routes.
///
/// ## Status: DRAFT — requires organiser verification before the event
///
/// The organisers asked specifically for clearer guidance between parking and
/// event destinations, because attendees get disoriented after dark. These
/// routes are the answer to that, but **the written directions below are a
/// first draft written from campus coordinates, not from walking the campus at
/// night.** Every route is therefore [DataConfidence.placeholder].
///
/// Before the event, each route needs someone to walk it after sunset and
/// confirm three things:
///   1. the described landmarks are visible and correctly named;
///   2. the path is actually lit (the `lightingNotes` field is currently a
///      question, not an answer, on most routes);
///   3. whether it is step-free (`isAccessible` is `null` — meaning *unknown*,
///      which the UI renders as "not yet confirmed", never as "no").
///
/// ## Why the polylines are straight lines
///
/// Where both endpoints have coordinates, `points` holds exactly two points:
/// origin and destination. That is a **direction indicator, not a path** — we
/// have no verified path geometry, and drawing an invented curve through
/// campus would imply precision we do not have. The map renders
/// placeholder-confidence routes as a dashed line with an explicit caption so
/// this reads as "that way" rather than "walk exactly here".
///
/// Replace `points` with surveyed geometry (a GPX trace walked on site is
/// ideal) and flip `pathConfidence` to [DataConfidence.confirmed] to get solid
/// lines. See `docs/navigation-strategy.md`.
abstract final class RoutesData {
  // Endpoint coordinates, kept as named constants so a corrected coordinate
  // only has to be edited once.
  static const LatLng _west5 = LatLng(-33.773501, 151.109232);
  static const LatLng _south2 = LatLng(-33.776533, 151.114171);
  static const LatLng _centralCourtyard = LatLng(-33.7733531, 151.1133796);
  static const LatLng _observatory = LatLng(-33.7703261, 151.1111248);
  static const LatLng _sportAquatic = LatLng(-33.7726489, 151.1105693);
  static const LatLng _seventeenWW = LatLng(-33.7748805, 151.1133652);
  static const LatLng _metro = LatLng(-33.7768086, 151.1175848);

  static const List<WalkingRoute> all = [
    // ══════════════════════════════════════════════════════
    // From West 5
    // ══════════════════════════════════════════════════════
    WalkingRoute(
      id: 'west-5-to-central-courtyard',
      fromId: 'west-5',
      toId: 'central-courtyard',
      fromLabel: 'West 5 parking',
      toLabel: 'Central Courtyard',
      walkingMinutes: 6,
      distanceMetres: 400,
      pathConfidence: DataConfidence.placeholder,
      points: [_west5, _centralCourtyard],
      lightingNotes: 'Lighting on this route not yet confirmed.',
      steps: [
        RouteStep(
          instruction:
              'Leave West 5 car park and head east, into the campus, away '
              'from Western Road.',
          landmark: 'Keep the sports fields on your left.',
        ),
        RouteStep(
          instruction:
              'Follow the main pedestrian path east for about 350 metres.',
        ),
        RouteStep(
          instruction:
              'The Central Courtyard opens up ahead of you — look for the '
              'food stalls and the registration point.',
          landmark: 'Registration point 1 is in the courtyard.',
        ),
      ],
    ),
    WalkingRoute(
      id: 'west-5-to-sport-and-aquatic-centre',
      fromId: 'west-5',
      toId: 'sport-and-aquatic-centre',
      fromLabel: 'West 5 parking',
      toLabel: 'Sport and Aquatic Centre (planetariums)',
      walkingMinutes: 3,
      distanceMetres: 160,
      pathConfidence: DataConfidence.placeholder,
      points: [_west5, _sportAquatic],
      lightingNotes: 'Lighting on this route not yet confirmed.',
      steps: [
        RouteStep(
          instruction:
              'From West 5, head north-east towards Gymnasium Road.',
        ),
        RouteStep(
          instruction:
              'The Sport and Aquatic Centre is the large building directly '
              'ahead. Planetarium sessions run from inside.',
          landmark: '10 Gymnasium Road.',
        ),
      ],
    ),
    WalkingRoute(
      id: 'west-5-to-astronomical-observatory',
      fromId: 'west-5',
      toId: 'astronomical-observatory',
      fromLabel: 'West 5 parking',
      toLabel: 'Astronomical Observatory (Telescope Park)',
      walkingMinutes: 7,
      distanceMetres: 450,
      pathConfidence: DataConfidence.placeholder,
      points: [_west5, _observatory],
      lightingNotes:
          'The Observatory end is deliberately dark to protect night '
          'viewing. Bring a torch and use its red mode if it has one.',
      steps: [
        RouteStep(
          instruction: 'From West 5, join Gymnasium Road and head north.',
        ),
        RouteStep(
          instruction:
              'Continue north past the Sport and Aquatic Centre, staying on '
              'Gymnasium Road.',
          landmark: 'Sport and Aquatic Centre on your right.',
        ),
        RouteStep(
          instruction:
              'The Observatory is at 5 Gymnasium Road, at the northern end. '
              'Telescopes are set up on the open ground beside it.',
          landmark: 'Look for the telescope domes.',
        ),
      ],
    ),

    // ══════════════════════════════════════════════════════
    // From West 6
    //
    // West 6 has no confirmed coordinate (see ParkingData), so this route
    // has NO polyline — text only. The map shows written directions and an
    // explicit "location to be confirmed" notice rather than a guessed pin.
    // ══════════════════════════════════════════════════════
    WalkingRoute(
      id: 'west-6-to-central-courtyard',
      fromId: 'west-6',
      toId: 'central-courtyard',
      fromLabel: 'West 6 parking',
      toLabel: 'Central Courtyard',
      pathConfidence: DataConfidence.placeholder,
      lightingNotes: 'Lighting on this route not yet confirmed.',
      steps: [
        RouteStep(
          instruction:
              'West 6’s exact position is still being confirmed with the '
              'event organisers, so these directions are general.',
        ),
        RouteStep(
          instruction:
              'From the western car parks, head east into the campus, away '
              'from Western Road, and follow the signs for the Central '
              'Courtyard.',
        ),
        RouteStep(
          instruction:
              'If in doubt, ask a marshal or head for the lit food stalls — '
              'the Central Courtyard is the busiest point on campus.',
        ),
      ],
    ),

    // ══════════════════════════════════════════════════════
    // From South 2
    // ══════════════════════════════════════════════════════
    WalkingRoute(
      id: 'south-2-to-central-courtyard',
      fromId: 'south-2',
      toId: 'central-courtyard',
      fromLabel: 'South 2 parking',
      toLabel: 'Central Courtyard',
      walkingMinutes: 6,
      distanceMetres: 380,
      pathConfidence: DataConfidence.placeholder,
      points: [_south2, _centralCourtyard],
      lightingNotes: 'Lighting on this route not yet confirmed.',
      steps: [
        RouteStep(
          instruction:
              'Leave South 2 car park heading north, into the campus.',
        ),
        RouteStep(
          instruction:
              'Continue north past the Library, staying on the main paved '
              'path.',
          landmark: 'Waranara Library on your right.',
        ),
        RouteStep(
          instruction:
              'Keep going north through Wally’s Walk until the Central '
              'Courtyard opens up ahead.',
        ),
      ],
    ),
    WalkingRoute(
      id: 'south-2-to-17-wallys-walk',
      fromId: 'south-2',
      toId: '17-wallys-walk',
      fromLabel: 'South 2 parking',
      toLabel: '17 Wally’s Walk (featured presentations)',
      walkingMinutes: 3,
      distanceMetres: 200,
      pathConfidence: DataConfidence.placeholder,
      points: [_south2, _seventeenWW],
      lightingNotes: 'Lighting on this route not yet confirmed.',
      steps: [
        RouteStep(
          instruction: 'Leave South 2 car park heading north-west.',
        ),
        RouteStep(
          instruction:
              '17 Wally’s Walk is a short walk up on your left. The featured '
              'presentations and astrophotography exhibition are inside, in '
              'the G25 Theatre.',
        ),
      ],
    ),

    // ══════════════════════════════════════════════════════
    // Between event venues
    // ══════════════════════════════════════════════════════
    WalkingRoute(
      id: 'central-courtyard-to-astronomical-observatory',
      fromId: 'central-courtyard',
      toId: 'astronomical-observatory',
      fromLabel: 'Central Courtyard',
      toLabel: 'Astronomical Observatory (Telescope Park)',
      walkingMinutes: 10,
      distanceMetres: 600,
      pathConfidence: DataConfidence.placeholder,
      points: [_centralCourtyard, _observatory],
      lightingNotes:
          'Gets progressively darker towards the Observatory — that is '
          'intentional, to protect night viewing. Bring a torch.',
      steps: [
        RouteStep(
          instruction:
              'From the Central Courtyard, head north-west and pick up '
              'Gymnasium Road.',
        ),
        RouteStep(
          instruction:
              'Follow Gymnasium Road north. This is also the Solar system '
              'walk — you will pass the scale-model planets on the way.',
          landmark: 'Scale-model planets along the path.',
        ),
        RouteStep(
          instruction:
              'Continue past the Sport and Aquatic Centre to the Observatory '
              'at 5 Gymnasium Road.',
        ),
        RouteStep(
          instruction:
              'Allow about 10 minutes each way, and take a jacket — the '
              'Telescope Park is open ground.',
        ),
      ],
    ),
    WalkingRoute(
      id: 'central-courtyard-to-sport-and-aquatic-centre',
      fromId: 'central-courtyard',
      toId: 'sport-and-aquatic-centre',
      fromLabel: 'Central Courtyard',
      toLabel: 'Sport and Aquatic Centre (planetariums)',
      walkingMinutes: 5,
      distanceMetres: 320,
      pathConfidence: DataConfidence.placeholder,
      points: [_centralCourtyard, _sportAquatic],
      lightingNotes: 'Lighting on this route not yet confirmed.',
      steps: [
        RouteStep(
          instruction:
              'From the Central Courtyard, head north-west towards Gymnasium '
              'Road.',
        ),
        RouteStep(
          instruction:
              'The Sport and Aquatic Centre is on your left at 10 Gymnasium '
              'Road. Planetarium sessions run about every 20 minutes.',
        ),
      ],
    ),

    // ══════════════════════════════════════════════════════
    // From public transport
    // ══════════════════════════════════════════════════════
    WalkingRoute(
      id: 'metro-station-to-central-courtyard',
      fromId: 'metro-station',
      toId: 'central-courtyard',
      fromLabel: 'Macquarie University Metro Station',
      toLabel: 'Central Courtyard',
      walkingMinutes: 10,
      distanceMetres: 700,
      pathConfidence: DataConfidence.placeholder,
      points: [_metro, _centralCourtyard],
      lightingNotes:
          'Main campus walkways. Generally well lit, but not yet confirmed '
          'for the full route.',
      steps: [
        RouteStep(
          instruction:
              'Leave the Metro station and head north-west into the campus, '
              'away from Macquarie Centre.',
        ),
        RouteStep(
          instruction:
              'Follow University Avenue, then the main pedestrian walkways '
              'north-west through campus.',
        ),
        RouteStep(
          instruction:
              'Continue until the Central Courtyard opens up — registration '
              'and information points are here.',
        ),
      ],
    ),
  ];

  static WalkingRoute? byId(String id) {
    for (final r in all) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// All routes starting at [fromId].
  static List<WalkingRoute> from(String fromId) =>
      all.where((r) => r.fromId == fromId).toList();

  /// The route between [fromId] and [toId], or null if none is defined.
  static WalkingRoute? between(String fromId, String toId) {
    for (final r in all) {
      if (r.fromId == fromId && r.toId == toId) return r;
    }
    return null;
  }
}
