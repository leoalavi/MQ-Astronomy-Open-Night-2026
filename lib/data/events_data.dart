import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/models/data_confidence.dart';
import 'package:aon2026/models/event.dart';

/// The Astronomy Open Night 2026 programme.
///
/// ## Source
///
/// Every title, description, time, room and map reference below is transcribed
/// from the official Macquarie University programme:
/// `docs/source-materials/FSE26193_AON_2026_Program_and_Map_A3_FA_DIGITAL.pdf`
/// (pages 2 and 3). Nothing here is invented.
///
/// ## Where times are placeholders
///
/// Some programme entries give a start time but no end ("4.15pm start"), and a
/// few give no time at all. Those sessions are marked
/// [DataConfidence.placeholder] and end at the event close (10pm). They are
/// listed in `docs/data-sources.md` and rendered with a qualifier in the UI —
/// the app never states a finish time the organisers did not publish.
///
/// ## Liz's 2026-08-31 update (supersedes older programme data on conflict)
///
/// * Capture the Cosmos (17 Wally's Walk foyer) — "just open all night"; the
///   astrophotography-competition display Liz calls the "astrophotography
///   display". Now [TimingConfidence.fullEventConfirmed] → "Open all night".
///   (There is no SEPARATE "Astrophotography Display" entry in the official
///   source — it IS Capture the Cosmos — so none was invented.)
/// * Exhibitor / Exhibition Hall (14 SCO) — exact 4.15pm–10pm.
/// * Solar System Walk (Gymnasium Road) — "no set opening times", present
///   throughout: [TimingConfidence.openAllNight] → "Open all night", but never
///   a scheduled start/finish.
/// * The featured 17 WW G25 astro talk (5–5.45pm) already exists as
///   `featured-astrophotography` ("Astrophotography: The sky is your lab").
/// * Kids' space moved from Room 106 to Room 109 (Room 109 Kids' space is
///   VALID; the Room 109 Huntsman activity stays removed — see below).
///
/// ## Deliberate exclusion
///
/// **The Huntsman Telescope Exploratorium (Room 109, 1 Central Courtyard) is
/// intentionally absent.** It appears on page 2 of the supplied programme and
/// on the printed map, but the event organisers have confirmed it is no longer
/// going ahead. Do not re-add it when reconciling this file against the PDF —
/// `test/unit/huntsman_exclusion_test.dart` will fail if you do. That test is
/// there precisely because a future maintainer diffing against the official
/// programme would otherwise "fix" the omission.
abstract final class EventsData {
  /// Shared blurb printed above the short-talks timetable.
  static const String _shortTalksBlurb =
      'The Faculty of Science and Engineering presents a series of short talks '
      'by our academics and students. These talks are designed for the general '
      'public and amateur astronomers, showcasing a diverse range of topics in '
      'astronomy and physics.';

  static const String _bookingNote =
      'Seats must be pre-booked at the time of ticket purchase.';

  static final List<AonEvent> all = [
    ..._activities,
    ..._keynote,
    ..._featuredPresentations,
    ..._shortTalks,
  ];

  // ══════════════════════════════════════════════════════
  // Activities — PDF page 2
  // ══════════════════════════════════════════════════════
  static final List<AonEvent> _activities = [
    AonEvent(
      id: 'physics-magic-show',
      title: 'Physics magic show',
      description:
          'A live physics magic show in the Macquarie Theatre. Seats must be '
          'pre-booked at the time of ticket purchase.',
      category: EventCategory.activity,
      venueId: 'macquarie-theatre',
      mapReference: 'A',
      bookingRequired: true,
      bookingNote: _bookingNote,
      tags: ['physics', 'show', 'family'],
      sourceNote: 'Programme p.2 — "Magic show times: 5pm – 5.45pm, '
          '6.15pm – 7pm, 8.45pm – 9.30pm".',
      sessions: [
        EventSession(start: _t(17, 0), end: _t(17, 45)),
        EventSession(start: _t(18, 15), end: _t(19, 0)),
        EventSession(start: _t(20, 45), end: _t(21, 30)),
      ],
    ),
    AonEvent(
      id: 'destination-moon',
      title: 'Destination Moon with Fizzics Education',
      description: 'Discover the science required to reach the Moon.',
      category: EventCategory.activity,
      venueId: 'mason-theatre',
      mapReference: 'B',
      bookingRequired: true,
      bookingNote: _bookingNote,
      tags: ['moon', 'family', 'show'],
      sourceNote: 'Programme p.2 — "7.30pm – 8.15pm".',
      sessions: [EventSession(start: _t(19, 30), end: _t(20, 15))],
    ),
    AonEvent(
      id: 'chemistry-magic-show',
      title: 'Chemistry magic show',
      description:
          'A live chemistry magic show in the Mason Theatre. Seats must be '
          'pre-booked at the time of ticket purchase.',
      category: EventCategory.activity,
      venueId: 'mason-theatre',
      mapReference: 'B',
      bookingRequired: true,
      bookingNote: _bookingNote,
      tags: ['chemistry', 'show', 'family'],
      sourceNote:
          'Programme p.2 — "Magic show times: 5pm – 5.45pm, 6.15pm – 7pm".',
      sessions: [
        EventSession(start: _t(17, 0), end: _t(17, 45)),
        EventSession(start: _t(18, 15), end: _t(19, 0)),
      ],
    ),
    AonEvent(
      id: 'exhibition-hall',
      title: 'Exhibition Hall',
      description:
          'Our Exhibition Hall features a range of fun and exciting stalls '
          'from the local astronomy community. Here, you can chat about '
          'astronomy and science, connect with your local astronomy society, '
          'learn how to choose a telescope and discover much more.',
      category: EventCategory.activity,
      venueId: '14-sir-christopher-ondaatje-avenue',
      mapReference: 'D',
      // 'exhibitor' aliases Liz's wording ("Exhibitor Hall") so a search for it
      // finds this "Exhibition Hall" entry (program search matches tags).
      tags: ['exhibition', 'exhibitor', 'community', 'telescopes'],
      sourceNote: 'Liz 2026-08-31 — "Exhibitor Hall — 14 SCO Hall is open from '
          '4.15pm to 10 pm." Exact confirmed timing (supersedes the programme\'s '
          'no-time entry).',
      sessions: [
        // Liz published exact hours: 4.15pm–10pm.
        EventSession(start: _t(16, 15), end: _t(22, 0)),
      ],
    ),
    AonEvent(
      id: 'stories-across-worlds',
      title: 'Stories Across Worlds',
      description:
          'Explore our new experimental short film festival featuring works '
          'from the Archival Futures Collective.',
      category: EventCategory.activity,
      venueId: '14-sir-christopher-ondaatje-avenue',
      room: 'Theatre 100',
      mapReference: 'D',
      tags: ['film', 'arts'],
      sourceNote: 'Programme p.2 — "4.15pm start". No finish time published.',
      sessions: [
        EventSession(
          // Real published START (4.15pm); the end is a bound, not a fact.
          start: _t(16, 15),
          end: _t(22, 0),
          timing: TimingConfidence.startOnly,
          note: 'Starts 4.15pm. Finish time not published.',
        ),
      ],
    ),
    AonEvent(
      id: 'phenomenal-physics',
      title: 'Phenomenal physics and mathematical mysteries',
      description:
          'Experience and nurture your love for science and explore the magic '
          'and mysteries behind some of the coolest scientific phenomena by '
          'joining us as we demonstrate some funky experiments.',
      category: EventCategory.activity,
      venueId: '1-central-courtyard',
      room: 'Room 101',
      mapReference: 'E',
      tags: ['physics', 'maths', 'demonstration'],
      sourceNote: 'Programme p.2 — "4.15pm – 9.30pm".',
      sessions: [EventSession(start: _t(16, 15), end: _t(21, 30))],
    ),
    AonEvent(
      id: 'junior-science-academy',
      title: 'Space exploration with the Junior Science Academy',
      description:
          'Design the highest-flying rocket, create your own galaxy, or become '
          'a NASA flight director and create your own spacecraft.',
      category: EventCategory.activity,
      venueId: '1-central-courtyard',
      room: 'Room 105',
      mapReference: 'E',
      tags: ['kids', 'rockets', 'hands-on'],
      sourceNote: 'Programme p.2 — "4.15pm start". No finish time published.',
      sessions: [
        EventSession(
          // Real published START (4.15pm); the end is a bound, not a fact.
          start: _t(16, 15),
          end: _t(22, 0),
          timing: TimingConfidence.startOnly,
          note: 'Starts 4.15pm. Finish time not published.',
        ),
      ],
    ),
    AonEvent(
      id: 'kids-space',
      title: 'Kids’ space',
      description:
          'Bring your little scientists along to learn about space, planets, '
          'gravity and building – and discover some of the tricks of physics '
          'and a whole lot more. Children must at all times be accompanied by '
          'a parent or guardian while in this space.',
      category: EventCategory.activity,
      venueId: '1-central-courtyard',
      // Moved from Room 106 to Room 109 (Liz update 2026-08-31). Room 109 is the
      // room the cancelled Huntsman Exploratorium once occupied — that activity
      // stays removed; Kids' space simply now uses the room.
      room: 'Room 109',
      mapReference: 'E',
      tags: ['kids', 'family', 'hands-on'],
      sourceNote: 'Programme p.2 — "4.15pm start". No finish time published. '
          'Room updated to 109 per Liz 2026-08-31 (was 106).',
      sessions: [
        EventSession(
          // Real published START (4.15pm); the end is a bound, not a fact.
          start: _t(16, 15),
          end: _t(22, 0),
          timing: TimingConfidence.startOnly,
          note: 'Starts 4.15pm. Finish time not published.',
        ),
      ],
    ),
    AonEvent(
      id: 'fun-with-fizzics',
      title: 'Fun with Fizzics Education',
      description:
          'Come and discover how Earth and the Moon and Sun work in the solar '
          'system, with Fizzics Education.',
      category: EventCategory.activity,
      venueId: '1-central-courtyard',
      room: 'Room 107',
      mapReference: 'E',
      tags: ['kids', 'solar system', 'hands-on'],
      sourceNote: 'Programme p.2 — "5pm – 8pm".',
      sessions: [EventSession(start: _t(17, 0), end: _t(20, 0))],
    ),
    AonEvent(
      id: 'scientist-spotlight',
      title: 'Scientist spotlight',
      description:
          'Meet scientists from across astronomy, engineering, genetics, '
          'palaeontology and biology, and discover how they’re helping us '
          'better understand our world, our past and our universe.',
      category: EventCategory.activity,
      venueId: '1-central-courtyard',
      room: 'Room 108',
      mapReference: 'E',
      tags: ['meet the scientists', 'careers'],
      sourceNote: 'Programme p.2 — "4.15pm – 9pm".',
      sessions: [EventSession(start: _t(16, 15), end: _t(21, 0))],
    ),

    // ────────────────────────────────────────────────────
    // Room 109 — The Huntsman Telescope Exploratorium — is
    // deliberately NOT listed here. Cancelled by the event
    // organisers. See the class doc above.
    // ────────────────────────────────────────────────────

    AonEvent(
      id: 'vr-space-experience',
      title: 'Virtual reality space experience',
      description:
          'Float through the International Space Station or design your own '
          'solar system.',
      category: EventCategory.activity,
      venueId: '1-central-courtyard',
      room: 'Room 112',
      mapReference: 'E',
      tags: ['vr', 'hands-on', 'space station'],
      sourceNote: 'Programme p.2 — "4.15pm – 9pm".',
      sessions: [EventSession(start: _t(16, 15), end: _t(21, 0))],
    ),
    AonEvent(
      id: 'robotics-room',
      title: 'Robotics room',
      description:
          'Come and drive one of the world championship robots from the '
          'FIRST® Robotics Competition. This activity allows ages 5+ to earn '
          'their robotics driver’s licence in a fun and exciting hands-on '
          'activity.',
      category: EventCategory.activity,
      venueId: '1-central-courtyard',
      room: 'Rooms 114–115',
      mapReference: 'E',
      tags: ['robotics', 'kids', 'hands-on'],
      sourceNote: 'Programme p.2 — "4.15pm – 9.30pm".',
      sessions: [EventSession(start: _t(16, 15), end: _t(21, 30))],
    ),
    AonEvent(
      id: 'cosmic-arcade',
      title: 'Cosmic arcade',
      description:
          'Join us for a night of fun, filled with student-made games and '
          'challenges – get ready to shoot for the stars!',
      category: EventCategory.activity,
      venueId: '1-central-courtyard',
      room: 'Room 116',
      mapReference: 'E',
      tags: ['games', 'students', 'arcade'],
      sourceNote: 'Programme p.2 — "4.15pm – 9.30pm".',
      sessions: [EventSession(start: _t(16, 15), end: _t(21, 30))],
    ),
    AonEvent(
      id: 'planetariums',
      title: 'Planetariums',
      description:
          'Planetariums simulate the night sky and provide the opportunity to '
          'look up close at the motion of celestial objects, the surfaces of '
          'planets, deep sky objects, constellations and much more. '
          'Planetarium sessions are not dependent on the weather.',
      category: EventCategory.activity,
      venueId: 'sport-and-aquatic-centre',
      mapReference: 'F',
      tags: ['planetarium', 'all weather', 'family'],
      sourceNote:
          'Programme p.2 — "Sessions run about every 20 minutes, starting at '
          '4.15pm." No finish time published.',
      sessions: [
        EventSession(
          // Published start AND repeating cadence; finish not published, so
          // the end here is a bound rather than a fact.
          start: _t(16, 15),
          end: _t(22, 0),
          timing: TimingConfidence.repeating,
          note:
              'Sessions run about every 20 minutes from 4.15pm. Finish time '
              'not published.',
        ),
      ],
    ),
    AonEvent(
      id: 'telescope-park',
      title: 'Telescope Park',
      description:
          'Join us in exploring the cosmos and search for celestial objects '
          'such as planets, star clusters and nebulae. There will be an '
          'amazing array of telescopes from Macquarie University Observatory, '
          'local astronomy clubs and individual astronomers.',
      category: EventCategory.activity,
      venueId: 'astronomical-observatory',
      mapReference: 'G',
      tags: ['telescopes', 'observing', 'outdoors'],
      sourceNote:
          'Programme p.2 — "4.15pm – 9.30pm, twilight from 6.30pm".',
      sessions: [
        EventSession(
          start: _t(16, 15),
          end: _t(21, 30),
          note: 'Twilight from 6.30pm — best viewing is after dark.',
        ),
      ],
    ),
    AonEvent(
      id: 'laser-challenge',
      title: 'Laser Challenge',
      description:
          'Put your spy skills to the test in our kids’ laser challenge. Find '
          'your way through without touching any of the laser beams.',
      category: EventCategory.activity,
      venueId: '11-wallys-walk',
      mapReference: 'H',
      tags: ['kids', 'lasers', 'hands-on'],
      sourceNote: 'Programme p.2 — "4.15pm – 9.30pm".',
      sessions: [EventSession(start: _t(16, 15), end: _t(21, 30))],
    ),
    AonEvent(
      id: 'capture-the-cosmos',
      title: 'Capture the cosmos',
      description:
          'Explore the winning astrophotography images taken by YOU as part '
          'of our astrophotography competition. Come along and vote for the '
          'People’s Choice award.',
      category: EventCategory.activity,
      venueId: '17-wallys-walk',
      // Liz 2026-08-31: "Capture the Cosmos — 17 WW foyer is just open all
      // night." This astrophotography-competition DISPLAY (Liz's "astrophotography
      // display") lives in the 17 Wally's Walk foyer.
      room: 'Foyer',
      mapReference: 'I',
      tags: ['astrophotography', 'exhibition', 'display'],
      sourceNote: 'Liz 2026-08-31 — "17 WW foyer is just open all night". '
          'Confirmed full-event display (supersedes the programme\'s no-time entry).',
      sessions: [
        EventSession(
          // Open for the whole event, confirmed by Liz. start/end are the event
          // window; fullEventConfirmed renders as "Open all night".
          start: _t(16, 0),
          end: _t(22, 0),
          timing: TimingConfidence.fullEventConfirmed,
          note: 'Open all night (17 Wally’s Walk foyer).',
        ),
      ],
    ),
    AonEvent(
      id: 'laser-graffiti',
      title: 'Laser Graffiti',
      description:
          'Paint the campus with light as you try your hand at laser graffiti.',
      category: EventCategory.activity,
      venueId: 'central-courtyard',
      tags: ['lasers', 'outdoors', 'after dark'],
      sourceNote: 'Programme p.2 — "6.30pm – 9.30pm".',
      sessions: [EventSession(start: _t(18, 30), end: _t(21, 30))],
    ),
    AonEvent(
      id: 'laser-guide-star',
      title: 'Laser guide star',
      description:
          'Why would an astronomer want to stop the stars from twinkling? '
          'Join us in the Central Courtyard to find out more.',
      category: EventCategory.activity,
      venueId: 'central-courtyard',
      tags: ['lasers', 'outdoors', 'after dark'],
      sourceNote: 'Programme p.2 — "6.30pm – 10pm".',
      sessions: [EventSession(start: _t(18, 30), end: _t(22, 0))],
    ),
    AonEvent(
      id: 'solar-system-walk',
      title: 'Solar system walk',
      description:
          'Join us on a walk from the Central Courtyard to our Telescope Park, '
          'passing the planets of our solar system in our scale model. Every '
          'metre you walk represents 37.3 million kilometres. Think you can '
          'make it all the way?',
      category: EventCategory.activity,
      venueId: 'gymnasium-road',
      tags: ['walk', 'outdoors', 'scale model', 'family'],
      sourceNote: 'Liz 2026-08-31 — "Will go up on Gymnasium Road a few days '
          'before the event and taken down a few days after. It\'s outside so no '
          'set opening times." Available all night; no precise start/finish '
          'published, so classified openAllNight (not an exact session).',
      sessions: [
        EventSession(
          // Physically present the whole event, but Liz published NO set times.
          // openAllNight renders as "Open all night" and is available all
          // evening WITHOUT claiming a scheduled start/finish. start/end are the
          // event window (bounds only, never shown as a published session).
          start: _t(16, 0),
          end: _t(22, 0),
          timing: TimingConfidence.openAllNight,
          note: 'Open all night (outdoor scale model along Gymnasium Road). '
              'No set opening times.',
        ),
      ],
    ),
  ];

  // ══════════════════════════════════════════════════════
  // Keynote lecture — PDF page 3
  // ══════════════════════════════════════════════════════
  static final List<AonEvent> _keynote = [
    AonEvent(
      id: 'keynote-artemis',
      title: 'Artemis and beyond: Humankind’s future on the moon',
      description:
          'The Astronomy Open Night 2026 keynote lecture, presented by '
          'Professor Fred Watson AM.',
      category: EventCategory.keynote,
      venueId: 'macquarie-theatre',
      presenter: 'Professor Fred Watson AM',
      mapReference: 'A',
      tags: ['keynote', 'moon', 'artemis'],
      sourceNote: 'Programme p.3 — "Keynote lecture (7.30 pm – 8.15pm)".',
      sessions: [EventSession(start: _t(19, 30), end: _t(20, 15))],
    ),
  ];

  // ══════════════════════════════════════════════════════
  // Featured presentations — PDF page 3
  // 17 Wally's Walk, G25 Theatre (map reference I)
  // ══════════════════════════════════════════════════════
  static final List<AonEvent> _featuredPresentations = [
    AonEvent(
      id: 'featured-astrophotography',
      title: 'Astrophotography: The sky is your lab',
      description:
          'Following the announcement of the winners of our 2026 '
          'Astrophotography Competition, learn about astrophotography '
          'techniques and how we can use our own images to measure the '
          'universe.',
      category: EventCategory.featuredPresentation,
      venueId: '17-wallys-walk',
      room: 'G25 Theatre',
      mapReference: 'I',
      tags: ['astrophotography', 'competition'],
      sourceNote: 'Programme p.3 — "5pm – 5.45pm".',
      sessions: [EventSession(start: _t(17, 0), end: _t(17, 45))],
    ),
    AonEvent(
      id: 'featured-big-cosmic-qa',
      title: 'The Big Cosmic Q&A',
      description:
          'Join our fun and engaging new panel that gives young space '
          'explorers the chance to ask real experts anything about the '
          'universe.',
      category: EventCategory.featuredPresentation,
      venueId: '17-wallys-walk',
      room: 'G25 Theatre',
      mapReference: 'I',
      tags: ['panel', 'kids', 'q&a'],
      sourceNote: 'Programme p.3 — "6.15pm – 7pm".',
      sessions: [EventSession(start: _t(18, 15), end: _t(19, 0))],
    ),
    AonEvent(
      id: 'featured-engineering-astronomy',
      title: 'The engineering behind modern astronomy',
      description:
          'Learn how our engineers make big science possible on the global '
          'stage and gain insight into some of the cutting-edge technology '
          'being designed and built by Australian Astronomical Optics here at '
          'Macquarie University.',
      category: EventCategory.featuredPresentation,
      venueId: '17-wallys-walk',
      room: 'G25 Theatre',
      mapReference: 'I',
      tags: ['engineering', 'technology', 'AAO'],
      sourceNote: 'Programme p.3 — "7.30pm – 8.15pm".',
      sessions: [EventSession(start: _t(19, 30), end: _t(20, 15))],
    ),
  ];

  // ══════════════════════════════════════════════════════
  // Short talks — PDF page 3
  // 14 Sir Christopher Ondaatje Avenue (map reference D),
  // Theatre 3 and Theatre 4, 4.30pm – 8.45pm
  // ══════════════════════════════════════════════════════
  static final List<AonEvent> _shortTalks = [
    // ── Theatre 3 ──
    _talk('t3-pope', 'Galactic guesswork: Estimating everything from piano '
        'tuners to alien civilisations', 'Benjamin Pope', 'Theatre 3', 16, 30),
    _talk('t3-binkowski', 'Measuring the unknown: How uncertainty shapes our '
        'view of the universe', 'Karol Binkowski', 'Theatre 3', 17, 15),
    _talk('t3-pal', 'We are made of stardust', 'Harshit Pal', 'Theatre 3',
        18, 0),
    _talk('t3-gonzalez-bolivar', 'Space tech in your pocket: Cosmic innovation '
        'in everyday life', 'Miguel Angel Gonzalez Bolivar', 'Theatre 3',
        18, 45),
    _talk('t3-salvador-campe', 'Cosmic distance illusions: Galaxy evolution '
        'across time', 'Diego Ignacio Salvador Campe', 'Theatre 3', 19, 30),
    _talk('t3-andrych', 'Cosmic hide and seek: How we detect what space tries '
        'to hide', 'Kateryna Andrych', 'Theatre 3', 20, 15),

    // ── Theatre 4 ──
    _talk('t4-fava', 'So you like science at school – what now?',
        'Claudia Fava', 'Theatre 4', 16, 30),
    _talk('t4-ghosn', 'Space isn’t just for astronomers', 'Claudia Ghosn',
        'Theatre 4', 17, 15),
    _talk('t4-de-grijs', 'The sound of silence: Listening to the universe',
        'Richard de Grijs', 'Theatre 4', 18, 0),
    _talk('t4-raidani', 'Cosmic flashlights: Uncovering distant galaxies '
        'secrets', 'Arihant Raidani', 'Theatre 4', 18, 45),
    _talk('t4-terno', 'Not always wrong', 'Daniel Terno', 'Theatre 4', 19, 30),
    _talk('t4-white', 'Does time slow down at the edge of the universe?',
        'Ryan White', 'Theatre 4', 20, 15),
  ];

  /// Builds a short talk. Every short talk in the programme is a 30-minute
  /// slot in Theatre 3 or Theatre 4 at 14 Sir Christopher Ondaatje Avenue,
  /// so only the varying parts are passed in.
  static AonEvent _talk(
    String id,
    String title,
    String presenter,
    String room,
    int hour,
    int minute,
  ) {
    return AonEvent(
      id: id,
      title: title,
      description: _shortTalksBlurb,
      category: EventCategory.shortTalk,
      venueId: '14-sir-christopher-ondaatje-avenue',
      room: room,
      presenter: presenter,
      mapReference: 'D',
      tags: ['short talk', 'astronomy', 'physics'],
      sourceNote: 'Programme p.3 — short talks timetable.',
      sessions: [
        EventSession(
          start: _t(hour, minute),
          end: _t(hour, minute).add(const Duration(minutes: 30)),
        ),
      ],
    );
  }

  static DateTime _t(int hour, int minute) => EventInfo.at(hour, minute);

  static AonEvent? byId(String id) {
    for (final e in all) {
      if (e.id == id) return e;
    }
    return null;
  }
}
