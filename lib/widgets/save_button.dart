import 'dart:async';

import 'package:flutter/material.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/config/event_config.dart';
import 'package:aon2026/services/saved_events.dart';
import 'package:aon2026/utils/haptics.dart';
import 'package:aon2026/widgets/aon_tactile_button.dart';

/// Adds or removes an activity from the visitor's plan.
///
/// Two forms, one behaviour — [SaveButton.icon] for dense list rows and
/// [SaveButton.labelled] for detail screens. Sharing one widget means the
/// saved/unsaved semantics, haptics and accessibility labels can never drift
/// between them.
///
/// The label is read from [EventTerminology], so this widget says "My Night"
/// at Astronomy and would say "Your Day" at Open Day without being touched.
class SaveButton extends ConsumerWidget {
  const SaveButton({
    required this.eventId,
    required this.eventTitle,
    this.labelled = false,
    super.key,
  });

  const SaveButton.labelled({
    required this.eventId,
    required this.eventTitle,
    super.key,
  }) : labelled = true;

  final String eventId;

  /// Used only for the confirmation message. Passing it in avoids a lookup
  /// for something the caller already has.
  final String eventTitle;

  final bool labelled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AonL10n.of(context);
    final saved = ref.watch(isSavedProvider(eventId));
    final planName = ref.watch(terminologyProvider).myPlan(l);

    // Filled star = saved, outline = not. Shape carries the state as well as
    // colour, so it survives a night-shift filter and colour-blindness.
    final icon = saved ? Icons.star_rounded : Icons.star_outline_rounded;
    final colour = saved ? context.aon.accent : context.aon.contentSecondary;
    final semanticLabel = saved
        ? 'Remove $eventTitle from $planName'
        : 'Save $eventTitle to $planName';

    Future<void> onPressed() async {
      final nowSaved = await ref
          .read(savedEventsProvider.notifier)
          .toggle(eventId);
      unawaited(AonHaptics.selection(true));
      if (!context.mounted) return;

      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger
        ?..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              nowSaved ? 'Saved to $planName' : 'Removed from $planName',
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }

    if (labelled) {
      return Semantics(
        button: true,
        label: semanticLabel,
        child: ExcludeSemantics(
          child: OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, color: colour),
            label: Text(saved ? 'Saved' : 'Save'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colour,
              side: BorderSide(
                color: saved ? context.aon.accent : context.aon.borderStrong,
              ),
            ),
          ),
        ),
      );
    }

    // AonTactileButton, not IconButton: the design system forbids InkWell on
    // these surfaces (it fights the glass/tactile press feedback), and this
    // button sits inside cards that the governance tests check.
    //
    // AonTactileButton merges its subtree into one button node, so the
    // accessible name has to come from a Semantics label — there is no text
    // to merge, only a star glyph.
    return AonTactileButton(
      onTap: () => unawaited(onPressed()),
      borderRadius: AonSpacing.radiusFull,
      child: Semantics(
        label: semanticLabel,
        child: Tooltip(
          message: saved ? 'Remove from $planName' : 'Save to $planName',
          child: ConstrainedBox(
            // The full 56pt target even though the glyph is small — this sits
            // inside a scrolling list and gets tapped one-handed in the dark.
            constraints: const BoxConstraints(
              minWidth: AonSpacing.minTapTarget,
              minHeight: AonSpacing.minTapTarget,
            ),
            child: Icon(icon, color: colour),
          ),
        ),
      ),
    );
  }
}
