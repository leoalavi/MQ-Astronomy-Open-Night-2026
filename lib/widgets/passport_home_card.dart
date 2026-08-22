import 'package:flutter/material.dart';

import 'package:aon2026/l10n/generated/app_localizations.dart';
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
    final l = AonL10n.of(context);
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
                    l.passportTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    // Localised + locale-aware digits: the old
                    // "$count / $total stamps" literal put a Latin word and
                    // Western digits into a Persian line, where bidi reordered
                    // them to read "stamps 9 / 0". "{count} of {total} stamps"
                    // ("{count} از {total} مهر") is a coherent run in each
                    // language, so current/total never visually reverse.
                    l.passportStampProgress(
                      state.count,
                      PassportPolicy.stationCount,
                    ),
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
