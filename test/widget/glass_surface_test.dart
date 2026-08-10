import 'package:flutter/material.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_glass.dart';
import 'package:aon2026/widgets/glass_shader.dart';
import 'package:aon2026/widgets/glass_surface.dart';

Widget host({
  required Widget child,
  bool highContrast = false,
  bool disableAnimations = false,
}) {
  return MaterialApp(
    localizationsDelegates: AonL10n.localizationsDelegates,
    supportedLocales: AonL10n.supportedLocales,
    theme: ThemeData(brightness: Brightness.dark),
    home: MediaQuery(
      data: MediaQueryData(
        highContrast: highContrast,
        disableAnimations: disableAnimations,
      ),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  group('resolveGlassRenderMode', () {
    test('content is always solid', () {
      expect(
        resolveGlassRenderMode(
          variant: GlassVariant.content,
          highContrast: false,
          disableAnimations: false,
          shaderSupported: true,
        ),
        GlassRenderMode.solid,
      );
    });
    test('high contrast forces solid', () {
      expect(
        resolveGlassRenderMode(
          variant: GlassVariant.control,
          highContrast: true,
          disableAnimations: false,
          shaderSupported: true,
        ),
        GlassRenderMode.solid,
      );
    });
    test('reduce motion drops to frost', () {
      expect(
        resolveGlassRenderMode(
          variant: GlassVariant.control,
          highContrast: false,
          disableAnimations: true,
          shaderSupported: true,
        ),
        GlassRenderMode.frost,
      );
    });
    test('no shader support drops to frost', () {
      expect(
        resolveGlassRenderMode(
          variant: GlassVariant.bar,
          highContrast: false,
          disableAnimations: false,
          shaderSupported: false,
        ),
        GlassRenderMode.frost,
      );
    });
    test('supported + no a11y flags -> shader', () {
      expect(
        resolveGlassRenderMode(
          variant: GlassVariant.control,
          highContrast: false,
          disableAnimations: false,
          shaderSupported: true,
        ),
        GlassRenderMode.shader,
      );
    });
    test('allowShader:false forces frost even when supported', () {
      expect(
        resolveGlassRenderMode(
          variant: GlassVariant.control,
          highContrast: false,
          disableAnimations: false,
          shaderSupported: true,
          allowShader: false,
        ),
        GlassRenderMode.frost,
      );
    });
  });

  group(
    'GlassSurface tiers (Impeller off in tests -> frost, never shader)',
    () {
      testWidgets('content tier is solid - no BackdropFilter', (tester) async {
        await tester.pumpWidget(
          host(
            child: const GlassSurface(
              variant: GlassVariant.content,
              child: SizedBox(width: 100, height: 40),
            ),
          ),
        );
        expect(find.byType(BackdropFilter), findsNothing);
      });
      testWidgets('control tier renders a frost BackdropFilter', (
        tester,
      ) async {
        await tester.pumpWidget(
          host(
            child: const GlassSurface(
              variant: GlassVariant.control,
              child: SizedBox(width: 100, height: 40),
            ),
          ),
        );
        expect(find.byType(BackdropFilter), findsOneWidget);
      });
      testWidgets('high contrast forces solid (no BackdropFilter)', (
        tester,
      ) async {
        await tester.pumpWidget(
          host(
            highContrast: true,
            child: const GlassSurface(
              variant: GlassVariant.control,
              child: SizedBox(width: 100, height: 40),
            ),
          ),
        );
        expect(find.byType(BackdropFilter), findsNothing);
      });
    },
  );

  group('GlassShaderCache', () {
    test(
      'ensureLoaded never throws and is not ready without Impeller',
      () async {
        // The test harness has no Impeller, so the shader never loads; the load
        // must complete non-fatally and report not-ready (→ frost fallback).
        await GlassShaderCache.ensureLoaded();
        expect(GlassShaderCache.ready, isFalse);
      },
    );
  });

  group('AonGlass tokens', () {
    test('dark tint is the aon2026 night surface, content stays legible', () {
      expect(AonGlass.tint(true), AonPalette.dark.surfaceRaised);
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
