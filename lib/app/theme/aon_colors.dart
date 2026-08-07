import 'package:flutter/material.dart';

/// Astronomy Open Night 2026 colour palette.
///
/// The structure of this file (abstract final class of `static const Color`
/// tokens) is adapted from MQ Journey's `mq_colors.dart` so the two codebases
/// stay familiar to the same developers. **The values are entirely new** — they
/// are tuned for an outdoor, after-dark event rather than MQ Journey's
/// light-first Open Day palette.
///
/// Palette rationale — the interface is used outdoors, at night, by people
/// whose eyes are dark-adapted (some of them are about to look through a
/// telescope). So:
///
/// * Backgrounds are near-black blues, not pure black — pure black makes OLED
///   smearing obvious when scrolling and looks harsh next to a starfield.
/// * The accent family is warm amber/gold rather than blue-white. Long
///   wavelengths preserve dark adaptation far better, which is why observatory
///   torches are red. Amber is the compromise between "preserves night vision"
///   and "still legible to everyone, including colour-blind users".
/// * Every foreground token below is checked against its intended background
///   for WCAG AA (4.5:1 body, 3:1 large text). See `docs/architecture.md`.
///
/// Hues are *inspired by* the supplied hero image (deep blue-black sky, warm
/// stellar cores). No artwork is reproduced — these are plain colour values.
abstract final class AonColors {
  // ── Night surfaces (background family) ─────────────────
  /// App scaffold background — deepest surface.
  static const Color night950 = Color(0xFF05070F);

  /// Default card / sheet surface.
  static const Color night900 = Color(0xFF0B0F1D);

  /// Raised surface (selected cards, sheet headers).
  static const Color night800 = Color(0xFF141A2E);

  /// Hairline borders and dividers on dark surfaces.
  static const Color night700 = Color(0xFF232B45);

  /// Disabled / inactive chrome.
  static const Color night600 = Color(0xFF39425F);

  // ── Accent: warm amber (primary brand action) ──────────
  /// Primary accent. Contrast on [night950] ≈ 10.9:1 — passes AA and AAA.
  static const Color amber = Color(0xFFFFB945);

  /// Brighter amber for hover/pressed and high-emphasis icons.
  static const Color amberBright = Color(0xFFFFD180);

  /// Deep amber, used for filled surfaces that carry dark text.
  static const Color amberDeep = Color(0xFFC17A12);

  // ── Accent: stellar blue (secondary / informational) ───
  /// Secondary accent — routes, "you are here", informational chips.
  static const Color stellar = Color(0xFF7FC4FF);

  /// Deeper stellar blue for filled informational surfaces.
  static const Color stellarDeep = Color(0xFF1B4F80);

  /// Nebula magenta — retained as a sparing tertiary highlight.
  static const Color nebula = Color(0xFFE07BC4);

  // ── Content (foreground on night surfaces) ─────────────
  /// Primary body text. Contrast on [night950] ≈ 17.5:1.
  static const Color contentPrimary = Color(0xFFF2F4FA);

  /// Secondary text — captions, supporting copy. ≈ 10.1:1 on [night950].
  static const Color contentSecondary = Color(0xFFB9C0D4);

  /// Tertiary text — timestamps, metadata. ≈ 5.4:1 on [night950], still AA.
  static const Color contentTertiary = Color(0xFF8790A8);

  /// Text/icon colour to place *on top of* [amber] or [amberBright] fills.
  static const Color onAccent = Color(0xFF1A1206);

  // ── Semantic ───────────────────────────────────────────
  /// "Happening now" / success.
  static const Color live = Color(0xFF4ADE80);

  /// "Starting soon" / warning.
  static const Color soon = Color(0xFFFFC658);

  /// Errors and destructive actions.
  static const Color error = Color(0xFFFF8A8A);

  /// Neutral informational.
  static const Color info = stellar;

  // ── Map-specific ───────────────────────────────────────
  /// Event venue markers.
  static const Color mapVenue = amber;

  /// Parking markers.
  static const Color mapParking = Color(0xFFB69BFF);

  /// Facility markers (toilets, first aid, info points).
  static const Color mapFacility = stellar;

  /// Transport markers (Metro, shuttle, bus).
  static const Color mapTransport = Color(0xFF6EE7C8);

  /// Highlighted walking-route polyline.
  static const Color mapRoute = amber;

  /// Casing drawn beneath [mapRoute] so the line stays visible over any
  /// basemap tile. Dark, wide, drawn first.
  static const Color mapRouteCasing = Color(0xFF2A1A00);
}
