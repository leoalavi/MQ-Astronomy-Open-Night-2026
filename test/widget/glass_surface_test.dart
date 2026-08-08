import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/app/theme/aon_colors.dart';
import 'package:aon2026/app/theme/aon_glass.dart';
import 'package:aon2026/widgets/glass_shader.dart';

void main() {
  group('GlassShaderCache', () {
    test('ensureLoaded never throws and is not ready without Impeller', () async {
      // The test harness has no Impeller, so the shader never loads; the load
      // must complete non-fatally and report not-ready (→ frost fallback).
      await GlassShaderCache.ensureLoaded();
      expect(GlassShaderCache.ready, isFalse);
    });
  });

  group('AonGlass tokens', () {
    test('dark tint is the aon2026 night surface, content stays legible', () {
      expect(AonGlass.tint(true), AonColors.night800);
      expect(AonGlass.opacityContent, greaterThanOrEqualTo(0.94));
      expect(AonGlass.opacityHighContrast, greaterThanOrEqualTo(0.94));
    });

    test('regular (shader body) opacity is translucent enough to refract', () {
      expect(AonGlass.opacityRegular(true), lessThan(0.6));
      expect(AonGlass.opacityRegular(true), greaterThan(0.3));
    });

    test('shader tokens carried from the reference', () {
      expect(AonGlass.refractiveIndex, 1.6);
      expect(AonGlass.rimWidth, 42);
      expect(AonGlass.fresnel, 0.8);
      expect(AonGlass.refractIntensity, 0.85);
    });
  });
}
