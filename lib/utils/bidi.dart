/// Bidirectional-text helpers.
///
/// The Astronomy programme is full of English proper nouns that never get
/// translated — "Macquarie Theatre", "17 Wally's Walk", "Fizzics Education".
/// In a Persian (RTL) screen these are left-to-right runs embedded in
/// right-to-left text, and the Unicode bidi algorithm resolves them against
/// whatever happens to sit next to them.
///
/// The visible failure is punctuation and digits drifting to the wrong end:
/// "Room 108, 1 Central Courtyard" can render as "1 Central Courtyard ,108
/// Room". Wrapping each foreign run in an *isolate* tells the algorithm to
/// resolve it independently of its surroundings, which fixes the drift without
/// forcing a direction on the whole string.
abstract final class Bidi {
  /// U+2068 FIRST STRONG ISOLATE — direction inferred from the first strong
  /// character in the run, which is what we want for names that may be either
  /// script.
  static const String _fsi = '\u2068';

  /// U+2069 POP DIRECTIONAL ISOLATE.
  static const String _pdi = '\u2069';

  /// Wraps [text] so it resolves as its own bidi run.
  ///
  /// Safe to apply unconditionally: in a left-to-right locale the isolate is
  /// a no-op, so call sites do not have to know the current direction.
  static String isolate(String? text) {
    if (text == null || text.isEmpty) return '';
    return '$_fsi$text$_pdi';
  }

  /// Joins parts with [separator], isolating each part.
  ///
  /// Used for the composed strings the app builds a lot of — "Room 108 ·
  /// 1 Central Courtyard", "5pm – 5.45pm · Macquarie Theatre" — where each
  /// segment has its own natural direction.
  static String joinIsolated(Iterable<String?> parts, {String separator = ' · '}) {
    final kept = parts.where((p) => p != null && p.isNotEmpty).cast<String>();
    return kept.map(isolate).join(separator);
  }
}
