import 'package:flutter/widgets.dart';

import 'package:aon2026/app/theme/aon_colors.dart';

/// Design tokens for the Liquid Glass-inspired ("Glass UI layer") material.
///
/// Adapted from MQ Journey's `mq_glass.dart` (REUSE WITH MODIFICATION). The
/// numeric shader/frost tokens are carried over; the **tint is aon2026's night
/// surface** and values are dark-tuned (this app is dark-only). Owns the
/// aon2026 glass identity so the generic `GlassSurface` primitive stays free of
/// `AonColors`/`AonTheme` coupling.
abstract final class AonGlass {
  // Blur (sigma) for the non-shader frost fallback.
  static const double blurMd = 18;

  // Body opacity per rung. Thin enough that refraction shows through on the
  // shader path; near-opaque on the content tier so text never depends on the
  // backdrop.
  static double opacityRegular(bool isDark) => isDark ? 0.45 : 0.52;
  static const double opacityContent = 0.94;
  static const double opacityHighContrast = 0.96;

  // Border / shadow alpha.
  static double borderAlpha(bool isDark) => isDark ? 0.28 : 0.35;
  static double shadowAlpha(bool isDark) => isDark ? 0.35 : 0.14;

  // Default radii (geometry may still be overridden per surface).
  static const double radiusBar = 18;
  static const double radiusFloating = 22;

  // Shader params (logical/UV; converted to physical px in the shader path).
  static const double refractiveIndex = 1.6;
  static const double rimWidth = 42;
  static const double aberration = 0.05;
  static const double blurCoeff = 0.03;

  // Liquid-glass rim effects (0..1 strengths).
  static const double fresnel = 0.8;

  /// Strength of the physically-based (Snell) refraction march.
  static const double refractIntensity = 0.85;

  /// Base tint colour. aon2026 is dark-only; the light branch is retained for
  /// API symmetry with the reference but resolves to a night surface.
  static Color tint(bool isDark) =>
      isDark ? AonColors.night800 : AonColors.night900;
}
