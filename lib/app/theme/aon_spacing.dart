/// Spacing, radius and sizing tokens.
///
/// Adapted from MQ Journey's `mq_spacing.dart` (REUSE WITH MODIFICATION).
/// The 4pt scale is carried over unchanged; the tap-target and icon minimums
/// are **increased** because this app is used one-handed, outdoors, in the
/// dark, often by someone holding a child's hand.
abstract final class AonSpacing {
  // ── Spacing scale (4pt grid) ───────────────────────────
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double space8 = 32;
  static const double space10 = 40;
  static const double space12 = 48;
  static const double space16 = 64;

  // ── Border radius ──────────────────────────────────────
  static const double radiusSm = 6;
  static const double radius = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 18;
  static const double radiusXl = 24;
  static const double radiusFull = 999;

  /// Minimum interactive target. MQ Journey uses 48 (the Material floor);
  /// we use 56 — closer to the Apple/WCAG "comfortable" target — because
  /// mis-taps are much more likely in the dark while walking.
  static const double minTapTarget = 56;

  // ── Icon sizes ─────────────────────────────────────────
  static const double iconSm = 18;
  static const double iconMd = 22;
  static const double iconDefault = 26;
  static const double iconLg = 34;
  static const double iconXl = 44;
  static const double iconHero = 60;
}
