/// How trustworthy a given piece of data is.
///
/// The brief was explicit: *do not invent event times or locations, and clearly
/// distinguish confirmed information from placeholders.* Rather than tracking
/// that in a spreadsheet somewhere, it is a field on the data itself, so the UI
/// can render an "approximate location" badge and tests can assert that nothing
/// user-facing silently presents a guess as fact.
enum DataConfidence {
  /// Taken verbatim from the official Macquarie University event materials
  /// (the AON 2026 Program & Map PDF in `docs/source-materials/`).
  confirmed,

  /// Sourced from the MQ Journey campus building dataset. The building and its
  /// coordinates are real and verified, but the *event's* use of it is inferred
  /// by name-matching the programme against that dataset.
  derived,

  /// Not available in any supplied source. The value is a stand-in and MUST be
  /// replaced before the event. Anything marked this way should be visibly
  /// flagged in the UI and listed in `docs/data-sources.md`.
  placeholder,
}

extension DataConfidenceX on DataConfidence {
  /// Whether this value is safe to present without qualification.
  bool get isReliable => this != DataConfidence.placeholder;

  String get label => switch (this) {
    DataConfidence.confirmed => 'Confirmed',
    DataConfidence.derived => 'Derived from campus data',
    DataConfidence.placeholder => 'Approximate — to be confirmed',
  };
}
