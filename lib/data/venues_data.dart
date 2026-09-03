import 'package:aon2026/models/data_confidence.dart';
import 'package:aon2026/models/venue.dart';

/// The venue registry.
///
/// ## Sources
///
/// * **Names, map-legend letters (A–I), room numbers and facility lists** come
///   from the official programme and map:
///   `docs/source-materials/FSE26193_AON_2026_Program_and_Map_A3_FA_DIGITAL.pdf`.
/// * **Latitude/longitude** are copied from the MQ Journey campus building
///   dataset (`assets/data/buildings.json` in that repository), matched by
///   building name. Those are marked [DataConfidence.derived]: the coordinate
///   itself is verified campus data, but the *link* from an event venue to a
///   building record was made by us, not by the organisers.
/// * Anything the supplied materials do not state is
///   [DataConfidence.placeholder] with `latitude`/`longitude` left **null**.
///   We do not guess coordinates — a confidently-drawn pin in the wrong place
///   is worse at night than no pin at all.
///
/// See `docs/data-sources.md` for the full provenance table.
abstract final class VenuesData {
  static const List<Venue> all = [
    // ── Event venues (map legend A–I) ────────────────────
    Venue(
      id: 'macquarie-theatre',
      artworkX: 2258, artworkY: 1954, // official map: marker "A"
      buildingId: 'MQTH', campusX: 2140, campusY: 1954,
      name: 'Macquarie Theatre',
      category: VenueCategory.eventVenue,
      building: '21 Wally’s Walk',
      address: '21 Wally’s Walk',
      latitude: -33.7746334,
      longitude: 151.1122714,
      coordinateConfidence: DataConfidence.derived,
      mapReference: 'A',
      aliases: ['MQ Theatre', 'Keynote', 'Physics magic show',
        'تئاتر مکواری', 'سخنرانی کلیدی', 'نمایش فیزیک'],
      notes: 'Toilets available in this building.',
    ),
    Venue(
      id: 'mason-theatre',
      artworkX: 3046, artworkY: 1750, // official map: marker "B"
      name: 'Mason Theatre',
      category: VenueCategory.eventVenue,
      building: '14 Sir Christopher Ondaatje Avenue',
      address: '14 Sir Christopher Ondaatje Avenue',
      latitude: -33.773899,
      longitude: 151.114706,
      coordinateConfidence: DataConfidence.derived,
      mapReference: 'B',
      aliases: ['Chemistry magic show', 'Destination Moon',
        'تئاتر میسون', 'نمایش شیمی'],
      notes: 'Toilets available in this building.',
    ),
    Venue(
      id: 'central-courtyard',
      artworkX: 2718, artworkY: 1720, // official map: the labelled "Central Courtyard" block
      name: 'Central Courtyard',
      category: VenueCategory.eventVenue,
      address: 'Central Courtyard',
      latitude: -33.7733531,
      longitude: 151.1133796,
      coordinateConfidence: DataConfidence.derived,
      // NO mapReference. The official legend's "C" is *Food and drink, Central
      // Courtyard* — the activity, not the courtyard — and the artwork prints
      // that C disc over 1CC, which is where `food-and-drink` is now pinned.
      // The courtyard block itself carries no letter on the printed map, so
      // claiming one here would draw a second "C" the paper map does not have.
      mapReference: null,
      aliases: [
        'Food and drink',
        'Laser graffiti',
        'Laser guide star',
        'Registration',
        'حیاط مرکزی', 'مرکز حیاط', 'ثبت‌نام', 'اطلاعات', 'غذا',
      ],
      notes:
          'Open-air courtyard. Registration and information points, food and '
          'drink, and the evening laser activities are all here.',
    ),
    Venue(
      id: '14-sir-christopher-ondaatje-avenue',
      artworkX: 3150, artworkY: 1750, // official map: marker "D"
      buildingId: '14SCO', campusX: 2766, campusY: 1761,
      shortName: '14 Sir Christopher Ondaatje Ave',
      name: '14 Sir Christopher Ondaatje Avenue',
      category: VenueCategory.eventVenue,
      building: '14 Sir Christopher Ondaatje Avenue',
      address: '14 Sir Christopher Ondaatje Avenue',
      latitude: -33.773899,
      longitude: 151.114706,
      coordinateConfidence: DataConfidence.derived,
      mapReference: 'D',
      aliases: [
        '14 SCO',
        'Exhibition Hall',
        'Short talks',
        'Theatre 3',
        'Theatre 4',
        'Theatre 100',
        'سخنرانی‌های کوتاه', 'نمایشگاه', 'ارائه‌ها',
        'Mason Theatre',
      ],
      notes:
          'Houses the Exhibition Hall, Theatre 100, Theatre 3 and Theatre 4 '
          '(short talks), and Mason Theatre.',
    ),
    Venue(
      id: '1-central-courtyard',
      artworkX: 2830, artworkY: 1506, // official map: marker "E"
      buildingId: '1CC', campusX: 2547, campusY: 1618,
      name: '1 Central Courtyard',
      category: VenueCategory.eventVenue,
      building: '1 Central Courtyard',
      address: '1 Central Courtyard',
      latitude: -33.7738842,
      longitude: 151.1135164,
      coordinateConfidence: DataConfidence.derived,
      mapReference: 'E',
      aliases: ['1CC', 'The Hub', 'Kids’ space', 'Science demos',
        'فضای کودکان', 'کودکان', 'نمایش علمی'],
      notes:
          'Indoor activity rooms (101–116). Toilets available in this '
          'building.',
    ),
    Venue(
      id: 'sport-and-aquatic-centre',
      artworkX: 1950, artworkY: 1326, // official map: marker "F"
      buildingId: 'SPORT', campusX: 1637, campusY: 1289,
      shortName: 'Sport & Aquatic Centre',
      name: 'Macquarie University Sport and Aquatic Centre',
      category: VenueCategory.eventVenue,
      building: 'Macquarie University Sport and Aquatic Centre',
      address: '10 Gymnasium Road',
      latitude: -33.7726489,
      longitude: 151.1105693,
      coordinateConfidence: DataConfidence.derived,
      mapReference: 'F',
      aliases: ['MUSAC', 'Planetariums', 'Sport & Aquatic Centre',
        'سیاره‌نما', 'آسمان‌نما', 'پلنتاریوم', 'ورزشی'],
    ),
    Venue(
      id: 'astronomical-observatory',
      artworkX: 1982, artworkY: 566, // official map: marker "G"
      buildingId: 'OBS', campusX: 1745, campusY: 480,
      shortName: 'Observatory',
      name: 'Macquarie University Astronomical Observatory',
      category: VenueCategory.eventVenue,
      building: 'Macquarie University Observatory',
      address: '5 Gymnasium Road',
      latitude: -33.7703261,
      longitude: 151.1111248,
      coordinateConfidence: DataConfidence.derived,
      mapReference: 'G',
      aliases: ['Telescope Park', 'Observatory', 'Telescopes',
        'رصدخانه', 'تلسکوپ', 'رصد', 'پارک تلسکوپ'],
      notes:
          'At the northern end of campus. Bring a jacket — it is open ground.',
    ),
    Venue(
      id: '11-wallys-walk',
      artworkX: 3126, artworkY: 1950, // official map: marker "H"
      buildingId: '11WW', campusX: 2987, campusY: 1937,
      name: '11 Wally’s Walk',
      category: VenueCategory.eventVenue,
      building: '11 Wally’s Walk',
      address: '11 Wally’s Walk',
      latitude: -33.7746267,
      longitude: 151.1151193,
      coordinateConfidence: DataConfidence.derived,
      mapReference: 'H',
      aliases: ['11WW', 'Laser Challenge', 'چالش لیزری', 'لیزر'],
    ),
    Venue(
      id: '17-wallys-walk',
      artworkX: 2626, artworkY: 1958, // official map: marker "I"
      buildingId: '17WW', campusX: 2516, campusY: 1883,
      name: '17 Wally’s Walk',
      category: VenueCategory.eventVenue,
      building: '17 Wally’s Walk',
      address: '17 Wally’s Walk',
      latitude: -33.7748805,
      longitude: 151.1133652,
      coordinateConfidence: DataConfidence.derived,
      mapReference: 'I',
      aliases: [
        '17WW',
        'G25 Theatre',
        'Astrophotography Exhibition',
        'Capture the cosmos',
        'Featured presentations',
      ],
      notes: 'Featured presentations are in the G25 Theatre.',
    ),

    // ── Route-based venue ────────────────────────────────
    Venue(
      id: 'gymnasium-road',
      name: 'Gymnasium Road',
      category: VenueCategory.other,
      address: 'Gymnasium Road',
      // PLACEHOLDER: this is a road, not a point. The Solar system walk runs
      // its length, from the Central Courtyard to the Observatory. A single
      // marker would be misleading, so it has none until a path is supplied.
      mapReference: null,
      aliases: ['Solar system walk'],
      notes:
          'The Solar system walk follows Gymnasium Road from the Central '
          'Courtyard to the Telescope Park at the Observatory.',
    ),

    // ── Registration and information (map legend 1, 2, 3) ─
    Venue(
      id: 'registration-point',
      artworkX: 2894, artworkY: 1665, // official map: marker "1"
      shortName: 'Registration',
      name: 'Registration point',
      aliases: ['ثبت‌نام', 'باجه ثبت‌نام'],
      category: VenueCategory.registration,
      building: 'Central Courtyard',
      latitude: -33.7733531,
      longitude: 151.1133796,
      // PLACEHOLDER: the map marks this as point "1" inside the Central
      // Courtyard. We have the courtyard's coordinate but not the point's.
      coordinateConfidence: DataConfidence.placeholder,
      mapReference: '1',
      notes: 'Marked as point 1 on the official map, in the Central Courtyard.',
    ),
    Venue(
      id: 'information-point-2',
      artworkX: 2907, artworkY: 1857, // official map: marker "2"
      name: 'Information point 2',
      aliases: ['اطلاعات', 'باجه اطلاعات', 'راهنما'],
      category: VenueCategory.informationPoint,
      building: 'Central Courtyard',
      latitude: -33.7733531,
      longitude: 151.1133796,
      coordinateConfidence: DataConfidence.placeholder,
      mapReference: '2',
      notes: 'Marked as point 2 on the official map, in the Central Courtyard.',
    ),
    Venue(
      id: 'information-point-3',
      artworkX: 2624, artworkY: 1665, // official map: marker "3"
      name: 'Information point 3',
      category: VenueCategory.informationPoint,
      building: 'Central Courtyard',
      latitude: -33.7733531,
      longitude: 151.1133796,
      coordinateConfidence: DataConfidence.placeholder,
      mapReference: '3',
      notes: 'Marked as point 3 on the official map, in the Central Courtyard.',
    ),

    // ── Facilities ───────────────────────────────────────
    // The programme states *which buildings* have toilets, not where in them.
    // Each entry therefore carries its building's coordinate, marked derived.
    Venue(
      id: 'toilets-macquarie-theatre',
      artworkX: 2338, artworkY: 1949, // official map: marker "T"
      name: 'Toilets — Macquarie Theatre',
      aliases: ['Toilets', 'توالت', 'دستشویی', 'سرویس بهداشتی'],
      category: VenueCategory.toilets,
      building: 'Macquarie Theatre',
      latitude: -33.7746334,
      longitude: 151.1122714,
      coordinateConfidence: DataConfidence.derived,
      notes: 'Building-level location. Follow signage inside.',
    ),
    Venue(
      id: 'toilets-1-central-courtyard',
      artworkX: 2591, artworkY: 1416, // official map: marker "T"
      name: 'Toilets — 1 Central Courtyard',
      aliases: ['Toilets', 'توالت', 'دستشویی', 'سرویس بهداشتی'],
      category: VenueCategory.toilets,
      building: '1 Central Courtyard',
      latitude: -33.7738842,
      longitude: 151.1135164,
      coordinateConfidence: DataConfidence.derived,
      notes: 'Building-level location. Follow signage inside.',
    ),
    Venue(
      id: 'toilets-mason-theatre',
      artworkX: 3006, artworkY: 1665, // official map: marker "T"
      name: 'Toilets — Mason Theatre',
      aliases: ['Toilets', 'توالت', 'دستشویی', 'سرویس بهداشتی'],
      category: VenueCategory.toilets,
      building: 'Mason Theatre',
      latitude: -33.773899,
      longitude: 151.114706,
      coordinateConfidence: DataConfidence.derived,
      notes: 'Building-level location. Follow signage inside.',
    ),
    Venue(
      id: 'food-and-drink',
      artworkX: 2594, artworkY: 1506, // official map: marker "C"
      name: 'Food and drink',
      aliases: ['Food', 'غذا', 'خوراکی', 'نوشیدنی', 'کافه'],
      category: VenueCategory.foodAndDrink,
      building: 'Central Courtyard',
      latitude: -33.7733531,
      longitude: 151.1133796,
      coordinateConfidence: DataConfidence.derived,
      mapReference: 'C',
    ),

    // ── Transport ────────────────────────────────────────
    Venue(
      id: 'metro-station',
      shortName: 'Metro Station',
      name: 'Macquarie University Metro Station',
      category: VenueCategory.metro,
      address: 'Herring Road / University Avenue',
      // PLACEHOLDER: approximated from the adjacent "Macquarie University Stn"
      // bike-rack record in the MQ Journey dataset. Close, but not the station
      // entrance. Verify before the event.
      latitude: -33.7768086,
      longitude: 151.1175848,
      coordinateConfidence: DataConfidence.placeholder,
      aliases: ['Metro', 'Train', 'Macquarie University Station',
        'مترو', 'ایستگاه مترو', 'قطار'],
      notes:
          'Sydney Metro. The station sits at the south-eastern corner of '
          'campus, next to Macquarie Centre.',
    ),
    Venue(
      id: 'shuttle-stop',
      shortName: 'Shuttle bus',
      name: 'Complimentary shuttle bus',
      category: VenueCategory.shuttleStop,
      // PLACEHOLDER: the map legend lists a complimentary shuttle bus, but no
      // stop locations, route or timetable are given in the supplied material.
      aliases: ['Shuttle', 'Free bus', 'شاتل', 'اتوبوس رایگان'],
      // No note: stop locations/timetable are unconfirmed, so an unconfirmed
      // placeholder line is omitted rather than shown.
    ),
    Venue(
      id: 'bus-stop',
      shortName: 'Bus stop',
      name: 'Transport NSW bus stop',
      category: VenueCategory.busStop,
      // PLACEHOLDER: marked on the map legend without a listed location.
      aliases: ['Bus', 'اتوبوس', 'ایستگاه اتوبوس'],
      // No note: exact stop locations are unconfirmed, so no placeholder line.
    ),
  ];

  /// Venues that appear in the programme as event locations.
  static List<Venue> get eventVenues =>
      all.where((v) => v.category == VenueCategory.eventVenue).toList();

  static Venue? byId(String id) {
    for (final v in all) {
      if (v.id == id) return v;
    }
    return null;
  }
}
