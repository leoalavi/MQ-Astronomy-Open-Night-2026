import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/services/passport_providers.dart';
import 'package:aon2026/services/stamp_service.dart';
import 'package:aon2026/widgets/passport_fact_sheet.dart';
import 'package:aon2026/widgets/passport_grid.dart';

/// The passport progress line, disabled-state-aware (design §14).
///
/// Completion outranks the disabled gate: a persisted, already-complete passport
/// must not be relabelled "opens on event night" just because a release build
/// currently disables NEW collection. The gate blocks new collection, it does
/// not rewrite history.
String passportProgressLine({
  required bool collectionEnabled,
  required int count,
  required int total,
}) {
  if (count >= total) return '$total / $total stamps'; // completed — always
  if (!collectionEnabled) return 'Astronomy Passport opens on event night';
  if (count == 0) return 'Scan or enter a venue code to start';
  if (count == total - 1) return 'Just 1 more to go!';
  return '$count / $total stamps';
}

/// The Astronomy Passport: progress, the 9-cell grid, and the capture entry.
class PassportScreen extends ConsumerWidget {
  const PassportScreen({super.key});

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset passport?'),
        content:
            const Text('This clears all collected stamps on this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (yes ?? false) ref.read(passportProvider.notifier).reset();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(passportProvider);
    final enabled = ref.watch(passportCollectionEnabledProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Astronomy Passport'),
        actions: [
          // Reset is a demo/QA control, compiled out of release builds.
          if (kDebugMode)
            IconButton(
              tooltip: 'Reset passport (debug)',
              icon: const Icon(Icons.restart_alt_rounded),
              onPressed: () => _confirmReset(context, ref),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AonSpacing.space4),
        children: [
          Text(
            passportProgressLine(
              collectionEnabled: enabled,
              count: state.count,
              total: PassportPolicy.stationCount,
            ),
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: AonSpacing.space3),
          LinearProgressIndicator(
            value: state.count / PassportPolicy.stationCount,
          ),
          if (state.saveFailed) ...[
            const SizedBox(height: AonSpacing.space3),
            Text(
              'Your progress may not be saved on this device.',
              style: theme.textTheme.bodySmall,
            ),
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
              label: const Text('View your reward'),
            )
          else
            FilledButton.icon(
              onPressed: () => context.push(Routes.passportScan),
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Scan or enter a code'),
            ),
        ],
      ),
    );
  }
}
