import 'package:aon2026/models/passport_fact.dart';

/// The 9 passport learning moments — one per event venue.
///
/// DRAFTS: every fact ships `DataConfidence.placeholder` and is gated by the
/// publication policy (design §6) until the astronomy team signs off. The
/// `target` comments record the intended tier after review (design §7).
abstract final class PassportFactsData {
  static const List<PassportFact> all = [
    PassportFact(
      venueId: 'central-courtyard',
      activityLabel: 'Laser Guide Star',
      title: 'Why make an artificial star?',
      fact: 'Earth’s shifting atmosphere bends incoming starlight and '
          'blurs telescope images. Adaptive optics measures that distortion '
          'and changes optical surfaces in real time; laser guide stars '
          'provide bright reference points when the sky does not offer a '
          'suitable natural one nearby.',
      sourceRef: 'MQ-AON-2026-LGS', // target: derived
    ),
    PassportFact(
      venueId: 'astronomical-observatory',
      activityLabel: 'Telescope Park',
      title: 'A telescope is also a time machine',
      fact: 'Light takes time to travel, so a star 1,000 light-years away is '
          'seen as it was 1,000 years ago. Looking farther into space also '
          'means looking farther into the past.',
      // target: confirmed
    ),
    PassportFact(
      venueId: 'sport-and-aquatic-centre',
      activityLabel: 'Planetarium',
      title: 'A sky indoors',
      fact: 'A planetarium can simulate the night sky and guide an audience '
          'through planets, constellations, star clusters and nebulae even '
          'when weather hides the real sky outside.',
      sourceRef: 'MQ-AON-2026-PLANETARIUM', // target: derived
    ),
    PassportFact(
      venueId: '17-wallys-walk',
      activityLabel: 'Astrophotography',
      title: 'Pictures can become measurements',
      fact: 'Astronomical images are not only beautiful: measurements made '
          'from images can be used to investigate things such as lunar '
          'features, planetary motion and Earth’s rotation.',
      sourceRef: 'MQ-AON-2026-ASTROPHOTO', // target: derived
    ),
    PassportFact(
      venueId: 'mason-theatre',
      activityLabel: 'Chemistry Magic / Destination Moon',
      title: 'Stars carry chemical fingerprints',
      fact: 'Spectroscopy separates light by wavelength; characteristic '
          'patterns in a spectrum let astronomers identify atoms and '
          'molecules without physically sampling the star.',
      // target: confirmed
    ),
    PassportFact(
      venueId: 'macquarie-theatre',
      activityLabel: 'Physics Magic Show',
      title: 'Gravity can bend light',
      fact: 'A massive foreground object can deflect light from something '
          'farther away, producing gravitational-lensing magnification and '
          'distortion.',
      // target: confirmed
    ),
    PassportFact(
      venueId: '1-central-courtyard',
      activityLabel: 'Kids’ Space',
      title: 'Orbit is continuous free fall',
      fact: 'An orbiting spacecraft moves sideways fast enough that Earth’s '
          'curved surface keeps falling away beneath it while gravity '
          'continually pulls it downward.',
      // target: confirmed
    ),
    PassportFact(
      venueId: '11-wallys-walk',
      activityLabel: 'Laser Challenge',
      title: 'Why does a laser form such a tight beam?',
      fact: 'Laser light occupies a narrow range of wavelengths and has strong '
          'coherence, allowing it to remain highly directional compared with '
          'ordinary light sources.',
      // target: confirmed
    ),
    PassportFact(
      venueId: '14-sir-christopher-ondaatje-avenue',
      activityLabel: 'Exhibition Hall',
      title: 'Modern astronomy is also engineering',
      fact: 'Optics, detectors, electronics and software are what turn faint '
          'incoming light into measurements scientists can actually use.',
      sourceRef: 'AAO-MQ-INSTRUMENTATION', // target: derived
    ),
  ];

  /// Reviewer source references considered valid (design §5.1). The human
  /// registry lives in docs/passport-fact-sources.md; this set is the
  /// machine-checkable half so a test needn't parse Markdown.
  static const Set<String> sourceRegistry = {
    'MQ-AON-2026-LGS',
    'MQ-AON-2026-PLANETARIUM',
    'MQ-AON-2026-ASTROPHOTO',
    'AAO-MQ-INSTRUMENTATION',
  };

  static Set<String> get venueIds => all.map((f) => f.venueId).toSet();

  static PassportFact? byVenueId(String venueId) {
    for (final f in all) {
      if (f.venueId == venueId) return f;
    }
    return null;
  }
}
