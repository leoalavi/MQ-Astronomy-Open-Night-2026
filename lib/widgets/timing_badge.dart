import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/services/event_phase.dart';
import 'package:aon2026/services/whats_on_service.dart';
import 'package:aon2026/utils/timing_labels.dart';

/// A small status pill: "Happening now", "Starting soon", "Later tonight".
///
/// Each state carries an icon as well as a colour. Relying on green-vs-amber
/// alone would fail for the ~8% of male attendees with a red-green colour
/// deficiency, and the badge is the primary signal on this screen.
class TimingBadge extends ConsumerWidget {
  const TimingBadge({
    required this.timing,
    this.trailingText,
    this.maxWidth,
    super.key,
  });

  final EventTiming timing;

  /// Optional countdown appended after the label, e.g. "in 12 min".
  final String? trailingText;

  /// Width the badge has to fit into, when the caller knows it.
  ///
  /// Supply this wherever the box is genuinely tight — the Home rail card is a
  /// fixed 268pt — and the badge will drop [trailingText] rather than let it be
  /// ellipsized. See the note in [build] for why a cut countdown is unacceptable.
  ///
  /// Deliberately a parameter rather than a LayoutBuilder measurement: the rail
  /// wraps its cards in an `IntrinsicHeight` to equalise their heights, and a
  /// LayoutBuilder anywhere in that subtree throws "does not support returning
  /// intrinsic dimensions". Callers that have room simply omit it.
  final double? maxWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (color, icon) = switch (timing) {
      EventTiming.happeningNow => (context.aon.live, Icons.circle),
      EventTiming.startingSoon => (context.aon.soon, Icons.schedule_rounded),
      EventTiming.upcoming => (
          context.aon.contentTertiary,
          Icons.more_time_rounded
        ),
      EventTiming.finished => (
          context.aon.contentTertiary,
          Icons.check_circle_outline_rounded
        ),
    };

    // Phase-aware: "Later tonight" is only true on the event date.
    final localised = timing.labelOf(
      AonL10n.of(context),
      phase: ref.watch(eventPhaseProvider),
    );
    final style =
        Theme.of(context).textTheme.labelSmall?.copyWith(color: color);
    final iconSize =
        timing == EventTiming.happeningNow ? 9.0 : AonSpacing.iconSm;

    // Everything in the pill that is not the text itself.
    const chrome = AonSpacing.space3 * 2 + AonSpacing.space2;

    // ── Why this measures instead of just ellipsizing ──
    //
    // The countdown is a number, and a clipped number is worse than no number.
    // In the Home rail the card is a fixed 268pt with 56pt reserved for the save
    // button, so the badge gets ~196pt — not enough for
    // "Happening now · in 15 min", which ellipsis rendered as
    // "Happening now · in 1…". That still reads as a valid duration, so nothing
    // signals to the reader that anything was lost: a visitor sees "in 1" and
    // believes they have a minute to cross campus rather than fifteen.
    //
    // So degrade by dropping the countdown whole. A missing countdown is
    // recoverable — the card prints the session's real time range directly
    // underneath — and a wrong one is not.
    final full = trailingText == null ? localised : '$localised · $trailingText';

    var label = full;
    if (trailingText != null && maxWidth != null) {
      final available = maxWidth! - chrome - iconSize;
      if (_widthOf(full, style, context) > available) label = localised;
    }

    return _pill(context,
        color: color, icon: icon, iconSize: iconSize, label: label, style: style);
  }

  /// Laid-out width of [text] in [style], unconstrained.
  double _widthOf(String text, TextStyle? style, BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    return painter.size.width;
  }

  Widget _pill(
    BuildContext context, {
    required Color color,
    required IconData icon,
    required double iconSize,
    required String label,
    required TextStyle? style,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AonSpacing.space3,
        vertical: AonSpacing.space1 + 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AonSpacing.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            // The "now" dot is a filled circle and reads as a live indicator
            // at a much smaller size than the other glyphs.
            size: iconSize,
            color: color,
          ),
          const SizedBox(width: AonSpacing.space2),
          // Still Flexible + ellipsis as a last resort: the countdown has
          // already been dropped by now, so anything clipped here is a word of
          // the status label, not a number.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}
