import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/config/qa_mode.dart';
import 'package:aon2026/l10n/generated/app_localizations.dart';
import 'package:aon2026/services/passport_providers.dart';
import 'package:aon2026/services/stamp_service.dart';
import 'package:aon2026/widgets/passport_fact_sheet.dart';
import 'package:aon2026/widgets/passport_grid.dart';
import 'package:aon2026/widgets/passport_preview_badge.dart';

/// The passport progress line, disabled-state-aware (design §14).
///
/// Completion outranks the disabled gate: a persisted, already-complete passport
/// must not be relabelled "opens on event night" just because a release build
/// currently disables NEW collection. The gate blocks new collection, it does
/// not rewrite history.
String passportProgressLine(
  AonL10n l, {
  required bool collectionEnabled,
  required int count,
  required int total,
}) {
  if (count >= total) return l.passportProgress(total, total); // done — always
  if (!collectionEnabled) return l.passportOpensOnEventNight;
  if (count == 0) return l.passportStartHint;
  if (count == total - 1) return l.passportOneMoreToGo;
  return l.passportProgress(count, total);
}

/// The Astronomy Passport: progress, the 9-cell grid, and the capture entry.
class PassportScreen extends ConsumerWidget {
  const PassportScreen({super.key});

  Future<void> _confirmReset(
    BuildContext context,
    WidgetRef ref,
    AonL10n l,
  ) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.passportResetTitle),
        content: Text(l.passportResetBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.passportResetConfirm),
          ),
        ],
      ),
    );
    if (yes ?? false) ref.read(passportProvider.notifier).reset();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = AonL10n.of(context);
    final state = ref.watch(passportProvider);
    final enabled = ref.watch(passportCollectionEnabledProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.passportTitle),
        actions: [
          // Reset is a QA control behind an explicit per-run define (see
          // qa_mode.dart) — never in release, and no longer in plain debug
          // builds either, so screenshots and E2E see the shipped app bar.
          if (ref.watch(passportResetToolProvider))
            IconButton(
              tooltip: 'Reset passport (debug)',
              icon: const Icon(Icons.restart_alt_rounded),
              onPressed: () => _confirmReset(context, ref, l),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AonSpacing.space4),
        children: [
          // Travels with the stamps, not with the switch: a practice stamp must
          // never read as one earned at a venue.
          const Align(
            alignment: AlignmentDirectional.centerStart,
            child: PassportPreviewBadge(),
          ),
          Text(
            passportProgressLine(
              l,
              collectionEnabled: enabled,
              count: state.count,
              total: PassportPolicy.stationCount,
            ),
            style: theme.textTheme.headlineSmall,
          ),
          // The app has no onboarding (docs/onboarding-decision.md): the one
          // feature a first-time visitor cannot infer from its name is
          // explained here, at the moment they open it, and only until their
          // first stamp — after that the grid itself tells the story.
          if (enabled && state.count == 0) ...[
            const SizedBox(height: AonSpacing.space2),
            Text(
              l.passportHowItWorks,
              key: const Key('passport-how-it-works'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.aon.contentSecondary,
              ),
            ),
          ],
          const SizedBox(height: AonSpacing.space3),
          LinearProgressIndicator(
            value: state.count / PassportPolicy.stationCount,
          ),
          if (state.saveFailed) ...[
            const SizedBox(height: AonSpacing.space3),
            Text(l.passportSaveFailed, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: AonSpacing.space5),
          PassportGrid(
            collectedVenueIds: state.collectedVenueIds,
            onTapCollected: (id) => showPassportFactSheet(
              context, id,
              reason: FactRevealReason.revisit),
          ),
          const SizedBox(height: AonSpacing.space5),
          if (state.isComplete)
            FilledButton.icon(
              onPressed: () => context.push(Routes.passportReward),
              icon: const Icon(Icons.celebration_rounded),
              label: Text(l.passportViewReward),
            )
          else
            FilledButton.icon(
              onPressed: () => context.push(Routes.passportScan),
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: Text(l.passportScanOrEnter),
            ),
        ],
      ),
    );
  }
}
