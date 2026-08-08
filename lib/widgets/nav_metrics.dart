import 'package:flutter/widgets.dart';

/// Single source of truth for the floating glass tab-bar's geometry.
///
/// The island height and the body clearance behind it are derived from ONE
/// resolved height so they can never drift into separate magic numbers
/// (spec §5.8). aon2026 measures first: the bar height is constant unless a
/// real overflow is found at a large text scale, in which case only this
/// function changes and all four consumers follow.
abstract final class AonNavMetrics {
  /// The `LiquidTabBar` default height. Baseline expected to hold through 2.0
  /// text scale (non-scaling icon 25 + scaled 13px label ≈ 53 < 66); verified
  /// by the shell tests, not assumed.
  static const double barHeight = 66;

  /// Gap between the island and the screen edges (matches the shell padding).
  static const double _outerBottomPadding = 12;

  /// Breathing room between the last content item and the island.
  static const double _contentGap = 12;

  /// The resolved bar height for the current context. Constant today; the
  /// single place to make it text-scale-aware if measurement demands it.
  static double resolvedBarHeight(BuildContext context) => barHeight;

  /// Bottom clearance a scrollable body must reserve so its last item, and any
  /// floating control, clears the glass island AND the home indicator.
  static double clearance(BuildContext context) =>
      resolvedBarHeight(context) +
      _outerBottomPadding +
      _contentGap +
      MediaQuery.paddingOf(context).bottom;
}
