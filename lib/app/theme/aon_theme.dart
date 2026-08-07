import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:aon2026/app/theme/aon_colors.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/app/theme/aon_typography.dart';

/// Builds the single application [ThemeData].
///
/// **There is intentionally no light theme.** MQ Journey ships light + dark and
/// follows the system setting. This app does not: the event runs from dusk to
/// 10pm, and a phone that flashes a white screen at someone standing at a
/// telescope eyepiece ruins their dark adaptation (and their neighbours').
/// Locking to dark is a product decision, not an unfinished one.
abstract final class AonTheme {
  static ThemeData build() {
    final textTheme = AonTypography.textTheme;

    const colorScheme = ColorScheme.dark(
      primary: AonColors.amber,
      onPrimary: AonColors.onAccent,
      primaryContainer: AonColors.amberDeep,
      onPrimaryContainer: AonColors.contentPrimary,
      secondary: AonColors.stellar,
      onSecondary: AonColors.onAccent,
      secondaryContainer: AonColors.stellarDeep,
      onSecondaryContainer: AonColors.contentPrimary,
      tertiary: AonColors.nebula,
      onTertiary: AonColors.onAccent,
      error: AonColors.error,
      onError: AonColors.onAccent,
      surface: AonColors.night900,
      onSurface: AonColors.contentPrimary,
      surfaceContainerHighest: AonColors.night800,
      onSurfaceVariant: AonColors.contentSecondary,
      outline: AonColors.night700,
      outlineVariant: AonColors.night700,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AonColors.night950,
      canvasColor: AonColors.night950,
      textTheme: textTheme,

      appBarTheme: AppBarTheme(
        backgroundColor: AonColors.night950,
        foregroundColor: AonColors.contentPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineSmall,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),

      cardTheme: CardThemeData(
        color: AonColors.night900,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AonSpacing.radiusMd),
          side: const BorderSide(color: AonColors.night700),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AonColors.amber,
          foregroundColor: AonColors.onAccent,
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
          foregroundColor: AonColors.contentPrimary,
          textStyle: textTheme.labelLarge,
          minimumSize: const Size(0, AonSpacing.minTapTarget),
          side: const BorderSide(color: AonColors.night600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AonSpacing.radius),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AonColors.amber,
          textStyle: textTheme.labelLarge,
          minimumSize: const Size(0, AonSpacing.minTapTarget),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AonColors.night800,
        selectedColor: AonColors.amber,
        // ChoiceChip resolves its selected background from
        // `secondarySelectedColor`, not `selectedColor` — leaving it at the
        // default produced a blue-grey fill with near-black label text, about
        // 2:1 contrast. Both must be set or the wayfinding chips fail WCAG.
        secondarySelectedColor: AonColors.amber,
        disabledColor: AonColors.night800,
        labelStyle: textTheme.labelMedium,
        // Applied to the label when a chip is selected.
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: AonColors.onAccent,
        ),
        checkmarkColor: AonColors.onAccent,
        side: const BorderSide(color: AonColors.night700),
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
        fillColor: AonColors.night900,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: AonColors.contentTertiary,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AonSpacing.space4,
          vertical: AonSpacing.space4,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AonSpacing.radius),
          borderSide: const BorderSide(color: AonColors.night700),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AonSpacing.radius),
          borderSide: const BorderSide(color: AonColors.night700),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AonSpacing.radius),
          borderSide: const BorderSide(color: AonColors.amber, width: 2),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AonColors.night900,
        indicatorColor: AonColors.amber,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? textTheme.labelSmall?.copyWith(color: AonColors.amber)
              : textTheme.labelSmall?.copyWith(
                  color: AonColors.contentSecondary,
                ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? const IconThemeData(
                  color: AonColors.onAccent,
                  size: AonSpacing.iconDefault,
                )
              : const IconThemeData(
                  color: AonColors.contentSecondary,
                  size: AonSpacing.iconDefault,
                ),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: AonColors.night700,
        thickness: 1,
        space: 1,
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AonColors.night900,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),

      listTileTheme: const ListTileThemeData(
        iconColor: AonColors.contentSecondary,
        textColor: AonColors.contentPrimary,
        minVerticalPadding: AonSpacing.space3,
      ),
    );
  }
}
