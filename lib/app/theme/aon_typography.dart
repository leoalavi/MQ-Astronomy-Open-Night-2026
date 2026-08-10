import 'package:flutter/material.dart';


/// Typography scale.
///
/// Adapted from MQ Journey's `mq_typography.dart`. Two deliberate changes for
/// outdoor night reading:
///
/// 1. **Every size is bumped up one step.** MQ Journey's `bodyMedium` is 14px;
///    ours is 16px, and `bodySmall` is 14 rather than 12. Nothing below 13px
///    exists in this scale — small text is unreadable on a dim, auto-brightened
///    screen at arm's length.
/// 2. **Line heights are looser** (1.45 for body vs Flutter's default ~1.2),
///    which measurably helps when the reader's eyes are dark-adapted.
///
/// Fonts remain the platform system sans (San Francisco / Roboto). These are
/// highly legible, already optimised for small sizes, and cost zero bundle
/// bytes. If Macquarie brand fonts are licensed for this project later, set
/// [_fontPrimary] and add the family to `pubspec.yaml`.
abstract final class AonTypography {
  static const String? _fontPrimary = null;

  /// The scale, rendered in [baseColor]. The colour is supplied by the theme
  /// rather than baked in, so the same scale serves light and dark.
  static TextTheme textThemeFor(Color baseColor) => _build(baseColor);

  static TextTheme _build(Color base) {
    return TextTheme(
      // Display — hero headline only.
      displayLarge: TextStyle(
        fontFamily: _fontPrimary,
        fontSize: 44,
        fontWeight: FontWeight.w800,
        color: base,
        height: 1.08,
        letterSpacing: -0.5,
      ),
      displayMedium: TextStyle(
        fontFamily: _fontPrimary,
        fontSize: 36,
        fontWeight: FontWeight.w700,
        color: base,
        height: 1.12,
        letterSpacing: -0.3,
      ),
      displaySmall: TextStyle(
        fontFamily: _fontPrimary,
        fontSize: 30,
        fontWeight: FontWeight.w700,
        color: base,
        height: 1.18,
      ),

      // Headline — screen and section titles.
      headlineLarge: TextStyle(
        fontFamily: _fontPrimary,
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: base,
        height: 1.25,
      ),
      headlineMedium: TextStyle(
        fontFamily: _fontPrimary,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: base,
        height: 1.3,
      ),
      headlineSmall: TextStyle(
        fontFamily: _fontPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: base,
        height: 1.35,
      ),

      // Title — card headers.
      titleLarge: TextStyle(
        fontFamily: _fontPrimary,
        fontSize: 19,
        fontWeight: FontWeight.w600,
        color: base,
        height: 1.35,
      ),
      titleMedium: TextStyle(
        fontFamily: _fontPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: base,
        height: 1.4,
      ),
      titleSmall: TextStyle(
        fontFamily: _fontPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: base,
        height: 1.4,
      ),

      // Body — descriptions and long-form copy.
      bodyLarge: TextStyle(
        fontFamily: _fontPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w400,
        color: base,
        height: 1.45,
      ),
      bodyMedium: TextStyle(
        fontFamily: _fontPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: base,
        height: 1.45,
      ),
      bodySmall: TextStyle(
        fontFamily: _fontPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: base,
        height: 1.4,
      ),

      // Label — buttons, chips, badges.
      labelLarge: TextStyle(
        fontFamily: _fontPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: base,
        letterSpacing: 0.1,
      ),
      labelMedium: TextStyle(
        fontFamily: _fontPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: base,
        letterSpacing: 0.2,
      ),
      labelSmall: TextStyle(
        fontFamily: _fontPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: base,
        letterSpacing: 0.4,
      ),
    );
  }
}
