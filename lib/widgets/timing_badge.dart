import 'package:flutter/material.dart';

import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/services/whats_on_service.dart';
import 'package:aon2026/utils/timing_labels.dart';

/// A small status pill: "Happening now", "Starting soon", "Later tonight".
///
/// Each state carries an icon as well as a colour. Relying on green-vs-amber
/// alone would fail for the ~8% of male attendees with a red-green colour
/// deficiency, and the badge is the primary signal on this screen.
class TimingBadge extends StatelessWidget {
  const TimingBadge({required this.timing, this.trailingText, super.key});

  final EventTiming timing;

  /// Optional countdown appended after the label, e.g. "in 12 min".
  final String? trailingText;

  @override
  Widget build(BuildContext context) {
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

    final localised = timing.labelOf(AonL10n.of(context));
    final label =
        trailingText == null ? localised : '$localised · $trailingText';

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
            size: timing == EventTiming.happeningNow ? 9 : AonSpacing.iconSm,
            color: color,
          ),
          const SizedBox(width: AonSpacing.space2),
          // Flexible so the pill ellipsizes its countdown rather than
          // overflowing when it shares a tight row with a long title. Callers
          // must give the badge a bounded width (a Flexible/Wrap/SizedBox
          // parent); every current call site does.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
