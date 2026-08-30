import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/data/event_info.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/services/clock.dart';
import 'package:aon2026/utils/time_format.dart';

/// Pins the app's clock to a chosen point on event night.
///
/// ## Why this lives in Settings, not on the visitor's main path
///
/// It used to sit behind a science-flask icon in the app bar of the
/// (now-removed) What's On screen — directly in the flow a first-time visitor
/// takes. At a live event that is noise at best and alarming at worst: a
/// stranger tapping it silently makes the whole app lie about the time.
///
/// It is genuinely useful, though — the organisers review the app weeks before
/// the night, when the honest answer to "what's on now?" is "nothing". So it
/// stays, moved to the bottom of Settings, plainly labelled, and with a
/// permanent banner while it is engaged so nobody can leave it on by accident.
class EventTimePreviewCard extends ConsumerWidget {
  const EventTimePreviewCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = AonL10n.of(context);
    final simulated = ref.watch(simulatedTimeProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AonSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.previewTitle, style: theme.textTheme.titleSmall),
            const SizedBox(height: AonSpacing.space1),
            Text(
              l.previewBody(TimeFormat.date(EventInfo.startsAt)),
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.aon.contentSecondary,
              ),
            ),
            const SizedBox(height: AonSpacing.space4),
            SizedBox(
              width: double.infinity,
              child: simulated == null
                  ? OutlinedButton.icon(
                      onPressed: () => _pick(context, ref),
                      icon: const Icon(Icons.science_outlined),
                      label: Text(l.previewChooseTime),
                    )
                  : FilledButton.icon(
                      onPressed: () =>
                          ref.read(simulatedTimeProvider.notifier).clear(),
                      icon: const Icon(Icons.restore_rounded),
                      label: Text(l.previewBackToRealTime),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _TimePickerSheet(),
    );
  }
}

class _TimePickerSheet extends ConsumerWidget {
  const _TimePickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = AonL10n.of(context);
    final simulated = ref.watch(simulatedTimeProvider);

    // Half-hourly steps across the published event window.
    final steps = <DateTime>[
      for (var h = EventInfo.startsAt.hour; h < EventInfo.endsAt.hour; h++) ...[
        EventInfo.at(h, 0),
        EventInfo.at(h, 30),
      ],
      // The close itself, so an organiser can preview the "that's a wrap"
      // ended state — the loop stopped at 9.30pm, leaving it unreachable in
      // preview (audit HP-F).
      EventInfo.at(EventInfo.endsAt.hour, EventInfo.endsAt.minute),
    ];

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AonSpacing.space5,
            0,
            AonSpacing.space5,
            AonSpacing.space6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.previewTitle, style: theme.textTheme.headlineSmall),
              const SizedBox(height: AonSpacing.space2),
              Text(
                l.previewBody(TimeFormat.date(EventInfo.startsAt)),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: context.aon.contentSecondary,
                ),
              ),
              const SizedBox(height: AonSpacing.space5),
              Wrap(
                spacing: AonSpacing.space2,
                runSpacing: AonSpacing.space2,
                children: [
                  for (final step in steps)
                    ChoiceChip(
                      label: Text(TimeFormat.time(step)),
                      selected: simulated == step,
                      onSelected: (_) {
                        ref.read(simulatedTimeProvider.notifier).set(step);
                        Navigator.of(context).pop();
                      },
                    ),
                ],
              ),
              const SizedBox(height: AonSpacing.space5),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    ref.read(simulatedTimeProvider.notifier).clear();
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.restore_rounded),
                  label: Text(l.previewBackToRealTime),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A persistent strip shown app-wide while the clock is simulated.
///
/// Without this, a visitor who is handed a phone that someone left in preview
/// mode sees a programme that is confidently wrong with no explanation.
class EventTimePreviewBanner extends ConsumerWidget {
  const EventTimePreviewBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final simulated = ref.watch(simulatedTimeProvider);
    if (simulated == null) return const SizedBox.shrink();

    final l = AonL10n.of(context);
    final theme = Theme.of(context);

    return Material(
      color: context.aon.soon.withValues(alpha: 0.18),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AonSpacing.space4,
            vertical: AonSpacing.space2,
          ),
          child: Row(
            children: [
              Icon(
                Icons.science_rounded,
                size: AonSpacing.iconSm,
                color: context.aon.soon,
              ),
              const SizedBox(width: AonSpacing.space2),
              Expanded(
                child: Text(
                  l.previewBanner(TimeFormat.time(simulated)),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: context.aon.soon,
                  ),
                ),
              ),
              TextButton(
                onPressed: () =>
                    ref.read(simulatedTimeProvider.notifier).clear(),
                child: Text(l.previewExit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
