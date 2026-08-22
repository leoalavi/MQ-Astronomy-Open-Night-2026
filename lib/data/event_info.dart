/// Top-level facts about the event itself.
///
/// Source: `docs/source-materials/FSE26193_AON_2026_Program_and_Map_A3_FA_DIGITAL.pdf`
/// — front page ("19 SEPTEMBER 2026 / 4PM – 10PM") and page 2 header
/// ("Astronomy Open Night activities (4 pm – 10pm)").
abstract final class EventInfo {
  static const String name = 'Astronomy Open Night';
  static const String year = '2026';
  static const String fullName = 'Astronomy Open Night 2026';

  static const String host = 'Macquarie University';
  static const String faculty = 'Faculty of Science and Engineering';

  /// Social handles printed on the programme.
  static const String socialHandle = '@MQPhysAstro';
  static const String hashtag = '#MQAstroOpen';

  /// The event date. Saturday 19 September 2026.
  static const int eventYear = 2026;
  static const int eventMonth = 9;
  static const int eventDay = 19;

  /// Doors open / event close, as local Sydney time.
  ///
  /// **Timezone note:** these are constructed as naive local `DateTime`s, not
  /// UTC. That is correct for the MVP because the app is used *on campus*, by
  /// people whose devices are on Sydney time, for a single-day event. If the
  /// app ever needs to show correct times to someone in another timezone, this
  /// is the place to introduce the `timezone` package and pin to
  /// `Australia/Sydney` — see `docs/architecture.md`.
  static DateTime get startsAt => at(16, 0);
  static DateTime get endsAt => at(22, 0);

  /// Builds a `DateTime` on the event date at the given local time.
  static DateTime at(int hour, [int minute = 0]) =>
      DateTime(eventYear, eventMonth, eventDay, hour, minute);

  /// A representative instant used to preview the app before event night.
  /// 7:00pm — busy enough that several things are running at once.
  static DateTime get previewInstant => at(19, 0);

  static const String cricosProvider = 'CRICOS Provider 00002J';
  static const String materialReference = 'FSE26193';

  // ── Attribution ──
  //
  // The two people who built the app. Single source of truth; rendered in the
  // Info credits and as a subtle Home footer line. Exact spelling — do not
  // alter. Kept as separate constants so the localised "Developed by A and B"
  // join adapts per language while the proper nouns never change.
  static const String developerPrimary = 'Leo Alavi';
  static const String developerSecondary = 'Mohammad Raouf Abedini';
}
