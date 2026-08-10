import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aon2026/app/router/app_router.dart';
import 'package:aon2026/app/theme/aon_palette.dart';
import 'package:aon2026/app/theme/aon_spacing.dart';
import 'package:aon2026/services/passport_providers.dart';
import 'package:aon2026/services/stamp_service.dart';
import 'package:aon2026/widgets/aon_tactile_button.dart';

/// Home-screen entry to the Astronomy Passport, showing live progress.
class PassportHomeCard extends ConsumerWidget {
  const PassportHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(passportProvider);

    return AonTactileButton(
      onTap: () => context.push(Routes.passport),
      borderRadius: AonSpacing.radiusMd,
      child: Container(
        padding: const EdgeInsets.all(AonSpacing.space4),
        decoration: BoxDecoration(
          color: context.aon.surface,
          borderRadius: BorderRadius.circular(AonSpacing.radiusMd),
          border: Border.all(color: context.aon.accent.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.workspace_premium_rounded,
              color: context.aon.accent,
              size: AonSpacing.iconMd,
            ),
            const SizedBox(width: AonSpacing.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Astronomy Passport',
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    '${state.count} / ${PassportPolicy.stationCount} stamps',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: context.aon.contentSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.aon.accent),
          ],
        ),
      ),
    );
  }
}
