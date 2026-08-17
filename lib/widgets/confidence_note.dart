import 'package:flutter/material.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';

import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/models/data_confidence.dart';

/// An inline notice that a piece of information is not yet confirmed.
///
/// This widget is the visible half of [DataConfidence]. The brief required
/// placeholders to be clearly distinguished from confirmed information, and a
/// comment in a Dart file does not help someone standing in a car park — so
/// anywhere the app renders placeholder data, it renders one of these next to
/// it.
///
/// Renders nothing at all for confirmed or derived data, so call sites can
/// drop it in unconditionally.
class ConfidenceNote extends StatelessWidget {
  const ConfidenceNote({
    required this.confidence,
    this.message,
    this.compact = false,
    super.key,
  });

  final DataConfidence confidence;

  /// Overrides the default wording with something specific to this field.
  final String? message;

  /// Renders as a single line without the boxed background.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l = AonL10n.of(context);
    if (confidence.isReliable) return const SizedBox.shrink();

    final text = message ?? l.infoDetailToBeConfirmed;
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: context.aon.soon);

    if (compact) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: AonSpacing.iconSm,
            color: context.aon.soon,
          ),
          const SizedBox(width: AonSpacing.space2),
          Expanded(child: Text(text, style: style)),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(AonSpacing.space3),
      decoration: BoxDecoration(
        // Low-saturation amber wash — noticeable without competing with the
        // primary accent, which is also amber.
        color: context.aon.soon.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AonSpacing.radiusSm),
        border: Border.all(color: context.aon.soon.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: AonSpacing.iconMd,
            color: context.aon.soon,
          ),
          const SizedBox(width: AonSpacing.space3),
          Expanded(child: Text(text, style: style)),
        ],
      ),
    );
  }
}
