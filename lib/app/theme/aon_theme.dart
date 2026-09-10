import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/app/theme/aon_typography.dart';

/// Builds the application [ThemeData] for a given brightness.
///
/// Dark remains the **recommended** experience — the event runs from dusk to
/// 10pm and a bright screen beside a telescope spoils night vision — so it is
/// the event config's default. But light is a fully supported, deliberately
/// designed theme, not an inversion: see [AonPalette].
///
/// Every colour comes from the [AonPalette] extension, which is attached to
/// the returned theme. Widgets read it through `context.aon`, so a theme
/// switch repaints them with no restart and no manual plumbing.
abstract final class AonTheme {
  /// The dark (default) theme.
  static ThemeData build() => forBrightness(Brightness.dark);

  static ThemeData light() => forBrightness(Brightness.light);

  static ThemeData forBrightness(Brightness brightness) {
    final palette = AonPalette.of(brightness);
    // CanvasKit otherwise fetches Persian fallback glyphs from Google before
    // consent. Bundle the fallback and keep native system typography unchanged.
    final textTheme = AonTypography.textThemeFor(palette.contentPrimary).apply(
      fontFamilyFallback: kIsWeb ? const ['NotoSansArabic'] : null,
    );

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: palette.accent,
      onPrimary: palette.onAccent,
      primaryContainer: palette.accentDeep,
      onPrimaryContainer: palette.contentPrimary,
      secondary: palette.info,
      onSecondary: palette.onAccent,
      secondaryContainer: palette.infoDeep,
      onSecondaryContainer: palette.contentPrimary,
      tertiary: palette.tertiary,
      onTertiary: palette.onAccent,
      error: palette.error,
      onError: palette.onAccent,
      surface: palette.surface,
      onSurface: palette.contentPrimary,
      surfaceContainerHighest: palette.surfaceRaised,
      onSurfaceVariant: palette.contentSecondary,
      outline: palette.border,
      outlineVariant: palette.border,
    );

    return ThemeData(
      fontFamilyFallback: kIsWeb ? const ['NotoSansArabic'] : null,
      useMaterial3: true,
      brightness: brightness,
      extensions: <ThemeExtension<dynamic>>[palette],
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.surfaceBase,
      canvasColor: palette.surfaceBase,
      textTheme: textTheme,

      appBarTheme: AppBarTheme(
        backgroundColor: palette.surfaceBase,
        foregroundColor: palette.contentPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineSmall,
        systemOverlayStyle: brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),

      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AonSpacing.radiusMd),
          side: BorderSide(color: palette.border),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: palette.onAccent,
          textStyle: textTheme.labelLarge,
          minimumSize: const Size(0, AonSpacing.minTapTarget),
          padding: const EdgeInsets.symmetric(horizontal: AonSpacing.space5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AonSpacing.radius),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.contentPrimary,
          textStyle: textTheme.labelLarge,
          minimumSize: const Size(0, AonSpacing.minTapTarget),
          side: BorderSide(color: palette.borderStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AonSpacing.radius),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.accent,
          textStyle: textTheme.labelLarge,
          minimumSize: const Size(0, AonSpacing.minTapTarget),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: palette.surfaceRaised,
        selectedColor: palette.accent,
        // ChoiceChip resolves its selected background from
        // `secondarySelectedColor`, not `selectedColor` — leaving it at the
        // default produced a blue-grey fill with near-black label text, about
        // 2:1 contrast. Both must be set or the wayfinding chips fail WCAG.
        secondarySelectedColor: palette.accent,
        disabledColor: palette.surfaceRaised,
        labelStyle: textTheme.labelMedium,
        // Applied to the label when a chip is selected.
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: palette.onAccent,
        ),
        checkmarkColor: palette.onAccent,
        side: BorderSide(color: palette.border),
        padding: const EdgeInsets.symmetric(
          horizontal: AonSpacing.space3,
          vertical: AonSpacing.space2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AonSpacing.radiusFull),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: palette.contentTertiary,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AonSpacing.space4,
          vertical: AonSpacing.space4,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AonSpacing.radius),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AonSpacing.radius),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AonSpacing.radius),
          borderSide: BorderSide(color: palette.accent, width: 2),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surface,
        indicatorColor: palette.accent,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? textTheme.labelSmall?.copyWith(color: palette.accent)
              : textTheme.labelSmall?.copyWith(
                  color: palette.contentSecondary,
                ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? IconThemeData(
                  color: palette.onAccent,
                  size: AonSpacing.iconDefault,
                )
              : IconThemeData(
                  color: palette.contentSecondary,
                  size: AonSpacing.iconDefault,
                ),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: palette.border,
        thickness: 1,
        space: 1,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),

      listTileTheme: ListTileThemeData(
        iconColor: palette.contentSecondary,
        textColor: palette.contentPrimary,
        minVerticalPadding: AonSpacing.space3,
      ),
    );
  }
}
