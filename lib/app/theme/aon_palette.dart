import 'package:flutter/material.dart';

/// The app's semantic colour palette, resolved per brightness.
///
/// ## Why a ThemeExtension
///
/// The app previously read colours from `AonColors`, a set of `static const`
/// tokens. That works perfectly for one theme and cannot work for two: a
/// `static const` cannot know whether the app is in light or dark mode. Adding
/// a light theme therefore meant moving every colour behind something that
/// resolves from the `BuildContext`.
///
/// `ThemeExtension` is the right mechanism rather than a custom InheritedWidget:
/// it rides on `ThemeData`, so it participates in `MaterialApp`'s theme
/// animation, survives `Theme.of` overrides, and switches automatically when
/// `themeMode` changes — no restart, no manual plumbing.
///
/// ## Naming
///
/// The tokens are named for their **role**, not their appearance. The old names
/// (`night950`, `night900`) describe a dark surface and would be actively
/// misleading in the light theme, where the same role is a near-white. So
/// `night950` became [surfaceBase], `night700` became [border], and so on.
///
/// ## The light theme is designed, not inverted
///
/// Inverting the dark palette produces muddy, low-chroma colours and — worse —
/// an amber accent that fails contrast on white (#FFB945 on white is ~1.9:1).
/// The light theme therefore uses its **own** accent family: deep amber for
/// primary, deep blue for informational, with white text on the accent fills.
/// Every foreground token below was chosen against its intended background to
/// clear WCAG AA (4.5:1 body, 3:1 large text); the ratios are noted inline.
@immutable
class AonPalette extends ThemeExtension<AonPalette> {
  const AonPalette({
    required this.brightness,
    required this.surfaceBase,
    required this.surface,
    required this.surfaceRaised,
    required this.border,
    required this.borderStrong,
    required this.accent,
    required this.accentBright,
    required this.accentDeep,
    required this.onAccent,
    required this.info,
    required this.infoDeep,
    required this.tertiary,
    required this.contentPrimary,
    required this.contentSecondary,
    required this.contentTertiary,
    required this.live,
    required this.soon,
    required this.error,
    required this.mapVenue,
    required this.mapParking,
    required this.mapFacility,
    required this.mapTransport,
    required this.mapRoute,
    required this.mapRouteCasing,
  });

  final Brightness brightness;

  bool get isDark => brightness == Brightness.dark;

  // ── Surfaces ───────────────────────────────────────────
  /// Scaffold background — the deepest/plainest surface.
  final Color surfaceBase;

  /// Cards, sheets, dialogs.
  final Color surface;

  /// Raised surface — selected chips, sheet headers, skeletons.
  final Color surfaceRaised;

  /// Hairline borders and dividers.
  final Color border;

  /// Stronger border / disabled chrome.
  final Color borderStrong;

  // ── Accent ─────────────────────────────────────────────
  /// Primary action colour.
  final Color accent;

  /// Higher-emphasis variant (pressed, active icons).
  final Color accentBright;

  /// Filled-surface variant.
  final Color accentDeep;

  /// Foreground placed **on top of** [accent] fills.
  final Color onAccent;

  // ── Secondary / informational ──────────────────────────
  final Color info;
  final Color infoDeep;

  /// Sparing tertiary highlight (nebula magenta family).
  final Color tertiary;

  // ── Content ────────────────────────────────────────────
  final Color contentPrimary;
  final Color contentSecondary;
  final Color contentTertiary;

  // ── Semantic ───────────────────────────────────────────
  /// "Happening now" / success.
  final Color live;

  /// "Starting soon" / warning / unconfirmed data.
  final Color soon;

  final Color error;

  // ── Map ────────────────────────────────────────────────
  final Color mapVenue;
  final Color mapParking;
  final Color mapFacility;
  final Color mapTransport;
  final Color mapRoute;

  /// Casing drawn beneath [mapRoute] so the line stays legible over any
  /// basemap tile. Dark under a bright line, light under a dark one.
  final Color mapRouteCasing;

  // ══════════════════════════════════════════════════════
  // Dark — the Astronomy identity. Values unchanged from the
  // original AonColors, so the night look is byte-identical.
  // ══════════════════════════════════════════════════════
  static const AonPalette dark = AonPalette(
    brightness: Brightness.dark,

    // Near-black blues rather than pure black: pure black makes OLED smearing
    // obvious when scrolling and looks harsh beside a starfield.
    surfaceBase: Color(0xFF05070F),
    surface: Color(0xFF0B0F1D),
    surfaceRaised: Color(0xFF141A2E),
    border: Color(0xFF232B45),
    borderStrong: Color(0xFF39425F),

    // Warm amber, not blue-white: long wavelengths preserve dark adaptation,
    // which is why observatory torches are red. 10.9:1 on surfaceBase.
    accent: Color(0xFFFFB945),
    accentBright: Color(0xFFFFD180),
    accentDeep: Color(0xFFC17A12),
    onAccent: Color(0xFF1A1206),

    info: Color(0xFF7FC4FF),
    infoDeep: Color(0xFF1B4F80),
    tertiary: Color(0xFFE07BC4),

    contentPrimary: Color(0xFFF2F4FA), // 17.5:1
    contentSecondary: Color(0xFFB9C0D4), // 10.1:1
    contentTertiary: Color(0xFF8790A8), // 5.4:1

    live: Color(0xFF4ADE80),
    soon: Color(0xFFFFC658),
    error: Color(0xFFFF8A8A),

    mapVenue: Color(0xFFFFB945),
    mapParking: Color(0xFFB69BFF),
    mapFacility: Color(0xFF7FC4FF),
    mapTransport: Color(0xFF6EE7C8),
    mapRoute: Color(0xFFFFB945),
    mapRouteCasing: Color(0xFF2A1A00),
  );

  // ══════════════════════════════════════════════════════
  // Light — a designed daytime companion, not an inversion.
  // ══════════════════════════════════════════════════════
  static const AonPalette light = AonPalette(
    brightness: Brightness.light,

    // Cool off-whites carrying a trace of the night palette's blue, so the two
    // themes feel like one product. Not pure white — less glare, and it lets
    // white cards sit above the background.
    surfaceBase: Color(0xFFF6F8FC),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFEBEFF8),
    border: Color(0xFFD3DAE8),
    borderStrong: Color(0xFF9AA4BA),

    // The dark theme's #FFB945 is ~1.9:1 on white and unusable. Light mode
    // gets its own deep-amber accent: 5.5:1 on white, and it still reads as
    // the same warm brand colour.
    accent: Color(0xFF9A5B00),
    accentBright: Color(0xFF7A4700),
    accentDeep: Color(0xFFFFE8C2),
    onAccent: Color(0xFFFFFFFF),

    info: Color(0xFF0B5FA5), // 5.9:1 on white
    infoDeep: Color(0xFFD7E8F7),
    tertiary: Color(0xFFA0246F), // 6.4:1 on white

    contentPrimary: Color(0xFF131722), // 16.1:1 on surfaceBase
    contentSecondary: Color(0xFF414A5E), // 8.9:1
    contentTertiary: Color(0xFF5D6678), // 5.8:1 — still AA for body text

    live: Color(0xFF157F3C), // 4.9:1
    soon: Color(0xFF8A5200), // 6.1:1 — amber warnings must darken on light
    error: Color(0xFFB3261E), // 5.9:1

    mapVenue: Color(0xFF9A5B00),
    mapParking: Color(0xFF6D3FD4),
    mapFacility: Color(0xFF0B5FA5),
    mapTransport: Color(0xFF05715C),
    mapRoute: Color(0xFF9A5B00),
    // A dark line over light tiles needs a light casing, not a dark one.
    mapRouteCasing: Color(0xFFFFFFFF),
  );

  static AonPalette of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  @override
  AonPalette copyWith({
    Brightness? brightness,
    Color? surfaceBase,
    Color? surface,
    Color? surfaceRaised,
    Color? border,
    Color? borderStrong,
    Color? accent,
    Color? accentBright,
    Color? accentDeep,
    Color? onAccent,
    Color? info,
    Color? infoDeep,
    Color? tertiary,
    Color? contentPrimary,
    Color? contentSecondary,
    Color? contentTertiary,
    Color? live,
    Color? soon,
    Color? error,
    Color? mapVenue,
    Color? mapParking,
    Color? mapFacility,
    Color? mapTransport,
    Color? mapRoute,
    Color? mapRouteCasing,
  }) {
    return AonPalette(
      brightness: brightness ?? this.brightness,
      surfaceBase: surfaceBase ?? this.surfaceBase,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      accent: accent ?? this.accent,
      accentBright: accentBright ?? this.accentBright,
      accentDeep: accentDeep ?? this.accentDeep,
      onAccent: onAccent ?? this.onAccent,
      info: info ?? this.info,
      infoDeep: infoDeep ?? this.infoDeep,
      tertiary: tertiary ?? this.tertiary,
      contentPrimary: contentPrimary ?? this.contentPrimary,
      contentSecondary: contentSecondary ?? this.contentSecondary,
      contentTertiary: contentTertiary ?? this.contentTertiary,
      live: live ?? this.live,
      soon: soon ?? this.soon,
      error: error ?? this.error,
      mapVenue: mapVenue ?? this.mapVenue,
      mapParking: mapParking ?? this.mapParking,
      mapFacility: mapFacility ?? this.mapFacility,
      mapTransport: mapTransport ?? this.mapTransport,
      mapRoute: mapRoute ?? this.mapRoute,
      mapRouteCasing: mapRouteCasing ?? this.mapRouteCasing,
    );
  }

  /// Interpolates during `MaterialApp`'s theme cross-fade.
  ///
  /// [brightness] snaps at the halfway point rather than interpolating — a
  /// brightness is categorical, and anything reading `isDark` mid-transition
  /// must get one answer or the other, never a blend.
  @override
  AonPalette lerp(covariant AonPalette? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;

    return AonPalette(
      brightness: t < 0.5 ? brightness : other.brightness,
      surfaceBase: c(surfaceBase, other.surfaceBase),
      surface: c(surface, other.surface),
      surfaceRaised: c(surfaceRaised, other.surfaceRaised),
      border: c(border, other.border),
      borderStrong: c(borderStrong, other.borderStrong),
      accent: c(accent, other.accent),
      accentBright: c(accentBright, other.accentBright),
      accentDeep: c(accentDeep, other.accentDeep),
      onAccent: c(onAccent, other.onAccent),
      info: c(info, other.info),
      infoDeep: c(infoDeep, other.infoDeep),
      tertiary: c(tertiary, other.tertiary),
      contentPrimary: c(contentPrimary, other.contentPrimary),
      contentSecondary: c(contentSecondary, other.contentSecondary),
      contentTertiary: c(contentTertiary, other.contentTertiary),
      live: c(live, other.live),
      soon: c(soon, other.soon),
      error: c(error, other.error),
      mapVenue: c(mapVenue, other.mapVenue),
      mapParking: c(mapParking, other.mapParking),
      mapFacility: c(mapFacility, other.mapFacility),
      mapTransport: c(mapTransport, other.mapTransport),
      mapRoute: c(mapRoute, other.mapRoute),
      mapRouteCasing: c(mapRouteCasing, other.mapRouteCasing),
    );
  }
}

/// `context.aon` — the palette for the current theme.
///
/// Falls back to the AON palette matching the ambient `Theme.brightness`
/// rather than throwing if the extension is missing. A widget mounted under a
/// bare `MaterialApp` in a test should render in the Astronomy identity, not
/// crash — and it should not flip to a dark palette on a light scaffold while
/// doing it.
extension AonPaletteContext on BuildContext {
  AonPalette get aon =>
      Theme.of(this).extension<AonPalette>() ??
      AonPalette.of(Theme.of(this).brightness);
}
